option(BUILD_TEST "build test" ON)
set(USE_CUDA OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


function(scan_target name)
    file(GLOB_RECURSE h         CONFIGURE_DEPENDS src/*.h)
    file(GLOB_RECURSE hpp       CONFIGURE_DEPENDS src/*.hpp)
    file(GLOB_RECURSE private_h CONFIGURE_DEPENDS src/*.private.h)
    file(GLOB_RECURSE private_hpp CONFIGURE_DEPENDS src/*.private.hpp)
    file(GLOB_RECURSE cpp       CONFIGURE_DEPENDS src/*.cpp)
    file(GLOB         main      CONFIGURE_DEPENDS src/main.cpp)
    file(GLOB_RECURSE ixx       CONFIGURE_DEPENDS src/*.ixx)
    file(GLOB_RECURSE test      CONFIGURE_DEPENDS src/*.test.cpp)

    file(GLOB_RECURSE cu        CONFIGURE_DEPENDS src/*.cu)
    file(GLOB_RECURSE test_cu   CONFIGURE_DEPENDS src/*.test.cu)

    if(cu)
        if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
            set(CMAKE_CUDA_ARCHITECTURES 75 86 89 90)
        endif()
        enable_language(CUDA)
        set(CMAKE_CUDA_STANDARD 20)
        set(CMAKE_CUDA_STANDARD_REQUIRED ON)
        set(CMAKE_CUDA_EXTENSIONS ON)
    endif ()


    list(REMOVE_ITEM h ${private_h})
    list(REMOVE_ITEM hpp ${private_hpp})
    list(REMOVE_ITEM cpp ${test} ${main})
    list(REMOVE_ITEM cu ${test_cu})



    set(${name}_header ${h} ${hpp} PARENT_SCOPE)
    set(${name}_main ${main} PARENT_SCOPE)
    set(${name}_src ${cu} ${cpp} PARENT_SCOPE)
    set(${name}_ixx ${ixx} PARENT_SCOPE)
    set(${name}_test ${test} ${test_cu} PARENT_SCOPE)
endfunction()

function(configure_target target)
    scan_target(${target})
    get_target_property(target_type ${target} TYPE)
    set(lib ${target})
    list(APPEND ${target}_src ${${target}_main})

    if (${target}_src)
        target_sources(${lib}
                PRIVATE ${${target}_src})
    endif ()
    if (${target}_ixx)
        target_sources(${lib}
                PUBLIC FILE_SET ixx
                TYPE CXX_MODULES
                FILES ${${target}_ixx})
    endif ()
    if (${target}_header)
        if (target_type STREQUAL "INTERFACE_LIBRARY")
            target_include_directories(${lib} INTERFACE src)
            target_sources(${lib}
                    INTERFACE FILE_SET h
                    TYPE HEADERS
                    FILES ${${target}_header})
        else ()
            target_include_directories(${lib} PUBLIC src)
            target_sources(${lib}
                    PUBLIC FILE_SET h
                    TYPE HEADERS
                    FILES ${${target}_header})
        endif ()
    endif ()


    if (BUILD_TEST AND NOT target_type STREQUAL "EXECUTABLE")
        foreach (file ${${target}_test})
            get_filename_component(name ${file} NAME_WLE)
            get_filename_component(name ${name} NAME_WLE)

            set(test_exe_name "${target}-test__${name}")
            add_executable(${test_exe_name} ${file})
            target_link_libraries(${test_exe_name} PRIVATE ${lib})
        endforeach ()
    endif ()
endfunction()


find_program(VCPKG NAMES vcpkg.exe)

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(TARGET_ARCH x64)
else()
    set(TARGET_ARCH x86)
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
    set(TARGET_ARCH arm64)
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
    set(TARGET_ARCH arm)
endif()

string(TOLOWER "${TARGET_ARCH}-${CMAKE_SYSTEM_NAME}" target_triple)

if (VCPKG)
    get_filename_component(VCPKG_ROOT ${VCPKG} DIRECTORY)
    set(CMAKE_TOOLCHAIN_FILE
            "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
            CACHE STRING ""
    )
#    include_directories(
#            "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}/include"
#            "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}-static/include")
#    if (${CMAKE_BUILD_TYPE} STREQUAL Debug)
#        link_directories(
#                "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}/debug/lib"
#                "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}-static/debug/lib" )
#    else ()
#        link_directories(
#                "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}/lib"
#                "${PROJECT_SOURCE_DIR}/.vcpkg/${target_triple}-static/lib" )
#    endif ()
    function(add_vcpkg_library name type)
        string(TOLOWER "${name}:${target_triple}" tgt)
        if (type STREQUAL STATIC)
            set(tgt ${tgt}-static)
        endif ()
        execute_process(COMMAND ${VCPKG} install ${tgt} --x-install-root=${PROJECT_SOURCE_DIR}/.vcpkg)
    endfunction()
else()
    function(add_vcpkg_library)
        message(FATAL_ERROR "VCPKG Not Found in Path, disable 'add_vcpkg_library'")
    endfunction()
endif ()