# HealthMate

A local-first Flutter health companion. Your profile, appointments, vaccination
records, reports and PIN are stored on the device. Only public data (news,
campaigns, place lookups and OpenStreetMap facilities) is requested through the
small Node proxy in `tools/`.

## What is in the app

- **Onboarding and local profile** — two-step setup, searchable list of all 36
  Indian states and union territories, optional city and health details. No
  account is created.
- **Appointments** — a private visit planner with date/time validation,
  duplicate-slot prevention, upcoming/past/cancelled states, details, editing,
  cancellation and completion. It does not book hospital slots.
- **Nearby care** — OpenStreetMap map and list of hospitals, clinics, doctors
  and pharmacies, with device location (optional), manual city/area/PIN search,
  radius and type filters, and honest permission/error states.
- **Health news** — live Google News RSS headlines through the proxy, category
  filters, cached results with saved timestamps, stale-data warnings and
  publisher links.
- **Health records** — on-device vaccination records and saved reports.
- **Settings** — app language (English, Hindi, Marathi, Bengali, Gujarati,
  Tamil), emergency number, accessibility options, optional local PIN app lock,
  privacy/data controls, help and about.
- **PIN app lock** — salted SHA-256 hash stored locally. It is a privacy screen;
  it does **not** encrypt the app's files.

## Requirements

- Flutter 3.47+ / Dart 3.13+ (the project was built with Flutter 3.47.1)
- Node.js 18+ for the public-data proxy

## Run it

```powershell
flutter pub get
npm install
```

Start the proxy in one terminal:

```powershell
npm run proxy
# HealthMate proxy listening on http://localhost:8787
```

Run the Flutter app in another terminal:

```powershell
flutter run -d chrome
```

The app defaults to `http://localhost:8787` for the proxy in debug builds.

### Release web build

Release web builds must use an HTTPS proxy; browsers block mixed content:

```powershell
flutter build web --release --dart-define=HEALTHMATE_PROXY_URL=https://your-proxy.example.com
```

Then serve `build/web` (for local checks, `node tools/serve_web.js` serves it on
port 8090).

## Proxy API

`tools/healthmate_server.js` exposes:

| Endpoint | Purpose |
| --- | --- |
| `GET /api/health` | Proxy status and active data sources |
| `GET /api/news?category=&lang=&page=&limit=` | Google News RSS headlines and publisher links |
| `GET /api/campaigns` | Public vaccination campaign information |
| `GET /api/geocode?q=` | Nominatim place search for manual area lookup |
| `GET /api/facilities?lat=&lon=&radius=&type=` | Overpass facilities, with a Nominatim fallback |

There are no API keys in the Flutter bundle. Proxy settings:

| Variable | Default | Meaning |
| --- | --- | --- |
| `PORT` | `8787` | Proxy port |
| `HOST` | `0.0.0.0` | Bind address |
| `HEALTHMATE_ALLOWED_ORIGIN` | `*` | CORS origin |
| `HEALTHMATE_NEWS_TTL_MS` | `300000` | Server-side news cache |
| `HEALTHMATE_FACILITY_TTL_MS` | `600000` | Server-side facility cache |

## Permissions

- **Location (optional)** — requested only when you tap *Detect* during setup or
  *Use my location* / *Allow location* in Nearby care. Coordinates go to the
  proxy for the OSM query and are not stored in your profile. You can search by
  city, area or PIN instead. Denial, disabled services, timeout and unavailable
  states are handled in-app.
- **Phone dialer** — used only when you tap *Call* for the emergency number;
  the app opens the system dialer and does not place the call itself.
- **Notifications** — this build does not send system or push notifications.
  There is no notification permission request, and upcoming visits are shown on
  Home only while the app is open.

## Tests

```powershell
flutter analyze
flutter test
node tools/test_proxy.js
```

## Known limitations

- There is no cloud account, sync or backup. Clearing browser/app data or using
  *Delete all data* removes everything permanently.
- Hindi, Marathi, Bengali, Gujarati and Tamil are translated for the existing
  interface; any newer string that is not translated yet falls back to English.
- Appointments are a personal planner; no clinic is contacted and no slot is
  reserved. Ratings, doctor photos and clinic booking are deliberately not
  fabricated.
- The PIN lock is a privacy screen, not encryption at rest.
- No push notifications or background reminders.
- `flutter_tts` uses `dart:js` on web, so the Wasm build target is not supported.
  The JavaScript web build works.
- Overpass can be slow or unavailable; the proxy then falls back to the
  Nominatim facility index and the app shows a warning with the source used.
- News, campaigns and nearby search need the proxy to be running. Without it the
  app shows an error state and keeps any previously cached public news.
- The map uses the public OpenStreetMap tile server. That server is intended for
  light use; a high-traffic deployment should configure a commercial or
  self-hosted tile provider in `lib/screens/nearby_screen.dart`.
