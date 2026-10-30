"""Optional real-Chromium check of the shipped JS against local HTML5 media.

Requires Python Playwright, its Chromium browser, and ffmpeg. This test routes
all page requests to local fixtures; it does not test the live YouTube service.
"""
import base64
import json
import pathlib
import subprocess
import tempfile
from playwright.sync_api import sync_playwright

repo = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    clip = pathlib.Path(directory) / 'sample.webm'
    subprocess.run([
        'ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i',
        'color=c=blue:s=160x90:r=15', '-f', 'lavfi', '-i',
        'sine=frequency=440:sample_rate=44100', '-t', '20', '-c:v', 'libvpx',
        '-b:v', '150k', '-c:a', 'libvorbis', '-y', str(clip),
    ], check=True)
    source = base64.b64encode(clip.read_bytes()).decode()
    html = '''<html><head><title>HTML5 fixture - YouTube</title></head><body>
    <button id="start" onclick="document.querySelector('video').play()">Play</button>
    <div id="movie_player" class="html5-video-player"><video controls src="data:video/webm;base64,SOURCE"></video>
    <button class="ytp-ad-skip-button" onclick="document.querySelector('#movie_player').classList.remove('ad-showing')">Skip</button></div>
    <script>window.messages=[];window.TaxiYouTubeMedia={postMessage:v=>messages.push(JSON.parse(v))};</script>
    </body></html>'''.replace('SOURCE', source)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        page = browser.new_page()
        errors = []
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.route('**/*', lambda route: route.fulfill(status=200, content_type='text/html', body=html))
        page.goto('https://m.youtube.com/watch?v=abcdefghijk')
        page.evaluate((repo / 'assets/scripts/youtube_media.js').read_text().replace(
            '__TAXI_BRIDGE_TOKEN__', json.dumps('smoke-document')))
        page.evaluate((repo / 'assets/scripts/youtube_filter.js').read_text())
        page.evaluate('taxiYouTubeFilter.setEnabled(true)')
        page.click('#start')
        page.wait_for_function("document.querySelector('video').currentTime > 0.1")
        page.evaluate('taxiYouTubeMedia.pause()')
        page.wait_for_function("document.querySelector('video').paused")
        page.evaluate('taxiYouTubeMedia.play()')
        page.wait_for_function("!document.querySelector('video').paused")
        page.evaluate('taxiYouTubeMedia.seek(2)')
        page.wait_for_function("document.querySelector('video').currentTime >= 2")
        page.evaluate('taxiYouTubeMedia.compact(true)')
        assert page.locator('video').is_visible()
        page.evaluate('taxiYouTubeMedia.compact(false)')
        page.evaluate("document.querySelector('#movie_player').classList.add('ad-showing')")
        page.wait_for_function("!document.querySelector('#movie_player').classList.contains('ad-showing')")
        result = page.evaluate('''() => ({playing: !document.querySelector('video').paused,
            muted: document.querySelector('video').muted,
            position: document.querySelector('video').currentTime,
            bridge: messages.some(m=>m.token==='smoke-document' && m.playing)})''')
        assert result['playing'] and not result['muted'] and result['bridge'], result
        assert result['position'] < 10, result  # A filter must never jump to the end.
        assert not errors, errors
        print(json.dumps({'chromium': browser.version, 'fixture': 'local HTML5 WebM', **result}))
        browser.close()
