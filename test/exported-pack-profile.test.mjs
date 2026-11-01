import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, realpathSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'
import test from 'node:test'

test('only a verified managed standalone or explicit release option selects stripped gates', async () => {
  const source = readFileSync(new URL('../scripts/check-exported-pack.mjs', import.meta.url), 'utf8')
  const selector = source.slice(0, source.indexOf('\nconst godot ='))
    .replace(/^import \{ runGodotCheck \} from '[^']+'\n/m, '')
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'platformer-pack-profile-')))
  const previousRuntime = process.env.GAME_RUNTIME
  const previousArgs = process.argv
  let attempt = 0
  try {
    mkdirSync(join(root, 'scripts'))
    const installed = join(root, 'installed runtime')
    mkdirSync(join(installed, 'scripts'), { recursive: true })
    writeFileSync(join(installed, 'scripts/verify-game.mjs'),
      'export function verifiedPack(root) { return { path: root + process.env.PLATFORMER_TEST_PACK } }')
    const select = async args => {
      process.argv = ['node', 'check-exported-pack.mjs', ...args]
      const file = join(root, 'scripts', `selector-${++attempt}.mjs`)
      writeFileSync(file, selector + '\nexport { packPath, releaseProfile }\n')
      return import(pathToFileURL(file).href)
    }
    process.env.GAME_RUNTIME = installed
    process.env.PLATFORMER_TEST_PACK = '/dist/standalone/index.pck'
    assert.equal((await select([])).releaseProfile, true)
    process.env.PLATFORMER_TEST_PACK = '/dist/.preview/builds/current/index.pck'
    assert.equal((await select([])).releaseProfile, false)
    assert.equal((await select(['raw.pck'])).releaseProfile, false)
    const release = await select(['chosen.pck', '--release-profile'])
    assert.equal(release.packPath, join(root, 'chosen.pck'))
    assert.equal(release.releaseProfile, true)
    process.env.GAME_RUNTIME = join(root, 'missing-runtime')
    await assert.rejects(select([]), /Cannot find module/)
    delete process.env.GAME_RUNTIME
    assert.equal((await select([])).releaseProfile, false)
  } finally {
    process.argv = previousArgs
    if (previousRuntime === undefined) delete process.env.GAME_RUNTIME
    else process.env.GAME_RUNTIME = previousRuntime
    delete process.env.PLATFORMER_TEST_PACK
    rmSync(root, { recursive: true, force: true })
  }
})
