#include "WeatherService.h"

#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>

namespace ciderdeck {

WeatherService::WeatherService(QObject *parent)
    : QObject(parent)
    , nam_(new QNetworkAccessManager(this))
    , refreshTimer_(new QTimer(this)) {
    refreshTimer_->setInterval(30 * 60 * 1000); // 30 minutes
    connect(refreshTimer_, &QTimer::timeout, this, &WeatherService::refresh);
    refreshTimer_->start();
}

void WeatherService::refresh() {
    if (locations_.isEmpty()) {
        // Auto-detect with empty location
        fetchWeather(QString());
    } else if (currentLocationIndex_ < locations_.size()) {
        fetchWeather(locations_[currentLocationIndex_]);
    }
}

void WeatherService::setLocations(const QStringList &locations) {
    locations_ = locations;
    currentLocationIndex_ = 0;
    refresh();
}

void WeatherService::setUnit(const QString &unit) {
    unit_ = unit;
    refresh();
}

void WeatherService::setCurrentLocationIndex(int idx) {
    if (idx >= 0 && idx < locations_.size() && idx != currentLocationIndex_) {
        currentLocationIndex_ = idx;
        emit currentLocationChanged();
        refresh();
    }
}

void WeatherService::setRefreshInterval(int minutes) {
    if (minutes > 0) {
        refreshTimer_->setInterval(minutes * 60 * 1000);
    }
}

void WeatherService::nextLocation() {
    if (locations_.size() > 1) {
        setCurrentLocationIndex((currentLocationIndex_ + 1) % locations_.size());
    }
}

void WeatherService::previousLocation() {
    if (locations_.size() > 1) {
        setCurrentLocationIndex((currentLocationIndex_ - 1 + locations_.size()) % locations_.size());
    }
}

void WeatherService::fetchWeather(const QString &location) {
    QString urlStr = QStringLiteral("https://wttr.in/%1?format=j1").arg(location);
    QNetworkRequest request{QUrl(urlStr)};
    request.setHeader(QNetworkRequest::UserAgentHeader, "CiderDeck/1.0");

    auto *reply = nam_->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError) {
            parseResponse(reply->readAll());
        }
    });
}

void WeatherService::parseResponse(const QByteArray &data) {
    auto doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    auto root = doc.object();
    auto current = root["current_condition"].toArray();
    if (current.isEmpty()) return;

    auto cc = current[0].toObject();

    if (unit_ == "f") {
        temperature_ = cc["temp_F"].toString() + QStringLiteral("\u00B0F");
    } else {
        temperature_ = cc["temp_C"].toString() + QStringLiteral("\u00B0C");
    }

    auto desc = cc["weatherDesc"].toArray();
    condition_ = desc.isEmpty() ? QString() : desc[0].toObject()["value"].toString();

    auto weatherCode = cc["weatherCode"].toString().toInt();
    // Map weather codes to Lucide icon names (in icons.qrc)
    if (weatherCode == 113) icon_ = "sun";
    else if (weatherCode == 116) icon_ = "cloud-sun";
    else if (weatherCode >= 119 && weatherCode <= 122) icon_ = "cloud";
    else if (weatherCode >= 176 && weatherCode <= 299) icon_ = "cloud-rain";
    else if (weatherCode >= 302 && weatherCode <= 399) icon_ = "cloud-snow";
    else if (weatherCode >= 200 && weatherCode <= 232) icon_ = "cloud-lightning";
    else icon_ = "cloud";

    windSpeed_ = cc["windspeedMiles"].toString() + QStringLiteral(" mph");
    humidity_ = cc["humidity"].toString() + QStringLiteral("%");

    auto nearest = root["nearest_area"].toArray();
    if (!nearest.isEmpty()) {
        auto area = nearest[0].toObject();
        auto areaName = area["areaName"].toArray();
        location_ = areaName.isEmpty() ? QString() : areaName[0].toObject()["value"].toString();
    }

    emit weatherUpdated();
}

} // namespace ciderdeck
