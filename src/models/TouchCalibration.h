#pragma once

#include <QList>
#include <QPointF>
#include <QString>

#include <array>
#include <optional>

namespace ciderdeck {

struct TouchCalibrationSample {
    QPointF input;
    QPointF target;
};

class TouchAffineTransform;

QPointF mapEvdevToNormalized(int x, int y,
                             int xMinimum, int xMaximum,
                             int yMinimum, int yMaximum,
                             const TouchAffineTransform &transform);

QString stableTouchscreenIdentity(quint16 busType, quint16 vendor, quint16 product,
                                  quint16 version, const QString &name,
                                  const QString &physicalPath);

class TouchAffineTransform {
public:
    TouchAffineTransform();
    explicit TouchAffineTransform(const std::array<double, 6> &coefficients);

    static TouchAffineTransform identity();
    static TouchAffineTransform rotation(int clockwiseDegrees);
    static TouchAffineTransform flipped(bool horizontal, bool vertical);
    static std::optional<TouchAffineTransform> fit(
        const QList<TouchCalibrationSample> &samples, double maximumRmsError,
        QString *error = nullptr);

    QPointF map(const QPointF &normalizedPoint) const;
    TouchAffineTransform then(const TouchAffineTransform &after) const;
    bool isValid() const;
    const std::array<double, 6> &coefficients() const { return coefficients_; }

private:
    std::array<double, 6> coefficients_;
};

class TouchCalibrationStore {
public:
    explicit TouchCalibrationStore(QString storagePath);

    TouchAffineTransform profileFor(const QString &stableDeviceIdentity,
                                    QString *error = nullptr) const;
    bool hasProfile(const QString &stableDeviceIdentity, QString *error = nullptr) const;
    bool saveProfile(const QString &stableDeviceIdentity,
                     const TouchAffineTransform &transform, QString *error = nullptr) const;
    bool removeProfile(const QString &stableDeviceIdentity, QString *error = nullptr) const;

private:
    QString storagePath_;
};

} // namespace ciderdeck
