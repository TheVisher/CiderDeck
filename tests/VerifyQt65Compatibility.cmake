file(READ "${SOURCE_DIR}/src/viewmodels/InstalledAppsModel.cpp" installed_apps_source)
file(READ "${SOURCE_DIR}/CMakeLists.txt" cmake_source)

string(FIND "${installed_apps_source}"
  "QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)"
  modern_filter_guard)
string(FIND "${installed_apps_source}"
  "!defined(CIDERDECK_FORCE_QT65_FILTER_API)"
  forced_qt65_guard)
string(FIND "${installed_apps_source}"
  "invalidateFilter();"
  qt65_filter_invalidation)
string(FIND "${cmake_source}"
  "add_library(ciderdeck-qt65-compatibility-build OBJECT"
  qt65_build_target)
string(FIND "${cmake_source}"
  "CIDERDECK_FORCE_QT65_FILTER_API"
  qt65_build_definition)

if(modern_filter_guard EQUAL -1 OR
   forced_qt65_guard EQUAL -1 OR
   qt65_filter_invalidation EQUAL -1 OR
   qt65_build_target EQUAL -1 OR
   qt65_build_definition EQUAL -1)
  message(FATAL_ERROR
    "AppFilterModel must retain a Qt 6.5-compatible invalidateFilter() path and "
    "a build target that compiles that path on the current Qt version")
endif()
