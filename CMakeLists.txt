cmake_minimum_required(VERSION 3.22)
project(ciderdeck VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Core5Compat Gui Qml Quick DBus Sql Widgets)

# Layer-shell-qt for Wayland no-focus-steal
find_package(LayerShellQt QUIET)

# KDE Frameworks (all optional)
find_package(ECM QUIET NO_MODULE)
if(ECM_FOUND)
  list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})
endif()

find_package(KF6WindowSystem QUIET)
find_package(KF6StatusNotifierItem QUIET)
find_package(KF6PulseAudioQt QUIET)

# libddcutil for direct DDC/CI brightness control (faster than ddcutil subprocess)
find_library(DDCUTIL_LIBRARY NAMES ddcutil)
find_path(DDCUTIL_INCLUDE_DIR ddcutil_c_api.h)

add_executable(ciderdeck
  src/main.cpp

  src/app/CiderDeckApp.h
  src/app/CiderDeckApp.cpp

  src/models/TileType.h
  src/models/TileData.h
  src/models/MonitorInfo.h
  src/models/DeckConfig.h
  src/models/DeckConfig.cpp
  src/models/TouchCalibration.h
  src/models/TouchCalibration.cpp

  src/services/MonitorManager.h
  src/services/MonitorManager.cpp
  src/services/ThemeManager.h
  src/services/ThemeManager.cpp
  src/services/AppIconProvider.h
  src/services/AppIconProvider.cpp
  src/services/CommandRunner.h
  src/services/CommandRunner.cpp
  src/services/AppLaunchManager.h
  src/services/AppLaunchManager.cpp
  src/services/AudioManager.h
  src/services/AudioManager.cpp
  src/services/AudioMixerService.h
  src/services/AudioMixerService.cpp
  src/services/MprisManager.h
  src/services/MprisManager.cpp
  src/services/WeatherService.h
  src/services/WeatherService.cpp
  src/services/SystemMonitorService.h
  src/services/SystemMonitorService.cpp
  src/services/ProcessManagerService.h
  src/services/ProcessManagerService.cpp
  src/services/UpdateService.h
  src/services/UpdateService.cpp
  src/services/AgentTerminalService.h
  src/services/AgentTerminalService.cpp
  src/services/ScreenshotService.h
  src/services/ScreenshotService.cpp
  src/services/BrightnessService.h
  src/services/BrightnessService.cpp
  src/services/ClipboardService.h
  src/services/ClipboardService.cpp
  src/services/TimerService.h
  src/services/TimerService.cpp
  src/services/KWinDBusClient.h
  src/services/KWinDBusClient.cpp
  src/services/EvdevTouchService.h
  src/services/EvdevTouchService.cpp
  src/services/TouchCalibrationService.h
  src/services/TouchCalibrationService.cpp

  src/viewmodels/TileGridModel.h
  src/viewmodels/TileGridModel.cpp
  src/viewmodels/EditModeController.h
  src/viewmodels/EditModeController.cpp
  src/viewmodels/ToastModel.h
  src/viewmodels/ToastModel.cpp
  src/viewmodels/InstalledAppsModel.h
  src/viewmodels/InstalledAppsModel.cpp

  src/qml/qml.qrc
  src/resources/icons.qrc
)

target_include_directories(ciderdeck PRIVATE src)

target_compile_definitions(ciderdeck PRIVATE
  $<$<BOOL:${LayerShellQt_FOUND}>:HAVE_LAYERSHELLQT>
  $<$<BOOL:${KF6WindowSystem_FOUND}>:HAVE_KF6WINDOWSYSTEM>
  $<$<BOOL:${KF6StatusNotifierItem_FOUND}>:HAVE_KF6STATUSNOTIFIERITEM>
  $<$<BOOL:${KF6PulseAudioQt_FOUND}>:HAVE_KF6PULSEAUDIOQT>
  $<$<AND:$<BOOL:${DDCUTIL_LIBRARY}>,$<BOOL:${DDCUTIL_INCLUDE_DIR}>>:HAVE_LIBDDCUTIL>
)

target_link_libraries(ciderdeck PRIVATE
  Qt6::Core
  Qt6::Core5Compat
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::DBus
  Qt6::Sql
  Qt6::Widgets
)

if(LayerShellQt_FOUND)
  target_link_libraries(ciderdeck PRIVATE LayerShellQt::Interface)
  message(STATUS "LayerShellQt found: layer-shell support enabled")
else()
  message(WARNING "LayerShellQt not found: window will use normal placement")
endif()

if(KF6WindowSystem_FOUND)
  target_link_libraries(ciderdeck PRIVATE KF6::WindowSystem)
else()
  message(WARNING "KF6WindowSystem not found: blur-behind disabled")
endif()

if(KF6StatusNotifierItem_FOUND)
  target_link_libraries(ciderdeck PRIVATE KF6::StatusNotifierItem)
endif()

if(KF6PulseAudioQt_FOUND)
  target_link_libraries(ciderdeck PRIVATE KF6::PulseAudioQt)
  message(STATUS "KF6PulseAudioQt found: audio control enabled")
endif()

if(DDCUTIL_LIBRARY AND DDCUTIL_INCLUDE_DIR)
  target_link_libraries(ciderdeck PRIVATE ${DDCUTIL_LIBRARY})
  target_include_directories(ciderdeck PRIVATE ${DDCUTIL_INCLUDE_DIR})
  message(STATUS "libddcutil found: direct DDC brightness control enabled")
else()
  message(WARNING "libddcutil not found: falling back to ddcutil subprocess")
endif()

include(GNUInstallDirs)

install(TARGETS ciderdeck RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES ciderdeck.desktop DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
install(FILES ciderdeck.desktop DESTINATION "/etc/xdg/autostart")
install(FILES kwin-scripts/ciderdeck-bridge.js
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/ciderdeck/kwin-scripts")
install(FILES data/icons/ciderdeck.svg
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")

include(CTest)
if(BUILD_TESTING)
  find_package(Qt6 6.5 REQUIRED COMPONENTS Test)

  # Compile the Qt 6.5 filter-invalidation path even when developing with a
  # newer Qt, so later API usage cannot silently raise the documented minimum.
  add_library(ciderdeck-qt65-compatibility-build OBJECT
    src/viewmodels/InstalledAppsModel.h
    src/viewmodels/InstalledAppsModel.cpp
  )
  target_include_directories(ciderdeck-qt65-compatibility-build PRIVATE src)
  target_compile_definitions(ciderdeck-qt65-compatibility-build PRIVATE
    CIDERDECK_FORCE_QT65_FILTER_API
    QT_NO_DEPRECATED_WARNINGS
  )
  target_link_libraries(ciderdeck-qt65-compatibility-build PRIVATE Qt6::Core)

  add_executable(ciderdeck-model-tests
    tests/ModelTests.cpp
    src/models/DeckConfig.h
    src/models/DeckConfig.cpp
    src/models/TileData.h
    src/models/TileType.h
    src/viewmodels/TileGridModel.h
    src/viewmodels/TileGridModel.cpp
  )
  target_include_directories(ciderdeck-model-tests PRIVATE src)
  target_link_libraries(ciderdeck-model-tests PRIVATE Qt6::Core Qt6::Test)

  add_test(NAME ciderdeck-model-tests COMMAND ciderdeck-model-tests)

  add_executable(ciderdeck-clipboard-tests
    tests/ClipboardServiceTests.cpp
    src/services/ClipboardService.h
    src/services/ClipboardService.cpp
  )
  target_include_directories(ciderdeck-clipboard-tests PRIVATE src)
  target_link_libraries(ciderdeck-clipboard-tests PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Sql
    Qt6::Test
    Qt6::Widgets
  )

  add_test(NAME ciderdeck-clipboard-tests COMMAND ciderdeck-clipboard-tests)
  set_tests_properties(ciderdeck-clipboard-tests PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
  )

  add_executable(ciderdeck-service-settings-tests
    tests/ServiceSettingsTests.cpp
    src/services/MprisManager.h
    src/services/MprisManager.cpp
    src/services/TimerService.h
    src/services/TimerService.cpp
    src/services/UpdateService.h
    src/services/UpdateService.cpp
  )
  target_include_directories(ciderdeck-service-settings-tests PRIVATE src)
  target_link_libraries(ciderdeck-service-settings-tests PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Test
  )
  find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session)
  if(DBUS_RUN_SESSION_EXECUTABLE)
    add_test(NAME ciderdeck-service-settings-tests
      COMMAND "${DBUS_RUN_SESSION_EXECUTABLE}" -- "$<TARGET_FILE:ciderdeck-service-settings-tests>")
  else()
    add_test(NAME ciderdeck-service-settings-tests COMMAND ciderdeck-service-settings-tests)
  endif()

  add_executable(ciderdeck-monitoring-activity-tests
    tests/MonitoringActivityTests.cpp
    src/services/SystemMonitorService.h
    src/services/SystemMonitorService.cpp
    src/services/ProcessManagerService.h
    src/services/ProcessManagerService.cpp
    src/services/KWinDBusClient.h
    src/services/KWinDBusClient.cpp
  )
  target_include_directories(ciderdeck-monitoring-activity-tests PRIVATE src)
  target_link_libraries(ciderdeck-monitoring-activity-tests PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Test
  )
  add_test(NAME ciderdeck-monitoring-activity-tests
    COMMAND ciderdeck-monitoring-activity-tests)

  add_executable(ciderdeck-audio-mixer-tests
    tests/AudioMixerServiceTests.cpp
    src/services/AudioManager.h
    src/services/AudioManager.cpp
    src/services/AudioMixerService.h
    src/services/AudioMixerService.cpp
  )
  target_include_directories(ciderdeck-audio-mixer-tests PRIVATE src)
  target_link_libraries(ciderdeck-audio-mixer-tests PRIVATE
    Qt6::Core
    Qt6::Test
  )
  add_test(NAME ciderdeck-audio-mixer-tests COMMAND ciderdeck-audio-mixer-tests)

  add_test(NAME ciderdeck-audio-routing-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyAudioRoutingWiring.cmake"
  )

  add_test(NAME ciderdeck-mixer-output-picker-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyMixerOutputPicker.cmake"
  )

  add_executable(ciderdeck-evdev-touch-tests
    tests/EvdevTouchServiceTests.cpp
    src/models/TouchCalibration.h
    src/models/TouchCalibration.cpp
    src/services/EvdevTouchService.h
    src/services/EvdevTouchService.cpp
  )
  target_include_directories(ciderdeck-evdev-touch-tests PRIVATE src)
  target_link_libraries(ciderdeck-evdev-touch-tests PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Test
  )
  add_test(NAME ciderdeck-evdev-touch-tests COMMAND ciderdeck-evdev-touch-tests)

  add_executable(ciderdeck-touch-calibration-tests
    tests/TouchCalibrationTests.cpp
    src/models/TouchCalibration.h
    src/models/TouchCalibration.cpp
  )
  target_include_directories(ciderdeck-touch-calibration-tests PRIVATE src)
  target_link_libraries(ciderdeck-touch-calibration-tests PRIVATE Qt6::Core Qt6::Test)
  add_test(NAME ciderdeck-touch-calibration-tests COMMAND ciderdeck-touch-calibration-tests)

  add_executable(ciderdeck-touch-calibration-service-tests
    tests/TouchCalibrationServiceTests.cpp
    src/models/TouchCalibration.h
    src/models/TouchCalibration.cpp
    src/services/TouchCalibrationService.h
    src/services/TouchCalibrationService.cpp
  )
  target_include_directories(ciderdeck-touch-calibration-service-tests PRIVATE src)
  target_link_libraries(ciderdeck-touch-calibration-service-tests PRIVATE Qt6::Core Qt6::Test)
  add_test(NAME ciderdeck-touch-calibration-service-tests
    COMMAND ciderdeck-touch-calibration-service-tests)

  add_test(NAME ciderdeck-touch-calibration-wizard-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyTouchCalibrationWizard.cmake"
  )

  add_test(NAME ciderdeck-headless-startup-smoke
    COMMAND "${CMAKE_COMMAND}"
      "-DCIDERDECK_EXECUTABLE=$<TARGET_FILE:ciderdeck>"
      "-DSTARTUP_CONFIG_DIR=${CMAKE_CURRENT_BINARY_DIR}/headless-startup-config"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyHeadlessStartup.cmake"
  )

  find_program(QMLLINT_EXECUTABLE NAMES qmllint)
  if(QMLLINT_EXECUTABLE)
    file(GLOB CIDERDECK_QML_FILES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/qml/*.qml")
    add_test(NAME ciderdeck-qml-lint
      COMMAND "${QMLLINT_EXECUTABLE}" -I "${CMAKE_CURRENT_SOURCE_DIR}/src/qml" ${CIDERDECK_QML_FILES}
    )
  endif()

  if(TARGET Qt6::qmltestrunner)
    add_test(NAME ciderdeck-content-layout-qml-tests
      COMMAND Qt6::qmltestrunner
        -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/qml/tst_ContentLayoutController.qml"
        -import "${CMAKE_CURRENT_SOURCE_DIR}/src/qml"
    )
    set_tests_properties(ciderdeck-content-layout-qml-tests PROPERTIES
      ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    )

    add_test(NAME ciderdeck-metric-sparkline-qml-tests
      COMMAND Qt6::qmltestrunner
        -input "${CMAKE_CURRENT_SOURCE_DIR}/tests/qml/tst_MetricSparkline.qml"
        -import "${CMAKE_CURRENT_SOURCE_DIR}/src/qml"
    )
    set_tests_properties(ciderdeck-metric-sparkline-qml-tests PROPERTIES
      ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
    )
  endif()

  add_test(NAME ciderdeck-tile-scale-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyTileContentScale.cmake"
  )

  add_test(NAME ciderdeck-media-seek-controls-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyMediaSeekControls.cmake"
  )

  add_test(NAME ciderdeck-monitoring-activity-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyMonitoringActivityWiring.cmake"
  )

  add_test(NAME ciderdeck-system-monitor-smoothing-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifySystemMonitorSmoothing.cmake"
  )

  add_test(NAME ciderdeck-qt65-compatibility-contract
    COMMAND "${CMAKE_COMMAND}"
      "-DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/VerifyQt65Compatibility.cmake"
  )
endif()
