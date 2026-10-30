# Taxi Auto

Flutter companion app scaffold for ThanhTaxiXanh. The initial APK opens a Vietnamese
placeholder screen. Map, calendar, payment, media and settings are reserved modules;
their production features and Android Auto projection are not implemented yet.

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

`pubspec.yaml` lists the dependencies requested by the Master Prompt. Dependencies
are not wired into the initial screen. Commit `pubspec.lock` when updating packages.
Native Android platform files are included; do not regenerate them for each build.

## Structure

- `lib/app`: application composition and root widget.
- `lib/core`: shared errors, networking, storage and Android Auto adapters.
- `lib/features/{map,calendar,payment,media,settings}`: feature boundaries.
- Each feature has `data`, `domain`, and `presentation` layers. Domain will contain
  pure Dart models and repository contracts; data will implement contracts;
  presentation will use Riverpod providers to connect state and widgets.
- `lib/features/dashboard/presentation`: initial companion screen.
- `test/app_test.dart`: launch and layout checks for portrait and landscape screens.

Directories with `.gitkeep` reserve boundaries. They do not contain implementations.

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

The referenced `LunarCalendar.txt` and JavaScript QR shortcut were not supplied.
Obtain these before porting their algorithms. Calendar tests must cover Vietnam's
time zone, leap lunar months and year transitions. QR tests must verify EMV TLV
byte lengths, bank/account fields and CRC against independent known-good payloads.
The sample lunar date in the prompt is not a validated test vector. These domain
algorithms and their required unit tests remain future implementation work.

Media needs an audio handler, Android foreground service and lifecycle setup.
Video playback needs parked-mode support from the host. YouTube integration needs
supported player APIs and host capabilities; no ad-removal patches are included.
