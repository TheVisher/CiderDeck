#pragma once

#include <QObject>

namespace ciderdeck {

class ScreenshotService : public QObject {
    Q_OBJECT

public:
    explicit ScreenshotService(QObject *parent = nullptr);

    Q_INVOKABLE void captureScreen(const QString &monitor = QString());
    Q_INVOKABLE void captureRegion();

signals:
    void screenshotSaved(const QString &path);
    void screenshotFailed(const QString &error);

private:
    QString savePath() const;
};

} // namespace ciderdeck
