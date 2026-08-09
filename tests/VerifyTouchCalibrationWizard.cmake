if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

set(WIZARD_PATH "${SOURCE_DIR}/src/qml/TouchCalibrationWizard.qml")
if(NOT EXISTS "${WIZARD_PATH}")
  message(FATAL_ERROR "Touch calibration wizard contract failed: TouchCalibrationWizard.qml is not registered yet")
endif()

file(READ "${SOURCE_DIR}/CMakeLists.txt" CMAKE_SOURCE)
file(READ "${SOURCE_DIR}/src/app/CiderDeckApp.h" APP_HEADER)
file(READ "${SOURCE_DIR}/src/app/CiderDeckApp.cpp" APP_SOURCE)
file(READ "${SOURCE_DIR}/src/qml/qml.qrc" QML_RESOURCES)
file(READ "${SOURCE_DIR}/src/qml/main.qml" MAIN_QML)
file(READ "${SOURCE_DIR}/src/qml/GeneralSettings.qml" SETTINGS_QML)
file(READ "${WIZARD_PATH}" WIZARD_QML)

function(require_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "Touch calibration wizard contract failed: ${description}")
  endif()
endfunction()

foreach(source IN ITEMS
    "src/services/TouchCalibrationService.h"
    "src/services/TouchCalibrationService.cpp")
  require_text("${CMAKE_SOURCE}" "${source}"
    "the calibration coordinator must be compiled into the application")
endforeach()
require_text("${APP_HEADER}" "TouchCalibrationService *touchCalibration_ = nullptr;"
  "the composition root must own the coordinator")
require_text("${APP_SOURCE}" "new TouchCalibrationService(evdevTouch_, this)"
  "the coordinator must use the evdev calibration-device boundary")
require_text("${APP_SOURCE}" "setContextProperty(\"touchCalibrationService\", touchCalibration_)"
  "QML must receive only the narrow calibration coordinator")
foreach(signal IN ITEMS rawTouchPressed rawTouchMoved rawTouchReleased activeChanged devicePathChanged calibrationChanged)
  require_text("${APP_SOURCE}" "&EvdevTouchService::${signal}"
    "the composition root must wire ${signal}")
endforeach()

require_text("${QML_RESOURCES}" "<file>TouchCalibrationWizard.qml</file>"
  "the wizard must be registered as a QML resource")
require_text("${MAIN_QML}"
  "TouchCalibrationWizard {\n        x: 0\n        y: 0\n        width: root.width\n        height: root.height\n        z: 400"
  "the Popup-based wizard must use valid full-window geometry at window scope")
string(REGEX MATCH
  "TouchCalibrationWizard[ \t\r\n]*\\{[^}]*anchors\\.fill"
  INVALID_WIZARD_FILL_ANCHOR "${MAIN_QML}")
if(INVALID_WIZARD_FILL_ANCHOR)
  message(FATAL_ERROR
    "Touch calibration wizard contract failed: Popup mounting must not use anchors.fill")
endif()
require_text("${MAIN_QML}"
  "Item {\n        id: applicationContent\n        anchors.fill: parent\n        enabled: !touchCalibrationService.active\n        Accessible.ignored: touchCalibrationService.active"
  "the bounded dashboard underlay must be inert and accessibility-hidden during calibration")
require_text("${MAIN_QML}" "|| touchCalibrationService.active"
  "calibration must keep keyboard interactivity synchronized without focus grabbing")
require_text("${MAIN_QML}" "&& !touchCalibrationService.active"
  "the ordinary Escape shortcut must defer to the active wizard")
require_text("${MAIN_QML}" "if (enabled === root.keyboardInteractivityEnabled)"
  "wizard state updates must not repeat a focus activation request")

require_text("${SETTINGS_QML}" "text: \"Touch calibration\""
  "general settings must expose the calibration section")
foreach(diagnostic IN ITEMS deviceName devicePath deviceIdentity statusText deviceAvailable hasCalibration)
  require_text("${SETTINGS_QML}" "touchCalibrationService.${diagnostic}"
    "general settings must display ${diagnostic}")
endforeach()
foreach(control IN ITEMS startCalibrationButton resetCalibrationButton)
  require_text("${SETTINGS_QML}" "id: ${control}"
    "general settings must expose ${control}")
  require_text("${SETTINGS_QML}" "Accessible.onPressAction: ${control}.activate()"
    "${control} must share assistive activation")
  require_text("${SETTINGS_QML}" "onClicked: ${control}.activate()"
    "${control} must share pointer activation")
endforeach()

require_text("${WIZARD_QML}" "model: 5"
  "the wizard must show all five calibration points")
require_text("${WIZARD_QML}" "touchCalibrationService.acknowledgedPointCount"
  "completed points must remain visibly acknowledged")
require_text("${WIZARD_QML}" "touchCalibrationService.targetPoint"
  "the collecting target must follow service state")
require_text("${WIZARD_QML}" "touchCalibrationService.contactSampleCount"
  "contact averaging must have immediate visible feedback")
require_text("${WIZARD_QML}" "touchCalibrationService.previewPosition"
  "candidate calibration must expose a live preview marker")
require_text("${WIZARD_QML}" "touchCalibrationService.errorMessage"
  "poor-fit and degenerate errors must be presented")
require_text("${WIZARD_QML}" "touchCalibrationService.errorMessage.length > 0"
  "apply failures must remain visible during candidate preview")
require_text("${WIZARD_QML}"
  "visible: touchCalibrationService.active\n    modal: true\n    focus: true\n    padding: 0\n    closePolicy: Popup.NoAutoClose"
  "the visible wizard must be a focused modal popup that closes only through calibration state restoration")
require_text("${WIZARD_QML}" "Popup {\n    id: touchCalibrationWizard"
  "the modal properties must belong to a Qt Quick Controls popup")
require_text("${WIZARD_QML}" "onActivated: touchCalibrationWizard.cancelCalibration()"
  "Escape must use the wizard's safe cancellation path")
require_text("${WIZARD_QML}" "function activate() {\n                touchCalibrationWizard.cancelCalibration()"
  "the Cancel action must share the same safe cancellation path")
require_text("${WIZARD_QML}" "id: cancelCalibrationButton\n            focus: true"
  "the always-visible Cancel action must receive initial modal focus")

foreach(control IN ITEMS retryPointButton cancelCalibrationButton retryCalibrationButton applyCalibrationButton)
  require_text("${WIZARD_QML}" "id: ${control}"
    "the wizard must expose ${control}")
  require_text("${WIZARD_QML}" "Accessible.onPressAction: ${control}.activate()"
    "${control} must share assistive activation")
  require_text("${WIZARD_QML}" "onClicked: ${control}.activate()"
    "${control} must share pointer activation")
endforeach()

string(REGEX MATCHALL "implicitHeight: 4[4-9]" WIZARD_TOUCH_TARGETS "${WIZARD_QML}")
list(LENGTH WIZARD_TOUCH_TARGETS WIZARD_TOUCH_TARGET_COUNT)
if(WIZARD_TOUCH_TARGET_COUNT LESS 4)
  message(FATAL_ERROR
    "Touch calibration wizard contract failed: all four wizard actions need at least 44px touch targets")
endif()
string(REGEX MATCHALL "implicitHeight: 4[4-9]" SETTINGS_TOUCH_TARGETS "${SETTINGS_QML}")
list(LENGTH SETTINGS_TOUCH_TARGETS SETTINGS_TOUCH_TARGET_COUNT)
if(SETTINGS_TOUCH_TARGET_COUNT LESS 2)
  message(FATAL_ERROR
    "Touch calibration wizard contract failed: Start and Reset need at least 44px touch targets")
endif()

foreach(forbidden IN ITEMS forceActiveFocus requestActivate raise)
  foreach(qml IN ITEMS "${WIZARD_QML}" "${SETTINGS_QML}")
    string(FIND "${qml}" "${forbidden}" FOCUS_STEAL_INDEX)
    if(NOT FOCUS_STEAL_INDEX EQUAL -1)
      message(FATAL_ERROR
        "Touch calibration wizard contract failed: calibration UI must not use ${forbidden}")
    endif()
  endforeach()
endforeach()
