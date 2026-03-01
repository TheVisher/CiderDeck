#include "AudioManager.h"

#ifdef HAVE_KF6PULSEAUDIOQT
#include <PulseAudioQt/context.h>
#include <PulseAudioQt/models.h>
#include <PulseAudioQt/server.h>
#include <PulseAudioQt/sink.h>
#include <PulseAudioQt/sinkinput.h>
#include <PulseAudioQt/source.h>
#include <PulseAudioQt/sourceoutput.h>
#endif

namespace ciderdeck {

AudioManager::AudioManager(QObject *parent)
    : QObject(parent) {
#ifdef HAVE_KF6PULSEAUDIOQT
    sinkModel_ = new PulseAudioQt::SinkModel(this);
    sinkInputModel_ = new PulseAudioQt::SinkInputModel(this);
    sourceModel_ = new PulseAudioQt::SourceModel(this);
    sourceOutputModel_ = new PulseAudioQt::SourceOutputModel(this);

    // Connect to server's default sink changes
    auto *ctx = PulseAudioQt::Context::instance();
    auto *server = ctx->server();
    connect(server, &PulseAudioQt::Server::defaultSinkChanged, this, [this](PulseAudioQt::Sink *) {
        connectToDefaultSink();
    });

    // Also try connecting once the context is ready
    connect(ctx, &PulseAudioQt::Context::stateChanged, this, [this]() {
        auto *ctx2 = PulseAudioQt::Context::instance();
        if (ctx2->state() == PulseAudioQt::Context::State::Ready) {
            connectToDefaultSink();
        }
    });

    // Increment refreshTick_ on any sink input model change so QML can react
    auto bumpTick = [this]() {
        ++refreshTick_;
        emit refreshTickChanged();
    };
    connect(sinkInputModel_, &QAbstractItemModel::rowsInserted, this, bumpTick);
    connect(sinkInputModel_, &QAbstractItemModel::rowsRemoved,  this, bumpTick);
    connect(sinkInputModel_, &QAbstractItemModel::dataChanged,  this, bumpTick);

    // Try immediately in case context is already ready
    connectToDefaultSink();
#endif
}

#ifdef HAVE_KF6PULSEAUDIOQT
void AudioManager::connectToDefaultSink() {
    auto *server = PulseAudioQt::Context::instance()->server();
    auto *sink = server->defaultSink();

    if (sink == currentDefaultSink_) {
        // Same sink, just update values
        updateFromDefaultSink();
        return;
    }

    // Disconnect old sink signals
    if (currentDefaultSink_) {
        disconnect(currentDefaultSink_, nullptr, this, nullptr);
    }

    currentDefaultSink_ = sink;

    if (!sink) {
        defaultSinkName_.clear();
        emit defaultSinkChanged();
        return;
    }

    defaultSinkName_ = sink->description();
    emit defaultSinkChanged();

    // Connect to volume/mute changes on the new default sink
    connect(sink, &PulseAudioQt::Sink::volumeChanged, this, &AudioManager::updateFromDefaultSink);
    connect(sink, &PulseAudioQt::Sink::mutedChanged, this, &AudioManager::updateFromDefaultSink);

    updateFromDefaultSink();
}

void AudioManager::updateFromDefaultSink() {
    if (!currentDefaultSink_) return;

    qint64 normalVol = PulseAudioQt::normalVolume();
    int vol = normalVol > 0 ? qRound(100.0 * currentDefaultSink_->volume() / normalVol) : 0;
    vol = qBound(0, vol, 150); // allow >100% like PA does

    if (vol != defaultVolume_) {
        defaultVolume_ = vol;
        emit defaultVolumeChanged();
    }

    bool muted = currentDefaultSink_->isMuted();
    if (muted != defaultMuted_) {
        defaultMuted_ = muted;
        emit defaultMutedChanged();
    }
}
#endif

QObject *AudioManager::sinkModel() const {
#ifdef HAVE_KF6PULSEAUDIOQT
    return sinkModel_;
#else
    return nullptr;
#endif
}

QObject *AudioManager::sinkInputModel() const {
#ifdef HAVE_KF6PULSEAUDIOQT
    return sinkInputModel_;
#else
    return nullptr;
#endif
}

QObject *AudioManager::sourceModel() const {
#ifdef HAVE_KF6PULSEAUDIOQT
    return sourceModel_;
#else
    return nullptr;
#endif
}

QObject *AudioManager::sourceOutputModel() const {
#ifdef HAVE_KF6PULSEAUDIOQT
    return sourceOutputModel_;
#else
    return nullptr;
#endif
}

void AudioManager::setDefaultVolume(int percent) {
#ifdef HAVE_KF6PULSEAUDIOQT
    if (!currentDefaultSink_) return;
    percent = qBound(0, percent, 150);
    qint64 normalVol = PulseAudioQt::normalVolume();
    qint64 paVolume = static_cast<qint64>(percent) * normalVol / 100;
    currentDefaultSink_->setVolume(paVolume);
#else
    Q_UNUSED(percent)
#endif
}

void AudioManager::setDefaultMuted(bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    if (!currentDefaultSink_) return;
    currentDefaultSink_->setMuted(muted);
#else
    Q_UNUSED(muted)
#endif
}

void AudioManager::setSinkVolume(int index, int volume) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sinkModel_->index(index, 0);
    auto *sink = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::Sink *>();
    if (sink) {
        qint64 normalVol = PulseAudioQt::normalVolume();
        qint64 paVolume = static_cast<qint64>(volume) * normalVol / 100;
        sink->setVolume(paVolume);
    }
#else
    Q_UNUSED(index) Q_UNUSED(volume)
#endif
}

void AudioManager::setSinkMuted(int index, bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sinkModel_->index(index, 0);
    auto *sink = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::Sink *>();
    if (sink) {
        sink->setMuted(muted);
    }
#else
    Q_UNUSED(index) Q_UNUSED(muted)
#endif
}

void AudioManager::setSinkInputVolume(int index, int volume) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sinkInputModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::SinkInput *>();
    if (obj) {
        qint64 normalVol = PulseAudioQt::normalVolume();
        qint64 paVolume = static_cast<qint64>(volume) * normalVol / 100;
        obj->setVolume(paVolume);
    }
#else
    Q_UNUSED(index) Q_UNUSED(volume)
#endif
}

void AudioManager::setSinkInputMuted(int index, bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sinkInputModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::SinkInput *>();
    if (obj) {
        obj->setMuted(muted);
    }
#else
    Q_UNUSED(index) Q_UNUSED(muted)
#endif
}

void AudioManager::setSourceVolume(int index, int volume) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sourceModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::Source *>();
    if (obj) {
        qint64 normalVol = PulseAudioQt::normalVolume();
        qint64 paVolume = static_cast<qint64>(volume) * normalVol / 100;
        obj->setVolume(paVolume);
    }
#else
    Q_UNUSED(index) Q_UNUSED(volume)
#endif
}

void AudioManager::setSourceMuted(int index, bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sourceModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::Source *>();
    if (obj) {
        obj->setMuted(muted);
    }
#else
    Q_UNUSED(index) Q_UNUSED(muted)
#endif
}

void AudioManager::setSourceOutputVolume(int index, int volume) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sourceOutputModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::SourceOutput *>();
    if (obj) {
        qint64 normalVol = PulseAudioQt::normalVolume();
        qint64 paVolume = static_cast<qint64>(volume) * normalVol / 100;
        obj->setVolume(paVolume);
    }
#else
    Q_UNUSED(index) Q_UNUSED(volume)
#endif
}

void AudioManager::setSourceOutputMuted(int index, bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sourceOutputModel_->index(index, 0);
    auto *obj = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::SourceOutput *>();
    if (obj) {
        obj->setMuted(muted);
    }
#else
    Q_UNUSED(index) Q_UNUSED(muted)
#endif
}

// ---------------------------------------------------------------------------
// Generic device access helpers
// ---------------------------------------------------------------------------

#ifdef HAVE_KF6PULSEAUDIOQT
// Internal helper: resolve (type, index) to an AbstractModel and the typed PA object.
// Returns the PulseObject* cast to QObject so callers can downcast as needed.
// Returns nullptr on out-of-range or unknown type.
static PulseAudioQt::AbstractModel *modelForType(
    const QString &type,
    PulseAudioQt::SinkModel *sinkModel,
    PulseAudioQt::SinkInputModel *sinkInputModel,
    PulseAudioQt::SourceModel *sourceModel,
    PulseAudioQt::SourceOutputModel *sourceOutputModel)
{
    if (type == QLatin1String("sink"))         return sinkModel;
    if (type == QLatin1String("source"))       return sourceModel;
    if (type == QLatin1String("sinkInput"))    return sinkInputModel;
    if (type == QLatin1String("sourceOutput")) return sourceOutputModel;
    return nullptr;
}
#endif

int AudioManager::deviceCount(const QString &type) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    return model ? model->rowCount() : 0;
#else
    Q_UNUSED(type)
    return 0;
#endif
}

QString AudioManager::deviceName(const QString &type, int index) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return {};
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return {};
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::PulseObject *>();
    return obj ? obj->name() : QString{};
#else
    Q_UNUSED(type) Q_UNUSED(index)
    return {};
#endif
}

QString AudioManager::deviceDescription(const QString &type, int index) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return {};
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return {};
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::PulseObject *>();
    if (!obj) return {};

    // Device types carry a human-readable description; stream types do not.
    if (type == QLatin1String("sink") || type == QLatin1String("source")) {
        auto *dev = qobject_cast<PulseAudioQt::Device *>(obj);
        if (dev) return dev->description();
    }
    // For stream types fall back to the client name, then the PA object name.
    if (type == QLatin1String("sinkInput")) {
        auto *si = static_cast<PulseAudioQt::SinkInput *>(obj);
        if (si->client()) return si->client()->name();
    }
    if (type == QLatin1String("sourceOutput")) {
        auto *so = static_cast<PulseAudioQt::SourceOutput *>(obj);
        if (so->client()) return so->client()->name();
    }
    return obj->name();
#else
    Q_UNUSED(type) Q_UNUSED(index)
    return {};
#endif
}

QString AudioManager::deviceAppBinary(const QString &type, int index) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    // Only meaningful for stream types (sinkInput / sourceOutput).
    PulseAudioQt::AbstractModel *model = nullptr;
    if (type == QLatin1String("sinkInput"))
        model = sinkInputModel_;
    else if (type == QLatin1String("sourceOutput"))
        model = sourceOutputModel_;
    else
        return {};

    auto mi = model->index(index, 0);
    if (!mi.isValid()) return {};
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::PulseObject *>();
    if (!obj) return {};

    // PulseAudio stores the process binary in the "application.process.binary" property.
    return obj->properties().value(QStringLiteral("application.process.binary")).toString();
#else
    Q_UNUSED(type) Q_UNUSED(index)
    return {};
#endif
}

int AudioManager::deviceVolume(const QString &type, int index) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return 0;
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return 0;
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    if (!obj) return 0;
    qint64 normalVol = PulseAudioQt::normalVolume();
    return normalVol > 0 ? qBound(0, qRound(100.0 * obj->volume() / normalVol), 150) : 0;
#else
    Q_UNUSED(type) Q_UNUSED(index)
    return 0;
#endif
}

bool AudioManager::deviceMuted(const QString &type, int index) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return false;
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return false;
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    return obj ? obj->isMuted() : false;
#else
    Q_UNUSED(type) Q_UNUSED(index)
    return false;
#endif
}

void AudioManager::setDeviceVolume(const QString &type, int index, int percent) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return;
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return;
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    if (!obj) return;
    percent = qBound(0, percent, 150);
    qint64 normalVol = PulseAudioQt::normalVolume();
    obj->setVolume(static_cast<qint64>(percent) * normalVol / 100);
#else
    Q_UNUSED(type) Q_UNUSED(index) Q_UNUSED(percent)
#endif
}

void AudioManager::setDeviceMuted(const QString &type, int index, bool muted) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto *model = modelForType(type, sinkModel_, sinkInputModel_, sourceModel_, sourceOutputModel_);
    if (!model) return;
    auto mi = model->index(index, 0);
    if (!mi.isValid()) return;
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    if (obj) obj->setMuted(muted);
#else
    Q_UNUSED(type) Q_UNUSED(index) Q_UNUSED(muted)
#endif
}

// ---------------------------------------------------------------------------
// App-level stream helpers
// ---------------------------------------------------------------------------

// Return the app name for a stream PulseObject.  We prefer the client name
// (what PulseAudio associates with the registered PA client) and fall back to
// the "application.name" property, then the raw PA object name.
#ifdef HAVE_KF6PULSEAUDIOQT
static QString streamAppName(PulseAudioQt::PulseObject *obj) {
    // Try to get client name via Stream::client()
    if (auto *si = qobject_cast<PulseAudioQt::SinkInput *>(obj)) {
        if (si->client()) return si->client()->name();
    }
    if (auto *so = qobject_cast<PulseAudioQt::SourceOutput *>(obj)) {
        if (so->client()) return so->client()->name();
    }
    // Fallback: "application.name" PA property
    const QString appName = obj->properties().value(QStringLiteral("application.name")).toString();
    if (!appName.isEmpty()) return appName;
    return obj->name();
}
#endif

QVariantList AudioManager::findStreamsByApp(const QString &appName, const QString &streamType) const {
    QVariantList result;
#ifdef HAVE_KF6PULSEAUDIOQT
    if (appName.isEmpty()) return result;

    PulseAudioQt::AbstractModel *model =
        (streamType == QLatin1String("source")) ? static_cast<PulseAudioQt::AbstractModel *>(sourceOutputModel_)
                                                : static_cast<PulseAudioQt::AbstractModel *>(sinkInputModel_);

    const int count = model->rowCount();
    const QString needle = appName.toLower();
    for (int i = 0; i < count; ++i) {
        auto mi = model->index(i, 0);
        auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::PulseObject *>();
        if (!obj) continue;
        if (streamAppName(obj).toLower().contains(needle))
            result.append(i);
    }
#else
    Q_UNUSED(appName) Q_UNUSED(streamType)
#endif
    return result;
}

int AudioManager::appVolume(const QString &appName, const QString &streamType) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    const QVariantList indices = findStreamsByApp(appName, streamType);
    if (indices.isEmpty()) return 0;

    PulseAudioQt::AbstractModel *model =
        (streamType == QLatin1String("source")) ? static_cast<PulseAudioQt::AbstractModel *>(sourceOutputModel_)
                                                : static_cast<PulseAudioQt::AbstractModel *>(sinkInputModel_);

    const int idx = indices.first().toInt();
    auto mi = model->index(idx, 0);
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    if (!obj) return 0;
    qint64 normalVol = PulseAudioQt::normalVolume();
    return normalVol > 0 ? qBound(0, qRound(100.0 * obj->volume() / normalVol), 150) : 0;
#else
    Q_UNUSED(appName) Q_UNUSED(streamType)
    return 0;
#endif
}

bool AudioManager::appMuted(const QString &appName, const QString &streamType) const {
#ifdef HAVE_KF6PULSEAUDIOQT
    const QVariantList indices = findStreamsByApp(appName, streamType);
    if (indices.isEmpty()) return false;

    PulseAudioQt::AbstractModel *model =
        (streamType == QLatin1String("source")) ? static_cast<PulseAudioQt::AbstractModel *>(sourceOutputModel_)
                                                : static_cast<PulseAudioQt::AbstractModel *>(sinkInputModel_);

    const int idx = indices.first().toInt();
    auto mi = model->index(idx, 0);
    auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
    return obj ? obj->isMuted() : false;
#else
    Q_UNUSED(appName) Q_UNUSED(streamType)
    return false;
#endif
}

void AudioManager::setAppVolume(const QString &appName, int percent, const QString &streamType) {
#ifdef HAVE_KF6PULSEAUDIOQT
    const QVariantList indices = findStreamsByApp(appName, streamType);
    if (indices.isEmpty()) return;

    PulseAudioQt::AbstractModel *model =
        (streamType == QLatin1String("source")) ? static_cast<PulseAudioQt::AbstractModel *>(sourceOutputModel_)
                                                : static_cast<PulseAudioQt::AbstractModel *>(sinkInputModel_);

    percent = qBound(0, percent, 150);
    qint64 normalVol = PulseAudioQt::normalVolume();
    const qint64 paVolume = static_cast<qint64>(percent) * normalVol / 100;

    for (const QVariant &v : indices) {
        auto mi = model->index(v.toInt(), 0);
        auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
        if (obj) obj->setVolume(paVolume);
    }
#else
    Q_UNUSED(appName) Q_UNUSED(percent) Q_UNUSED(streamType)
#endif
}

void AudioManager::setAppMuted(const QString &appName, bool muted, const QString &streamType) {
#ifdef HAVE_KF6PULSEAUDIOQT
    const QVariantList indices = findStreamsByApp(appName, streamType);
    if (indices.isEmpty()) return;

    PulseAudioQt::AbstractModel *model =
        (streamType == QLatin1String("source")) ? static_cast<PulseAudioQt::AbstractModel *>(sourceOutputModel_)
                                                : static_cast<PulseAudioQt::AbstractModel *>(sinkInputModel_);

    for (const QVariant &v : indices) {
        auto mi = model->index(v.toInt(), 0);
        auto *obj = mi.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::VolumeObject *>();
        if (obj) obj->setMuted(muted);
    }
#else
    Q_UNUSED(appName) Q_UNUSED(muted) Q_UNUSED(streamType)
#endif
}

} // namespace ciderdeck
