import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

/* Razor Path level generator. All geometry is in tiles, with y measured up from the floor. */
export const P = {
  tile: 64,
  speedPxPerSecond: 360,
  jumpVelocityPxPerSecond: 700,
  gravityPxPerSecond2: 1850,
  speed: 360 / 64,
  jumpV: 700 / 64,
  gravity: 1850 / 64,
  collisionBoxPx: { width: 36, height: 118 },
  collisionBox: { width: 36 / 64, height: 118 / 64 },
  H: 18,
  margin: 1.5,
  maxRise: 2,
  minW: 2,
};
P.jumpH = +(P.jumpV ** 2 / (2 * P.gravity)).toFixed(2);
// Maximum horizontal gap at height difference r with the reference's 20% safety margin.
export const reach = (r) => +(0.8 * P.speed * (P.jumpV + Math.sqrt(Math.max(0, P.jumpV ** 2 - 2 * P.gravity * r))) / P.gravity).toFixed(2);
P.spike = reach(0);

export const GROUPS = [
  'تعليم أساسيات الحركة والقفز', 'قفزات أطول وعقبات بسيطة متتابعة', 'فجوات أعمق ومنصات مرتفعة', 'إدخال العقبات المتحركة', 'دمج عدة أنواع من العقبات',
  'مسارات ضيقة وتوقيت أدق', 'تحديات تعتمد على سرعة رد الفعل', 'مجموعات عقبات متتابعة', 'منصات متحركة وعقبات متزامنة', 'تحديات متقدمة تجمع المهارات السابقة',
  'مسارات أكثر تعقيدًا', 'قفزات دقيقة مع عقبات متحركة', 'تحديات تتطلب تخطيطًا مسبقًا', 'دمج أنواع متعددة من العقبات', 'تحديات متقدمة مع مساحات آمنة أقل',
  'مسارات طويلة ومتنوعة', 'عقبات متتابعة تتطلب توقيتًا دقيقًا', 'تحديات مركبة بمستوى صعوبة مرتفع', 'اختبارات متقدمة لجميع مهارات اللاعب', 'مراحل شديدة الصعوبة مع تدرج عادل',
  'تحديات احترافية', 'مسارات مركبة تتطلب دقة عالية', 'تحديات متقدمة تجمع عدة آليات', 'مراحل صعبة جدًا مع تصميم متقن', 'مراحل نهائية تختبر جميع مهارات اللاعب',
];
const A = ['الوادي', 'الممر', 'الهاوية', 'القمة', 'النفق', 'الجسر', 'الصحراء', 'الغابة', 'القلعة', 'المنحدر', 'الشرفة', 'الأطلال', 'الدرب', 'المحجر', 'السور'];
const B = ['الهادئ', 'المظلم', 'المنسي', 'الأخير', 'الصامت', 'المتصدع', 'الحاد', 'البعيد', 'الضائع', 'الرمادي', 'المهجور', 'العالي', 'الضيق', 'القديم', 'الغامض', 'المكسور', 'الأخضر'];
export const MIN = { gaps: 1, spikes: 1, stairs: 11, ladder: 21, drop: 21, movH: 31, movV: 31, saw: 31, tunnel: 41, bridge: 41, combo: 41, pillars: 51, chain: 71, gauntlet: 101 };

export function rng(seed) {
  let s = seed;
  return () => {
    s |= 0;
    s = (s + 0x6D2B79F5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function gen(n) {
  if (!Number.isInteger(n) || n < 1 || n > 250) throw new RangeError('Level number must be an integer from 1 to 250');
  const r = rng(n * 7919 + 13), d = (n - 1) / 249, Wt = Math.round(240 + n * 1.45);
  const L = {
    n, name: `${A[n % 15]} ${B[n % 17]}`, group: Math.ceil(n / 10), groupName: GROUPS[Math.ceil(n / 10) - 1], difficulty: +d.toFixed(3),
    surfaces: [], ladders: [], spikes: [], saws: [], ceilings: [], checkpoints: [], stars: [], kinds: {}, counts: {}, start: 3, finish: 0, W: 0, H: P.H,
  };
  let x = 0, y = 3, dl = d, last = [], lastCP = 0;
  const R = (a, b) => a + r() * (b - a);
  const I = (a, b) => Math.floor(R(a, b + 1));
  const adv = (v) => { x = +(x + v).toFixed(1); };
  const S = (t, o) => { const s = Object.assign({ t }, o); L.surfaces.push(s); return s; };
  const pw = () => Math.max(2, Math.round(5.5 - dl * 3.5 + R(0, 2)));
  const dyr = () => n < 11 ? 0 : n < 21 ? I(-1, 1) : I(-2, 2);
  // Keep a small reserve below the computed 20%-margin reach; round down so rounding cannot invalidate a jump.
  const gp = (dy) => {
    const safeMax = Math.max(0.1, reach(dy) - 0.2);
    const desired = Math.min(safeMax, 1.8 + dl * 1.6 + R(-0.3, 0.3), 4.2);
    return +(Math.floor(desired * 10) / 10).toFixed(1);
  };
  const step = (dy, w, t) => {
    const ny = Math.max(3, Math.min(13, y + dy));
    dy = ny - y;
    adv(gp(dy));
    const s = S(t || 'g', { x, y: ny, w });
    adv(w); y = ny;
    return s;
  };
  const sp = () => +R(1.2, 2 + dl * 1.5).toFixed(1);
  const spikes = (k, sw) => {
    // One spike span may not exceed the physics-derived safe horizontal range.
    sw = sw || Math.min(I(2, n < 11 ? 2 : 3), Math.floor(P.spike));
    k = k || (n < 11 ? 1 : I(1, dl > 0.4 ? 3 : 2));
    const ex = I(0, 2), w = 3 + k * sw + 3 * (k - 1) + ex;
    const s = step(dyr(), w);
    let c = s.x + 1.5 + I(0, ex);
    for (let i = 0; i < k; i += 1) { L.spikes.push([+c.toFixed(1), y, sw]); c += sw + 3; }
  };
  const T = {
    gaps() { const k = I(2, 4); for (let i = 0; i < k; i += 1) step(dyr(), pw()); },
    spikes() { spikes(); },
    stairs() { const k = I(2, 4 + (dl > 0.5 ? 1 : 0)), up = y < 8 ? 1 : -1; for (let i = 0; i < k; i += 1) step(up * (n >= 21 && dl > 0.3 ? I(1, 2) : 1), pw()); },
    ladder() {
      if (y > 8) return T.drop();
      step(0, Math.max(4, pw()));
      const h = Math.min(I(4, dl > 0.5 ? 6 : 5), 13 - y);
      if (h < 4) return;
      const ux = +(x - 1).toFixed(1), w = pw() + 2;
      L.ladders.push([+(x - 0.5).toFixed(1), y, y + h]);
      S('g', { x: ux, y: y + h, w, lad: true });
      x = +(ux + w).toFixed(1); y += h;
    },
    drop() { const k = I(1, 2); for (let i = 0; i < k; i += 1) step(-I(2, 3), pw()); },
    movH() {
      const rr = Math.round(R(3, 5 + dl * 3)), w = Math.max(3, Math.round(4 - dl)), x0 = +(x + gp(0)).toFixed(1);
      S('m', { x: x0, x1: +(x0 + rr).toFixed(1), y, w, sp: sp() });
      x = +(x0 + rr + w + gp(0)).toFixed(1);
      const W = Math.max(3, pw() + 1); S('g', { x, y, w: W }); adv(W);
    },
    movV() {
      const h = Math.min(I(3, 5), 13 - y);
      if (h < 3) return T.movH();
      const x0 = +(x + gp(0)).toFixed(1);
      S('v', { x: x0, y0: y, y1: y + h, w: 4, sp: sp() });
      x = +(x0 + 4 + gp(0)).toFixed(1); y += h;
      const W = pw() + 1; S('g', { x, y, w: W }); adv(W);
    },
    saw() { const pl = I(4, 6 + Math.round(dl * 3)), s = step(0, pl + 5), x0 = +(s.x + 2.5).toFixed(1); L.saws.push([x0, +(x0 + pl).toFixed(1), y, sp()]); },
    tunnel() { const cl = I(8, 12), s = step(0, cl + 7); L.ceilings.push([s.x + 3.5, cl, y + 3]); if (dl > 0.3) L.spikes.push([s.x + 3.5 + Math.floor(cl / 2) - 1, y, Math.min(2, Math.floor(P.spike))]); },
    bridge() { const k = I(3, 5); for (let i = 0; i < k; i += 1) step(0, I(3, 4), 'b'); },
    pillars() { const k = I(3, 5); for (let i = 0; i < k; i += 1) step(i % 2 ? -1 : 1, 2); },
    combo() { spikes(1, 2); step(I(0, 1), 2); spikes(1, 2); },
    chain() { spikes(I(3, 4), 2); },
    gauntlet() { const c = Object.keys(T).filter((k) => MIN[k] <= n && k !== 'gauntlet' && k !== 'ladder' && k !== 'gaps'); for (let i = 0; i < 3; i += 1) T[c[I(0, c.length - 1)]](); },
  };
  const names = Object.keys(T).filter((k) => MIN[k] <= n), wt = {};
  names.forEach((k) => { wt[k] = 0.4 + r() * 1.6; });
  const pick = () => {
    let c = names.filter((k) => !last.includes(k));
    if (!c.length) c = names;
    let v = r() * c.reduce((a, k) => a + wt[k], 0);
    for (const k of c) { v -= wt[k]; if (v <= 0) return k; }
    return c[c.length - 1];
  };
  const rest = (len) => { const s = step(0, len); L.checkpoints.push(s.x + Math.floor(len / 2)); lastCP = x; };
  S('g', { x: 0, y: 3, w: 16 }); x = 16;
  while (x < Wt - 20) {
    dl = Math.min(1, d * 0.75 + 0.25 * x / Wt);
    const k = pick(); T[k](); L.kinds[k] = (L.kinds[k] || 0) + 1; last = [last[last.length - 1], k];
    if (x - lastCP >= 95) rest(10);
    else if (r() < 0.5 - 0.4 * d && x - lastCP > 40) step(0, 6);
  }
  const f = step(0, 16); L.finish = f.x + 10; L.W = x; L.H = P.H;
  const staticSurfaces = L.surfaces.filter((s) => s.t === 'g' || s.t === 'b');
  const free = (s, c) => L.spikes.every((k) => k[1] !== s.y || c < k[0] - 2 || c > k[0] + k[2] + 2)
    && L.saws.every((k) => k[2] !== s.y || c < k[0] - 2.5 || c > k[1] + 2.5)
    && !L.checkpoints.some((q) => Math.abs(q - c) < 1.5);
  // Select three safe static ledges, one near each progress quantile.
  L.stars = [0.2, 0.5, 0.8].map((p) => {
    let best = null, bestDistance = Infinity;
    for (const s of staticSurfaces) {
      if (s.w < 4 || s.x < 8 || s.x > L.W - 20) continue;
      for (let c = s.x + 1.5; c <= s.x + s.w - 1.5; c += 0.5) {
        if (!free(s, c)) continue;
        const distance = Math.abs(c - p * L.W);
        if (distance < bestDistance) { bestDistance = distance; best = [+c.toFixed(1), +(s.y + 1.2).toFixed(1)]; }
      }
    }
    return best;
  }).filter(Boolean);
  L.counts = {
    spikes: L.spikes.length, saws: L.saws.length, tunnels: L.ceilings.length, ladders: L.ladders.length,
    movers: L.surfaces.filter((s) => s.t === 'm' || s.t === 'v').length,
    gaps: L.surfaces.length - 1 - L.ladders.length - L.surfaces.filter((s) => s.t === 'm' || s.t === 'v').length * 2,
  };
  return L;
}

const bounds = (s) => s.t === 'm'
  ? { L: s.x, R: s.x1 + s.w, b: s.y, t: s.y }
  : s.t === 'v' ? { L: s.x, R: s.x + s.w, b: s.y0, t: s.y1 } : { L: s.x, R: s.x + s.w, b: s.y, t: s.y };

export function validate(L) {
  const failures = [], surfaces = L.surfaces, staticSurfaces = surfaces.filter((s) => s.t === 'g' || s.t === 'b'), m = P.margin;
  surfaces.forEach((s, i) => {
    const b = bounds(s);
    if (b.R - b.L < P.minW - 1e-6) failures.push(`عرض صغير ${b.L}`);
    if (b.t > 14 || b.b < 3) failures.push(`ارتفاع خارج النطاق ${b.L}`);
    if (!i) return;
    const p = bounds(surfaces[i - 1]);
    if (s.lad) {
      if (!L.ladders.some((ladder) => ladder[0] >= Math.max(p.L, b.L) && ladder[0] <= Math.min(p.R, b.R) && ladder[1] === p.t && ladder[2] === b.b)) failures.push(`سلم مفقود ${b.L}`);
    } else {
      const gap = +(b.L - p.R).toFixed(2), rise = b.b - p.t;
      if (gap < 0) failures.push(`تداخل ${b.L}`);
      if (gap > reach(rise) + 1e-6) failures.push(`فجوة ${gap} مع صعود ${rise} عند ${p.R}`);
      if (rise > P.maxRise) failures.push(`صعود ${rise} عند ${b.L}`);
    }
  });
  const inSurface = (k0, k1, yy) => staticSurfaces.some((s) => s.y === yy && k0 >= s.x + m - 1e-6 && k1 <= s.x + s.w - m + 1e-6);
  L.spikes.forEach((k) => { if (k[2] > P.spike || !inSurface(k[0], k[0] + k[2], k[1])) failures.push(`أشواك ${k}`); });
  L.saws.forEach((k) => { if (!inSurface(k[0], k[1], k[2])) failures.push(`منشار ${k}`); });
  L.ceilings.forEach((c) => { if (!staticSurfaces.some((s) => s.x <= c[0] && s.x + s.w >= c[0] + c[1] && c[2] - s.y >= 3)) failures.push(`نفق ${c}`); });
  L.checkpoints.forEach((x) => { if (!staticSurfaces.some((s) => x >= s.x + 1 && x <= s.x + s.w - 1) || L.spikes.some((k) => Math.abs(k[0] + k[2] / 2 - x) < 4)) failures.push(`حفظ ${x}`); });
  if (L.stars.length !== 3 || L.stars.some((q) => !staticSurfaces.some((s) => Math.abs(s.y + 1.2 - q[1]) < 1e-6 && q[0] >= s.x + 1 && q[0] <= s.x + s.w - 1))) failures.push('نجوم');
  [L.start, L.finish].forEach((x) => { if (!staticSurfaces.some((s) => x >= s.x && x <= s.x + s.w)) failures.push(`بداية/نهاية ${x}`); });
  return failures;
}

export function generateLevels() { return Array.from({ length: 250 }, (_, i) => gen(i + 1)); }
export function writeLevels(outputFile = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data/stages/razor_path_250.json')) {
  const payload = { tile: P.tile, physics: P, levels: generateLevels() };
  fs.mkdirSync(path.dirname(path.resolve(outputFile)), { recursive: true });
  fs.writeFileSync(outputFile, `${JSON.stringify(payload, null, 2)}\n`);
  return payload;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  const target = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data/stages/razor_path_250.json');
  const result = writeLevels(target);
  console.log(`Wrote ${result.levels.length} levels to ${target}`);
}
