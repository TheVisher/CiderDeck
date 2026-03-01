cmake_minimum_required(VERSION 3.22)
project(ciderdeck VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick DBus Widgets)
find_package(Qt6 6.5 OPTIONAL_COMPONENTS Multimedia)
find_package(Qt5Compat 6.5 QUIET COMPONENTS GraphicalEffects)

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
  src/services/MprisManager.h
  src/services/MprisManager.cpp
  src/services/WeatherService.h
  src/services/WeatherService.cpp
  src/services/SystemMonitorService.h
  src/services/SystemMonitorService.cpp
  src/services/ProcessManagerService.h
  src/services/ProcessManagerService.cpp
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

  src/viewmodels/TileGridModel.h
  src/viewmodels/TileGridModel.cpp
  src/viewmodels/EditModeController.h
  src/viewmodels/EditModeController.cpp
  src/viewmodels/ToastModel.h
  src/viewmodels/ToastModel.cpp
  src/viewmodels/InstalledAppsModel.h
  src/viewmodels/InstalledAppsModel.cpp

  src/qml/qml.qrc
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
  Qt6::Gui
  Qt6::Qml
  Qt6::Quick
  Qt6::DBus
  Qt6::Widgets
)

# Qt5Compat for GraphicalEffects (DropShadow, etc.)
if(TARGET Qt6::Qt5Compat)
  target_link_libraries(ciderdeck PRIVATE Qt6::Qt5Compat)
elseif(TARGET Qt5Compat::GraphicalEffects)
  target_link_libraries(ciderdeck PRIVATE Qt5Compat::GraphicalEffects)
endif()

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

if(Qt6Multimedia_FOUND)
  target_link_libraries(ciderdeck PRIVATE Qt6::Multimedia)
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
install(FILES ciderdeck.desktop DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/autostart")
install(FILES kwin-scripts/ciderdeck-bridge.js
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/ciderdeck/kwin-scripts")
install(FILES data/icons/ciderdeck.svg
        DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/icons/hicolor/scalable/apps")
