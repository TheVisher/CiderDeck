#pragma once

#include <QObject>

#ifdef HAVE_KF6PULSEAUDIOQT
namespace PulseAudioQt {
class Sink;
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

    // Default sink properties (for simple volume tile)
    Q_PROPERTY(int defaultVolume READ defaultVolume NOTIFY defaultVolumeChanged)
    Q_PROPERTY(bool defaultMuted READ defaultMuted NOTIFY defaultMutedChanged)
    Q_PROPERTY(QString defaultSinkName READ defaultSinkName NOTIFY defaultSinkChanged)

public:
    explicit AudioManager(QObject *parent = nullptr);

    QObject *sinkModel() const;
    QObject *sinkInputModel() const;
    QObject *sourceModel() const;

    int defaultVolume() const { return defaultVolume_; }
    bool defaultMuted() const { return defaultMuted_; }
    QString defaultSinkName() const { return defaultSinkName_; }

    // Operate on default sink
    Q_INVOKABLE void setDefaultVolume(int percent);
    Q_INVOKABLE void setDefaultMuted(bool muted);

    // Operate by model index (for advanced per-device control)
    Q_INVOKABLE void setSinkVolume(int index, int volume);
    Q_INVOKABLE void setSinkMuted(int index, bool muted);
    Q_INVOKABLE void setSinkInputVolume(int index, int volume);
    Q_INVOKABLE void setSinkInputMuted(int index, bool muted);

signals:
    void defaultVolumeChanged();
    void defaultMutedChanged();
    void defaultSinkChanged();

private:
#ifdef HAVE_KF6PULSEAUDIOQT
    void connectToDefaultSink();
    void updateFromDefaultSink();

    PulseAudioQt::SinkModel *sinkModel_ = nullptr;
    PulseAudioQt::SinkInputModel *sinkInputModel_ = nullptr;
    PulseAudioQt::SourceModel *sourceModel_ = nullptr;
    PulseAudioQt::Sink *currentDefaultSink_ = nullptr;
#endif
    int defaultVolume_ = 100;
    bool defaultMuted_ = false;
    QString defaultSinkName_;
};

} // namespace ciderdeck
