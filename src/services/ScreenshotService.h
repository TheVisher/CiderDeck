#pragma once

#include <QObject>

namespace ciderdeck {

class ScreenshotService : public QObject {
    Q_OBJECT

public:
    explicit ScreenshotService(QObject *parent = nullptr);

    Q_INVOKABLE bool triggerShortcut();

signals:
    void screenshotFailed(const QString &error);
};

} // namespace ciderdeck
