#pragma once

#include <QAbstractListModel>
#include <QSortFilterProxyModel>

namespace ciderdeck {

struct AppEntry {
    QString name;
    QString icon;
    QString desktopFile; // basename, e.g. "firefox.desktop"
    QString exec;
};

class InstalledAppsModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconRole,
        DesktopFileRole,
        ExecRole,
    };

    explicit InstalledAppsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void refresh();

private:
    void scanDirectory(const QString &dir);

    QList<AppEntry> apps_;
};

class AppFilterModel : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)

public:
    explicit AppFilterModel(QObject *parent = nullptr);

    QString filterText() const { return filterText_; }
    void setFilterText(const QString &text);

signals:
    void filterTextChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    QString filterText_;
};

} // namespace ciderdeck
