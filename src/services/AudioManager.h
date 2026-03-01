#pragma once

#include <QObject>
#include <QVariantList>

#ifdef HAVE_KF6PULSEAUDIOQT
namespace PulseAudioQt {
class Sink;
class SinkModel;
class SinkInputModel;
class Source;
class SourceModel;
class SourceOutputModel;
}
#endif

namespace ciderdeck {

class AudioManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject *sinkModel READ sinkModel CONSTANT)
    Q_PROPERTY(QObject *sinkInputModel READ sinkInputModel CONSTANT)
    Q_PROPERTY(QObject *sourceModel READ sourceModel CONSTANT)
    Q_PROPERTY(QObject *sourceOutputModel READ sourceOutputModel CONSTANT)

    // Default sink properties (for simple volume tile)
    Q_PROPERTY(int defaultVolume READ defaultVolume NOTIFY defaultVolumeChanged)
    Q_PROPERTY(bool defaultMuted READ defaultMuted NOTIFY defaultMutedChanged)
    Q_PROPERTY(QString defaultSinkName READ defaultSinkName NOTIFY defaultSinkChanged)
    Q_PROPERTY(int refreshTick READ refreshTick NOTIFY refreshTickChanged)

public:
    explicit AudioManager(QObject *parent = nullptr);

    QObject *sinkModel() const;
    QObject *sinkInputModel() const;
    QObject *sourceModel() const;
    QObject *sourceOutputModel() const;

    int defaultVolume() const { return defaultVolume_; }
    bool defaultMuted() const { return defaultMuted_; }
    QString defaultSinkName() const { return defaultSinkName_; }
    int refreshTick() const { return refreshTick_; }

    // Operate on default sink
    Q_INVOKABLE void setDefaultVolume(int percent);
    Q_INVOKABLE void setDefaultMuted(bool muted);

    // Operate by model index (for advanced per-device control)
    Q_INVOKABLE void setSinkVolume(int index, int volume);
    Q_INVOKABLE void setSinkMuted(int index, bool muted);
    Q_INVOKABLE void setSinkInputVolume(int index, int volume);
    Q_INVOKABLE void setSinkInputMuted(int index, bool muted);
    Q_INVOKABLE void setSourceVolume(int index, int volume);
    Q_INVOKABLE void setSourceMuted(int index, bool muted);
    Q_INVOKABLE void setSourceOutputVolume(int index, int volume);
    Q_INVOKABLE void setSourceOutputMuted(int index, bool muted);

    // Generic device access by type string ("sink", "source", "sinkInput", "sourceOutput")
    Q_INVOKABLE int deviceCount(const QString &type) const;
    Q_INVOKABLE QString deviceName(const QString &type, int index) const;
    Q_INVOKABLE QString deviceDescription(const QString &type, int index) const;
    Q_INVOKABLE QString deviceAppBinary(const QString &type, int index) const;
    Q_INVOKABLE int deviceVolume(const QString &type, int index) const;
    Q_INVOKABLE bool deviceMuted(const QString &type, int index) const;
    Q_INVOKABLE void setDeviceVolume(const QString &type, int index, int percent);
    Q_INVOKABLE void setDeviceMuted(const QString &type, int index, bool muted);

    // App-level stream helpers (for mixer)
    Q_INVOKABLE QVariantList findStreamsByApp(const QString &appName, const QString &streamType = {}) const;
    Q_INVOKABLE int appVolume(const QString &appName, const QString &streamType = {}) const;
    Q_INVOKABLE bool appMuted(const QString &appName, const QString &streamType = {}) const;
    Q_INVOKABLE void setAppVolume(const QString &appName, int percent, const QString &streamType = {});
    Q_INVOKABLE void setAppMuted(const QString &appName, bool muted, const QString &streamType = {});

signals:
    void defaultVolumeChanged();
    void defaultMutedChanged();
    void defaultSinkChanged();
    void refreshTickChanged();

private:
#ifdef HAVE_KF6PULSEAUDIOQT
    void connectToDefaultSink();
    void updateFromDefaultSink();

    PulseAudioQt::SinkModel *sinkModel_ = nullptr;
    PulseAudioQt::SinkInputModel *sinkInputModel_ = nullptr;
    PulseAudioQt::SourceModel *sourceModel_ = nullptr;
    PulseAudioQt::SourceOutputModel *sourceOutputModel_ = nullptr;
    PulseAudioQt::Sink *currentDefaultSink_ = nullptr;
#endif
    int defaultVolume_ = 100;
    bool defaultMuted_ = false;
    QString defaultSinkName_;
    int refreshTick_ = 0;
};

} // namespace ciderdeck
