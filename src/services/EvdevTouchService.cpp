#include "EvdevTouchService.h"

#include <QCoreApplication>
#include <QMouseEvent>
#include <QSocketNotifier>
#include <QWindow>
#include <QDebug>

#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>

namespace ciderdeck {

EvdevTouchService::EvdevTouchService(QWindow *window, QObject *parent)
    : QObject(parent)
    , window_(window)
{
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

bool EvdevTouchService::start(const QString &devicePath)
{
    if (fd_ >= 0) {
        qWarning() << "[EvdevTouchService] Already started on" << devicePath_;
        return true;
    }

    QString path = devicePath;
    if (path.isEmpty())
        path = detectDevice();

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
    notifier_ = new QSocketNotifier(fd_, QSocketNotifier::Read, this);
    connect(notifier_, &QSocketNotifier::activated, this, &EvdevTouchService::onReadReady);

    qInfo() << "[EvdevTouchService] Opened" << path
            << "X range:" << absXMin_ << "-" << absXMax_
            << "Y range:" << absYMin_ << "-" << absYMax_;

    emit activeChanged();
    emit devicePathChanged();
    return true;
}

void EvdevTouchService::stop()
{
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

void EvdevTouchService::onReadReady()
{
    struct input_event ev;
    while (::read(fd_, &ev, sizeof(ev)) == static_cast<ssize_t>(sizeof(ev))) {
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
