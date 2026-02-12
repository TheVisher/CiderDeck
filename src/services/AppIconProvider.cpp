#include "AppIconProvider.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QPainter>

namespace ciderdeck {

AppIconProvider::AppIconProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

QPixmap AppIconProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const int extent = (requestedSize.width() > 0 && requestedSize.height() > 0)
                           ? qMax(requestedSize.width(), requestedSize.height())
                           : 48;

    const QString cacheKey = id.toLower() + QLatin1Char('@') + QString::number(extent);

    {
        QMutexLocker lock(&cacheMutex_);
        auto it = cache_.find(cacheKey);
        if (it != cache_.end()) {
            if (size) *size = it->size();
            return *it;
        }
    }

    QPixmap pm = resolveIcon(id, extent);

    {
        QMutexLocker lock(&cacheMutex_);
        cache_.insert(cacheKey, pm);
    }

    if (size) *size = pm.size();
    return pm;
}

QPixmap AppIconProvider::resolveIcon(const QString &id, int extent) const {
    QIcon icon = QIcon::fromTheme(id.toLower());
    if (!icon.isNull()) {
        return icon.pixmap(extent, extent);
    }

    QString normalized = id.toLower();
    normalized.remove(QStringLiteral(".desktop"));

    icon = QIcon::fromTheme(normalized);
    if (!icon.isNull()) {
        return icon.pixmap(extent, extent);
    }

    QString iconName = iconNameFromDesktopFile(normalized);
    if (!iconName.isEmpty()) {
        icon = QIcon::fromTheme(iconName);
        if (!icon.isNull()) {
            return icon.pixmap(extent, extent);
        }
        if (QFile::exists(iconName)) {
            QPixmap pm(iconName);
            if (!pm.isNull()) {
                return pm.scaled(extent, extent, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            }
        }
    }

    if (normalized.contains(QLatin1Char('.'))) {
        const QString lastSegment = normalized.section(QLatin1Char('.'), -1);
        icon = QIcon::fromTheme(lastSegment);
        if (!icon.isNull()) {
            return icon.pixmap(extent, extent);
        }
    }

    // Fallback: letter avatar
    QPixmap fallback(extent, extent);
    fallback.fill(Qt::transparent);

    QPainter p(&fallback);
    p.setRenderHint(QPainter::Antialiasing);

    const qreal radius = extent * 0.2;
    QRectF rect(0, 0, extent, extent);

    p.setBrush(QColor(255, 255, 255, 20));
    p.setPen(Qt::NoPen);
    p.drawRoundedRect(rect, radius, radius);

    p.setPen(QColor(255, 255, 255, 180));
    QFont font;
    font.setPixelSize(extent * 0.42);
    font.setWeight(QFont::Medium);
    p.setFont(font);

    const QString letter = id.isEmpty() ? QStringLiteral("?") : id.left(1).toUpper();
    p.drawText(rect, Qt::AlignCenter, letter);
    p.end();

    return fallback;
}

QString AppIconProvider::iconNameFromDesktopFile(const QString &id) const {
    const QString path = findDesktopFile(id);
    if (path.isEmpty()) return {};

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return {};

    QTextStream stream(&file);
    bool inDesktopEntry = false;

    while (!stream.atEnd()) {
        const QString line = stream.readLine().trimmed();
        if (line.startsWith(QLatin1Char('['))) {
            inDesktopEntry = (line == QStringLiteral("[Desktop Entry]"));
            continue;
        }
        if (inDesktopEntry && line.startsWith(QStringLiteral("Icon="))) {
            return line.mid(5).trimmed();
        }
    }

    return {};
}

QString AppIconProvider::findDesktopFile(const QString &id) const {
    QStringList candidates;

    QString withSuffix = id;
    if (!withSuffix.endsWith(QStringLiteral(".desktop"))) {
        withSuffix += QStringLiteral(".desktop");
    }
    candidates << withSuffix;
    candidates << withSuffix.toLower();

    if (!id.contains(QLatin1Char('.'))) {
        candidates << id.toLower() + QStringLiteral(".desktop");
    }

    const QStringList dataDirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);

    for (const QString &dir : dataDirs) {
        for (const QString &candidate : candidates) {
            const QString fullPath = dir + QLatin1Char('/') + candidate;
            if (QFile::exists(fullPath)) {
                return fullPath;
            }
        }

        QDir d(dir);
        const QStringList entries = d.entryList(QDir::Files);
        for (const QString &entry : entries) {
            if (entry.toLower().contains(id.toLower()) && entry.endsWith(QStringLiteral(".desktop"))) {
                return dir + QLatin1Char('/') + entry;
            }
        }
    }

    return {};
}

} // namespace ciderdeck
