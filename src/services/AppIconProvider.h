#pragma once

#include <QQuickImageProvider>
#include <QIcon>
#include <QPixmap>
#include <QString>
#include <QHash>
#include <QMutex>

namespace ciderdeck {

class AppIconProvider : public QQuickImageProvider {
public:
    AppIconProvider();

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    QPixmap resolveIcon(const QString &id, int extent) const;
    QString iconNameFromDesktopFile(const QString &id) const;
    QString findDesktopFile(const QString &id) const;

    mutable QMutex cacheMutex_;
    mutable QHash<QString, QPixmap> cache_;
};

} // namespace ciderdeck
