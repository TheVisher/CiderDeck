#include "EvdevTouchService.h"

#include <QCoreApplication>
#include <QMouseEvent>
#include <QSocketNotifier>
#include <QTimer>
#include <QWindow>
#include <QDebug>
#include <QDir>

#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <cerrno>

namespace ciderdeck {

EvdevTouchService::EvdevTouchService(QWindow *window, QObject *parent)
    : QObject(parent)
    , window_(window)
{
    reconnectTimer_ = new QTimer(this);
    reconnectTimer_->setSingleShot(true);
    connect(reconnectTimer_, &QTimer::timeout, this, &EvdevTouchService::reconnect);
}

EvdevTouchService::~EvdevTouchService()
{
    stop();
}

QString EvdevTouchService::detectDevice()
{
    char name[256];
    for (int i = 0; i < 32; ++i) {
        const QString path = QStringLiteral("/dev/input/event%1").arg(i);
        int testFd = ::open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK);
        if (testFd < 0)
            continue;

        if (::ioctl(testFd, EVIOCGNAME(sizeof(name)), name) >= 0) {
            const QString devName = QString::fromUtf8(name);
            if (devName.contains(QStringLiteral("TouchScreen"), Qt::CaseInsensitive)) {
                ::close(testFd);
                qInfo() << "[EvdevTouchService] Detected touchscreen:" << devName << "at" << path;
                return path;
            }
        }
        ::close(testFd);
    }
    return {};
}

void EvdevTouchService::disableUsbAutosuspend()
{
    // Find the USB device's power/control file and set it to "on"
    // to prevent the kernel from suspending the touchscreen.
    QDir inputDir(QStringLiteral("/sys/class/input"));
    const QString eventName = QFileInfo(devicePath_).fileName(); // e.g. "event22"
    const QString deviceLink = QStringLiteral("/sys/class/input/%1/device").arg(eventName);

    // Walk up to find the USB device: device -> ../.. until we find power/control
    QString path = QFileInfo(deviceLink).canonicalFilePath();
    for (int i = 0; i < 6 && !path.isEmpty(); ++i) {
        const QString powerControl = path + QStringLiteral("/power/control");
        if (QFile::exists(powerControl)) {
            QFile f(powerControl);
            if (f.open(QIODevice::WriteOnly)) {
                f.write("on");
                f.close();
                qInfo() << "[EvdevTouchService] Disabled USB autosuspend via" << powerControl;
            }
            return;
        }
        path = QFileInfo(path).absolutePath(); // go up one level
    }
}

bool EvdevTouchService::start(const QString &devicePath)
{
    if (fd_ >= 0) {
        qWarning() << "[EvdevTouchService] Already started on" << devicePath_;
        return true;
    }

    QString path = devicePath;
    if (path.isEmpty())
        path = lastDevicePath_.isEmpty() ? detectDevice() : lastDevicePath_;

    if (path.isEmpty()) {
        qWarning() << "[EvdevTouchService] No touchscreen device found — touch falls back to compositor";
        return false;
    }

    fd_ = ::open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK);
    if (fd_ < 0) {
        qWarning() << "[EvdevTouchService] Failed to open" << path << "— check permissions (user must be in 'input' group)";
        return false;
    }

    // Exclusive grab — prevents double-input since this screen is dedicated to CiderDeck
    if (::ioctl(fd_, EVIOCGRAB, 1) < 0) {
        qWarning() << "[EvdevTouchService] EVIOCGRAB failed on" << path << "— continuing without exclusive grab";
    }

    // Read axis ranges
    struct input_absinfo absX{}, absY{};
    if (::ioctl(fd_, EVIOCGABS(ABS_X), &absX) == 0) {
        absXMin_ = absX.minimum;
        absXMax_ = absX.maximum;
    }
    if (::ioctl(fd_, EVIOCGABS(ABS_Y), &absY) == 0) {
        absYMin_ = absY.minimum;
        absYMax_ = absY.maximum;
    }

    if (absXMax_ <= absXMin_ || absYMax_ <= absYMin_) {
        qWarning() << "[EvdevTouchService] Invalid axis ranges — X:" << absXMin_ << "-" << absXMax_
                    << "Y:" << absYMin_ << "-" << absYMax_;
        stop();
        return false;
    }

    devicePath_ = path;
    lastDevicePath_ = path;
    notifier_ = new QSocketNotifier(fd_, QSocketNotifier::Read, this);
    connect(notifier_, &QSocketNotifier::activated, this, &EvdevTouchService::onReadReady);

    disableUsbAutosuspend();

    qInfo() << "[EvdevTouchService] Opened" << path
            << "X range:" << absXMin_ << "-" << absXMax_
            << "Y range:" << absYMin_ << "-" << absYMax_;

    emit activeChanged();
    emit devicePathChanged();
    return true;
}

void EvdevTouchService::stop()
{
    reconnectTimer_->stop();

    if (fd_ < 0)
        return;

    delete notifier_;
    notifier_ = nullptr;

    ::ioctl(fd_, EVIOCGRAB, 0);
    ::close(fd_);
    fd_ = -1;
    devicePath_.clear();
    touchDown_ = false;
    pressed_ = false;

    emit activeChanged();
    emit devicePathChanged();
}

void EvdevTouchService::reconnect()
{
    qInfo() << "[EvdevTouchService] Attempting reconnect...";
    // stop() without clearing lastDevicePath_ so start() can reuse it
    if (fd_ >= 0) {
        delete notifier_;
        notifier_ = nullptr;
        ::ioctl(fd_, EVIOCGRAB, 0);
        ::close(fd_);
        fd_ = -1;
        devicePath_.clear();
        touchDown_ = false;
        pressed_ = false;
    }

    // Try the remembered path first, fall back to re-detection
    if (!start(lastDevicePath_)) {
        // Device might have a new event number after USB reset
        lastDevicePath_.clear();
        if (!start()) {
            qWarning() << "[EvdevTouchService] Reconnect failed — retrying in 3s";
            reconnectTimer_->start(3000);
        }
    }
}

void EvdevTouchService::onReadReady()
{
    struct input_event ev;
    for (;;) {
        ssize_t n = ::read(fd_, &ev, sizeof(ev));
        if (n == static_cast<ssize_t>(sizeof(ev))) {
            // Successfully read an event — process it below
        } else if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            break; // No more events available right now
        } else {
            // Read error (ENODEV, EIO, etc.) or unexpected short read — device is gone
            qWarning() << "[EvdevTouchService] Read error (errno:" << errno << ") — scheduling reconnect";
            // Send a release if we had a press in flight
            if (pressed_ && window_) {
                const QPointF lastPos(
                    static_cast<qreal>(currentX_ - absXMin_) * window_->width() / (absXMax_ - absXMin_),
                    static_cast<qreal>(currentY_ - absYMin_) * window_->height() / (absYMax_ - absYMin_));
                QMouseEvent release(QEvent::MouseButtonRelease, lastPos, window_->mapToGlobal(lastPos),
                                    Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window_, &release);
            }
            pressed_ = false;
            touchDown_ = false;
            reconnectTimer_->start(1000);
            return;
        }

        switch (ev.type) {
        case EV_ABS:
            if (ev.code == ABS_X)
                currentX_ = ev.value;
            else if (ev.code == ABS_Y)
                currentY_ = ev.value;
            break;

        case EV_KEY:
            if (ev.code == BTN_TOUCH)
                touchDown_ = (ev.value != 0);
            break;

        case EV_SYN:
            if (ev.code == SYN_REPORT && window_) {
                const int winW = window_->width();
                const int winH = window_->height();

                const qreal pixelX = static_cast<qreal>(currentX_ - absXMin_) * winW / (absXMax_ - absXMin_);
                const qreal pixelY = static_cast<qreal>(currentY_ - absYMin_) * winH / (absYMax_ - absYMin_);
                const QPointF localPos(pixelX, pixelY);

                if (touchDown_) {
                    if (!pressed_) {
                        QMouseEvent press(QEvent::MouseButtonPress, localPos, window_->mapToGlobal(localPos),
                                          Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
                        QCoreApplication::sendEvent(window_, &press);
                        pressed_ = true;
                    } else {
                        QMouseEvent move(QEvent::MouseMove, localPos, window_->mapToGlobal(localPos),
                                         Qt::LeftButton, Qt::LeftButton, Qt::NoModifier);
                        QCoreApplication::sendEvent(window_, &move);
                    }
                } else if (pressed_) {
                    QMouseEvent release(QEvent::MouseButtonRelease, localPos, window_->mapToGlobal(localPos),
                                        Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
                    QCoreApplication::sendEvent(window_, &release);
                    pressed_ = false;
                }
            }
            break;

        default:
            break;
        }
    }
}

} // namespace ciderdeck
