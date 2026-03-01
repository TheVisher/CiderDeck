#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QModelIndex>

namespace PulseAudioQt {
class SinkInput;
class Source;
}

namespace ciderdeck {

class AudioManager;

class AudioMixerService : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged)
    Q_PROPERTY(int micVolume READ micVolume NOTIFY micVolumeChanged)
    Q_PROPERTY(bool micMuted READ micMuted NOTIFY micMutedChanged)
    Q_PROPERTY(QStringList eqPresets READ eqPresets NOTIFY eqPresetsChanged)
    Q_PROPERTY(QString currentEqPreset READ currentEqPreset NOTIFY currentEqPresetChanged)
    Q_PROPERTY(bool eqAvailable READ eqAvailable CONSTANT)

public:
    // Represents one mixer group (a named collection of sink inputs)
    struct Group {
        QString   name;
        int       volume    = 100;
        bool      muted     = false;
        QStringList apps;
        bool      isGeneral = false; // true for the catch-all "General" group
    };

    explicit AudioMixerService(ciderdeck::AudioManager *audioManager,
                               QObject *parent = nullptr);

    // Q_PROPERTY accessors
    QVariantList groups() const;
    int          micVolume() const    { return micVolume_; }
    bool         micMuted()  const    { return micMuted_; }
    QStringList  eqPresets() const    { return eqPresets_; }
    QString      currentEqPreset() const { return currentEqPreset_; }
    bool         eqAvailable() const  { return eqAvailable_; }

    // Group management
    Q_INVOKABLE void setGroupVolume(int groupIndex, int percent);
    Q_INVOKABLE void setGroupMuted(int groupIndex, bool muted);
    Q_INVOKABLE void addGroup(const QString &name);
    Q_INVOKABLE void removeGroup(int groupIndex);
    Q_INVOKABLE void renameGroup(int groupIndex, const QString &name);

    // App-to-group assignment
    Q_INVOKABLE void addAppToGroup(int groupIndex, const QString &appName);
    Q_INVOKABLE void removeAppFromGroup(int groupIndex, const QString &appName);
    Q_INVOKABLE void moveAppToGroup(const QString &appName, int targetGroupIndex);

    // Mic controls
    Q_INVOKABLE void setMicVolume(int percent);
    Q_INVOKABLE void setMicMuted(bool muted);

    // EQ preset management
    Q_INVOKABLE void loadEqPreset(const QString &name);
    Q_INVOKABLE void refreshEqPresets();

    // Sync all group volumes to PulseAudio
    Q_INVOKABLE void syncGroupVolumes();

    // Query helpers
    Q_INVOKABLE QStringList unassignedApps() const;
    Q_INVOKABLE QStringList activeAudioApps() const;
    Q_INVOKABLE QStringList groupNames() const;

signals:
    void groupsChanged();
    void micVolumeChanged();
    void micMutedChanged();
    void eqPresetsChanged();
    void currentEqPresetChanged();

private:
    // Config persistence
    QString configPath() const;
    void    loadConfig();
    void    saveConfig();

    // Bootstrap the default group set if none exist
    void ensureDefaultGroups();

    // Return the index of the group that owns appName, or -1
    int matchGroup(const QString &appName) const;

    // PulseAudio sink-input model slots
    void onSinkInputAdded(const QModelIndex &parent, int first, int last);

    // Refresh micVolume_ / micMuted_ from the default source
    void updateMicFromSource();

    // Owned data
    QList<Group> groups_;

    int     micVolume_      = 100;
    bool    micMuted_       = false;
    QStringList eqPresets_;
    QString currentEqPreset_;
    bool    eqAvailable_    = false;

    // Non-owning pointer to the shared AudioManager
    AudioManager *audioManager_ = nullptr;
};

} // namespace ciderdeck
