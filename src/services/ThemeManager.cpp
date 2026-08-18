#include "ThemeManager.h"
#include "models/DeckConfig.h"

#include <QFile>
#include <QSettings>
#include <QStandardPaths>

namespace ciderdeck {

ThemeManager::ThemeManager(DeckConfig *config, QObject *parent)
    : QObject(parent)
    , config_(config) {
    connect(config_, &DeckConfig::appearanceChanged, this, &ThemeManager::refresh);
    refresh();
}

void ThemeManager::refresh() {
    if (config_->followSystemTheme()) {
        readKdeTheme();
    } else if (config_->theme() == "light") {
        applyLight();
    } else {
        applyDark();
    }
    emit themeChanged();
}

void ThemeManager::applyDark() {
    isDark_ = true;
    backgroundColor_ = QColor(20, 26, 35);         // #141a23
    textColor_ = QColor(244, 247, 251);             // #f4f7fb
    secondaryTextColor_ = QColor(166, 178, 192);    // #a6b2c0
    accentColor_ = QColor(77, 163, 255);            // #4da3ff
    borderColor_ = QColor(255, 255, 255, 30);
    overlayColor_ = QColor(255, 255, 255, 20);
    successColor_ = QColor(70, 199, 144);
    errorColor_ = QColor(255, 107, 107);
}

void ThemeManager::applyLight() {
    isDark_ = false;
    backgroundColor_ = QColor(245, 245, 245);     // #f5f5f5
    textColor_ = QColor(26, 26, 26);              // #1a1a1a
    secondaryTextColor_ = QColor(100, 100, 110);
    accentColor_ = QColor(0, 102, 204);           // #0066cc
    borderColor_ = QColor(0, 0, 0, 25);
    overlayColor_ = QColor(0, 0, 0, 10);
    successColor_ = QColor(56, 142, 60);
    errorColor_ = QColor(211, 47, 47);
}

void ThemeManager::readKdeTheme() {
    const QString configDir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QString kdeglobals = configDir + QStringLiteral("/kdeglobals");

    if (!QFile::exists(kdeglobals)) {
        applyDark();
        return;
    }

    QSettings settings(kdeglobals, QSettings::IniFormat);

    settings.beginGroup("Colors:Window");
    const QString bgStr = settings.value("BackgroundNormal").toString();
    const QString fgStr = settings.value("ForegroundNormal").toString();
    settings.endGroup();

    auto parseColor = [](const QString &str) -> QColor {
        const auto parts = str.split(',');
        if (parts.size() >= 3) {
            return QColor(parts[0].trimmed().toInt(),
                          parts[1].trimmed().toInt(),
                          parts[2].trimmed().toInt());
        }
        return QColor();
    };

    QColor bg = parseColor(bgStr);
    QColor fg = parseColor(fgStr);

    if (!bg.isValid() || !fg.isValid()) {
        applyDark();
        return;
    }

    isDark_ = bg.lightnessF() < 0.5;
    backgroundColor_ = bg;
    textColor_ = fg;
    secondaryTextColor_ = fg;
    secondaryTextColor_.setAlphaF(0.6);

    settings.beginGroup("Colors:Selection");
    const QString accentStr = settings.value("BackgroundNormal").toString();
    settings.endGroup();
    QColor accent = parseColor(accentStr);
    accentColor_ = accent.isValid() ? accent : QColor(68, 136, 255);

    borderColor_ = isDark_ ? QColor(255, 255, 255, 25) : QColor(0, 0, 0, 25);
    overlayColor_ = isDark_ ? QColor(255, 255, 255, 15) : QColor(0, 0, 0, 10);
    successColor_ = QColor(76, 175, 80);
    errorColor_ = QColor(244, 67, 54);
}

} // namespace ciderdeck
