#include <QApplication>
#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QMimeData>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QTest>
#include <QUuid>

#include "services/ClipboardService.h"

using namespace ciderdeck;

class ClipboardServiceTests : public QObject {
    Q_OBJECT

private slots:
    void mirrorsKlipperTextAndImageEntries();
};

void ClipboardServiceTests::mirrorsKlipperTextAndImageEntries()
{
    QTemporaryDir temporaryDirectory;
    QVERIFY(temporaryDirectory.isValid());

    const QString databasePath = temporaryDirectory.filePath(QStringLiteral("history3.sqlite"));
    const QString connectionName = QStringLiteral("clipboard-test-setup-%1")
                                       .arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
    {
        QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        database.setDatabaseName(databasePath);
        QVERIFY(database.open());

        QSqlQuery query(database);
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE main (uuid TEXT PRIMARY KEY, added_time REAL, last_used_time REAL, "
            "mimetypes TEXT, text TEXT, starred INTEGER)")));
        QVERIFY(query.exec(QStringLiteral(
            "CREATE TABLE aux (uuid TEXT, mimetype TEXT, data_uuid TEXT)")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO main VALUES ('text-entry', 100, 200, 'text/plain,text/html', "
            "'Test text', 0)")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO main VALUES ('image-entry', 300, 400, 'image/png', '', 0)")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO aux VALUES ('text-entry', 'text/plain', 'plain-data')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO aux VALUES ('text-entry', 'text/html', 'html-data')")));
        QVERIFY(query.exec(QStringLiteral(
            "INSERT INTO aux VALUES ('image-entry', 'image/png', 'image-data')")));
        database.close();
    }
    QSqlDatabase::removeDatabase(connectionName);

    const QString dataRoot = temporaryDirectory.filePath(QStringLiteral("data"));
    QVERIFY(QDir().mkpath(dataRoot + QStringLiteral("/text-entry")));
    QVERIFY(QDir().mkpath(dataRoot + QStringLiteral("/image-entry")));

    const auto writeData = [](const QString &path, const QByteArray &data) {
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly))
            return false;
        return file.write(data) == data.size();
    };

    QVERIFY(writeData(dataRoot + QStringLiteral("/text-entry/plain-data"), "Test text"));
    QVERIFY(writeData(dataRoot + QStringLiteral("/text-entry/html-data"), "<b>Test text</b>"));
    const QByteArray pngData = QByteArray::fromBase64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/"
        "WpeKAAAAAElFTkSuQmCC");
    QVERIFY(writeData(dataRoot + QStringLiteral("/image-entry/image-data"), pngData));

    qputenv("KLIPPER_DATABASE", databasePath.toUtf8());
    ClipboardService service;
    QTRY_COMPARE(service.rowCount(), 2);

    const QModelIndex imageIndex = service.index(0, 0);
    QVERIFY(service.data(imageIndex, ClipboardService::IsImageRole).toBool());
    QVERIFY(service.data(imageIndex, ClipboardService::ImageSourceRole).toUrl().isLocalFile());
    QCOMPARE(service.data(imageIndex, ClipboardService::TimestampEpochRole).toLongLong(), 400);

    const QModelIndex textIndex = service.index(1, 0);
    QCOMPARE(service.data(textIndex, ClipboardService::TextRole).toString(), QStringLiteral("Test text"));
    QCOMPARE(service.data(textIndex, ClipboardService::TimestampEpochRole).toLongLong(), 200);

    service.copyToClipboard(1);
    const QMimeData *textMimeData = QApplication::clipboard()->mimeData();
    QCOMPARE(textMimeData->data(QStringLiteral("text/plain")), QByteArray("Test text"));
    QCOMPARE(textMimeData->data(QStringLiteral("text/html")), QByteArray("<b>Test text</b>"));

    service.copyToClipboard(0);
    const QMimeData *imageMimeData = QApplication::clipboard()->mimeData();
    QCOMPARE(imageMimeData->data(QStringLiteral("image/png")), pngData);

    qunsetenv("KLIPPER_DATABASE");
}

QTEST_MAIN(ClipboardServiceTests)

#include "ClipboardServiceTests.moc"
