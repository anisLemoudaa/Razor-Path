# Legacy provenance
The supplied `/home/ubuntu/upload/index.html` was copied byte-for-byte to `legacy/index.html`. Embedded data URLs were decoded without modification.

| File | MIME | Bytes | SHA-256 |
|---|---|---:|---|
| `assets/legacy/embedded_01.mp3` | `audio/mpeg` | 6,287,262 | `75436144dc91abbe52466692546d11b53120261d087388eb24b16ee7086aabf7` |
| `assets/legacy/embedded_02.mp4` | `video/mp4` | 2,970,014 | `335992804a958c61d0beaaf50e613e81878563c30845278dc496956cf442d1e0` |
| `assets/legacy/embedded_03.png` | `image/png` | 11,707 | `f145a555da0926db2aca62ea491530bab1baf2a4be6141b1c561f636098df1ab` |
| `assets/legacy/embedded_04.png` | `image/png` | 5,942 | `97aa34284e0953841e63346ad15a702b52f42b009585fd0b67d7827bc559ec04` |
| `assets/legacy/embedded_05.png` | `image/png` | 8,367 | `a3a822f28cc7a07e7236a80bdb0f59754d73ad3e35a0087178c93d690791a90f` |
| `assets/legacy/embedded_06.jpg` | `image/jpeg` | 16,709 | `4adec4147bc734b5559be00a6fff4212c80df921bea26f6139928234114333b6` |
| `assets/legacy/embedded_07.jpg` | `image/jpeg` | 24,589 | `b30daaf924fa638ad068a69b6abc184a247db51d120f8b256bef01f20a3fbc8f` |
| `assets/legacy/embedded_08.jpg` | `image/jpeg` | 27,427 | `e851f854f5731e4de606929645ecc663cca6333c06c66aa1b53fff777d176cc3` |
| `assets/legacy/embedded_09.jpg` | `image/jpeg` | 25,384 | `2db90d001be05a5ec290b07f300d0abe702b2a03d59eed4f5c7faa8882bdece4` |
| `assets/legacy/embedded_10.jpg` | `image/jpeg` | 16,709 | `770c4d73958852e04b214c7308778c8636a91bdd9981148f138cc01d7da03e4c` |
| `assets/legacy/embedded_11.mp3` | `audio/mpeg` | 49,534 | `9ebc5d424fed9a14386985b238edf91e87ad51243a543e9812368a04c4040fdb` |

These files are reference assets extracted from the user-supplied prototype, not newly generated production assets.

## Razor Path reapplication assets

The following three JPEGs were supplied by the user as design references and are kept unchanged under `assets/reference/`:

| File | SHA-256 |
|---|---|
| `assets/reference/warm_world.jpg` | `508dd11312eaf9a0ed0757da13cabd143b40a50428ca6bb8e06fe2a6275465aa` |
| `assets/reference/razor_character_sheet.jpg` | `1d89846fe4e32f5b1288ac38b48001d5804463b3ff564da9d025b2e9904569c9` |
| `assets/reference/level16_monochrome.jpg` | `883d5f64748b66bde53f9c6f01087049a8029b4d76acce76effe907a512f663d` |

`tools/process_character_sheet.py` deterministically splits the supplied 4x2 character sheet into eight 160x292 RGBA frames. It removes only near-white pixels connected to the sheet edge (threshold 247), retains enclosed white character fills, and preserves the full common frame canvas as a shared pivot. The source Nunito WOFF2 is reused from the existing project template and copied to `assets/fonts/`; its SIL Open Font License is retained as `assets/fonts/Nunito-OFL.txt`. Two `FontVariation` resources combine Nunito with the corresponding Noto Sans Arabic fallback for Latin and Arabic UI coverage.

## Android app icon

The user-supplied 1254x1254 PNG is preserved unchanged as `assets/reference/razor_path_app_icon_source.png` (1,737,202 bytes; SHA-256 `2a6a8a7a5a5b47b3d2d11a7f7b49a692d2f92860ce6234c59bc1bb721cfd2059`). `tools/prepare_app_icon.py` creates the 1920x1920 launcher icon with Lanczos resizing and an adaptive foreground/background pair at 432x432. For the adaptive foreground, only near-black pixels (`max(R,G,B) < 12`) connected to the source image edge are made transparent; the original artwork and source file remain unchanged. The foreground artwork is contained in a centered 288x288 safe area, and the matching background samples the source corner color.

## Menu background

`assets/ui/razor_path_menu_backdrop.png` is a project-specific generated 16:9 illustration of warm, layered ruins, mountains, and suspended platforms, made as a clean background plate without text, logo, or interface controls. UI labels, panels, buttons, stage previews, and character sprites remain live Godot elements. The image is a 2560x1440 PNG; no supplied reference image was modified or embedded as a flattened screen.
