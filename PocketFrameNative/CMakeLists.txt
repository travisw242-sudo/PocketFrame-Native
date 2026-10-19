cmake_minimum_required(VERSION 3.25)
project(PocketFrameNative LANGUAGES CXX)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(FATAL_ERROR "Use the Linux/ARM64 toolchain. This target never builds the Windows DLL.")
endif()
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
# The emulator is dynamically linked to libstdc++. Do not export a second,
# statically linked C++ runtime from the adapter into the same process: locale
# facet IDs/vtables can interpose across versions and crash during game loading.
set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL "Share the platform C++ runtime with Azahar" FORCE)
set(GODOTCPP_TARGET template_release CACHE STRING "" FORCE)
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/native/pocketframe_azahar/build_profile.json" CACHE FILEPATH "Only bindings used by the native emulator adapter" FORCE)
set(GODOTCPP_CUSTOM_API_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../extension_api.json" CACHE FILEPATH "Godot 4.7.2 API")
set(GODOTCPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../work/godot-cpp-main" CACHE PATH "Bindings source")
add_subdirectory("${GODOTCPP_DIR}" godot-cpp)
find_package(Threads REQUIRED)
set(PF_NATIVE native/pocketframe_azahar)
add_library(PocketFrameRuntime SHARED
    ${PF_NATIVE}/src/register_types.cpp
    ${PF_NATIVE}/src/azahar_core.cpp
    ${PF_NATIVE}/src/vulkan_host.cpp)
target_compile_features(PocketFrameRuntime PRIVATE cxx_std_20)
target_compile_definitions(PocketFrameRuntime PRIVATE TYPED_METHOD_BIND VK_NO_PROTOTYPES)
target_include_directories(PocketFrameRuntime PRIVATE
    ${PF_NATIVE}/include
    ../work/AzaharSource/externals/libretro-common/libretro-common/include
    ../work/AzaharSource/externals/vulkan-headers/include)
target_link_libraries(PocketFrameRuntime PRIVATE godot::cpp Threads::Threads ${CMAKE_DL_LIBS})
set_target_properties(PocketFrameRuntime PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin")

add_executable(PocketFrameTouchTest EXCLUDE_FROM_ALL ${PF_NATIVE}/tests/test_touch_mapping.cpp)
target_compile_features(PocketFrameTouchTest PRIVATE cxx_std_20)
target_include_directories(PocketFrameTouchTest PRIVATE ${PF_NATIVE}/include)
