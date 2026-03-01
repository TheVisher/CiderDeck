#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QTimer>

namespace ciderdeck {

class WeatherService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString temperature READ temperature NOTIFY weatherUpdated)
    Q_PROPERTY(QString condition READ condition NOTIFY weatherUpdated)
    Q_PROPERTY(QString icon READ icon NOTIFY weatherUpdated)
    Q_PROPERTY(QString windSpeed READ windSpeed NOTIFY weatherUpdated)
    Q_PROPERTY(QString humidity READ humidity NOTIFY weatherUpdated)
    Q_PROPERTY(QString location READ location NOTIFY weatherUpdated)
    Q_PROPERTY(int currentLocationIndex READ currentLocationIndex WRITE setCurrentLocationIndex NOTIFY currentLocationChanged)

public:
    explicit WeatherService(QObject *parent = nullptr);

    QString temperature() const { return temperature_; }
    QString condition() const { return condition_; }
    QString icon() const { return icon_; }
    QString windSpeed() const { return windSpeed_; }
    QString humidity() const { return humidity_; }
    QString location() const { return location_; }
    int currentLocationIndex() const { return currentLocationIndex_; }

    void setCurrentLocationIndex(int idx);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setLocations(const QStringList &locations);
    Q_INVOKABLE void setUnit(const QString &unit);
    Q_INVOKABLE void setRefreshInterval(int minutes);
    Q_INVOKABLE void nextLocation();
    Q_INVOKABLE void previousLocation();

signals:
    void weatherUpdated();
    void currentLocationChanged();

private:
    void fetchWeather(const QString &location);
    void parseResponse(const QByteArray &data);

    QNetworkAccessManager *nam_ = nullptr;
    QTimer *refreshTimer_ = nullptr;
    QStringList locations_;
    int currentLocationIndex_ = 0;
    QString unit_ = "f";

    QString temperature_;
    QString condition_;
    QString icon_;
    QString windSpeed_;
    QString humidity_;
    QString location_;
};

} // namespace ciderdeck
