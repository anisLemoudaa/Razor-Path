import assert from 'node:assert/strict';
import test from 'node:test';
import { gen, generateLevels, MIN, P, validate } from '../tools/razor-gen.js';

const levels = generateLevels();
const signature = (level) => JSON.stringify({
  W: level.W,
  H: level.H,
  surfaces: level.surfaces,
  ladders: level.ladders,
  spikes: level.spikes,
  saws: level.saws,
  ceilings: level.ceilings,
  checkpoints: level.checkpoints,
  stars: level.stars,
  kinds: level.kinds,
});

test('fixed n*7919+13 seed produces byte-for-byte repeatable level records', () => {
  for (const n of [1, 2, 31, 100, 250]) assert.deepEqual(gen(n), gen(n));
});

test('all 250 levels pass the source validator with empty failure lists', () => {
  assert.equal(levels.length, 250);
  const invalid = levels.map((level) => ({ n: level.n, failures: validate(level) })).filter((x) => x.failures.length);
  assert.deepEqual(invalid, []);
});

test('all 250 levels have distinct geometry signatures independent of level number', () => {
  assert.equal(new Set(levels.map(signature)).size, 250);
});

test('level dimensions and geometry use tile coordinates within the declared world', () => {
  for (const level of levels) {
    assert.ok(Number.isFinite(level.W) && level.W >= 240 && level.W < 700, `unexpected width at ${level.n}: ${level.W}`);
    assert.equal(level.H, 18);
    assert.equal(level.start, 3);
    assert.ok(level.finish > level.start && level.finish <= level.W);
    for (const surface of level.surfaces) {
      for (const value of Object.values(surface)) if (typeof value === 'number') assert.ok(Number.isFinite(value));
      assert.ok(['g', 'b', 'm', 'v'].includes(surface.t));
      assert.ok(surface.x >= 0 && surface.x <= level.W);
    }
  }
  assert.equal(P.tile, 64);
  assert.equal(P.speed, 5.625);
  assert.equal(P.jumpV, 10.9375);
  assert.equal(P.gravity, 28.90625);
  assert.equal(P.collisionBox.width, 0.5625);
  assert.equal(P.collisionBox.height, 1.84375);
});

test('every level has three validator-safe stars and at least one checkpoint', () => {
  for (const level of levels) {
    assert.equal(level.stars.length, 3, `level ${level.n}`);
    assert.ok(level.checkpoints.length > 0, `level ${level.n}`);
    for (const checkpoint of level.checkpoints) {
      assert.ok(level.surfaces.some((surface) => (surface.t === 'g' || surface.t === 'b') && checkpoint >= surface.x + 1 && checkpoint <= surface.x + surface.w - 1));
    }
  }
});

test('obstacle templates unlock progressively and never occur before their group threshold', () => {
  for (const [kind, firstLevel] of Object.entries(MIN)) {
    assert.ok(levels.slice(firstLevel - 1, firstLevel + 9).some((level) => (level.kinds[kind] || 0) > 0), `${kind} absent from its first eligible ten levels`);
    assert.ok(levels.some((level) => level.n < firstLevel && (level.kinds[kind] || 0) > 0) === false, `${kind} appears before level ${firstLevel}`);
  }
  for (const level of levels) for (const kind of Object.keys(level.kinds)) assert.ok(level.n >= MIN[kind], `${kind} appears too early at level ${level.n}`);
});
