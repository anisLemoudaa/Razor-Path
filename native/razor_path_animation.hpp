#pragma once

// Native-facing contract for the Razor Path character renderer.
// The shipped Godot runtime uses scripts/anis_character.gd; this header keeps
// the same state and skin data available for a future C++/GDExtension build.

#include <array>
#include <cstdint>
#include <string_view>

namespace razor_path {

enum class AnimationState : std::uint8_t {
    Idle,
    Run,
    Jump,
    Fall,
    Land,
    WallSlide,
    Dash,
    Death,
    Win,
};

struct SkinPalette {
    std::string_view id;
    std::string_view display_name;
    std::uint32_t primary_rgb;
    std::uint32_t accent_rgb;
    std::uint32_t scarf_rgb;
    std::uint16_t price;
};

inline constexpr std::array<SkinPalette, 6> kSkins{{
    {"default", "الافتراضي", 0x171126, 0xD4AF37, 0xB07D14, 0},
    {"ruby", "الياقوت", 0x32152B, 0xF05B68, 0xB82F4D, 200},
    {"emerald", "الزمرد", 0x102C2C, 0x54D6A0, 0x178D75, 200},
    {"diamond", "الماسي", 0x1B2945, 0x8BE5FF, 0x4388D4, 350},
    {"gold", "الذهبي", 0x32220E, 0xFFF0A8, 0xE0A928, 0},
    {"legend", "الأسطورة", 0x29123F, 0xE78CFF, 0x8735BD, 500},
}};

struct AnimationFrame {
    AnimationState state{AnimationState::Idle};
    float time_seconds{0.0f};
    float facing{1.0f};
    float velocity_x{0.0f};
    float velocity_y{0.0f};
    std::uint32_t death_count{0};
};

inline constexpr float kDeathFreezeSeconds = 0.060f;
inline constexpr float kJumpStretch = 1.12f;
inline constexpr float kLandingSquash = 0.82f;

} // namespace razor_path
