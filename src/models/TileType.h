#pragma once

#include <QObject>

namespace ciderdeck {

Q_NAMESPACE

enum class TileType {
    AppLauncher,
    MediaPlayer,
    Volume,
    ClockDate,
    Weather,
    SystemMonitor,
    ProcessManager,
    Screenshot,
    Brightness,
    Clipboard,
    TimerStopwatch,
    CommandButton,
    ShowDesktop,
    Overview,
    AudioMixer,
};
Q_ENUM_NS(TileType)

inline QString tileTypeToString(TileType type) {
    switch (type) {
    case TileType::AppLauncher:     return QStringLiteral("app_launcher");
    case TileType::MediaPlayer:     return QStringLiteral("media_player");
    case TileType::Volume:          return QStringLiteral("volume");
    case TileType::ClockDate:       return QStringLiteral("clock_date");
    case TileType::Weather:         return QStringLiteral("weather");
    case TileType::SystemMonitor:   return QStringLiteral("system_monitor");
    case TileType::ProcessManager:  return QStringLiteral("process_manager");
    case TileType::Screenshot:      return QStringLiteral("screenshot");
    case TileType::Brightness:      return QStringLiteral("brightness");
    case TileType::Clipboard:       return QStringLiteral("clipboard");
    case TileType::TimerStopwatch:  return QStringLiteral("timer_stopwatch");
    case TileType::CommandButton:   return QStringLiteral("command_button");
    case TileType::ShowDesktop:    return QStringLiteral("show_desktop");
    case TileType::Overview:       return QStringLiteral("overview");
    case TileType::AudioMixer:     return QStringLiteral("audio_mixer");
    }
    return QStringLiteral("unknown");
}

inline TileType tileTypeFromString(const QString &str) {
    if (str == "app_launcher")     return TileType::AppLauncher;
    if (str == "media_player")     return TileType::MediaPlayer;
    if (str == "volume")           return TileType::Volume;
    if (str == "clock_date")       return TileType::ClockDate;
    if (str == "weather")          return TileType::Weather;
    if (str == "system_monitor")   return TileType::SystemMonitor;
    if (str == "process_manager")  return TileType::ProcessManager;
    if (str == "screenshot")       return TileType::Screenshot;
    if (str == "brightness")       return TileType::Brightness;
    if (str == "clipboard")        return TileType::Clipboard;
    if (str == "timer_stopwatch")  return TileType::TimerStopwatch;
    if (str == "command_button")   return TileType::CommandButton;
    if (str == "show_desktop")    return TileType::ShowDesktop;
    if (str == "overview")        return TileType::Overview;
    if (str == "audio_mixer")     return TileType::AudioMixer;
    return TileType::AppLauncher;
}

} // namespace ciderdeck
