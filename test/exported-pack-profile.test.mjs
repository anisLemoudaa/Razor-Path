import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

const preset = readFileSync(new URL('../export_presets.cfg', import.meta.url), 'utf8')
const extension = readFileSync(new URL('../native/razor_path.gdextension', import.meta.url), 'utf8')
const workflow = readFileSync(new URL('../.github/workflows/godot-ci.yml', import.meta.url), 'utf8')

test('Android export includes both native ABIs and verifies the signed debug package', () => {
  assert.match(preset, /architectures\/armeabi-v7a=true/)
  assert.match(preset, /architectures\/arm64-v8a=true/)
  assert.match(preset, /package\/signed=true/)
  assert.match(preset, /screen\/orientation=0/)
  assert.match(preset, /data\/stages\/razor_path_levels\.json/)
  assert.match(preset, /assets\/characters\/\*\.png/)
  assert.match(preset, /assets\/razor_path_theme\.tres/)
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
  assert.match(workflow, /apksigner"\s+verify --verbose/)
  assert.match(workflow, /actions\/upload-artifact@v4/)
})
