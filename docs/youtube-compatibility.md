# YouTube passenger-screen requirement

Updated: 2026-10-30 (Vietnam).

The Master Prompt requires YouTube without ads and video while the vehicle is
moving. The owner clarified that the display is dedicated to passengers and
receives Android Auto projection from a phone. This requirement remains open;
the regular-app WebView is a reusable first component, not proof of projection.

## Reported equipment

| Component | Owner-provided information |
| --- | --- |
| Phone | Xiaomi Redmi Note 12 Pro |
| Phone OS | Android 13 |
| Android Auto | 18.1.164344 |
| Display | Dedicated to passengers, Android Auto receiver |
| Display manufacturer/model | Not yet provided |
| Physical test connection | No phone/head unit attached to the development environment |

## Evidence and implementation boundary

1. [Android Auto overview](https://developer.android.com/training/cars/platforms/android-auto)
   documents host-controlled services/templates, parked activity projection on
   Android 15+, automatic app exit on vehicle motion, and trusted-install-source
   requirements for real vehicles. The Android 15+ activity path does not apply
   to the reported Android 13 phone.
2. [Add support for Android Auto to your parked app](https://developer.android.com/training/cars/parked/auto)
   currently lists games as the generally supported parked activity category.
   Declaring CAR_LAUNCHER does not make an arbitrary video/browser app compatible.
3. [Supported app categories](https://developer.android.com/training/cars)
   distinguishes media audio, templated navigation and parked video. Audio
   media controls do not carry a video surface.
4. The referenced [Fermata manifest](https://github.com/AndreyPavlenko/Fermata/blob/7d2bd42e0fea98a796ba069b56c48ef07d874549/fermata/src/auto/AndroidManifest.xml),
   [build configuration](https://github.com/AndreyPavlenko/Fermata/blob/7d2bd42e0fea98a796ba069b56c48ef07d874549/fermata/build.gradle)
   and [MainCarActivity](https://github.com/AndreyPavlenko/Fermata/blob/7d2bd42e0fea98a796ba069b56c48ef07d874549/fermata/src/auto/java/me/aap/fermata/auto/MainCarActivity.java)
   show a separate bundled aauto.aar SDK and CarActivity-based projection
   services. This differs from mt_carplay's standard AndroidX templates.
   The reviewed source does not prove compatibility with this owner's Android
   Auto version. No Fermata source/binary was copied into this project.
5. [Flutter Android WebView fullscreen documentation](https://pub.dev/packages/webview_flutter_android)
   describes embedding and fullscreen callbacks inside a regular activity. It
   does not provide an Android Auto transport.

The app does not request that the host disable motion restrictions or assume
that a non-default display is necessarily a verified passenger display.

## Acceptance status

| Requirement | Current status | Remaining evidence |
| --- | --- | --- |
| YouTube entry, search/link, back/home/reload | Implemented in regular app | Native phone test |
| Fullscreen video and lifecycle pause | Implemented using Android WebView | Native phone/display test |
| Filter preference and restored public location | Implemented and tested with mock preferences | App restart check on phone |
| Experimental ad filtering | Script behavior tested on simulated DOM | Live YouTube playback/ad tests; check for breakage |
| Reliably no YouTube ads | **Not verified / not complete** | Actual ad cases across several videos and sessions; maintain filter as YouTube changes |
| Display YouTube via Android Auto 18.1.164344 | **Not implemented / not complete** | Supported projection adapter and target-device connection |
| Continue video in motion on dedicated passenger display | **Not implemented / not complete** | Receiver capabilities and supported passenger display/session integration |

## Device validation sequence

1. Record the receiver model, firmware, wired/wireless connection type and whether
   it exposes an OEM-supported passenger video/display interface.
2. Verify the regular APK on the phone: search, public video, fullscreen,
   back/home, offline error/retry, screen rotation and background pause.
3. Check several ad-bearing videos with the filter on/off. Record visible ads,
   playback failures and whether ordinary content was skipped. Test without
   entering account credentials first; Google WebView sign-in may be refused.
4. Select a projection approach only after confirming receiver and phone support.
   A successful APK build, a media-service launcher icon or phone playback does
   not count as projected video acceptance.
5. Validate a supported passenger display/session using a stationary test setup
   or simulator that can report vehicle motion state. Confirm the driver-facing
   session remains separate. Do not ask the driver to watch or operate the video
   during a road test.

No new hardware purchase or Android OS update is assumed in this implementation.
