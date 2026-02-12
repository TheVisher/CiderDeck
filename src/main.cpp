#include <QApplication>

#ifdef HAVE_LAYERSHELLQT
#include <LayerShellQt/Shell>
#endif

#include "app/CiderDeckApp.h"

int main(int argc, char *argv[]) {
#ifdef HAVE_LAYERSHELLQT
    LayerShellQt::Shell::useLayerShell();
#endif

    QApplication app(argc, argv);
    app.setApplicationName("ciderdeck");
    app.setOrganizationName("ciderdeck");
    app.setQuitOnLastWindowClosed(false);

    ciderdeck::CiderDeckApp deckApp;
    return deckApp.run(app);
}
