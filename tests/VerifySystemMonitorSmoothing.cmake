if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

file(READ "${SOURCE_DIR}/src/qml/SystemMonitorTile.qml" SYSTEM_MONITOR_QML)
file(READ "${SOURCE_DIR}/src/qml/MetricSparkline.qml" SPARKLINE_QML)

function(require_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "System monitor smoothing contract failed: ${description}")
  endif()
endfunction()

function(reject_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(NOT match_index EQUAL -1)
    message(FATAL_ERROR "System monitor smoothing contract failed: ${description}")
  endif()
endfunction()

function(require_sub_poll_duration haystack property_name description)
  string(REGEX MATCH
    "readonly property int ${property_name}: ([0-9]+)"
    duration_match
    "${haystack}")
  if(NOT duration_match)
    message(FATAL_ERROR
      "System monitor smoothing contract failed: ${description} must declare ${property_name}")
  endif()
  if(CMAKE_MATCH_1 GREATER_EQUAL 2000)
    message(FATAL_ERROR
      "System monitor smoothing contract failed: ${description} must settle before the 2000 ms polling cadence")
  endif()
endfunction()

require_sub_poll_duration("${SYSTEM_MONITOR_QML}"
  "metricTransitionDuration"
  "percentage interpolation")
require_text("${SYSTEM_MONITOR_QML}"
  "property real displayedMetricPercent: metricPercent"
  "single-metric presentation must animate a displayed copy of the raw service percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "Behavior on displayedMetricPercent"
  "single-metric percentage changes must use an interrupt-safe behavior")
require_text("${SYSTEM_MONITOR_QML}"
  "Behavior on displayedMetricPercent {\n        enabled: sysmonTile.monitoringActive"
  "single-metric percentage animation must be disabled while its page is inactive")
require_text("${SYSTEM_MONITOR_QML}"
  "text: Math.round(sysmonTile.displayedMetricPercent) + \"%\""
  "single-metric text must render the interpolated percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "sysmonTile.displayedMetricPercent / 100"
  "single-metric bar geometry must render the interpolated percentage")
reject_text("${SYSTEM_MONITOR_QML}"
  "Behavior on width"
  "bar width must not add a second animation on top of the interpolated percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "color: sysmonTile.metricPercent >= 90 ? themeManager.errorColor : sysmonTile.metricColor"
  "error thresholds must continue to use the immediate raw service percentage")

require_text("${SYSTEM_MONITOR_QML}"
  "id: overviewMetricModel"
  "the overview must use a stable model with persistent delegate identities")
require_text("${SYSTEM_MONITOR_QML}"
  "model: overviewMetricModel"
  "the overview repeater must consume the stable identity model")
reject_text("${SYSTEM_MONITOR_QML}"
  "model: ["
  "the overview repeater model must not be recreated from live telemetry objects")
foreach(metric_key IN ITEMS cpu gpu memory storage)
  require_text("${SYSTEM_MONITOR_QML}"
    "metricKey: \"${metric_key}\""
    "the stable overview model must include ${metric_key}")
endforeach()
require_text("${SYSTEM_MONITOR_QML}"
  "readonly property real rawPercent:"
  "each overview delegate must bind directly to its raw service percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "property real displayedPercent: rawPercent"
  "each stable overview delegate must own its animated presentation percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "Behavior on displayedPercent"
  "overview percentage updates must be interrupt-safe")
require_text("${SYSTEM_MONITOR_QML}"
  "Behavior on displayedPercent {\n                        enabled: sysmonTile.monitoringActive"
  "each overview percentage animation must be disabled while its page is inactive")
require_text("${SYSTEM_MONITOR_QML}"
  "text: Math.round(displayedPercent) + \"%\""
  "overview labels must render the interpolated delegate percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "displayedPercent / 100"
  "overview bar geometry must render the interpolated delegate percentage")
require_text("${SYSTEM_MONITOR_QML}"
  "values: metricHistory"
  "overview histories must remain bound to raw service history")
require_text("${SYSTEM_MONITOR_QML}"
  "values: sysmonTile.metricHistory\n                maxValue: 100\n                lineColor: sysmonTile.metricColor\n                presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph && sysmonTile.sizeClass !== \"tiny\""
  "the single-metric sparkline must animate only while its page and graph are active")
require_text("${SYSTEM_MONITOR_QML}"
  "values: systemMonitor.downloadHistory\n                maxValue: 0\n                lineColor: \"#62d2a2\"\n                presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph"
  "the network sparkline must animate only while its page and graph are active")
require_text("${SYSTEM_MONITOR_QML}"
  "values: metricHistory\n                        maxValue: 100\n                        lineColor: metricColor\n                        presentationActive: sysmonTile.monitoringActive && sysmonTile.showGraph"
  "each overview sparkline must animate only while its page and graph are active")

require_sub_poll_duration("${SPARKLINE_QML}"
  "transitionDuration"
  "sparkline morphing")
require_text("${SPARKLINE_QML}"
  "property bool presentationActive: true"
  "sparklines must expose explicit presentation activity")
require_text("${SPARKLINE_QML}"
  "return isFinite(number) ? number : 0"
  "sparklines must sanitize NaN and both infinities with a Qt 6.5-compatible finite check")
require_text("${SPARKLINE_QML}"
  "copied.push(finiteNumber(source[i]))"
  "raw history must be sanitized before entering transition state")
require_text("${SPARKLINE_QML}"
  "var configuredMax = finiteNumber(maxValue)"
  "configured scale must be sanitized before ceiling arithmetic")
require_text("${SPARKLINE_QML}"
  "ceiling = Math.max(ceiling, finiteNumber(source[m]))"
  "dynamic scale samples must be sanitized before ceiling arithmetic")
require_text("${SPARKLINE_QML}"
  "var leftValue = finiteNumber(source[leftIndex])\n        var rightValue = finiteNumber(source[rightIndex])"
  "transition endpoints must be sanitized before interpolation arithmetic")
require_text("${SPARKLINE_QML}"
  "property var fromValues: []"
  "sparklines must retain the rendered history at the start of a morph")
require_text("${SPARKLINE_QML}"
  "property var toValues: []"
  "sparklines must retain the newest raw history as the morph target")
require_text("${SPARKLINE_QML}"
  "readonly property real displayedCeiling:"
  "dynamic network scaling must transition with the rendered history")
require_text("${SPARKLINE_QML}"
  "function interpolatedValues()"
  "sparkline paint data must interpolate old and new histories")
require_text("${SPARKLINE_QML}"
  "function beginTransition()"
  "history and scale updates must share one interrupt-safe transition path")
require_text("${SPARKLINE_QML}"
  "function beginTransition() {\n        if (!presentationActive)\n            return"
  "inactive sparklines must reject transition work before copying or interpolating history")
require_text("${SPARKLINE_QML}"
  "function synchronizePresentation()"
  "activation must have an explicit latest-state synchronization path")
require_text("${SPARKLINE_QML}"
  "var currentValues = interpolatedValues()"
  "interrupted transitions must continue from their currently rendered history")
require_text("${SPARKLINE_QML}"
  "var currentCeiling = displayedCeiling"
  "interrupted auto-scaling must continue from its currently rendered ceiling")
require_text("${SPARKLINE_QML}"
  "ceiling *= 1.15"
  "dynamic auto-scaling must preserve headroom for raw spikes")
require_text("${SPARKLINE_QML}"
  "property: \"transitionProgress\""
  "the sparkline morph must animate only bounded presentation state")
require_text("${SPARKLINE_QML}"
  "onValuesChanged: {\n        if (transitionReady && presentationActive)\n            beginTransition()"
  "inactive sample changes must not start transition work")
require_text("${SPARKLINE_QML}"
  "onMaxValueChanged: {\n        if (transitionReady && presentationActive)\n            beginTransition()"
  "inactive scale changes must not start transition work")
require_text("${SPARKLINE_QML}"
  "if (presentationActive)\n            synchronizePresentation()\n        else\n            morphAnimation.stop()"
  "activation must snap to latest state and deactivation must stop the morph")
require_text("${SPARKLINE_QML}"
  "onTransitionProgressChanged: {\n        if (presentationActive)\n            requestPaint()\n    }"
  "only active bounded morph frames may request canvas repaint")
reject_text("${SPARKLINE_QML}"
  "onTransitionProgressChanged: requestPaint()"
  "morph-frame repaint must never be unconditional")
require_text("${SPARKLINE_QML}"
  "var displayedValues = chart.interpolatedValues()"
  "the canvas must paint the morphed history rather than the raw target")
