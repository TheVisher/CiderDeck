#include "CiderDeckApp.h"

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include <QDebug>
#include <QWindow>
#include <QGuiApplication>
#include <QScreen>

#ifdef HAVE_KF6WINDOWSYSTEM
#include <KWindowEffects>
#endif

#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Window>
#endif

#include "models/DeckConfig.h"
#include "services/MonitorManager.h"
#include "services/ThemeManager.h"
#include "services/AppIconProvider.h"
#include "services/CommandRunner.h"
#include "services/AppLaunchManager.h"
#include "services/AudioManager.h"
#include "services/MprisManager.h"
#include "services/WeatherService.h"
#include "services/SystemMonitorService.h"
#include "services/ProcessManagerService.h"
#include "services/ScreenshotService.h"
#include "services/BrightnessService.h"
#include "services/ClipboardService.h"
#include "services/TimerService.h"
#include "services/KWinDBusClient.h"
#include "viewmodels/TileGridModel.h"
#include "viewmodels/EditModeController.h"
#include "viewmodels/ToastModel.h"
#include "viewmodels/InstalledAppsModel.h"

namespace ciderdeck {

CiderDeckApp::CiderDeckApp(QObject *parent)
    : QObject(parent) {}

int CiderDeckApp::run(QApplication &app) {
    // Core
    config_ = new DeckConfig(this);
    monitorManager_ = new MonitorManager(this);
    themeManager_ = new ThemeManager(config_, this);

    // Services
    commandRunner_ = new CommandRunner(this);
    appLaunchManager_ = new AppLaunchManager(this);
    audioManager_ = new AudioManager(this);
    mprisManager_ = new MprisManager(this);
    weatherService_ = new WeatherService(this);
    systemMonitor_ = new SystemMonitorService(this);
    processManager_ = new ProcessManagerService(this);
    screenshotService_ = new ScreenshotService(this);
    brightnessService_ = new BrightnessService(this);
    clipboardService_ = new ClipboardService(this);
    timerService_ = new TimerService(this);
    kwinClient_ = new KWinDBusClient(this);
    kwinClient_->publishService();
    appLaunchManager_->setKWinClient(kwinClient_);

    // ViewModels
    tileGridModel_ = new TileGridModel(config_, this);
    editController_ = new EditModeController(config_, tileGridModel_, this);
    toastModel_ = new ToastModel(this);
    installedApps_ = new InstalledAppsModel(this);
    appFilterModel_ = new AppFilterModel(this);
    appFilterModel_->setSourceModel(installedApps_);

    engine_ = new QQmlApplicationEngine(this);

    QObject::connect(engine_, &QQmlApplicationEngine::warnings, this, [](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings) {
            fprintf(stderr, "[QML WARNING] %s\n", warning.toString().toUtf8().constData());
        }
    });

    engine_->addImageProvider(QStringLiteral("appicon"), new AppIconProvider());

    auto *ctx = engine_->rootContext();
    ctx->setContextProperty("deckConfig", config_);
    ctx->setContextProperty("monitorManager", monitorManager_);
    ctx->setContextProperty("themeManager", themeManager_);
    ctx->setContextProperty("commandRunner", commandRunner_);
    ctx->setContextProperty("appLaunchManager", appLaunchManager_);
    ctx->setContextProperty("audioManager", audioManager_);
    ctx->setContextProperty("mprisManager", mprisManager_);
    ctx->setContextProperty("weatherService", weatherService_);
    ctx->setContextProperty("systemMonitor", systemMonitor_);
    ctx->setContextProperty("processManager", processManager_);
    ctx->setContextProperty("screenshotService", screenshotService_);
    ctx->setContextProperty("brightnessService", brightnessService_);
    ctx->setContextProperty("clipboardService", clipboardService_);
    ctx->setContextProperty("timerService", timerService_);
    ctx->setContextProperty("kwinClient", kwinClient_);
    ctx->setContextProperty("tileGridModel", tileGridModel_);
    ctx->setContextProperty("editController", editController_);
    ctx->setContextProperty("toastModel", toastModel_);
    ctx->setContextProperty("installedAppsModel", installedApps_);
    ctx->setContextProperty("appFilterModel", appFilterModel_);

    wireSignals();

    const QUrl url(QStringLiteral("qrc:/src/qml/main.qml"));

    QObject::connect(engine_, &QQmlApplicationEngine::objectCreated,
                     this, [this, url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            qWarning() << "[CiderDeckApp] QML root failed to load:" << url;
            return;
        }

        auto *window = qobject_cast<QWindow *>(obj);
        if (window) {
            configureWindow(window);
            window->setVisible(true);
        }
    });

    engine_->load(url);
    if (engine_->rootObjects().isEmpty()) {
        qWarning() << "[CiderDeckApp] No QML root objects loaded";
    }

    return app.exec();
}

void CiderDeckApp::wireSignals() {
    QObject::connect(config_, &DeckConfig::currentPageChanged, tileGridModel_, [this]() {
        tileGridModel_->setCurrentPage(config_->currentPage());
    });

    // Wire toast undo actions
    QObject::connect(toastModel_, &ToastModel::actionTriggered, this, [this](const QString &actionId) {
        if (actionId.startsWith("undo_delete")) {
            editController_->undoDelete();
        } else if (actionId == "timer_add_5") {
            timerService_->addTime(5 * 60);
        } else if (actionId == "timer_add_10") {
            timerService_->addTime(10 * 60);
        }
    });

    // Timer finished toast
    QObject::connect(timerService_, &TimerService::finished, this, [this]() {
        toastModel_->showWithAction("Timer finished!", "Add 5min", "timer_add_5", 10000);
    });

    // Screenshot saved toast
    QObject::connect(screenshotService_, &ScreenshotService::screenshotSaved, this, [this](const QString &path) {
        Q_UNUSED(path)
        toastModel_->show("Screenshot saved", 4000);
    });

    // KWin bridge errors
    QObject::connect(kwinClient_, &KWinDBusClient::bridgeError, this, [](const QString &msg) {
        qWarning() << "[KWinDBusClient]" << msg;
    });

    // Request initial window list once bridge is up
    kwinClient_->requestWindowList();
}

void CiderDeckApp::configureWindow(QWindow *window) {
    if (!window) return;

    QScreen *targetScreen = nullptr;
    if (!config_->targetDisplay().isEmpty()) {
        targetScreen = monitorManager_->findByName(config_->targetDisplay());
        if (targetScreen) {
            qInfo() << "[CiderDeckApp] Found target display by name:" << config_->targetDisplay();
        }
    }
    if (!targetScreen) {
        targetScreen = monitorManager_->findByResolution(2560, 720);
        if (targetScreen) {
            qInfo() << "[CiderDeckApp] Found Xeneon Edge by resolution:" << targetScreen->name()
                     << targetScreen->geometry();
        }
    }

    if (targetScreen) {
        window->setScreen(targetScreen);
        window->setGeometry(targetScreen->geometry());
        qInfo() << "[CiderDeckApp] Window placed on:" << targetScreen->name()
                 << "geometry:" << targetScreen->geometry();
    } else {
        qWarning() << "[CiderDeckApp] No target screen found, using default. Available screens:";
        for (auto *s : QGuiApplication::screens()) {
            qWarning() << "  " << s->name() << s->size() << s->geometry();
        }
    }

#ifdef HAVE_LAYERSHELLQT
    auto *lw = LayerShellQt::Window::get(window);
    if (lw) {
        lw->setLayer(LayerShellQt::Window::LayerBottom);
        lw->setAnchors(LayerShellQt::Window::Anchors(
            LayerShellQt::Window::AnchorTop
            | LayerShellQt::Window::AnchorBottom
            | LayerShellQt::Window::AnchorLeft
            | LayerShellQt::Window::AnchorRight));
        lw->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityOnDemand);
        lw->setExclusiveZone(-1);
        lw->setScope(QStringLiteral("ciderdeck"));

        qInfo() << "[CiderDeckApp] Layer-shell configured on" << (targetScreen ? targetScreen->name() : "default");
    }
#endif

    applyWindowEffects(window);
}

void CiderDeckApp::applyWindowEffects(QWindow *window) {
#ifdef HAVE_KF6WINDOWSYSTEM
    if (!window) return;

    const bool isWayland = QGuiApplication::platformName().contains(
        QStringLiteral("wayland"), Qt::CaseInsensitive);

    if (config_->globalBlur() &&
        (isWayland || KWindowEffects::isEffectAvailable(KWindowEffects::BlurBehind))) {
        KWindowEffects::enableBlurBehind(window, true, QRegion());
        KWindowEffects::enableBackgroundContrast(window, true, 1.0, 1.06, 1.24, QRegion());

        static bool loggedOnce = false;
        if (!loggedOnce) {
            qInfo() << "[CiderDeckApp] Blur-behind enabled, platform:" << QGuiApplication::platformName();
            loggedOnce = true;
        }
    }
#else
    Q_UNUSED(window)
#endif
}

} // namespace ciderdeck
