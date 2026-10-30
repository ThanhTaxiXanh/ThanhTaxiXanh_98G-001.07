# Taxi Auto

Flutter companion app for ThanhTaxiXanh, with a Vietnamese lunar calendar and a
VietQR generator ported from the two source files supplied by the owner. Android
application ID and namespace: `vn.thanhtaxixanh.car98g00107`.

The phone dashboard shows today's Gregorian/lunar date and Can Chi year in UTC+7.
The payment form generates an account-transfer QR and supports gallery images for
bank and center logos. Account information is currently session-only. Map, event
CRUD, persisted settings, media and Android Auto projection remain unimplemented.

## Development

Use Flutter **3.47.9 stable** (Dart 3.13.7), an Android SDK, and JDK 21.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
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
- `lib/features/payment/presentation`: form, card renderer and PNG capture API.
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

## Integration decisions still required

Android Auto projection uses host-controlled templates. Arbitrary Flutter widgets,
a fixed 60/40 split, QR images and WebViews cannot be assumed to work on the car
screen. Validate `mt_carplay` Android templates, supported app categories and the
target head unit before choosing an adapter. The initial screen runs on the phone;
no Android Auto car service or manifest integration has been implemented.

`flutter_map` supplies a 2D map. A true 3D map needs a different renderer. OSM tiles
and Overpass are community services with usage policies and incomplete coverage;
offline maps need an explicit tile source, download policy and cache. A nearby
`maxspeed` tag alone does not establish the speed limit of the current road.

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

The reference image shows a 3D vector map with extruded buildings. Matching it
requires a renderer such as MapLibre/Mapbox, a style and a compatible building-data
source. No 3D map or access token has been configured in this change.

Media needs an audio handler, Android foreground service and lifecycle setup.
Video playback needs parked-mode support from the host. YouTube integration needs
supported player APIs and host capabilities; no ad-removal patches are included.
