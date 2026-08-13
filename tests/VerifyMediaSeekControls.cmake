if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

if(DEFINED MEDIA_QML_PATH)
  file(READ "${MEDIA_QML_PATH}" MEDIA_QML)
else()
  file(READ "${SOURCE_DIR}/src/qml/MediaPlayerTile.qml" MEDIA_QML)
endif()

function(require_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "Media seek controls contract failed: ${description}")
  endif()
endfunction()

function(extract_control_block output control end_marker)
  string(FIND "${MEDIA_QML}" "id: ${control}" block_start)
  if(block_start EQUAL -1)
    message(FATAL_ERROR "Media seek controls contract failed: ${control} must have a stable identity")
  endif()
  string(SUBSTRING "${MEDIA_QML}" ${block_start} -1 block_tail)
  string(FIND "${block_tail}" "${end_marker}" block_length)
  if(block_length EQUAL -1)
    message(FATAL_ERROR "Media seek controls contract failed: ${control} block boundary is missing")
  endif()
  string(SUBSTRING "${block_tail}" 0 ${block_length} block)
  set(${output} "${block}" PARENT_SCOPE)
endfunction()

function(extract_mouse_area output block control)
  string(REGEX MATCH "MouseArea[ \t\r\n]*\\{[^{}]*\\}" mouse_area "${block}")
  if(mouse_area STREQUAL "")
    message(FATAL_ERROR
      "Media seek controls contract failed: ${control} must have a dedicated MouseArea")
  endif()
  set(${output} "${mouse_area}" PARENT_SCOPE)
endfunction()

function(require_slot_contract block control label action)
  extract_mouse_area(MOUSE_AREA "${block}" "${control}")
  require_text("${block}" "width: mediaTile.transportSlotSize"
    "the ${label} interaction slot must use the shared minimum target size")
  require_text("${block}" "height: mediaTile.transportSlotSize"
    "the ${label} interaction slot must be square")
  require_text("${block}" "activeFocusOnTab: enabled"
    "the ${label} action must be keyboard reachable")
  require_text("${block}" "Accessible.role: Accessible.Button"
    "the ${label} control must expose button semantics")
  require_text("${block}" "Accessible.name:"
    "the ${label} control must expose an accessible name")
  require_text("${block}" "Accessible.onPressAction: ${control}.activate()"
    "the ${label} assistive action must use activate()")
  require_text("${block}" "Keys.onPressed: (event) => mediaTile.activateTransportKey(event, ${control})"
    "the ${label} keyboard action must use the shared dispatcher")
  require_text("${MOUSE_AREA}" "anchors.fill: parent"
    "the ${label} pointer target must fill only its non-overlapping slot")
  require_text("${MOUSE_AREA}" "enabled: ${control}.enabled"
    "the ${label} pointer target must follow its control's enabled state")
  require_text("${MOUSE_AREA}" "onClicked: ${control}.activate()"
    "the ${label} pointer action must use activate()")
  require_text("${block}" "${action}"
    "the ${label} control must preserve its transport action")
  require_text("${block}" "anchors.centerIn: parent"
    "the ${label} scaled visual must remain centered in its slot")
  require_text("${block}" "border.width: ${control}.activeFocus ? 2 : 0"
    "the ${label} keyboard focus must be visible")
endfunction()

require_text("${MEDIA_QML}" "readonly property real transportSlotSize: Math.max(44,"
  "transport interaction slots must stay at least 44 logical pixels")
require_text("${MEDIA_QML}" "(224 * buttonScale - 5 * transportSlotSize) / 4"
  "slot spacing must derive from the legacy five-control transport budget")
require_text("${MEDIA_QML}" "spacing: mediaTile.transportSpacing"
  "the transport row must use the derived non-overlapping slot spacing")
require_text("${MEDIA_QML}" "function activateTransportKey(event, control)"
  "transport controls must share one keyboard activation dispatcher")
foreach(key IN ITEMS Return Enter Space)
  require_text("${MEDIA_QML}" "Qt.Key_${key}" "transport controls must support ${key}")
endforeach()

extract_control_block(BACKWARD_BLOCK seekBackwardButton "id: previousButton")
extract_control_block(PREVIOUS_BLOCK previousButton "id: playPauseButton")
extract_control_block(PLAY_BLOCK playPauseButton "id: nextButton")
extract_control_block(NEXT_BLOCK nextButton "// Right extra:")
extract_control_block(FORWARD_BLOCK seekForwardButton "// End transport controls")

require_slot_contract("${BACKWARD_BLOCK}" seekBackwardButton "minus 10 seconds or shuffle"
  "mprisManager.skipBackward(10)")
require_slot_contract("${PREVIOUS_BLOCK}" previousButton "previous track"
  "mprisManager.previous()")
require_slot_contract("${PLAY_BLOCK}" playPauseButton "play or pause"
  "mprisManager.playPause()")
require_slot_contract("${NEXT_BLOCK}" nextButton "next track"
  "mprisManager.next()")
require_slot_contract("${FORWARD_BLOCK}" seekForwardButton "plus 10 seconds or repeat"
  "mprisManager.skipForward(10)")

require_text("${BACKWARD_BLOCK}" "Accessible.name: mprisManager.isSpotify"
  "the backward extra must expose a state-appropriate accessible name")
require_text("${BACKWARD_BLOCK}" "text: \"-10\""
  "the backward seek meaning must be visually explicit")
require_text("${BACKWARD_BLOCK}" "source: \"qrc:/icons/lucide/shuffle.svg\""
  "Spotify shuffle must keep its bundled Lucide affordance")
require_text("${BACKWARD_BLOCK}" "mprisManager.toggleShuffle()"
  "Spotify shuffle behavior must be preserved")
require_text("${FORWARD_BLOCK}" "Accessible.name: mprisManager.isSpotify"
  "the forward extra must expose a state-appropriate accessible name")
require_text("${FORWARD_BLOCK}" "text: \"+10\""
  "the forward seek meaning must be visually explicit")
require_text("${FORWARD_BLOCK}" "qrc:/icons/lucide/repeat-1.svg"
  "Spotify repeat-one affordance must be preserved")
require_text("${FORWARD_BLOCK}" "mprisManager.cycleLoopStatus()"
  "Spotify repeat behavior must be preserved")

# Mirror the declarative geometry for every constrained content/element scale
# pairing. Integer truncation affects only visuals smaller than the 44px slot.
foreach(content_scale IN ITEMS 100 75 50)
  foreach(element_scale IN ITEMS 100 75 50)
    math(EXPR play_size "40 * ${content_scale} * ${element_scale} / 10000")
    math(EXPR skip_size "28 * ${content_scale} * ${element_scale} / 10000")
    math(EXPR extra_size "24 * ${content_scale} * ${element_scale} / 10000")
    set(slot_size 44)
    foreach(visual_size IN ITEMS ${play_size} ${skip_size} ${extra_size})
      if(visual_size GREATER slot_size)
        set(slot_size ${visual_size})
      endif()
    endforeach()
    math(EXPR spacing "(224 - 5 * ${slot_size}) / 4")
    if(spacing LESS 0)
      set(spacing 0)
    endif()
    math(EXPR row_width "5 * ${slot_size} + 4 * ${spacing}")
    if(slot_size LESS 44)
      message(FATAL_ERROR
        "Media seek controls geometry failed at scales ${content_scale}/${element_scale}: ${slot_size}px target")
    endif()
    if(row_width GREATER 224)
      message(FATAL_ERROR
        "Media seek controls geometry failed at scales ${content_scale}/${element_scale}: ${row_width}px row")
    endif()
  endforeach()
endforeach()

string(FIND "${MEDIA_QML}" "id: transportRow" TRANSPORT_START)
string(SUBSTRING "${MEDIA_QML}" ${TRANSPORT_START} -1 TRANSPORT_TAIL)
string(FIND "${TRANSPORT_TAIL}" "// End transport controls" TRANSPORT_LENGTH)
string(SUBSTRING "${TRANSPORT_TAIL}" 0 ${TRANSPORT_LENGTH} TRANSPORT_BLOCK)
string(FIND "${TRANSPORT_BLOCK}" "anchors.margins: -10" OVERLAP_INDEX)
if(NOT OVERLAP_INDEX EQUAL -1)
  message(FATAL_ERROR "Media seek controls contract failed: fixed overlapping target expansion is forbidden")
endif()
string(FIND "${MEDIA_QML}" "forceActiveFocus" FOCUS_STEAL_INDEX)
if(NOT FOCUS_STEAL_INDEX EQUAL -1)
  message(FATAL_ERROR "Media seek controls contract failed: controls must not steal focus")
endif()
