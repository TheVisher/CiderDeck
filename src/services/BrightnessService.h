#pragma once

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QVariantMap>

namespace ciderdeck {

class BrightnessService : public QObject {
    Q_OBJECT
    Q_PROPERTY(int brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString method READ method NOTIFY availableChanged)
    Q_PROPERTY(QVariantList displays READ displays NOTIFY displaysChanged)

public:
    explicit BrightnessService(QObject *parent = nullptr);

    int brightness() const { return brightness_; }
    bool available() const { return available_; }
    QString method() const { return method_; }
    QVariantList displays() const { return displays_; }

    Q_INVOKABLE void setBrightness(int percent);
    Q_INVOKABLE void setBrightness(int displayIndex, int percent);
    Q_INVOKABLE int getBrightness(int displayIndex) const;
    Q_INVOKABLE void refresh();

signals:
    void brightnessChanged();
    void availableChanged();
    void displaysChanged();
    void displayBrightnessChanged(int displayIndex, int percent);

private:
    struct DisplayInfo {
        int ddcDisplayNum = -1;
        QString name;
        int brightness = 100;
        int maxBrightness = 100;
        bool busy = false;
    };

    void initBacklight();
    void initDdcutil();
    void enumerateDdcDisplays();
    QString findBacklightPath() const;

    int brightness_ = 100;
    int maxBrightness_ = 0;
    bool available_ = false;
    QString method_;          // "backlight" or "ddcutil"
    QString backlightPath_;
    int ddcDisplayNum_ = -1;  // ddcutil --display N (legacy single-display)

    QVariantList displays_;
    QVector<DisplayInfo> ddcDisplays_;
};

} // namespace ciderdeck
