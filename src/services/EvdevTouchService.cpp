#include "EvdevTouchService.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QMouseEvent>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTimer>
#include <QWindow>
#include <QDebug>
#include <QDir>

#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <cerrno>

#include <algorithm>

namespace ciderdeck {

namespace {

template <size_t N>
bool bitIsSet(const unsigned long (&bits)[N], unsigned int bit)
{
    constexpr unsigned int bitsPerWord = sizeof(unsigned long) * 8;
    return bit / bitsPerWord < N && (bits[bit / bitsPerWord] & (1UL << (bit % bitsPerWord)));
}

QString touchCalibrationStoragePath()
{
    const QString overrideDirectory = qEnvironmentVariable("CIDERDECK_CONFIG_DIR");
    const QString directory = overrideDirectory.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation)
        : overrideDirectory;
    return QDir(directory).filePath(QStringLiteral("touch-calibration.json"));
}

} // namespace

EvdevTouchService::EvdevTouchService(QWindow *window, QObject *parent)
    : QObject(parent)
    , window_(window)
    , deviceProbe_(&EvdevTouchService::probeDevice)
    , calibrationStoragePath_(touchCalibrationStoragePath())
{
    reconnectTimer_ = new QTimer(this);
    reconnectTimer_->setSingleShot(true);
    connect(reconnectTimer_, &QTimer::timeout, this, &EvdevTouchService::reconnect);

    // Listen for system sleep/wake via systemd-logind
    QDBusConnection::systemBus().connect(
        QStringLiteral("org.freedesktop.login1"),
        QStringLiteral("/org/freedesktop/login1"),
        QStringLiteral("org.freedesktop.login1.Manager"),
        QStringLiteral("PrepareForSleep"),
        this, SLOT(onSystemWake(bool)));
}

EvdevTouchService::~EvdevTouchService()
{
    stop();
}

int EvdevTouchService::RetryState::recordFailure()
{
    static constexpr int delaysMs[]{3000, 6000, 12000, 24000, 48000, 60000};
    const int index = failureCount < 5 ? failureCount : 5;
    if (failureCount < 5)
        ++failureCount;
    return delaysMs[index];
}

bool EvdevTouchService::RetryState::shouldLogUnavailable()
{
    unavailable = true;
    if (unavailableLogEmitted)
        return false;

    unavailableLogEmitted = true;
    return true;
}

void EvdevTouchService::RetryState::markUnavailable()
{
    unavailable = true;
}

bool EvdevTouchService::RetryState::markRecovered()
{
    const bool wasUnavailable = unavailable;
    reset();
    return wasUnavailable;
}

void EvdevTouchService::RetryState::reset()
{
    failureCount = 0;
    unavailable = false;
    unavailableLogEmitted = false;
}

bool EvdevTouchService::DeviceIdentity::isValid() const
{
    return vendor != 0 || product != 0 || !name.isEmpty() || !physical.isEmpty();
}

QString EvdevTouchService::deviceName() const
{
    return selectedIdentity_.name;
}

QString EvdevTouchService::deviceIdentity() const
{
    if (!selectedIdentity_.isValid())
        return {};
    return stableTouchscreenIdentity(
        selectedIdentity_.busType, selectedIdentity_.vendor,
        selectedIdentity_.product, selectedIdentity_.version,
        selectedIdentity_.name, selectedIdentity_.physical);
}

QString EvdevTouchService::statusText() const
{
    if (active())
        return QStringLiteral("Direct touch input active");
    if (!lastOpenError_.isEmpty())
        return lastOpenError_;
    return QStringLiteral("Waiting for a direct touchscreen");
}

void EvdevTouchService::useCalibration(const TouchAffineTransform &transform)
{
    calibrationTransform_ = transform.isValid() ? transform : TouchAffineTransform::identity();
    emit calibrationChanged();
}

bool EvdevTouchService::saveCalibration(const TouchAffineTransform &transform, QString *error)
{
    const QString identity = deviceIdentity();
    if (identity.isEmpty() || calibrationStoragePath_.isEmpty()) {
        if (error)
            *error = QStringLiteral("No stable touchscreen identity is available");
        return false;
    }
    if (!TouchCalibrationStore(calibrationStoragePath_).saveProfile(identity, transform, error))
        return false;

    calibrationTransform_ = transform;
    hasCalibrationProfile_ = true;
    emit calibrationChanged();
    return true;
}

bool EvdevTouchService::resetCalibration(QString *error)
{
    const QString identity = deviceIdentity();
    if (identity.isEmpty() || calibrationStoragePath_.isEmpty()) {
        if (error)
            *error = QStringLiteral("No stable touchscreen identity is available");
        return false;
    }
    if (!TouchCalibrationStore(calibrationStoragePath_).removeProfile(identity, error))
        return false;

    calibrationTransform_ = TouchAffineTransform::identity();
    hasCalibrationProfile_ = false;
    emit calibrationChanged();
    return true;
}

EvdevTouchService::ProbedDevice EvdevTouchService::probeDevice(const QString &path)
{
    const int testFd = ::open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK);
    if (testFd < 0)
        return probeResultForOpenError(errno);

    ProbedDevice probe;
    probe.result = DeviceProbeResult::NotTouchscreen;
    probe.candidate.path = path;

    struct input_id id{};
    if (::ioctl(testFd, EVIOCGID, &id) == 0) {
        probe.candidate.identity.busType = id.bustype;
        probe.candidate.identity.vendor = id.vendor;
        probe.candidate.identity.product = id.product;
        probe.candidate.identity.version = id.version;
    }

    char name[256]{};
    if (::ioctl(testFd, EVIOCGNAME(sizeof(name)), name) >= 0)
        probe.candidate.identity.name = QString::fromUtf8(name);

    char physical[256]{};
    if (::ioctl(testFd, EVIOCGPHYS(sizeof(physical)), physical) >= 0)
        probe.candidate.identity.physical = QString::fromUtf8(physical);

    unsigned long properties[(INPUT_PROP_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    unsigned long absoluteBits[(ABS_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    unsigned long keyBits[(KEY_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    unsigned long relativeBits[(REL_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    ::ioctl(testFd, EVIOCGPROP(sizeof(properties)), properties);
    ::ioctl(testFd, EVIOCGBIT(EV_ABS, sizeof(absoluteBits)), absoluteBits);
    ::ioctl(testFd, EVIOCGBIT(EV_KEY, sizeof(keyBits)), keyBits);
    ::ioctl(testFd, EVIOCGBIT(EV_REL, sizeof(relativeBits)), relativeBits);

    probe.candidate.direct = bitIsSet(properties, INPUT_PROP_DIRECT);
    probe.candidate.hasAbsX = bitIsSet(absoluteBits, ABS_X);
    probe.candidate.hasAbsY = bitIsSet(absoluteBits, ABS_Y);
    probe.candidate.hasMtX = bitIsSet(absoluteBits, ABS_MT_POSITION_X);
    probe.candidate.hasMtY = bitIsSet(absoluteBits, ABS_MT_POSITION_Y);
    probe.candidate.hasBtnTouch = bitIsSet(keyBits, BTN_TOUCH);
    probe.candidate.hasMtTrackingId = bitIsSet(absoluteBits, ABS_MT_TRACKING_ID);
    probe.candidate.hasRelX = bitIsSet(relativeBits, REL_X);
    probe.candidate.hasRelY = bitIsSet(relativeBits, REL_Y);

    if (candidateScore(probe.candidate) >= 0)
        probe.result = DeviceProbeResult::Touchscreen;

    ::close(testFd);
    return probe;
}

int EvdevTouchService::candidateScore(const DeviceCandidate &candidate)
{
    const bool hasCoordinates = (candidate.hasAbsX && candidate.hasAbsY)
        || (candidate.hasMtX && candidate.hasMtY);
    const bool hasTouchSignal = candidate.hasBtnTouch || candidate.hasMtTrackingId;
    if (!candidate.direct || !hasCoordinates || !hasTouchSignal)
        return -1;

    int score = 0;
    if (candidate.direct)
        score += 1000;
    if (candidate.hasMtX && candidate.hasMtY)
        score += 400;
    if (candidate.hasAbsX && candidate.hasAbsY)
        score += 300;
    if (candidate.hasMtTrackingId)
        score += 200;
    if (candidate.hasBtnTouch)
        score += 100;
    if (candidate.identity.name.contains(QStringLiteral("touchscreen"), Qt::CaseInsensitive))
        score += 25;
    if (candidate.hasRelX || candidate.hasRelY)
        score -= 1000;
    return score;
}

EvdevTouchService::DeviceCandidate EvdevTouchService::selectBestCandidate(
    const QList<DeviceCandidate> &candidates)
{
    return selectBestCandidate(candidates, DeviceIdentity{});
}

EvdevTouchService::DeviceCandidate EvdevTouchService::selectBestCandidate(
    const QList<DeviceCandidate> &candidates,
    const DeviceIdentity &requiredIdentity)
{
    DeviceCandidate best;
    int bestScore = -1;
    for (const DeviceCandidate &candidate : candidates) {
        if (requiredIdentity.isValid() && !(candidate.identity == requiredIdentity))
            continue;
        const int score = candidateScore(candidate);
        if (score > bestScore) {
            best = candidate;
            bestScore = score;
        }
    }
    return best;
}

EvdevTouchService::TouchUpdate EvdevTouchService::processInputEvent(
    InputState &state, quint16 type, quint16 code, qint32 value)
{
    if (type == EV_SYN && code == SYN_DROPPED) {
        TouchUpdate update = cancelInput(state);
        update.reconnect = true;
        state.dropping = true;
        return update;
    }

    if (state.dropping) {
        if (type == EV_SYN && code == SYN_REPORT)
            state.dropping = false;
        return {};
    }

    if (type == EV_ABS) {
        switch (code) {
        case ABS_X:
            state.x = value;
            break;
        case ABS_Y:
            state.y = value;
            break;
        case ABS_MT_SLOT:
            state.mtSeen = true;
            state.currentSlot = value;
            break;
        case ABS_MT_TRACKING_ID: {
            state.mtSeen = true;
            MtContact &contact = state.contacts[state.currentSlot];
            contact.trackingId = value;
            if (value >= 0 && state.activeSlot < 0)
                state.activeSlot = state.currentSlot;
            break;
        }
        case ABS_MT_POSITION_X:
            state.mtSeen = true;
            state.contacts[state.currentSlot].x = value;
            break;
        case ABS_MT_POSITION_Y:
            state.mtSeen = true;
            state.contacts[state.currentSlot].y = value;
            break;
        default:
            break;
        }
        return {};
    }

    if (type == EV_KEY && code == BTN_TOUCH) {
        state.buttonDown = value != 0;
        return {};
    }

    if (type != EV_SYN || code != SYN_REPORT)
        return {};

    bool down = state.buttonDown;
    if (state.mtSeen) {
        auto contact = state.contacts.constFind(state.activeSlot);
        if (contact == state.contacts.cend() || contact->trackingId < 0) {
            int nextActiveSlot = -1;
            for (auto it = state.contacts.cbegin(); it != state.contacts.cend(); ++it) {
                if (it->trackingId >= 0 && (nextActiveSlot < 0 || it.key() < nextActiveSlot))
                    nextActiveSlot = it.key();
            }
            state.activeSlot = nextActiveSlot;
            contact = state.contacts.constFind(state.activeSlot);
        }
        down = contact != state.contacts.cend() && contact->trackingId >= 0;
        if (contact != state.contacts.cend()) {
            state.x = contact->x;
            state.y = contact->y;
        }
    }

    TouchUpdate update;
    update.x = state.x;
    update.y = state.y;
    if (down) {
        update.action = state.pressed ? TouchAction::Move : TouchAction::Press;
        state.pressed = true;
    } else if (state.pressed) {
        update.action = TouchAction::Release;
        state.pressed = false;
    }
    return update;
}

EvdevTouchService::TouchUpdate EvdevTouchService::cancelInput(InputState &state)
{
    TouchUpdate update;
    update.x = state.x;
    update.y = state.y;
    if (state.pressed)
        update.action = TouchAction::Release;
    state = {};
    return update;
}

QPointF EvdevTouchService::normalizedPosition(const TouchUpdate &update) const
{
    return mapEvdevToNormalized(update.x, update.y,
                                absXMin_, absXMax_, absYMin_, absYMax_,
                                calibrationTransform_);
}

void EvdevTouchService::dispatchTouchUpdate(const TouchUpdate &update)
{
    if (update.action == TouchAction::None)
        return;

    if (window_ && !calibrationCaptureActive_) {
        const QPointF normalized = normalizedPosition(update);
        const QPointF localPos(normalized.x() * window_->width(),
                               normalized.y() * window_->height());

        QEvent::Type eventType = QEvent::MouseMove;
        Qt::MouseButton button = Qt::NoButton;
        Qt::MouseButtons buttons = Qt::LeftButton;
        if (update.action == TouchAction::Press) {
            eventType = QEvent::MouseButtonPress;
            button = Qt::LeftButton;
        } else if (update.action == TouchAction::Release) {
            eventType = QEvent::MouseButtonRelease;
            button = Qt::LeftButton;
            buttons = Qt::NoButton;
        }
        QMouseEvent mouseEvent(eventType, localPos, window_->mapToGlobal(localPos),
                               button, buttons, Qt::NoModifier);
        QCoreApplication::sendEvent(window_, &mouseEvent);
    }

    const QPointF rawPosition = mapEvdevToNormalized(
        update.x, update.y, absXMin_, absXMax_, absYMin_, absYMax_,
        TouchAffineTransform::identity());
    switch (update.action) {
    case TouchAction::Press:
        emit rawTouchPressed(rawPosition);
        break;
    case TouchAction::Move:
        emit rawTouchMoved(rawPosition);
        break;
    case TouchAction::Release:
        emit rawTouchReleased(rawPosition);
        break;
    case TouchAction::None:
        break;
    }
}

EvdevTouchService::DeviceProbeResult EvdevTouchService::probeResultForOpenError(int errorNumber)
{
    return errorNumber == EACCES || errorNumber == EPERM ? DeviceProbeResult::PermissionDenied
                                                          : DeviceProbeResult::Unavailable;
}

QString EvdevTouchService::permissionDeniedError(const QString &path)
{
    return QStringLiteral(
               "Failed to open %1 — check permissions (user must be in 'input' group)")
        .arg(path);
}

QString EvdevTouchService::detectDevice()
{
    QString permissionDeniedPath;
    QList<DeviceCandidate> candidates;
    const QStringList devicePaths = eventDevicePaths(inputDirectory_);
    for (const QString &path : devicePaths) {
        const ProbedDevice probe = deviceProbe_(path);
        if (probe.result == DeviceProbeResult::Touchscreen)
            candidates.append(probe.candidate);
        if (probe.result == DeviceProbeResult::PermissionDenied && permissionDeniedPath.isEmpty())
            permissionDeniedPath = path;
    }

    const DeviceCandidate selected = selectBestCandidate(candidates, selectedIdentity_);
    if (!selected.path.isEmpty()) {
        selectedCandidate_ = selected;
        return selected.path;
    }

    if (!permissionDeniedPath.isEmpty())
        lastOpenError_ = permissionDeniedError(permissionDeniedPath);
    return {};
}

QStringList EvdevTouchService::eventDevicePaths(const QString &inputDirectory)
{
    const QDir directory(inputDirectory);
    const QFileInfoList entries = directory.entryInfoList(
        {QStringLiteral("event*")},
        QDir::Files | QDir::System | QDir::NoDotAndDotDot,
        QDir::NoSort);

    QFileInfoList eventEntries;
    for (const QFileInfo &entry : entries) {
        bool eventNumberIsValid = false;
        entry.fileName().mid(5).toUInt(&eventNumberIsValid);
        if (eventNumberIsValid)
            eventEntries.append(entry);
    }

    std::sort(eventEntries.begin(), eventEntries.end(), [](const QFileInfo &left, const QFileInfo &right) {
        return left.fileName().mid(5).toUInt() < right.fileName().mid(5).toUInt();
    });

    QStringList paths;
    paths.reserve(eventEntries.size());
    for (const QFileInfo &entry : eventEntries)
        paths.append(entry.absoluteFilePath());
    return paths;
}

QString EvdevTouchService::attemptReconnectCycle(
    const QString &rememberedPath,
    const std::function<QString()> &detectDevice,
    const std::function<bool(const QString &)> &openDevice)
{
    Q_UNUSED(rememberedPath);

    const QString detectedPath = detectDevice();
    if (detectedPath.isEmpty())
        return {};

    return openDevice(detectedPath) ? detectedPath : QString{};
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
    runningRequested_ = true;

    if (fd_ >= 0) {
        qWarning() << "[EvdevTouchService] Already started on" << devicePath_;
        return true;
    }

    QString path = devicePath;
    if (path.isEmpty()) {
        lastOpenError_.clear();
        path = detectDevice();
    } else {
        // An explicit path is a configured selection. Probe it so its stable
        // identity and MT capabilities can be retained for later rediscovery.
        selectedCandidate_ = {};
        selectedIdentity_ = {};
        const ProbedDevice probe = deviceProbe_(path);
        if (probe.result == DeviceProbeResult::Touchscreen)
            selectedCandidate_ = probe.candidate;
    }

    if (path.isEmpty()) {
        if (lastOpenError_.isEmpty())
            lastOpenError_ = QStringLiteral("No touchscreen device found");
        handleReconnectFailure();
        return false;
    }

    if (!openDevice(path)) {
        handleReconnectFailure();
        return false;
    }

    reconnectTimer_->stop();
    if (selectedCandidate_.path == path && selectedCandidate_.identity.isValid())
        selectedIdentity_ = selectedCandidate_.identity;
    loadCalibrationProfile();
    logOpened(retryState_.markRecovered());
    return true;
}

bool EvdevTouchService::openDevice(const QString &path)
{
    lastOpenError_.clear();
    fd_ = ::open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK);
    if (fd_ < 0) {
        if (errno == EACCES || errno == EPERM) {
            lastOpenError_ = permissionDeniedError(path);
        } else {
            lastOpenError_ = QStringLiteral("Failed to open %1 (errno %2)").arg(path).arg(errno);
        }
        return false;
    }

    // Read axis ranges
    struct input_absinfo absX{}, absY{};
    const bool useMultitouchAxes = selectedCandidate_.path == path
        && selectedCandidate_.hasMtX && selectedCandidate_.hasMtY;
    const int xAxis = useMultitouchAxes ? ABS_MT_POSITION_X : ABS_X;
    const int yAxis = useMultitouchAxes ? ABS_MT_POSITION_Y : ABS_Y;
    absXMin_ = 0;
    absXMax_ = 1;
    absYMin_ = 0;
    absYMax_ = 1;
    if (::ioctl(fd_, EVIOCGABS(xAxis), &absX) == 0) {
        absXMin_ = absX.minimum;
        absXMax_ = absX.maximum;
    }
    if (::ioctl(fd_, EVIOCGABS(yAxis), &absY) == 0) {
        absYMin_ = absY.minimum;
        absYMax_ = absY.maximum;
    }

    if (absXMax_ <= absXMin_ || absYMax_ <= absYMin_) {
        lastOpenError_ = QStringLiteral("Invalid axis ranges on %1 — X: %2-%3 Y: %4-%5")
                             .arg(path)
                             .arg(absXMin_)
                             .arg(absXMax_)
                             .arg(absYMin_)
                             .arg(absYMax_);
        ::close(fd_);
        fd_ = -1;
        return false;
    }

    // Grab only after the selected node's capabilities and ranges have been
    // validated. Failure leaves compositor input intact as a safe fallback.
    const bool grabFailed = ::ioctl(fd_, EVIOCGRAB, 1) < 0;

    devicePath_ = path;
    lastDevicePath_ = path;
    notifier_ = new QSocketNotifier(fd_, QSocketNotifier::Read, this);
    connect(notifier_, &QSocketNotifier::activated, this, &EvdevTouchService::onReadReady);

    disableUsbAutosuspend();

    if (grabFailed) {
        qWarning() << "[EvdevTouchService] EVIOCGRAB failed on" << path
                   << "— continuing without exclusive grab";
    }

    emit activeChanged();
    emit devicePathChanged();
    return true;
}

void EvdevTouchService::stop()
{
    runningRequested_ = false;
    reconnectTimer_->stop();
    closeDevice();
    retryState_.reset();
}

void EvdevTouchService::closeDevice()
{
    if (fd_ < 0)
        return;

    const bool wasActive = !devicePath_.isEmpty();
    const TouchUpdate cancelled = cancelInput(inputState_);
    if (cancelled.action == TouchAction::Release && window_) {
        const QPointF normalized = normalizedPosition(cancelled);
        const QPointF lastPos(normalized.x() * window_->width(),
                              normalized.y() * window_->height());
        QMouseEvent release(QEvent::MouseButtonRelease, lastPos, window_->mapToGlobal(lastPos),
                            Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(window_, &release);
    }
    delete notifier_;
    notifier_ = nullptr;

    ::ioctl(fd_, EVIOCGRAB, 0);
    ::close(fd_);
    fd_ = -1;
    devicePath_.clear();
    if (wasActive) {
        emit activeChanged();
        emit devicePathChanged();
    }
}

void EvdevTouchService::handleReconnectFailure()
{
    const int retryDelayMs = retryState_.recordFailure();
    if (retryState_.shouldLogUnavailable()) {
        qWarning().noquote()
            << "[EvdevTouchService]" << lastOpenError_
            << "— touch falls back to the compositor; reconnecting with backoff from"
            << retryDelayMs / 1000 << "s to 60s";
    }
    scheduleReconnect(retryDelayMs);
}

void EvdevTouchService::loadCalibrationProfile()
{
    calibrationTransform_ = TouchAffineTransform::identity();
    hasCalibrationProfile_ = false;
    if (!selectedIdentity_.isValid() || calibrationStoragePath_.isEmpty())
        return;

    const QString stableIdentity = deviceIdentity();
    QString error;
    const TouchCalibrationStore store(calibrationStoragePath_);
    hasCalibrationProfile_ = store.hasProfile(stableIdentity, &error);
    if (error.isEmpty() && hasCalibrationProfile_)
        calibrationTransform_ = store.profileFor(stableIdentity, &error);
    if (!error.isEmpty()) {
        hasCalibrationProfile_ = false;
        qWarning().noquote()
            << "[EvdevTouchService] Ignoring touchscreen calibration settings:"
            << error << "— using identity transform";
    }
    emit calibrationChanged();
}

void EvdevTouchService::logOpened(bool recovered) const
{
    qInfo() << (recovered ? "[EvdevTouchService] Touchscreen recovered on"
                         : "[EvdevTouchService] Opened")
            << devicePath_
            << "X range:" << absXMin_ << "-" << absXMax_
            << "Y range:" << absYMin_ << "-" << absYMax_;
}

void EvdevTouchService::scheduleReconnect(int delayMs)
{
    if (!runningRequested_)
        return;

    const int remainingMs = reconnectTimer_->remainingTime();
    if (!reconnectTimer_->isActive() || remainingMs < 0 || delayMs < remainingMs)
        reconnectTimer_->start(delayMs);
}

void EvdevTouchService::reconnect()
{
    if (!runningRequested_)
        return;

    // Close without resetting retry state or the remembered path.
    closeDevice();
    if (!runningRequested_ || fd_ >= 0)
        return;

    lastOpenError_.clear();

    // Rediscover by stable identity instead of trusting the old event path,
    // which may now refer to a different interface after re-enumeration.
    const QString recoveredPath = attemptReconnectCycle(
        lastDevicePath_,
        [this]() { return detectDevice(); },
        [this](const QString &path) { return openDevice(path); });
    if (recoveredPath.isEmpty()) {
        lastDevicePath_.clear();
        if (lastOpenError_.isEmpty())
            lastOpenError_ = QStringLiteral("No touchscreen device found");
        handleReconnectFailure();
        return;
    }

    reconnectTimer_->stop();
    loadCalibrationProfile();
    logOpened(retryState_.markRecovered());
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
            if (retryState_.shouldLogUnavailable()) {
                qWarning() << "[EvdevTouchService] Touchscreen read error (errno:" << errno
                           << ") — touch falls back to the compositor while reconnecting";
            }
            // A dead evdev fd remains readable and would continuously retrigger the
            // notifier until reconnect() closes it.
            if (notifier_)
                notifier_->setEnabled(false);
            // Send a release if we had a press in flight
            if (inputState_.pressed && window_) {
                const TouchUpdate releaseUpdate{TouchAction::Release, inputState_.x, inputState_.y};
                const QPointF normalized = normalizedPosition(releaseUpdate);
                const QPointF lastPos(normalized.x() * window_->width(),
                                      normalized.y() * window_->height());
                QMouseEvent release(QEvent::MouseButtonRelease, lastPos, window_->mapToGlobal(lastPos),
                                    Qt::LeftButton, Qt::NoButton, Qt::NoModifier);
                QCoreApplication::sendEvent(window_, &release);
            }
            inputState_ = {};
            scheduleReconnect(1000);
            return;
        }

        const TouchUpdate update = processInputEvent(inputState_, ev.type, ev.code, ev.value);
        dispatchTouchUpdate(update);

        if (update.reconnect) {
            closeDevice();
            scheduleReconnect(1000);
            return;
        }
    }
}

void EvdevTouchService::onSystemWake(bool suspending)
{
    if (suspending || !runningRequested_)
        return;

    // System just woke up. The USB device likely reset, so the fd is stale
    // even if no read error occurred. Force a reconnect after a short delay
    // to give the USB subsystem time to re-enumerate.
    qInfo() << "[EvdevTouchService] System wake detected — reconnecting in 2s";
    retryState_.markUnavailable();
    scheduleReconnect(2000);
}

} // namespace ciderdeck
