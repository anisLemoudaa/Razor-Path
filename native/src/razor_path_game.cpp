#include "razor_path_game.hpp"

#include <godot_cpp/classes/audio_server.hpp>
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
#include <godot_cpp/classes/panel.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/style_box_flat.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/texture_rect.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/variant/callable.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

namespace godot {
namespace {

constexpr double kHeroAnimationFps = 30.0;

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

double motion_position(double from, double to, double speed, double time) {
    const double distance = std::abs(to - from);
    if (distance < 0.0001 || speed <= 0.0001) {
        return from;
    }
    const double travel_time = distance / speed;
    const double period = travel_time * 2.0 + 0.8;
    const double phase = std::fmod(std::max(0.0, time), period);
    const double direction = to >= from ? 1.0 : -1.0;
    if (phase < travel_time) {
        return from + direction * speed * phase;
    }
    if (phase < travel_time + 0.4) {
        return to;
    }
    if (phase < travel_time * 2.0 + 0.4) {
        return to - direction * speed * (phase - travel_time - 0.4);
    }
    return from;
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
    ClassDB::bind_method(D_METHOD("test_stage_loadable", "requested_index"), &RazorPathGame::test_stage_loadable);
    ClassDB::bind_method(D_METHOD("test_stage_star_count"), &RazorPathGame::test_stage_star_count);
    ClassDB::bind_method(D_METHOD("test_set_coins", "value"), &RazorPathGame::test_set_coins);
    ClassDB::bind_method(D_METHOD("test_purchase_skin", "skin_index"), &RazorPathGame::test_purchase_skin);
    ClassDB::bind_method(D_METHOD("test_claim_daily_gift_at", "now_utc"), &RazorPathGame::test_claim_daily_gift_at);
    ClassDB::bind_method(D_METHOD("test_skin_owned", "skin_index"), &RazorPathGame::test_skin_owned);
    ClassDB::bind_method(D_METHOD("test_animation_frame_at", "animation_seconds"), &RazorPathGame::test_animation_frame_at);
    ClassDB::bind_method(D_METHOD("_on_ui_action", "action"), &RazorPathGame::_on_ui_action);
}

void RazorPathGame::_ready() {
    load_assets();
    load_save();
    if (AudioServer::get_singleton() != nullptr) {
        AudioServer::get_singleton()->set_bus_mute(0, muted);
    }
    load_authored_stages();
    load_campaign_stages();
    last_seen_utc = std::max(last_seen_utc, utc_now());

    ui_layer = memnew(CanvasLayer);
    ui_layer->set_layer(8);
    add_child(ui_layer);
    ui_root = memnew(Control);
    ui_layer->add_child(ui_root);
    ui_root->set_anchors_and_offsets_preset(Control::PRESET_FULL_RECT);
    ui_root->set_layout_direction(Control::LAYOUT_DIRECTION_LTR);
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
        menu_background = loader->load("res://assets/ui/razor_path_menu_backdrop.png");
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
        unlocked_stage = static_cast<int32_t>(config->get_value("progress", "unlocked_stage", 10));
        coins = static_cast<int32_t>(config->get_value("progress", "coins", 0));
        selected_skin = static_cast<int32_t>(config->get_value("appearance", "skin", 0));
        selected_effect = static_cast<int32_t>(config->get_value("effects", "equipped", 0));
        muted = static_cast<bool>(config->get_value("settings", "muted", false));
        reduced_motion = static_cast<bool>(config->get_value("settings", "reduced_motion", false));
        large_text = static_cast<bool>(config->get_value("settings", "large_text", false));

        const Dictionary saved_levels = config->get_value("progress", "level_progress", Dictionary());
        const Array level_keys = saved_levels.keys();
        for (int32_t i = 0; i < level_keys.size(); ++i) {
            const String key = level_keys[i];
            const int32_t index = static_cast<int32_t>(key.to_int());
            const Dictionary record = saved_levels[key];
            if (index < 1 || index > 250) {
                continue;
            }
            RazorLevelProgress progress;
            progress.completed = static_cast<bool>(record.get("completed", false));
            progress.star_mask = static_cast<uint8_t>(std::clamp(static_cast<int32_t>(record.get("star_mask", 0)), 0, 7));
            progress.best_time = std::max(0.0, static_cast<double>(record.get("best_time", 0.0)));
            level_progress[index] = progress;
        }

        const Array saved_skins = config->get_value("appearance", "owned_skins", Array());
        for (int32_t i = 0; i < saved_skins.size(); ++i) {
            const int32_t skin = static_cast<int32_t>(saved_skins[i]);
            if (skin >= 0 && skin < static_cast<int32_t>(owned_skins.size())) {
                owned_skins[skin] = true;
            }
        }
        const Array saved_chests = config->get_value("progress", "claimed_group_chests", Array());
        for (int32_t i = 0; i < saved_chests.size(); ++i) {
            const int32_t group = static_cast<int32_t>(saved_chests[i]);
            if (group >= 1 && group <= static_cast<int32_t>(claimed_group_chests.size())) {
                claimed_group_chests[group - 1] = true;
            }
        }
        const Array saved_achievements = config->get_value("progress", "claimed_achievements", Array());
        for (int32_t i = 0; i < saved_achievements.size(); ++i) {
            const int32_t achievement = static_cast<int32_t>(saved_achievements[i]);
            if (achievement >= 0 && achievement < static_cast<int32_t>(claimed_achievements.size())) {
                claimed_achievements[achievement] = true;
            }
        }
        const Array saved_effects = config->get_value("effects", "owned", Array());
        for (int32_t i = 0; i < saved_effects.size(); ++i) {
            const int32_t effect = static_cast<int32_t>(saved_effects[i]);
            if (effect >= 0 && effect < static_cast<int32_t>(owned_effects.size())) {
                owned_effects[effect] = true;
            }
        }
        deaths = std::max(0, static_cast<int32_t>(config->get_value("stats", "deaths", 0)));
        coins_earned = std::max(0, static_cast<int32_t>(config->get_value("stats", "coins_earned", 0)));
        total_jumps = std::max(0, static_cast<int32_t>(config->get_value("stats", "total_jumps", 0)));
        play_seconds_total = std::max(0.0, static_cast<double>(config->get_value("stats", "play_seconds", 0.0)));
        daily_last_claim = std::max<int64_t>(0, static_cast<int64_t>(config->get_value("gifts", "daily_last_claim", 0)));
        last_seen_utc = std::max<int64_t>(0, static_cast<int64_t>(config->get_value("gifts", "last_seen_utc", 0)));
    }
    for (int32_t group = 0; group < static_cast<int32_t>(claimed_group_chests.size()); ++group) {
        if (claimed_group_chests[group]) {
            unlocked_stage = std::max(unlocked_stage, std::min(250, (group + 2) * 10));
        }
    }
    unlocked_stage = std::clamp(unlocked_stage, 10, 250);
    coins = std::max(0, coins);
    selected_skin = std::clamp(selected_skin, 0, static_cast<int32_t>(owned_skins.size()) - 1);
    selected_effect = std::clamp(selected_effect, 0, static_cast<int32_t>(owned_effects.size()) - 1);
    owned_skins[0] = true;
    owned_effects[0] = true;
    if (selected_skin > 0) {
        // Old saves only stored the equipped skin; treat it as owned during migration.
        owned_skins[selected_skin] = true;
    }
}

bool RazorPathGame::save_progress() {
    Ref<ConfigFile> config;
    config.instantiate();
    config->set_value("progress", "unlocked_stage", unlocked_stage);
    config->set_value("progress", "coins", coins);
    Dictionary saved_levels;
    for (const auto &entry : level_progress) {
        Dictionary record;
        record["completed"] = entry.second.completed;
        record["star_mask"] = static_cast<int32_t>(entry.second.star_mask);
        record["best_time"] = entry.second.best_time;
        saved_levels[String::num_int64(entry.first)] = record;
    }
    config->set_value("progress", "level_progress", saved_levels);
    Array saved_chests;
    for (int32_t i = 0; i < static_cast<int32_t>(claimed_group_chests.size()); ++i) {
        if (claimed_group_chests[i]) {
            saved_chests.push_back(i + 1);
        }
    }
    config->set_value("progress", "claimed_group_chests", saved_chests);
    Array saved_achievements;
    for (int32_t i = 0; i < static_cast<int32_t>(claimed_achievements.size()); ++i) {
        if (claimed_achievements[i]) {
            saved_achievements.push_back(i);
        }
    }
    config->set_value("progress", "claimed_achievements", saved_achievements);
    config->set_value("appearance", "skin", selected_skin);
    Array saved_skins;
    for (int32_t i = 0; i < static_cast<int32_t>(owned_skins.size()); ++i) {
        if (owned_skins[i]) {
            saved_skins.push_back(i);
        }
    }
    config->set_value("appearance", "owned_skins", saved_skins);
    config->set_value("effects", "equipped", selected_effect);
    Array saved_effects;
    for (int32_t i = 0; i < static_cast<int32_t>(owned_effects.size()); ++i) {
        if (owned_effects[i]) {
            saved_effects.push_back(i);
        }
    }
    config->set_value("effects", "owned", saved_effects);
    config->set_value("settings", "muted", muted);
    config->set_value("settings", "reduced_motion", reduced_motion);
    config->set_value("settings", "large_text", large_text);
    config->set_value("stats", "deaths", deaths);
    config->set_value("stats", "coins_earned", coins_earned);
    config->set_value("stats", "total_jumps", total_jumps);
    config->set_value("stats", "play_seconds", play_seconds_total);
    config->set_value("gifts", "daily_last_claim", daily_last_claim);
    config->set_value("gifts", "last_seen_utc", std::max(last_seen_utc, utc_now()));
    const Error result = config->save("user://razor_path_save.cfg");
    if (result != OK) {
        UtilityFunctions::push_warning("Razor Path: could not save progress.");
        return false;
    }
    return true;
}

int64_t RazorPathGame::utc_now() const {
    Time *clock = Time::get_singleton();
    return clock == nullptr ? 0 : static_cast<int64_t>(clock->get_unix_time_from_system());
}

bool RazorPathGame::purchase_skin(int32_t skin_index) {
    static const std::array<int32_t, 9> prices = {0, 800, 750, 600, 700, 700, 900, 1000, 950};
    if (skin_index <= 0 || skin_index >= static_cast<int32_t>(owned_skins.size()) || owned_skins[skin_index]) {
        return false;
    }
    const int32_t price = prices[skin_index];
    if (coins < price) {
        return false;
    }
    // The balance and ownership are persisted together before the UI reports success.
    const int32_t previous_coins = coins;
    coins -= price;
    owned_skins[skin_index] = true;
    if (!save_progress()) {
        coins = previous_coins;
        owned_skins[skin_index] = false;
        ui_notice = ui("تعذر حفظ الشراء على الجهاز؛ لم تُخصم العملات.");
        return false;
    }
    return true;
}

bool RazorPathGame::claim_daily_gift(int64_t now_utc) {
    if (now_utc <= 0 || (daily_last_claim > 0 && (now_utc < daily_last_claim || now_utc - daily_last_claim < 86400))) {
        return false;
    }
    const int64_t previous_claim = daily_last_claim;
    const int32_t previous_coins = coins;
    const int32_t previous_coins_earned = coins_earned;
    daily_last_claim = now_utc;
    coins += 100;
    coins_earned += 100;
    if (!save_progress()) {
        daily_last_claim = previous_claim;
        coins = previous_coins;
        coins_earned = previous_coins_earned;
        ui_notice = ui("تعذر حفظ الهدية؛ لم تُضف العملات.");
        return false;
    }
    return true;
}

void RazorPathGame::check_group_chest(int32_t group_index) {
    if (group_index < 1 || group_index > static_cast<int32_t>(claimed_group_chests.size()) || claimed_group_chests[group_index - 1]) {
        return;
    }
    const int32_t first = (group_index - 1) * 10 + 1;
    const int32_t last = std::min(250, group_index * 10);
    for (int32_t index = first; index <= last; ++index) {
        const auto progress = level_progress.find(index);
        if (progress == level_progress.end() || !progress->second.completed) {
            return;
        }
    }
    claimed_group_chests[group_index - 1] = true;
    coins += 100;
    coins_earned += 100;
    if (toast_label != nullptr) {
        toast_label->set_text(ui("صندوق المجموعة: +100 عملة"));
        toast_time = 2.5;
    }
}

int32_t RazorPathGame::total_stars() const {
    int32_t total = 0;
    for (const auto &entry : level_progress) {
        for (int32_t bit = 0; bit < 3; ++bit) {
            if ((entry.second.star_mask & static_cast<uint8_t>(1u << bit)) != 0) {
                ++total;
            }
        }
    }
    return total;
}

int32_t RazorPathGame::completed_stages() const {
    int32_t total = 0;
    for (const auto &entry : level_progress) {
        if (entry.second.completed) {
            ++total;
        }
    }
    return total;
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
        if (index >= 1 && index <= 250) {
            authored_stages[index] = parse_stage(record);
        }
    }
}

bool RazorPathGame::load_campaign_stages() {
    Ref<FileAccess> file = FileAccess::open("res://data/stages/razor_path_250.json", FileAccess::READ);
    if (file.is_null()) {
        UtilityFunctions::push_warning("Razor Path: 250-level data is missing; authored stages and fallback generation will be used.");
        return false;
    }
    Ref<JSON> json;
    json.instantiate();
    const Error parse_error = json->parse(file->get_as_text());
    if (parse_error != OK || json->get_data().get_type() != Variant::DICTIONARY) {
        UtilityFunctions::push_warning("Razor Path: 250-level JSON could not be parsed.");
        return false;
    }
    const Dictionary root = json->get_data();
    const Array records = root.get("levels", Array());
    if (records.size() != 250) {
        UtilityFunctions::push_warning("Razor Path: expected exactly 250 generated levels.");
        return false;
    }
    for (int32_t i = 0; i < records.size(); ++i) {
        if (records[i].get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary record = records[i];
        const int32_t index = static_cast<int32_t>(record.get("n", 0));
        if (index < 1 || index > 250) {
            continue;
        }
        const StageData generated = parse_campaign_stage(record);
        if (generated.index == 1 || generated.index == 16) {
            // Preserve the two authored levels already shipped in the project.
            continue;
        }
        authored_stages[index] = generated;
    }
    return true;
}

RazorPathGame::StageData RazorPathGame::parse_stage(const Dictionary &record) const {
    StageData parsed;
    parsed.index = static_cast<int32_t>(record.get("index", 1));
    parsed.group = std::clamp(static_cast<int32_t>(record.get("group", (parsed.index - 1) / 10 + 1)), 1, 25);
    parsed.name = record.get("name", ui("الطريق الأول"));
    parsed.world_width = static_cast<double>(record.get("world_width", 3600.0));
    parsed.world_height = 720.0;
    parsed.required_coins = static_cast<double>(record.get("required_coins", 0));
    parsed.spawn = point_from_array(record.get("spawn", Array()), Vector2(130.0, 590.0));
    parsed.exit = point_from_array(record.get("exit", Array()), Vector2(parsed.world_width - 120.0, 590.0));
    const String palette = record.get("palette", String("warm"));
    parsed.monochrome = palette == "monochrome";

    const Array platforms_data = record.get("platforms", Array());
    for (int32_t i = 0; i < platforms_data.size(); ++i) {
        const Array values = platforms_data[i];
        if (values.size() >= 4) {
            RazorPlatformData platform;
            platform.bounds = Rect2(
                Vector2(static_cast<double>(values[0]), static_cast<double>(values[1])),
                Vector2(static_cast<double>(values[2]), static_cast<double>(values[3])));
            platform.motion_start = platform.bounds.position;
            platform.motion_end = platform.bounds.position;
            parsed.platforms.push_back(platform);
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
        RazorPlatformData platform;
        platform.bounds = Rect2(Vector2(0.0, 620.0), Vector2(parsed.world_width, 100.0));
        platform.motion_start = platform.bounds.position;
        platform.motion_end = platform.bounds.position;
        parsed.platforms.push_back(platform);
    }
    return parsed;
}

RazorPathGame::StageData RazorPathGame::parse_campaign_stage(const Dictionary &record) const {
    constexpr double tile = 64.0;
    StageData parsed;
    parsed.index = static_cast<int32_t>(record.get("n", 1));
    parsed.name = record.get("name", ui("الممر"));
    parsed.group = static_cast<int32_t>(record.get("group", 1));
    const double tiles_wide = static_cast<double>(record.get("W", 240.0));
    const double tiles_high = static_cast<double>(record.get("H", 18.0));
    parsed.world_width = tiles_wide * tile;
    parsed.world_height = tiles_high * tile;
    parsed.tile_campaign = true;
    parsed.required_coins = 0.0;

    const Array surfaces = record.get("surfaces", Array());
    double start_surface_y = 3.0;
    double finish_surface_y = 3.0;
    const double start_x_tiles = static_cast<double>(record.get("start", 3.0));
    const double finish_x_tiles = static_cast<double>(record.get("finish", tiles_wide - 3.0));
    bool found_start = false;
    for (int32_t i = 0; i < surfaces.size(); ++i) {
        if (surfaces[i].get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary surface = surfaces[i];
        const String kind = surface.get("t", String("g"));
        const double x = static_cast<double>(surface.get("x", 0.0));
        const double y = static_cast<double>(surface.get("y", 3.0));
        const double width = static_cast<double>(surface.get("w", 2.0));
        RazorPlatformData platform;
        const double height = kind == "b" ? 0.4 * tile : (kind == "v" ? 1.2 * tile : (y <= 4.0 ? y * tile : 1.2 * tile));
        platform.bounds = Rect2(Vector2(x * tile, (tiles_high - y) * tile), Vector2(width * tile, height));
        platform.bridge = kind == "b";
        platform.ladder_top = static_cast<bool>(surface.get("lad", false));
        platform.motion_start = platform.bounds.position;
        platform.motion_end = platform.bounds.position;
        if (kind == "m") {
            platform.moving = true;
            platform.speed = static_cast<double>(surface.get("sp", 1.0)) * tile;
            platform.motion_start.x = x * tile;
            platform.motion_end.x = static_cast<double>(surface.get("x1", x)) * tile;
        } else if (kind == "v") {
            platform.moving = true;
            platform.vertical = true;
            platform.speed = static_cast<double>(surface.get("sp", 1.0)) * tile;
            platform.motion_start.y = (tiles_high - static_cast<double>(surface.get("y0", y))) * tile;
            platform.motion_end.y = (tiles_high - static_cast<double>(surface.get("y1", y))) * tile;
            platform.bounds.position.y = platform.motion_start.y;
        }
        parsed.platforms.push_back(platform);
        if (start_x_tiles >= x && start_x_tiles <= x + width && !found_start) {
            start_surface_y = y;
            found_start = true;
        }
        if (finish_x_tiles >= x && finish_x_tiles <= x + width && !platform.moving) {
            finish_surface_y = y;
        }
    }
    parsed.spawn = Vector2(start_x_tiles * tile, (tiles_high - start_surface_y) * tile);
    parsed.exit = Vector2(finish_x_tiles * tile, (tiles_high - finish_surface_y) * tile);

    const Array spikes = record.get("spikes", Array());
    for (int32_t i = 0; i < spikes.size(); ++i) {
        const Array values = spikes[i];
        if (values.size() < 3) {
            continue;
        }
        const double x = static_cast<double>(values[0]) * tile;
        const double y = (tiles_high - static_cast<double>(values[1])) * tile;
        const double width = static_cast<double>(values[2]) * tile;
        parsed.hazards.emplace_back(Vector2(x, y - 0.7 * tile), Vector2(width, 0.7 * tile));
    }

    const Array saws = record.get("saws", Array());
    for (int32_t i = 0; i < saws.size(); ++i) {
        const Array values = saws[i];
        if (values.size() >= 4) {
            parsed.saws.push_back(RazorSawData{
                static_cast<double>(values[0]) * tile,
                static_cast<double>(values[1]) * tile,
                (tiles_high - static_cast<double>(values[2])) * tile,
                static_cast<double>(values[3]) * tile});
        }
    }

    const Array ceilings = record.get("ceilings", Array());
    for (int32_t i = 0; i < ceilings.size(); ++i) {
        const Array values = ceilings[i];
        if (values.size() >= 3) {
            const double bottom = (tiles_high - static_cast<double>(values[2])) * tile;
            parsed.ceilings.emplace_back(
                Vector2(static_cast<double>(values[0]) * tile, 0.0),
                Vector2(static_cast<double>(values[1]) * tile, bottom));
        }
    }

    const Array ladders = record.get("ladders", Array());
    for (int32_t i = 0; i < ladders.size(); ++i) {
        const Array values = ladders[i];
        if (values.size() >= 3) {
            parsed.ladders.push_back(RazorLadderData{
                static_cast<double>(values[0]) * tile,
                (tiles_high - static_cast<double>(values[2])) * tile,
                (tiles_high - static_cast<double>(values[1])) * tile});
        }
    }

    const Array checkpoints = record.get("checkpoints", Array());
    for (int32_t i = 0; i < checkpoints.size(); ++i) {
        const double x = static_cast<double>(checkpoints[i]);
        double y = start_surface_y;
        for (int32_t s = 0; s < surfaces.size(); ++s) {
            if (surfaces[s].get_type() != Variant::DICTIONARY) {
                continue;
            }
            const Dictionary surface = surfaces[s];
            const String kind = surface.get("t", String("g"));
            const double sx = static_cast<double>(surface.get("x", 0.0));
            const double width = static_cast<double>(surface.get("w", 0.0));
            if ((kind == "g" || kind == "b") && x >= sx && x <= sx + width) {
                y = static_cast<double>(surface.get("y", y));
                break;
            }
        }
        parsed.checkpoints.push_back(RazorCheckpointData{Vector2(x * tile, (tiles_high - y) * tile), false});
    }

    const Array stars = record.get("stars", Array());
    for (int32_t i = 0; i < stars.size(); ++i) {
        const Array values = stars[i];
        if (values.size() >= 2) {
            parsed.stars.push_back(RazorStarData{
                Vector2(static_cast<double>(values[0]) * tile, (tiles_high - static_cast<double>(values[1])) * tile), false});
        }
    }
    return parsed;
}

Rect2 RazorPathGame::current_platform_rect(const RazorPlatformData &platform, double time) const {
    Rect2 bounds = platform.bounds;
    if (!platform.moving) {
        return bounds;
    }
    if (platform.vertical) {
        bounds.position.y = motion_position(platform.motion_start.y, platform.motion_end.y, platform.speed, time);
    } else {
        bounds.position.x = motion_position(platform.motion_start.x, platform.motion_end.x, platform.speed, time);
    }
    return bounds;
}

RazorPathGame::StageData RazorPathGame::make_generated_stage(int32_t requested_index) const {
    StageData generated;
    generated.index = requested_index;
    generated.name = ui("مسار الظلال ") + String::num_int64(requested_index);
    generated.world_width = 3200.0 + requested_index * 120.0;
    generated.required_coins = requested_index >= 2 ? 2.0 + (requested_index % 4) : 0.0;
    generated.spawn = Vector2(120.0, 590.0);
    generated.exit = Vector2(generated.world_width - 130.0, 590.0);
    generated.monochrome = false;
    RazorPlatformData ground;
    ground.bounds = Rect2(Vector2(0.0, 620.0), Vector2(720.0, 100.0));
    generated.platforms.push_back(ground);
    for (int32_t i = 0; i < 6; ++i) {
        const double x = 560.0 + i * (generated.world_width - 900.0) / 6.0;
        const double y = 510.0 - ((i + requested_index) % 3) * 58.0;
        const double width = 260.0 + ((i + requested_index) % 2) * 55.0;
        RazorPlatformData platform;
        platform.bounds = Rect2(Vector2(x, y), Vector2(width, 30.0));
        generated.platforms.push_back(platform);
        generated.coins.emplace_back(Vector2(x + width * 0.5, y - 52.0));
        if ((i + requested_index) % 3 == 1) {
            generated.hazards.emplace_back(Vector2(x + width * 0.55, y - 36.0), Vector2(48.0, 36.0));
        }
    }
    RazorPlatformData end_ground;
    end_ground.bounds = Rect2(Vector2(generated.world_width - 430.0, 620.0), Vector2(430.0, 100.0));
    generated.platforms.push_back(end_ground);
    return generated;
}

bool RazorPathGame::load_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > 250) {
        return false;
    }
    const auto authored = authored_stages.find(requested_index);
    stage = authored != authored_stages.end() ? authored->second : make_generated_stage(requested_index);
    if (stage.stars.empty()) {
        for (int32_t i = 0; i < 3; ++i) {
            Vector2 position;
            if (!stage.coins.empty()) {
                const size_t coin_index = static_cast<size_t>(i) * (stage.coins.size() - 1) / 2;
                position = stage.coins[coin_index];
            } else {
                const RazorPlatformData &platform = stage.platforms[std::min<size_t>(i, stage.platforms.size() - 1)];
                position = Vector2(platform.bounds.position.x + platform.bounds.size.x * 0.5, platform.bounds.position.y - 84.0);
            }
            stage.stars.push_back(RazorStarData{position, false});
        }
    }
    if (stage.checkpoints.empty()) {
        const double target = stage.world_width * 0.58;
        const RazorPlatformData *chosen = nullptr;
        double nearest = std::numeric_limits<double>::max();
        for (const RazorPlatformData &platform : stage.platforms) {
            if (platform.moving) {
                continue;
            }
            const double distance = target < platform.bounds.position.x ? platform.bounds.position.x - target :
                (target > platform.bounds.position.x + platform.bounds.size.x ? target - platform.bounds.position.x - platform.bounds.size.x : 0.0);
            if (distance < nearest) {
                nearest = distance;
                chosen = &platform;
            }
        }
        if (chosen != nullptr) {
            const double x = std::clamp(target, chosen->bounds.position.x + 64.0,
                chosen->bounds.position.x + std::max(64.0, chosen->bounds.size.x - 64.0));
            stage.checkpoints.push_back(RazorCheckpointData{Vector2(x, chosen->bounds.position.y), false});
        }
    }
    stage_index = requested_index;
    player_x = stage.spawn.x;
    player_feet = stage.spawn.y;
    player_vy = 0.0;
    camera_x = 0.0;
    camera_y = 0.0;
    stage_elapsed = 0.0;
    run_elapsed = 0.0;
    stage_coins = 0;
    remaining_time = 180.0;
    on_ground = false;
    run_finalized = false;
    jump_requested = false;
    attack_requested = false;
    landing_time = 0.0;
    std::fill(std::begin(stage_coin_collected), std::end(stage_coin_collected), false);
    const auto saved = level_progress.find(requested_index);
    for (size_t i = 0; i < stage.stars.size(); ++i) {
        const uint8_t mask = saved == level_progress.end() ? 0 : saved->second.star_mask;
        stage.stars[i].collected = i < 3 && (mask & static_cast<uint8_t>(1u << i)) != 0;
    }
    for (RazorCheckpointData &checkpoint : stage.checkpoints) {
        checkpoint.activated = false;
    }
    checkpoint_x = stage.spawn.x;
    checkpoint_feet = stage.spawn.y;
    return true;
}

void RazorPathGame::start_new_run() {
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
    RazorLevelProgress &progress = level_progress[stage_index];
    const bool first_completion = !progress.completed;
    progress.completed = true;
    if (progress.best_time <= 0.0 || run_elapsed < progress.best_time) {
        progress.best_time = run_elapsed;
    }
    if (first_completion) {
        coins += 10;
        coins_earned += 10;
    }
    if (stage_index < 250) {
        screen = RazorScreen::STAGE_CLEAR;
    } else {
        unlocked_stage = 250;
        screen = RazorScreen::VICTORY;
    }
    check_group_chest(stage.group);
    if (stage.group > 0 && stage.group <= static_cast<int32_t>(claimed_group_chests.size()) && claimed_group_chests[stage.group - 1]) {
        unlocked_stage = std::max(unlocked_stage, std::min(250, (stage.group + 1) * 10));
    }
    if (!save_progress()) {
        ui_notice = ui("تعذر حفظ تقدم الجولة على الجهاز؛ أبقِ التطبيق مفتوحًا وحاول الحفظ مجددًا.");
        toast_time = 3.0;
    }
    touch_actions.clear();
    rebuild_ui();
    queue_redraw();
}

void RazorPathGame::fail_run() {
    if (run_finalized) {
        return;
    }
    run_finalized = true;
    if (!save_progress()) {
        ui_notice = ui("تعذر حفظ التقدم على الجهاز.");
        toast_time = 3.0;
    }
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
        if (selected_effect == 1) {
            p.color = rgba8(0xe3b84d);
        } else if (selected_effect == 2) {
            p.color = rgba8(0x63c8cf);
        } else if (selected_effect == 3) {
            p.color = rgba8(0x9a83b5);
        }
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
    if (toast_time <= 0.0 && toast_label != nullptr) {
        toast_label->set_text(String());
        ui_notice = String();
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
    const int32_t frame = current_hero_frame();
    if (frame >= 0 && frame < static_cast<int32_t>(hero_frames.size()) && hero_frames[frame].is_valid()) {
        if (hero_preview_widget != nullptr) {
            hero_preview_widget->set_texture(hero_frames[frame]);
            hero_preview_widget->set_modulate(hero_tint());
            const double gait_phase = std::fmod(animation_time * Math_TAU * 1.25, Math_TAU);
            const double bounce = (1.0 - std::cos(gait_phase * 2.0)) * 2.0;
            Vector2 preview_position = hero_preview_rect.position;
            if (screen == RazorScreen::LEVEL_SELECT) {
                preview_position.x += std::fmod(animation_time * 35.0, 188.0);
            }
            hero_preview_widget->set_position(preview_position - Vector2(0.0, bounce));
            hero_preview_widget->set_rotation(std::sin(gait_phase) * 0.018);
        }
        for (TextureRect *preview : skin_preview_widgets) {
            if (preview != nullptr) {
                preview->set_texture(hero_frames[frame]);
            }
        }
    }
    queue_redraw();
}

void RazorPathGame::_physics_process(double delta) {
    if (screen != RazorScreen::PLAYING) {
        return;
    }
    stage_elapsed += delta;
    run_elapsed += delta;
    play_seconds_total += delta;
    remaining_time = std::max(0.0, remaining_time - delta);
    if (remaining_time <= 0.0) {
        fail_run();
        return;
    }

    Input *input = Input::get_singleton();
    bool left = input->is_key_pressed(Key::KEY_A) || input->is_key_pressed(Key::KEY_LEFT);
    bool right = input->is_key_pressed(Key::KEY_D) || input->is_key_pressed(Key::KEY_RIGHT);
    const bool climb_up_key = input->is_key_pressed(Key::KEY_W) || input->is_key_pressed(Key::KEY_UP);
    const bool climb_down_key = input->is_key_pressed(Key::KEY_S) || input->is_key_pressed(Key::KEY_DOWN);
    bool attack = attack_requested || input->is_key_pressed(Key::KEY_J) || input->is_key_pressed(Key::KEY_X);
    bool climb_up_touch = false;
    for (const auto &entry : touch_actions) {
        left = left || entry.second == TouchAction::LEFT;
        right = right || entry.second == TouchAction::RIGHT;
        climb_up_touch = climb_up_touch || entry.second == TouchAction::JUMP;
    }
    const bool climb_up = climb_up_key || climb_up_touch;
    const bool climb_down = climb_down_key;

    const double axis = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    if (on_ground) {
        for (const RazorPlatformData &platform : stage.platforms) {
            if (!platform.moving) {
                continue;
            }
            const Rect2 previous = current_platform_rect(platform, std::max(0.0, stage_elapsed - delta));
            const Rect2 current = current_platform_rect(platform, stage_elapsed);
            if (player_x + 18.0 > previous.position.x && player_x - 18.0 < previous.position.x + previous.size.x &&
                std::abs(player_feet - previous.position.y) < 5.0) {
                player_x += current.position.x - previous.position.x;
                player_feet += current.position.y - previous.position.y;
                break;
            }
        }
    }
    player_x = std::clamp(player_x + axis * 360.0 * delta, 18.0, stage.world_width - 18.0);

    bool climbing = false;
    bool ladder_top_landed = false;
    const Rect2 before_climb = player_body_rect();
    for (const RazorLadderData &ladder : stage.ladders) {
        const Rect2 ladder_rect(Vector2(ladder.x - 19.0, ladder.y0), Vector2(38.0, ladder.y1 - ladder.y0));
        if (before_climb.intersects(ladder_rect) && (climb_up || climb_down)) {
            player_x = ladder.x;
            player_vy = 0.0;
            if (climb_up) {
                player_feet = std::max(ladder.y0 + 118.0, player_feet - 256.0 * delta);
                climbing = player_feet > ladder.y0 + 118.0;
                if (!climbing) {
                    player_feet = ladder.y0;
                    ladder_top_landed = true;
                }
            } else {
                player_feet = std::min(ladder.y1, player_feet + 256.0 * delta);
                climbing = player_feet < ladder.y1;
            }
            break;
        }
    }
    if (jump_requested && on_ground && !climbing) {
        player_vy = -700.0;
        on_ground = false;
        total_jumps += 1;
        spawn_particles(Vector2(player_x, player_feet - 4.0), stage.monochrome ? rgba8(0x111111) : rgba8(0x685e49), 8, 95.0);
    }
    if (attack && attack_cooldown <= 0.0) {
        attack_time = 0.28;
        attack_cooldown = 0.45;
        const double dir = axis < 0.0 ? -1.0 : 1.0;
        const Rect2 strike(Vector2(player_x + dir * 18.0 - 24.0, player_feet - 112.0), Vector2(68.0, 82.0));
        for (Rect2 &hazard : stage.hazards) {
            if (strike.intersects(hazard)) {
                const Vector2 hazard_center = hazard.position + hazard.size * 0.5;
                hazard.position.x = -100000.0;
                spawn_particles(hazard_center, stage.monochrome ? rgba8(0x222222) : rgba8(0xe7b84b), 10, 130.0);
            }
        }
    }
    jump_requested = false;
    attack_requested = false;

    const double old_feet = player_feet;
    if (!climbing) {
        player_vy += 1850.0 * delta;
        player_feet += player_vy * delta;
    }
    if (player_vy < 0.0) {
        const double old_head = old_feet - 118.0;
        const double new_head = player_feet - 118.0;
        for (const Rect2 &ceiling : stage.ceilings) {
            const double underside = ceiling.position.y + ceiling.size.y;
            const bool overlaps_x = player_x + 18.0 > ceiling.position.x && player_x - 18.0 < ceiling.position.x + ceiling.size.x;
            if (overlaps_x && old_head >= underside && new_head < underside) {
                player_feet = underside + 118.0;
                player_vy = 0.0;
                break;
            }
        }
    }
    const bool was_on_ground = on_ground;
    on_ground = climbing || ladder_top_landed;
    if (!climbing && !ladder_top_landed) {
        for (const RazorPlatformData &data : stage.platforms) {
            const Rect2 platform = current_platform_rect(data, stage_elapsed);
            const bool overlaps_x = player_x + 18.0 > platform.position.x && player_x - 18.0 < platform.position.x + platform.size.x;
            const bool crossed_top = old_feet <= platform.position.y + 4.0 && player_feet >= platform.position.y;
            if (overlaps_x && crossed_top && player_vy >= 0.0) {
                player_feet = platform.position.y;
                player_vy = 0.0;
                on_ground = true;
            }
        }
    }
    if (on_ground && !was_on_ground && !climbing) {
        landing_time = 0.14;
        spawn_particles(Vector2(player_x, player_feet - 2.0), stage.monochrome ? rgba8(0x444444) : rgba8(0x625c4f), 5, 55.0);
    }

    auto respawn = [&]() {
        ++deaths;
        remaining_time = std::max(0.0, remaining_time - 10.0);
        player_x = checkpoint_x;
        player_feet = checkpoint_feet;
        player_vy = 0.0;
        on_ground = false;
        stage_elapsed = 0.0;
        camera_x = std::clamp(player_x - logical_size().x * 0.38, 0.0, std::max(0.0, stage.world_width - logical_size().x));
        camera_y = std::clamp(player_feet - logical_size().y * 0.64, 0.0, std::max(0.0, stage.world_height - logical_size().y));
        spawn_particles(Vector2(player_x, player_feet - 30.0), stage.monochrome ? rgba8(0x555555) : rgba8(0x744b42), 14, 100.0);
        save_progress();
    };
    Rect2 body = player_body_rect();
    bool hit = false;
    for (const Rect2 &hazard : stage.hazards) {
        if (hazard.position.x > -500.0 && body.intersects(hazard)) {
            hit = true;
            break;
        }
    }
    for (const RazorSawData &saw : stage.saws) {
        const double center_x = motion_position(saw.x0, saw.x1, saw.speed, stage_elapsed);
        const Rect2 saw_bounds(Vector2(center_x - 32.0, saw.y - 32.0), Vector2(64.0, 64.0));
        if (body.intersects(saw_bounds)) {
            hit = true;
            break;
        }
    }
    if (hit) {
        respawn();
        return;
    }
    if (player_feet > stage.world_height + 96.0) {
        respawn();
        return;
    }

    for (RazorCheckpointData &checkpoint : stage.checkpoints) {
        if (std::abs(player_x - checkpoint.position.x) < 64.0 && std::abs(player_feet - checkpoint.position.y) < 160.0) {
            checkpoint_x = checkpoint.position.x;
            checkpoint_feet = checkpoint.position.y;
            checkpoint.activated = true;
        }
    }

    body = player_body_rect();
    for (size_t i = 0; i < stage.stars.size() && i < 3; ++i) {
        RazorStarData &star = stage.stars[i];
        if (!star.collected && body.grow(24.0).has_point(star.position)) {
            star.collected = true;
            RazorLevelProgress &progress = level_progress[stage_index];
            const uint8_t bit = static_cast<uint8_t>(1u << i);
            if ((progress.star_mask & bit) == 0) {
                progress.star_mask |= bit;
                coins += 5;
                coins_earned += 5;
            }
            spawn_particles(star.position, rgba8(0xd5a749), 10, 100.0);
            save_progress();
        }
    }
    for (size_t i = 0; i < stage.coins.size() && i < 256; ++i) {
        if (!stage_coin_collected[i] && body.grow(7.0).has_point(stage.coins[i])) {
            stage_coin_collected[i] = true;
            ++stage_coins;
            ++coins;
            ++coins_earned;
            spawn_particles(stage.coins[i], stage.monochrome ? rgba8(0x222222) : rgba8(0xd5a749), 12, 105.0);
            save_progress();
        }
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
    const double view_height = logical_size().y;
    const double max_camera_y = std::max(0.0, stage.world_height - view_height);
    const double target_camera_y = std::clamp(player_feet - view_height * 0.64, 0.0, max_camera_y);
    camera_y += (target_camera_y - camera_y) * std::min(1.0, 8.0 * delta);
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
    if (selected_skin == 3) {
        return Color(0.31, 0.34, 0.36, 1.0);
    }
    if (selected_skin == 4) {
        return Color(1.0, 0.52, 0.32, 1.0);
    }
    if (selected_skin == 5) {
        return Color(0.60, 0.83, 1.0, 1.0);
    }
    if (selected_skin == 6) {
        return Color(0.83, 0.90, 0.94, 0.88);
    }
    if (selected_skin == 7) {
        return Color(0.39, 0.86, 0.84, 1.0);
    }
    if (selected_skin == 8) {
        return Color(0.43, 0.36, 0.50, 1.0);
    }
    return Color(1.0, 1.0, 1.0, 1.0);
}

Rect2 RazorPathGame::player_body_rect() const {
    return Rect2(Vector2(player_x - 18.0, player_feet - 118.0), Vector2(36.0, 118.0));
}

int32_t RazorPathGame::current_hero_frame() const {
    const int64_t animation_tick = static_cast<int64_t>(std::floor(animation_time * kHeroAnimationFps));
    const int64_t pose_tick = animation_tick / 3;
    // The supplied 4x2 sheet has two alternating run poses, then landing/jump,
    // two attack poses, idle, and a final profile run pose.
    static constexpr std::array<int32_t, 2> run_cycle = {0, 1};
    const bool menu_preview = screen == RazorScreen::HOME || screen == RazorScreen::LEVEL_SELECT || screen == RazorScreen::SHOP;
    if (menu_preview) {
        return run_cycle[static_cast<size_t>(pose_tick % static_cast<int64_t>(run_cycle.size()))];
    }
    if (screen == RazorScreen::VICTORY || screen == RazorScreen::STAGE_CLEAR) {
        return 6;
    }
    if (attack_time > 0.0) {
        return (pose_tick % 2 == 0) ? 4 : 5;
    }
    if (!on_ground) {
        return player_vy < -70.0 ? 3 : 2;
    }
    if (landing_time > 0.0) {
        return 2;
    }
    if (horizontal_input_active()) {
        return run_cycle[static_cast<size_t>(pose_tick % static_cast<int64_t>(run_cycle.size()))];
    }
    return 6;
}

bool RazorPathGame::horizontal_input_active() const {
    const Input *input = Input::get_singleton();
    if (input != nullptr && (input->is_key_pressed(Key::KEY_A) || input->is_key_pressed(Key::KEY_D) ||
        input->is_key_pressed(Key::KEY_LEFT) || input->is_key_pressed(Key::KEY_RIGHT))) {
        return true;
    }
    for (const auto &entry : touch_actions) {
        if (entry.second == TouchAction::LEFT || entry.second == TouchAction::RIGHT) {
            return true;
        }
    }
    return false;
}

int32_t RazorPathGame::test_animation_frame_at(double animation_seconds) {
    const double old_time = animation_time;
    const RazorScreen old_screen = screen;
    animation_time = std::max(0.0, animation_seconds);
    screen = RazorScreen::SHOP;
    const int32_t frame = current_hero_frame();
    animation_time = old_time;
    screen = old_screen;
    return frame;
}

void RazorPathGame::_draw() {
    const Vector2 size = logical_size();
    const bool illustrated_menu = screen == RazorScreen::HOME || screen == RazorScreen::LEVEL_SELECT || screen == RazorScreen::SHOP;
    if (illustrated_menu && menu_background.is_valid()) {
        draw_texture_rect(menu_background, Rect2(Vector2(), size), false);
        draw_rect(Rect2(Vector2(), size), Color(0.30, 0.19, 0.12, 0.14), true);
    } else {
        draw_rect(Rect2(Vector2(), size), background_color(), true);
    }

    if (!illustrated_menu) {
    // Layered warm/monochrome silhouettes echo the supplied world references.
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
    const double camera_vertical = showing_world ? camera_y : 0.0;
    const Color platform = platform_color();
    for (const RazorPlatformData &platform_data : stage.platforms) {
        const Rect2 platform_rect = current_platform_rect(platform_data, stage_elapsed);
        const Rect2 visible(Vector2((platform_rect.position.x - camera) * scale_x, (platform_rect.position.y - camera_vertical) * scale_y),
            Vector2(platform_rect.size.x * scale_x, std::max(7.0, platform_rect.size.y * scale_y)));
        if (visible.position.x < size.x && visible.position.x + visible.size.x > 0.0) {
            draw_rect(visible, platform, true);
            draw_rect(Rect2(visible.position, Vector2(visible.size.x, 4.0 * scale_y)), stage.monochrome ? rgba8(0x111111) : rgba8(0x171614), true);
        }
    }

    // Foreground landmarks: small ladders, sparse grass and a blocky exit gate.
    for (const Rect2 &ceiling : stage.ceilings) {
        const Rect2 visible(Vector2((ceiling.position.x - camera) * scale_x, (ceiling.position.y - camera_vertical) * scale_y),
            Vector2(ceiling.size.x * scale_x, ceiling.size.y * scale_y));
        if (visible.position.x < size.x && visible.position.x + visible.size.x > 0.0) {
            draw_rect(visible, platform, true);
        }
    }
    for (const RazorLadderData &ladder : stage.ladders) {
        const double x = (ladder.x - camera) * scale_x;
        const double top = (ladder.y0 - camera_vertical) * scale_y;
        const double bottom = (ladder.y1 - camera_vertical) * scale_y;
        if (x > -40.0 && x < size.x + 40.0) {
            const Color rung = stage.monochrome ? rgba8(0x080808) : rgba8(0x171614);
            draw_line(Vector2(x - 16.0 * scale_x, top), Vector2(x - 16.0 * scale_x, bottom), rung, 4.0 * scale_x);
            draw_line(Vector2(x + 16.0 * scale_x, top), Vector2(x + 16.0 * scale_x, bottom), rung, 4.0 * scale_x);
            for (double y = top + 18.0 * scale_y; y < bottom; y += 28.0 * scale_y) {
                draw_line(Vector2(x - 16.0 * scale_x, y), Vector2(x + 16.0 * scale_x, y), rung, 3.0 * scale_x);
            }
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
        const Vector2 center((stage.coins[i].x - camera) * scale_x, (stage.coins[i].y - camera_vertical) * scale_y);
        if (center.x > -24.0 && center.x < size.x + 24.0) {
            draw_circle(center, 12.0 * scale_x, stage.monochrome ? rgba8(0x222222) : rgba8(0xd8ab42));
            draw_circle(center, 6.0 * scale_x, stage.monochrome ? rgba8(0xf5f5f5) : rgba8(0xf4df9b));
        }
    }

    for (const Rect2 &hazard : stage.hazards) {
        if (hazard.position.x < -500.0) {
            continue;
        }
        const Rect2 r(Vector2((hazard.position.x - camera) * scale_x, (hazard.position.y - camera_vertical) * scale_y),
            Vector2(hazard.size.x * scale_x, hazard.size.y * scale_y));
        if (r.position.x < size.x && r.position.x + r.size.x > 0.0) {
            draw_rect(r, stage.monochrome ? rgba8(0x111111) : rgba8(0x282724), true);
            draw_circle(r.position + Vector2(r.size.x * 0.35, r.size.y * 0.43), 4.0 * scale_x, stage.monochrome ? rgba8(0xffffff) : rgba8(0x595b60));
            draw_circle(r.position + Vector2(r.size.x * 0.70, r.size.y * 0.43), 4.0 * scale_x, stage.monochrome ? rgba8(0xffffff) : rgba8(0x595b60));
        }
    }

    const Vector2 exit_pos((stage.exit.x - camera) * scale_x, (stage.exit.y - camera_vertical) * scale_y);
    if (exit_pos.x > -100.0 && exit_pos.x < size.x + 100.0) {
        const Color gate = stage.monochrome ? rgba8(0x080808) : rgba8(0x111111);
        draw_rect(Rect2(exit_pos + Vector2(-24.0 * scale_x, -150.0 * scale_y), Vector2(16.0 * scale_x, 150.0 * scale_y)), gate, true);
        draw_rect(Rect2(exit_pos + Vector2(24.0 * scale_x, -150.0 * scale_y), Vector2(16.0 * scale_x, 150.0 * scale_y)), gate, true);
        draw_rect(Rect2(exit_pos + Vector2(-24.0 * scale_x, -150.0 * scale_y), Vector2(64.0 * scale_x, 14.0 * scale_y)), gate, true);
    }

    for (const RazorSawData &saw : stage.saws) {
        const double center_x = motion_position(saw.x0, saw.x1, saw.speed, stage_elapsed);
        const Vector2 center((center_x - camera) * scale_x, (saw.y - camera_vertical) * scale_y);
        if (center.x > -60.0 && center.x < size.x + 60.0) {
            const double radius = 38.0 * scale_x;
            const Color blade = stage.monochrome ? rgba8(0x111111) : rgba8(0x24211e);
            draw_circle(center, radius, blade);
            for (int32_t tooth = 0; tooth < 8; ++tooth) {
                const double angle = Math_TAU * tooth / 8.0 + animation_time * 4.0;
                draw_line(center, center + Vector2(std::cos(angle), std::sin(angle)) * radius, rgba8(0xf1e4cb), 2.0 * scale_x);
            }
            draw_circle(center, radius * 0.28, stage.monochrome ? rgba8(0xf5f5f5) : rgba8(0xc28a39));
        }
    }

    for (const RazorStarData &star : stage.stars) {
        if (star.collected) {
            continue;
        }
        const Vector2 center((star.position.x - camera) * scale_x, (star.position.y - camera_vertical) * scale_y);
        if (center.x < -24.0 || center.x > size.x + 24.0) {
            continue;
        }
        PackedVector2Array points;
        for (int32_t point = 0; point < 10; ++point) {
            const double angle = -Math_PI * 0.5 + point * Math_PI / 5.0;
            const double radius = (point % 2 == 0 ? 15.0 : 7.0) * scale_x;
            points.push_back(center + Vector2(std::cos(angle), std::sin(angle)) * radius);
        }
        draw_colored_polygon(points, rgba8(0xe1b449));
    }

    for (const RazorCheckpointData &checkpoint : stage.checkpoints) {
        const Vector2 base((checkpoint.position.x - camera) * scale_x, (checkpoint.position.y - camera_vertical) * scale_y);
        if (base.x > -24.0 && base.x < size.x + 24.0) {
            draw_line(base, base + Vector2(0.0, -58.0 * scale_y), platform, 3.0 * scale_x);
            PackedVector2Array flag_points;
            flag_points.push_back(base + Vector2(1.0 * scale_x, -56.0 * scale_y));
            flag_points.push_back(base + Vector2(30.0 * scale_x, -48.0 * scale_y));
            flag_points.push_back(base + Vector2(1.0 * scale_x, -39.0 * scale_y));
            draw_colored_polygon(flag_points, checkpoint.activated ? rgba8(0x41a871) : rgba8(0xc28a39));
        }
    }

    if (screen == RazorScreen::PLAYING || screen == RazorScreen::PAUSED || screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER) {
        const int32_t frame = current_hero_frame();
        const double gait_phase = std::fmod(animation_time * Math_TAU * 1.25, Math_TAU);
        const bool running = screen == RazorScreen::PLAYING && horizontal_input_active();
        const double stride = running ? std::sin(gait_phase) : 0.0;
        const double bounce = running ? (1.0 - std::cos(gait_phase * 2.0)) * 2.2 * scale_y : 0.0;
        const double sprite_width = 66.0 * scale_x * (1.0 + 0.025 * stride);
        const double sprite_height = 132.0 * world_scale_y * (1.0 - 0.018 * stride);
        const Vector2 sprite_pos((player_x - camera) * scale_x - sprite_width * 0.5,
            (player_feet - camera_vertical) * scale_y - sprite_height - bounce);
        if (hero_frames[frame].is_valid()) {
            draw_texture_rect(hero_frames[frame], Rect2(sprite_pos, Vector2(sprite_width, sprite_height)), false, hero_tint());
        } else {
            draw_circle(sprite_pos + Vector2(sprite_width * 0.5, 20.0 * scale_y), 13.0 * scale_x, rgba8(0xf5f5f5));
            draw_rect(Rect2(sprite_pos + Vector2(sprite_width * 0.36, 34.0 * scale_y), Vector2(sprite_width * 0.28, 72.0 * scale_y)), rgba8(0xf5f5f5), true);
        }
    }

    for (const Particle &particle : particles) {
        const Vector2 p((particle.position.x - camera) * scale_x, (particle.position.y - camera_vertical) * scale_y);
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
        // Direction arrows and action glyphs are geometric, avoiding font-direction ambiguity.
        draw_line(Vector2(size.x * 0.075 - 12.0, cy), Vector2(size.x * 0.075 + 10.0, cy), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.20 + 12.0, cy), Vector2(size.x * 0.20 - 10.0, cy), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.82, cy + 12.0), Vector2(size.x * 0.82, cy - 12.0), control_line, 5.0 * scale_x);
        draw_line(Vector2(size.x * 0.93 - 10.0, cy + 10.0), Vector2(size.x * 0.93 + 10.0, cy - 10.0), control_line, 5.0 * scale_x);
    }
    }

    if (screen == RazorScreen::PAUSED || screen == RazorScreen::SETTINGS || screen == RazorScreen::STATISTICS || screen == RazorScreen::GIFTS || screen == RazorScreen::ACHIEVEMENTS || screen == RazorScreen::STAGE_CLEAR || screen == RazorScreen::VICTORY || screen == RazorScreen::GAME_OVER) {
        draw_rect(Rect2(Vector2(), size), Color(0.02, 0.02, 0.02, 0.54), true);
    }
    if (show_purchase_confirm || pending_equip >= 0 || show_exit_confirm) {
        draw_rect(Rect2(Vector2(size.x * 0.20, size.y * 0.56), Vector2(size.x * 0.60, size.y * 0.32)), Color(0.08, 0.07, 0.05, 0.96), true);
        draw_rect(Rect2(Vector2(size.x * 0.20, size.y * 0.56), Vector2(size.x * 0.60, size.y * 0.32)), rgba8(0xe0bc68), false, 3.0);
    }
}

void RazorPathGame::clear_ui() {
    hud_label = nullptr;
    toast_label = nullptr;
    hero_preview_widget = nullptr;
    skin_preview_widgets.fill(nullptr);
    hero_preview_rect = Rect2();
    if (ui_root == nullptr) {
        return;
    }
    for (int32_t i = ui_root->get_child_count() - 1; i >= 0; --i) {
        Node *child = ui_root->get_child(i);
        ui_root->remove_child(child);
        child->queue_free();
    }
}

void RazorPathGame::add_panel(const Rect2 &rect, const Color &fill, const Color &border, int32_t radius, int32_t border_width) {
    if (ui_root == nullptr) {
        return;
    }
    Panel *panel = memnew(Panel);
    panel->set_position(rect.position);
    panel->set_size(rect.size);
    panel->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    Ref<StyleBoxFlat> style;
    style.instantiate();
    style->set_bg_color(fill);
    style->set_border_width_all(border_width);
    style->set_border_color(border);
    style->set_corner_radius_all(radius);
    style->set_content_margin_all(8.0);
    panel->add_theme_stylebox_override("panel", style);
    ui_root->add_child(panel);
}

TextureRect *RazorPathGame::add_texture_rect(const Ref<Texture2D> &texture, const Rect2 &rect, const Color &tint) {
    if (ui_root == nullptr || texture.is_null()) {
        return nullptr;
    }
    TextureRect *image = memnew(TextureRect);
    image->set_position(rect.position);
    image->set_size(rect.size);
    image->set_texture(texture);
    image->set_expand_mode(TextureRect::EXPAND_IGNORE_SIZE);
    image->set_stretch_mode(TextureRect::STRETCH_KEEP_ASPECT_CENTERED);
    image->set_modulate(tint);
    image->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    ui_root->add_child(image);
    return image;
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
    label->set_layout_direction(Control::LAYOUT_DIRECTION_LTR);
    label->set_text_direction(rtl ? Control::TEXT_DIRECTION_RTL : Control::TEXT_DIRECTION_AUTO);
    label->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
    if (bold && arabic_bold_font.is_valid()) {
        label->add_theme_font_override("font", arabic_bold_font);
    }
    label->add_theme_font_size_override("font_size", large_text ? static_cast<int32_t>(std::round(font_size * 1.18)) : font_size);
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
    button->set_layout_direction(Control::LAYOUT_DIRECTION_LTR);
    button->set_text_direction(Control::TEXT_DIRECTION_AUTO);
    button->set_focus_mode(Control::FOCUS_NONE);
    const bool illustrated_menu = screen == RazorScreen::HOME || screen == RazorScreen::LEVEL_SELECT || screen == RazorScreen::SHOP;
    button->add_theme_font_size_override("font_size", large_text ? 25 : (illustrated_menu ? 19 : 24));
    const bool locked_level = action.begins_with("stage:") && static_cast<int32_t>(action.substr(6).to_int()) > unlocked_stage;
    const bool selected_level_button = action.begins_with("stage:") && static_cast<int32_t>(action.substr(6).to_int()) == selected_level;
    const bool selected_tab = action.begins_with("tab:") && static_cast<int32_t>(action.substr(4).to_int()) == shop_tab;
    Color fill = (disabled || locked_level) ? rgba8(0x777777) : rgba8(0x171717);
    Color border_color = stage.monochrome ? rgba8(0x111111) : rgba8(0x766f5f);
    Color text_color = rgba8(0xfaf8f1);
    if (illustrated_menu) {
        fill = rgba8(0x38261d);
        border_color = rgba8(0x9c6d39);
        text_color = rgba8(0xfff4dd);
        if (locked_level) {
            fill = rgba8(0x746a60);
            border_color = rgba8(0x9a8a78);
            text_color = rgba8(0xd8cfc2);
        } else if (selected_level_button || selected_tab || (disabled && action.begins_with("skin:"))) {
            fill = rgba8(0xb9782f);
            border_color = rgba8(0xffd36a);
            text_color = rgba8(0x291a10);
        }
    }
    Ref<StyleBoxFlat> normal;
    normal.instantiate();
    normal->set_bg_color(fill);
    normal->set_border_width_all(illustrated_menu ? 3 : 2);
    normal->set_border_color(border_color);
    normal->set_corner_radius_all(illustrated_menu ? 16 : 12);
    normal->set_content_margin_all(illustrated_menu ? 7.0 : 10.0);
    button->add_theme_stylebox_override("normal", normal);
    button->add_theme_stylebox_override("disabled", normal);
    Ref<StyleBoxFlat> hover;
    hover.instantiate();
    hover->set_bg_color(disabled ? fill : (illustrated_menu ? rgba8(0x68462a) : (stage.monochrome ? rgba8(0x3a3a3a) : rgba8(0x474236))));
    hover->set_border_width_all(illustrated_menu ? 3 : 2);
    hover->set_border_color(illustrated_menu ? rgba8(0xffdc83) : (stage.monochrome ? rgba8(0xffffff) : rgba8(0xe2bd69)));
    hover->set_corner_radius_all(illustrated_menu ? 16 : 12);
    hover->set_content_margin_all(illustrated_menu ? 7.0 : 10.0);
    button->add_theme_stylebox_override("hover", hover);
    button->add_theme_stylebox_override("pressed", hover);
    button->add_theme_color_override("font_color", text_color);
    button->add_theme_color_override("font_hover_color", rgba8(0xffffff));
    button->add_theme_color_override("font_disabled_color", text_color);
    button->connect("pressed", Callable(this, "_on_ui_action").bind(action));
    ui_root->add_child(button);
    return button;
}

void RazorPathGame::update_hud() {
    if (hud_label != nullptr) {
        String text = ui("المرحلة ") + String::num_int64(stage_index) + ui("، العملات ") + String::num_int64(stage_coins) + ui(" من ") + String::num_int64(static_cast<int64_t>(stage.required_coins)) + ui("، الوقت ");
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
        add_label(ui("RAZOR PATH"), rect(300, 42, 680, 86), 56, true, false);
        add_label(ui("٢٥٠ طريقًا — قفزات دقيقة، عقبات متحركة، ومكافآت تجميلية"), rect(230, 124, 820, 52), 23, false, true);
        add_button(ui("العملات: ") + String::num_int64(coins) + ui(" +"), rect(24, 218, 230, 58), "offers");
        add_button(ui("الهدية اليومية"), rect(270, 218, 226, 58), "gifts");
        add_button(ui("الإحصاءات"), rect(512, 218, 226, 58), "statistics");
        add_button(ui("الإنجازات"), rect(754, 218, 226, 58), "achievements");
        add_button(ui("الإعدادات"), rect(996, 218, 260, 58), "settings");
        add_button(ui("متابعة إلى الجولة ") + String::num_int64(unlocked_stage), rect(120, 318, 500, 68), "continue");
        add_button(ui("اختيار جولة"), rect(660, 318, 500, 68), "levels");
        add_button(ui("المتجر"), rect(120, 402, 500, 62), "shop");
        add_button(ui("معاينة المظهر الحالي"), rect(660, 402, 500, 62), "appearance");
        add_button(ui("إعلان المكافأة: +200"), rect(280, 494, 320, 62), "rewarded_ad");
        add_button(ui("خروج"), rect(680, 494, 320, 62), "exit");
        add_label(ui("الحركة: يسار ويمين، القفز، الهجوم؛ لمس الشاشة يدعم عدة أصابع"), rect(180, 575, 920, 40), 18, false, true);
    } else if (screen == RazorScreen::LEVEL_SELECT) {
        const int32_t first_level = selection_page * 20 + 1;
        const int32_t selected_group = std::clamp((selected_level + 9) / 10, 1, 25);
        const int32_t group_start = (selected_group - 1) * 10 + 1;
        int32_t group_completed = 0;
        for (int32_t level = group_start; level < group_start + 10; ++level) {
            const auto progress = level_progress.find(level);
            group_completed += progress != level_progress.end() && progress->second.completed ? 1 : 0;
        }
        const bool chest_claimed = claimed_group_chests[selected_group - 1];

        add_panel(rect(74, 140, 1132, 500), rgba8(0xf0dfc2, 0.97), rgba8(0x2b1b14), 24, 6);
        add_panel(rect(102, 180, 302, 372), Color(0.56, 0.39, 0.26, 0.22), rgba8(0x81562f), 18, 3);
        add_panel(rect(420, 180, 758, 372), rgba8(0xf8ead5, 0.26), rgba8(0x805b3e), 18, 3);
        add_panel(rect(112, 232, 282, 148), rgba8(0xf0d4a8, 0.88), rgba8(0x9d774b), 12, 1);
        const auto map_found = authored_stages.find(selected_level);
        const StageData map_preview = map_found != authored_stages.end() ? map_found->second : make_generated_stage(selected_level);
        const double map_x = 120.0;
        const double map_y = 240.0;
        const double map_width = 266.0;
        const double map_height = 132.0;
        const double map_sx = map_width / std::max(1.0, map_preview.world_width);
        const double map_sy = map_height / std::max(1.0, map_preview.world_height);
        const double map_bottom = map_y + map_height;
        for (const RazorPlatformData &data : map_preview.platforms) {
            const Rect2 platform_rect = current_platform_rect(data, 0.0);
            const double x = map_x + platform_rect.position.x * map_sx;
            const double y = map_bottom - (map_preview.world_height - platform_rect.position.y) * map_sy;
            add_panel(rect(x, y, std::max(3.0, platform_rect.size.x * map_sx), std::max(4.0, platform_rect.size.y * map_sy)), rgba8(0x211812), rgba8(0x211812), 0, 0);
        }
        for (const Rect2 &hazard : map_preview.hazards) {
            const double x = map_x + hazard.position.x * map_sx;
            const double y = map_bottom - (map_preview.world_height - hazard.position.y) * map_sy;
            add_panel(rect(x, y, std::max(3.0, hazard.size.x * map_sx), 5.0), rgba8(0xc55a42), rgba8(0xc55a42), 0, 0);
        }
        const double start_x = map_x + map_preview.spawn.x * map_sx;
        const double start_y = map_bottom - (map_preview.world_height - map_preview.spawn.y) * map_sy;
        const double exit_x = map_x + map_preview.exit.x * map_sx;
        add_panel(rect(start_x - 4.0, start_y - 4.0, 8.0, 8.0), rgba8(0xffd36a), rgba8(0x7d481b), 4, 1);
        add_panel(rect(exit_x, map_y + 2.0, 3.0, map_height - 4.0), rgba8(0xf0b245), rgba8(0xf0b245), 0, 0);
        add_panel(rect(418, 72, 468, 58), rgba8(0x35231a), rgba8(0xd7a652), 20, 3);
        add_button(ui("‹ عودة"), rect(28, 17, 158, 56), "back");
        add_button(ui("اختيار المستوى"), rect(422, 76, 460, 49), "noop", true);
        add_button(ui("RAZOR\nPATH"), rect(1038, 14, 208, 86), "noop", true);
        add_button(ui("★ ") + String::num_int64(total_stars()) + ui(" / 750"), rect(418, 135, 205, 42), "noop", true);
        add_button(ui("إجمالي المستويات: ٢٥٠"), rect(629, 135, 265, 42), "noop", true);
        add_button(ui("المستوى ") + String::num_int64(selected_level), rect(119, 187, 268, 43), "noop", true);
        if (!hero_frames.empty() && hero_frames[0].is_valid()) {
            hero_preview_rect = rect(147, 332, 34, 62);
            hero_preview_widget = add_texture_rect(hero_frames[0], hero_preview_rect, hero_tint());
        }
        add_label(ui("أهداف المستوى"), rect(122, 398, 262, 38), 20, true);
        add_label(ui("اجمع النجوم الثلاثة"), rect(122, 434, 262, 35), 18, false);
        add_label(ui("نقطة حفظ ومخرج آمن"), rect(122, 463, 262, 32), 16, false);
        if (chest_claimed) {
            add_button(ui("تم الاستلام"), rect(120, 500, 268, 42), "noop", true);
        } else {
            add_button(ui("صندوق المجموعة ") + String::num_int64(selected_group), rect(120, 500, 176, 42), "noop", true);
            add_button(String::num_int64(group_completed) + ui(" / 10"), rect(300, 500, 88, 42), "noop", true);
        }

        for (int32_t offset = 0; offset < 20 && first_level + offset <= 250; ++offset) {
            const int32_t i = first_level + offset;
            const int32_t col = offset % 5;
            const int32_t row = offset / 5;
            const double x = 434.0 + col * 137.0;
            const double y = 188.0 + row * 90.0;
            const bool locked = i > unlocked_stage;
            const auto progress = level_progress.find(i);
            uint8_t star_mask = 0;
            if (progress != level_progress.end() && progress->second.completed) {
                star_mask = progress->second.star_mask;
            }
            String stars_line;
            for (int32_t bit = 0; bit < 3; ++bit) {
                stars_line += ((star_mask & static_cast<uint8_t>(1u << bit)) != 0) ? ui("★ ") : ui("☆ ");
            }
            const String caption = String::num_int64(i) + (locked ? ui("\n🔒") : ui("\n") + stars_line);
            Button *level_button = add_button(caption, rect(x, y, 126, 78), "stage:" + String::num_int64(i));
            if (level_button != nullptr) {
                level_button->add_theme_font_size_override("font_size", large_text ? 22 : 18);
            }
        }
        add_button(ui("‹"), rect(12, 326, 54, 78), "page_prev", selection_page == 0);
        add_button(ui("›"), rect(1214, 326, 54, 78), "page_next", selection_page >= 12);
        add_button(ui("أكمل 10 مستويات لفتح الصندوق التالي"), rect(430, 570, 515, 48), "noop", true);
        add_button(String::num_int64(group_completed) + ui(" / 10"), rect(951, 570, 177, 48), "noop", true);
        add_label(ui("الصفحة ") + String::num_int64(selection_page + 1) + ui(" من 13"), rect(558, 624, 170, 28), 15, true);
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
        static const std::array<String, 9> skin_names = {ui("الأساسي"), ui("الذهبي"), ui("الحجري"), ui("الداكن"), ui("الناري"), ui("الجليدي"), ui("الشبحي"), ui("السماوي"), ui("المظلم")};
        static const std::array<int32_t, 9> skin_prices = {0, 800, 750, 600, 700, 700, 900, 1000, 950};
        static const std::array<String, 4> effect_names = {ui("بلا أثر"), ui("أثر ذهبي"), ui("أثر سماوي"), ui("أثر شبحي")};
        static const std::array<int32_t, 4> effect_prices = {0, 200, 250, 300};
        static const std::array<int32_t, 8> display_order = {1, 3, 4, 5, 6, 2, 7, 8};
        static const std::array<Color, 9> skin_tints = {
            rgba8(0xffffff), rgba8(0xffd35b), rgba8(0xb7aa96), rgba8(0x27212a), rgba8(0xff593c),
            rgba8(0x8bdcff), rgba8(0xe3e4ed), rgba8(0x88c5ff), rgba8(0x241b24)};
        const int64_t now = utc_now();
        const bool gift_ready = daily_last_claim == 0 || (now > daily_last_claim && now - daily_last_claim >= 86400);
        const int64_t gift_remaining = gift_ready ? 0 : std::max<int64_t>(0, 86400 - (now - daily_last_claim));
        const String gift_timer = gift_ready ? ui("متاحة الآن") : ui("متبقي ") + String::num_int64(gift_remaining / 3600) + ui(" س ") + String::num_int64((gift_remaining % 3600) / 60) + ui(" د");

        add_panel(rect(28, 150, 1224, 475), rgba8(0xf1dfc4, 0.97), rgba8(0x2c1b13), 24, 6);
        add_panel(rect(47, 169, 220, 438), rgba8(0xe8d4b6, 0.92), rgba8(0x765038), 18, 3);
        add_panel(rect(278, 169, 664, 438), rgba8(0xf8ebd8, 0.45), rgba8(0x896543), 18, 3);
        add_panel(rect(956, 169, 278, 210), rgba8(0xf2dfbd, 0.94), rgba8(0x805530), 18, 3);
        add_panel(rect(956, 391, 278, 216), rgba8(0xe8d0aa, 0.94), rgba8(0x805530), 18, 3);
        add_button(ui("‹ عودة"), rect(30, 17, 155, 56), "back");
        add_button(ui("★ ") + String::num_int64(coins) + ui("   +"), rect(199, 17, 203, 56), "tab:3");
        add_button(ui("المتجر"), rect(508, 17, 352, 63), "noop", true);
        add_button(ui("RAZOR\nPATH"), rect(1053, 11, 194, 82), "noop", true);
        const std::array<String, 4> tab_names = {ui("المظاهر"), ui("المؤثرات"), ui("العناصر"), ui("عروض خاصة")};
        for (int32_t tab = 0; tab < 4; ++tab) {
            add_button(tab_names[tab], rect(284.0 + tab * 176.0, 96, 168, 49), "tab:" + String::num_int64(tab), shop_tab == tab);
        }
        add_button(ui("معاينة الشخصية"), rect(59, 180, 196, 39), "noop", true);
        if (!hero_frames.empty() && hero_frames[0].is_valid()) {
            hero_preview_rect = rect(70, 220, 173, 241);
            hero_preview_widget = add_texture_rect(hero_frames[0], hero_preview_rect, hero_tint());
        }
        add_label(ui("المظهر الحالي"), rect(62, 470, 190, 30), 17, false);
        add_label(skin_names[std::clamp(selected_skin, 0, 8)], rect(62, 499, 190, 38), 23, true);
        add_button(ui("تغيير المظهر"), rect(63, 550, 187, 44), "appearance");
        if (shop_tab == 0) {
            for (int32_t slot = 0; slot < static_cast<int32_t>(display_order.size()); ++slot) {
                const int32_t skin = display_order[slot];
                const int32_t col = slot % 4;
                const int32_t row = slot / 4;
                const Rect2 card = rect(288.0 + col * 163.0, 176.0 + row * 209.0, 153.0, 198.0);
                add_panel(card, rgba8(0xf1dfc4, 0.98), rgba8(0x60432d), 17, 3);
                add_button(skin_names[skin], rect(card.position.x + 6.0, card.position.y + 5.0, card.size.x - 12.0, 31.0), "noop", true);
                if (hero_frames[0].is_valid()) {
                    skin_preview_widgets[slot] = add_texture_rect(hero_frames[0], rect(card.position.x + 23.0, card.position.y + 37.0, card.size.x - 46.0, 85.0), skin_tints[skin]);
                }
                const bool owned = owned_skins[skin];
                String action;
                String caption;
                if (selected_skin == skin) {
                    caption = ui("مجهز ✓");
                    action = "skin:" + String::num_int64(skin);
                } else if (owned) {
                    caption = ui("تجهيز");
                    action = "skin:" + String::num_int64(skin);
                } else {
                    add_label(ui("★ ") + String::num_int64(skin_prices[skin]), rect(card.position.x + 10.0, card.position.y + 122.0, card.size.x - 20.0, 26.0), 18, true, false);
                    caption = ui("شراء");
                    action = "buy_skin:" + String::num_int64(skin);
                }
                if (owned) {
                    add_label(ui("مظهر مملوك"), rect(card.position.x + 10.0, card.position.y + 122.0, card.size.x - 20.0, 26.0), 16, false);
                }
                add_button(caption, rect(card.position.x + 10.0, card.position.y + 157.0, card.size.x - 20.0, 35.0), action, selected_skin == skin);
                if (skin == 1) {
                    add_button(ui("مميز"), rect(card.position.x + 8.0, card.position.y + 39.0, 63.0, 25.0), "noop", true);
                }
            }
        } else if (shop_tab == 1) {
            for (int32_t effect = 0; effect < static_cast<int32_t>(effect_names.size()); ++effect) {
                const int32_t col = effect % 2;
                const int32_t row = effect / 2;
                const Rect2 card = rect(318.0 + col * 306.0, 190.0 + row * 193.0, 286.0, 174.0);
                add_panel(card, rgba8(0xf1dfc4, 0.98), rgba8(0x60432d), 17, 3);
                add_label(effect_names[effect], rect(card.position.x + 12.0, card.position.y + 14.0, card.size.x - 24.0, 34.0), 20, true);
                const bool owned = owned_effects[effect];
                String action;
                String caption;
                if (selected_effect == effect) {
                    caption = ui("مجهز ✓");
                    action = "effect:" + String::num_int64(effect);
                } else if (owned) {
                    caption = ui("تجهيز");
                    action = "effect:" + String::num_int64(effect);
                } else {
                    add_label(ui("★ ") + String::num_int64(effect_prices[effect]), rect(card.position.x + 14.0, card.position.y + 77.0, card.size.x - 28.0, 28.0), 18, true);
                    caption = ui("شراء");
                    action = "buy_effect:" + String::num_int64(effect);
                }
                add_button(caption, rect(card.position.x + 18.0, card.position.y + 121.0, card.size.x - 36.0, 40.0), action, selected_effect == effect);
            }
            add_label(ui("آثار الركض والقفز تجميلية فقط ولا تغيّر سرعة اللاعب أو القفز."), rect(312, 573, 620, 30), 16, false);
        } else if (shop_tab == 2) {
            add_panel(rect(316, 205, 585, 300), rgba8(0xf1dfc4, 0.98), rgba8(0x60432d), 20, 3);
            add_label(ui("العناصر"), rect(340, 235, 536, 48), 28, true);
            add_label(ui("لا توجد عناصر استهلاكية تمنح حصانة أو تغيّر الفيزياء."), rect(340, 304, 536, 70), 21, false);
            add_label(ui("نحافظ على توازن المراحل؛ ستظهر العناصر الشكلية هنا عند إضافتها."), rect(340, 390, 536, 82), 18, false);
        } else {
            add_panel(rect(316, 195, 610, 345), rgba8(0xf1dfc4, 0.98), rgba8(0x60432d), 20, 3);
            add_label(ui("العروض الخاصة"), rect(342, 214, 558, 48), 27, true);
            add_button(ui("حزمة 500 عملة · الشراء غير متاح"), rect(346, 275, 548, 50), "noop", true);
            add_button(ui("حزمة 1200 عملة · الشراء غير متاح"), rect(346, 337, 548, 50), "noop", true);
            add_button(ui("إزالة الإعلانات · غير متاحة"), rect(346, 399, 548, 50), "noop", true);
            add_label(ui("لا يوجد مزود دفع مهيأ؛ لا تُخصم أموال من داخل اللعبة."), rect(342, 466, 558, 48), 16, false);
        }
        add_label(ui("الهدية اليومية"), rect(969, 178, 252, 34), 21, true);
        add_label(gift_ready ? ui("هدية مجانية كل يوم") : gift_timer, rect(969, 214, 252, 30), 17, false);
        add_label(ui("★ 100 عملة"), rect(969, 247, 252, 32), 21, true);
        add_button(gift_ready ? ui("استلام الهدية") : ui("العودة لاحقًا"), rect(971, 290, 246, 42), "daily_claim", !gift_ready);
        add_label(gift_timer, rect(969, 337, 252, 26), 15, false);
        add_label(ui("مكافأة العودة"), rect(969, 400, 252, 35), 20, true);
        add_label(ui("اكسب 200 عملة بعد مشاهدة إعلان فعلي."), rect(969, 440, 252, 56), 16, false);
        add_button(ui("▶ مشاهدة إعلان"), rect(971, 501, 246, 42), "rewarded_ad");
        add_label(ui("+ 200 عملة"), rect(969, 551, 252, 30), 17, true);
        add_button(ui("الإنجازات"), rect(52, 638, 210, 59), "achievements");
        add_button(ui("الإحصائيات"), rect(278, 638, 210, 59), "statistics");
        add_button(ui("الهدايا"), rect(504, 638, 180, 59), "gifts");
        add_button(ui("العروض الخاصة"), rect(1010, 638, 220, 59), "tab:3", shop_tab == 3);
    } else if (screen == RazorScreen::SETTINGS) {
        add_label(ui("الإعدادات"), rect(390, 76, 500, 75), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        add_button(muted ? ui("الصوت: مكتوم") : ui("الصوت: يعمل"), rect(345, 205, 590, 62), "mute");
        add_button(reduced_motion ? ui("الحركة: منخفضة") : ui("الحركة: كاملة"), rect(345, 284, 590, 62), "motion");
        add_button(large_text ? ui("حجم النص: كبير") : ui("حجم النص: عادي"), rect(345, 363, 590, 62), "text");
        add_label(ui("الوضع الأفقي ملء الشاشة"), rect(390, 455, 500, 50), 23);
    } else if (screen == RazorScreen::STATISTICS) {
        const int64_t seconds = static_cast<int64_t>(play_seconds_total);
        const String duration = String::num_int64(seconds / 3600) + ui(" س ") + String::num_int64((seconds / 60) % 60) + ui(" د ") + String::num_int64(seconds % 60) + ui(" ث");
        add_label(ui("إحصاءات اللاعب"), rect(360, 60, 560, 70), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        add_label(ui("الجولات المكتملة: ") + String::num_int64(completed_stages()) + ui(" / 250"), rect(300, 170, 680, 55), 27);
        add_label(ui("النجوم: ") + String::num_int64(total_stars()) + ui(" / 750"), rect(300, 235, 680, 55), 27);
        add_label(ui("العملات المكتسبة: ") + String::num_int64(coins_earned) + ui(" — الرصيد: ") + String::num_int64(coins), rect(300, 300, 680, 55), 25);
        add_label(ui("عدد الوفيات: ") + String::num_int64(deaths) + ui(" — القفزات: ") + String::num_int64(total_jumps), rect(300, 365, 680, 55), 25);
        add_label(ui("وقت اللعب: ") + duration, rect(300, 430, 680, 55), 25);
    } else if (screen == RazorScreen::GIFTS) {
        const int64_t now = utc_now();
        const bool clock_back = daily_last_claim > 0 && now < daily_last_claim;
        const int64_t left = daily_last_claim == 0 ? 0 : std::max<int64_t>(0, 86400 - (now - daily_last_claim));
        const String countdown = String::num_int64(left / 3600) + ui(" ساعة، ") + String::num_int64((left / 60) % 60) + ui(" دقيقة، ") + String::num_int64(left % 60) + ui(" ثانية");
        const bool ready = daily_last_claim == 0 || (!clock_back && left == 0);
        add_label(ui("الهدايا"), rect(390, 64, 500, 70), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        add_label(ui("هدية يومية: 100 عملة كل 24 ساعة"), rect(260, 175, 760, 56), 27, true);
        add_button(ready ? ui("استلام +100") : ui("الوقت المتبقي: ") + countdown, rect(350, 250, 580, 68), "daily_claim", !ready);
        if (clock_back) {
            add_label(ui("ساعة الجهاز رجعت إلى الوراء؛ لن تُمنح هدية حتى يتجاوز الوقت آخر استلام."), rect(230, 335, 820, 58), 20);
        }
        add_button(ui("مشاهدة إعلان مكافأة +200"), rect(350, 425, 580, 68), "rewarded_ad");
        add_label(ui("لا يتوفر إعلان الآن ما لم يكتمل إعلان فعلي عبر مزود إعلانات."), rect(260, 505, 760, 48), 19);
    } else if (screen == RazorScreen::ACHIEVEMENTS) {
        const std::array<String, 5> titles = {ui("أكمل أول جولة"), ui("اجمع 30 نجمة"), ui("أكمل 50 جولة"), ui("أكمل الحملة كاملة"), ui("اكسب 1000 عملة")};
        const std::array<int32_t, 5> rewards = {25, 100, 250, 500, 100};
        const std::array<bool, 5> eligible = {completed_stages() >= 1, total_stars() >= 30, completed_stages() >= 50, completed_stages() >= 250, coins_earned >= 1000};
        add_label(ui("الإنجازات"), rect(390, 45, 500, 70), 42, true);
        add_button(ui("رجوع"), rect(38, 35, 150, 58), "back");
        for (int32_t i = 0; i < 5; ++i) {
            const double y = 135.0 + i * 88.0;
            add_label(titles[i] + ui(" · مكافأة ") + String::num_int64(rewards[i]), rect(220, y, 560, 58), 21, true);
            add_button(claimed_achievements[i] ? ui("تم الاستلام") : (eligible[i] ? ui("استلام") : ui("غير مكتمل")),
                rect(810, y, 250, 58), "achievement:" + String::num_int64(i), claimed_achievements[i] || !eligible[i]);
        }
    } else if (screen == RazorScreen::STAGE_CLEAR) {
        const auto progress = level_progress.find(stage_index);
        const int32_t stars = progress == level_progress.end() ? 0 : static_cast<int32_t>((progress->second.star_mask & 1) != 0) + static_cast<int32_t>((progress->second.star_mask & 2) != 0) + static_cast<int32_t>((progress->second.star_mask & 4) != 0);
        add_label(ui("أحسنت! الطريق التالي مفتوح"), rect(260, 120, 760, 76), 42, true);
        add_label(ui("الجولة ") + String::num_int64(stage_index) + ui(" اكتملت · النجوم ") + String::num_int64(stars) + ui(" / 3 · +10 عملات"), rect(280, 205, 720, 54), 24);
        add_button(ui("المرحلة التالية"), rect(420, 335, 440, 68), "next");
        add_button(ui("اختيار المراحل"), rect(420, 420, 210, 62), "levels");
        add_button(ui("القائمة الرئيسية"), rect(650, 420, 210, 62), "home");
    } else if (screen == RazorScreen::VICTORY) {
        add_label(ui("اكتمل طريق الظلال!"), rect(260, 135, 760, 86), 46, true);
        add_label(ui("أنهيت الجولات الـ250 وجمعت ") + String::num_int64(total_stars()) + ui(" نجمة"), rect(260, 230, 760, 54), 27);
        add_button(ui("أعد الجولة 250"), rect(385, 340, 510, 68), "restart");
        add_button(ui("القائمة الرئيسية"), rect(385, 428, 510, 64), "home");
    } else if (screen == RazorScreen::GAME_OVER) {
        add_label(ui("انتهى الوقت"), rect(390, 150, 500, 80), 44, true);
        add_button(ui("أعد المحاولة"), rect(420, 300, 440, 68), "restart");
        add_button(ui("القائمة الرئيسية"), rect(420, 390, 440, 64), "home");
    }

    if (show_purchase_confirm && pending_purchase >= 0) {
        static const std::array<String, 9> skin_names = {ui("الأساسي"), ui("الذهبي"), ui("الحجري"), ui("الداكن"), ui("الناري"), ui("الجليدي"), ui("الشبحي"), ui("السماوي"), ui("المظلم")};
        static const std::array<int32_t, 9> skin_prices = {0, 800, 750, 600, 700, 700, 900, 1000, 950};
        static const std::array<String, 4> effect_names = {ui("بلا أثر"), ui("أثر ذهبي"), ui("أثر سماوي"), ui("أثر شبحي")};
        static const std::array<int32_t, 4> effect_prices = {0, 200, 250, 300};
        const bool is_effect = pending_purchase >= 100;
        const int32_t item = is_effect ? pending_purchase - 100 : pending_purchase;
        const String name = is_effect ? effect_names[std::clamp(item, 0, 3)] : skin_names[std::clamp(item, 0, 8)];
        const int32_t cost = is_effect ? effect_prices[std::clamp(item, 0, 3)] : skin_prices[std::clamp(item, 0, 8)];
        add_label(ui("تأكيد شراء ") + name + ui(" · السعر ") + String::num_int64(cost) + ui(" · الرصيد بعد الشراء ") + String::num_int64(coins - cost), rect(250, 430, 780, 62), 24, true);
        add_button(ui("تأكيد الشراء"), rect(350, 500, 250, 62), "confirm_purchase");
        add_button(ui("إلغاء"), rect(680, 500, 250, 62), "cancel_purchase");
    }
    if (pending_equip >= 0) {
        add_label(ui("تم الشراء بنجاح. هل تريد التجهيز الآن؟"), rect(250, 440, 780, 56), 24, true);
        add_button(ui("تجهيز الآن"), rect(350, 505, 250, 62), "equip_pending");
        add_button(ui("لاحقًا"), rect(680, 505, 250, 62), "later_equip");
    }
    if (show_exit_confirm) {
        add_label(ui("هل تريد الخروج من اللعبة؟"), rect(360, 440, 560, 60), 26, true);
        add_button(ui("خروج"), rect(390, 510, 220, 62), "confirm_exit");
        add_button(ui("إلغاء"), rect(670, 510, 220, 62), "cancel_exit");
    }
    if (!ui_notice.is_empty()) {
        toast_label = memnew(Label);
        toast_label->set_text(ui_notice);
        toast_label->set_position(Vector2(300.0 * sx, 648.0 * sy));
        toast_label->set_size(Vector2(680.0 * sx, 48.0 * sy));
        toast_label->set_horizontal_alignment(HORIZONTAL_ALIGNMENT_CENTER);
        toast_label->set_vertical_alignment(VERTICAL_ALIGNMENT_CENTER);
        toast_label->set_layout_direction(Control::LAYOUT_DIRECTION_RTL);
        toast_label->set_text_direction(Control::TEXT_DIRECTION_RTL);
        toast_label->set_mouse_filter(Control::MOUSE_FILTER_IGNORE);
        toast_label->add_theme_font_size_override("font_size", 20);
        ui_root->add_child(toast_label);
    }
    queue_redraw();
}

void RazorPathGame::set_screen(RazorScreen next_screen) {
    if (screen == RazorScreen::PLAYING && next_screen != RazorScreen::PLAYING) {
        save_progress();
    }
    screen = next_screen;
    if (screen == RazorScreen::LEVEL_SELECT) {
        selected_level_confirmed = false;
    }
    touch_actions.clear();
    jump_requested = false;
    attack_requested = false;
    show_exit_confirm = false;
    show_purchase_confirm = false;
    rebuild_ui();
}

void RazorPathGame::go_back() {
    if (show_purchase_confirm) {
        show_purchase_confirm = false;
        pending_purchase = -1;
        rebuild_ui();
    } else if (pending_equip >= 0) {
        pending_equip = -1;
        rebuild_ui();
    } else if (show_exit_confirm) {
        show_exit_confirm = false;
        rebuild_ui();
    } else if (screen == RazorScreen::SHOP || screen == RazorScreen::SETTINGS || screen == RazorScreen::STATISTICS || screen == RazorScreen::GIFTS || screen == RazorScreen::ACHIEVEMENTS) {
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
    } else if (action == "continue") {
        start_stage(std::clamp(unlocked_stage, 1, 250));
    } else if (action == "levels") {
        if (screen != RazorScreen::PAUSED) {
            return_screen = RazorScreen::HOME;
        }
        selection_page = std::clamp((selected_level - 1) / 20, 0, 12);
        set_screen(RazorScreen::LEVEL_SELECT);
    } else if (action == "shop") {
        return_screen = screen;
        shop_tab = 0;
        set_screen(RazorScreen::SHOP);
    } else if (action == "appearance") {
        return_screen = screen;
        shop_tab = 0;
        set_screen(RazorScreen::SHOP);
    } else if (action == "offers") {
        return_screen = screen;
        shop_tab = 3;
        set_screen(RazorScreen::SHOP);
    } else if (action == "settings") {
        return_screen = screen;
        set_screen(RazorScreen::SETTINGS);
    } else if (action == "statistics") {
        return_screen = screen;
        set_screen(RazorScreen::STATISTICS);
    } else if (action == "gifts") {
        return_screen = screen;
        set_screen(RazorScreen::GIFTS);
    } else if (action == "achievements") {
        return_screen = screen;
        set_screen(RazorScreen::ACHIEVEMENTS);
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
        start_stage(std::min(250, stage_index + 1));
    } else if (action == "page_prev") {
        selection_page = std::max(0, selection_page - 1);
        selected_level = selection_page * 20 + 1;
        selected_level_confirmed = false;
        rebuild_ui();
    } else if (action == "page_next") {
        selection_page = std::min(12, selection_page + 1);
        selected_level = selection_page * 20 + 1;
        selected_level_confirmed = false;
        rebuild_ui();
    } else if (action.begins_with("tab:")) {
        shop_tab = std::clamp(static_cast<int32_t>(action.substr(4).to_int()), 0, 3);
        rebuild_ui();
    } else if (action.begins_with("stage:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(6).to_int());
        const int32_t previously_selected = selected_level;
        selected_level = std::clamp(chosen, 1, 250);
        if (chosen <= unlocked_stage) {
            if (previously_selected == chosen && selected_level_confirmed) {
                start_stage(chosen);
            } else {
                selected_level_confirmed = true;
                rebuild_ui();
            }
        } else {
            selected_level_confirmed = false;
            ui_notice = ui("أكمل جميع مستويات المجموعة السابقة لفتح هذه الجولة.");
            toast_time = 2.5;
            rebuild_ui();
        }
    } else if (action.begins_with("skin:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(5).to_int());
        if (chosen >= 0 && chosen < static_cast<int32_t>(owned_skins.size()) && owned_skins[chosen]) {
            const int32_t previous_skin = selected_skin;
            selected_skin = chosen;
            if (!save_progress()) {
                selected_skin = previous_skin;
                ui_notice = ui("تعذر حفظ المظهر المحدد.");
                toast_time = 2.8;
            }
            rebuild_ui();
        }
    } else if (action.begins_with("buy_skin:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(9).to_int());
        static const std::array<int32_t, 9> prices = {0, 800, 750, 600, 700, 700, 900, 1000, 950};
        if (chosen > 0 && chosen < static_cast<int32_t>(owned_skins.size()) && !owned_skins[chosen]) {
            if (coins < prices[chosen]) {
                shop_tab = 3;
                ui_notice = ui("عملات غير كافية؛ راجع العروض المتاحة.");
                toast_time = 2.8;
            } else {
                pending_purchase = chosen;
                show_purchase_confirm = true;
            }
            rebuild_ui();
        }
    } else if (action.begins_with("effect:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(7).to_int());
        if (chosen >= 0 && chosen < static_cast<int32_t>(owned_effects.size()) && owned_effects[chosen]) {
            const int32_t previous_effect = selected_effect;
            selected_effect = chosen;
            if (!save_progress()) {
                selected_effect = previous_effect;
                ui_notice = ui("تعذر حفظ الأثر المحدد.");
                toast_time = 2.8;
            }
            rebuild_ui();
        }
    } else if (action.begins_with("buy_effect:")) {
        const int32_t chosen = static_cast<int32_t>(action.substr(11).to_int());
        static const std::array<int32_t, 4> prices = {0, 200, 250, 300};
        if (chosen > 0 && chosen < static_cast<int32_t>(owned_effects.size()) && !owned_effects[chosen]) {
            if (coins < prices[chosen]) {
                shop_tab = 3;
                ui_notice = ui("عملات غير كافية؛ راجع العروض المتاحة.");
                toast_time = 2.8;
            } else {
                pending_purchase = 100 + chosen;
                show_purchase_confirm = true;
            }
            rebuild_ui();
        }
    } else if (action == "confirm_purchase") {
        const int32_t item = pending_purchase;
        show_purchase_confirm = false;
        ui_notice = String();
        bool purchased = false;
        if (item >= 0 && item < static_cast<int32_t>(owned_skins.size())) {
            purchased = purchase_skin(item);
        } else if (item >= 100 && item < 100 + static_cast<int32_t>(owned_effects.size())) {
            static const std::array<int32_t, 4> prices = {0, 200, 250, 300};
            const int32_t effect = item - 100;
            if (effect > 0 && !owned_effects[effect] && coins >= prices[effect]) {
                const int32_t previous_coins = coins;
                coins -= prices[effect];
                owned_effects[effect] = true;
                purchased = save_progress();
                if (!purchased) {
                    coins = previous_coins;
                    owned_effects[effect] = false;
                    ui_notice = ui("تعذر حفظ الشراء؛ لم تُخصم العملات.");
                }
            }
        }
        pending_purchase = -1;
        if (purchased) {
            pending_equip = item;
            ui_notice = ui("تم حفظ الشراء. يمكنك تجهيز العنصر الآن.");
        } else {
            shop_tab = 3;
            if (ui_notice.is_empty()) {
                ui_notice = ui("تعذر الشراء أو أن العنصر مملوك مسبقًا.");
            }
        }
        toast_time = 2.8;
        rebuild_ui();
    } else if (action == "cancel_purchase") {
        show_purchase_confirm = false;
        pending_purchase = -1;
        rebuild_ui();
    } else if (action == "equip_pending") {
        const int32_t previous_skin = selected_skin;
        const int32_t previous_effect = selected_effect;
        if (pending_equip >= 100) {
            selected_effect = pending_equip - 100;
        } else if (pending_equip >= 0) {
            selected_skin = pending_equip;
        }
        pending_equip = -1;
        if (!save_progress()) {
            selected_skin = previous_skin;
            selected_effect = previous_effect;
            ui_notice = ui("تعذر حفظ التجهيز؛ لم يتغير اختيارك.");
            toast_time = 2.8;
        }
        rebuild_ui();
    } else if (action == "later_equip") {
        pending_equip = -1;
        rebuild_ui();
    } else if (action == "daily_claim") {
        ui_notice = String();
        if (claim_daily_gift(utc_now())) {
            ui_notice = ui("استلمت 100 عملة. عُد بعد 24 ساعة.");
        } else if (ui_notice.is_empty()) {
            ui_notice = ui("الهدية غير جاهزة أو أن ساعة الجهاز رجعت إلى الوراء.");
        }
        toast_time = 3.0;
        rebuild_ui();
    } else if (action == "rewarded_ad") {
        ui_notice = has_rewarded_ad ? ui("لم يكتمل الإعلان؛ لم تُمنح عملات.") : ui("لا يوجد إعلان الآن؛ لم تُمنح أي عملات.");
        toast_time = 3.0;
        rebuild_ui();
    } else if (action.begins_with("achievement:")) {
        const int32_t id = static_cast<int32_t>(action.substr(13).to_int());
        const std::array<int32_t, 5> rewards = {25, 100, 250, 500, 100};
        const std::array<bool, 5> eligible = {completed_stages() >= 1, total_stars() >= 30, completed_stages() >= 50, completed_stages() >= 250, coins_earned >= 1000};
        if (id >= 0 && id < 5 && !claimed_achievements[id] && eligible[id]) {
            const int32_t previous_coins = coins;
            const int32_t previous_coins_earned = coins_earned;
            claimed_achievements[id] = true;
            coins += rewards[id];
            coins_earned += rewards[id];
            if (save_progress()) {
                ui_notice = ui("تم استلام مكافأة الإنجاز.");
            } else {
                claimed_achievements[id] = false;
                coins = previous_coins;
                coins_earned = previous_coins_earned;
                ui_notice = ui("تعذر حفظ المكافأة؛ لم تُضف العملات.");
            }
        }
        toast_time = 2.4;
        rebuild_ui();
    } else if (action == "exit") {
        show_exit_confirm = true;
        rebuild_ui();
    } else if (action == "confirm_exit") {
        save_progress();
        get_tree()->quit();
    } else if (action == "cancel_exit") {
        show_exit_confirm = false;
        rebuild_ui();
    } else if (action == "mute") {
        muted = !muted;
        if (AudioServer::get_singleton() != nullptr) {
            AudioServer::get_singleton()->set_bus_mute(0, muted);
        }
        save_progress();
        rebuild_ui();
    } else if (action == "motion") {
        reduced_motion = !reduced_motion;
        save_progress();
        rebuild_ui();
    } else if (action == "text") {
        large_text = !large_text;
        save_progress();
        rebuild_ui();
    }
}

void RazorPathGame::_on_ui_action(const String &action) {
    handle_action(action);
}

bool RazorPathGame::start_test_stage(int32_t requested_index) {
    if (requested_index < 1 || requested_index > 250) {
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
    unlocked_stage = std::clamp(requested_index, 1, 250);
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

bool RazorPathGame::test_stage_loadable(int32_t requested_index) {
    if (requested_index < 1 || requested_index > 250) {
        return false;
    }
    const StageData previous_stage = stage;
    const int32_t previous_index = stage_index;
    const bool loaded = load_stage(requested_index);
    const bool has_campaign_record = requested_index == 1 || requested_index == 16 || stage.tile_campaign;
    const bool valid = loaded && stage.index == requested_index && has_campaign_record && stage.world_width >= 640.0 && stage.world_height >= 640.0 &&
        !stage.platforms.empty() && stage.stars.size() == 3 && stage.checkpoints.size() >= 1 && stage.exit.x > stage.spawn.x;
    stage = previous_stage;
    stage_index = previous_index;
    return valid;
}

int32_t RazorPathGame::test_stage_star_count() const {
    return static_cast<int32_t>(stage.stars.size());
}

void RazorPathGame::test_set_coins(int32_t value) {
    coins = std::max(0, value);
}

bool RazorPathGame::test_purchase_skin(int32_t skin_index) {
    return purchase_skin(skin_index);
}

bool RazorPathGame::test_claim_daily_gift_at(int64_t now_utc) {
    return claim_daily_gift(now_utc);
}

bool RazorPathGame::test_skin_owned(int32_t skin_index) const {
    return skin_index >= 0 && skin_index < static_cast<int32_t>(owned_skins.size()) && owned_skins[skin_index];
}

} // namespace godot
