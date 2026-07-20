file(GLOB tile_files "${SOURCE_DIR}/src/qml/*Tile.qml")

if(NOT tile_files)
  message(FATAL_ERROR "No tile QML files found")
endif()

foreach(tile_file IN LISTS tile_files)
  file(READ "${tile_file}" tile_source)
  string(REGEX MATCHALL "contentScale" scale_references "${tile_source}")
  list(LENGTH scale_references scale_reference_count)
  if(scale_reference_count LESS 2)
    get_filename_component(tile_name "${tile_file}" NAME)
    message(FATAL_ERROR
      "${tile_name} must read the shared contentScale and apply it to visible content")
  endif()
endforeach()
