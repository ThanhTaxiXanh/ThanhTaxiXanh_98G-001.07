import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const script = readFileSync(
  new URL('../assets/scripts/youtube_filter.js', import.meta.url), 'utf8',
);

function page({ ad = false, duration = 120, muted = false, paused = false } = {}) {
  const video = { duration, currentTime: 10, muted, paused, ended: false };
  const state = { ad, clicks: 0, styles: [], timeouts: [], intervals: new Map(), observers: [] };
  const skip = { disabled: false, getClientRects: () => [1], click: () => state.clicks++ };
  const player = { querySelector: selector => selector === 'video' ? video : skip };
  const document = {
    querySelector: () => state.ad ? player : null,
    documentElement: {},
    head: { appendChild: style => state.styles.push(style) },
    createElement: () => ({
      remove() { state.styles = state.styles.filter(s => s !== this); },
    }),
  };
  let nextId = 0;
  const window = {
    setTimeout: fn => { state.timeouts.push(fn); return ++nextId; },
    setInterval: fn => { const id = ++nextId; state.intervals.set(id, fn); return id; },
    clearInterval: id => state.intervals.delete(id),
  };
  class MutationObserver {
    constructor(fn) { this.fn = fn; state.observers.push(this); }
    observe() { this.active = true; }
    disconnect() { this.active = false; }
  }
  const context = vm.createContext({ window, document, MutationObserver });
  vm.runInContext(script, context);
  return {
    video, state, window, context,
    filter: window.taxiYouTubeFilter,
    tick: () => [...state.intervals.values()].forEach(fn => fn()),
  };
}

test('an ordinary video is never sought, muted or skipped', () => {
  const p = page();
  p.filter.setEnabled(true);
  p.tick();
  assert.equal(p.video.currentTime, 10);
  assert.equal(p.video.muted, false);
  assert.equal(p.state.clicks, 0);
  assert.equal(p.state.styles.length, 1);
});

test('positive ad state uses the visible skip control without seeking or muting', () => {
  for (const muted of [true, false]) {
    const p = page({ ad: true, duration: 30, muted });
    p.filter.setEnabled(true);
    assert.equal(p.state.clicks, 1);
    assert.equal(p.video.currentTime, 10);
    assert.equal(p.video.muted, muted);
    p.state.ad = false;
    p.tick();
    assert.equal(p.video.muted, muted);
  }
});

test('paused or live videos are not sought and filtering never calls play', () => {
  const paused = page({ ad: true, paused: true });
  paused.filter.setEnabled(true);
  assert.equal(paused.video.currentTime, 10);
  assert.equal(paused.video.muted, false);
  assert.equal(paused.state.clicks, 0);
  const live = page({ ad: true, duration: Infinity });
  live.filter.setEnabled(true);
  assert.equal(live.video.currentTime, 10);
  live.filter.dispose();
  assert.equal(live.video.muted, false);
});

test('disabling releases styles, observers, timers and any mute change', () => {
  const p = page({ ad: true });
  p.filter.setEnabled(true);
  p.filter.setEnabled(false);
  assert.equal(p.state.styles.length, 0);
  assert.equal(p.state.intervals.size, 0);
  assert.equal(p.state.observers.some(o => o.active), false);
  assert.equal(p.video.muted, false);
  const time = p.video.currentTime;
  p.tick();
  assert.equal(p.video.currentTime, time);
});

test('SPA reinjection is idempotent and mutation bursts are throttled', () => {
  const p = page();
  p.filter.setEnabled(true);
  vm.runInContext(script, p.context);
  assert.equal(p.window.taxiYouTubeFilter, p.filter);
  assert.equal(p.state.intervals.size, 1);
  p.state.observers[0].fn();
  p.state.observers[0].fn();
  assert.equal(p.state.timeouts.length, 1);
  p.filter.setEnabled(false);
  p.state.timeouts[0]();
  assert.equal(p.state.clicks, 0);
});
