#!/usr/bin/env bash
set -euo pipefail
# Run inside Ubuntu after tools/setup-ubuntu.sh. No Windows build paths are used.
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace_dir="$(cd "$project_dir/.." && pwd)"
build_dir="${PF_BUILD_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/pocketframe-arm64}"
jobs="${PF_BUILD_JOBS:-2}"
toolchain="$project_dir/tools/linux-arm64.cmake"
for tool in cmake ninja aarch64-linux-gnu-g++ python3; do
    command -v "$tool" >/dev/null || { echo "Missing $tool. Run tools/setup-ubuntu.sh first." >&2; exit 1; }
done
test -f "$workspace_dir/extension_api.json"
test -f "$workspace_dir/third_party/azahar/CMakeLists.txt"
test -f "$workspace_dir/third_party/godot-cpp/CMakeLists.txt"
cmake -S "$workspace_dir/third_party/azahar" -B "$build_dir/core" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_LIBRETRO=ON -DENABLE_VULKAN=ON -DENABLE_OPENGL=OFF \
    -DENABLE_QT=OFF -DENABLE_SDL2=OFF -DENABLE_WEB_SERVICE=OFF \
    -DENABLE_SCRIPTING=OFF -DENABLE_GDBSTUB=OFF -DENABLE_OPENAL=OFF \
    -DENABLE_CUBEB=OFF -DENABLE_FFMPEG=OFF -DENABLE_ROOM=OFF \
    -DENABLE_ROOM_STANDALONE=OFF -DENABLE_LIBUSB=OFF \
    -DENABLE_LTO=OFF -DCITRA_WARNINGS_AS_ERRORS=OFF
cmake --build "$build_dir/core" --target citra_libretro --parallel "$jobs"
cmake -S "$project_dir" -B "$build_dir/extension" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$toolchain" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_dir/extension" --target PocketFrameRuntime --parallel "$jobs"
mapfile -t cores < <(find "$build_dir/core" -type f -name azahar_libretro.so)
if [[ ${#cores[@]} != 1 ]]; then
    echo "Expected exactly one core library; found ${#cores[@]}. Nothing staged." >&2
    exit 1
fi
for library in "${cores[0]}" "$project_dir/bin/libPocketFrameRuntime.so"; do
    aarch64-linux-gnu-readelf -h "$library" | grep -q 'Machine:.*AArch64'
    file "$library"
    aarch64-linux-gnu-readelf -d "$library" | grep NEEDED || true
done
mkdir -p "$project_dir/runtime/vulkan"
install -m 755 "${cores[0]}" "$project_dir/runtime/vulkan/azahar_libretro.so"
echo "ARM64 libraries staged. Godot export and real-headset testing are still required."
