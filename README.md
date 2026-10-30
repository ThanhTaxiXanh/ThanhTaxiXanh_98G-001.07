# Taxi Auto

Flutter companion app for ThanhTaxiXanh, with a Vietnamese lunar calendar and a
VietQR generator ported from the two source files supplied by the owner. Android
application ID and namespace: `vn.thanhtaxixanh.car98g00107`.

The phone dashboard shows today's Gregorian/lunar date and Can Chi year in UTC+7.
The dashboard also shows today's events and upcoming events over the next 30 days,
with an entry to create, edit and delete events. Events can use Gregorian or
Vietnamese lunar dates, including annual recurrence.

The payment screen selects saved recipients and asks only for amount and note in
daily use. Recipients, default selection, default note and optional footer/center
logos are stored in the app's SQLite database. A searchable bank picker replaces
manual bank-name/BIN entry. A MapLibre 3D map, foreground GPS, address search and route preview are available.
A passenger YouTube browser now has a shared background playback session,
Android picture-in-picture and MediaSession/MediaBrowser integration. Android
Auto has an audio browser and a native map/dashboard template service.
YouTube video/PiP on the projected car screen remains **unresolved**; the audio
media service does not transport video.

## Development

Use Flutter **3.47.9 stable** (Dart 3.13.7), an Android SDK, and JDK 21.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
node --test scripts/*.test.mjs
dart run tool/generate_car_qr_fixture.dart
(cd android && ./gradlew :app:testDebugUnitTest --no-daemon)
flutter run
flutter build apk --release --split-per-abi
```

`pubspec.yaml` lists the dependencies requested by the Master Prompt. Calendar, payment and Riverpod are integrated; other feature dependencies
are reserved for later implementation. Commit `pubspec.lock` when updating packages.
Native Android platform files are included; do not regenerate them for each build.

## Structure

- `lib/app`: application composition and root widget.
- `lib/core`: shared errors, networking, storage and Android Auto adapters.
- `lib/features/{map,calendar,payment,media,settings}`: feature boundaries.
- Each feature has `data`, `domain`, and `presentation` layers. Domain will contain
  pure Dart models and repository contracts; data will implement contracts;
  presentation will use Riverpod providers to connect state and widgets.
- `lib/features/dashboard/presentation`: calendar dashboard and payment entry.
- `lib/features/calendar/domain/lunar_calendar.dart`: pure Dart lunar conversion.
- `lib/features/payment/domain/viet_qr.dart`: account-transfer TLV and CRC.
- `lib/features/payment/presentation`: recipient picker/editor, amount/note form,
  card renderer and PNG capture API.
- `lib/core/storage/app_database.dart`: SQLite schema for bank catalog, recipients
  and calendar events.
- `assets/data/vietqr_banks.json`: bundled public bank-name/BIN snapshot.
- `test/`: domain, launch/layout, payment-form and PNG export tests.

Empty directories with `.gitkeep` reserve layers for future implementations.

## GitHub Actions and APKs

The workflow in `.github/workflows/build.yml` runs on pushes to `main` and
`feature/**`, pull requests to `main`, and manual dispatch. It resolves the committed
lockfile, checks formatting, analyzes, tests, builds release APKs per ABI, and uploads
them as a `taxi-auto-apks-<run number>` artifact retained for 14 days.

Open a successful run in the repository's **Actions** tab and download its artifact.
GitHub requires sign-in to download artifacts. Pick `arm64-v8a` for most recent
physical Android devices, `armeabi-v7a` for supported older 32-bit devices, or
`x86_64` for a compatible emulator.

The initial release build uses Android's debug signing key for installation tests.
It is not configured for store distribution or stable update signing. A production
keystore and CI secrets must be configured before publishing a production release.

## Android Auto integration

The manifest declares both media and template capabilities. Audio uses
`audio_service`'s MediaBrowserService and the same cached Flutter engine as
MainActivity. A car can browse up to 20 recent played videos and send
play/pause/seek/previous/next/stop commands. A cold car launch loads recent public
video IDs from preferences without needing an Activity or Google sign-in.

`TaxiCarService` uses AndroidX Car App Library navigation templates and a
MapLibre renderer on the surface supplied by the car host. API 7+ combines the map
with an overview containing Gregorian/lunar dates, an event countdown, VietQR and
media status/actions. Home/Lịch/QR/Media actions open the detailed panels. Older
hosts use a navigation map with separate detail screens. The host controls pane
placement, scaling and content limits; the phone's 60/40 Flutter layout is not a
fixed pixel layout on Android Auto. The existing mt_carplay dependency does not
provide the map surface adapter, so that adapter is native AndroidX code.

The car renderer retains native attribution, follows requested GPS fixes, shows
route geometry, supports pan/zoom/3D/2D and lets a map tap choose a destination.
Calendar and QR data come from the same repositories and payment preview as the
phone. Editing an amount or changing account details hides a stale car QR.

For real-car installation, Google's [testing guide](https://developer.android.com/training/cars/testing)
requires a trusted source for Car App Library apps, such as Play Internal App
Sharing/Internal Testing. Android Auto's developer **Unknown sources** option
can enable sideloaded media apps; it does not authorize the native navigation
template service. A GitHub APK build alone does not establish launcher visibility
or Play eligibility. The release host validator uses AndroidX's published Google
host certificate allowlist. No physical phone/head unit is attached here; test
the launcher, audio routing and map viewport on the intended receiver.

## Offline bank catalog and saved recipients

The app ships a snapshot of `https://api.vietqr.io/v2/banks`, so the bank picker
works even on the first launch without Internet. The snapshot records its source
and fetch timestamp. The account editor's refresh button requests only this public
bank catalog, validates the complete response and commits it in one transaction.
Network or invalid-response failures keep the previous offline list intact.
Recipient/account details are not sent to this API. The release manifest includes
`INTERNET` permission for that optional refresh; gallery selection uses the platform
photo picker without a broad storage permission.

Add a recipient once using bank selection, account number and holder name. Save
multiple recipients, edit them, choose a default or delete one with confirmation.
Deleting the default promotes another saved recipient, if one exists. Optional
logos and a default note are saved per recipient. No real account or branding from
the reference screenshots is prefilled. Daily use needs only recipient selection,
an amount (including quick-amount buttons) and note, followed by **CẬP NHẬT**.
**XÓA SỐ TIỀN** generates an open-amount QR. Editing amount/note hides the old QR
until updating, so an old payment request is not displayed as the new one.

## Personal events

Use **Quản lý sự kiện** on the dashboard. Add, edit or delete an all-day event with
a title, date and notes. Select **Dương lịch** or **Âm lịch**; lunar input also has
an explicit leap-month flag and a Gregorian preview. Monthly and annual repeat
options keep the chosen calendar day/date. February 29 and dates in lunar leap months recur only in
years containing that date; they are not shifted to another day. The dashboard
shows the next occurrence of each event within 30 days (up to five entries), and
the management screen includes all events, including past one-off entries.

Event and recipient records survive app restarts and app updates that preserve
app data. Uninstalling the app or clearing its data removes this local database.
These are all-day calendar entries; notification alarms are not implemented.
Tests reopen a real SQLite database, exercise create/edit/delete/default changes,
check bank-cache failure handling, and cover the UI flows and lunar recurrence.

## Event countdown and defaults

Every upcoming occurrence shows **Còn N ngày** (or **Hôm nay**) with its actual
Gregorian and lunar dates. Countdown arithmetic uses Vietnam civil days (UTC+7),
not elapsed 24-hour periods from the current clock time. For example, from
2026-10-29 the next first lunar day is 2026-11-09: **Còn 11 ngày**, **1/10 (Âm lịch)**.
The count updates with the calendar clock and recurring events advance afterward.

Nineteen editable/deletable default observances are inserted once, alongside
existing personal events: monthly lunar mùng 1/rằm, New Year, International Women's
Day, Reunification Day, Labour Day, Children's Day, National Day, Vietnamese Women's
Day, Teachers' Day, Army Day, Christmas, Lunar New Year, Nguyên tiêu, Hùng Kings,
Đoan Ngọ, Vu Lan, Mid-Autumn and Kitchen Gods. These are observances, not an official
schedule of days off or compensating holidays. Deleted defaults are not recreated
on restart. Monthly lunar occurrences include leap months. Invalid days are
skipped rather than shifted. SQLite schema v2 adds monthly recurrence without
replacing existing accounts/events; tests exercise a v1 database upgrade.

## 3D map, GPS and route preview

**Mở bản đồ 3D** opens MapLibre Native with the OpenFreeMap Liberty vector style and
its extruded-building layer. Toggle **3D/2D**, pan/zoom/rotate, tap the GPS button or
search for an address. Initial camera center is Hanoi; it is not a fabricated user
location. Location permission is requested on the phone after pressing GPS.
Phone-only GPS stops when the app is backgrounded. GPS explicitly requested from
Android Auto uses a location foreground service/notification and continues while
the phone UI is hidden; it stops on car disconnect or GPS stop. A cold car session
asks the user to grant missing location permission on the phone. No background
location permission is declared. Speed is measured GPS speed in km/h,
with an accuracy indicator. Unknown speed is shown as a dash.

Address search uses explicit submissions to Nominatim in Vietnam, identifies the
app, caches repeated queries and paces new queries. It does not send autocomplete
requests. Selecting a result or long-pressing the map chooses a destination.
With an active GPS fix, **Xem tuyến ô tô** uses OSRM to draw a route with distance,
approximate duration and a list of maneuvers. This is a route preview: no automatic
rerouting, voice instructions or downloaded offline map
regions are implemented. Maps/search/routing need Internet and public service
availability. Retain the native attribution control and OSM/OpenFreeMap credits.

Overpass requests are bounded to a 1 km radius, a 15-second server budget and
80 output records. Refreshes are paced/cached. Node traffic signs and road-center
`maxspeed` records can be inspected under **OSM lân cận**, including distance and
snapshot time. They are nearby records, not a matched speed limit for the road
being driven. Missing/incomplete data and request failures are surfaced; a failed
query is not reported as an absence of signs. Current coordinates are sent to
Overpass/OSRM only for these requested map features; searches go to Nominatim.

Public endpoints: [OpenFreeMap](https://openfreemap.org/),
[Nominatim policy](https://operations.osmfoundation.org/policies/nominatim/),
[OSRM](https://project-osrm.org/), [Overpass](https://overpass-api.de/).
These shared public services are suitable for evaluation and have no service
availability guarantee; production deployments should choose suitable hosted or
self-hosted services and honor each provider's usage policy.

Map tests cover parsing, GPS permissions/pause, stale route-result suppression,
Haversine distance, speed units, cache/rate limits, failures and Flutter control
flows. The native viewport is replaced by a test surface in widget tests. Live
search and a short Hanoi route were checked successfully; the live Overpass probe
timed out and its failure handling is covered. Native 3D rendering and physical
GPS accuracy still need a real-device check; no emulator/physical device is
attached to this environment.

## Source ports and validation

`LunarCalendar.txt` contains Kotlin based on the Ho Ngoc Duc algorithm. The Dart
port retains its UTC+7 astronomical calculations and Can Chi names, with strict
Gregorian input validation, nonexistent lunar-date rejection, and a corrected
new-moon estimate boundary (the source could produce day 0 on 2054-05-07).
The supported Gregorian range is 1900–2099. Inverse conversion returns a UTC
`DateTime` carrying a civil date; it does not represent Vietnam midnight as an
instant. `forInstant` handles the UTC+7 day boundary explicitly.

Tests cover known Tet/leap-month dates, invalid leap flags, 29-day lunar months,
and round trips across every Gregorian day in the supported range. This verifies
conversion consistency; it is not an independent ephemeris certification.

`JavaScript tạo QR.txt` supplies the EMV TLV construction and CRC-16/CCITT-FALSE
logic. The Dart payload matches the inspected JavaScript section byte for byte for
the fixtures in `test/fixtures/viet_qr_source.json`. Their CRCs were independently
verified with Python's `binascii.crc_hqx` with initial value `0xffff`. Vietnamese
normalization, nested TLV fields, zero/open amount and the standard CRC check vector
are also tested. These are synthetic test accounts, not verified bank beneficiaries.

Differences from the shortcut: negative/text/fractional amounts are rejected rather
than silently stripping meaningful characters; thousands separators must be well
formed. Bank BINs require six digits and accounts require 1–19 ASCII alphanumeric
characters after whitespace removal. Zero retains the original open-amount
behavior. The note is normalized to ASCII and capped at 50 characters.

The QR matrix is generated by `pretty_qr_code`, replacing the shortcut's custom
version-1–10 encoder. `VietQrCard` renders the card and optional logos with a
four-module quiet zone, medium error correction normally and high with a center
logo. `captureVietQrPng` captures a painted `RepaintBoundary` to PNG bytes, replacing
`canvas.toDataURL`; callers can Base64-encode these bytes. The card export API is
tested, but a save/share button is not implemented. No live bank transfer has been
tested; verify recipient and amount in a banking app before using a generated code.

The reference image motivates the extruded-building map. MapLibre/OpenFreeMap now
provide that rendering path without an access token; building detail follows the
available vector data and is not a photorealistic building model.

## Background audio and Android PiP

The YouTube browser is owned by a process-level Riverpod session. Leaving its
phone route, switching apps or locking the screen no longer closes/pauses it by
default. A real media foreground service publishes playback, metadata and recent
videos. Notification/lock-screen/Android Auto commands control the same browser.
Calls/audio-focus interruptions and headphone disconnect pause playback.
The phone dashboard contains a compact media card for returning to the player.

Use the **PiP** action after opening a video. MainActivity declares native Android
PiP support, retains the shared audio engine, enables automatic PiP on Home while
the video screen is visible/playing, and hides page/Flutter controls in the small
window. The YouTube menu controls **Phát âm thanh nền** and **Tự bật PiP khi về
Home**. Explicit Stop releases the media session's active playback.

The media script makes at most one attempt to resume an already-playing public
video if the page pauses it when hidden. Native pause/stop and ended videos are
respected. It does not spoof document visibility, extract streams or unlock
restricted videos. YouTube/account restrictions and device battery policies can
still interrupt background playback; the actual Redmi/receiver needs a live
check. Android Auto receives an audio media surface, not an Android PiP window.

## Passenger YouTube browser (experimental)

The dashboard's YouTube action opens the public mobile YouTube website in a
WebView. Search by words or paste an HTTPS YouTube link, return to the YouTube
homepage, go back through browser history, retry failed loads, and use the
website's fullscreen video control. Fullscreen back exits the video view first.
The native media session can play a selected recent video without a page gesture.
Opening the app or a car template alone does not create a browser or fabricate
playing state; real media events drive the notification and car controls.

The shield action toggles the experimental ad filter. Its JavaScript hides known
promoted-card/overlay elements and attempts to skip a playing video only when
YouTube positively marks the player as showing an ad. Ordinary/paused videos and
unknown/live durations are not sought. A previous mute state is restored when an
ad ends or the filter is disabled. It does not remove creator sponsorships,
patch the YouTube APK, extract streams or intercept network responses. YouTube's
markup and ad delivery change: **ad-free playback is not guaranteed or verified
on the actual website**, and filtering can break playback. Turn it off to
diagnose a playback problem. This is not a completed 100% ad-free requirement.

Preferences retain filter/background/PiP choices, one sanitized public YouTube
location and up to 20 played-video IDs/titles. Account credentials and sign-in
redirect parameters are not saved. Cookies stay in the platform WebView.
Google can refuse sign-in in embedded WebViews. Public videos need no account,
and video availability still depends on YouTube, region and network access.
Top-level navigation is limited to exact HTTPS YouTube/Google consent/sign-in
hosts; arbitrary external sites and custom schemes are not opened. Web camera
and microphone requests are denied. Certificate errors use the platform's
default behavior.

**Current target:** a passenger-only receiver connected to a Xiaomi Redmi Note
12 Pro, Android 13, Android Auto 18.1.164344. Android phone PiP, car audio and
navigation-template code are implemented. Projected YouTube video and PiP on
Android Auto are not implemented. The receiver's app availability and composition
remain host-controlled.

See [YouTube compatibility and remaining acceptance checks](docs/youtube-compatibility.md).
Flutter tests cover URL boundaries, settings persistence, ordered writes, browser
control flow, fullscreen back, retry, background/PiP lifecycle and responsive layouts.
The native browser is replaced by a fake in widget tests; Node tests execute the
actual scripts against simulated ad/non-ad/background player states. Native tests
verify manifest services/PiP, pane content limits, stale-QR handling and decoding
an Android-rendered bitmap from the current Dart QR encoder using ZXing. These
checks do not validate live YouTube ads, the physical screen or car video.
