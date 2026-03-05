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
class AudioManager;
class MprisManager;
class WeatherService;
class SystemMonitorService;
class ProcessManagerService;
class ScreenshotService;
class BrightnessService;
class ClipboardService;
class TimerService;
class AudioMixerService;
class KWinDBusClient;
class EvdevTouchService;
class TileGridModel;
class EditModeController;
class ToastModel;
class InstalledAppsModel;
class AppFilterModel;

class CiderDeckApp : public QObject {
    Q_OBJECT

public:
    explicit CiderDeckApp(QObject *parent = nullptr);
    int run(QApplication &app);

    Q_INVOKABLE void setKeyboardEnabled(bool enabled);

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
    AudioManager *audioManager_ = nullptr;
    AudioMixerService *audioMixerService_ = nullptr;
    MprisManager *mprisManager_ = nullptr;
    WeatherService *weatherService_ = nullptr;
    SystemMonitorService *systemMonitor_ = nullptr;
    ProcessManagerService *processManager_ = nullptr;
    ScreenshotService *screenshotService_ = nullptr;
    BrightnessService *brightnessService_ = nullptr;
    ClipboardService *clipboardService_ = nullptr;
    TimerService *timerService_ = nullptr;
    KWinDBusClient *kwinClient_ = nullptr;
    TileGridModel *tileGridModel_ = nullptr;
    EditModeController *editController_ = nullptr;
    ToastModel *toastModel_ = nullptr;
    InstalledAppsModel *installedApps_ = nullptr;
    AppFilterModel *appFilterModel_ = nullptr;
    QWindow *mainWindow_ = nullptr;
    EvdevTouchService *evdevTouch_ = nullptr;
};

} // namespace ciderdeck
