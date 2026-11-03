extends RefCounted
## Paths keep gameplay audio outside the title startup dependency graph.
## Literal paths are retained in the all-resources Web export.

const BGM_PATH := "res://assets/template/audio/bgm.ogg"
const CUE_PATHS: Dictionary[StringName, String] = {
	&"stage_clear": "res://assets/template/audio/checkpoint.ogg",
	&"invalid": "res://assets/template/audio/death.ogg",
	&"tutorial": "res://assets/template/audio/checkpoint.ogg",
	&"attack": "res://assets/template/audio/jump.ogg",
	&"confirm": "res://assets/template/audio/confirm.ogg",
	&"jump": "res://assets/template/audio/jump.ogg",
	&"land": "res://assets/template/audio/land.ogg",
	&"coin": "res://assets/template/audio/coin.ogg",
	&"stomp": "res://assets/template/audio/stomp.ogg",
	&"checkpoint": "res://assets/template/audio/checkpoint.ogg",
	&"death": "res://assets/template/audio/death.ogg",
	&"success": "res://assets/template/audio/success.ogg",
	&"ui_confirm": "res://assets/template/audio/confirm.ogg",
	&"ui_back": "res://assets/template/audio/land.ogg",
	&"ui_cancel": "res://assets/template/audio/land.ogg",
	&"ui_hover": "res://assets/template/audio/land.ogg",
	&"ui_focus": "res://assets/template/audio/land.ogg",
	&"ui_selection": "res://assets/template/audio/coin.ogg",
	&"ui_toggle": "res://assets/template/audio/confirm.ogg",
	&"ui_slider": "res://assets/template/audio/land.ogg",
	&"ui_invalid": "res://assets/template/audio/death.ogg",
	&"ui_notification": "res://assets/template/audio/checkpoint.ogg",
}

# Reuse the supplied final cue set with deliberate UI gain/pitch treatment.
# All one-shot routing, levels and repeat limits remain in this registry.
const CUE_SETTINGS := {
	&"invalid": {"cooldown_ms": 300, "gain_db": -13.0},
	&"tutorial": {"cooldown_ms": 300, "gain_db": -15.0},
	&"ui_confirm": {"cooldown_ms": 90, "gain_db": -8.0},
	&"ui_back": {"cooldown_ms": 90, "gain_db": -10.0, "pitch": 0.9},
	&"ui_cancel": {"cooldown_ms": 90, "gain_db": -10.0, "pitch": 0.9},
	&"ui_hover": {"cooldown_ms": 100, "gain_db": -20.0, "pitch": 1.5},
	&"ui_focus": {"cooldown_ms": 100, "gain_db": -20.0, "pitch": 1.5},
	&"ui_selection": {"cooldown_ms": 90, "gain_db": -13.0, "pitch": 1.1},
	&"ui_toggle": {"cooldown_ms": 90, "gain_db": -11.0},
	&"ui_slider": {"cooldown_ms": 90, "gain_db": -22.0, "pitch": 1.25},
	&"ui_invalid": {"cooldown_ms": 220, "gain_db": -13.0, "pitch": 1.15},
	&"ui_notification": {"cooldown_ms": 250, "gain_db": -12.0},
}
