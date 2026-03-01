#include <QApplication>
#include <QLoggingCategory>

#include "app/CiderDeckApp.h"

int main(int argc, char *argv[]) {
    // Suppress noisy Qt network debug messages (HTTP/2 GOAWAY spam from weather/album art)
    QLoggingCategory::setFilterRules(QStringLiteral(
        "qt.network.http2=false\n"
        "qt.qpa.services=false\n"
    ));

    QApplication app(argc, argv);
    app.setApplicationName("ciderdeck");
    app.setApplicationDisplayName("CiderDeck");
    app.setOrganizationName("ciderdeck");
    app.setDesktopFileName("ciderdeck");
    app.setQuitOnLastWindowClosed(false);

    ciderdeck::CiderDeckApp deckApp;
    return deckApp.run(app);
}
