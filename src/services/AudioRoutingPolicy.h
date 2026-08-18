#pragma once

#include <QList>
#include <QString>
#include <QStringList>
#include <QStringView>

#include <optional>

namespace ciderdeck::audio {

inline bool isAsmVirtualSinkName(QStringView name)
{
    return name == u"Arctis_Game"
        || name == u"Arctis_Media"
        || name == u"Arctis_Chat";
}

inline bool isInternalProcessingStreamName(QStringView name)
{
    return ((name.startsWith(u"Sonar ") || name.startsWith(u"Arctis "))
            && name.endsWith(u" output"))
        || name == u"Virtual Surround Sink"
        || name.startsWith(u"effect_output.sonar-")
        || name.startsWith(u"effect_input.sonar-");
}

struct RoutingGroup {
    QStringList apps;
    QString outputSinkName;
    bool isGeneral = false;
};

struct RoutingSink {
    QString name;
    QString description;
    quint32 deviceIndex = 0;
};

struct RoutingStream {
    QString appName;
    QString streamName;
    quint32 currentDeviceIndex = 0;
};

enum class RoutingStatus {
    NoAssignment,
    DestinationUnavailable,
    AlreadyRouted,
    Move,
    ExcludedInternalStream,
};

struct RoutingDecision {
    RoutingStatus status = RoutingStatus::NoAssignment;
    std::optional<quint32> targetDeviceIndex;
};

inline RoutingDecision routingDecision(
    const RoutingStream &stream,
    const QList<RoutingGroup> &groups,
    const QList<RoutingSink> &sinks)
{
    if (isInternalProcessingStreamName(stream.appName)
        || isInternalProcessingStreamName(stream.streamName)) {
        return {RoutingStatus::ExcludedInternalStream, std::nullopt};
    }
    const RoutingGroup *matchedGroup = nullptr;
    const RoutingGroup *generalGroup = nullptr;
    for (const auto &group : groups) {
        if (group.isGeneral) {
            generalGroup = &group;
        } else if (group.apps.contains(stream.appName)) {
            matchedGroup = &group;
            break;
        }
    }
    if (!matchedGroup) {
        matchedGroup = generalGroup;
    }
    if (!matchedGroup || matchedGroup->outputSinkName.isEmpty()) {
        return {RoutingStatus::NoAssignment, std::nullopt};
    }

    for (const auto &sink : sinks) {
        if (sink.name != matchedGroup->outputSinkName) {
            continue;
        }
        if (sink.deviceIndex == stream.currentDeviceIndex) {
            return {RoutingStatus::AlreadyRouted, std::nullopt};
        }
        return {RoutingStatus::Move, sink.deviceIndex};
    }
    return {RoutingStatus::DestinationUnavailable, std::nullopt};
}

inline std::optional<quint32> routeTargetDeviceIndex(
    const RoutingStream &stream,
    const QList<RoutingGroup> &groups,
    const QList<RoutingSink> &sinks)
{
    return routingDecision(stream, groups, sinks).targetDeviceIndex;
}

} // namespace ciderdeck::audio
