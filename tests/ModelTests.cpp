#include <QtTest/QTest>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QTemporaryDir>

#include "models/DeckConfig.h"
#include "models/TileData.h"
#include "models/TileType.h"
#include "services/AudioRoutingPolicy.h"
#include "viewmodels/TileGridModel.h"

using namespace ciderdeck;

class ModelTests : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();
    void tileTypesRoundTrip();
    void tileDataRoundTripsThroughJson();
    void gridDetectsCollisionsAndFindsFreeSpace();
    void tilesMoveBetweenPages();
    void agentWorkspacePageIsAddedOnce();
    void pagesCanBeReordered();
    void deletingPageCreatesRecoveryBackup();
    void audioRoutingPolicyRecognizesAsmObjects();

private:
    QTemporaryDir configDir_;
};

void ModelTests::initTestCase() {
    QVERIFY(configDir_.isValid());
    QVERIFY(qputenv("CIDERDECK_CONFIG_DIR", configDir_.path().toUtf8()));
}

void ModelTests::tileTypesRoundTrip() {
    const QList<TileType> types = {
        TileType::AppLauncher,
        TileType::MediaPlayer,
        TileType::Volume,
        TileType::ClockDate,
        TileType::Weather,
        TileType::SystemMonitor,
        TileType::ProcessManager,
        TileType::Updates,
        TileType::Screenshot,
        TileType::Brightness,
        TileType::Clipboard,
        TileType::TimerStopwatch,
        TileType::CommandButton,
        TileType::ShowDesktop,
        TileType::Overview,
        TileType::AudioMixer,
    };

    for (const TileType type : types) {
        QCOMPARE(tileTypeFromString(tileTypeToString(type)), type);
    }
    QCOMPARE(tileTypeFromString(QStringLiteral("not_a_tile")), TileType::AppLauncher);
}

void ModelTests::tileDataRoundTripsThroughJson() {
    TileData original;
    original.id = QStringLiteral("tile-123");
    original.type = TileType::Weather;
    original.col = 7;
    original.row = 2;
    original.colSpan = 5;
    original.rowSpan = 3;
    original.label = QStringLiteral("Forecast");
    original.showLabel = false;
    original.opacity = 0.75;
    original.blurLevel = 0.4;
    original.settings = {
        {QStringLiteral("location"), QStringLiteral("Portland")},
        {QStringLiteral("showHumidity"), true},
    };

    const TileData restored = TileData::fromJson(original.toJson());

    QCOMPARE(restored.id, original.id);
    QCOMPARE(restored.type, original.type);
    QCOMPARE(restored.col, original.col);
    QCOMPARE(restored.row, original.row);
    QCOMPARE(restored.colSpan, original.colSpan);
    QCOMPARE(restored.rowSpan, original.rowSpan);
    QCOMPARE(restored.label, original.label);
    QCOMPARE(restored.showLabel, original.showLabel);
    QCOMPARE(restored.opacity, original.opacity);
    QCOMPARE(restored.blurLevel, original.blurLevel);
    QCOMPARE(restored.settings, original.settings);
}

void ModelTests::gridDetectsCollisionsAndFindsFreeSpace() {
    DeckConfig config;
    const QVariantList starterTiles = config.tilesForPage(0);
    for (const QVariant &tile : starterTiles) {
        config.removeTile(tile.toMap().value(QStringLiteral("id")).toString());
    }

    config.addTile(0, {
        {QStringLiteral("id"), QStringLiteral("primary")},
        {QStringLiteral("type"), QStringLiteral("clock_date")},
        {QStringLiteral("col"), 2},
        {QStringLiteral("row"), 1},
        {QStringLiteral("colSpan"), 3},
        {QStringLiteral("rowSpan"), 2},
    });

    TileGridModel grid(&config);

    QCOMPARE(grid.rowCount(), 1);
    QVERIFY(grid.checkCollision(2, 1, 3, 2));
    QVERIFY(grid.checkCollision(0, 0, 3, 2));
    QVERIFY(!grid.checkCollision(0, 0, 2, 1));
    QVERIFY(!grid.checkCollision(2, 1, 3, 2, QStringLiteral("primary")));
    QVERIFY(grid.checkCollision(-1, 0, 1, 1));
    QVERIFY(grid.checkCollision(config.gridColumns(), 0, 1, 1));

    const QVariantMap freePosition = grid.findFreePosition(2, 1);
    QCOMPARE(freePosition.value(QStringLiteral("col")).toInt(), 0);
    QCOMPARE(freePosition.value(QStringLiteral("row")).toInt(), 0);
    QCOMPARE(grid.getTileById(QStringLiteral("primary")).value(QStringLiteral("label")).toString(),
             QString());
}

void ModelTests::tilesMoveBetweenPages() {
    DeckConfig config;
    while (config.pageCount() > 1) {
        config.removePage(config.pageCount() - 1);
    }
    const QVariantList existingTiles = config.tilesForPage(0);
    for (const QVariant &tile : existingTiles) {
        config.removeTile(tile.toMap().value(QStringLiteral("id")).toString());
    }

    config.addPage(QStringLiteral("Second"));
    config.addTile(0, {
        {QStringLiteral("id"), QStringLiteral("moving-tile")},
        {QStringLiteral("type"), QStringLiteral("clock_date")},
        {QStringLiteral("col"), 4},
        {QStringLiteral("row"), 2},
        {QStringLiteral("colSpan"), 3},
        {QStringLiteral("rowSpan"), 2},
    });

    QVERIFY(config.moveTileToPage(QStringLiteral("moving-tile"), 1));
    QCOMPARE(config.tilesForPage(0).size(), 0);
    QCOMPARE(config.tilesForPage(1).size(), 1);
    const QVariantMap movedTile = config.tilesForPage(1).first().toMap();
    QCOMPARE(movedTile.value(QStringLiteral("id")).toString(), QStringLiteral("moving-tile"));
    QCOMPARE(movedTile.value(QStringLiteral("col")).toInt(), 4);
    QCOMPARE(movedTile.value(QStringLiteral("row")).toInt(), 2);

    config.setGridColumns(2);
    config.setGridRows(2);
    config.addTile(0, {
        {QStringLiteral("id"), QStringLiteral("blocked-tile")},
        {QStringLiteral("type"), QStringLiteral("clock_date")},
        {QStringLiteral("colSpan"), 1},
        {QStringLiteral("rowSpan"), 1},
    });
    config.addTile(1, {
        {QStringLiteral("id"), QStringLiteral("full-page")},
        {QStringLiteral("type"), QStringLiteral("clock_date")},
        {QStringLiteral("colSpan"), 2},
        {QStringLiteral("rowSpan"), 2},
    });

    QVERIFY(!config.moveTileToPage(QStringLiteral("blocked-tile"), 1));
    QCOMPARE(config.tilesForPage(0).size(), 1);
}

void ModelTests::agentWorkspacePageIsAddedOnce() {
    DeckConfig config;
    const int originalCount = config.pageCount();
    const int page = config.ensureAgentWorkspacePage();

    QCOMPARE(config.pageCount(), originalCount + 1);
    QCOMPARE(config.pageType(page), QStringLiteral("agents"));
    QCOMPARE(config.pageNames().at(page), QStringLiteral("Agents"));
    QCOMPARE(config.ensureAgentWorkspacePage(), page);
    QCOMPARE(config.pageCount(), originalCount + 1);

    DeckConfig reloaded;
    QCOMPARE(reloaded.pageType(page), QStringLiteral("agents"));
    QCOMPARE(reloaded.ensureAgentWorkspacePage(), page);
    QCOMPARE(reloaded.pageCount(), originalCount + 1);
}

void ModelTests::pagesCanBeReordered() {
    DeckConfig config;
    while (config.pageCount() > 1)
        config.removePage(config.pageCount() - 1);
    config.addPage(QStringLiteral("Second"));
    config.addPage(QStringLiteral("Third"));
    config.setCurrentPage(0);

    QVERIFY(config.movePage(0, 2));
    QCOMPARE(config.pageNames(), QStringList({QStringLiteral("Second"),
                                              QStringLiteral("Third"),
                                              QStringLiteral("Page 1")}));
    QCOMPARE(config.currentPage(), 2);

    QVERIFY(config.movePage(0, 1));
    QCOMPARE(config.pageNames(), QStringList({QStringLiteral("Third"),
                                              QStringLiteral("Second"),
                                              QStringLiteral("Page 1")}));
    QCOMPARE(config.currentPage(), 2);
    QVERIFY(!config.movePage(-1, 0));
    QVERIFY(!config.movePage(0, 3));
}

void ModelTests::deletingPageCreatesRecoveryBackup() {
    DeckConfig config;
    config.addPage(QStringLiteral("Important"));
    const int pageCountBeforeDelete = config.pageCount();
    const QString configPath = config.configPath();
    const QDir backupDir(QFileInfo(configPath).dir().filePath(QStringLiteral("backups")));
    const QStringList backupsBefore = backupDir.entryList(
        {QStringLiteral("config-before-page-delete-*.json")},
        QDir::Files);

    config.removePage(0);

    const QStringList backupsAfter = backupDir.entryList(
        {QStringLiteral("config-before-page-delete-*.json")},
        QDir::Files);
    QCOMPARE(backupsAfter.size(), backupsBefore.size() + 1);

    QString newBackup;
    for (const QString &backup : backupsAfter) {
        if (!backupsBefore.contains(backup)) {
            newBackup = backup;
            break;
        }
    }
    QVERIFY(!newBackup.isEmpty());

    QFile backup(backupDir.filePath(newBackup));
    QVERIFY(backup.open(QIODevice::ReadOnly));
    const QJsonDocument document = QJsonDocument::fromJson(backup.readAll());
    QVERIFY(document.isObject());
    QCOMPARE(document.object()[QStringLiteral("pages")].toArray().size(),
             pageCountBeforeDelete);
}

void ModelTests::audioRoutingPolicyRecognizesAsmObjects() {
    using ciderdeck::audio::isAsmVirtualSinkName;
    using ciderdeck::audio::isInternalProcessingStreamName;

    QVERIFY(isAsmVirtualSinkName(u"Arctis_Game"));
    QVERIFY(isAsmVirtualSinkName(u"Arctis_Media"));
    QVERIFY(isAsmVirtualSinkName(u"Arctis_Chat"));
    QVERIFY(!isAsmVirtualSinkName(u"alsa_output.usb-SteelSeries"));

    QVERIFY(isInternalProcessingStreamName(u"Sonar Media EQ output"));
    QVERIFY(isInternalProcessingStreamName(u"Arctis Nova Pro Wireless Game output"));
    QVERIFY(isInternalProcessingStreamName(u"Virtual Surround Sink"));
    QVERIFY(!isInternalProcessingStreamName(u"Zen"));
    QVERIFY(!isInternalProcessingStreamName(u"World of Warcraft"));
}

QTEST_GUILESS_MAIN(ModelTests)

#include "ModelTests.moc"
