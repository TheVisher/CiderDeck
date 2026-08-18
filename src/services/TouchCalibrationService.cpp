#include "TouchCalibrationService.h"

#include <algorithm>
#include <cmath>

namespace ciderdeck {

namespace {

const QList<QPointF> &calibrationTargets()
{
    static const QList<QPointF> targets{
        {0.1, 0.1}, {0.9, 0.1}, {0.9, 0.9}, {0.1, 0.9}, {0.5, 0.5},
    };
    return targets;
}

} // namespace

TouchCalibrationService::TouchCalibrationService(TouchCalibrationDevice *device, QObject *parent)
    : QObject(parent)
    , device_(device)
{
}

QString TouchCalibrationService::stageName() const
{
    switch (stage_) {
    case Stage::Collecting:
        return QStringLiteral("collecting");
    case Stage::Preview:
        return QStringLiteral("preview");
    case Stage::Error:
        return QStringLiteral("error");
    case Stage::Idle:
        return QStringLiteral("idle");
    }
    return QStringLiteral("idle");
}

QPointF TouchCalibrationService::targetPoint() const
{
    return currentPoint_ >= 0 && currentPoint_ < calibrationTargets().size()
        ? calibrationTargets().at(currentPoint_) : QPointF(0.5, 0.5);
}

bool TouchCalibrationService::start()
{
    if (!device_ || !device_->isAvailable() || device_->deviceIdentity().isEmpty())
        return false;

    stage_ = Stage::Collecting;
    device_->setCalibrationCaptureActive(true);
    originalTransform_ = device_->currentCalibration();
    currentPoint_ = 0;
    contactSamples_.clear();
    samples_.clear();
    lastAcceptedInputPoint_ = {};
    previewPosition_ = {};
    errorMessage_.clear();
    emit stateChanged();
    return true;
}

void TouchCalibrationService::touchPressed(const QPointF &point)
{
    if (stage_ == Stage::Preview) {
        previewPosition_ = pendingTransform_.map(point);
        emit stateChanged();
        return;
    }
    if (stage_ != Stage::Collecting)
        return;

    contactSamples_.clear();
    appendContactSample(point);
    emit stateChanged();
}

void TouchCalibrationService::touchMoved(const QPointF &point)
{
    if (stage_ == Stage::Preview) {
        previewPosition_ = pendingTransform_.map(point);
        emit stateChanged();
        return;
    }
    if (stage_ != Stage::Collecting || contactSamples_.isEmpty())
        return;

    appendContactSample(point);
    emit stateChanged();
}

void TouchCalibrationService::touchReleased(const QPointF &point)
{
    if (stage_ == Stage::Preview) {
        previewPosition_ = pendingTransform_.map(point);
        emit stateChanged();
        return;
    }
    if (stage_ != Stage::Collecting || contactSamples_.isEmpty())
        return;

    appendContactSample(point);
    finishContact();
}

void TouchCalibrationService::cancel()
{
    if (stage_ == Stage::Idle)
        return;

    device_->useCalibration(originalTransform_);
    device_->setCalibrationCaptureActive(false);
    stage_ = Stage::Idle;
    currentPoint_ = 0;
    contactSamples_.clear();
    samples_.clear();
    errorMessage_.clear();
    emit stateChanged();
}

void TouchCalibrationService::retry()
{
    if (stage_ == Stage::Error) {
        device_->useCalibration(originalTransform_);
        stage_ = Stage::Collecting;
        currentPoint_ = 0;
        contactSamples_.clear();
        samples_.clear();
        lastAcceptedInputPoint_ = {};
        errorMessage_.clear();
        emit stateChanged();
        return;
    }
    if (stage_ != Stage::Collecting || samples_.isEmpty())
        return;

    samples_.removeLast();
    currentPoint_ = samples_.size();
    contactSamples_.clear();
    lastAcceptedInputPoint_ = samples_.isEmpty() ? QPointF() : samples_.constLast().input;
    emit stateChanged();
}

bool TouchCalibrationService::apply()
{
    if (stage_ != Stage::Preview)
        return false;

    QString error;
    if (!device_->saveCalibration(pendingTransform_, &error)) {
        errorMessage_ = error.isEmpty() ? QStringLiteral("Could not save touchscreen calibration")
                                        : error;
        emit stateChanged();
        return false;
    }

    device_->setCalibrationCaptureActive(false);
    stage_ = Stage::Idle;
    currentPoint_ = 0;
    contactSamples_.clear();
    samples_.clear();
    errorMessage_.clear();
    emit stateChanged();
    emit deviceChanged();
    return true;
}

bool TouchCalibrationService::reset()
{
    if (!device_)
        return false;
    if (stage_ != Stage::Idle)
        cancel();

    QString error;
    if (!device_->resetCalibration(&error)) {
        errorMessage_ = error.isEmpty() ? QStringLiteral("Could not reset touchscreen calibration")
                                        : error;
        emit stateChanged();
        return false;
    }

    errorMessage_.clear();
    emit stateChanged();
    emit deviceChanged();
    return true;
}

void TouchCalibrationService::appendContactSample(const QPointF &point)
{
    if (!std::isfinite(point.x()) || !std::isfinite(point.y()))
        return;

    if (contactSamples_.size() == maximumContactSamples_)
        contactSamples_.removeFirst();
    contactSamples_.append(QPointF(std::clamp(point.x(), 0.0, 1.0),
                                   std::clamp(point.y(), 0.0, 1.0)));
}

void TouchCalibrationService::finishContact()
{
    if (contactSamples_.isEmpty())
        return;

    QPointF average;
    for (const QPointF &point : std::as_const(contactSamples_))
        average += point;
    average /= contactSamples_.size();
    lastAcceptedInputPoint_ = average;

    const QPointF acceptedTarget = calibrationTargets().at(currentPoint_);
    samples_.append({average, acceptedTarget});
    const int acceptedIndex = currentPoint_;
    ++currentPoint_;
    contactSamples_.clear();
    emit pointAccepted(acceptedIndex, acceptedTarget);

    if (currentPoint_ == calibrationTargets().size()) {
        QString error;
        const auto fitted = TouchAffineTransform::fit(samples_, 0.04, &error);
        if (fitted) {
            pendingTransform_ = *fitted;
            device_->useCalibration(pendingTransform_);
            stage_ = Stage::Preview;
            errorMessage_.clear();
        } else {
            stage_ = Stage::Error;
            errorMessage_ = error;
        }
    }
    emit stateChanged();
}

} // namespace ciderdeck
