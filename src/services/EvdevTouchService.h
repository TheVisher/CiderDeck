#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <QHash>

#include <functional>

#include "models/TouchCalibration.h"

class QWindow;
class QSocketNotifier;
class QTimer;

namespace ciderdeck {

class EvdevTouchServiceTests;

class EvdevTouchService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(QString devicePath READ devicePath NOTIFY devicePathChanged)

public:
    explicit EvdevTouchService(QWindow *window, QObject *parent = nullptr);
    ~EvdevTouchService() override;

    bool active() const { return fd_ >= 0; }
    QString devicePath() const { return devicePath_; }

    Q_INVOKABLE bool start(const QString &devicePath = {});
    Q_INVOKABLE void stop();

signals:
    void activeChanged();
    void devicePathChanged();

private slots:
    void onSystemWake(bool suspending);

private:
    friend class EvdevTouchServiceTests;

    enum class DeviceProbeResult {
        Unavailable,
        NotTouchscreen,
        Touchscreen,
        PermissionDenied,
    };

    struct DeviceIdentity {
        quint16 busType = 0;
        quint16 vendor = 0;
        quint16 product = 0;
        quint16 version = 0;
        QString name;
        QString physical;

        bool isValid() const;
        bool operator==(const DeviceIdentity &other) const = default;
    };

    struct DeviceCandidate {
        QString path;
        DeviceIdentity identity;
        bool direct = false;
        bool hasAbsX = false;
        bool hasAbsY = false;
        bool hasMtX = false;
        bool hasMtY = false;
        bool hasBtnTouch = false;
        bool hasMtTrackingId = false;
        bool hasRelX = false;
        bool hasRelY = false;
    };

    struct ProbedDevice {
        ProbedDevice() = default;
        ProbedDevice(DeviceProbeResult value) : result(value) {}

        DeviceProbeResult result = DeviceProbeResult::Unavailable;
        DeviceCandidate candidate;
    };

    enum class TouchAction {
        None,
        Press,
        Move,
        Release,
    };

    struct TouchUpdate {
        TouchAction action = TouchAction::None;
        int x = 0;
        int y = 0;
        bool reconnect = false;
    };

    struct MtContact {
        int trackingId = -1;
        int x = 0;
        int y = 0;
    };

    struct InputState {
        QHash<int, MtContact> contacts;
        int currentSlot = 0;
        int activeSlot = -1;
        int x = 0;
        int y = 0;
        bool mtSeen = false;
        bool buttonDown = false;
        bool pressed = false;
        bool dropping = false;
    };

    struct RetryState {
        int recordFailure();
        bool shouldLogUnavailable();
        void markUnavailable();
        bool markRecovered();
        void reset();

        int failureCount = 0;
        bool unavailable = false;
        bool unavailableLogEmitted = false;
    };

    static QStringList eventDevicePaths(const QString &inputDirectory);
    static QString attemptReconnectCycle(
        const QString &rememberedPath,
        const std::function<QString()> &detectDevice,
        const std::function<bool(const QString &)> &openDevice);
    static QString permissionDeniedError(const QString &path);
    static ProbedDevice probeDevice(const QString &path);
    static DeviceProbeResult probeResultForOpenError(int errorNumber);
    static int candidateScore(const DeviceCandidate &candidate);
    static DeviceCandidate selectBestCandidate(const QList<DeviceCandidate> &candidates);
    static DeviceCandidate selectBestCandidate(
        const QList<DeviceCandidate> &candidates,
        const DeviceIdentity &requiredIdentity);
    static TouchUpdate processInputEvent(
        InputState &state, quint16 type, quint16 code, qint32 value);
    static TouchUpdate cancelInput(InputState &state);
    QPointF normalizedPosition(const TouchUpdate &update) const;
    QString detectDevice();
    bool openDevice(const QString &path);
    void closeDevice();
    void handleReconnectFailure();
    void loadCalibrationProfile();
    void logOpened(bool recovered) const;
    void scheduleReconnect(int delayMs);
    void onReadReady();
    void reconnect();
    void disableUsbAutosuspend();

    QWindow *window_ = nullptr;
    int fd_ = -1;
    QSocketNotifier *notifier_ = nullptr;
    QTimer *reconnectTimer_ = nullptr;
    QString devicePath_;
    QString lastDevicePath_; // remembered across reconnects
    QString lastOpenError_;
    RetryState retryState_;
    bool runningRequested_ = false;
    QString inputDirectory_ = QStringLiteral("/dev/input");
    std::function<ProbedDevice(const QString &)> deviceProbe_;
    DeviceIdentity selectedIdentity_;
    DeviceCandidate selectedCandidate_;
    QString calibrationStoragePath_;

    // Axis ranges from EVIOCGABS
    int absXMin_ = 0;
    int absXMax_ = 1;
    int absYMin_ = 0;
    int absYMax_ = 1;

    TouchAffineTransform calibrationTransform_;

    InputState inputState_;
};

} // namespace ciderdeck
