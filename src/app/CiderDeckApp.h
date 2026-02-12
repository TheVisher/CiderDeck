#pragma once

#include <QObject>

class QApplication;
class QQmlApplicationEngine;
class QWindow;

namespace ciderdeck {

class DeckConfig;
class MonitorManager;
class ThemeManager;
class AppIconProvider;
class CommandRunner;
class AppLaunchManager;
class TileGridModel;

class CiderDeckApp : public QObject {
    Q_OBJECT

public:
    explicit CiderDeckApp(QObject *parent = nullptr);
    int run(QApplication &app);

private:
    void wireSignals();
    void configureWindow(QWindow *window);
    void applyWindowEffects(QWindow *window);

    QQmlApplicationEngine *engine_ = nullptr;
    DeckConfig *config_ = nullptr;
    MonitorManager *monitorManager_ = nullptr;
    ThemeManager *themeManager_ = nullptr;
    CommandRunner *commandRunner_ = nullptr;
    AppLaunchManager *appLaunchManager_ = nullptr;
    TileGridModel *tileGridModel_ = nullptr;
};

} // namespace ciderdeck
