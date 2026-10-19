#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/audio_stream_generator.hpp>
#include <godot_cpp/classes/audio_stream_generator_playback.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <atomic>
#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

using namespace godot;

// The GDScript adapter owns this node.  Its eventual worker thread is the
// only code allowed to invoke retro_run; _process will publish only a newest
// completed frame on Godot's main thread.
class PFAzaharCore : public Node {
    GDCLASS(PFAzaharCore, Node);

    bool started = false;
    std::atomic_bool stop_requested{false};
    std::atomic_bool worker_running{false};
    std::atomic_bool emulation_paused{false};
    std::thread worker;
    std::mutex state_mutex;
    std::string pending_game;
    std::string pending_status;
    struct NetworkConfig {
        int mode=0;
        unsigned port=24872;
        std::string nickname, address, password;
        uint64_t revision=0;
    } network_config;
    std::string network_status="1|0|-1|0";
    bool pending_connected = false;
    bool status_dirty = false;
    std::vector<uint8_t> newest_frame;
    // Reused presentation-side frame.  Its capacity is retained so copying a
    // completed emulation frame does not allocate on every Godot frame.
    std::vector<uint8_t> processing_frame;
    unsigned frame_width = 0;
    unsigned frame_height = 0;
    bool frame_rgba = false;
    bool frame_dirty = false;
    bool frame_connected = false;
    std::atomic_uint64_t presented_frames{0};
    std::deque<int16_t> audio_samples;
    std::vector<int16_t> audio_pending;
    AudioStreamPlayer *audio_player = nullptr;
    Ref<AudioStreamGenerator> audio_stream;
    Ref<AudioStreamGeneratorPlayback> audio_playback;
    Ref<ImageTexture> top_texture;
    Ref<ImageTexture> bottom_texture;
    Ref<Image> top_image;
    Ref<Image> bottom_image;
    PackedByteArray top_data;
    PackedByteArray bottom_data;
    std::unordered_map<unsigned, bool> buttons;
    int16_t circle_x = 0;
    int16_t circle_y = 0;
    int16_t touch_x = 0;
    int16_t touch_y = 0;
    bool touch_pressed = false;

    void worker_main(std::string content_path);
    void publish_status(bool connected, const std::string &detail);
    void clear_presentation();

protected:
    static void _bind_methods();

public:
    ~PFAzaharCore() override;
    void start();
    void load_game(const String &content_path);
    void unload_game();
    void set_paused(bool paused);
    bool is_running() const;
    void set_touch(const Vector2 &uv, bool pressed);
    void set_button(const String &button, bool pressed);
    void set_circle_pad(const Vector2 &value);
    void set_resolution_factor(int32_t factor);
    void set_stereo_depth(double depth);
    void set_player_name(const String &name);
    void configure_network(int32_t mode, const String &nickname, const String &address, int32_t port, const String &password);
    String get_network_status();
    void _process(double delta) override;
    void receive_frame(const void *data, unsigned width, unsigned height, size_t pitch, bool rgba = false);
    void receive_audio(const int16_t *samples, size_t frames);
    int16_t read_input(unsigned device, unsigned index, unsigned id);
    int64_t get_presented_frame_count() const;
    void report_libretro_message(const char *message);
};

