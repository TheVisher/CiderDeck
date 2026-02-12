#pragma once

#include <QObject>

namespace ciderdeck {

class BrightnessService : public QObject {
    Q_OBJECT
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)

public:
    explicit BrightnessService(QObject *parent = nullptr);

    int brightness() const { return brightness_; }
    bool available() const { return available_; }

    Q_INVOKABLE void setBrightness(int percent);
    Q_INVOKABLE void refresh();

signals:
    void brightnessChanged();
    void availableChanged();

private:
    QString findBacklightPath() const;

    int brightness_ = 100;
    int maxBrightness_ = 0;
    bool available_ = false;
    QString backlightPath_;
};

} // namespace ciderdeck
