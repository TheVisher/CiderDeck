#include "AudioMixerService.h"
#include "AudioManager.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>

#ifdef HAVE_KF6PULSEAUDIOQT
#include <PulseAudioQt/context.h>
#include <PulseAudioQt/models.h>
#include <PulseAudioQt/client.h>
#include <PulseAudioQt/sinkinput.h>
#include <PulseAudioQt/source.h>
#endif

namespace ciderdeck {

AudioMixerService::AudioMixerService(AudioManager *audioManager, QObject *parent)
    : QObject(parent)
    , audioManager_(audioManager)
{
    // Check if easyeffects is available for EQ support
    QProcess probe;
    probe.start(QStringLiteral("which"), {QStringLiteral("easyeffects")});
    probe.waitForFinished(3000);
    eqAvailable_ = (probe.exitCode() == 0);

#ifdef HAVE_KF6PULSEAUDIOQT
    // Connect to sink input model's rowsInserted to apply group volumes to new streams
    QObject *simObj = audioManager_->sinkInputModel();
    if (simObj) {
        auto *sim = static_cast<PulseAudioQt::SinkInputModel *>(simObj);
        connect(sim, &PulseAudioQt::SinkInputModel::rowsInserted,
                this, &AudioMixerService::onSinkInputAdded);
    }

    // Monitor default source for mic volume/muted changes
    QObject *srcObj = audioManager_->sourceModel();
    if (srcObj) {
        auto *srcModel = static_cast<PulseAudioQt::SourceModel *>(srcObj);
        connect(srcModel, &PulseAudioQt::SourceModel::dataChanged,
                this, [this](const QModelIndex &, const QModelIndex &, const QList<int> &) {
            updateMicFromSource();
        });
        connect(srcModel, &PulseAudioQt::SourceModel::rowsInserted,
                this, [this](const QModelIndex &, int, int) {
            updateMicFromSource();
        });
    }

    // Initial mic read
    updateMicFromSource();
#endif

    loadConfig();

    if (eqAvailable_) {
        refreshEqPresets();
    }
}

// ---------------------------------------------------------------------------
// Config persistence
// ---------------------------------------------------------------------------

QString AudioMixerService::configPath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                        + QStringLiteral("/ciderdeck");
    QDir().mkpath(dir);
    return dir + QStringLiteral("/mixer.json");
}

void AudioMixerService::loadConfig()
{
    QFile file(configPath());
    if (!file.open(QIODevice::ReadOnly)) {
        ensureDefaultGroups();
        return;
    }

    const auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray()) {
        ensureDefaultGroups();
        return;
    }

    groups_.clear();
    const auto arr = doc.array();
    for (const auto &val : arr) {
        const auto obj = val.toObject();
        Group g;
        g.name      = obj[QStringLiteral("name")].toString();
        g.volume    = obj[QStringLiteral("volume")].toInt(100);
        g.muted     = obj[QStringLiteral("muted")].toBool(false);
        g.isGeneral = obj[QStringLiteral("isGeneral")].toBool(false);

        const auto appsArr = obj[QStringLiteral("apps")].toArray();
        for (const auto &a : appsArr) {
            g.apps.append(a.toString());
        }
        groups_.append(g);
    }

    if (groups_.isEmpty()) {
        ensureDefaultGroups();
        return;
    }

    emit groupsChanged();
}

void AudioMixerService::saveConfig()
{
    QJsonArray arr;
    for (const auto &g : groups_) {
        QJsonArray appsArr;
        for (const auto &app : g.apps) {
            appsArr.append(app);
        }
        QJsonObject obj;
        obj[QStringLiteral("name")]      = g.name;
        obj[QStringLiteral("volume")]    = g.volume;
        obj[QStringLiteral("muted")]     = g.muted;
        obj[QStringLiteral("isGeneral")] = g.isGeneral;
        obj[QStringLiteral("apps")]      = appsArr;
        arr.append(obj);
    }

    QFile file(configPath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
    }
}

void AudioMixerService::ensureDefaultGroups()
{
    groups_.clear();

    Group general;
    general.name      = QStringLiteral("General");
    general.isGeneral = true;
    groups_.append(general);

    Group gaming;
    gaming.name = QStringLiteral("Gaming");
    groups_.append(gaming);

    Group media;
    media.name = QStringLiteral("Media");
    groups_.append(media);

    Group comms;
    comms.name = QStringLiteral("Communication");
    groups_.append(comms);

    saveConfig();
    emit groupsChanged();
}

// ---------------------------------------------------------------------------
// Q_PROPERTY accessor
// ---------------------------------------------------------------------------

QVariantList AudioMixerService::groups() const
{
    QVariantList result;
    result.reserve(groups_.size());
    for (const auto &g : groups_) {
        QVariantMap map;
        map[QStringLiteral("name")]      = g.name;
        map[QStringLiteral("volume")]    = g.volume;
        map[QStringLiteral("muted")]     = g.muted;
        map[QStringLiteral("isGeneral")] = g.isGeneral;

        QVariantList apps;
        apps.reserve(g.apps.size());
        for (const auto &app : g.apps) {
            apps.append(app);
        }
        map[QStringLiteral("apps")] = apps;

        result.append(map);
    }
    return result;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

int AudioMixerService::matchGroup(const QString &appName) const
{
    for (int i = 0; i < groups_.size(); ++i) {
        if (groups_[i].isGeneral) continue;
        if (groups_[i].apps.contains(appName)) {
            return i;
        }
    }
    return -1;
}

// ---------------------------------------------------------------------------
// PulseAudio sink-input slot
// ---------------------------------------------------------------------------

void AudioMixerService::onSinkInputAdded(const QModelIndex &parent, int first, int last)
{
    Q_UNUSED(parent)
#ifdef HAVE_KF6PULSEAUDIOQT
    QObject *simObj = audioManager_->sinkInputModel();
    if (!simObj) return;
    auto *sim = static_cast<PulseAudioQt::SinkInputModel *>(simObj);

    qint64 normalVol = PulseAudioQt::normalVolume();
    if (normalVol <= 0) return;

    for (int row = first; row <= last; ++row) {
        const auto idx = sim->index(row, 0);
        auto *si = idx.data(PulseAudioQt::AbstractModel::PulseObjectRole)
                       .value<PulseAudioQt::SinkInput *>();
        if (!si) continue;

        const QString appName = si->name();
        if (appName.isEmpty()) continue;

        int gi = matchGroup(appName);

        // If no specific group matched, use General (first isGeneral group)
        if (gi < 0) {
            for (int i = 0; i < groups_.size(); ++i) {
                if (groups_[i].isGeneral) { gi = i; break; }
            }
        }
        if (gi < 0) continue;

        const auto &g = groups_[gi];
        qint64 paVolume = static_cast<qint64>(g.volume) * normalVol / 100;
        si->setVolume(paVolume);
        si->setMuted(g.muted);
    }
#else
    Q_UNUSED(first) Q_UNUSED(last)
#endif
}

// ---------------------------------------------------------------------------
// Group volume / mute control
// ---------------------------------------------------------------------------

void AudioMixerService::setGroupVolume(int groupIndex, int percent)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    percent = qBound(0, percent, 150);
    groups_[groupIndex].volume = percent;

    for (const auto &app : groups_[groupIndex].apps) {
        audioManager_->setAppVolume(app, percent);
    }

    // For the General group also apply to unassigned apps
    if (groups_[groupIndex].isGeneral) {
        const QStringList unassigned = unassignedApps();
        for (const auto &app : unassigned) {
            audioManager_->setAppVolume(app, percent);
        }
    }

    emit groupsChanged();
    saveConfig();
}

void AudioMixerService::setGroupMuted(int groupIndex, bool muted)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    groups_[groupIndex].muted = muted;

    for (const auto &app : groups_[groupIndex].apps) {
        audioManager_->setAppMuted(app, muted);
    }

    if (groups_[groupIndex].isGeneral) {
        const QStringList unassigned = unassignedApps();
        for (const auto &app : unassigned) {
            audioManager_->setAppMuted(app, muted);
        }
    }

    emit groupsChanged();
    saveConfig();
}

// ---------------------------------------------------------------------------
// Group management
// ---------------------------------------------------------------------------

void AudioMixerService::addGroup(const QString &name)
{
    if (name.isEmpty()) return;
    Group g;
    g.name = name;
    groups_.append(g);
    emit groupsChanged();
    saveConfig();
}

void AudioMixerService::removeGroup(int groupIndex)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    // Don't remove the General group
    if (groups_[groupIndex].isGeneral) return;
    groups_.removeAt(groupIndex);
    emit groupsChanged();
    saveConfig();
}

void AudioMixerService::renameGroup(int groupIndex, const QString &name)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    if (name.isEmpty()) return;
    groups_[groupIndex].name = name;
    emit groupsChanged();
    saveConfig();
}

// ---------------------------------------------------------------------------
// App-to-group assignment
// ---------------------------------------------------------------------------

void AudioMixerService::addAppToGroup(int groupIndex, const QString &appName)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    if (appName.isEmpty()) return;
    if (groups_[groupIndex].apps.contains(appName)) return;
    groups_[groupIndex].apps.append(appName);
    emit groupsChanged();
    saveConfig();
}

void AudioMixerService::removeAppFromGroup(int groupIndex, const QString &appName)
{
    if (groupIndex < 0 || groupIndex >= groups_.size()) return;
    groups_[groupIndex].apps.removeAll(appName);
    emit groupsChanged();
    saveConfig();
}

void AudioMixerService::moveAppToGroup(const QString &appName, int targetGroupIndex)
{
    if (targetGroupIndex < 0 || targetGroupIndex >= groups_.size()) return;
    if (appName.isEmpty()) return;

    // Remove from any existing group
    for (auto &g : groups_) {
        g.apps.removeAll(appName);
    }

    // Add to target group (unless target is General — unassigned means General)
    if (!groups_[targetGroupIndex].isGeneral) {
        groups_[targetGroupIndex].apps.append(appName);
    }

    emit groupsChanged();
    saveConfig();
}

// ---------------------------------------------------------------------------
// Mic controls
// ---------------------------------------------------------------------------

void AudioMixerService::setMicVolume(int percent)
{
    percent = qBound(0, percent, 150);
#ifdef HAVE_KF6PULSEAUDIOQT
    QObject *srcObj = audioManager_->sourceModel();
    if (!srcObj) return;
    auto *srcModel = static_cast<PulseAudioQt::SourceModel *>(srcObj);

    qint64 normalVol = PulseAudioQt::normalVolume();
    if (normalVol <= 0) return;
    qint64 paVolume = static_cast<qint64>(percent) * normalVol / 100;

    for (int row = 0; row < srcModel->rowCount(); ++row) {
        const auto idx = srcModel->index(row, 0);
        auto *src = idx.data(PulseAudioQt::AbstractModel::PulseObjectRole)
                        .value<PulseAudioQt::Source *>();
        if (src && src->isDefault()) {
            src->setVolume(paVolume);
            break;
        }
    }
#else
    Q_UNUSED(percent)
#endif

    if (micVolume_ != percent) {
        micVolume_ = percent;
        emit micVolumeChanged();
    }
}

void AudioMixerService::setMicMuted(bool muted)
{
#ifdef HAVE_KF6PULSEAUDIOQT
    QObject *srcObj = audioManager_->sourceModel();
    if (!srcObj) return;
    auto *srcModel = static_cast<PulseAudioQt::SourceModel *>(srcObj);

    for (int row = 0; row < srcModel->rowCount(); ++row) {
        const auto idx = srcModel->index(row, 0);
        auto *src = idx.data(PulseAudioQt::AbstractModel::PulseObjectRole)
                        .value<PulseAudioQt::Source *>();
        if (src && src->isDefault()) {
            src->setMuted(muted);
            break;
        }
    }
#else
    Q_UNUSED(muted)
#endif

    if (micMuted_ != muted) {
        micMuted_ = muted;
        emit micMutedChanged();
    }
}

void AudioMixerService::updateMicFromSource()
{
#ifdef HAVE_KF6PULSEAUDIOQT
    QObject *srcObj = audioManager_->sourceModel();
    if (!srcObj) return;
    auto *srcModel = static_cast<PulseAudioQt::SourceModel *>(srcObj);

    qint64 normalVol = PulseAudioQt::normalVolume();
    if (normalVol <= 0) return;

    for (int row = 0; row < srcModel->rowCount(); ++row) {
        const auto idx = srcModel->index(row, 0);
        auto *src = idx.data(PulseAudioQt::AbstractModel::PulseObjectRole)
                        .value<PulseAudioQt::Source *>();
        if (!src || !src->isDefault()) continue;

        int vol = qBound(0, static_cast<int>(qRound(100.0 * src->volume() / normalVol)), 150);
        bool muted = src->isMuted();

        if (micVolume_ != vol) {
            micVolume_ = vol;
            emit micVolumeChanged();
        }
        if (micMuted_ != muted) {
            micMuted_ = muted;
            emit micMutedChanged();
        }
        break;
    }
#endif
}

// ---------------------------------------------------------------------------
// EQ preset management
// ---------------------------------------------------------------------------

void AudioMixerService::refreshEqPresets()
{
    if (!eqAvailable_) return;

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0) {
            const QString output = proc->readAllStandardOutput();
            eqPresets_.clear();
            const auto lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const auto &line : lines) {
                const QString preset = line.trimmed();
                if (!preset.isEmpty()) {
                    eqPresets_.append(preset);
                }
            }
            emit eqPresetsChanged();
        }
        proc->deleteLater();
    });
    proc->start(QStringLiteral("easyeffects"), {QStringLiteral("--list-presets")});
}

void AudioMixerService::loadEqPreset(const QString &name)
{
    if (!eqAvailable_ || name.isEmpty()) return;

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc, name](int exitCode, QProcess::ExitStatus) {
        if (exitCode == 0) {
            currentEqPreset_ = name;
            emit currentEqPresetChanged();
        }
        proc->deleteLater();
    });
    proc->start(QStringLiteral("easyeffects"), {QStringLiteral("--load-preset"), name});
}

// ---------------------------------------------------------------------------
// Sync all group volumes to PulseAudio
// ---------------------------------------------------------------------------

void AudioMixerService::syncGroupVolumes()
{
    for (int i = 0; i < groups_.size(); ++i) {
        const auto &g = groups_[i];
        const QStringList targets = g.isGeneral ? unassignedApps() : g.apps;
        for (const auto &app : targets) {
            audioManager_->setAppVolume(app, g.volume);
            audioManager_->setAppMuted(app, g.muted);
        }
    }
}

// ---------------------------------------------------------------------------
// Query helpers
// ---------------------------------------------------------------------------

QStringList AudioMixerService::activeAudioApps() const
{
    QStringList result;
#ifdef HAVE_KF6PULSEAUDIOQT
    QObject *simObj = audioManager_->sinkInputModel();
    if (!simObj) return result;
    auto *sim = static_cast<PulseAudioQt::SinkInputModel *>(simObj);

    for (int row = 0; row < sim->rowCount(); ++row) {
        const auto idx = sim->index(row, 0);
        auto *si = idx.data(PulseAudioQt::AbstractModel::PulseObjectRole)
                       .value<PulseAudioQt::SinkInput *>();
        if (!si) continue;
        // Use client name to match findStreamsByApp() resolution order
        QString name;
        if (si->client()) {
            name = si->client()->name();
        }
        if (name.isEmpty()) {
            name = si->properties().value(QStringLiteral("application.name")).toString();
        }
        if (name.isEmpty()) {
            name = si->name();
        }
        if (!name.isEmpty() && !result.contains(name)) {
            result.append(name);
        }
    }
#endif
    return result;
}

QStringList AudioMixerService::unassignedApps() const
{
    const QStringList active = activeAudioApps();
    QStringList result;
    for (const auto &app : active) {
        if (matchGroup(app) < 0) {
            result.append(app);
        }
    }
    return result;
}

QStringList AudioMixerService::groupNames() const
{
    QStringList result;
    result.reserve(groups_.size());
    for (const auto &g : groups_) {
        result.append(g.name);
    }
    return result;
}

} // namespace ciderdeck
