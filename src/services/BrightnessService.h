#pragma once

#include <QObject>
#include <QProcess>

namespace ciderdeck {

class BrightnessService : public QObject {
    Q_OBJECT
    Q_PROPERTY(int brightness READ brightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(QString method READ method NOTIFY availableChanged)

public:
    explicit BrightnessService(QObject *parent = nullptr);

    int brightness() const { return brightness_; }
    bool available() const { return available_; }
    QString method() const { return method_; }

    Q_INVOKABLE void setBrightness(int percent);
    Q_INVOKABLE void refresh();

signals:
    void brightnessChanged();
    void availableChanged();

private:
    void initBacklight();
    void initDdcutil();
    QString findBacklightPath() const;

    int brightness_ = 100;
    int maxBrightness_ = 0;
    bool available_ = false;
    QString method_;          // "backlight" or "ddcutil"
    QString backlightPath_;
    int ddcDisplayNum_ = -1;  // ddcutil --display N
    bool ddcBusy_ = false;    // prevent overlapping ddcutil calls
};

} // namespace ciderdeck
