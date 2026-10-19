#include "azahar_core.hpp"
#include "vulkan_host.hpp"
#include "touch_mapping.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <libretro.h>
#include <libretro_vulkan.h>
#ifdef _WIN32
#include <windows.h>
#include <gl/GL.h>
#else
#include <dlfcn.h>
#include <unistd.h>
#endif
#include <climits>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <cstdio>
#include <cstdarg>

using namespace godot;
namespace {
PFAzaharCore *g_core = nullptr;
std::atomic_int g_resolution_factor{1};
std::atomic_int g_stereo_depth{0};
std::atomic_bool g_options_dirty{false};
std::string g_player_name;
std::atomic_bool g_vulkan_enabled{false};
PFVulkanHost g_vulkan;
retro_hw_render_callback *g_vulkan_callback = nullptr;
const retro_hw_render_context_negotiation_interface_vulkan *g_vulkan_negotiation = nullptr;
std::atomic_uint64_t g_readback_us{0};
void RETRO_CALLCONV core_log(enum retro_log_level level, const char *format, ...) {
    if (level < RETRO_LOG_WARN) return;
    va_list args; va_start(args, format); std::vfprintf(stderr, format, args); va_end(args);
}
// This owns a small, invisible WGL context solely for the LibRetro core.  Godot
// keeps its own Vulkan/OpenXR context; the two are deliberately not shared.
// The interim transfer is GPU render -> glReadPixels -> latest Godot texture.
// It is not zero-copy, but it removes software 3DS rendering from the hot path.
#ifdef _WIN32
struct GLHost {
    HWND window{}; HDC dc{}; HGLRC rc{}; GLuint fbo{}, color{}; unsigned width{}, height{};
    // All three are persistent: allocating them at 60 Hz was a substantial
    // source of periodic allocator stalls, especially in 2x quality mode.
    std::vector<uint8_t> pixels, flipped, native;
    using GenFbo = void (APIENTRY *)(GLsizei, GLuint*); using BindFbo = void (APIENTRY *)(GLenum, GLuint);
    using DelFbo = void (APIENTRY *)(GLsizei, const GLuint*); using CheckFbo = GLenum (APIENTRY *)(GLenum);
    using AttachTex = void (APIENTRY *)(GLenum, GLenum, GLenum, GLuint, GLint);
    using GenBuffers = void (APIENTRY *)(GLsizei, GLuint*); using BindBuffer = void (APIENTRY *)(GLenum, GLuint);
    using BufferData = void (APIENTRY *)(GLenum, ptrdiff_t, const void*, GLenum);
    using MapBufferRange = void *(APIENTRY *)(GLenum, ptrdiff_t, ptrdiff_t, GLbitfield);
    using UnmapBuffer = GLboolean (APIENTRY *)(GLenum); using DelBuffers = void (APIENTRY *)(GLsizei, const GLuint*);
    using FenceSync = void *(APIENTRY *)(GLenum, GLbitfield); using ClientWaitSync = GLenum (APIENTRY *)(void *, GLbitfield, uint64_t);
    using DelSync = void (APIENTRY *)(void *);
    GenFbo gen_fbo{}; BindFbo bind_fbo{}; DelFbo del_fbo{}; CheckFbo check_fbo{}; AttachTex attach_tex{};
    GenBuffers gen_buffers{}; BindBuffer bind_buffer{}; BufferData buffer_data{}; MapBufferRange map_buffer_range{}; UnmapBuffer unmap_buffer{}; DelBuffers del_buffers{};
    FenceSync fence_sync{}; ClientWaitSync client_wait_sync{}; DelSync del_sync{};
    GLuint readback_pbos[3]{}; void *readback_fences[3]{}; unsigned pbo_write{}, pbo_read{}, pbo_pending{}; size_t pbo_bytes{};
    static constexpr GLenum FRAMEBUFFER = 0x8D40, COLOR_ATTACHMENT0 = 0x8CE0, FRAMEBUFFER_COMPLETE = 0x8CD5, BGRA = 0x80E1, RGBA8 = 0x8058,
        PIXEL_PACK_BUFFER = 0x88EB, STREAM_READ = 0x88E1, MAP_READ_BIT = 0x0001, SYNC_GPU_COMMANDS_COMPLETE = 0x9117,
        ALREADY_SIGNALED = 0x911A, CONDITION_SATISFIED = 0x911C;
    void *proc(const char *name) {
        void *p = reinterpret_cast<void*>(wglGetProcAddress(name));
        if (!p || p == reinterpret_cast<void*>(1) || p == reinterpret_cast<void*>(2) || p == reinterpret_cast<void*>(3) || p == reinterpret_cast<void*>(-1))
            p = reinterpret_cast<void*>(GetProcAddress(GetModuleHandleA("opengl32.dll"), name));
        return p;
    }
    bool make_current() {
        if (rc) return wglMakeCurrent(dc, rc) == TRUE;
        WNDCLASSA wc{}; wc.style = CS_OWNDC; wc.lpfnWndProc = DefWindowProcA; wc.hInstance = GetModuleHandleA(nullptr); wc.lpszClassName = "PocketFrameAzaharGL";
        RegisterClassA(&wc);
        window = CreateWindowA(wc.lpszClassName, "", WS_POPUP, 0, 0, 1, 1, nullptr, nullptr, wc.hInstance, nullptr);
        if (!window) return false;
        dc = GetDC(window); PIXELFORMATDESCRIPTOR pfd{}; pfd.nSize = sizeof(pfd); pfd.nVersion = 1; pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER; pfd.iPixelType = PFD_TYPE_RGBA; pfd.cColorBits = 32; pfd.cDepthBits = 24;
        const int format = ChoosePixelFormat(dc, &pfd);
        if (!format || !SetPixelFormat(dc, format, &pfd)) return false;
        rc = wglCreateContext(dc);
        if (!rc || !wglMakeCurrent(dc, rc)) return false;
        gen_fbo = reinterpret_cast<GenFbo>(proc("glGenFramebuffers")); bind_fbo = reinterpret_cast<BindFbo>(proc("glBindFramebuffer")); del_fbo = reinterpret_cast<DelFbo>(proc("glDeleteFramebuffers")); check_fbo = reinterpret_cast<CheckFbo>(proc("glCheckFramebufferStatus")); attach_tex = reinterpret_cast<AttachTex>(proc("glFramebufferTexture2D"));
        gen_buffers = reinterpret_cast<GenBuffers>(proc("glGenBuffers")); bind_buffer = reinterpret_cast<BindBuffer>(proc("glBindBuffer")); buffer_data = reinterpret_cast<BufferData>(proc("glBufferData")); map_buffer_range = reinterpret_cast<MapBufferRange>(proc("glMapBufferRange")); unmap_buffer = reinterpret_cast<UnmapBuffer>(proc("glUnmapBuffer")); del_buffers = reinterpret_cast<DelBuffers>(proc("glDeleteBuffers")); fence_sync = reinterpret_cast<FenceSync>(proc("glFenceSync")); client_wait_sync = reinterpret_cast<ClientWaitSync>(proc("glClientWaitSync")); del_sync = reinterpret_cast<DelSync>(proc("glDeleteSync"));
        return gen_fbo && bind_fbo && del_fbo && check_fbo && attach_tex;
    }
    uintptr_t framebuffer() {
        if (!make_current()) return 0;
        const unsigned factor = std::clamp(g_resolution_factor.load(), 1, 3);
        const unsigned out_w = 400 * factor * (g_stereo_depth.load() > 0 ? 2 : 1);
        const unsigned out_h = 480 * factor;
        if (!fbo) { gen_fbo(1, &fbo); glGenTextures(1, &color); }
        if (width != out_w || height != out_h) { width = out_w; height = out_h; glBindTexture(GL_TEXTURE_2D, color); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); glTexImage2D(GL_TEXTURE_2D, 0, RGBA8, width, height, 0, BGRA, GL_UNSIGNED_BYTE, nullptr); }
        bind_fbo(FRAMEBUFFER, fbo); attach_tex(FRAMEBUFFER, COLOR_ATTACHMENT0, GL_TEXTURE_2D, color, 0);
        return check_fbo(FRAMEBUFFER) == FRAMEBUFFER_COMPLETE ? fbo : 0;
    }
    void readback(PFAzaharCore *core, unsigned w, unsigned h) {
        if (!core || !make_current() || !fbo || !color) return;
        const size_t byte_count = static_cast<size_t>(w) * h * 4;
        // Pixel-buffer objects let the GPU copy the frame in the background.
        // We never wait here: if a scene transition is still rendering, VR
        // simply retains the last finished image for one refresh.
        // Kept behind this safety gate until the WGL worker context can be
        // validated against SteamVR's OpenXR compositor. The persistent CPU
        // buffers below remain active in both paths.
        const bool async = false;
        if (async && pbo_bytes != byte_count) {
            for (unsigned i = 0; i < 3; ++i) { if (readback_fences[i]) { del_sync(readback_fences[i]); readback_fences[i] = nullptr; } }
            if (readback_pbos[0]) del_buffers(3, readback_pbos);
            std::fill(std::begin(readback_pbos), std::end(readback_pbos), 0); pbo_write = pbo_read = pbo_pending = 0; pbo_bytes = byte_count;
            gen_buffers(3, readback_pbos);
            for (unsigned i = 0; i < 3; ++i) { bind_buffer(PIXEL_PACK_BUFFER, readback_pbos[i]); buffer_data(PIXEL_PACK_BUFFER, static_cast<ptrdiff_t>(byte_count), nullptr, STREAM_READ); }
            bind_buffer(PIXEL_PACK_BUFFER, 0);
        }
        if (async && readback_pbos[0]) {
            if (pbo_pending) {
                const GLenum done = client_wait_sync(readback_fences[pbo_read], 0, 0);
                if (done == ALREADY_SIGNALED || done == CONDITION_SATISFIED) {
                    bind_buffer(PIXEL_PACK_BUFFER, readback_pbos[pbo_read]);
                    void *mapped = map_buffer_range(PIXEL_PACK_BUFFER, 0, static_cast<ptrdiff_t>(byte_count), MAP_READ_BIT);
                    if (mapped) { if (pixels.size() != byte_count) pixels.resize(byte_count); std::copy_n(static_cast<const uint8_t *>(mapped), byte_count, pixels.data()); unmap_buffer(PIXEL_PACK_BUFFER); }
                    bind_buffer(PIXEL_PACK_BUFFER, 0); del_sync(readback_fences[pbo_read]); readback_fences[pbo_read] = nullptr; pbo_read = (pbo_read + 1) % 3; --pbo_pending;
                    if (!mapped) return;
                } else return;
            }
            bind_fbo(FRAMEBUFFER, fbo); bind_buffer(PIXEL_PACK_BUFFER, readback_pbos[pbo_write]); glReadPixels(0, 0, w, h, BGRA, GL_UNSIGNED_BYTE, nullptr); bind_buffer(PIXEL_PACK_BUFFER, 0); readback_fences[pbo_write] = fence_sync(SYNC_GPU_COMMANDS_COMPLETE, 0); pbo_write = (pbo_write + 1) % 3; ++pbo_pending;
        } else {
            bind_fbo(FRAMEBUFFER, fbo); if (pixels.size() != byte_count) pixels.resize(byte_count); glReadPixels(0, 0, w, h, BGRA, GL_UNSIGNED_BYTE, pixels.data());
        }
        // OpenGL starts at bottom-left while PocketFrame textures start at top-left.
        if (flipped.size() != byte_count) flipped.resize(byte_count); const size_t row = static_cast<size_t>(w) * 4;
        for (unsigned y = 0; y < h; ++y) std::copy_n(pixels.data() + static_cast<size_t>(h - 1 - y) * row, row, flipped.data() + static_cast<size_t>(y) * row);
        // Preserve all rendered detail at every preset. Physical panel size and
        // normalized touch coordinates are independent of texture resolution.
        core->receive_frame(flipped.data(), w, h, row);
    }
    void destroy() { if (!rc) return; wglMakeCurrent(dc, rc); for (unsigned i = 0; i < 3; ++i) if (readback_fences[i] && del_sync) del_sync(readback_fences[i]); if (readback_pbos[0] && del_buffers) del_buffers(3, readback_pbos); if (fbo) del_fbo(1, &fbo); if (color) glDeleteTextures(1, &color); wglMakeCurrent(nullptr, nullptr); wglDeleteContext(rc); ReleaseDC(window, dc); DestroyWindow(window); window = nullptr; dc = nullptr; rc = nullptr; fbo = color = 0; std::fill(std::begin(readback_pbos), std::end(readback_pbos), 0); std::fill(std::begin(readback_fences), std::end(readback_fences), nullptr); pbo_bytes = pbo_pending = pbo_read = pbo_write = 0; }
} g_gl;
#else
// Native Steam Frame is Vulkan-only. No GL/WGL dependency in this target.
struct GLHost {
    unsigned width=0,height=0;
    bool make_current(){return false;}
    uintptr_t framebuffer(){return 0;}
    void* proc(const char*){return nullptr;}
    void readback(PFAzaharCore*,unsigned,unsigned){}
    void destroy(){}
} g_gl;
#endif
uintptr_t RETRO_CALLCONV current_framebuffer() { return g_gl.framebuffer(); }
retro_proc_address_t RETRO_CALLCONV gl_proc(const char *name) { return reinterpret_cast<retro_proc_address_t>(g_gl.proc(name)); }
void RETRO_CALLCONV video(const void *p, unsigned w, unsigned h, size_t pitch) {
    if (!g_core) return;
    if (p == RETRO_HW_FRAME_BUFFER_VALID) {
        if (g_vulkan_enabled.load()) {
            const auto begin = std::chrono::steady_clock::now();
            if (!g_vulkan.readback(g_core, w, h)) throw std::runtime_error("Vulkan frame transfer failed");
            g_readback_us.fetch_add(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-begin).count());
        } else g_gl.readback(g_core, w, h);
    } else if (p) g_core->receive_frame(p,w,h,pitch);
}
size_t RETRO_CALLCONV audio(const int16_t *samples, size_t frames) { if (g_core && samples) g_core->receive_audio(samples, frames); return frames; }
void RETRO_CALLCONV poll() {}
int16_t RETRO_CALLCONV input(unsigned, unsigned device, unsigned index, unsigned id) { return g_core ? g_core->read_input(device,index,id) : 0; }
const char *native_data_directory() {
    static const std::string path = [] {
        const char* profile=std::getenv("POCKETFRAME_PROFILE");
        std::filesystem::path data;
        if(profile && *profile) data=profile;
        else if(const char* xdg=std::getenv("XDG_DATA_HOME");xdg && *xdg)
            data=std::filesystem::path(xdg)/"PocketFrame Native"/"emulator";
        else if(const char* home=std::getenv("HOME");home && *home)
            data=std::filesystem::path(home)/".local/share/PocketFrame Native/emulator";
        else throw std::runtime_error("No writable native profile directory configured");
        std::filesystem::create_directories(data);
        return data.string();
    }();
    return path.c_str();
}
bool RETRO_CALLCONV env(unsigned cmd, void *data) {
    switch (cmd) {
    case RETRO_ENVIRONMENT_GET_LOG_INTERFACE:
        static_cast<retro_log_callback*>(data)->log = core_log; return true;
    case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: case RETRO_ENVIRONMENT_SET_VARIABLES:
    case RETRO_ENVIRONMENT_SET_CORE_OPTIONS: case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
    case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO: case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
    case RETRO_ENVIRONMENT_SET_GEOMETRY: return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *static_cast<bool*>(data)=g_options_dirty.exchange(false); return true;
    case RETRO_ENVIRONMENT_GET_VARIABLE: {
        auto *variable = static_cast<retro_variable*>(data);
        if (variable && variable->key && std::strcmp(variable->key, "pocketframe_username") == 0) {
            variable->value = g_player_name.c_str(); return true;
        }
        if (variable && variable->key && std::strcmp(variable->key, "citra_render_3d") == 0) {
            variable->value = g_stereo_depth.load() > 0 ? "side-by-side-full" : "off"; return true;
        }
        if (variable && variable->key && std::strcmp(variable->key, "citra_factor_3d") == 0) {
            thread_local std::string factor;
            factor = std::to_string(g_stereo_depth.load()); variable->value = factor.c_str(); return true;
        }
        if (variable && variable->key && std::strcmp(variable->key, "citra_async_shader_compilation") == 0) {
            variable->value = g_vulkan_enabled.load() ? "enabled" : "disabled";
            return true;
        }
        if (variable && variable->key && std::strcmp(variable->key, "citra_resolution_factor") == 0) {
            const int factor = std::clamp(g_resolution_factor.load(), 1, 3);
            variable->value = const_cast<char*>(factor == 3 ? "3" : factor == 2 ? "2" : "1");
            return true;
        }
        if (variable && variable->key && std::strcmp(variable->key, "citra_graphics_api") == 0) {
            variable->value = const_cast<char*>(g_vulkan_enabled.load() ? "Vulkan" : "OpenGL");
            return true;
        }
        return false;
    }
    case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *static_cast<unsigned*>(data)=2; return true;
    case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER: *static_cast<retro_hw_context_type*>(data)=g_vulkan_enabled.load() ? RETRO_HW_CONTEXT_VULKAN : RETRO_HW_CONTEXT_OPENGL_CORE; return true;
    case RETRO_ENVIRONMENT_SET_HW_SHARED_CONTEXT: return true;
    case RETRO_ENVIRONMENT_SET_HW_RENDER: {
        auto *callback = static_cast<retro_hw_render_callback*>(data);
        if (callback && callback->context_type == RETRO_HW_CONTEXT_VULKAN) {
            g_vulkan_callback = callback;
            return true;
        }
        if (!callback || !g_gl.make_current()) return false;
        callback->get_proc_address = gl_proc;
        callback->get_current_framebuffer = current_framebuffer;
        if (callback->context_reset) callback->context_reset();
        return true;
    }
    case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE:
        if (!data) return false;
        g_vulkan_negotiation = static_cast<const retro_hw_render_context_negotiation_interface_vulkan*>(data);
        return g_vulkan_negotiation != nullptr;
    case RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT:
        if (!data) return false;
        static_cast<retro_hw_render_context_negotiation_interface*>(data)->interface_version = 1;
        return true;
    case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE:
        if (!data || !g_vulkan.ready()) return false;
        *static_cast<void**>(data) = const_cast<struct retro_hw_render_interface_vulkan*>(g_vulkan.get_interface());
        return true;
    case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
    case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
        *static_cast<char **>(data) = const_cast<char *>(native_data_directory()); return true;
    case RETRO_ENVIRONMENT_SET_MESSAGE:
        if (g_core && data) g_core->report_libretro_message(static_cast<retro_message *>(data)->msg);
        return true;
    default: return false;
    }
}
template <class T> T proc(void* m, const char *n) { return reinterpret_cast<T>(dlsym(m,n)); }
unsigned key(const String &s) {
 if (s=="A") return RETRO_DEVICE_ID_JOYPAD_A; if(s=="B") return RETRO_DEVICE_ID_JOYPAD_B;
 if(s=="X") return RETRO_DEVICE_ID_JOYPAD_X; if(s=="Y") return RETRO_DEVICE_ID_JOYPAD_Y;
 if(s=="L") return RETRO_DEVICE_ID_JOYPAD_L; if(s=="R") return RETRO_DEVICE_ID_JOYPAD_R;
 if(s=="START") return RETRO_DEVICE_ID_JOYPAD_START; if(s=="SELECT") return RETRO_DEVICE_ID_JOYPAD_SELECT;
 if(s=="UP") return RETRO_DEVICE_ID_JOYPAD_UP; if(s=="DOWN") return RETRO_DEVICE_ID_JOYPAD_DOWN;
 if(s=="LEFT") return RETRO_DEVICE_ID_JOYPAD_LEFT; if(s=="RIGHT") return RETRO_DEVICE_ID_JOYPAD_RIGHT; return UINT_MAX;
}
}

// Godot may be installed anywhere. The project folder is the process working
// directory when PocketFrame is launched, so the local experimental core sits
// one directory above it under work/.
static std::filesystem::path local_core_dll_path() {
    if(const char* install=std::getenv("POCKETFRAME_RUNTIME_ROOT");install && *install)
        return std::filesystem::path(install)/"runtime/vulkan/azahar_libretro.so";
    char executable[32768]{};
    const auto length=readlink("/proc/self/exe",executable,sizeof(executable)-1);
    if(length<=0)throw std::runtime_error("Cannot locate native runtime folder");
    return std::filesystem::path(executable).parent_path()/"runtime/vulkan/azahar_libretro.so";
}

void PFAzaharCore::_bind_methods() {
 ClassDB::bind_method(D_METHOD("start"),&PFAzaharCore::start); ClassDB::bind_method(D_METHOD("load_game","content_path"),&PFAzaharCore::load_game);
 ClassDB::bind_method(D_METHOD("set_touch","uv","pressed"),&PFAzaharCore::set_touch); ClassDB::bind_method(D_METHOD("set_button","button","pressed"),&PFAzaharCore::set_button); ClassDB::bind_method(D_METHOD("set_circle_pad","value"),&PFAzaharCore::set_circle_pad); ClassDB::bind_method(D_METHOD("set_resolution_factor","factor"),&PFAzaharCore::set_resolution_factor);
 ClassDB::bind_method(D_METHOD("get_presented_frame_count"),&PFAzaharCore::get_presented_frame_count);
 ClassDB::bind_method(D_METHOD("set_stereo_depth","depth"),&PFAzaharCore::set_stereo_depth);
 ClassDB::bind_method(D_METHOD("set_player_name","name"),&PFAzaharCore::set_player_name);
 ClassDB::bind_method(D_METHOD("unload_game"),&PFAzaharCore::unload_game);
 ClassDB::bind_method(D_METHOD("set_paused","paused"),&PFAzaharCore::set_paused);
 ClassDB::bind_method(D_METHOD("is_running"),&PFAzaharCore::is_running);
 ClassDB::bind_method(D_METHOD("configure_network","mode","nickname","address","port","password"),&PFAzaharCore::configure_network);
 ClassDB::bind_method(D_METHOD("get_network_status"),&PFAzaharCore::get_network_status);
 ADD_SIGNAL(MethodInfo("frame_ready",PropertyInfo(Variant::OBJECT,"top"),PropertyInfo(Variant::OBJECT,"bottom"))); ADD_SIGNAL(MethodInfo("state_changed",PropertyInfo(Variant::BOOL,"connected"),PropertyInfo(Variant::STRING,"detail")));
}
PFAzaharCore::~PFAzaharCore(){ stop_requested=true; if(worker.joinable()) worker.join(); }
bool PFAzaharCore::is_running() const { return worker_running.load(); }
void PFAzaharCore::set_paused(bool paused) {
    emulation_paused=paused;
    if(audio_player)audio_player->set_stream_paused(paused);
}
void PFAzaharCore::publish_status(bool c,const std::string &s){ std::lock_guard l(state_mutex); if(!status_dirty && pending_connected==c && pending_status==s)return; pending_connected=c;pending_status=s;status_dirty=true; }
void PFAzaharCore::start(){ started=true;set_process(true);publish_status(false,"Native Azahar host ready · waiting for a cartridge"); }
void PFAzaharCore::configure_network(int32_t mode,const String &nickname,const String &address,int32_t port,const String &password) {
    std::lock_guard lock(state_mutex);
    network_config.mode=std::clamp(mode,0,2);
    network_config.nickname=nickname.utf8().get_data();
    network_config.address=address.utf8().get_data();
    network_config.port=static_cast<unsigned>(port);
    network_config.password=password.utf8().get_data();
    ++network_config.revision;
}
String PFAzaharCore::get_network_status() {
    std::lock_guard lock(state_mutex);
    return String((worker_running?network_status:std::string("1|0|-1|0")).c_str());
}
void PFAzaharCore::clear_presentation(){
    { std::lock_guard l(state_mutex);
      frame_dirty=false; newest_frame.clear(); processing_frame.clear();
      audio_samples.clear(); audio_pending.clear(); buttons.clear();
      circle_x=circle_y=0; touch_pressed=false; }
    frame_connected=false; presented_frames.store(0);
    top_texture.unref(); bottom_texture.unref(); top_image.unref(); bottom_image.unref();
    audio_playback.unref(); audio_stream.unref();
    if(audio_player){audio_player->stop();audio_player->queue_free();audio_player=nullptr;}
}
void PFAzaharCore::unload_game(){
    {std::lock_guard lock(state_mutex);network_config.mode=0;network_config.password.clear();++network_config.revision;network_status="1|0|-1|0";}
    pending_game.clear(); stop_requested=true; clear_presentation();
    publish_status(false,"Cartridge ejected - stopping emulation");
}
void PFAzaharCore::load_game(const String &path){
    if(!started)start();
    if(worker_running){pending_game=path.utf8().get_data();stop_requested=true;clear_presentation();publish_status(false,"Changing cartridges - waiting for shutdown");return;}
    if(worker.joinable())worker.join();
    pending_game.clear(); clear_presentation();stop_requested=false;worker_running=true;
    // std::thread would copy only a char* from a temporary Godot UTF8 buffer.
    // Own the filename before dispatch, including during queued replacements.
    const std::string game_path=path.utf8().get_data();
    worker=std::thread(&PFAzaharCore::worker_main,this,game_path);
}
void PFAzaharCore::set_touch(const Vector2 &uv,bool down){
    const auto pointer = pocketframe::bottom_lcd_pointer(uv.x, uv.y, g_stereo_depth.load() > 0);
    std::lock_guard l(state_mutex);
    touch_x=pointer.x; touch_y=pointer.y;
    touch_pressed=down && uv.x>=0.f && uv.x<=1.f && uv.y>=0.f && uv.y<=1.f;
}
void PFAzaharCore::set_button(const String &name,bool down){unsigned k=key(name.to_upper());if(k==UINT_MAX)return;std::lock_guard l(state_mutex);buttons[k]=down;}
void PFAzaharCore::set_circle_pad(const Vector2 &v){std::lock_guard l(state_mutex);circle_x=(int16_t)(std::clamp(v.x,-1.f,1.f)*32767);circle_y=(int16_t)(std::clamp(-v.y,-1.f,1.f)*32767);}
void PFAzaharCore::set_resolution_factor(int32_t factor){g_resolution_factor.store(std::clamp(factor,1,3));}
void PFAzaharCore::set_stereo_depth(double depth){
    const int next = std::clamp(static_cast<int>(std::lround(depth * 100.0)),0,100);
    const int old = g_stereo_depth.exchange(next);
    if ((old > 0) != (next > 0)) g_options_dirty.store(true);
}
void PFAzaharCore::set_player_name(const String &name){
    // Profile is read on the emulation thread during boot; changes require restart.
    if (!worker_running) g_player_name = name.strip_edges().utf8().get_data();
}
int64_t PFAzaharCore::get_presented_frame_count() const{return static_cast<int64_t>(presented_frames.load());}
void PFAzaharCore::report_libretro_message(const char *message){std::fprintf(stderr,"PocketFrame core: %s\n",message ? message : "Unknown error");publish_status(false,message ? message : "Azahar reported an unknown error");}
void PFAzaharCore::receive_audio(const int16_t *samples, size_t frames) {
    std::lock_guard lock(state_mutex);
    constexpr size_t max_samples = 32728 * 2; // One second of stereo: enough to absorb VR frame-time jitter, never unbounded.
    const size_t incoming = frames * 2;
    if (incoming >= max_samples) { audio_samples.clear(); samples += incoming - max_samples; }
    while (audio_samples.size() + incoming > max_samples) { audio_samples.pop_front(); audio_samples.pop_front(); }
    audio_samples.insert(audio_samples.end(), samples, samples + incoming);
}
int16_t PFAzaharCore::read_input(unsigned device,unsigned index,unsigned id){std::lock_guard l(state_mutex);if(device==RETRO_DEVICE_JOYPAD)return buttons[id]?1:0;if(device==RETRO_DEVICE_ANALOG&&index==RETRO_DEVICE_INDEX_ANALOG_LEFT)return id==RETRO_DEVICE_ID_ANALOG_X?circle_x:(id==RETRO_DEVICE_ID_ANALOG_Y?circle_y:0);if(device==RETRO_DEVICE_POINTER)return id==RETRO_DEVICE_ID_POINTER_X?touch_x:(id==RETRO_DEVICE_ID_POINTER_Y?touch_y:(id==RETRO_DEVICE_ID_POINTER_PRESSED&&touch_pressed));return 0;}
void PFAzaharCore::receive_frame(const void *p,unsigned w,unsigned h,size_t pitch,bool rgba){const unsigned scale=h/480;if(!p||h%480!=0||scale<1||scale>3||(w!=400*scale&&w!=800*scale)||pitch<w*4)return;std::lock_guard l(state_mutex);newest_frame.resize(static_cast<size_t>(w)*h*4);auto s=(const uint8_t*)p;for(unsigned y=0;y<h;y++)std::copy_n(s+y*pitch,w*4,newest_frame.data()+static_cast<size_t>(y)*w*4);frame_width=w;frame_height=h;frame_rgba=rgba;frame_dirty=true;}
void PFAzaharCore::_process(double) {
    if(stop_requested){
        if(worker_running) return; // Never join a live emulation worker on the VR thread.
        if(worker.joinable())worker.join();
        clear_presentation();stop_requested=false;
        const std::string next=pending_game;pending_game.clear();
        if(!next.empty())load_game(String(next.c_str()));
        else publish_status(false,"Integrated runtime available - no cartridge loaded");
    }
    if (!audio_player) {
        audio_player = memnew(AudioStreamPlayer);
        audio_stream.instantiate();
        audio_stream->set_mix_rate_mode(AudioStreamGenerator::MIX_RATE_CUSTOM);
        audio_stream->set_mix_rate(32728.0f);
        audio_stream->set_buffer_length(0.35f);
        audio_player->set_stream(audio_stream);
        add_child(audio_player);
        audio_player->play();
        audio_player->set_stream_paused(emulation_paused.load());
    }
    if (audio_playback.is_null() && audio_player->has_stream_playback()) audio_playback = audio_player->get_stream_playback();
    if (audio_playback.is_valid()) {
        audio_pending.clear();
        // A slow VR frame must still be able to catch up on several audio
        // batches; 1024 was below the 32,728 Hz source rate at 30 FPS.
        const int wanted = (std::min)(audio_playback->get_frames_available(), 4096);
        if (wanted > 0) {
            std::lock_guard lock(state_mutex);
            const size_t count = (std::min)(static_cast<size_t>(wanted) * 2, audio_samples.size() - audio_samples.size() % 2);
            if (audio_pending.capacity() < count) audio_pending.reserve(count);
            for (size_t i = 0; i < count; ++i) { audio_pending.push_back(audio_samples.front()); audio_samples.pop_front(); }
        }
        for (size_t i = 0; i + 1 < audio_pending.size(); i += 2) audio_playback->push_frame(Vector2(audio_pending[i] / 32768.0f, audio_pending[i + 1] / 32768.0f));
    }
    bool emit_state = false, connected = false, got_frame = false;
    unsigned presented_width = 0, presented_height = 0;
    bool presented_rgba = false;
    std::string detail;
    {
        std::lock_guard lock(state_mutex);
        if (status_dirty) {
            emit_state = true;
            connected = pending_connected;
            detail = pending_status;
            status_dirty = false;
        }
        if (frame_dirty) {
            processing_frame = newest_frame;
            presented_width = frame_width;
            presented_height = frame_height;
            presented_rgba = frame_rgba;
            frame_dirty = false;
            got_frame = true;
        }
    }
    if (emit_state) emit_signal("state_changed", connected, String(detail.c_str()));
    // Do not re-upload a previously presented texture on every VR frame.
    // The emulator submits at 60 Hz; preserving that cadence frees GPU time
    // for scene transitions while the headset compositor keeps displaying it.
    if (!got_frame || processing_frame.empty()) return;

    const bool stereo = presented_width * 3 == presented_height * 5;
    const unsigned scale = presented_height / 480;
    const unsigned eye_width = 400 * scale;
    const unsigned top_width = eye_width * (stereo ? 2 : 1), lcd_height = 240 * scale;
    const unsigned bottom_width = 320 * scale, bottom_margin = 40 * scale;
    const unsigned red = presented_rgba ? 0 : 2, blue = presented_rgba ? 2 : 0;
    if (top_data.size() != top_width * lcd_height * 4) top_data.resize(top_width * lcd_height * 4);
    if (bottom_data.size() != bottom_width * lcd_height * 4) bottom_data.resize(bottom_width * lcd_height * 4);
    // Acquire writable storage once. Indexed writes across the GDExtension
    // boundary cost hundreds of thousands of engine calls per frame.
    uint8_t *top_bytes = top_data.ptrw();
    uint8_t *bottom_bytes = bottom_data.ptrw();
    for (unsigned y = 0; y < lcd_height; ++y) for (unsigned x = 0; x < top_width; ++x) {
        const auto *pixel = &processing_frame[(y * presented_width + x) * 4];
        const unsigned dst = (y * top_width + x) * 4;
        top_bytes[dst] = pixel[red]; top_bytes[dst + 1] = pixel[1];
        top_bytes[dst + 2] = pixel[blue]; top_bytes[dst + 3] = 255;
    }
    for (unsigned y = 0; y < lcd_height; ++y) for (unsigned x = 0; x < bottom_width; ++x) {
        const auto *pixel = &processing_frame[((y + lcd_height) * presented_width + x + bottom_margin) * 4];
        const unsigned dst = (y * bottom_width + x) * 4;
        bottom_bytes[dst] = pixel[red]; bottom_bytes[dst + 1] = pixel[1];
        bottom_bytes[dst + 2] = pixel[blue]; bottom_bytes[dst + 3] = 255;
    }
    if (top_image.is_null()) {
        top_image.instantiate();
        bottom_image.instantiate();
    }
    top_image->set_data(top_width, lcd_height, false, Image::FORMAT_RGBA8, top_data);
    bottom_image->set_data(bottom_width, lcd_height, false, Image::FORMAT_RGBA8, bottom_data);
    if (top_texture.is_null()) {
        top_texture = ImageTexture::create_from_image(top_image);
        bottom_texture = ImageTexture::create_from_image(bottom_image);
        emit_signal("frame_ready", top_texture, bottom_texture);
    } else if (top_texture->get_width() != static_cast<int>(top_width) || top_texture->get_height() != static_cast<int>(lcd_height)) {
        top_texture->set_image(top_image);
        bottom_texture->set_image(bottom_image);
        emit_signal("frame_ready", top_texture, bottom_texture);
    } else {
        top_texture->update(top_image);
        bottom_texture->update(bottom_image);
    }
    presented_frames.fetch_add(1);
    if (!frame_connected) {
        frame_connected = true;
        publish_status(true, "Native Azahar runtime connected");
    }
}
void PFAzaharCore::worker_main(std::string game) {
    g_vulkan_enabled.store(true);
    g_vulkan_callback = nullptr;
    g_vulkan_negotiation = nullptr;
    std::filesystem::path core_path;
    try { core_path = local_core_dll_path(); }
    catch (const std::exception &error) {
        publish_status(false,error.what()); worker_running=false; return;
    }
    void* module = dlopen(core_path.c_str(),RTLD_NOW|RTLD_LOCAL);
    if (!module) std::fprintf(stderr,"PocketFrame native runtime load failed: %s\n",dlerror());
    if (!module) { publish_status(false, "Native ARM64 core library could not be loaded"); worker_running=false; return; }
    using Z=void(*)(); using L=bool(*)(const retro_game_info*);
    auto se=proc<void(*)(retro_environment_t)>(module,"retro_set_environment");
    auto sv=proc<void(*)(retro_video_refresh_t)>(module,"retro_set_video_refresh");
    auto sa=proc<void(*)(retro_audio_sample_batch_t)>(module,"retro_set_audio_sample_batch");
    auto sp=proc<void(*)(retro_input_poll_t)>(module,"retro_set_input_poll");
    auto si=proc<void(*)(retro_input_state_t)>(module,"retro_set_input_state");
    auto init=proc<Z>(module,"retro_init"); auto run=proc<Z>(module,"retro_run");
    auto de=proc<Z>(module,"retro_deinit"); auto un=proc<Z>(module,"retro_unload_game");
    auto load=proc<L>(module,"retro_load_game");
    auto network_command=proc<int(*)(int,const char*,const char*,unsigned,const char*,const char*)>(module,"pocketframe_network_command");
    auto network_poll=proc<void(*)(char*,unsigned)>(module,"pocketframe_network_status");
    if (!se||!sv||!sa||!sp||!si||!init||!run||!de||!un||!load) {
        publish_status(false,"Native core is missing a required entry point");
        dlclose(module); worker_running=false; return;
    }
    bool initialized=false, loaded=false;
    g_core=this;
    try {
        se(env); sv(video); sa(audio); sp(poll); si(input); init(); initialized=true;
        retro_game_info info{}; info.path=game.c_str();
        loaded=load(&info);
        if (!loaded) throw std::runtime_error("Azahar could not load this cartridge");
        if (g_vulkan_enabled.load()) {
            if (!g_vulkan.initialize(g_vulkan_negotiation))
                throw std::runtime_error("Vulkan device negotiation failed");
            if (!g_vulkan_callback || !g_vulkan_callback->context_reset)
                throw std::runtime_error("Vulkan context callback was not provided");
            g_vulkan_callback->context_reset();
        }
        publish_status(false, g_vulkan_enabled.load() ? "Vulkan Azahar started - waiting for first frame" : "OpenGL Azahar started - waiting for first frame");
        auto next_frame=std::chrono::steady_clock::now();
        auto sample_start=next_frame;
        uint64_t run_us=0, run_count=0;
        uint64_t network_revision=UINT64_MAX;
        bool network_command_ok=true;
        auto network_sample=next_frame;
        while (!stop_requested) {
            if(emulation_paused) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                next_frame=std::chrono::steady_clock::now();
                sample_start=next_frame;run_us=run_count=0;
                continue;
            }
            NetworkConfig config;
            { std::lock_guard lock(state_mutex); config.revision=network_config.revision; if(config.revision!=network_revision)config=network_config; }
            if(config.revision!=network_revision) {
                network_revision=config.revision;
                const int result=network_command?network_command(config.mode,config.nickname.c_str(),config.address.c_str(),config.port,config.password.c_str(),nullptr):-5;
                network_command_ok=result>=0;
                {std::lock_guard lock(state_mutex);network_status=result<0?"1|0|"+std::to_string(result-100)+"|0":"2|0|-1|0";}
            }
            if(network_poll && std::chrono::steady_clock::now()-network_sample>std::chrono::milliseconds(250)) {
                char buffer[96]{};network_poll(buffer,sizeof(buffer));
                {std::lock_guard lock(state_mutex);if(network_command_ok)network_status=buffer;}
                network_sample=std::chrono::steady_clock::now();
            }
            const auto run_start=std::chrono::steady_clock::now();
            run();
            run_us+=std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now()-run_start).count(); ++run_count;
            if (std::chrono::steady_clock::now()-sample_start > std::chrono::seconds(5)) {
                std::fprintf(stderr,"PocketFrame GPU timing: run %.2f ms, transfer %.2f ms, calls %llu\n",run_us/1000.0/run_count,g_readback_us.exchange(0)/1000.0/run_count,static_cast<unsigned long long>(run_count));
                sample_start=std::chrono::steady_clock::now(); run_us=run_count=0;
            }
            next_frame+=std::chrono::microseconds(16667);
            const auto now=std::chrono::steady_clock::now();
            if(next_frame>now) std::this_thread::sleep_until(next_frame); else next_frame=now;
        }
    } catch (const std::exception &error) {
        publish_status(false, std::string("Native runtime: ") + error.what());
    } catch (...) { publish_status(false, "Native runtime failed during GPU startup"); }
    if (loaded) un();
    if (initialized) de();
    g_core=nullptr;
    g_vulkan.destroy(); g_gl.destroy();
    g_vulkan_callback=nullptr; g_vulkan_negotiation=nullptr;
    // A replacement OpenGL context needs fresh texture storage even if the
    // next cartridge uses exactly the same resolution as the previous one.
    g_gl.width=g_gl.height=0;
    dlclose(module); worker_running=false;
}
