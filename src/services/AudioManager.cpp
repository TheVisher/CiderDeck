#include "AudioManager.h"

#ifdef HAVE_KF6PULSEAUDIOQT
#include <PulseAudioQt/context.h>
#include <PulseAudioQt/models.h>
#include <PulseAudioQt/server.h>
#include <PulseAudioQt/sink.h>
#include <PulseAudioQt/sinkinput.h>
#endif

namespace ciderdeck {

AudioManager::AudioManager(QObject *parent)
    : QObject(parent) {
#ifdef HAVE_KF6PULSEAUDIOQT
    sinkModel_ = new PulseAudioQt::SinkModel(this);
    sinkInputModel_ = new PulseAudioQt::SinkInputModel(this);
    sourceModel_ = new PulseAudioQt::SourceModel(this);

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

} // namespace ciderdeck
