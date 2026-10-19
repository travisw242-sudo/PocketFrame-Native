cmake_minimum_required(VERSION 3.25)
# Legacy Windows adapter entry point retained from the shared source snapshot.
# Native Steam Frame builds use PocketFrameNative/CMakeLists.txt instead.
project(PocketFrameAzahar LANGUAGES CXX)
add_executable(PocketFrameNetworkProbe EXCLUDE_FROM_ALL tests/network_probe.cpp)
target_include_directories(PocketFrameNetworkProbe PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../../../third_party/azahar/externals/libretro-common/libretro-common/include")
target_compile_features(PocketFrameNetworkProbe PRIVATE cxx_std_20)
add_executable(PocketFrameTouchTest EXCLUDE_FROM_ALL tests/test_touch_mapping.cpp)
target_include_directories(PocketFrameTouchTest PRIVATE include)
target_compile_features(PocketFrameTouchTest PRIVATE cxx_std_20)

# Build this extension against the bindings generated from the installed Godot
# 4.7 runtime.  The paths stay outside the shipping project so the generated
# SDK and the GPL-covered emulator source are never silently bundled.
set(GODOT_CPP_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../third_party/godot-cpp" CACHE PATH "godot-cpp source")
set(GODOT_CPP_BUILD_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../work/godot-cpp-4.7-build" CACHE PATH "generated godot-cpp build")

# Reuse the already-built bindings.  This keeps extension-only rebuilds quick
# and makes the generated headers unambiguously match the local Godot 4.7 API.
add_library(godot-cpp STATIC IMPORTED)
set_target_properties(godot-cpp PROPERTIES
    IMPORTED_LOCATION "${GODOT_CPP_BUILD_DIR}/bin/libgodot-cpp.windows.template_release.x86_64.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${GODOT_CPP_DIR}/include;${GODOT_CPP_BUILD_DIR}/gen/include"
)

add_library(PocketFrameAzahar SHARED
    src/register_types.cpp
    src/azahar_core.cpp
    src/vulkan_host.cpp
)
target_compile_features(PocketFrameAzahar PRIVATE cxx_std_20)
target_compile_definitions(PocketFrameAzahar PRIVATE TYPED_METHOD_BIND VK_NO_PROTOTYPES)
if(MSVC)
    target_compile_options(PocketFrameAzahar PRIVATE /Zc:__cplusplus)
    set_property(TARGET PocketFrameAzahar PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()
target_include_directories(PocketFrameAzahar PRIVATE include)
target_include_directories(PocketFrameAzahar PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../../../third_party/azahar/externals/libretro-common/libretro-common/include")
# Azahar ships the Vulkan LibRetro protocol and headers in-tree.  Linking the
# loader here prepares an opt-in Vulkan frontend without changing the stable
# OpenGL fallback path.
target_include_directories(PocketFrameAzahar PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../../../third_party/azahar/externals/vulkan-headers/include")
target_link_libraries(PocketFrameAzahar PRIVATE godot-cpp opengl32)
set_target_properties(PocketFrameAzahar PROPERTIES
 OUTPUT_NAME "PocketFrameRuntime"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/../../bin"
)
