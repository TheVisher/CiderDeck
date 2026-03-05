#pragma once

#include <QObject>
#include <QString>

class QWindow;
class QSocketNotifier;
class QTimer;

namespace ciderdeck {

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

private:
    QString detectDevice();
    void onReadReady();
    void reconnect();
    void disableUsbAutosuspend();

    QWindow *window_ = nullptr;
    int fd_ = -1;
    QSocketNotifier *notifier_ = nullptr;
    QTimer *reconnectTimer_ = nullptr;
    QString devicePath_;
    QString lastDevicePath_; // remembered across reconnects

    // Axis ranges from EVIOCGABS
    int absXMin_ = 0;
    int absXMax_ = 1;
    int absYMin_ = 0;
    int absYMax_ = 1;

    // Current touch state
    bool touchDown_ = false;
    bool pressed_ = false;
    int currentX_ = 0;
    int currentY_ = 0;
};

} // namespace ciderdeck
