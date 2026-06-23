# ⌚ Wear OS support

Hiddify runs on Wear OS watches (built and verified on a **Pixel Watch 4 / Wear OS 6**).
The watch shares the existing Flutter/Dart logic and Go core; only a trimmed,
round-screen UI and the watch ↔ phone glue are new.

The watch build uses a dedicated entry point — `lib/main_wear.dart` — and is
produced from the same project:

```bash
flutter build apk --debug -t lib/main_wear.dart --target-platform android-arm
```

> `--target-platform android-arm` (armeabi-v7a) matters: current Wear OS watches
> are 32-bit ARM. Building `android-arm64` produces an APK that crashes on the
> watch with a missing `libflutter.so`.

## What you get on the watch

- **Round-screen UI** — a centered connect/disconnect button, the active
  profile, live status and traffic, a profile list, and a "no profile yet" hint.
- **Rotary input** (the rotating crown) — scrolls the profile list and switches
  pages; swipe-to-dismiss returns to the home screen.
- **Quick-toggle Tile** — add it from the tile carousel to connect/disconnect
  with one tap.
- **Watch-face Complication** — a circular complication that shows the connected
  country's flag and ping while the VPN is on, and the Hiddify icon when off
  (refreshes about once a minute, tap to open the app).

## Two ways to use it

### 1. Remote control for the phone's VPN (recommended)

The watch controls the **phone's** Hiddify over the Wear Data Layer: toggle
connection, pick a profile, and see the phone's live status/traffic on your
wrist. This protects the phone's traffic fully (a real tun-VPN on the phone) and
is what most "Wear OS VPN" apps actually do.

### 2. Standalone proxy on the watch (Wi-Fi)

The watch can also run the core itself in **proxy mode** (`ProxyService`, no
`VpnService`) over its own Wi‑Fi, and point the system HTTP proxy at the local
mixed port so apps route through the tunnel. This requires a one-time permission
grant (see below).

## Profile sync (phone → watch)

Add a profile/subscription in the phone app and it is mirrored to the watch over
the Wear Data Layer (`watch_connectivity` application context): subscriptions
travel as a URL (the watch core fetches/updates them), manual configs as raw
config. The watch imports any profile it doesn't already have.

Both apps must share the same `applicationId` (`app.hiddify.com`) and signing
key for the Data Layer to connect.

## Enabling the system proxy (standalone mode)

A normal app can't set the device-wide HTTP proxy at runtime, so grant the
permission once over adb (no root):

```bash
adb shell pm grant app.hiddify.com android.permission.WRITE_SECURE_SETTINGS
```

On connect the app sets `Settings.Global.HTTP_PROXY = 127.0.0.1:<mixedPort>`;
on disconnect (and on app start) it clears it.

## Limitations (important)

- **No full tun‑VPN on the watch.** Wear OS does not expose the VPN management
  service (`vpn_management`), so `VpnService` cannot start on the watch. The
  standalone option is therefore **proxy-only**.
- **Proxy mode only covers proxy-aware HTTP/HTTPS traffic** (browsers and apps
  that honor the system HTTP proxy). Apps with their own networking — e.g.
  **Telegram** (MTProto) — and UDP traffic **bypass** it. For full coverage use
  the remote-control mode (VPN on the phone).
- **`minSdkVersion` is raised to 26** (Android 8.0) because the Wear OS
  tiles/complications libraries require it. Wear OS is API 30+ regardless.
- The complication/tile reflect the latest state the watch app has written;
  while the app is fully closed, the values can be stale.
