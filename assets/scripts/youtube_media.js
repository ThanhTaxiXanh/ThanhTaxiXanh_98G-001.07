(function () {
  'use strict';
  if (window.taxiYouTubeMedia) return;
  var attached = new WeakSet();
  var compact = false;
  var pendingPlay = 0;
  var backgroundAudio = true;
  var desiredPlaying = false;
  var backgroundResumeAttempted = false;
  var style = document.createElement('style');
  style.textContent =
    'html[data-taxi-compact] body{background:#000!important;margin:0!important;}' +
    'html[data-taxi-compact] body *{visibility:hidden!important;}' +
    'html[data-taxi-compact] [data-taxi-video-ancestor]{transform:none!important;' +
    'contain:none!important;overflow:visible!important;}' +
    'html[data-taxi-compact] video[data-taxi-video]{visibility:visible!important;' +
    'position:fixed!important;inset:0!important;width:100vw!important;' +
    'height:100vh!important;max-height:none!important;object-fit:contain!important;' +
    'z-index:2147483647!important;}';
  (document.head || document.documentElement).appendChild(style);

  function send(value) {
    if (window.TaxiYouTubeMedia) window.TaxiYouTubeMedia.postMessage(JSON.stringify(value));
  }
  function video() { return document.querySelector('video'); }
  function publish() {
    var v = video();
    if (!v) return;
    var url = new URL(window.location.href);
    var path = url.pathname.match(/^\/(?:shorts|live)\/([a-zA-Z0-9_-]{11})/);
    var id = url.searchParams.get('v') || (path && path[1]);
    if (!id || !/^[a-zA-Z0-9_-]{11}$/.test(id)) return;
    if (document.querySelector('.html5-video-player.ad-showing, #movie_player.ad-showing')) return;
    var title = document.querySelector(
      'h1.ytd-watch-metadata, .slim-video-information-title, ytm-watch-metadata h1'
    );
    var artist = document.querySelector(
      '#owner #channel-name a, .slim-owner-channel-name'
    );
    send({
      id: id,
      title: (title && title.textContent.trim()) ||
        document.title.replace(/\s*[-–]\s*YouTube$/, ''),
      artist: artist ? artist.textContent.trim() : 'YouTube',
      playing: !v.paused && !v.ended,
      buffering: !v.paused && v.readyState < 3,
      ended: v.ended,
      position: Number.isFinite(v.currentTime) ? v.currentTime : 0,
      duration: Number.isFinite(v.duration) && v.duration > 0 ? v.duration : null
    });
  }
  function markCompact(v) {
    v.setAttribute('data-taxi-video', '');
    var parent = v.parentElement;
    while (parent && parent !== document.documentElement) {
      parent.setAttribute('data-taxi-video-ancestor', '');
      parent = parent.parentElement;
    }
  }
  function play() {
    desiredPlaying = true;
    pendingPlay = 8;
    attemptPlay();
  }
  function attemptPlay() {
    var v = video();
    if (!v || pendingPlay <= 0) return;
    pendingPlay = 0;
    var result = v.play();
    if (result && result.catch) result.catch(function () {
      send({ error: 'Trang YouTube chưa cho phát. Mở video trên điện thoại rồi thử lại.' });
    });
  }
  function pause() {
    desiredPlaying = false;
    pendingPlay = 0;
    document.querySelectorAll('video,audio').forEach(function (v) { v.pause(); });
    publish();
  }
  function tick() {
    var v = video();
    if (v && !attached.has(v)) {
      attached.add(v);
      desiredPlaying = !v.paused && !v.ended;
      v.addEventListener('playing', function () { desiredPlaying = true; });
      v.addEventListener('ended', function () { desiredPlaying = false; });
      v.addEventListener('pause', function () {
        if (document.hidden && backgroundAudio && desiredPlaying &&
            !v.ended && !backgroundResumeAttempted) {
          // Resume only an already-playing public video, once per background
          // transition. Do not poll, spoof visibility, or start new content.
          backgroundResumeAttempted = true;
          window.setTimeout(function () {
            if (document.hidden && backgroundAudio && desiredPlaying) {
              var result = v.play();
              if (result && result.catch) result.catch(function () {
                send({error: 'YouTube đã dừng phát nền. Thử tiếp tục video bằng PiP.'});
              });
            }
          }, 150);
        } else if (!document.hidden) desiredPlaying = false;
      });
      ['play', 'playing', 'pause', 'ended', 'waiting', 'seeked', 'loadedmetadata']
        .forEach(function (name) { v.addEventListener(name, publish); });
    }
    if (v && compact) markCompact(v);
    if (pendingPlay > 0) {
      pendingPlay--;
      attemptPlay();
    }
    publish();
  }
  window.taxiYouTubeMedia = {
    play: play,
    pause: pause,
    configureBackground: function (value) { backgroundAudio = Boolean(value); },
    seek: function (seconds) {
      var v = video();
      if (v && Number.isFinite(v.duration) && Number.isFinite(seconds)) {
        v.currentTime = Math.max(0, Math.min(seconds, v.duration));
        publish();
      }
    },
    compact: function (value) {
      compact = Boolean(value);
      if (compact) document.documentElement.setAttribute('data-taxi-compact', '');
      else {
        document.documentElement.removeAttribute('data-taxi-compact');
        document.querySelectorAll('[data-taxi-video-ancestor],[data-taxi-video]')
          .forEach(function (e) {
            e.removeAttribute('data-taxi-video-ancestor');
            e.removeAttribute('data-taxi-video');
          });
      }
      if (compact && video()) markCompact(video());
    },
    publish: publish
  };
  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) backgroundResumeAttempted = false;
  });
  window.setInterval(tick, 1500);
  tick();
}());
