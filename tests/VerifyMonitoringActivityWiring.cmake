if(NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "SOURCE_DIR is required")
endif()

function(assert_contains file_path expected description)
  file(READ "${file_path}" contents)
  string(FIND "${contents}" "${expected}" match_index)
  if(match_index EQUAL -1)
    message(FATAL_ERROR "${description}: expected '${expected}' in ${file_path}")
  endif()
endfunction()

set(qml_dir "${SOURCE_DIR}/src/qml")

assert_contains(
  "${qml_dir}/DashboardPage.qml"
  "readonly property bool activePage: pageIndex === deckConfig.currentPage"
  "Dashboard activity must be derived explicitly from the configured current page")
assert_contains(
  "${qml_dir}/DashboardPage.qml"
  "monitoringActive: page.activePage"
  "Dashboard activity must be propagated to each tile loader")

assert_contains(
  "${qml_dir}/TileLoader.qml"
  "property bool monitoringActive"
  "TileLoader must accept explicit monitoring activity")
assert_contains(
  "${qml_dir}/TileLoader.qml"
  "property bool monitoringActive: tileLoader.monitoringActive"
  "TileLoader must propagate activity to the loaded tile")

foreach(tile_spec IN ITEMS
    "SystemMonitorTile.qml|systemMonitor|sysmonTile"
    "ProcessManagerTile.qml|processManager|procTile")
  string(REPLACE "|" ";" tile_parts "${tile_spec}")
  list(GET tile_parts 0 tile_file)
  list(GET tile_parts 1 service_name)
  list(GET tile_parts 2 tile_id)
  set(tile_path "${qml_dir}/${tile_file}")

  assert_contains(
    "${tile_path}"
    "property bool monitoringActive: parent ? parent.monitoringActive : false"
    "${tile_file} must consume the explicit page activity")
  assert_contains(
    "${tile_path}"
    "Component.onCompleted: ${service_name}.setConsumerActive(${tile_id}, ${tile_id}.monitoringActive)"
    "${tile_file} must register its initial consumer state")
  assert_contains(
    "${tile_path}"
    "onMonitoringActiveChanged: ${service_name}.setConsumerActive(${tile_id}, ${tile_id}.monitoringActive)"
    "${tile_file} must update its consumer state when pages change")
endforeach()
