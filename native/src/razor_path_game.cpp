#include "razor_path_game.hpp"

#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/canvas_layer.hpp>
#include <godot_cpp/classes/config_file.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event_screen_drag.hpp>
#include <godot_cpp/classes/input_event_screen_touch.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <cmath>

namespace godot {
namespace {

String ui(const char *text) {
    return String::utf8(text);
}

Color rgba8(uint32_t value, float alpha = 1.0f) {
    return Color(
        static_cast<float>((value >> 16) & 0xff) / 255.0f,
        static_cast<float>((value >> 8) & 0xff) / 255.0f,
        static_cast<float>(value & 0xff) / 255.0f,
        alpha);
}

Vector2 point_from_array(const Array &values, const Vector2 &fallback) {
    if (values.size() < 2) {
        return fallback;
    }
    return Vector2(static_cast<double>(values[0]), static_cast<double>(values[1]));
}

} // namespace

void RazorPathGame::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_hero_frame_assets", "value"), &RazorPathGame::set_hero_frame_assets);
    ClassDB::bind_method(D_METHOD("get_hero_frame_assets"), &RazorPathGame::get_hero_frame_assets);
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "hero_frame_assets", PROPERTY_HINT_ARRAY_TYPE, "Texture2D"), "set_hero_frame_assets", "get_hero_frame_assets");
    ClassDB::bind_method(D_METHOD("set_interface_theme", "value"), &RazorPathGame::set_interface_theme);
    ClassDB::bind_method(D_METHOD("get_interface_theme"), &RazorPathGame::get_interface_theme);
    ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "interface_theme", PROPERTY_HINT_RESOURCE_TYPE, "Theme"), "set_interface_theme", "get_interface_theme");
    ClassDB::bind_method(D_METHOD("start_test_stage", "stage_index"), &RazorPathGame::start_test_stage);
    ClassDB::bind_method(D_METHOD("test_register_touch", "finger_id", "action"), &RazorPathGame::test_register_touch);
    ClassDB::bind_method(D_METHOD("test_release_touch", "finger_id"), &RazorPathGame::test_release_touch);
    ClassDB::bind_method(D_METHOD("test_has_touch_action", "action"), &RazorPathGame::test_has_touch_action);
    ClassDB::bind_method(D_METHOD("test_screen"), &RazorPathGame::test_screen);
    ClassDB::bind_method(D_METHOD("test_stage"), &RazorPathGame::test_stage);
    ClassDB::bind_method(D_METHOD("test_unlocked_stage"), &RazorPathGame::test_unlocked_stage);
    ClassDB::bind_method(D_METHOD("test_coin_count"), &RazorPathGame::test_coin_count);
    ClassDB::bind_method(D_METHOD("test_frames_loaded"), &RazorPathGame::test_frames_loaded);
    ClassDB::bind_method(D_METHOD("test_stage_is_monochrome"), &RazorPathGame::test_stage_is_monochrome);
    ClassDB::bind_method(D_METHOD("test_stage_world_width"), &RazorPathGame::test_stage_world_width);
    ClassDB::bind_method(D_METHOD("test_try_start_stage", "stage_index"), &RazorPathGame::test_try_start_stage);
    ClassDB::bind_method(D_METHOD("test_set_unlocked_stage", "stage_index"), &RazorPathGame::test_set_unlocked_stage);
    ClassDB::bind_method(D_METHOD("test_complete_current_stage"), &RazorPathGame::test_complete_current_stage);
    ClassDB::bind_method(D_METHOD("test_open_shop"), &RazorPathGame::test_open_shop);
    ClassDB::bind_method(D_METHOD("test_open_settings"), &RazorPathGame::test_open_settings);
    ClassDB::bind_method(D_METHOD("test_back"), &RazorPathGame::test_back);
    ClassDB::bind_method(D_METHOD("_on_ui_action", "action"), &RazorPathGame::_on_ui_action);
}

void RazorPathGame::_ready() {
    load_assets();
    load_save();
    load_authored_stages();

    ui_layer = memnew(CanvasLayer);
    ui_layer->set_layer(8);
    add_child(ui_layer);
    ui_root = memnew(Control);
    ui_layer->add_child(ui_root);
    ui_root->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
    ui_root->set_mouse_filter(Control::MOUSE_FILTER_PASS);
    if (interface_theme.is_valid()) {
        ui_root->set_theme(interface_theme);
    }

    if (authored_stages.find(1) != authored_stages.end()) {
        stage = authored_stages.at(1);
    } else {
        stage = make_generated_stage(1);
    }
    rebuild_ui();
    set_process(true);
    set_physics_process(true);
    set_process_input(true);
    queue_redraw();
}

void RazorPathGame::set_hero_frame_assets(const Array &value) {
    hero_frame_assets = value;
}

Array RazorPathGame::get_hero_frame_assets() const {
    return hero_frame_assets;
}

void RazorPathGame::set_interface_theme(const Ref<Theme> &value) {
    interface_theme = value;
}

Ref<Theme> RazorPathGame::get_interface_theme() const {
    return interface_theme;
}

void RazorPathGame::load_assets() {
    ResourceLoader *loader = ResourceLoader::get_singleton();
    if (loader != nullptr) {
        arabic_bold_font = loader->load("res://assets/fonts/razor_path_ui_bold.tres");
        for (int32_t i = 0; i < 8; ++i) {
            if (i < hero_frame_assets.size() && hero_frame_assets[i].get_type() == Variant::OBJECT) {
                hero_frames[i] = hero_frame_assets[i];
            }
            String frame_number = String::num_int64(i + 1);
            if (frame_number.length() < 2) {
                frame_number = ui("0") + frame_number;
            }
            const String path = "res://assets/characters/razor_hero_" + frame_number + ".png";
            if (hero_frames[i].is_null()) {
                hero_frames[i] = loader->load(path);
            }
        }
    }
}

void RazorPathGame::load_save() {
    Ref<ConfigFile> config;
    config.instantiate();
    if (config->load("user://razor_path_save.cfg") == OK) {
        unlocked_stage = static_cast<int32_t>(config->get_value("progress", "unlocked_stage", 1));
        coins = static_cast<int32_t>(config->get_value("progress", "coins", 0));
        selected_skin = static_cast<int32_t>(config->get_value("appearance", "skin", 0));
        muted = static_cast<bool>(config->get_value("settings", "muted", false));
        reduced_motion = static_cast<bool>(config->get_value("settings", "reduced_motion", false));
    }
    unlocked_stage = std::clamp(unlocked_stage, 1, 16);
    coins = std::max(0, coins);
    selected_skin = std::clamp(selected_skin, 0, 2);
}

void RazorPathGame::save_progress() {
    Ref<ConfigFile> config;
    config.instantiate();
    config->set_value("progress", "unlocked_stage", unlocked_stage);
    config->set_value("progress", "coins", coins);
    config->set_value("appearance", "skin", selected_skin);
    config->set_value("settings", "muted", muted);
    config->set_value("settings", "reduced_motion", reduced_motion);
    const Error result = config->save("user://razor_path_save.cfg");
    if (result != OK) {
        UtilityFunctions::push_warning("Razor Path: could not save progress.");
    }
}

void RazorPathGame::load_authored_stages() {
    Ref<FileAccess> file = FileAccess::open("res://data/stages/razor_path_levels.json", FileAccess::READ);
    if (file.is_null()) {
        UtilityFunctions::push_warning("Razor Path: stage JSON is missing; generated levels will be used.");
        return;
    }
    Ref<JSON> json;
    json.instantiate();
    const Error parse_error = json->parse(file->get_as_text());
    if (parse_error != OK || json->get_data().get_type() != Variant::DICTIONARY) {
        UtilityFunctions::push_warning("Razor Path: stage JSON could not be parsed; generated levels will be used.");
        return;
    }
    const Dictionary root = json->get_data();
    const Array records = root.get("stages", Array());
    for (int32_t i = 0; i < records.size(); ++i) {
        if (records[i].get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary record = records[i];
        const int32_t index = static_cast<int32_t>(record.get("index", 0));
        if (index >= 1 && index <= 16) {
            authored_stages[index] = parse_stage(record);
        }
    }
}

RazorPathGame::StageData RazorPathGame::parse_stage(const Dictionary &record) const {
    StageData parsed;
    parsed.index = static_cast<int32_t>(record.get("index", 1));
    parsed.name = record.get("name", ui("الطريق الأول"));
    parsed.world_width = static_cast<double>(record.get("world_width", 3600.0));
    parsed.required_coins = static_cast<double>(record.get("required_coins", 0));
    parsed.spawn = point_from_array(record.get("spawn", Array()), Vector2(130.0, 590.0));
    parsed.exit = point_from_array(record.get("exit", Array()), Vector2(parsed.world_width - 120.0, 590.0));
    const String palette = record.get("palette", String("warm"));
    parsed.monochrome = palette == "monochrome";

    const Array platforms_data = record.get("platforms", Array());
    for (int32_t i = 0; i < platforms_data.size(); ++i) {
        const Array values = platforms_data[i];
        if (values.size() >= 4) {
            parsed.platforms.push_back(Rect2(
                Vector2(static_cast<double>(values[0]), static_cast<double>(values[1])),
                Vector2(static_cast<double>(values[2]), static_cast<double>(values[3]))));
        }
    }
    const Array coins_data = record.get("coins", Array());
    for (int32_t i = 0; i < coins_data.size(); ++i) {
        parsed.coins.push_back(point_from_array(coins_data[i], Vector2()));
    }
    const Array hazards_data = record.get("hazards", Array());
    for (int32_t i = 0; i < hazards_data.size(); ++i) {
        const Array values = hazards_data[i];
        if (values.size() >= 4) {
            parsed.hazards.push_back(Rect2(
                Vector2(static_cast<double>(values[0]), static_cast<double>(values[1])),
                Vector2(static_cast<double>(values[2]), static_cast<double>(values[3]))));
        }
    }
    if (parsed.platforms.empty()) {
        parsed.platforms.emplace_back(Vector2(0.0, 620.0), Vector2(parsed.world_width, 100.0));
    }
    return parsed;
}

RazorPathGame::StageData RazorPathGame::make_generated_stage(int32_t requested_index) const {
    StageData generated;
    generated.index = requested_index;
    generated.name = ui("مسار الظلال ") + String::num_int64(requested_index);
    generated.world_width = 3600.0 + requested_index * 180.0;
    generated.required_coins = std::clamp(static_cast<double>(requested_index), 1.0, 8.0);
    generated.spawn = Vector2(120.0, 590.0);
    generated.exit = Vector2(generated.world_width - 130.0, 590.0);
    generated.monochrome = (requested_index % 5 == 0);
    generated.platforms.emplace_back(Vector2(0.0, 620.0), Vector2(650.0, 100.0));

    const int32_t segments = 5 + (requested_index % 3);
    for (int32_t i = 0; i < segments; ++i) {
        const double start_x = 700.0 + i * ((generated.world_width - 1200.0) / segments);
        const double y = 520.0 - ((i + requested_index) % 4) * 78.0;
        const double width = 220.0 + (i % 2) * 90.0;
        generated.platforms.emplace_back(Vector2(start_x, y), Vector2(width, 28.0));
        generated.coins.emplace_back(Vector2(start_x + width * 0.45, y - 52.0));
        if ((i + requested_index) % 3 == 0) {
            generated.hazards.emplace_back(Vector2(start_x + width * 0.60, y - 38.0), Vector2(42.0, 34.0));
        }
    }

    const double final_x = generated.world_width - 420.0;
    generated.platforms.emplace_back(Vector2(final_x, 620.0), Vector2(420.0, 100.0));
    generated.coins.emplace_back(Vector2(final_x + 200.0, 525.0));
    generated.coins.emplace_back(Vector2(final_x + 120.0, 510.0));
    return generated;
}

bool RazorPathGame::load_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > 16) {
        return false;
    }
    const auto authored = authored_stages.find(requested_index);
    stage = authored != authored_stages.end() ? authored->second : make_generated_stage(requested_index);
    stage_index = requested_index;
    player_x = stage.spawn.x;
    player_feet = stage.spawn.y;
    player_vy = 0.0;
    camera_x = 0.0;
    stage_coins = 0;
    remaining_time = 180.0;
    on_ground = false;
    run_finalized = false;
    jump_requested = false;
    attack_requested = false;
    landing_time = 0.0;
    coyote_time = 0.0;
    jump_buffer_time = 0.0;
    std::fill(std::begin(stage_coin_collected), std::end(stage_coin_collected), false);
    return true;
}

void RazorPathGame::start_new_run() {
    total_jumps = 0;
    start_stage(1);
}

void RazorPathGame::start_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > unlocked_stage) {
        return;
    }
    if (!load_stage(requested_index)) {
        return;
    }
    screen = RazorScreen::PLAYING;
    touch_actions.clear();
    rebuild_ui();
    queue_redraw();
}

void RazorPathGame::complete_stage() {
    if (run_finalized) {
        return;
    }
    run_finalized = true;
    if (stage_index < 16) {
        unlocked_stage = std::max(unlocked_stage, stage_index + 1);
        screen = RazorScreen::STAGE_CLEAR;
    } else {
        unlocked_stage = 16;
        screen = RazorScreen::VICTORY;
    }
    save_progress();
    touch_actions.clear();
    rebuild_ui();
    queue_redraw();
}

void RazorPathGame::fail_run() {
    if (run_finalized) {
        return;
    }
    run_finalized = true;
    screen = RazorScreen::GAME_OVER;
    touch_actions.clear();
    rebuild_ui();
    queue_redraw();
}

void RazorPathGame::spawn_particles(const Vector2 &at, const Color &color, int32_t count, double impulse) {
    if (reduced_motion) {
        return;
    }
    for (int32_t i = 0; i < count && particles.size() < 192; ++i) {
        const double angle = (Math_TAU * static_cast<double>(i)) / std::max(1, count);
        const double speed = impulse * (0.45 + 0.55 * static_cast<double>((i % 5) + 1) / 5.0);
        Particle p;
        p.position = at;
        p.velocity = Vector2(std::cos(angle) * speed, std::sin(angle) * speed - 30.0);
        p.color = color;
        p.lifetime = 0.48 + (i % 4) * 0.07;
        p.size = 2.0 + (i % 3) * 1.2;
        particles.push_back(p);
    }
}

void RazorPathGame::update_touch_state(const Ref<InputEvent> &event) {
    if (screen != RazorScreen::PLAYING) {
        return;
    }
    const Vector2 size = logical_size();
    if (event.is_valid() && Object::cast_to<InputEventScreenTouch>(event.ptr())) {
        const InputEventScreenTouch *touch = Object::cast_to<InputEventScreenTouch>(event.ptr());
        const int32_t id = touch->get_index();
        const Vector2 pos = touch->get_position();
        if (!touch->is_pressed()) {
            touch_actions.erase(id);
            return;
        }
        if (pos.x > size.x - 170.0 && pos.y < 110.0) {
            screen = RazorScreen::PAUSED;
            touch_actions.clear();
            rebuild_ui();
            return;
        }
        TouchAction action = TouchAction::NONE;
        if (pos.y > size.y * 0.72 && pos.x < size.x * 0.30) {
            action = pos.x < size.x * 0.15 ? TouchAction::LEFT : TouchAction::RIGHT;
        } else if (pos.y > size.y * 0.62 && pos.x > size.x * 0.66) {
            action = pos.x > size.x * 0.85 ? TouchAction::ATTACK : TouchAction::JUMP;
        }
        if (action == TouchAction::JUMP) {
            jump_requested = true;
        } else if (action == TouchAction::ATTACK) {
            attack_requested = true;
        }
        if (action == TouchAction::NONE) {
            touch_actions.erase(id);
        } else {
            touch_actions[id] = action;
        }
        return;
    }
    if (event.is_valid() && Object::cast_to<InputEventScreenDrag>(event.ptr())) {
        const InputEventScreenDrag *drag = Object::cast_to<InputEventScreenDrag>(event.ptr());
        const int32_t id = drag->get_index();
        const Vector2 pos = drag->get_position();
        TouchAction action = TouchAction::NONE;
        if (pos.y > size.y * 0.72 && pos.x < size.x * 0.30) {
            action = pos.x < size.x * 0.15 ? TouchAction::LEFT : TouchAction::RIGHT;
        } else if (pos.y > size.y * 0.62 && pos.x > size.x * 0.66) {
            action = pos.x > size.x * 0.85 ? TouchAction::ATTACK : TouchAction::JUMP;
        }
        if (action == TouchAction::JUMP && touch_actions[id] != TouchAction::JUMP) {
            jump_requested = true;
        }
        if (action == TouchAction::ATTACK && touch_actions[id] != TouchAction::ATTACK) {
            attack_requested = true;
        }
        if (action == TouchAction::NONE) {
            touch_actions.erase(id);
        } else {
            touch_actions[id] = action;
        }
    }
}

void RazorPathGame::_input(const Ref<InputEvent> &event) {
    if (event.is_null()) {
        return;
    }
    if (Object::cast_to<InputEventKey>(event.ptr())) {
        const InputEventKey *key = Object::cast_to<InputEventKey>(event.ptr());
        if (!key->is_pressed() || key->is_echo()) {
            return;
        }
        const Key code = key->get_keycode();
        if (code == Key::KEY_ESCAPE || code == Key::KEY_BACK) {
            go_back();
            return;
        }
        if (screen == RazorScreen::PLAYING) {
            if (code == Key::KEY_SPACE || code == Key::KEY_UP || code == Key::KEY_W) {
                jump_requested = true;
                jump_buffer_time = 0.16;
            }
            if (code == Key::KEY_J || code == Key::KEY_X) {
                attack_requested = true;
            }
        }
    }
    update_touch_state(event);
}

void RazorPathGame::_process(double delta) {
    animation_time += delta;
    background_time += delta;
    attack_time = std::max(0.0, attack_time - delta);
    attack_cooldown = std::max(0.0, attack_cooldown - delta);
    landing_time = std::max(0.0, landing_time - delta);
    toast_time = std::max(0.0, toast_time - delta);
    jump_buffer_time = std::max(0.0, jump_buffer_time - delta);
    coyote_time = on_ground ? 0.12 : std::max(0.0, coyote_time - delta);
    if (toast_time <= 0.0 && toast_label != nullptr) {
        toast_label->set_text(String());
    }
    for (Particle &particle : particles) {
        particle.position += particle.velocity * delta;
        particle.velocity.y += 460.0 * delta;
        particle.lifetime -= delta;
    }
    particles.erase(std::remove_if(particles.begin(), particles.end(), [](const Particle &p) { return p.lifetime <= 0.0; }), particles.end());
    if (screen == RazorScreen::PLAYING && hud_label != nullptr) {
        update_hud();
    }
    queue_redraw();
}

void RazorPathGame::_physics_process(double delta) {
    if (screen != RazorScreen::PLAYING) {
        return;
    }
    remaining_time = std::max(0.0, remaining_time - delta);
    if (remaining_time <= 0.0) {
        fail_run();
        return;
    }

    Input *input = Input::get_singleton();
    bool left = input->is_key_pressed(Key::KEY_A) || input->is_key_pressed(Key::KEY_LEFT);
    bool right = input->is_key_pressed(Key::KEY_D) || input->is_key_pressed(Key::KEY_RIGHT);
    bool attack = attack_requested || input->is_key_pressed(Key::KEY_J) || input->is_key_pressed(Key::KEY_X);
    for (const auto &entry : touch_actions) {
        left = left || entry.second == TouchAction::LEFT;
        right = right || entry.second == TouchAction::RIGHT;
    }

    const double axis = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    const double move_speed = 420.0;
    player_x = std::clamp(player_x + axis * move_speed * delta, 18.0, stage.world_width - 18.0);

    if (jump_requested || jump_buffer_time > 0.0) {
        jump_buffer_time = std::max(jump_buffer_time, 0.16);
    }
    if (jump_buffer_time > 0.0 && (on_ground || coyote_time > 0.0)) {
        player_vy = -780.0;
        on_ground = false;
        coyote_time = 0.0;
        jump_buffer_time = 0.0;
        total_jumps += 1;
        spawn_particles(Vector2(player_x, player_feet - 4.0), stage.monochrome ? rgba8(0x111111) : rgba8(0x685e49), 8, 95.0);
    }
    if (attack && attack_cooldown <= 0.0) {
        attack_time = 0.28;
        attack_cooldown = 0.36;
        const double dir = axis < 0.0 ? -1.0 : 1.0;
        const Rect2 strike(Vector2(player_x + dir * 18.0 - 24.0, player_feet - 112.0), Vector2(68.0, 82.0));
        for (Rect2 &hazard : stage.hazards) {
            if (strike.intersects(hazard)) {
                const Vector2 hazard_center = hazard.position + hazard.size * 0.5;
                hazard.position.x = -100000.0;
                spawn_particles(hazard_center, stage.monochrome ? rgba8(0x222222) : rgba8(0xe7b84b), 12, 130.0);
            }
        }
    }
    jump_requested = false;
    attack_requested = false;

    const double old_feet = player_feet;
    player_vy += 1950.0 * delta;
    player_feet += player_vy * delta;
    on_ground = false;
    for (const Rect2 &platform : stage.platforms) {
        const bool overlaps_x = player_x + 20.0 > platform.position.x && player_x - 20.0 < platform.position.x + platform.size.x;
        const bool crossed_top = old_feet <= platform.position.y + 4.0 && player_feet >= platform.position.y;
        if (overlaps_x && crossed_top && player_vy >= 0.0) {
            player_feet = platform.position.y;
            player_vy = 0.0;
            on_ground = true;
            coyote_time = 0.12;
        }
    }
    if (on_ground && old_feet > player_feet + 2.0) {
        landing_time = 0.12;
        spawn_particles(Vector2(player_x, player_feet - 2.0), stage.monochrome ? rgba8(0x444444) : rgba8(0x625c4f), 5, 55.0);
    }

    const Rect2 body = player_body_rect();
    for (const Rect2 &hazard : stage.hazards) {
        if (hazard.position.x > -500.0 && body.intersects(hazard)) {
            remaining_time = std::max(0.0, remaining_time - 10.0);
            player_x = stage.spawn.x;
            player_feet = stage.spawn.y;
            player_vy = 0.0;
            camera_x = 0.0;
            spawn_particles(Vector2(player_x, player_feet - 30.0), stage.monochrome ? rgba8(0x555555) : rgba8(0x744b42), 14, 100.0);
            break;
        }
    }
    for (size_t i = 0; i < stage.coins.size() && i < 256; ++i) {
        if (!stage_coin_collected[i] && body.grow(7.0).has_point(stage.coins[i])) {
            stage_coin_collected[i] = true;
            ++stage_coins;
            ++coins;
            spawn_particles(stage.coins[i], stage.monochrome ? rgba8(0x222222) : rgba8(0xd5a749), 12, 105.0);
            save_progress();
        }
    }

    if (player_feet > 900.0) {
        remaining_time = std::max(0.0, remaining_time - 10.0);
        player_x = stage.spawn.x;
        player_feet = stage.spawn.y;
        player_vy = 0.0;
        camera_x = 0.0;
    }
    if (std::abs(player_x - stage.exit.x) < 38.0 && std::abs(player_feet - stage.exit.y) < 90.0) {
        if (stage_coins >= static_cast<int32_t>(stage.required_coins)) {
            complete_stage();
            return;
        }
        if (toast_time <= 0.0) {
            toast_time = 1.8;
            if (toast_label != nullptr) {
                toast_label->set_text(ui("اجمع عملات أكثر لفتح المخرج"));
            }
        }
    }

    const double view_width = logical_size().x;
    const double max_camera = std::max(0.0, stage.world_width - view_width);
    const double target_camera = std::clamp(player_x - view_width * 0.38, 0.0, max_camera);
    camera_x += (target_camera - camera_x) * std::min(1.0, 8.0 * delta);
}

Vector2 RazorPathGame::logical_size() const {
    const Rect2 viewport = get_viewport_rect();
    if (viewport.size.x < 1.0 || viewport.size.y < 1.0) {
        return Vector2(1280.0, 720.0);
    }
    return viewport.size;
}

Color RazorPathGame::background_color() const {
    return stage.monochrome ? rgba8(0xf6f6f3) : rgba8(0xf0e5c4);
}

Color RazorPathGame::far_color() const {
    return stage.monochrome ? rgba8(0xe8e8e6) : rgba8(0xb5ad91);
}

Color RazorPathGame::near_color() const {
    return stage.monochrome ? rgba8(0x111111) : rgba8(0x777365);
}

Color RazorPathGame::platform_color() const {
    return rgba8(0x090909);
}

Color RazorPathGame::hero_tint() const {
    if (selected_skin == 1) {
        return Color(1.0, 0.83, 0.46, 1.0);
    }
    if (selected_skin == 2) {
        return Color(0.74, 0.84, 0.92, 1.0);
    }
    return Color(1.0, 1.0, 1.0, 1.0);
}

Rect2 RazorPathGame::player_body_rect() const {
    return Rect2(Vector2(player_x - 18.0, player_feet - 118.0), Vector2(36.0, 118.0));
}

int32_t RazorPathGame::current_hero_frame() const {
    if (screen == RazorScreen::VICTORY || screen == RazorScreen::STAGE_CLEAR) {
        return 7;
    }
    if (attack_time > 0.0) {
        return (static_cast<int32_t>(animation_time * 16.0) % 2 == 0) ? 3 : 7;
    }
    if (!on_ground) {
        return player_vy < -70.0 ? 4 : 5;
    }
    if (landing_time > 0.0) {
        return 6;
    }
    const Input *input = Input::get_singleton();
    const bool moving = input->is_key_pressed(Key::KEY_A) || input->is_key_pressed(Key::KEY_D) ||
        input->is_key_pressed(Key::KEY_LEFT) || input->is_key_pressed(Key::KEY_RIGHT) || !touch_actions.empty();
    if (moving) {
        return (static_cast<int32_t>(animation_time * 10.0) % 2 == 0) ? 1 : 2;
    }
    return 0;
}

void RazorPathGame::_draw() {
    const Vector2 size = logical_size();
    draw_rect(Rect2(Vector2(), size), background_color(), true);

    const bool showing_world = screen == RazorScreen::PLAYING || screen == RazorScreen::PAUSED ||
        screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER;
    const double parallax = showing_world ? camera_x : 0.0;
    draw_rect(Rect2(Vector2(0.0, size.y * 0.48), Vector2(size.x, size.y * 0.30)), far_color(), true);
    PackedVector2Array distant;
    distant.push_back(Vector2(-20.0, size.y * 0.60));
    distant.push_back(Vector2(size.x * 0.03, size.y * 0.44));
    distant.push_back(Vector2(size.x * 0.16, size.y * 0.51));
    distant.push_back(Vector2(size.x * 0.29, size.y * 0.36));
    distant.push_back(Vector2(size.x * 0.45, size.y * 0.53));
    distant.push_back(Vector2(size.x * 0.60, size.y * 0.40));
    distant.push_back(Vector2(size.x * 0.76, size.y * 0.55));
    distant.push_back(Vector2(size.x * 0.91, size.y * 0.39));
    distant.push_back(Vector2(size.x + 20.0, size.y * 0.54));
    distant.push_back(Vector2(size.x + 20.0, size.y * 0.83));
    distant.push_back(Vector2(-20.0, size.y * 0.83));
    draw_colored_polygon(distant, far_color());

    const double skyline_shift = std::fmod(parallax * 0.14 + background_time * 4.0, 210.0);
    for (int32_t i = -1; i < static_cast<int32_t>(size.x / 170.0) + 3; ++i) {
        const double x = i * 170.0 - skyline_shift;
        const double top = size.y * (0.38 + (i % 3) * 0.025);
        draw_rect(Rect2(Vector2(x, top), Vector2(58.0 + (i % 2) * 24.0, size.y * 0.83 - top)), near_color(), true);
        draw_rect(Rect2(Vector2(x + 12.0, top - 22.0), Vector2(8.0, 22.0)), near_color(), true);
    }

    if (!stage.monochrome) {
        const double tree_scale_x = size.x / 1280.0;
        for (int32_t i = 0; i < 3; ++i) {
            const double tree_x = (280.0 + i * 1120.0 - parallax * 0.24) * tree_scale_x;
            const double tree_y = size.y * 0.60;
            if (tree_x > -70.0 && tree_x < size.x + 70.0) {
                draw_rect(Rect2(Vector2(tree_x - 5.0, tree_y - 25.0), Vector2(10.0, 70.0)), near_color(), true);
                draw_circle(Vector2(tree_x, tree_y - 51.0), 31.0 * tree_scale_x, near_color());
                draw_circle(Vector2(tree_x - 21.0 * tree_scale_x, tree_y - 35.0), 24.0 * tree_scale_x, near_color());
                draw_circle(Vector2(tree_x + 22.0 * tree_scale_x, tree_y - 34.0), 25.0 * tree_scale_x, near_color());
            }
        }
    }

    const double floor_y = size.y * 0.86;
    draw_rect(Rect2(Vector2(0.0, floor_y), Vector2(size.x, size.y - floor_y)), near_color(), true);

    const double scale_x = size.x / 1280.0;
    const double scale_y = size.y / 720.0;
    const double world_scale_y = scale_y;
    const double camera = showing_world ? camera_x : 0.0;
    const Color platform = platform_color();
    for (const Rect2 &platform_rect : stage.platforms) {
        const Rect2 visible(Vector2((platform_rect.position.x - camera) * scale_x, platform_rect.position.y * scale_y),
            Vector2(platform_rect.size.x * scale_x, std::max(7.0, platform_rect.size.y * scale_y)));
        if (visible.position.x < size.x && visible.position.x + visible.size.x > 0.0) {
            draw_rect(visible, platform, true);
            draw_rect(Rect2(visible.position, Vector2(visible.size.x, 4.0 * scale_y)), stage.monochrome ? rgba8(0x111111) : rgba8(0x171614), true);
        }
    }

    for (int32_t ladder = 0; ladder < 4; ++ladder) {
        const double lx = (520.0 + ladder * 950.0 - camera) * scale_x;
        const double ly = size.y * 0.60;
        if (lx > -30.0 && lx < size.x + 30.0) {
            const Color rung = stage.monochrome ? rgba8(0x080808) : rgba8(0x111111);
            draw_line(Vector2(lx, ly), Vector2(lx + 36.0 * scale_x, floor_y), rung, 4.0 * scale_x);
            draw_line(Vector2(lx + 20.0 * scale_x, ly), Vector2(lx + 56.0 * scale_x, floor_y), rung, 4.0 * scale_x);
            for (int32_t r = 0; r < 6; ++r) {
                const double y = ly + r * (floor_y - ly) / 6.0;
                draw_line(Vector2(lx + 4.0 * scale_x, y), Vector2(lx + 44.0 * scale_x, y), rung, 3.0 * scale_x);
            }
        }
    }

    for (size_t i = 0; i < stage.coins.size() && i < 256; ++i) {
        if (stage_coin_collected[i]) {
            continue;
        }
        const Vector2 center((stage.coins[i].x - camera) * scale_x, stage.coins[i].y * scale_y);
        if (center.x > -24.0 && center.x < size.x + 24.0) {
            draw_circle(center, 12.0 * scale_x, stage.monochrome ? rgba8(0x222222) : rgba8(0xd8ab42));
            draw_circle(center, 6.0 * scale_x, stage.monochrome ? rgba8(0xf5f5f5) : rgba8(0xf4df9b));
        }
    }

    for (const Rect2 &hazard : stage.hazards) {
        if (hazard.position.x < -500.0) {
            continue;
        }
        const Rect2 r(Vector2((hazard.position.x - camera) * scale_x, hazard.position.y * scale_y),
            Vector2(hazard.size.x * scale_x, hazard.size.y * scale_y));
        if (r.position.x < size.x && r.position.x + r.size.x > 0.0) {
            draw_rect(r, stage.monochrome ? rgba8(0x111111) : rgba8(0x282724), true);
            draw_circle(r.position + Vector2(r.size.x * 0.35, r.size.y * 0.43), 4.0 * scale_x, stage.monochrome ? rgba8(0xffffff) : rgba8(0x595b60));
            draw_circle(r.position + Vector2(r.size.x * 0.70, r.size.y * 0.43), 4.0 * scale_x, stage.monochrome ? rgba8(0xffffff) : rgba8(0x595b60));
        }
    }

    const Vector2 exit_pos((stage.exit.x - camera) * scale_x, stage.exit.y * scale_y);
    if (exit_pos.x > -100.0 && exit_pos.x < size.x + 100.0) {
        const Color gate = stage.monochrome ? rgba8(0x080808) : rgba8(0x111111);
        draw_rect(Rect2(exit_pos + Vector2(-24.0 * scale_x, -150.0 * scale_y), Vector2(16.0 * scale_x, 150.0 * scale_y)), gate, true);
        draw_rect(Rect2(exit_pos + Vector2(24.0 * scale_x, -150.0 * scale_y), Vector2(16.0 * scale_x, 150.0 * scale_y)), gate, true);
        draw_rect(Rect2(exit_pos + Vector2(-24.0 * scale_x, -150.0 * scale_y), Vector2(64.0 * scale_x, 14.0 * scale_y)), gate, true);
    }

    if (screen == RazorScreen::PLAYING || screen == RazorScreen::PAUSED || screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER) {
        const int32_t frame = current_hero_frame();
        const double sprite_width = 66.0 * scale_x;
        const double sprite_height = 132.0 * world_scale_y;
        const Vector2 sprite_pos((player_x - camera) * scale_x - sprite_width * 0.5, player_feet * scale_y - sprite_height);
        if (hero_frames[frame].is_valid()) {
            draw_texture_rect(hero_frames[frame], Rect2(sprite_pos, Vector2(sprite_width, sprite_height)), false, hero_tint());
        } else {
            draw_circle(sprite_pos + Vector2(sprite_width * 0.5, 20.0 * scale_y), 13.0 * scale_x, rgba8(0xf5f5f5));
            draw_rect(Rect2(sprite_pos + Vector2(sprite_width * 0.36, 34.0 * scale_y), Vector2(sprite_width * 0.28, 72.0 * scale_y)), rgba8(0xf5f5f5), true);
        }
    }

    for (const Particle &particle : particles) {
        const Vector2 p((particle.position.x - camera) * scale_x, particle.position.y * scale_y);
        const float alpha = static_cast<float>(std::clamp(particle.lifetime / 0.6, 0.0, 1.0));
        draw_circle(p, particle.size * scale_x, Color(particle.color.r, particle.color.g, particle.color.b, alpha));
    }

    if (screen == RazorScreen::PLAYING) {
        const Color control_fill(0.06, 0.06, 0.06, 0.42);
        const Color control_line(1.0, 1.0, 1.0, 0.60);
        const double cy = size.y * 0.84;
        for (const double x : {size.x * 0.075, size.x * 0.20, size.x * 0.82, size.x * 0.93}) {
            draw_circle(Vector2(x, cy), 42.0 * scale_x, control_fill);
            draw_arc(Vector2(x, cy), 42.0 * scale_x, 0.0, Math_TAU, 32, control_line, 2.0 * scale_x);
        }
        draw_line(Vector2(size.x * 0.075 - 12.0, cy), Vector2(size.x * 0.075 + 10.0, cy), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.20 + 12.0, cy), Vector2(size.x * 0.20 - 10.0, cy), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.82, cy + 12.0), Vector2(size.x * 0.82, cy - 12.0), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.93 - 10.0, cy + 10.0), Vector2(size.x * 0.93 + 10.0, cy - 10.0), control_line, 5.0 * scale_x);
    }

    if (screen == RazorScreen::PAUSED || screen == RazorScreen::SHOP || screen == RazorScreen::SETTINGS || screen == RazorScreen::LEVEL_SELECT || screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER) {
        draw_rect(Rect2(Vector2(), size), Color(0.02, 0.02, 0.02, 0.54), true);
    }
}

void RazorPathGame::clear_ui() {
    hud_label = nullptr;
    toast_label = nullptr;
    if (ui_root == nullptr) {
        return;
    }
    for (int32_t i = ui_root->get_child_count() - 1; i >= 0; --i) {
        Node *child = ui_root->get_child(i);
        ui_root->remove_child(child);
        child->queue_free();
    }
}

void RazorPathGame::add_label(const String &text, const Rect2 &rect, int32_t font_size, bool bold, bool rtl) {
    if (ui_root == nullptr) {
        return;
    }
    Label *label = memnew(Label);
    label->set_text(text);
    label->set_position(rect.position);
    label->set_size(rect.size);
    label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
    label->set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER);
    label->set_layout_direction(rtl ? Control::LAYOUT_DIRECTION_RTL : Control::LAYOUT_DIRECTION_LTR);
    label->set_text_direction(rtl ? Control::TEXT_DIRECTION_RTL : Control::TEXT_DIRECTION_AUTO);
    label->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    if (bold && arabic_bold_font.is_valid()) {
        label->add_theme_font_override("font", arabic_bold_font);
    }
    label->add_theme_font_size_override("font_size", font_size);
    ui_root->add_child(label);
}

Button *RazorPathGame::add_button(const String &text, const Rect2 &rect, const String &action, bool disabled) {
    if (ui_root == nullptr) {
        return nullptr;
    }
    Button *button = memnew(Button);
    button->set_text(text);
    button->set_position(rect.position);
    button->set_size(rect.size);
    button->set_disabled(disabled);
    button->set_layout_direction(Control::LAYOUT_DIRECTION_RTL);
    button->set_text_direction(Control::TEXT_DIRECTION_AUTO);
    button->set_focus_mode(Control::FOCUS_NONE);
    button->add_theme_font_size_override("font_size", 24);
    const Color fill = disabled ? rgba8(0x777777) : rgba8(0x171717);
    Ref<StyleBoxFlat> normal;
    normal.instantiate();
    normal->set_bg_color(fill);
    normal->set_border_width_all(2);
    normal->set_border_color(stage.monochrome ? rgba8(0x111111) : rgba8(0x766f5f));
    normal->set_corner_radius_all(12);
    normal->set_content_margin_all(10.0);
    button->add_theme_stylebox_override("normal", normal);
    Ref<StyleBoxFlat> hover;
    hover.instantiate();
    hover->set_bg_color(disabled ? fill : (stage.monochrome ? rgba8(0x3a3a3a) : rgba8(0x474236)));
    hover->set_border_width_all(2);
    hover->set_border_color(stage.monochrome ? rgba8(0xffffff) : rgba8(0xe2bd69));
    hover->set_corner_radius_all(12);
    hover->set_content_margin_all(10.0);
    button->add_theme_stylebox_override("hover", hover);
    button->add_theme_stylebox_override("pressed", hover);
    button->add_theme_color_override("font_color", rgba8(0xfaf8f1));
    button->add_theme_color_override("font_hover_color", rgba8(0xffffff));
    button->add_theme_color_override("font_disabled_color", rgba8(0xc9c9c9));
    button->connect("pressed", Callable(this, "_on_ui_action").bind(action));
    ui_root->add_child(button);
    return button;
}

void RazorPathGame::update_hud() {
    if (hud_label != nullptr) {
        String text = ui("المرحلة ") + String::num_int64(stage_index) + ui("، العملات ") + String::num_int64(stage_coins) + ui(" من ") + String::num_int64(static_cast<int64_t>(std::ceil(stage.required_coins))) + ui("، الوقت ");
        text += String::num_int64(static_cast<int64_t>(std::ceil(remaining_time))) + ui(" ثانية");
        hud_label->set_text(text);
    }
}

void RazorPathGame::rebuild_ui() {
    clear_ui();
    if (ui_root == nullptr) {
        return;
    }
    const Vector2 size = logical_size();
    const double sx = size.x / 1280.0;
    const double sy = size.y / 720.0;
    auto rect = [sx, sy](double x, double y, double w, double h) {
        return Rect2(Vector2(x * sx, y * sy), Vector2(w * sx, h * sy));
    };

    if (screen == RazorScreen::HOME) {
        add_label(ui("RAZOR PATH"), rect(300, 100, 680, 100), 58, true, false);
        add_label(ui("ظلال دافئة، قفزات دقيقة، وطريق يتكشف أمامك"), rect(230, 190, 820, 62), 25, false, true);
        add_button(ui("ابدأ المرحلة ١"), rect(430, 300, 420, 70), "new_game");
        add_button(ui("اختيار المرحلة"), rect(430, 390, 420, 64), "levels");
        add_button(ui("المتجر"), rect(430, 474, 200, 64), "shop");
        add_button(ui("الإعدادات"), rect(650, 474, 200, 64), "settings");
        add_label(ui("الحركة: يسار ويمين   القفز   الهجوم   الرجوع: زر الجهاز"), rect(150, 545, 980, 46), 20, false, true);
    } else if (screen == RazorScreen::LEVEL_SELECT) {
        add_label(ui("اختر طريقك"), rect(390, 52, 500, 78), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        for (int32_t i = 1; i <= 16; ++i) {
            const int32_t col = (i - 1) % 4;
            const int32_t row = (i - 1) / 4;
            const double x = 185.0 + col * 230.0;
            const double y = 150.0 + row * 112.0;
            const bool locked = i > unlocked_stage;
            String caption = locked ? ui("مقفلة") : ui("المرحلة ") + String::num_int64(i);
            add_button(caption, rect(x, y, 195, 74), "stage:" + String::num_int64(i), locked);
        }
    } else if (screen == RazorScreen::PLAYING) {
        hud_label = memnew(Label);
        hud_label->set_position(Vector2(250.0 * sx, 16.0 * sy));
        hud_label->set_size(Vector2(780.0 * sx, 56.0 * sy));
        hud_label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
        hud_label->set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER);
        hud_label->set_layout_direction(Control::LAYOUT_DIRECTION_RTL);
        hud_label->set_text_direction(Control::TEXT_DIRECTION_AUTO);
        hud_label->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
        hud_label->add_theme_font_size_override("font_size", 24);
        ui_root->add_child(hud_label);
        update_hud();
        add_button(ui("إيقاف"), rect(1110, 20, 132, 58), "pause");
        toast_label = memnew(Label);
        toast_label->set_position(Vector2(330.0 * sx, 500.0 * sy));
        toast_label->set_size(Vector2(620.0 * sx, 58.0 * sy));
        toast_label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
        toast_label->set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER);
        toast_label->set_layout_direction(Control::LAYOUT_DIRECTION_RTL);
        toast_label->set_text_direction(Control::TEXT_DIRECTION_RTL);
        toast_label->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
        toast_label->add_theme_font_size_override("font_size", 24);
        ui_root->add_child(toast_label);
    } else if (screen == RazorScreen::PAUSED) {
        add_label(ui("اللعبة متوقفة"), rect(390, 110, 500, 78), 44, true);
        add_button(ui("متابعة اللعب"), rect(440, 225, 400, 66), "resume");
        add_button(ui("إعادة المرحلة"), rect(440, 306, 400, 66), "restart");
        add_button(ui("المتجر"), rect(440, 387, 190, 62), "shop");
        add_button(ui("الإعدادات"), rect(650, 387, 190, 62), "settings");
        add_button(ui("العودة للقائمة"), rect(440, 467, 400, 62), "home");
    } else if (screen == RazorScreen::SHOP) {
        add_label(ui("متجر المظاهر"), rect(390, 76, 500, 75), 42, true);
        add_label(ui("رصيدك: ") + String::num_int64(coins), rect(460, 150, 360, 48), 25);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        add_button(ui("المظهر الأساسي، مجاني"), rect(345, 245, 590, 64), "skin:0", selected_skin == 0);
        add_button(ui("المظهر الذهبي، ٢٥ عملة"), rect(345, 330, 590, 64), "skin:1", selected_skin == 1);
        add_button(ui("المظهر الفضي، ٥٠ عملة"), rect(345, 415, 590, 64), "skin:2", selected_skin == 2);
        add_label(ui("يُحفظ المظهر المختار تلقائيًا"), rect(390, 515, 500, 48), 22);
    } else if (screen == RazorScreen::SETTINGS) {
        add_label(ui("الإعدادات"), rect(390, 76, 500, 75), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        add_button(muted ? ui("الصوت: مكتوم") : ui("الصوت: يعمل"), rect(345, 235, 590, 66), "mute");
        add_button(reduced_motion ? ui("الحركة: منخفضة") : ui("الحركة: كاملة"), rect(345, 325, 590, 66), "motion");
        add_label(ui("الوضع الأفقي ملء الشاشة"), rect(390, 435, 500, 50), 23);
    } else if (screen == RazorScreen::STAGE_CLEAR) {
        add_label(ui("أحسنت! الطريق التالي مفتوح"), rect(260, 150, 760, 80), 42, true);
        add_label(ui("المرحلة ") + String::num_int64(stage_index) + ui(" اكتملت"), rect(390, 230, 500, 50), 25);
        add_button(ui("المرحلة التالية"), rect(420, 335, 440, 68), "next");
        add_button(ui("اختيار المراحل"), rect(420, 420, 210, 62), "levels");
        add_button(ui("القائمة الرئيسية"), rect(650, 420, 210, 62), "home");
    } else if (screen == RazorScreen::VICTORY) {
        add_label(ui("اكتمل طريق الظلال!"), rect(260, 135, 760, 86), 46, true);
        add_label(ui("أنهيت المراحل الست عشرة"), rect(350, 230, 580, 54), 28);
        add_button(ui("العب المرحلة ١٦ مجددًا"), rect(385, 340, 510, 68), "restart");
        add_button(ui("القائمة الرئيسية"), rect(385, 428, 510, 64), "home");
    } else if (screen == RazorScreen::GAME_OVER) {
        add_label(ui("انتهى الوقت"), rect(390, 150, 500, 80), 44, true);
        add_button(ui("أعد المحاولة"), rect(420, 300, 440, 68), "restart");
        add_button(ui("القائمة الرئيسية"), rect(420, 390, 440, 64), "home");
    }
    queue_redraw();
}

void RazorPathGame::set_screen(RazorScreen next_screen) {
    screen = next_screen;
    touch_actions.clear();
    jump_requested = false;
    attack_requested = false;
    rebuild_ui();
}

void RazorPathGame::go_back() {
    if (screen == RazorScreen::SHOP || screen == RazorScreen::SETTINGS) {
        set_screen(return_screen);
    } else if (screen == RazorScreen::PAUSED) {
        set_screen(RazorScreen::PLAYING);
    } else if (screen == RazorScreen::PLAYING) {
        set_screen(RazorScreen::PAUSED);
    } else if (screen == RazorScreen::LEVEL_SELECT || screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER) {
        set_screen(RazorScreen::HOME);
    }
}

void RazorPathGame::handle_action(const String &action) {
    if (action == "new_game") {
        start_new_run();
    } else if (action == "levels") {
        if (screen != RazorScreen::PAUSED) {
            return_screen = RazorScreen::HOME;
        }
        set_screen(RazorScreen::LEVEL_SELECT);
    } else if (action == "shop") {
        return_screen = screen;
        set_screen(RazorScreen::SHOP);
    } else if (action == "settings") {
        return_screen = screen;
        set_screen(RazorScreen::SETTINGS);
    } else if (action == "back") {
        go_back();
    } else if (action == "pause") {
        set_screen(RazorScreen::PAUSED);
    } else if (action == "resume") {
        set_screen(RazorScreen::PLAYING);
    } else if (action == "restart") {
        start_stage(stage_index);
    } else if (action == "home") {
        set_screen(RazorScreen::HOME);
    } else if (action == "next") {
        start_stage(std::min(16, stage_index + 1));
    } else if (action.begins_with("stage:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(6).to_int());
        if (chosen <= unlocked_stage) {
            start_stage(chosen);
        }
    } else if (action.begins_with("skin:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(5).to_int());
        const int32_t cost = chosen == 1 ? 25 : (chosen == 2 ? 50 : 0);
        if (chosen >= 0 && chosen <= 2 && coins >= cost) {
            if (selected_skin != chosen) {
                coins -= cost;
            }
            selected_skin = chosen;
            save_progress();
            rebuild_ui();
        } else if (coins < cost && toast_label != nullptr) {
            toast_label->set_text(ui("اجمع عملات إضافية أولًا"));
        }
    } else if (action == "mute") {
        muted = !muted;
        save_progress();
        rebuild_ui();
    } else if (action == "motion") {
        reduced_motion = !reduced_motion;
        save_progress();
        rebuild_ui();
    }
}

void RazorPathGame::_on_ui_action(const String &action) {
    handle_action(action);
}

bool RazorPathGame::start_test_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > 16) {
        return false;
    }
    unlocked_stage = std::max(unlocked_stage, requested_index);
    start_stage(requested_index);
    return screen == RazorScreen::PLAYING && stage_index == requested_index;
}

bool RazorPathGame::test_register_touch(int32_t finger_id, int32_t action) {
    if (finger_id < 0 || action < 1 || action > 4) {
        return false;
    }
    touch_actions[finger_id] = static_cast<TouchAction>(action);
    return true;
}

bool RazorPathGame::test_release_touch(int32_t finger_id) {
    return touch_actions.erase(finger_id) > 0;
}

bool RazorPathGame::test_has_touch_action(int32_t action) const {
    for (const auto &entry : touch_actions) {
        if (static_cast<int32_t>(entry.second) == action) {
            return true;
        }
    }
    return false;
}

int32_t RazorPathGame::test_screen() const {
    return static_cast<int32_t>(screen);
}

int32_t RazorPathGame::test_stage() const {
    return stage_index;
}

int32_t RazorPathGame::test_unlocked_stage() const {
    return unlocked_stage;
}

int32_t RazorPathGame::test_coin_count() const {
    return coins;
}

bool RazorPathGame::test_frames_loaded() const {
    return std::all_of(hero_frames.begin(), hero_frames.end(), [](const Ref<Texture2D> &frame) { return frame.is_valid(); });
}

bool RazorPathGame::test_stage_is_monochrome() const {
    return stage.monochrome;
}

double RazorPathGame::test_stage_world_width() const {
    return stage.world_width;
}

bool RazorPathGame::test_try_start_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > unlocked_stage) {
        return false;
    }
    start_stage(requested_index);
    return screen == RazorScreen::PLAYING && stage_index == requested_index;
}

void RazorPathGame::test_set_unlocked_stage(int32_t requested_index) {
    unlocked_stage = std::clamp(requested_index, 1, 16);
}

void RazorPathGame::test_complete_current_stage() {
    complete_stage();
}

void RazorPathGame::test_open_shop() {
    return_screen = screen;
    set_screen(RazorScreen::SHOP);
}

void RazorPathGame::test_open_settings() {
    return_screen = screen;
    set_screen(RazorScreen::SETTINGS);
}

void RazorPathGame::test_back() {
    Ref<InputEventKey> event;
    event.instantiate();
    event->set_pressed(true);
    event->set_keycode(Key::KEY_BACK);
    _input(event);
}

} // namespace godot































































































































































































n
























































































































































































































































































