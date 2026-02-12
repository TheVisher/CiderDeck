#pragma once

#include <QObject>

#ifdef HAVE_KF6PULSEAUDIOQT
namespace PulseAudioQt {
class SinkModel;
class SinkInputModel;
class SourceModel;
}
#endif

namespace ciderdeck {

class AudioManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject *sinkModel READ sinkModel CONSTANT)
    Q_PROPERTY(QObject *sinkInputModel READ sinkInputModel CONSTANT)
    Q_PROPERTY(QObject *sourceModel READ sourceModel CONSTANT)

public:
    explicit AudioManager(QObject *parent = nullptr);

    QObject *sinkModel() const;
    QObject *sinkInputModel() const;
    QObject *sourceModel() const;

    Q_INVOKABLE void setSinkVolume(int index, int volume);
    Q_INVOKABLE void setSinkMuted(int index, bool muted);
    Q_INVOKABLE void setSinkInputVolume(int index, int volume);
    Q_INVOKABLE void setSinkInputMuted(int index, bool muted);

private:
#ifdef HAVE_KF6PULSEAUDIOQT
    PulseAudioQt::SinkModel *sinkModel_ = nullptr;
    PulseAudioQt::SinkInputModel *sinkInputModel_ = nullptr;
    PulseAudioQt::SourceModel *sourceModel_ = nullptr;
#endif
};

} // namespace ciderdeck
