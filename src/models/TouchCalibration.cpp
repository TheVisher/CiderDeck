#include "TouchCalibration.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QSaveFile>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>

namespace {

// Five-point touchscreen calibration is expected to cover most of both normalized
// screen axes. Requiring 5% RMS spread in the least-covered centered direction
// still allows substantial tap error while rejecting samples that effectively lie
// on one line and would amplify tiny input motion into full-screen output motion.
constexpr double kMinimumDirectionalSpread = 0.05;

// A full-screen calibration should be close to unit scale. Allowing up to 2x
// singular-value gain accommodates generous normalized range correction, while
// preventing a small input displacement from becoming unsafe large screen motion.
constexpr double kMaximumLinearAmplification = 2.0;

double floatingComparisonTolerance(double left, double right)
{
    // The covariance, eigensystem, and normal-equation paths each perform a small,
    // fixed number of rounded operations. Bound their accumulated comparison noise
    // in machine-epsilon units while scaling with the values being compared.
    constexpr double operationAllowance = 64.0;
    return operationAllowance * std::numeric_limits<double>::epsilon()
        * std::max(std::abs(left), std::abs(right));
}

bool solve3x3(double matrix[3][3], double values[3], double result[3])
{
    for (int column = 0; column < 3; ++column) {
        int pivot = column;
        for (int row = column + 1; row < 3; ++row) {
            if (std::abs(matrix[row][column]) > std::abs(matrix[pivot][column]))
                pivot = row;
        }
        if (matrix[pivot][column] == 0.0)
            return false;
        for (int entry = column; entry < 3; ++entry)
            std::swap(matrix[column][entry], matrix[pivot][entry]);
        std::swap(values[column], values[pivot]);
        for (int row = column + 1; row < 3; ++row) {
            const double factor = matrix[row][column] / matrix[column][column];
            for (int entry = column; entry < 3; ++entry)
                matrix[row][entry] -= factor * matrix[column][entry];
            values[row] -= factor * values[column];
        }
    }
    for (int row = 2; row >= 0; --row) {
        double value = values[row];
        for (int column = row + 1; column < 3; ++column)
            value -= matrix[row][column] * result[column];
        result[row] = value / matrix[row][row];
    }
    return true;
}

double minimumCenteredDirectionalSpread(const QList<ciderdeck::TouchCalibrationSample> &samples)
{
    double meanX = 0.0;
    double meanY = 0.0;
    for (const ciderdeck::TouchCalibrationSample &sample : samples) {
        meanX += sample.input.x();
        meanY += sample.input.y();
    }
    meanX /= samples.size();
    meanY /= samples.size();

    double covarianceXX = 0.0;
    double covarianceXY = 0.0;
    double covarianceYY = 0.0;
    for (const ciderdeck::TouchCalibrationSample &sample : samples) {
        const double centeredX = sample.input.x() - meanX;
        const double centeredY = sample.input.y() - meanY;
        covarianceXX += centeredX * centeredX;
        covarianceXY += centeredX * centeredY;
        covarianceYY += centeredY * centeredY;
    }
    covarianceXX /= samples.size();
    covarianceXY /= samples.size();
    covarianceYY /= samples.size();

    const double smallestEigenvalue = 0.5 * (covarianceXX + covarianceYY
        - std::hypot(covarianceXX - covarianceYY, 2.0 * covarianceXY));
    return std::sqrt(std::max(0.0, smallestEigenvalue));
}

double maximumLinearAmplification(const double x[3], const double y[3])
{
    const double gramXX = x[0] * x[0] + y[0] * y[0];
    const double gramXY = x[0] * x[1] + y[0] * y[1];
    const double gramYY = x[1] * x[1] + y[1] * y[1];
    if (!std::isfinite(gramXX) || !std::isfinite(gramXY) || !std::isfinite(gramYY))
        return std::numeric_limits<double>::infinity();

    const double largestEigenvalue = 0.5 * (gramXX + gramYY
        + std::hypot(gramXX - gramYY, 2.0 * gramXY));
    return std::sqrt(largestEigenvalue);
}

} // namespace

namespace ciderdeck {

QPointF mapEvdevToNormalized(int x, int y,
                             int xMinimum, int xMaximum,
                             int yMinimum, int yMaximum,
                             const TouchAffineTransform &transform)
{
    if (xMaximum <= xMinimum || yMaximum <= yMinimum)
        return QPointF();

    const std::int64_t xRange = static_cast<std::int64_t>(xMaximum)
        - static_cast<std::int64_t>(xMinimum);
    const std::int64_t yRange = static_cast<std::int64_t>(yMaximum)
        - static_cast<std::int64_t>(yMinimum);
    const QPointF normalized(
        static_cast<double>(static_cast<std::int64_t>(x) - static_cast<std::int64_t>(xMinimum))
            / static_cast<double>(xRange),
        static_cast<double>(static_cast<std::int64_t>(y) - static_cast<std::int64_t>(yMinimum))
            / static_cast<double>(yRange));
    return transform.map(normalized);
}

QString stableTouchscreenIdentity(quint16 busType, quint16 vendor, quint16 product,
                                  quint16 version, const QString &name,
                                  const QString &physicalPath)
{
    QByteArray identity;
    auto appendField = [&identity](const QByteArray &field) {
        identity.append(QByteArray::number(field.size()));
        identity.append(':');
        identity.append(field);
        identity.append(';');
    };
    appendField(QByteArray::number(busType));
    appendField(QByteArray::number(vendor));
    appendField(QByteArray::number(product));
    appendField(QByteArray::number(version));
    appendField(name.toUtf8());
    appendField(physicalPath.toUtf8());
    return QStringLiteral("evdev-v1:")
        + QString::fromLatin1(QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex());
}

TouchAffineTransform::TouchAffineTransform()
    : coefficients_{1.0, 0.0, 0.0, 0.0, 1.0, 0.0}
{
}

TouchAffineTransform::TouchAffineTransform(const std::array<double, 6> &coefficients)
    : coefficients_(coefficients)
{
}

TouchAffineTransform TouchAffineTransform::identity()
{
    return TouchAffineTransform();
}

TouchAffineTransform TouchAffineTransform::rotation(int clockwiseDegrees)
{
    switch ((clockwiseDegrees % 360 + 360) % 360) {
    case 90:
        return TouchAffineTransform({0.0, -1.0, 1.0, 1.0, 0.0, 0.0});
    case 180:
        return TouchAffineTransform({-1.0, 0.0, 1.0, 0.0, -1.0, 1.0});
    case 270:
        return TouchAffineTransform({0.0, 1.0, 0.0, -1.0, 0.0, 1.0});
    default:
        return identity();
    }
}

TouchAffineTransform TouchAffineTransform::flipped(bool horizontal, bool vertical)
{
    return TouchAffineTransform({horizontal ? -1.0 : 1.0, 0.0, horizontal ? 1.0 : 0.0,
                                 0.0, vertical ? -1.0 : 1.0, vertical ? 1.0 : 0.0});
}

TouchAffineTransform TouchAffineTransform::then(const TouchAffineTransform &after) const
{
    const auto &a = coefficients_;
    const auto &b = after.coefficients_;
    return TouchAffineTransform({
        b[0] * a[0] + b[1] * a[3], b[0] * a[1] + b[1] * a[4],
        b[0] * a[2] + b[1] * a[5] + b[2], b[3] * a[0] + b[4] * a[3],
        b[3] * a[1] + b[4] * a[4], b[3] * a[2] + b[4] * a[5] + b[5],
    });
}

std::optional<TouchAffineTransform> TouchAffineTransform::fit(
    const QList<TouchCalibrationSample> &samples, double maximumRmsError, QString *error)
{
    if (samples.size() < 3 || !std::isfinite(maximumRmsError) || maximumRmsError < 0.0) {
        if (error)
            *error = QStringLiteral("At least three finite samples and a valid error limit are required");
        return std::nullopt;
    }

    double normal[3][3]{};
    double targetX[3]{};
    double targetY[3]{};
    for (const TouchCalibrationSample &sample : samples) {
        const double row[3]{sample.input.x(), sample.input.y(), 1.0};
        if (!std::isfinite(row[0]) || !std::isfinite(row[1])
            || !std::isfinite(sample.target.x()) || !std::isfinite(sample.target.y())) {
            if (error)
                *error = QStringLiteral("Calibration samples must be finite");
            return std::nullopt;
        }
        for (int i = 0; i < 3; ++i) {
            targetX[i] += row[i] * sample.target.x();
            targetY[i] += row[i] * sample.target.y();
            for (int j = 0; j < 3; ++j)
                normal[i][j] += row[i] * row[j];
        }
    }

    const double directionalSpread = minimumCenteredDirectionalSpread(samples);
    const double directionalSpreadTolerance = floatingComparisonTolerance(
        directionalSpread, kMinimumDirectionalSpread);
    if (!std::isfinite(directionalSpread) || !std::isfinite(directionalSpreadTolerance)
        || directionalSpread < kMinimumDirectionalSpread - directionalSpreadTolerance) {
        if (error)
            *error = QStringLiteral("Calibration input geometry lacks independent directional spread");
        return std::nullopt;
    }

    double normalY[3][3];
    std::copy(&normal[0][0], &normal[0][0] + 9, &normalY[0][0]);
    double x[3]{};
    double y[3]{};
    if (!solve3x3(normal, targetX, x) || !solve3x3(normalY, targetY, y)) {
        if (error)
            *error = QStringLiteral("Calibration samples are degenerate");
        return std::nullopt;
    }

    const TouchAffineTransform transform({x[0], x[1], x[2], y[0], y[1], y[2]});
    if (!transform.isValid()) {
        if (error)
            *error = QStringLiteral("Calibration fit produced non-finite coefficients");
        return std::nullopt;
    }
    const double amplification = maximumLinearAmplification(x, y);
    const double amplificationTolerance = floatingComparisonTolerance(
        amplification, kMaximumLinearAmplification);
    if (!std::isfinite(amplification) || !std::isfinite(amplificationTolerance)
        || amplification > kMaximumLinearAmplification + amplificationTolerance) {
        if (error)
            *error = QStringLiteral("Calibration transform amplification exceeds safe limit");
        return std::nullopt;
    }

    double squaredError = 0.0;
    for (const TouchCalibrationSample &sample : samples) {
        const double mappedX = x[0] * sample.input.x() + x[1] * sample.input.y() + x[2];
        const double mappedY = y[0] * sample.input.x() + y[1] * sample.input.y() + y[2];
        squaredError += std::pow(mappedX - sample.target.x(), 2)
            + std::pow(mappedY - sample.target.y(), 2);
    }
    const double rmsError = std::sqrt(squaredError / samples.size());
    if (rmsError > maximumRmsError) {
        if (error)
            *error = QStringLiteral("Calibration fit error %1 exceeds limit %2")
                         .arg(rmsError).arg(maximumRmsError);
        return std::nullopt;
    }
    if (error)
        error->clear();
    return transform;
}

QPointF TouchAffineTransform::map(const QPointF &normalizedPoint) const
{
    if (!isValid())
        return QPointF(std::clamp(normalizedPoint.x(), 0.0, 1.0),
                       std::clamp(normalizedPoint.y(), 0.0, 1.0));

    const double x = coefficients_[0] * normalizedPoint.x()
        + coefficients_[1] * normalizedPoint.y() + coefficients_[2];
    const double y = coefficients_[3] * normalizedPoint.x()
        + coefficients_[4] * normalizedPoint.y() + coefficients_[5];
    return QPointF(std::clamp(x, 0.0, 1.0), std::clamp(y, 0.0, 1.0));
}

bool TouchAffineTransform::isValid() const
{
    return std::all_of(coefficients_.cbegin(), coefficients_.cend(),
                       [](double coefficient) { return std::isfinite(coefficient); });
}

TouchCalibrationStore::TouchCalibrationStore(QString storagePath)
    : storagePath_(std::move(storagePath))
{
}

namespace {

bool readProfiles(const QString &path, QMap<QString, TouchAffineTransform> *profiles, QString *error)
{
    QFile file(path);
    if (!file.exists()) {
        if (error)
            error->clear();
        return true;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &parseError);
    const QJsonObject root = document.object();
    if (parseError.error != QJsonParseError::NoError || !document.isObject()
        || root.value(QStringLiteral("version")).toInt(-1) != 1
        || !root.value(QStringLiteral("profiles")).isArray()) {
        if (error)
            *error = QStringLiteral("Unsupported or malformed touchscreen calibration settings");
        return false;
    }
    for (const QJsonValue &value : root.value(QStringLiteral("profiles")).toArray()) {
        const QJsonObject profile = value.toObject();
        const QString identity = profile.value(QStringLiteral("deviceId")).toString();
        const QJsonArray values = profile.value(QStringLiteral("coefficients")).toArray();
        if (identity.isEmpty() || values.size() != 6) {
            if (error)
                *error = QStringLiteral("Malformed touchscreen calibration profile");
            return false;
        }
        std::array<double, 6> coefficients{};
        for (int i = 0; i < 6; ++i) {
            if (!values.at(i).isDouble()) {
                if (error)
                    *error = QStringLiteral("Malformed touchscreen calibration coefficients");
                return false;
            }
            coefficients[i] = values.at(i).toDouble();
        }
        TouchAffineTransform transform(coefficients);
        if (!transform.isValid()) {
            if (error)
                *error = QStringLiteral("Non-finite touchscreen calibration coefficients");
            return false;
        }
        profiles->insert(identity, transform);
    }
    if (error)
        error->clear();
    return true;
}

} // namespace

TouchAffineTransform TouchCalibrationStore::profileFor(
    const QString &stableDeviceIdentity, QString *error) const
{
    QMap<QString, TouchAffineTransform> profiles;
    if (!readProfiles(storagePath_, &profiles, error))
        return TouchAffineTransform::identity();
    return profiles.value(stableDeviceIdentity, TouchAffineTransform::identity());
}

bool TouchCalibrationStore::saveProfile(const QString &stableDeviceIdentity,
                                        const TouchAffineTransform &transform, QString *error) const
{
    if (stableDeviceIdentity.isEmpty() || !transform.isValid()) {
        if (error)
            *error = QStringLiteral("A stable device identity and finite coefficients are required");
        return false;
    }
    QMap<QString, TouchAffineTransform> profiles;
    if (!readProfiles(storagePath_, &profiles, error))
        return false;
    profiles.insert(stableDeviceIdentity, transform);

    QJsonArray serializedProfiles;
    for (auto it = profiles.cbegin(); it != profiles.cend(); ++it) {
        QJsonArray coefficients;
        for (double coefficient : it.value().coefficients())
            coefficients.append(coefficient);
        serializedProfiles.append(QJsonObject{
            {QStringLiteral("deviceId"), it.key()},
            {QStringLiteral("coefficients"), coefficients},
        });
    }
    const QJsonDocument document(QJsonObject{
        {QStringLiteral("version"), 1},
        {QStringLiteral("profiles"), serializedProfiles},
    });
    if (!QDir().mkpath(QFileInfo(storagePath_).absolutePath())) {
        if (error)
            *error = QStringLiteral("Could not create touchscreen calibration directory");
        return false;
    }
    QSaveFile file(storagePath_);
    if (!file.open(QIODevice::WriteOnly) || file.write(document.toJson(QJsonDocument::Indented)) < 0
        || !file.commit()) {
        if (error)
            *error = file.errorString();
        return false;
    }
    if (error)
        error->clear();
    return true;
}

} // namespace ciderdeck
