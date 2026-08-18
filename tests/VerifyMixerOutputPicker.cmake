if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

file(READ "${SOURCE_DIR}/src/qml/MixerOverlay.qml" MIXER_QML)

function(require_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "Mixer output picker contract failed: ${description}")
  endif()
endfunction()

function(require_minimum_matches haystack pattern minimum description)
  string(REGEX MATCHALL "${pattern}" matches "${haystack}")
  list(LENGTH matches match_count)
  if(match_count LESS minimum)
    message(FATAL_ERROR
      "Mixer output picker contract failed: ${description}; found ${match_count}, expected at least ${minimum}")
  endif()
endfunction()

require_text("${MIXER_QML}"
  "readonly property var outputDestinationList: audioMixerService ? audioMixerService.outputDestinations : []"
  "the picker must bind to the service destination model")
require_text("${MIXER_QML}"
  "property int outputPickerGroupIndex: -1"
  "the picker must retain the selected group without taking keyboard focus")
require_text("${MIXER_QML}"
  "id: outputPickerButton"
  "each mixer group must expose an output destination button")
require_text("${MIXER_QML}"
  "id: outputPickerCard"
  "the destination choices must render in an in-panel touch card")
require_text("${MIXER_QML}"
  "text: \"System output\""
  "the picker must include an explicit system/default destination")
require_text("${MIXER_QML}"
  "audioMixerService.setGroupOutput(mixerOverlay.outputPickerGroupIndex, \"\")"
  "choosing System output must clear the persisted sink assignment")
require_text("${MIXER_QML}"
  "grp.outputAvailable === false"
  "the group control must expose a retained unavailable assignment")
require_text("${MIXER_QML}"
  "currentOutputSinkName === modelData.name"
  "the picker must identify the current physical destination")
require_text("${MIXER_QML}"
  "source: \"qrc:/icons/lucide/check.svg\""
  "the current destination must use the existing Lucide selected-state icon")
require_text("${MIXER_QML}"
  "source: \"qrc:/icons/lucide/volume-2.svg\""
  "the output control must use an existing Lucide audio icon")

require_minimum_matches("${MIXER_QML}"
  "Accessible\\.role: Accessible\\.Button"
  3
  "the group trigger, System output, and physical destinations must expose button semantics")
require_minimum_matches("${MIXER_QML}"
  "activeFocusOnTab: true"
  3
  "the group trigger, System output, and physical destinations must be keyboard reachable")
require_text("${MIXER_QML}"
  "activeFocusOnTab: true\n                                    Accessible.role: Accessible.Button\n                                    Accessible.name: \"Choose output for \" + (grp.name || \"group\")"
  "the group output trigger must combine tab reachability, button semantics, and a meaningful name")
require_text("${MIXER_QML}"
  "activeFocusOnTab: true\n                        Accessible.role: Accessible.Button\n                        Accessible.name: \"Use System output\""
  "the System/default choice must combine tab reachability, button semantics, and a meaningful name")
require_text("${MIXER_QML}"
  "activeFocusOnTab: true\n                            Accessible.role: Accessible.Button\n                            Accessible.name: \"Use output \" + (modelData.description || modelData.name)"
  "each physical destination must combine tab reachability, button semantics, and a meaningful name")

require_text("${MIXER_QML}"
  "function activatePickerControl(event, control)"
  "picker controls must share one keyboard activation dispatcher")
require_text("${MIXER_QML}" "event.key === Qt.Key_Return"
  "picker controls must activate with Return")
require_text("${MIXER_QML}" "event.key === Qt.Key_Enter"
  "picker controls must activate with Enter")
require_text("${MIXER_QML}" "event.key === Qt.Key_Space"
  "picker controls must activate with Space")
require_text("${MIXER_QML}"
  "if (event.key === Qt.Key_Escape) {\n            closeOutputPicker()\n            event.accepted = true\n            return\n        }"
  "Escape from a focused picker control must close the picker without requesting focus")

foreach(control IN ITEMS outputPickerButton systemOutputChoice destinationOutputChoice)
  require_text("${MIXER_QML}"
    "Keys.onPressed: (event) => mixerOverlay.activatePickerControl(event, ${control})"
    "${control} must use the shared Enter/Return/Space dispatcher")
  require_text("${MIXER_QML}"
    "Accessible.onPressAction: ${control}.activate()"
    "${control} must route assistive activation through its shared action")
  require_text("${MIXER_QML}"
    "onClicked: ${control}.activate()"
    "${control} must route pointer/touch activation through its shared action")
endforeach()

string(REGEX MATCHALL "id: (outputPickerButton|systemOutputChoice|destinationOutputChoice)[^}]*height: 4[4-9]" TOUCH_TARGETS "${MIXER_QML}")
list(LENGTH TOUCH_TARGETS TOUCH_TARGET_COUNT)
if(TOUCH_TARGET_COUNT LESS 3)
  message(FATAL_ERROR
    "Mixer output picker contract failed: button and destination rows must provide at least 44px touch targets")
endif()

string(FIND "${MIXER_QML}" "forceActiveFocus" FOCUS_STEAL_INDEX)
if(NOT FOCUS_STEAL_INDEX EQUAL -1)
  message(FATAL_ERROR "Mixer output picker contract failed: picker must not force keyboard focus")
endif()
