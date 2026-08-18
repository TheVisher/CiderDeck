#pragma once

#include <QList>
#include <QObject>
#include <QPointF>
#include <QString>

#include "models/TouchCalibration.h"

namespace ciderdeck {

class TouchCalibrationDevice {
public:
    virtual ~TouchCalibrationDevice() = default;

    virtual bool isAvailable() const = 0;
    virtual QString deviceName() const = 0;
    virtual QString devicePath() const = 0;
    virtual QString deviceIdentity() const = 0;
    virtual QString statusText() const = 0;
    virtual bool hasCalibration() const = 0;
    virtual TouchAffineTransform currentCalibration() const = 0;
    virtual void useCalibration(const TouchAffineTransform &transform) = 0;
    virtual bool saveCalibration(const TouchAffineTransform &transform, QString *error) = 0;
    virtual bool resetCalibration(QString *error) = 0;
    virtual void setCalibrationCaptureActive(bool active) = 0;
};

class TouchCalibrationService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(QString stageName READ stageName NOTIFY stateChanged)
    Q_PROPERTY(int currentPoint READ currentPoint NOTIFY stateChanged)
    Q_PROPERTY(int acknowledgedPointCount READ acknowledgedPointCount NOTIFY stateChanged)
    Q_PROPERTY(QPointF targetPoint READ targetPoint NOTIFY stateChanged)
    Q_PROPERTY(int contactSampleCount READ contactSampleCount NOTIFY stateChanged)
    Q_PROPERTY(QPointF lastAcceptedInputPoint READ lastAcceptedInputPoint NOTIFY stateChanged)
    Q_PROPERTY(QPointF previewPosition READ previewPosition NOTIFY stateChanged)
    Q_PROPERTY(bool canApply READ canApply NOTIFY stateChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY stateChanged)
    Q_PROPERTY(bool deviceAvailable READ deviceAvailable NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceChanged)
    Q_PROPERTY(QString devicePath READ devicePath NOTIFY deviceChanged)
    Q_PROPERTY(QString deviceIdentity READ deviceIdentity NOTIFY deviceChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY deviceChanged)
    Q_PROPERTY(bool hasCalibration READ hasCalibration NOTIFY deviceChanged)

public:
    explicit TouchCalibrationService(TouchCalibrationDevice *device, QObject *parent = nullptr);

    bool active() const { return stage_ != Stage::Idle; }
    QString stageName() const;
    int currentPoint() const { return currentPoint_; }
    int acknowledgedPointCount() const { return samples_.size(); }
    QPointF targetPoint() const;
    int contactSampleCount() const { return contactSamples_.size(); }
    QPointF lastAcceptedInputPoint() const { return lastAcceptedInputPoint_; }
    QPointF previewPosition() const { return previewPosition_; }
    bool canApply() const { return stage_ == Stage::Preview; }
    QString errorMessage() const { return errorMessage_; }
    bool deviceAvailable() const { return device_ && device_->isAvailable(); }
    QString deviceName() const { return device_ ? device_->deviceName() : QString(); }
    QString devicePath() const { return device_ ? device_->devicePath() : QString(); }
    QString deviceIdentity() const { return device_ ? device_->deviceIdentity() : QString(); }
    QString statusText() const { return device_ ? device_->statusText() : QString(); }
    bool hasCalibration() const { return device_ && device_->hasCalibration(); }

    Q_INVOKABLE bool start();
    Q_INVOKABLE void touchPressed(const QPointF &point);
    Q_INVOKABLE void touchMoved(const QPointF &point);
    Q_INVOKABLE void touchReleased(const QPointF &point);
    Q_INVOKABLE void retry();
    Q_INVOKABLE bool apply();
    Q_INVOKABLE void cancel();
    Q_INVOKABLE bool reset();
    Q_INVOKABLE void refreshDeviceStatus() { emit deviceChanged(); }

signals:
    void stateChanged();
    void deviceChanged();
    void pointAccepted(int index, const QPointF &target);

private:
    enum class Stage {
        Idle,
        Collecting,
        Preview,
        Error,
    };

    void appendContactSample(const QPointF &point);
    void finishContact();

    static constexpr int maximumContactSamples_ = 12;
    TouchCalibrationDevice *device_ = nullptr;
    Stage stage_ = Stage::Idle;
    int currentPoint_ = 0;
    QList<QPointF> contactSamples_;
    QList<TouchCalibrationSample> samples_;
    QPointF lastAcceptedInputPoint_;
    QPointF previewPosition_;
    TouchAffineTransform originalTransform_;
    TouchAffineTransform pendingTransform_;
    QString errorMessage_;
};

} // namespace ciderdeck
