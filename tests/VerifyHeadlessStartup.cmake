if(NOT DEFINED CIDERDECK_EXECUTABLE)
  message(FATAL_ERROR "CIDERDECK_EXECUTABLE is required")
endif()
if(NOT EXISTS "${CIDERDECK_EXECUTABLE}")
  message(FATAL_ERROR "CiderDeck startup smoke failed: executable does not exist")
endif()
if(NOT DEFINED STARTUP_CONFIG_DIR)
  message(FATAL_ERROR "STARTUP_CONFIG_DIR is required")
endif()

file(REMOVE_RECURSE "${STARTUP_CONFIG_DIR}")
file(MAKE_DIRECTORY "${STARTUP_CONFIG_DIR}")

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
    "QT_QPA_PLATFORM=offscreen"
    "CIDERDECK_CONFIG_DIR=${STARTUP_CONFIG_DIR}"
    "CIDERDECK_PREVIEW=1"
    "${CIDERDECK_EXECUTABLE}"
  RESULT_VARIABLE STARTUP_RESULT
  OUTPUT_VARIABLE STARTUP_STDOUT
  ERROR_VARIABLE STARTUP_STDERR
  TIMEOUT 3
)

file(REMOVE_RECURSE "${STARTUP_CONFIG_DIR}")
set(STARTUP_OUTPUT "${STARTUP_STDOUT}${STARTUP_STDERR}")

if(STARTUP_OUTPUT MATCHES "\\[QML WARNING\\]")
  message(FATAL_ERROR
    "CiderDeck startup smoke failed: QML warning emitted:\n${STARTUP_OUTPUT}")
endif()
if(STARTUP_OUTPUT MATCHES "QML root failed to load")
  message(FATAL_ERROR
    "CiderDeck startup smoke failed: QML root did not load:\n${STARTUP_OUTPUT}")
endif()
if(NOT "${STARTUP_RESULT}" MATCHES "[Tt]imeout")
  message(FATAL_ERROR
    "CiderDeck startup smoke failed: expected the event loop to remain alive, result=${STARTUP_RESULT}\n${STARTUP_OUTPUT}")
endif()
