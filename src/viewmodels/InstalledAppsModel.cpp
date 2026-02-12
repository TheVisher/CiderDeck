#include "InstalledAppsModel.h"

#include <QDir>
#include <QSettings>
#include <QStandardPaths>
#include <algorithm>

namespace ciderdeck {

InstalledAppsModel::InstalledAppsModel(QObject *parent)
    : QAbstractListModel(parent) {
    refresh();
}

int InstalledAppsModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return apps_.size();
}

QVariant InstalledAppsModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= apps_.size()) return {};

    const auto &app = apps_[index.row()];
    switch (role) {
    case NameRole:        return app.name;
    case IconRole:        return app.icon;
    case DesktopFileRole: return app.desktopFile;
    case ExecRole:        return app.exec;
    default:              return {};
    }
}

QHash<int, QByteArray> InstalledAppsModel::roleNames() const {
    return {
        {NameRole, "appName"},
        {IconRole, "appIcon"},
        {DesktopFileRole, "desktopFile"},
        {ExecRole, "appExec"},
    };
}

void InstalledAppsModel::refresh() {
    beginResetModel();
    apps_.clear();

    // Scan standard XDG application directories
    scanDirectory(QStringLiteral("/usr/share/applications"));
    scanDirectory(QStringLiteral("/usr/local/share/applications"));
    scanDirectory(QDir::homePath() + QStringLiteral("/.local/share/applications"));

    // Also scan flatpak exports
    scanDirectory(QStringLiteral("/var/lib/flatpak/exports/share/applications"));
    scanDirectory(QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/applications"));

    // Sort alphabetically by name
    std::sort(apps_.begin(), apps_.end(), [](const AppEntry &a, const AppEntry &b) {
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    endResetModel();
}

void InstalledAppsModel::scanDirectory(const QString &dirPath) {
    QDir dir(dirPath);
    if (!dir.exists()) return;

    const auto entries = dir.entryInfoList({QStringLiteral("*.desktop")}, QDir::Files);
    for (const auto &fileInfo : entries) {
        // Parse .desktop file using QSettings (INI format)
        QSettings desktop(fileInfo.filePath(), QSettings::IniFormat);
        desktop.beginGroup(QStringLiteral("Desktop Entry"));

        // Skip hidden entries and entries without a name
        if (desktop.value(QStringLiteral("NoDisplay")).toBool()) continue;
        if (desktop.value(QStringLiteral("Hidden")).toBool()) continue;

        QString name = desktop.value(QStringLiteral("Name")).toString();
        if (name.isEmpty()) continue;

        QString type = desktop.value(QStringLiteral("Type")).toString();
        if (type != QLatin1String("Application")) continue;

        // Check if this basename is already present (prefer first found)
        QString basename = fileInfo.fileName();
        bool duplicate = false;
        for (const auto &existing : apps_) {
            if (existing.desktopFile == basename) {
                duplicate = true;
                break;
            }
        }
        if (duplicate) continue;

        AppEntry entry;
        entry.name = name;
        entry.icon = desktop.value(QStringLiteral("Icon")).toString();
        entry.desktopFile = basename;
        entry.exec = desktop.value(QStringLiteral("Exec")).toString();

        apps_.append(std::move(entry));
    }
}

// --- AppFilterModel ---

AppFilterModel::AppFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent) {
    setFilterCaseSensitivity(Qt::CaseInsensitive);
}

void AppFilterModel::setFilterText(const QString &text) {
    if (filterText_ == text) return;
    filterText_ = text;
    emit filterTextChanged();
    beginFilterChange();
    endFilterChange();
}

bool AppFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const {
    if (filterText_.isEmpty()) return true;

    auto model = sourceModel();
    if (!model) return true;

    auto idx = model->index(sourceRow, 0, sourceParent);
    QString name = idx.data(InstalledAppsModel::NameRole).toString();
    QString desktop = idx.data(InstalledAppsModel::DesktopFileRole).toString();

    return name.contains(filterText_, Qt::CaseInsensitive) ||
           desktop.contains(filterText_, Qt::CaseInsensitive);
}

} // namespace ciderdeck
