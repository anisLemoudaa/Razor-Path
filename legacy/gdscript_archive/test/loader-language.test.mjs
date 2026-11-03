import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const shell = readFileSync(new URL('../web/loading.html', import.meta.url), 'utf8')
const selection = shell.match(/let locale = [^\n]*;[\s\S]*?const zh = locale === 'zh-CN';/)[0]

function selected(saved, language = 'zh-TW', unavailable = false, languages) {
  return vm.runInNewContext(`${selection}\nlocale`, {
    navigator: { language, ...(languages ? { languages } : {}) },
    localStorage: { getItem(key) {
      assert.equal(key, 'calico-language')
      if (unavailable) throw new Error('Storage unavailable')
      return saved
    } },
  })
}

test('fresh or invalid stored preference follows the browser language', () => {
  for (const [system, expected] of [['zh-CN', 'zh-CN'], ['zh-TW', 'zh-CN'], ['zh', 'zh-CN'], ['en-US', 'en'], ['fr-FR', 'en']]) {
    for (const saved of [null, '', 'unsupported']) assert.equal(selected(saved, system), expected)
  }
  assert.equal(selected(null, 'zh-CN', true), 'zh-CN')
  assert.equal(selected(null, 'en-US', true), 'en')
  // The first preferred language wins over the legacy single-language property.
  assert.equal(selected(null, 'en-US', false, ['zh-CN', 'en-US']), 'zh-CN')
  assert.equal(selected(null, 'zh-CN', false, ['en-GB', 'zh-CN']), 'en')
})

test('loader preserves the language explicitly chosen in game', () => {
  assert.equal(selected('zh-CN', 'en-US'), 'zh-CN')
  assert.equal(selected('en', 'zh-CN'), 'en')
})

test('runtime browser preference lookup reads the loader key and tolerates unavailable storage', () => {
  const runtime = readFileSync(new URL('../autoload/i18n.gd', import.meta.url), 'utf8')
  const lookup = runtime.match(/func _read_web_locale\(\) -> Variant:[\s\S]*?JavaScriptBridge\.eval\(("[^\n]*"), true\)/)
  assert.ok(lookup, 'runtime reads the saved browser choice before synchronizing it')
  const expression = JSON.parse(lookup[1])
  for (const saved of [null, '', 'unsupported', 'en', 'zh-CN']) {
    const actual = vm.runInNewContext(expression, { localStorage: { getItem(key) {
      assert.equal(key, 'calico-language')
      return saved
    } } })
    assert.equal(actual, saved)
  }
  assert.equal(vm.runInNewContext(expression, { localStorage: { getItem() { throw new Error('Storage unavailable') } } }), null)
})
