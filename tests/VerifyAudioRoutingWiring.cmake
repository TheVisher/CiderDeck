if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

file(READ "${SOURCE_DIR}/src/services/AudioMixerService.cpp" MIXER_SOURCE)
file(READ "${SOURCE_DIR}/src/services/AudioMixerService.h" MIXER_HEADER)

function(require_text haystack needle description)
  string(FIND "${haystack}" "${needle}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "Audio routing contract failed: ${description}")
  endif()
endfunction()

require_text("${MIXER_HEADER}"
  "void routeSinkInput(PulseAudioQt::SinkInput *stream);"
  "the service must expose a narrow private sink-input routing hook")
require_text("${MIXER_HEADER}"
  "void routeAllSinkInputs();"
  "the service must support deterministic reapplication across active streams")
require_text("${MIXER_SOURCE}"
  "stream->setDeviceIndex(targetDeviceIndex.value());"
  "routing must move a stream through PulseAudioQt::SinkInput::setDeviceIndex")
require_text("${MIXER_SOURCE}"
  "routeSinkInput(si);"
  "stream insertion and delayed identity updates must run routing")
require_text("${MIXER_SOURCE}"
  "void AudioMixerService::onSinkModelChanged()"
  "sink insertion, change, removal, and recreation must share a reapply hook")

string(REGEX MATCHALL "routeAllSinkInputs\\(\\);" ROUTE_ALL_CALLS "${MIXER_SOURCE}")
list(LENGTH ROUTE_ALL_CALLS ROUTE_ALL_CALL_COUNT)
if(ROUTE_ALL_CALL_COUNT LESS 6)
  message(FATAL_ERROR
    "Audio routing contract failed: group destination and app assignment paths must reapply routing (found ${ROUTE_ALL_CALL_COUNT} route-all calls)")
endif()
