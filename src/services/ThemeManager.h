#pragma once

#include <QObject>
#include <QColor>

namespace ciderdeck {

class DeckConfig;

class ThemeManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor backgroundColor READ backgroundColor NOTIFY themeChanged)
    Q_PROPERTY(QColor textColor READ textColor NOTIFY themeChanged)
    Q_PROPERTY(QColor secondaryTextColor READ secondaryTextColor NOTIFY themeChanged)
    Q_PROPERTY(QColor accentColor READ accentColor NOTIFY themeChanged)
    Q_PROPERTY(QColor borderColor READ borderColor NOTIFY themeChanged)
    Q_PROPERTY(QColor overlayColor READ overlayColor NOTIFY themeChanged)
    Q_PROPERTY(QColor successColor READ successColor NOTIFY themeChanged)
    Q_PROPERTY(QColor errorColor READ errorColor NOTIFY themeChanged)
    Q_PROPERTY(bool isDark READ isDark NOTIFY themeChanged)

public:
    explicit ThemeManager(DeckConfig *config, QObject *parent = nullptr);

    QColor backgroundColor() const { return backgroundColor_; }
    QColor textColor() const { return textColor_; }
    QColor secondaryTextColor() const { return secondaryTextColor_; }
    QColor accentColor() const { return accentColor_; }
    QColor borderColor() const { return borderColor_; }
    QColor overlayColor() const { return overlayColor_; }
    QColor successColor() const { return successColor_; }
    QColor errorColor() const { return errorColor_; }
    bool isDark() const { return isDark_; }

    Q_INVOKABLE void refresh();

signals:
    void themeChanged();

private:
    void applyDark();
    void applyLight();
    void readKdeTheme();

    DeckConfig *config_;
    bool isDark_ = true;
    QColor backgroundColor_;
    QColor textColor_;
    QColor secondaryTextColor_;
    QColor accentColor_;
    QColor borderColor_;
    QColor overlayColor_;
    QColor successColor_;
    QColor errorColor_;
};

} // namespace ciderdeck
