import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import vm from 'node:vm';

const script = readFileSync(new URL('../assets/scripts/youtube_media.js', import.meta.url), 'utf8');
function page({ paused = false } = {}) {
  const state = { hidden: false, plays: 0, messages: [], timers: [], intervals: [], marked: new Set() };
  function element(parent = null) {
    return {
      parentElement: parent, attributes: new Map(),
      setAttribute(name, value) { this.attributes.set(name, value); state.marked.add(this); },
      removeAttribute(name) { this.attributes.delete(name); },
    };
  }
  const root = element();
  const body = element(root);
  const listeners = new Map();
  const video = Object.assign(element(body), {
    paused, ended: false, duration: 120, currentTime: 12, readyState: 4,
    addEventListener(name, fn) { listeners.set(name, [...(listeners.get(name) || []), fn]); },
    emit(name) { for (const fn of listeners.get(name) || []) fn(); },
    play() { state.plays++; this.paused = false; this.emit('playing'); return Promise.resolve(); },
    pause() { this.paused = true; this.emit('pause'); },
  });
  const documentEvents = new Map();
  const document = {
    documentElement: root, body, head: { appendChild() {} }, title: 'Video Test - YouTube',
    get hidden() { return state.hidden; },
    createElement: () => element(),
    addEventListener: (name, fn) => documentEvents.set(name, fn),
    querySelector(selector) {
      if (selector === 'video') return video;
      if (selector.includes('ad-showing')) return null;
      return { textContent: selector.includes('owner') ? 'Test Channel' : 'Video Test' };
    },
    querySelectorAll(selector) {
      return selector === 'video,audio' ? [video] : [...state.marked];
    },
  };
  const window = {
    location: { href: 'https://m.youtube.com/watch?v=abcdefghijk' },
    TaxiYouTubeMedia: { postMessage: value => state.messages.push(JSON.parse(value)) },
    setInterval: fn => state.intervals.push(fn),
    setTimeout: fn => state.timers.push(fn),
  };
  vm.runInNewContext(script, { window, document, WeakSet, URL });
  return { state, video, body, root, api: window.taxiYouTubeMedia,
    visible() { state.hidden = false; documentEvents.get('visibilitychange')(); } };
}

test('media reports actual playing state and native pause/play/seek control the same video', () => {
  const p = page();
  assert.equal(p.state.messages.at(-1).playing, true);
  assert.equal(p.state.messages.at(-1).id, 'abcdefghijk');
  p.api.pause();
  assert.equal(p.video.paused, true);
  assert.equal(p.state.messages.at(-1).playing, false);
  p.api.play();
  assert.equal(p.state.plays, 1);
  p.api.seek(60);
  assert.equal(p.video.currentTime, 60);
  p.api.seek(10000);
  assert.equal(p.video.currentTime, 120);
});

test('a background page pause resumes a previously playing video only once', () => {
  const p = page();
  p.state.hidden = true;
  p.video.pause();
  assert.equal(p.state.timers.length, 1);
  p.state.timers.shift()();
  assert.equal(p.state.plays, 1);
  p.video.pause();
  assert.equal(p.state.timers.length, 0);
  p.visible();
  p.api.play();
  p.state.hidden = true;
  p.video.pause();
  assert.equal(p.state.timers.length, 1);
});

test('native pause, disabled background audio and ended videos never trigger a resume', () => {
  for (const scenario of ['nativePause', 'disabled', 'ended', 'initiallyPaused']) {
    const p = page({ paused: scenario === 'initiallyPaused' });
    p.state.hidden = true;
    if (scenario === 'disabled') p.api.configureBackground(false);
    if (scenario === 'ended') { p.video.ended = true; p.video.emit('ended'); }
    if (scenario === 'nativePause') p.api.pause(); else p.video.pause();
    assert.equal(p.state.timers.length, 0, scenario);
    assert.equal(p.state.plays, 0, scenario);
  }
});

test('PiP compact mode preserves the original video node and restores page attributes', () => {
  const p = page();
  p.api.compact(true);
  assert.equal(p.root.attributes.has('data-taxi-compact'), true);
  assert.equal(p.video.parentElement, p.body);
  assert.equal(p.video.attributes.has('data-taxi-video'), true);
  p.api.compact(false);
  assert.equal(p.root.attributes.has('data-taxi-compact'), false);
  assert.equal(p.video.attributes.has('data-taxi-video'), false);
  assert.equal(p.body.attributes.has('data-taxi-video-ancestor'), false);
});
