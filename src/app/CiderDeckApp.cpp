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
#include "viewmodels/TileGridModel.h"

namespace ciderdeck {

CiderDeckApp::CiderDeckApp(QObject *parent)
    : QObject(parent) {}

int CiderDeckApp::run(QApplication &app) {
    config_ = new DeckConfig(this);
    monitorManager_ = new MonitorManager(this);
    themeManager_ = new ThemeManager(config_, this);
    commandRunner_ = new CommandRunner(this);
    appLaunchManager_ = new AppLaunchManager(this);
    tileGridModel_ = new TileGridModel(config_, this);

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
    ctx->setContextProperty("tileGridModel", tileGridModel_);

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
        }
    }, Qt::QueuedConnection);

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
}

void CiderDeckApp::configureWindow(QWindow *window) {
    if (!window) return;

    // Target the Xeneon Edge display (2560x720) or fallback to configured display
    QScreen *targetScreen = nullptr;
    if (!config_->targetDisplay().isEmpty()) {
        targetScreen = monitorManager_->findByName(config_->targetDisplay());
    }
    if (!targetScreen) {
        targetScreen = monitorManager_->findByResolution(2560, 720);
    }
    if (targetScreen) {
        window->setScreen(targetScreen);
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
        lw->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        lw->setExclusiveZone(-1);
        lw->setScope(QStringLiteral("ciderdeck"));

        qInfo() << "[CiderDeckApp] Layer-shell configured: LayerBottom, no keyboard interactivity";
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
