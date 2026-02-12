#include "AudioManager.h"

#ifdef HAVE_KF6PULSEAUDIOQT
#include <PulseAudioQt/models.h>
#include <PulseAudioQt/sink.h>
#include <PulseAudioQt/sinkinput.h>
#include <PulseAudioQt/context.h>
#endif

namespace ciderdeck {

AudioManager::AudioManager(QObject *parent)
    : QObject(parent) {
#ifdef HAVE_KF6PULSEAUDIOQT
    sinkModel_ = new PulseAudioQt::SinkModel(this);
    sinkInputModel_ = new PulseAudioQt::SinkInputModel(this);
    sourceModel_ = new PulseAudioQt::SourceModel(this);
#endif
}

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

void AudioManager::setSinkVolume(int index, int volume) {
#ifdef HAVE_KF6PULSEAUDIOQT
    auto modelIndex = sinkModel_->index(index, 0);
    auto *sink = modelIndex.data(PulseAudioQt::AbstractModel::PulseObjectRole).value<PulseAudioQt::Sink *>();
    if (sink) {
        // PulseAudio volume: 0 = silent, 65536 = 100%
        qint64 paVolume = static_cast<qint64>(volume) * 65536 / 100;
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
        qint64 paVolume = static_cast<qint64>(volume) * 65536 / 100;
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
