#include "BrightnessService.h"

#include <QDir>
#include <QFile>
#include <QTextStream>

namespace ciderdeck {

BrightnessService::BrightnessService(QObject *parent)
    : QObject(parent) {
    backlightPath_ = findBacklightPath();
    available_ = !backlightPath_.isEmpty();
    refresh();
}

void BrightnessService::setBrightness(int percent) {
    if (!available_ || maxBrightness_ <= 0) return;

    percent = qBound(0, percent, 100);
    int value = static_cast<int>(static_cast<double>(percent) / 100.0 * maxBrightness_);

    QFile file(backlightPath_ + "/brightness");
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream stream(&file);
        stream << value;
        file.close();
        brightness_ = percent;
        emit brightnessChanged();
    }
}

void BrightnessService::refresh() {
    if (!available_) return;

    QFile maxFile(backlightPath_ + "/max_brightness");
    if (maxFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        maxBrightness_ = maxFile.readAll().trimmed().toInt();
        maxFile.close();
    }

    QFile curFile(backlightPath_ + "/brightness");
    if (curFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        int current = curFile.readAll().trimmed().toInt();
        curFile.close();
        if (maxBrightness_ > 0) {
            brightness_ = qRound(100.0 * current / maxBrightness_);
            emit brightnessChanged();
        }
    }
}

QString BrightnessService::findBacklightPath() const {
    QDir dir("/sys/class/backlight");
    auto entries = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    if (!entries.isEmpty()) {
        return "/sys/class/backlight/" + entries.first();
    }
    return {};
}

} // namespace ciderdeck
