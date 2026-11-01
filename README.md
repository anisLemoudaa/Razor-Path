# Horizontal Platformer Game Template (Godot 4.7 → Web/WASM)

This versioned source is owned by the Webdev Addon. Use the installed Game workflow for initialization, preview, release and publishing. Matching gameplay source: template-provenance.json. Existing projects are never overwritten by a new starter.

For online multiplayer, read [the shared service guide](docs/game-multiplayer.md).

## Shared game-development workflow

Applies to Standard effort, not `fast_prototype`; Fast uses its dedicated section instead. Keep edits scoped and preserve explicit constraints.

### Preserve the selected template
Extend the initialized project and keep its working simulation, controls, saves and delivery. Integrate supplied
games into that project. The first Preview must show the requested game, not a renamed demo; replace the Generic
maze gameplay unless a maze was requested.

### First-checkpoint completion contract
Deliver the requested goal, actions and outcome loop with understandable controls and feedback, recovery or replay
where it fits, coherent readable visuals, the necessary start, pause and results screens, and any requested
deliverable. Match run length and content to the brief; there is no minimum playtime, campaign, extra mode or screen
quota. Prioritize gameplay, broken resources, responsiveness and visible defects, and stop when the requested
experience works. Add art, audio or polish only for a concrete benefit. Leaderboards, new Tweak controls and extra
languages are optional; required Share OG and explicit media, concept or feature requests are not.
Default to desktop. Add or test touch controls, portrait layouts or mobile-browser support only when the user asks.
Sharing a Web link is not a mobile request. Keep inherited controls working without expanding mobile coverage.

Choose the [delivery scope](game-delivery.md#delivery-scope-and-stopping-boundary) from the request. Ordinary managed
delivery is check → save-release.mjs → applicable check --pack → push the exact SHA and confirm the checkpoint.
Documentation-only edits need no engine boot. Do not add audit reports, speculative test suites, a separate
self-review phase or duplicate validation workers.

### Ownership boundaries
Keep flow, authoritative simulation and scoring, input, entities, tuning, presentation and persistence in their
existing owners; cosmetics never decide collisions or rewards. Offline authority stays in Godot and online authority
on the dedicated server. WASD is reserved for player movement or camera panning, never abilities or menu actions;
leave it unbound when nothing moves, and update remapping, tutorials and hints when replacing conflicting shortcuts.

### Gameplay feedback and optional polish
Make actions, damage, rewards and outcomes readable with fitting cues. Reuse feedback and add effects only where they improve readability or the requested feel; particles, reward flights, shake and animated counters are optional. Keep overlays input-transparent, cosmetics independent of simulation and reduced-motion settings intact.

### Tutorial content boundary
Explain goals, controls and rules briefly in the game's language; simple games may use a start-screen hint.
A staged tutorial needs a working Skip that releases input/pause locks and remembers dismissal. Keep implementation values
and Tweak controls out of player instructions.

### Optional local leaderboard
Add local standings only when requested or integral to scoring and replay, and keep a useful existing one; changes
keep bounded records, once-only terminal submissions and deterministic ties. Online
rankings need an explicit request and the installed leaderboards guide; never provision a backend for an offline
game by default.

### Native verification
Reuse existing checks for changed gameplay, input, audio, saves, localization or tuning. For visual questions,
capture with the real renderer (`get_viewport().get_texture().get_image()` and `Image.save_png()`); headless Dummy
rendering proves nothing visual. Do not drive the Preview with browser automation, screenshots or self-tests unless
the user asks for browser debugging; use logs and report Web input, audio and layout as pending user acceptance.

### Concept work by request
Concepts are conditional, not a routine production step. Follow the Blueprint's recorded mockup choice and do not
offer a second concept workflow when the direction is already clear. For an explicit request, produce distinct,
coherent interpretations of the brief and keep the selected identity through revisions. The Game Concept Design flow
needs exactly three separate mockups generated under the recorded image consent, presented through the existing card
and explicitly approved; never label mockups as screenshots. Outside that flow, honor the requested count and
approval method. Mockup consent is not consent for production assets.
## Shared art and audio production

### Asset reuse and targeted production
Reuse suitable supplied, template and already available assets within their recorded permissions and the user's
source restrictions; template reuse needs no extra approval. Replace only assets that conflict with the requested
theme, lack necessary states or look visibly wrong. A new game or reskin does not require replacing every image,
animation, icon, track or effect unless the user asks for original art or a full replacement. Retain unused
reference files and supplied license notices, describe reused assets honestly, and update visible titles and themed
copy. Rename internal IDs only when needed, together with their consumers, saves and tests.

### Coherent scene and title art
Fulfill the requested visual scope with readable actors, hazards, UI and a coherent scene. Simple intentional
visuals are acceptable within the recorded source choice. Title and loading screens may reuse permitted game art
with live text; no separate key art is needed. A download is not integration: inspect the affected scene.

### 3D texture budgets
Budget the project's stored textures, including bytes embedded in GLB/glTF, not catalog masters or import limits.
Longest edge: 256–512 for small or distant props, 1024 by default, 2048 for close main actors or shared atlases,
4096 only for a justified visible difference. Never upscale, and keep UVs, channel packing and material bindings
intact. Remove replaced embedded bytes, keep ancestry and sync the changed files. If suitable tools are missing,
report it rather than replacing working assets. Claim only measured savings.

### Continuous animation and alignment
Use the approved animation method. AI continuous motion goes from approved static references to a guided
fixed-camera, in-place video to fixed-FPS extracted loops; independent poses need an approved stepped style. Keep a
shared canvas, scale, pivot and contact anchor across states and facings instead of per-state placement patches, and
keep raw masters outside the game. Check representative movement, reversal and ground contact with the native
renderer.

### Mandatory background removal for composited assets
Composited sprites, icons, portraits, cursors and loader art need clean real alpha that survives resize, import and
export; check changed edges on contrasting backgrounds at display scale. Opaque plates and terrain are exempt. Keep
words, numbers and HUD labels live, and never slice concept collages into runtime assets. Generate cursors on a
hot-pink or neon-green background and remove it before use.

### Seamless parallax backgrounds
Repeating layers must tile left and right without mirroring; check the joins between adjacent copies at the intended
scale after any crop, import or scale change. Side-scrollers keep a low scenic foreground above world actors and
below the HUD without hiding combat.

### Audio production as needed
BGM is optional unless requested or essential to the brief. Reuse a fitting permitted template, supplied or catalog
track when the source restrictions allow; silence with safe empty routes is valid, and a new Standard effort game is not a
reason to generate custom BGM. Honor explicit silence, supplied-only, AI-only and custom-music requests, and add only
useful event SFX. Generate audio only for an explicit request or a concrete
unmet need within recorded permissions: one usable result per needed track or cue, retried only for an actionable
correction. If requested custom music cannot be produced, report the unmet requirement. Audition changed audio and
ship compressed runtime audio, not raw WAV masters.

### Audio integration
Reuse the existing Music/SFX routing, gesture unlock and bounded voices, and keep empty routes safe across pause,
retry and scenes. New games that use audio keep the absolute base gains BGM 3× (+9.5424 dB) and SFX/UI 2×
(+6.0206 dB) over the inherited originals: place MusicBase/SfxBase before senders so each route crosses once,
replace old targets instead of stacking boosts, and keep the ≤0 dB guards, saved settings and explicit mixes.
Silent games need no gain plumbing, and existing delivered mixes stay unchanged. Spatial audio keeps real source
positions; music and global HUD sounds are separate. When music is used, keep the shared browser BGM adapter and
its native fallback.

### Asset generation mode gate
Recorded permissions govern generation regardless of mode or tools. Hybrid, AI or explicit permission covers
scoped visuals/SFX; mockup consent does not. Select models from live schemas/catalogs, not READMEs or asset history.
Images default to the latest available GPT Image; honor user choices. Tools record metadata automatically;
keep tool/provider/model/internal paths out of user copy and never guess model identity.

### Asset-production choice wording
Fast prototype follows its bounded workflow. New managed games call `webdev.init_project` once direction is clear,
with the complete brief; the canonical card settles unresolved choices, not parallel chat questions or a separate
Blueprint. Session-agent catalog search, access, downloads and delegation wait for successful initialization plus a
settled Blueprint, required plan and requested concept approval; in-flight or failed init is not success. Only
initialization's bounded metadata assessment may precede the card, never production downloads, generation or
integration. Standalone search or retrieval needs no project but does not justify speculative new-build sourcing.
Use the conversation language and call the catalog 游戏素材库 in Chinese. Recommend Hybrid mode for 2D, 3D and
unknown games. Card options for 2D/unknown: Manus game assets catalog, Hybrid mode, AI generation; Hybrid means
catalog plus AI art/audio, not scratch visuals. Known 3D: Game asset library and procedural generation, Hybrid mode,
AI generation. Only initialization's evidence-backed insufficient core-visual fit changes the first 3D label to
Procedural generation (Faster, lightweight, minimal token consumption); Unknown/sufficient fit or missing decoration
does not. Preserve historical accepted permissions; never infer them from option names or recommendations.
Only missing card support or a structured `planning_unavailable` receipt moves unresolved setup to one native
single-choice question; canonical state wins. For 2D/unknown: Manus game assets catalog, Hybrid (Recommended), AI
generated. Known 3D: Curated asset catalog and procedural (lowest token cost; catalog first, permitted gaps),
Hybrid (Recommended), AI generated (highest token cost). Keep these labels and this order, and record the answers.
No-questions sessions use
the recommended option within existing permission, which is not new consent. Additions to an existing game ask only
an unresolved production choice; delegation inherits constraints.
Accepted `choices.visualAssetSource: procedural` needs no repeated visual search/gap proof; audio follows its own
source restrictions and optional-production workflow. Catalog and Hybrid sourcing, including required-gap handling,
follows the game-asset-catalog Skill. Procedural permission never implies music composition.
## Shared Web runtime and delivery contract

### Browser-safe lifecycle
Bound and reuse voices, projectiles, particles, timers and subscriptions across pause, retry and scenes; change
pause or stream state on transitions, not every frame. Browser BGM uses the independent Web Audio renderer in
`scripts/manus/browser_bgm_player.gd`, never frame- or timer-fed PCM or finished-callback loops. It decodes once into
a bounded LRU AudioBuffer cache: call `prepare()` during loading or a transition before gameplay, then `play()`
reuses the buffer. Imported duplicates share an explicit original-path `buffer_key`, and changed PCM needs a new key.
Decode imported resources from the PCK, keep SFX in Godot and keep `thread_support=false`.
Route track, loop, position, pitch, mute, pause, duck, crossfade and Music/Master controls through the adapter.
External BGM does not inherit buses: the adapter mirrors player/bus volume, AudioEffectAmplify gain,
AudioEffectLimiter makeup and AudioEffectHardLimiter pre-gain only. HardLimiter ceiling/release and nonlinear
limiting are not reproduced; the independent browser renderer does not share Godot's combined BGM/SFX peak
protection. Positive HardLimiter pre-gain can clip browser BGM without the limiter's peak protection.
Reserve mix headroom and never rely on a Godot Master limiter to protect browser BGM. Keep native
Godot and the guarded Web fallback (`PLAYBACK_TYPE_STREAM` for long BGM) without overlapping backends; pending
autoplay waits for valid input, and stale starts are guarded. Stop voices and release removed cues with
`release_cached_stream()`, evict only unreferenced tracks, keep OS/bfcache suspend and restore, and release the context
on real teardown. Native tests cannot prove browser continuity through
main-thread stalls, so report that as pending user acceptance.

### Fast, recoverable startup
Keep the title and controls interactive with only the required fonts, UI, settings and small art. Defer scenes,
generation, media and decoding until needed, in bounded per-frame work; instantiate scenes on the main thread. Start
blocks duplicate transitions and reports recoverable content errors. Lazy PCK content reduces work, not transfer
bytes. Loading progress uses real bytes or phases and an indeterminate state for unknown totals; slow or stalled
notices are nonfatal, offer Retry, and clear on late success. When changing this mechanism, check cold load,
repeated Start, stall, unknown total, late success and Retry.

### Animated backgrounds without startup blocking
Show a small static placeholder immediately and retain it as fallback. Load animations asynchronously after the
title is interactive, outside Start/preload dependencies; swap on a ready frame, guarding exited scenes and stale
completions.

### Large explorable maps: presentation culling and live state
Offscreen simulation, pathfinding, orders, combat, economy, timers, replication, saves and minimap stay live. Cull
only cosmetics against current camera bounds, with sprite margins and separate fog; never remove gameplay actors,
projectiles or collision by distance. Reentry shows current state without replaying missed effects. Optimize measured
bottlenecks with existing spatial or dirty-region mechanisms; compare crowded, zoomed and revisited views to a
baseline rather than relying on empty-map FPS.

### Destructible props
Destroyed rubble and fragments render below actors in effective world z while keeping footprint, collision release
and reward position; reset restores the intact state.

### Game language
Use requested game language, else the user's Manus UI language (session default working language), then their
system language if known, then conversation language. Never use cloud sandbox locale.
New games use one language by default: pin this locale and disable inherited selectors and saved/OS/browser
auto-switching, overriding gameplay guides. Preserve existing-project localization; complete every exposed locale.
Requested Godot multilingual: [template localization](#requested-multilingual-support).
Completed single-language game: multilingual support is an optional follow-up; implement only on request.

### Tweak presentation language
For new Godot games, generate Tweak parameter labels, descriptions, category names, option labels
and human-readable units in the session default working language supplied by Node through Blueprint planning.
Reuse `data.state.language` from the canonical `webdev.config` GET `game/blueprint` already required after setup
or recovery; read it once if absent from context. Do not request a separate language parameter or infer it from
the game's language, conversation text, or sandbox/browser/OS locale. This overrides genre guides' Tweak
localization rules. Preserve existing projects' Tweak localization, including newly added controls, unless the user
asks to change it.

If init explicitly reports structured `planning_unavailable` with no saved Blueprint, use the session default
working language already known to the agent; only when unknown, use English. Pin the new catalog's presentation
language independently of the game's locale. Do not retry planning just to obtain a language or block the authorized
development. An ordinary Blueprint read error is not this fallback signal; follow the existing-game recovery
instructions and preserve existing Tweak text.

Keep parameter IDs, option values, source defaults, bounds and apply timing unchanged. Prevent the game's locale
from overriding the catalog's presentation language, including transport-generated description suffixes. This is
generation-time language selection; do not change the game's own language or add a player language selector or
live Manus-language switching.

### Requested multilingual support
Extend the selected template's localization system rather than adding a parallel one. Inspect its locale service,
catalogs and settings owner first: templates use different APIs, locale IDs and flat versus `{locale, entries}` JSON.
For example, Generic uses `autoload/i18n.gd` with `localization/en.json` and `zh-CN.json`; Tower Defense uses
`autoloads/i18n.gd`, `scripts/ui/components/ui_copy.gd` and `en-US.json`/`zh-CN.json`; Puzzle uses
`scripts/core/localization.gd` and `en.json`/`zh_CN.json`. Follow the initialized project's actual paths and API.

Keep stable keys, complete translations and matching whole-message placeholders for every exposed language;
route title, tutorial, HUD, settings, results and dynamic copy through the existing lookup/formatting service.
Keep player-facing words live, not baked into art. Extend the existing title/settings selector and persistence owner;
restore explicit saved choices before supported browser/OS detection and a documented fallback. Normalize locale IDs
to the catalogs actually shipped. A single-language game does not need runtime language detection or a selector.
Refresh visible controls through the template's signal or rebuild path without resetting gameplay, progress or audio
settings. Keep the Web loader and saved game locale aligned where the template has that bridge.

Include every exposed catalog in the export and verify bundled font coverage for its text. Reuse the template's
affected localization checks for key/placeholder parity, switching before and during play, saved choice after reload,
fallback behavior, dynamic text and layout. Exercise the exported resources too; font or boot checks alone do not
prove translations work. Support the requested languages, not an automatic EN/CN-only pair.

### Default typography
Default to the template's bundled theme: its display faces for titles/headings, its body face
(`assets/template/fonts/ui_{regular,medium,bold}.tres`) for UI text, then Noto Sans SC (6,547-codepoint repertoire)
for Chinese; Web loaders embed a small Noto Sans SC subset. Noto Sans SC is variable and its default instance is Thin,
so bind a weight through the template's font resources, not the raw file. Keep each bundled font's license
(`<Family>-OFL.txt`) beside it when copying, renaming or adding fonts; the Web export lists them on its Open Source
Licenses page. Missing template fonts restore from `assets.lock.json`; do not substitute system fonts. Existing
ManusCC0 projects keep their fonts unless the user asks for new typography. User-uploaded fonts are unrestricted: no
licensing, family, glyph-coverage, font-file, font-resource or font-pack size gates, and no rights review,
redistribution proof or notices. Theme or mood alone does not imply replacing the default fonts. This supersedes font
restrictions in frozen READMEs and local checks, including older ManusCC0 defaults: remove those policy gates when
integrating uploads, and keep only technical file-integrity and path checks.
Do not rebuild or re-audit unchanged fonts. Check changed text/layout/names; preserve name validation and saves.
Claim only supported character coverage.

### Viewport and background coverage
For fixed-coordinate Godot layouts set `[display]` `window/stretch/mode="canvas_items"`,
`window/stretch/aspect="keep"` and logical viewport size; retain working adaptive layouts. Input targets the active
surface, not letterbox margins. Check affected desktop resize, aspect and DPR. Isometric zoom uses ordinary wheel or
trackpad without Ctrl/Meta, with pointer-anchored picking and fixed-scale HUD. Mobile, touch and portrait work follows
the workflow's user-request rule even when template guides list those cases.

### Development Tweak when needed
The Addon generates the floating frosted-glass Tweak popover from the game's descriptors; never create an in-game
panel, launcher or F10 shortcut. Adapt the existing catalog to the requested game, extend it for meaningful tuning
and remove controls with no real consumer (at most 128). Keep one parameter manager with stable IDs, typed defaults,
bounds/options, localized labels, honest apply timing and existing run eligibility. Edits/reset affect only the
Addon draft. Apply validates and commits the whole patch without disk writes or preview reload; unchanged values
emit nothing. Gameplay boundaries consume pending values but never send catalogs. Do not add numeric revisions.
Save with Manus sends selected values to the task for source edits and the normal build/checkpoint flow; it does
not publish. Keep the adapter in `scripts/manus/preview/`, which release excludes with its autoload entry. Normal
player Settings and gameplay consumers remain. Existing genre rules below identify the actual parameter owners.

Follow [Tweak presentation language](#tweak-presentation-language) for the catalog and preview adapter.
For example, `tuning_transport.gd`'s `control_for` appends English timing text such as `Next Attack.` when mapping
apply modes. Localize that text in the project's adapter, preserving the actual apply boundary.

### Export constraints
Include runtime JSON/CSV/TXT through include_filter or Godot resources. Keep Web thread_support=false, resource paths discoverable, and the template-specific size budget. Use the Session port and the Addon preview/export workflow; do not hardcode the old Sandbox port or overwrite generated site/dist. Change identity through project.godot and the editable game loading shell, not generated HTML.

This complete current recipe overrides conflicting frozen README instructions, including genre-specific policy. Read historical README sections only for unchanged implementation details; use the receipt's GODOT_BIN and current Game delivery commands, never placeholder executable paths or retired hosting scripts.

## Playable reference and controls
`game-platformer-v58` is Yarn Platformer, a Godot 4.7.2 felt-cat platformer. Its loop is Title → Sunlit Nook → stage clear → Lofty Lounge → Victory; timer expiry produces Defeat. Stage 1 teaches traversal; Stage 2 requires 12 fish before its exit opens. Each course starts with 180 seconds. Falling or enemy contact returns the cat to its checkpoint and costs 10 seconds. Stage changes retain run score and reset actors, checkpoint, objective and timer; Restart starts a new run at Stage 1. Preserve terminal guards and once-only results when adding events.

| Course data | Authored content | Objective |
|---|---|---|
| `data/stages/sunlit_nook.json` | 7,800 px; 19 platforms, 3 trees, 7 reward blocks, 33 placed fish | Reach exit |
| `data/stages/lofty_lounge.json` | 8,500 px; 18 platforms, 3 trees, 10 reward blocks, 47 placed fish | Collect 12 fish and reach exit |

Default enemy budget is 11 per course. Actual-physics deterministic traversal takes roughly 61 seconds of simulated active play across both courses; this compact reference does not establish 10–15-minute content. Extend authored content when requested pacing requires it.

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | A/D or Left/Right | Left stick / D-pad | Floating joystick horizontal drag |
| Jump / short hop | Space or Up; release early | South button | Joystick upward drag |
| Yarn attack | J or X | West button | YARN button |
| Pause | Esc | Start | HUD pause |
| Skip tutorial | K | Back/View | Skip callout button |

W does not jump. Yarn uses cooldown, swept collisions, lifetime and count limits; missed shots disappear on their third ground rebound, while walls/robots consume them. Preserve coyote time, jump buffer, variable height, stomp and checkpoint recovery. Menus suppress gameplay input. Pause has Resume, Restart, Settings and Return to Title; destructive routes confirm progress loss. Modals restore prior pause/focus. Title provides profile/name, EN/CN, local standings, settings and tutorial replay.

## Implementation owners
| Owner | Responsibility |
|---|---|
| `scripts/game.gd`, `scenes/game.tscn` | Run/stage routing, construction, objective, timer, checkpoint, HUD, victory/defeat and retry/title routes |
| `scripts/stage_catalog.gd`, `data/stages/*.json` | Ordered stage IDs and validated geometry/spawn/objective definitions; add courses here, preserving one router |
| `scripts/player.gd`, `scripts/touch_input.gd` | Movement, buffered/coyote jumps, animation, attacks and touch state |
| `scripts/entities.gd`, `scripts/yarn_ball.gd` | Fish, robots, reward blocks, exit and bounded swept projectiles |
| `scripts/run_score.gd`, `scripts/save_store.gd` | Typed awards, finalized result snapshots, profile/local top ten, safe persistence and tutorial version |
| `scripts/tutorial_director.gd` | Event-driven, input-aware callouts; Skip, completion and replay |
| `scripts/title_screen.gd`, `scripts/pause_menu.gd` | Title and pause navigation |
| `scripts/menu_style.gd`, `scripts/menu_modal.gd`, `scripts/settings_panel.gd`, `scripts/leaderboard_panel.gd` | Shared styles, modal ownership, ordinary player settings and standings |
| `scripts/game_audio.gd`, `scripts/audio_catalog.gd` | Central music/cue mapping, eight one-shot voices and persistent category controls |
| `scripts/visual_effects.gd` | Bounded bursts/run dust, reduced motion, warm filter and screen feedback |
| `scripts/world_art.gd`, `scripts/viewport_policy.gd` | Camera-relative scenery and bounded responsive game surface |
| `scripts/surface_finish.gd`, `scripts/brick_surface.gd`, `scripts/sprite_grounding.gd` | Continuous terrain edges and alpha-aware foot/physics alignment |
| `config/tuning.json`, `scripts/tuning_store.gd`, `scripts/tuning_panel.gd` | Typed descriptors, validation, requested/active values, application timing, persistence and integrity |
| `autoload/i18n.gd`, `localization/en.json`, `localization/zh-CN.json` | `I18n.t`, complete EN/CN copy and persisted locale |

## Scores, onboarding and presentation
Awards are fish 100, robot 250, reward-block activation 50, and 10 per whole remaining second at stage clear; blocks also release fish. The default arithmetic ceiling is 19,650, including theoretical maximum time bonuses, not an attainable-score promise. `RunScore.finalize()` snapshots ID, score, stage, outcome, duration, timestamp, configuration hash and eligibility once. `SaveStore` keeps ten offline records ordered by score descending, then duration/timestamp/run ID ascending, rejecting malformed/duplicate records. There is no remote/global leaderboard. `user://save.json` owns profile, records and versioned tutorial state.

Names support at most 24 characters / 96 UTF-8 bytes, preserving supported mixed Latin/Simplified-Chinese text. Reject markup/control characters and unsupported glyphs without system-font substitution. The six tutorial steps react to movement, jump, yarn, hazard, checkpoint and pause, with an 18-second fallback. Skip never acquires an input lock or releases another modal's pause; completed tutorials stay completed across retry unless title replay is requested.

For user-uploaded fonts, apply the [shared typography policy](#default-typography) and update project-local font checks accordingly. EN/CN selection persists through runs and title return in `user://language.cfg` and Web storage; fresh profiles follow the system/browser language (`zh*` selects Chinese). Retain the template fonts with the bundled 6,547-codepoint Noto Sans SC fallback and separate loader subset. Rare Chinese names and Traditional Chinese are not guaranteed. Theme, loader, input validation and PCK font checks must agree.

`ViewportPolicy` defaults to centered 16:9 and offers adaptive 1:1–16:6 in player Settings. Small windows use physical-sized logical UI pixels; camera `world_scale()` preserves authored world framing and jump visibility. Menus reflow/scroll, and modal close controls stay outside scroll bodies. Touch starts inside the game surface and releases cleanly outside. Preserve shared foot pivots, flat walkable tops, seam-free tile joins and rounded whole-platform perimeters. Background/foreground camera factors are 0.08/0.16.

The 41 locked media files total 3,997,506 bytes. `assets/template/cat/` holds the calico/18 run frames, robots/fish/yarn/terrain/tree/scenery/title; `generated/foliage_near.webp` is the only retained original generated asset. Audio contains the supplied soundtrack and eight SFX; fonts are OFL subsets, each with its license file. The 24 superseded theme assets and restore/import entries are removed. Preserve retained provenance; unavailable original prompts, generator facts and editable media inputs are not newly produced evidence.

## Audio, effects and tuning
This sample retains its supplied 64.4-second Vorbis BGM and eight final SFX; reuse fitting supplied audio under its recorded permissions and the shared optional-production rules; do not describe it as newly generated custom BGM. `GameAudio` owns gesture unlock, idempotent title/game transitions, pause/UI handling, fade/duck and bounded voices through the browser BGM adapter/native fallback. Respawn reuses music; retry cleans up then restarts gameplay. `audio_catalog.gd` owns semantic cues/gains/cooldowns; controllers never allocate separate players. Player Master/Music/SFX/UI volumes and mutes persist in `user://audio.cfg`; debug multipliers do not overwrite them. Actual listening and browser acceptance remain separate from native/bridge checks.

`VisualEffects` caps 12 bursts / 48 particles per burst. Reduced motion replaces moving bursts with static feedback and suppresses trails. Feedback cannot alter physics/score and resets with stage/retry.

`config/tuning.json` and `scripts/tuning_store.gd` own the typed catalog, including display-mode enum choices.
`scripts/manus/preview/tuning_adapter.gd` translates it for the Addon. Camera/display/HUD/audio/filter/particles
apply live; attack cooldown at NEXT_ACTION; yarn at NEXT_SPAWN; enemies at NEXT_STAGE; movement/jump/time at NEXT_RUN.
Validate the whole patch against the authored jump envelope. Preserve sticky gameplay taint and the separate normal
player Settings whitelist/persistence; Addon Apply does not save debug overrides.

## Relevant verification hooks
Follow current Game delivery for finite checks, Preview, export, save and publication; these source hooks do not establish another export pipeline. Select meaningful affected hooks: `test/gameplay_contract.gd` covers stages/results/local records/tutorial; `test/traversal.gd` drives actual movement/jumps/attacks through both courses; `test/ui_contract.gd` covers menu input and modal ownership; `test/tweak_regression.gd` covers boundaries/integrity/release gates. Use existing audio, combat, VFX, terrain/grounding, responsive/framing and localization checks for changes in those owners. `test/acceptance_capture.gd` provides native EN/CN desktop/fixed-phone/adaptive-phone evidence; use representative affected states, not a mandatory fresh matrix. Tests that write saves need isolated temporary player storage; localization expects a `PlatformerLocalizationTests-` directory.

Keep `localization/*.json`, `config/*.json` and `data/stages/*.json` in export inclusion, and tests/authoring evidence outside the player pack. `scripts/check-exported-pack.mjs` checks the receipt-selected isolated PCK; its `--release-profile` mode applies only to the stripped release artifact. Relevant imported/exported checks and native captures do not prove deployed adoption, final listening or user Web acceptance. Preserve those distinctions at handoff.
