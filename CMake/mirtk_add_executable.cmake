# ==============================================================================
# Medical Image Registration ToolKit (MIRTK)
#
# Copyright 2013-2015 Imperial College London
# Copyright 2013-2015 Andreas Schuh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

include(CMakeParseArguments)

# ------------------------------------------------------------------------------
## Add build target for executable MIRTK command
function(mirtk_add_executable target_name)
  # Parse arguments
  if (NOT PROJECT_NAME)
    message(FATAL_ERROR "mirtk_add_executable called outside project scope!")
  endif ()
  cmake_parse_arguments(TARGET "" "" "SOURCES;DEPENDS;OPTIONAL" ${ARGN})
  if (TARGET_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "mirtk_add_library called with unrecognized arguments: ${TARGET_UNPARSED_ARGUMENTS}!")
  endif ()
  if ("^${target_name}$" STREQUAL "^commands$")
    message(FATAL_ERROR "Invalid command name ${target_name}, used internally!")
  endif ()
  # Add executable target
  set(LANGUAGE CXX)
  if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.cc")
    basis_add_executable(${target_name}.cc ${TARGET_SOURCES} LIBEXEC)
  elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.cxx")
    basis_add_executable(${target_name}.cxx ${TARGET_SOURCES} LIBEXEC)
  elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.cpp")
    basis_add_executable(${target_name}.cpp ${TARGET_SOURCES} LIBEXEC)
  elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.py" OR
          EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.py.in")
    basis_add_executable(${target_name}.py ${TARGET_SOURCES} LIBEXEC)
    set(LANGUAGE PYTHON)
  elseif (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.sh" OR
          EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${target_name}.sh.in")
    basis_add_executable(${target_name}.sh ${TARGET_SOURCES} LIBEXEC)
    set(LANGUAGE BASH)
  else ()
    message(FATAL_ERROR "Source file for MIRTK command ${target_name} not found!"
                        " Must have extension '.cc', '.cxx', '.cpp', '.sh', or '.py'."
                        " Exclude extension from mirtk_add_executable argument.")
  endif ()
  basis_set_target_properties(
    ${target_name} PROPERTIES
      OUTPUT_NAME "${PROJECT_PACKAGE_NAME_L}-${target_name}"
  )
  set_property(GLOBAL APPEND PROPERTY MIRTK_COMMANDS ${target_name})
  if (LANGUAGE STREQUAL CXX)
    if (BUILD_SHARED_LIBS)
      # FIXME: Should be set for each module independently in their mirtk<Module>Config.h
      #        Respectively, each module should provide a mirtk::Init<Module>() function
      #        which either does nothing or registers non-auto-registered types.
      basis_get_target_uid(target_uid ${target_name})
      target_compile_definitions(${target_uid} PRIVATE MIRTK_AUTO_REGISTER)
      # TODO: How can this be set as property of the library target and -Wl,--no-as-needed -l<library> -Wl,--as-needed
      #       be added to the executable link flags of those that depend on <library> ?
      if (CMAKE_CXX_COMPILER_ID STREQUAL GNU)
        basis_set_target_properties(${target_name} PROPERTIES LINK_FLAGS -Wl,--no-as-needed)
      endif ()
    endif ()
    # Add custom target to generate command documentation page
    if (BUILD_DOCUMENTATION AND BUILD_DOCUMENTATION_SOURCES AND NOT "^${target_name}$" STREQUAL "^help-rst$")
      if (TARGET help-rst)
        basis_get_target_location (mirtk_path mirtk ABSOLUTE)
        add_custom_target(${target_name}-description
          COMMAND "${mirtk_path}" help-rst "${target_name}" -generated -description -noheaders
                  -output "${TOPLEVEL_PROJECT_DOC_DIR}/commands/_descriptions/${target_name}.rst"
                  -output-brief-description "${TOPLEVEL_PROJECT_DOC_DIR}/commands/_summaries/${target_name}.rst"
          DEPENDS mirtk help-rst ${target_name}
          COMMENT "Extracting command description from ${target_name} -help"
        )
        add_custom_target(${target_name}-help
          COMMAND "${mirtk_path}" help-rst "${target_name}" -generated
                  "-include-description" "_descriptions/${target_name}.rst"
                  -output "${TOPLEVEL_PROJECT_DOC_DIR}/commands/${target_name}.rst"
          DEPENDS mirtk help-rst ${target_name} ${target_name}-description
          COMMENT "Generating documentation page for command ${target_name}"
        )
        if (NOT TARGET commands-help)
          add_custom_target(commands-help)
        endif ()
        add_dependencies(commands-help ${target_name}-help)
      else ()
        message(WARNING "Target help-rst missing! Skipping auto-generation of command documentation.")
      endif ()
    endif ()
    # Add required dependencies
    foreach (dep IN LISTS TARGET_DEPENDS)
      if (TARGET ${dep})
        get_property(type TARGET ${dep} PROPERTY TYPE)
        if (type MATCHES LIBRARY)
          basis_target_link_libraries(${target_name} ${dep})
        else ()
          basis_add_dependencies(${target_name} ${dep})
        endif ()
      else ()
        basis_target_link_libraries(${target_name} ${dep})
      endif ()
    endforeach ()
    # Add optional dependencies if targets exist
    foreach (dep IN LISTS TARGET_OPTIONAL)
      if (TARGET ${dep})
        get_property(type TARGET ${dep} PROPERTY TYPE)
        if (type MATCHES LIBRARY)
          basis_target_link_libraries(${target_name} ${dep})
          if ("^${dep}$" STREQUAL "^LibImage$")
            set(DEPENDS_ON_LibImage TRUE)
          endif ()
        else ()
          basis_add_dependencies(${target_name} ${dep})
        endif ()
      elseif (dep MATCHES "\\.(so|a|dylib|lib)(\\.[0-9].*)?$")
        basis_target_link_libraries(${target_name} ${dep})
      endif ()
    endforeach ()
  endif ()
endfunction()
