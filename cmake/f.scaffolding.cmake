option(BUILD_TEST "build test" ON)
set(USE_CUDA OFF)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_CUDA_STANDARD 20)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_EXTENSIONS ON)

function(scan_target name)
    file(GLOB_RECURSE h src/*.h)
    file(GLOB_RECURSE hpp src/*.hpp)
    file(GLOB_RECURSE private_h src/*.private.h)
    file(GLOB_RECURSE private_hpp src/*.private.hpp)
    file(GLOB_RECURSE cpp src/*.cpp)
    file(GLOB_RECURSE ixx src/*.ixx)
    file(GLOB_RECURSE test src/*.test.cpp)

    file(GLOB_RECURSE cu src/*.cu)
    file(GLOB_RECURSE test_cu src/*.test.cu)

    set(MODULE_ENABLE OFF)
    set(CUDA_ENABLE OFF)

    if (ixx)
        message(NOTICE "module detected")
        set(MODULE_ENABLE ON)
    endif ()
    if (cu)
        message(NOTICE "CUDA detected")
        set(CUDA_ENABLE ON)
    endif ()

    list(REMOVE_ITEM h ${private_h})
    list(REMOVE_ITEM hpp ${private_hpp})
    list(REMOVE_ITEM cpp ${test})
    list(REMOVE_ITEM cu ${test_cu})



    set(${name}_h ${h} PARENT_SCOPE)
    set(${name}_hpp ${hpp} PARENT_SCOPE)
    set(${name}_cu ${cu} PARENT_SCOPE)
    set(${name}_cpp ${cpp} PARENT_SCOPE)
    set(${name}_ixx ${ixx} PARENT_SCOPE)
    set(${name}_test ${test} PARENT_SCOPE)
    set(${name}_test_cu ${test_cu} PARENT_SCOPE)

    set(CUDA_ENABLE ${CUDA_ENABLE} PARENT_SCOPE)
    set(MODULE_ENABLE ${MODULE_ENABLE} PARENT_SCOPE)
endfunction()

function(configure_target target)
    scan_target(${target})

    target_sources(${target}
            PRIVATE ${${target}_cpp} ${${target}_cu}

            PUBLIC FILE_SET ixx
            TYPE CXX_MODULES
            FILES ${${target}_ixx}
            PUBLIC FILE_SET h
            TYPE HEADERS
            FILES ${${target}_h}
            PUBLIC FILE_SET hpp
            TYPE HEADERS
            FILES ${${target}_hpp})

    if (BUILD_TEST)
        foreach (file ${${target}_test} ${${target}_test_cu})
            get_filename_component(name ${file} NAME_WLE)
            get_filename_component(name ${name} NAME_WLE)

            set(test_exe_name "test-${target}-${name}")
            add_executable(${test_exe_name} ${file})
            target_link_libraries(${test_exe_name} PRIVATE ${target})
        endforeach ()
    endif ()

endfunction()