# YouTube, PiP and Android Auto — 0.4.0

Updated: 2026-10-30 (Vietnam).

Target reported by the owner: Xiaomi Redmi Note 12 Pro, Android 13, Android Auto
18.1.164344, connected to a passenger-only Android Auto receiver. Receiver model
and firmware are not yet known. No physical phone/receiver or Desktop Head Unit
is attached to this development environment.

## Implementation status

| Capability | Implementation | Device acceptance |
| --- | --- | --- |
| Public YouTube on phone | Existing WebView search/link/fullscreen; foreground playback confirmed by owner for 0.3.0 | Recheck 0.4.0 |
| Background audio | Persistent browser session, media foreground service, audio focus and notification/lock-screen controls | Phone/Home/screen-lock check needed |
| Android PiP | Native activity support, manual button, automatic Home entry, compact video UI | Check PiP permission and transitions on Redmi |
| Android Auto audio | MediaBrowserService, recent-played catalog, actual playback metadata and controls | Enable sideloaded media testing, then connect receiver |
| Android Auto layout | Native navigation service, map surface, overview and calendar/QR/media panels; older-host fallback | Requires supported host and trusted installation |
| Reliable removal of all ads | Experimental DOM filtering | Still not guaranteed or verified on live ads |
| YouTube video/PiP on Android Auto | **Not implemented**; audio/media templates do not carry the video window | Remains an unresolved requirement |

Android phone PiP and the Android Auto media surface are separate features. The
native map surface renders navigation content; it does not project a WebView or
Android PiP window. Host layout determines the map/pane split and launcher entries.

## Phone check

1. Open YouTube in the app and play a public video. Verify its title and play state
   in the media notification and the dashboard media card.
2. Use the PiP button, return to the video, and press Home with automatic PiP on.
   The small window should show video rather than the app toolbar/webpage header.
3. Turn automatic PiP off, keep background audio on, then press Home or lock the
   screen. Test pause/play/seek/stop from the notification and headset.
4. Return to the dashboard while listening and reopen YouTube. The player should
   retain its session. Explicit Stop should end active foreground playback.
5. Disable background audio and verify a fully backgrounded non-PiP activity
   pauses. Audio-focus interruptions and headphone disconnect should also pause.

The browser attempts to resume a previously playing video only once if a hidden
page pauses it. Native pause/stop, disabled background audio and video end take
precedence. No visibility spoofing, stream extraction or account/region unlock is
used. YouTube and device policies can still prevent playback; a functioning
foreground service cannot guarantee the website will supply background media.

## Android Auto installation and check

Google's [car testing guide](https://developer.android.com/training/cars/testing)
allows developer **Unknown sources** testing for media apps. That exception does
not apply to Car App Library navigation templates; those require a trusted source
such as Play Internal App Sharing/Internal Testing for use in a real vehicle.
A sideloaded APK may therefore show the music entry while the map entry remains
unavailable. Production signing and Play distribution are not configured yet.

For the audio APK test, open Android Auto settings, enable its developer menu by
repeatedly tapping the version information, enable **Unknown sources**, and check
its launcher customization for ThanhTaxiXanh. Play a video once on the phone to
populate **YouTube gần đây**, reconnect the receiver and select that catalog.
Check car-first startup, play/pause/seek/previous/next and audio routing.

For a trusted/DHU navigation installation, verify the map and overview appear,
then test Home/Lịch/QR/Media panels, zoom, 3D/2D and requested GPS. Grant missing
location permission on the phone first. Tapping the map selects a destination;
**Xem tuyến ô tô** draws a manually requested route preview. This is not yet voice
turn-by-turn navigation or automatic rerouting. Car-requested GPS runs in a
location foreground service while the phone UI is hidden and stops on disconnect.

The overview contains Gregorian/lunar dates, the next event, a payment summary
and media controls, with a QR image when a valid request exists. Editing payment
fields or changing saved recipient details must hide an old request. Test QR
readability and media control layout at the receiver's actual resolution.

## Automated evidence and limits

Flutter tests cover media-message validation, persistent sessions, background
preference, PiP entry/exit/failure, recent history, media-browser commands,
consecutive skips, calendar snapshots, stale QR suppression and car GPS lifecycle.
Node tests execute the actual filter/media scripts against simulated DOMs.
Native Robolectric tests validate manifest declarations, template content limits,
and an Android-rendered QR bitmap decoded with ZXing from the current Dart encoder.

These are code/model tests and compilation checks. They do not establish live
YouTube ad blocking, MIUI process survival, GPU rendering on the receiver, the
receiver's launcher policy, or video/PiP projection in motion. APK test builds
use temporary debug signing; changing signer requires reinstalling and removes
local app data. Stable production signing remains a separate release task.

References: [Android PiP](https://developer.android.com/develop/ui/views/picture-in-picture),
[Android Auto media integration](https://developer.android.com/training/cars/media/auto),
[Android Auto platforms](https://developer.android.com/training/cars/platforms/android-auto),
[MapWithContentTemplate](https://developer.android.com/reference/androidx/car/app/navigation/model/MapWithContentTemplate).
