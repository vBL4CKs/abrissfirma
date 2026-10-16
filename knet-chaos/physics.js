/* KNET CHAOS — deterministic, renderer-independent slingshot physics. */
(function (root, factory) {
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.KnetPhysics = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var STEP = 1 / 120;
  var GRAVITY = -8;
  var MAX_SPEED = 12;
  var RADIUS = 0.24;
  var WORLD = { left: -4.4, right: 4.4, bottom: -6, top: 6 };

  // Coordinates describe world units. Platform y is its TOP, not its centre.
  // Each goal is an additional platform, separate from the platforms array.
  var LEVELS = [
    {
      name: 'Der erste Platsch', subtitle: 'Zieh zurück. Lass deinen Blob fliegen!',
      hint: 'Zieh den Blob nach links unten und lass los.',
      start: { x: -2.8, y: -3.4 }, goal: { x: 2.55, y: -1.15, w: 1.65 },
      platforms: [{ x: -2.8, y: -3.64, w: 1.7, h: 0.65, type: 'stone' }],
      rings: [{ x: 0, y: 0.15, r: 0.62 }], hazards: []
    },
    {
      name: 'Mitten durch!', subtitle: 'Sammle den Ring auf dem Weg zu deinem Freund.',
      hint: 'Ein hoher Bogen bringt dich über die kleine Insel.',
      start: { x: -2.8, y: -3.4 }, goal: { x: 2.7, y: -0.3, w: 1.4 },
      platforms: [
        { x: -2.8, y: -3.64, w: 1.7, h: 0.65, type: 'stone' },
        { x: -0.5, y: -2.6, w: 1.25, h: 0.6, type: 'stone' }
      ],
      rings: [{ x: -0.1, y: 1.2, r: 0.64 }], hazards: []
    },
    {
      name: 'Boing nach oben', subtitle: 'Die grüne Feder gibt dir neuen Schwung.',
      hint: 'Versuche einen sanften Schuss auf die grüne Feder.',
      start: { x: -2.9, y: -3.4 }, goal: { x: 2.75, y: 1.6, w: 1.45 },
      platforms: [
        { x: -2.9, y: -3.64, w: 1.6, h: 0.65, type: 'stone' },
        { x: -0.6, y: -2.6, w: 1.5, h: 0.65, type: 'bounce' }
      ],
      rings: [{ x: 1.1, y: 1.9, r: 0.63 }], hazards: []
    },
    {
      name: 'Vorsicht, Wackelball!', subtitle: 'Finde deinen Bogen um die Stachelkugel.',
      hint: 'Mit einem hohen Bogen kommst du über die Kugel.',
      start: { x: -2.8, y: -3.4 }, goal: { x: 2.65, y: 0.4, w: 1.5 },
      platforms: [
        { x: -2.8, y: -3.64, w: 1.7, h: 0.65, type: 'stone' },
        { x: 0, y: -2.55, w: 1.1, h: 0.6, type: 'stone' }
      ],
      rings: [{ x: -0.55, y: 2, r: 0.65 }],
      hazards: [{ x: 0.2, y: -0.05, r: 0.48, motion: { axis: 'x', amplitude: 0.9, speed: 1.7 } }]
    },
    {
      name: 'Doppelter Glanz', subtitle: 'Zwei Ringe, ein Flug. Schaffst du beide?',
      hint: 'Mit genug Höhe liegt der zweite Ring auf deinem Rückweg nach unten.',
      start: { x: -2.8, y: -3.4 }, goal: { x: 2.7, y: 1.8, w: 1.45 },
      platforms: [
        { x: -2.8, y: -3.64, w: 1.7, h: 0.65, type: 'stone' },
        { x: -0.4, y: -2.4, w: 1.4, h: 0.65, type: 'bounce' },
        { x: 1.25, y: -0.65, w: 0.9, h: 0.65, type: 'stone' }
      ],
      rings: [{ x: -1.25, y: 1.65, r: 0.62 }, { x: 1.2, y: 3.5, r: 0.64 }], hazards: []
    },
    {
      name: 'Die Chaos-Krone', subtitle: 'Dein Freund wartet ganz oben!',
      hint: 'Ziele steil nach oben. Die Feder hilft bei einem kurzen Schuss.',
      start: { x: -2.9, y: -3.4 }, goal: { x: 2.65, y: 2.65, w: 1.5 },
      platforms: [
        { x: -2.9, y: -3.64, w: 1.6, h: 0.65, type: 'stone' },
        { x: -0.6, y: -1.8, w: 1.55, h: 0.7, type: 'bounce' },
        { x: 1.15, y: -2.2, w: 0.8, h: 0.6, type: 'stone' }
      ],
      rings: [{ x: -1.3, y: 2.1, r: 0.64 }, { x: 1.1, y: 4.15, r: 0.65 }],
      hazards: [{ x: 1.4, y: 0.2, r: 0.47, motion: { axis: 'y', amplitude: 0.75, speed: 1.9 } }]
    }
  ];

  function levelIndex(index) {
    return Math.max(0, Math.min(LEVELS.length - 1, Math.floor(Number(index) || 0)));
  }

  function createState(index) {
    index = levelIndex(index);
    var level = LEVELS[index];
    return {
      levelIndex: index, status: 'ready',
      ball: { x: level.start.x, y: level.start.y, vx: 0, vy: 0, r: RADIUS },
      time: 0, flightTime: 0, shots: 0, bounces: 0,
      ringHits: [], events: [], lossReason: null,
      _accumulator: 0, _ticks: 0, _flightTicks: 0
    };
  }

  function launch(state, vx, vy) {
    if (state.status !== 'ready' || !Number.isFinite(vx) || !Number.isFinite(vy)) return false;
    var speed = Math.sqrt(vx * vx + vy * vy);
    if (speed < 0.5) return false;
    if (speed > MAX_SPEED) { vx *= MAX_SPEED / speed; vy *= MAX_SPEED / speed; }
    state.ball.vx = vx;
    state.ball.vy = vy;
    state.status = 'flying';
    state.shots += 1;
    state.flightTime = 0;
    state._flightTicks = 0;
    state._accumulator = 0;
    state.events = [];
    return true;
  }

  function reset(state) {
    var fresh = createState(state.levelIndex);
    Object.keys(state).forEach(function (key) { delete state[key]; });
    Object.assign(state, fresh);
    return state;
  }

  function hazardAt(hazard, time) {
    var result = { x: hazard.x, y: hazard.y, r: hazard.r };
    if (hazard.motion) {
      var motion = hazard.motion;
      result[motion.axis] += Math.sin(time * motion.speed) * motion.amplitude;
    }
    return result;
  }

  // Earliest segment/circle contact; catches fast motion between fixed steps.
  function circleContact(ax, ay, bx, by, cx, cy, radius) {
    var dx = bx - ax, dy = by - ay, fx = ax - cx, fy = ay - cy;
    var c = fx * fx + fy * fy - radius * radius;
    if (c <= 0) return 0;
    var a = dx * dx + dy * dy;
    if (a < 1e-12) return null;
    var b = 2 * (fx * dx + fy * dy);
    var discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return null;
    var t = (-b - Math.sqrt(discriminant)) / (2 * a);
    return t >= 0 && t <= 1 ? t : null;
  }

  function lose(state, reason) {
    state.status = 'lost';
    state.lossReason = reason;
    state.ball.vx = 0;
    state.ball.vy = 0;
    state.events.push({ type: 'lose', x: state.ball.x, y: state.ball.y, reason: reason });
  }

  function fixedStep(state) {
    var oldTime = state.time;
    state._ticks += 1;
    state.time = state._ticks * STEP;
    if (state.status !== 'flying') return;
    state._flightTicks += 1;
    state.flightTime = state._flightTicks * STEP;
    var level = LEVELS[state.levelIndex], ball = state.ball;
    var ax = ball.x, ay = ball.y;
    ball.vy += GRAVITY * STEP;
    var bx = ax + ball.vx * STEP, by = ay + ball.vy * STEP;
    var first = null;

    function topContact(platform, kind) {
      if (ball.vy >= 0 || ay - ball.r < platform.y - 1e-8 || by - ball.r > platform.y) return;
      var t = (ay - ball.r - platform.y) / (ay - by);
      var x = ax + (bx - ax) * t;
      if (Math.abs(x - platform.x) > platform.w / 2 + ball.r * 0.35) return;
      if (!first || t < first.t) first = { t: t, kind: kind, x: x, y: platform.y + ball.r };
    }

    topContact(level.goal, 'goal');
    level.platforms.forEach(function (platform) { topContact(platform, platform.type); });
    level.hazards.forEach(function (hazard) {
      var before = hazardAt(hazard, oldTime), after = hazardAt(hazard, state.time);
      var t = circleContact(ax - before.x, ay - before.y, bx - after.x, by - after.y, 0, 0, ball.r + hazard.r);
      if (t !== null && (!first || t < first.t)) {
        first = { t: t, kind: 'hazard', x: ax + (bx - ax) * t, y: ay + (by - ay) * t };
      }
    });

    var endX = first ? first.x : bx, endY = first ? first.y : by;
    level.rings.forEach(function (ring, index) {
      if (state.ringHits.indexOf(index) !== -1) return;
      // A ring rewards flying through the opening, not merely grazing its outside.
      if (circleContact(ax, ay, endX, endY, ring.x, ring.y, Math.max(0.15, ring.r - ball.r * 0.45)) !== null) {
        state.ringHits.push(index);
        state.events.push({ type: 'ring', x: ring.x, y: ring.y, index: index });
      }
    });
    ball.x = endX;
    ball.y = endY;

    if (first) {
      if (first.kind === 'goal') {
        state.status = 'won'; ball.vx = 0; ball.vy = 0;
        state.events.push({ type: 'win', x: ball.x, y: ball.y });
      } else if (first.kind === 'bounce') {
        ball.y += 0.002;
        ball.vx *= 0.98;
        ball.vy = Math.min(11, Math.max(8.8, Math.abs(ball.vy) * 1.12));
        state.bounces += 1;
        state.events.push({ type: 'bounce', x: ball.x, y: first.y - ball.r });
      } else {
        lose(state, first.kind === 'hazard' ? 'hazard' : 'platform');
      }
    }
    if (state.status === 'flying') {
      if (ball.x < WORLD.left - ball.r || ball.x > WORLD.right + ball.r || ball.y < WORLD.bottom - ball.r || ball.y > WORLD.top + ball.r) {
        lose(state, 'outside');
      } else if (state.flightTime >= 8) {
        lose(state, 'timeout');
      }
    }
  }

  function step(state, dt) {
    state.events = [];
    if (dt === undefined) dt = STEP;
    if (!Number.isFinite(dt) || dt <= 0) return state;
    // Bound catch-up after a suspended browser tab; ordinary frame intervals are exact.
    state._accumulator += Math.min(dt, 0.25);
    while (state._accumulator >= STEP - 1e-10) {
      state._accumulator -= STEP;
      if (state._accumulator < 0) state._accumulator = 0;
      fixedStep(state);
    }
    return state;
  }

  function predict(index, vx, vy, time) {
    var state = createState(index);
    if (Number.isFinite(time) && time > 0) {
      state._ticks = Math.round(time / STEP);
      state.time = state._ticks * STEP;
    }
    var points = [{ x: state.ball.x, y: state.ball.y }];
    if (!launch(state, vx, vy)) return points;
    for (var i = 0; i < 960 && state.status === 'flying'; i += 1) {
      step(state, STEP);
      if (i % 4 === 3 || state.status !== 'flying') points.push({ x: state.ball.x, y: state.ball.y });
    }
    return points;
  }

  return {
    LEVELS: LEVELS, STEP: STEP, GRAVITY: GRAVITY, MAX_SPEED: MAX_SPEED,
    RADIUS: RADIUS, WORLD: WORLD, createState: createState, launch: launch,
    step: step, predict: predict, reset: reset, hazardAt: hazardAt
  };
});
