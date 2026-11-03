#pragma once

#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <array>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>

namespace godot {
class Button;
class CanvasLayer;
class Control;
class Font;
class InputEvent;
class Label;
class StyleBoxFlat;
class Texture2D;

enum class RazorScreen : int32_t {
    HOME = 0,
    LEVEL_SELECT = 1,
    PLAYING = 2,
    PAUSED = 3,
    SHOP = 4,
    SETTINGS = 5,
    STAGE_CLEAR = 6,
    VICTORY = 7,
    GAME_OVER = 8,
};

class RazorPathGame : public Node2D {
    GDCLASS(RazorPathGame, Node2D)

    struct StageData {
        int32_t index = 1;
        String name;
        double world_width = 3600.0;
        double required_coins = 0.0;
        Vector2 spawn = Vector2(130.0, 590.0);
        Vector2 exit = Vector2(3460.0, 590.0);
        bool monochrome = false;
        std::vector<Rect2> platforms;
        std::vector<Vector2> coins;
        std::vector<Rect2> hazards;
    };

    struct Particle {
        Vector2 position;
        Vector2 velocity;
        Color color;
        double lifetime = 0.0;
        double size = 3.0;
    };

    enum class TouchAction : int32_t {
        NONE = 0,
        LEFT = 1,
        RIGHT = 2,
        JUMP = 3,
        ATTACK = 4,
    };

    RazorScreen screen = RazorScreen::HOME;
    RazorScreen return_screen = RazorScreen::HOME;
    StageData stage;
    std::unordered_map<int32_t, StageData> authored_stages;
    std::array<Ref<Texture2D>, 8> hero_frames;
    Array hero_frame_assets;
    Ref<Theme> interface_theme;
    Ref<Font> arabic_bold_font;
    CanvasLayer *ui_layer = nullptr;
    Control *ui_root = nullptr;
    Label *hud_label = nullptr;
    Label *toast_label = nullptr;
    std::vector<Particle> particles;
    std::unordered_map<int32_t, TouchAction> touch_actions;

    int32_t stage_index = 1;
    int32_t unlocked_stage = 1;
    int32_t coins = 0;
    int32_t stage_coins = 0;
    int32_t selected_skin = 0;
    int32_t total_jumps = 0;
    double player_x = 130.0;
    double player_feet = 590.0;
    double player_vy = 0.0;
    double camera_x = 0.0;
    double remaining_time = 180.0;
    double animation_time = 0.0;
    double attack_time = 0.0;
    double attack_cooldown = 0.0;
    double landing_time = 0.0;
    double toast_time = 0.0;
    double background_time = 0.0;
    bool on_ground = false;
    bool jump_requested = false;
    bool attack_requested = false;
    bool muted = false;
    bool reduced_motion = false;
    bool run_finalized = false;
    bool stage_coin_collected[256] = {};

    static void _bind_methods();

public:
    void _ready() override;
    void _process(double delta) override;
    void _physics_process(double delta) override;
    void _input(const Ref<InputEvent> &event) override;
    void _draw() override;

private:
    void set_hero_frame_assets(const Array &value);
    Array get_hero_frame_assets() const;
    void set_interface_theme(const Ref<Theme> &value);
    Ref<Theme> get_interface_theme() const;
    void load_assets();
    void load_save();
    void save_progress();
    void load_authored_stages();
    bool load_stage(int32_t requested_index);
    StageData make_generated_stage(int32_t requested_index) const;
    StageData parse_stage(const Dictionary &record) const;
    void start_new_run();
    void start_stage(int32_t requested_index);
    void complete_stage();
    void fail_run();
    void spawn_particles(const Vector2 &at, const Color &color, int32_t count, double impulse);
    void update_touch_state(const Ref<InputEvent> &event);
    void update_hud();
    void rebuild_ui();
    void clear_ui();
    void set_screen(RazorScreen next_screen);
    void go_back();
    void handle_action(const String &action);
    void _on_ui_action(const String &action);
    void add_label(const String &text, const Rect2 &rect, int32_t font_size, bool bold = false, bool rtl = true);
    Button *add_button(const String &text, const Rect2 &rect, const String &action, bool disabled = false);
    void add_touch_feedback();
    Color background_color() const;
    Color far_color() const;
    Color near_color() const;
    Color platform_color() const;
    Color hero_tint() const;
    Rect2 player_body_rect() const;
    int32_t current_hero_frame() const;
    Vector2 logical_size() const;

public:
    RazorPathGame() = default;
    ~RazorPathGame() override = default;

    // Small native API used by the GDScript smoke test; gameplay stays in C++.
    bool start_test_stage(int32_t requested_index);
    bool test_register_touch(int32_t finger_id, int32_t action);
    bool test_release_touch(int32_t finger_id);
    bool test_has_touch_action(int32_t action) const;
    int32_t test_screen() const;
    int32_t test_stage() const;
    int32_t test_unlocked_stage() const;
    int32_t test_coin_count() const;
    bool test_frames_loaded() const;
    bool test_stage_is_monochrome() const;
    double test_stage_world_width() const;
    bool test_try_start_stage(int32_t requested_index);
    void test_set_unlocked_stage(int32_t requested_index);
    void test_complete_current_stage();
    void test_open_shop();
    void test_open_settings();
    void test_back();
};

} // namespace godot
