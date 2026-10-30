// Best-effort DOM filter for the public YouTube website. No video extraction,
// authentication changes, network interception or Android Auto host hooks.
(function () {
  'use strict';
  if (window.taxiYouTubeFilter) return;
  var enabled = false;
  var timer = null;
  var observer = null;
  var queued = false;
  var style = null;
  var mutedVideo = null;
  var originalMuted = false;
  var selectors = [
    'ytm-promoted-sparkles-web-renderer',
    'ytm-promoted-video-renderer',
    'ytm-ad-slot-renderer',
    'ytd-ad-slot-renderer',
    'ytd-promoted-sparkles-web-renderer',
    'ytd-promoted-video-renderer',
    'ytd-display-ad-renderer',
    '#masthead-ad',
    '.ytp-ad-overlay-container'
  ];

  function restoreAudio() {
    if (mutedVideo) {
      mutedVideo.muted = originalMuted;
      mutedVideo = null;
    }
  }

  function tick() {
    if (!enabled) return;
    // Do not seek a normal video just because a hidden skip button exists.
    var player = document.querySelector(
      '#movie_player.ad-showing, #movie_player.ad-interrupting, ' +
      '.html5-video-player.ad-showing, .html5-video-player.ad-interrupting'
    );
    if (!player) {
      restoreAudio();
      return;
    }
    var video = player.querySelector('video');
    if (!video || video.ended || video.paused) return;
    var skip = player.querySelector(
      '.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button'
    );
    if (skip && skip.getClientRects().length > 0 && !skip.disabled) skip.click();
    if (mutedVideo !== video) {
      restoreAudio();
      mutedVideo = video;
      originalMuted = video.muted;
    }
    video.muted = true;
    // Live/unknown durations cannot be skipped safely.
    if (Number.isFinite(video.duration) && video.duration > 0 &&
        video.currentTime < video.duration - 0.1) {
      try { video.currentTime = Math.max(0, video.duration - 0.05); } catch (_) {}
    }
  }

  function queueTick() {
    if (!enabled || queued) return;
    queued = true;
    window.setTimeout(function () {
      queued = false;
      tick();
    }, 120);
  }

  function setEnabled(value) {
    enabled = Boolean(value);
    if (observer) observer.disconnect();
    observer = null;
    if (timer !== null) window.clearInterval(timer);
    timer = null;
    if (style) style.remove();
    style = null;
    restoreAudio();
    if (!enabled) return;
    style = document.createElement('style');
    style.id = 'taxi-youtube-filter-style';
    style.textContent = selectors.join(',') + '{display:none!important;}';
    (document.head || document.documentElement).appendChild(style);
    observer = new MutationObserver(queueTick);
    observer.observe(document.documentElement, {
      subtree: true, childList: true, attributes: true,
      attributeFilter: ['class']
    });
    timer = window.setInterval(tick, 500);
    tick();
  }

  window.taxiYouTubeFilter = {
    setEnabled: setEnabled,
    dispose: function () { setEnabled(false); }
  };
}());
