import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import test from 'node:test'

const preset = readFileSync(new URL('../export_presets.cfg', import.meta.url), 'utf8')
const extension = readFileSync(new URL('../native/razor_path.gdextension', import.meta.url), 'utf8')
const workflow = readFileSync(new URL('../.github/workflows/godot-ci.yml', import.meta.url), 'utf8')
const project = readFileSync(new URL('../project.godot', import.meta.url), 'utf8')

test('Android export includes both native ABIs and verifies the signed debug package', () => {
  assert.match(preset, /architectures\/armeabi-v7a=true/)
  assert.match(preset, /architectures\/arm64-v8a=true/)
  assert.match(preset, /package\/signed=true/)
  assert.match(preset, /screen\/orientation=0/)
  assert.match(preset, /data\/stages\/razor_path_levels\.json/)
  assert.match(preset, /assets\/characters\/\*\.png/)
  assert.match(preset, /assets\/razor_path_theme\.tres/)
  assert.match(project, /config\/icon="res:\/\/assets\/icons\/razor_path_app_icon\.png"/)
  assert.match(preset, /launcher_icons\/main_1920x1920="res:\/\/assets\/icons\/razor_path_app_icon\.png"/)
  assert.match(preset, /launcher_icons\/adaptive_foreground_432x432="res:\/\/assets\/icons\/razor_path_adaptive_foreground\.png"/)
  assert.match(preset, /launcher_icons\/adaptive_background_432x432="res:\/\/assets\/icons\/razor_path_adaptive_background\.png"/)
  assert.match(preset, /include_filter=.*assets\/icons\/\*\.png/)
  for (const icon of [
    'razor_path_app_icon.png',
    'razor_path_adaptive_foreground.png',
    'razor_path_adaptive_background.png',
  ]) {
    assert.ok(existsSync(new URL(`../assets/icons/${icon}`, import.meta.url)), `Missing ${icon}`)
  }
  assert.match(preset, /exclude_filter=.*legacy\/\*/)
  assert.match(preset, /exclude_filter=.*test\/\*/)

  for (const library of [
    'librazor_path.android.template_debug.arm32.so',
    'librazor_path.android.template_debug.arm64.so',
  ]) {
    assert.ok(extension.includes(library), `GDExtension must declare ${library}`)
    assert.ok(workflow.includes(library), `CI must verify ${library}`)
  }
  assert.match(workflow, /platform=android target=template_debug arch=arm32/)
  assert.match(workflow, /platform=android target=template_debug arch=arm64/)
  assert.match(workflow, /python3 -m pip install --user 'SCons==4\.8\.1'/)
  assert.match(workflow, /set \+o pipefail\s+yes \| sdkmanager --licenses >\/dev\/null\s+set -o pipefail/)
  assert.match(workflow, /apksigner"\s+verify --verbose/)
  assert.match(workflow, /actions\/upload-artifact@v4/)
})
