# HealthMate — Project Pitch

> **One line:** HealthMate is a local-first health companion that helps a person organise their own health information, prepare for visits, find nearby care, and read current health news — in their own language.

---

## 1. The 30-second version

HealthMate is a mobile health companion built with Flutter. It brings appointments, vaccination records, saved health reports, nearby hospitals and pharmacies, and live health news into one app — in six Indian languages. The personal information stays on the phone. The app only goes online for public information such as news and nearby facilities. My goal was not to build an app that diagnoses people. I wanted to build the app people actually need before and after a doctor's visit: something that keeps them organised, helps them find care quickly, and protects them from health misinformation.

---

## 2. The problem

Most people do not have one place for their health information. It is spread across paper prescriptions, phone notes, SMS reminders, vaccination cards and several websites. That causes three practical problems:

1. **Health records are fragmented.** People forget appointment times, lose vaccination details, and cannot quickly show a doctor what happened last time.
2. **Finding care is a separate chore.** Searching for a hospital or pharmacy usually means opening a maps app, checking whether it is open, and then calling a number that may be outdated.
3. **Health news is noisy.** Articles are duplicated, undated, out of context, or presented as "breaking" when they are months old. It is hard to tell what is current and what is reliable.

There is also a privacy problem. Many health apps ask for an account and upload personal information to a server. For a student project — and for many real users — that is unnecessary for the features that matter.

---

## 3. The solution: what HealthMate is

HealthMate is a **local-first health companion**. It is organised into five tabs:

### Home
A daily overview: a greeting, quick actions, emergency help, the next appointments, a preview of the latest health news, and upcoming public-health campaigns.

### Appointments
A private visit planner. The user can add, edit, complete or cancel an appointment, with date/time validation and prevention of duplicate time slots. It shows upcoming, past and cancelled visits. It is deliberately **not** a hospital booking system: it records a visit the user has already arranged, so the app never pretends a doctor or clinic has confirmed a slot.

### Health Hub
The records and reports centre: vaccination records, a form to save a health concern, the list of saved reports, nearby care, and the campaigns calendar.

### News
Live health news from real publishers, with category filters, newest-first ordering, duplicate removal, article detail pages, read-aloud, share, and a link to the original article. When the network fails, previously saved articles are shown with a clear timestamp and a warning — never presented as if they were just fetched.

### Profile and Settings
The local profile, language selection, emergency number, accessibility text scaling, optional PIN app lock, privacy controls, help and about.

There are also two supporting features: an emergency panel that opens the phone dialer for the saved emergency number or **108** and can send an SOS SMS with location, and an optional assistant chatbot.

**The important boundary:** HealthMate is an organiser and information tool, not a doctor. It does not diagnose, prescribe, or replace professional care. The interface says this where it matters.

---

## 4. Why it is useful

### It organises the user's own health life
Appointments, vaccination records and reports are saved on the device and are available without an account. The user can open the app and see what is coming next and what has already happened.

### It turns "where do I go?" into an answer
Nearby Care uses the device's location — only when the user allows it — to show real hospitals, clinics and pharmacies on an OpenStreetMap map and in a list, with distance, address, phone number and open/closed status where the data provides it. The user can call or open directions. If location is denied or unavailable, they can search manually by city, area or PIN code. The app handles permission denial, disabled GPS, timeouts, no results and offline states honestly.

### It fights health misinformation
News comes from real publisher feeds and Google News, not from invented articles. Every card links to the original source. Dates are validated, old items are filtered out, duplicates are removed, and cached content is labelled as cached. That is a small but important trust feature.

### It is built for the Indian context
Six languages: English, Hindi, Marathi, Bengali, Gujarati and Tamil. A searchable list of all 36 states and union territories. Emergency numbers **112** and **108**. Manual PIN-code search. A campaigns calendar based on verified WHO and UN observances rather than invented local events.

### It respects privacy by design
There is no account, no cloud sync and no personal profile upload. Profiles, appointments, vaccination records, reports and the PIN hash stay on the device. Location is requested only when the user chooses to use it, and coordinates are not stored in the profile. The app bundle contains no private API keys.

### It is honest by design
No fake doctor ratings, no fake clinic photos, no fake booking confirmations, no fabricated local campaign venues. When data is stale, the app says so. When a feature is local-only, the app says so. This was a deliberate product decision, and it is one of the parts I am most proud of.

---

## 5. Technologies used

| Layer | Technology | Why it was chosen |
|---|---|---|
| App framework | **Flutter and Dart** | One codebase for Android and web, fast UI development, strong widget testing |
| UI | **Material 3**, custom theme, Plus Jakarta Sans | Consistent, accessible interface with a clear brand identity |
| State management | **Provider** | Simple, testable ChangeNotifier-based state for language, profile, appointments, settings and app lock |
| Local storage | **Hive** and **SharedPreferences** | Fast on-device storage for structured records and small settings values |
| Networking | **http** | Lightweight REST calls to the proxy and public data sources |
| Feed parsing | **xml** in Dart, **fast-xml-parser** in Node | Parsing RSS and Atom feeds from publishers |
| Maps | **flutter_map**, **OpenStreetMap**, **latlong2** | Real map tiles and markers without a paid map key |
| Location | **geolocator** | Permission handling, last-known position and precise device location |
| Places | **Nominatim** and **Overpass** (OpenStreetMap) | Real facility and address data, with no private key |
| News | Publisher **RSS/Atom** feeds plus **Google News RSS** | Genuine recent articles with links to the original publisher |
| Actions | **url_launcher**, **share_plus** | Dialler, directions, SMS and sharing |
| Accessibility | **flutter_tts**, text scaling, semantic labels | Read-aloud for articles and a more usable interface |
| Chatbot | **webview_flutter**, Noupe embed | Optional assistant inside the app |
| Security | **crypto** (salted SHA-256 PIN hash) | Local privacy screen with attempt lockout |
| Localisation | **flutter_localizations**, **intl**, ARB files | Six-language interface with English fallback |
| Backend (public data) | **Node.js** proxy, `fast-xml-parser` | CORS-safe access to feeds and OpenStreetMap for the web build; no keys in the app |
| Testing | **flutter_test**, Dart verification scripts, Node proxy tests | Widget, service and live API checks |

---

## 6. How it works

### High-level architecture

```text
Flutter UI (screens and reusable widgets)
        │
        ▼
Provider state (language, profile, appointments, settings, app lock)
        │
        ├── Repositories ──► Hive / SharedPreferences   (private, on-device)
        │
        └── Services ──────► HTTP
                              ├── Web build: Node.js proxy ──► publishers / OpenStreetMap
                              └── Android build: keyless HTTPS providers directly
```

The key architectural rule is **separation of concerns**:

- **Screens** handle presentation and user interaction.
- **Providers** hold app state and notify the UI.
- **Repositories** handle local persistence.
- **Services** handle networking, parsing, caching, filtering and error handling.

This means the UI does not know whether news came from a cache, a proxy or a direct feed. The service layer makes that decision and returns a consistent result.

### Flow 1: Finding nearby care

1. The user taps **Use my location**, or types a city, area or PIN code.
2. The app checks location permission. If permission is already granted, it can show results immediately from the last known position, then refine with a precise GPS fix.
3. `FacilityService` queries **Nominatim first** for a reliable facility index, with **Overpass as a fallback** when it is available.
4. Results are parsed, filtered by type and radius, deduplicated, and sorted by distance.
5. The map and lazy list are rendered. The user can call the facility or open directions.
6. If something fails — permission denied, GPS off, timeout, no results, offline — the app shows a specific, honest state and offers manual search instead of a blank screen.

### Flow 2: Loading health news

1. The app shows cached articles immediately, if any exist.
2. `NewsService` asks the proxy (web) or the direct keyless providers (Android).
3. The server-side pipeline fetches five publisher feeds, parses RSS/Atom, validates dates and links, infers categories, removes duplicates, filters to a recent window, and sorts newest first. Google News is used as an optional supplement.
4. Results are cached with timestamps. Repeated requests are coalesced, and feeds have a short cache TTL to avoid hammering publishers.
5. If the upstream source fails, the app serves the last good cache with a visible **"showing articles saved on …"** warning. It never labels stale content as live.

### Flow 3: Saving an appointment

1. The user fills in the title, provider, location, date, time, duration and notes.
2. The form validates required fields and prevents a duplicate slot.
3. The appointment is saved through the repository into Hive.
4. The provider notifies the UI, so Home and the Appointments tab update immediately.
5. Status changes (completed, cancelled) are stored locally and reflected in the upcoming/past sections.

### Why there is a proxy

The web build cannot call publisher RSS feeds or OpenStreetMap directly because those servers do not send CORS headers for arbitrary browser origins. A small Node.js proxy solves that. It also centralises caching and rate-limit handling. The Android build does not need `localhost` — on a phone that points to the phone itself — so it calls keyless HTTPS providers directly. No private API keys are shipped in the app.

---

## 7. Engineering challenges and decisions

### Challenge 1: Real data is messy
Publisher feeds differ in structure, dates, redirects and image URLs. Some return errors or rate limits. I built a parser that handles RSS and Atom, validates dates and links, normalises categories, removes duplicates and keeps a recent window. I also added caching, in-flight request coalescing and stale fallback so one failing source does not break the screen.

### Challenge 2: "Nearby" must work even when location does not
Location permission can be denied, GPS can be off, and a device may be indoors. The app uses a layered strategy: last known position for speed, precise GPS for accuracy, manual city/area/PIN search as a reliable fallback, and clear error states. Facility results use Nominatim first and Overpass as a secondary source, because Overpass can be slow or unavailable.

### Challenge 3: Performance on a real phone
The original structure built all five tabs at startup, which duplicated network work and loaded data that might never be opened. I changed it to **lazy-mount tabs on first visit and keep them alive**. Home and News now share one 12-article cache instead of fetching twice. Long lists use `SliverList` lazy building. News thumbnails are decoded at the display width. Services and controllers are disposed correctly. The bottom navigation was rebuilt with measured `FittedBox` labels so "Appointments" stays on one line even at 320 dp width.

### Challenge 4: Trust and honesty
It is easy to make a health app look complete by inventing ratings, clinics or "live" labels. I deliberately did not. The app distinguishes local data from public data, marks cached news, shows the source of facility data, and states that appointments are a personal planner rather than a confirmed booking. This makes the project less flashy but much more defensible.

### Challenge 5: Privacy without a backend account
All personal features are local-first. The optional PIN lock stores a salted SHA-256 hash, not the PIN itself, with attempt lockout. The app is explicit that this is a privacy screen, not full encryption at rest.

---

## 8. What has been verified

- The Flutter test suite passes: **78 tests**.
- `flutter analyze` reports **no issues**.
- Live news checks returned real articles from multiple publishers, with no duplicates, unsorted items, bad dates or unsafe links.
- Live facility checks returned **38 real hospitals, 38 clinics and 12 pharmacies** around Bhayandar, all named and located, in about one second on the Nominatim path.
- Place search and reverse geocoding returned real local results.
- The proxy was tested for categories, pagination, limits and language fallback.
- Stale-news behaviour was tested with a controlled upstream failure: the app served cached real articles with a clear stale warning.
- The 320 dp navigation layout was tested to keep "Appointments" on a single line with a touch-friendly bar height.

**Honest status:** the implementation and automated checks are complete for the features above. Final runtime validation on a physical Android device is the remaining step; browser preview alone is not treated as proof of Android performance.

---

## 9. Limitations and next steps

- **No cloud account or sync.** Data is local; clearing app data removes it permanently. A future version could add optional encrypted backup.
- **No push notifications.** Upcoming visits are visible while the app is open; background reminders would need a notification service.
- **The PIN lock is a privacy screen, not encryption.** Full database encryption would be a future security improvement.
- **Appointments do not book hospital slots.** That would require partnerships and real clinic integrations.
- **The web build needs the proxy.** A production deployment should host it over HTTPS.
- **OpenStreetMap's public tile server is for light use.** A high-traffic deployment should use a commercial or self-hosted tile provider.
- **Android device testing is pending.** The next milestone is an APK run on a real phone, checking startup time, scrolling, permission flows and network behaviour.

---

## 10. Closing

HealthMate is not trying to replace a doctor. It is trying to fix the gap around the doctor: the scattered records, the uncertainty about where to go, and the noise of online health information. It is local-first, bilingual by design, built on real public data, and honest about what it does not know.

What I learned from this project is that the hard part of a health app is not the screens. It is the data pipeline, the failure states, the privacy decisions, and the discipline to say "I don't have that information" instead of inventing it. That is the standard I tried to build to.

Thank you. I am happy to take questions.

---

# Short version (about 3 minutes)

HealthMate is a Flutter-based, local-first health companion. It solves a simple problem: a person's health information is scattered across paper, notes, messages and websites, and finding trustworthy care and news takes too many separate steps.

The app has five areas: Home, Appointments, Health Hub, News, and Profile. Appointments is a private visit planner with validation and status tracking. Health Hub holds vaccination records and saved reports. Nearby Care shows real hospitals, clinics and pharmacies from OpenStreetMap, using the phone's location or a manual city/area/PIN search, with call and directions actions. News pulls genuine recent articles from publisher feeds, removes duplicates, validates dates, links to the original source, and clearly labels cached content if the network fails.

It is built with Flutter and Dart, Provider for state, Hive and SharedPreferences for local storage, http and xml for data, flutter_map and OpenStreetMap for maps, geolocator for location, and a small Node.js proxy for CORS-safe public data on web. Personal data never leaves the device, and there are no private API keys in the app.

The most important engineering decisions were lazy-loading the tabs, sharing one news cache between Home and News, using lazy lists and correctly sized images, and designing honest fallbacks for permission denial, no GPS, no results and stale news.

The test suite passes, the analyzer is clean, and live checks returned real hospitals and real news articles. The remaining step is final runtime testing on a physical Android device.

---

# Likely teacher questions

**Is this a medical diagnosis app?**
No. It is an organiser and information tool. It does not diagnose or prescribe, and the interface says so. It helps users prepare for and follow up on professional care.

**Where is the user's data stored?**
On the device, in Hive and SharedPreferences. There is no account and no cloud sync. The profile, appointments, vaccination records, reports and PIN hash stay local.

**Does the app work without internet?**
The personal features — profile, appointments, vaccination records and saved reports — work offline. News and nearby care need internet; when news fails, the last cached articles are shown with a warning. Nearby care offers manual search and clear error states.

**How do you know the news is real?**
Articles come from publisher RSS/Atom feeds and Google News, with links to the original publisher. Dates are validated, old items are filtered, duplicates are removed, and cached content is labelled. The app does not generate articles.

**How does Nearby Care find hospitals?**
It uses OpenStreetMap data through Nominatim first, with Overpass as a fallback, then filters by type and radius, removes duplicates, and sorts by distance. It shows distance, address, phone and status where available, and offers call and directions.

**What happens if the user denies location permission?**
They can search by city, area or PIN code. The app explains the state and does not block the feature.

**What was the hardest part?**
Making the data layer reliable and honest: multiple feeds with different formats, rate limits, missing fields, stale caches, and the need to show a useful state instead of a blank screen.

**What would you improve next?**
Physical Android testing, optional encrypted backup, background reminders, and stronger local verification of facility data.

**What did you learn?**
How to design for failure, separate UI from data logic, protect privacy by default, and validate a health feature against real sources instead of assuming it works.
