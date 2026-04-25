# Device QA Checklist — what Claude could not verify and what you must

Date: 2026-04-25

Claude ran a senior-QA pass against the renamed Nexdoz stack. Stock Android (Pixel 7 API 34, Expo Go via local Metro) was verified live in this environment. Two platforms could not be tested locally and need a real device or a Mac. This doc enumerates the exact checks for each.

---

## ✅ Already verified by Claude (do not re-run unless a regression appears)

- **Web** (google-chrome headless, Playwright through `node_modules/@playwright/test`)
  - Login → push to `/dashboard`, NEXDOZ-branded heading rendered
  - 11 routes load with HTTP 200 (`/`, `/login`, `/dashboard`, `/insights`, `/clinician`, `/settings`, `/pricing`, `/market`, `/patient/{meal-ai,timeline,logging}`)
  - `public/brand-icon-v2.svg` 200 (was 404 before fix)
  - PWA manifest valid; icons resolved
  - Dark/light bg + sidebar nav visible
- **Android stock — Pixel 7 API 34 emulator** (KVM, Expo Go via local Metro)
  - App bundles + boots after `index.ts` entry-point fix
  - Header reads `NEXDOZ MOBILE` (was `DIA BUDDY MOBILE`)
  - Hero cards, status cards, scroll all render; no JS errors in dev log
  - App name in Expo Go menu shows `Nexdoz`
- **Backend e2e** (`docker compose -f docker-compose.prod.yml -f docker-compose.smoke.yml up -d`)
  - `/healthz` 200, `/readyz` 200, `/metrics` populated
  - `POST /users` 201 with real DB write, returns nested profile
  - `POST /auth/login` returns valid JWT pair

---

## 🟡 You must verify on real device or Mac

### iOS — Mac required (Ubuntu can't run iOS Simulator)

On a Mac with Xcode + the Nexdoz mobile repo cloned:

```bash
cd FrontEnd/nexdoz-mobile
pnpm install
pnpm exec expo run:ios
```

Then walk through:

- [ ] App icon on home screen shows the **smile** (not a frown). The icon source is `assets/icon.png` (512×512). If it shows the wrong shape, the asset wasn't picked up by `expo prebuild` — re-run with `--clean`.
- [ ] Splash screen background `#0E2A47` (deep navy), with the centered icon.
- [ ] Status bar text style readable on the navy hero.
- [ ] Header eyebrow reads `NEXDOZ MOBILE`.
- [ ] Hero title `Diabetes Care Companion`, subtitle visible.
- [ ] Connected Data Sources card lists: Apple Health (Not connected), Google Health Connect (Not connected), Xiaomi Health (Not connected). On iOS, Apple Health connect button should request HealthKit permissions when tapped (the integration itself isn't wired yet — flag in HANDOFF if it is).
- [ ] Notification permission prompt: when first asked, the icon shown in the prompt should be the Nexdoz icon, not a generic placeholder.
- [ ] Tablet (iPad layout) — supportsTablet is true in `app.json`. Icons should scale crisp at 2x and 3x.
- [ ] No red error overlays (RN dev mode displays them on JS errors).

If any item fails, capture a screenshot + the file:line of the relevant component and open an issue on `next-trace/nexdoz-mobile`.

### Xiaomi / MIUI — physical device required

MIUI applies its own launcher-icon mask (rounded square different from stock Android), and its system WebView differs. Stock-Android-emulator parity is **not** sufficient.

On a Xiaomi/Redmi/POCO phone running MIUI 14+:

```bash
# Connect via USB with Developer Options + USB Debugging
adb devices  # should show your phone
cd FrontEnd/nexdoz-mobile
pnpm exec expo run:android --device  # pick your physical device
```

Then walk through:

- [ ] App icon on launcher: **smile** correct, MIUI mask doesn't crop the smile arc. If the smile gets cut by MIUI's rounded square, we need to add proper adaptive-icon foreground/background layers (`mipmap-anydpi-v26/ic_launcher.xml`). Current state ships only legacy `ic_launcher.webp` PNGs.
- [ ] Notification icon (when push lands later): MIUI shows it monochrome on the status bar. The current `assets/notification-icon.png` is full-color — pre-existing follow-up, expect this to show as a coloured square or get auto-tinted weirdly. Follow-up: ship a white-on-transparent silhouette.
- [ ] App boots without "App not optimized" warning. MIUI sometimes throttles RN apps in the background.
- [ ] Toggle Dark Mode in MIUI settings → re-open the app → confirm the deep-navy hero stays correct (no MIUI override).
- [ ] Open the in-app browser link (if any) — MIUI's WebView is older than stock Chrome; some CSS may render differently.

If MIUI mangles the icon or notifications, file follow-ups on `next-trace/nexdoz-mobile` so we can ship adaptive icons before private beta.

### Android — Pixel/Samsung physical device (optional sanity)

Same `pnpm exec expo run:android --device`. Quick spot-checks:

- [ ] Adaptive launcher icon (Android 8+) on a Pixel: smile shape clear in both round + squircle mask shapes the launcher chooses.
- [ ] Notification icon (when notifications wired): see Xiaomi notes above.
- [ ] App icon doesn't render as a white square (means the `adaptive-icon.png` is missing or the wrong format).

---

## What's not verifiable until production

- TLS certs from Let's Encrypt (need a real DO droplet + DNS).
- Better Stack log ingestion (need an actual `LOGGER_BETTERSTACK_SOURCE_TOKEN`).
- Apple Health / Google Health Connect / Xiaomi Health integrations (currently stub UI in the dashboard "Connected Data Sources" card).
- Push notifications (Expo push tokens, APNs / FCM).
- App-store / Play-store icon previews — need an EAS Build + submission dry-run.

---

If you walk through both lists and nothing red comes back, the v0.3.1 user-api / v0.2.0 web / v0.2.0 mobile build is launch-ready for the internal-test tier under the new Nexdoz brand.
