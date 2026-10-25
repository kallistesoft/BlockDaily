# Block Daily: remaining steps to production (Google Play)

Status as of 2026-10-24: **submitted for Google review** (build 37, all countries, managed publishing off, so it goes live automatically on approval). Android first; iOS needs an Apple developer account (later).
**Owner:** *you* = the account owner, *Claude* = can be done by Claude, *Google* = waiting on Google.

## Done

- [x] Real AdMob ads on Android: interstitial at game over (capped: none in the first 3 min, then at most one per 90 s), rewarded Continue, banner. Consent (EU/UK, US states) with a Privacy options link.
- [x] AdMob (contact@kallistesoft.ca, pub-7557144664039757): app `~3884220247`, 3 ad units, ad content rating **T**, sensitive categories blocked (alcohol, gambling, dating, get-rich, sexual, social casino).
- [x] Remove Ads purchase in code (`remove_ads`), with a parental gate and Restore purchase. The button stays hidden until the product exists on Play.
- [x] Kallistesoft-branded icon (Android adaptive, iOS, web) and app name "Block Daily".
- [x] App ID `ca.kallistesoft.block_daily` (iOS `ca.kallistesoft.blockDaily`).
- [x] Force / recommended update through Firebase Remote Config (project `block-daily-b71d6`); see README.
- [x] Play developer account is an **organization** account (KallisteSoft), so the 14-day / 12-tester closed test doesn't apply.
- [x] Payments profile created; enrolled in the **15% service fee** program.
- [x] Privacy policy: dedicated page https://kallistesoft.ca/en/privacy/block-daily/ (FR: /confidentialite/block-daily/), used by the AdMob EU consent message.
- [x] Crash reporting: Firebase Crashlytics in release builds (BlockDaily#7), privacy section 6 (kallistesoft-site#4); a test crash showed up readable in the console.
- [x] No public web version: play.kallistesoft.ca only shows "Coming soon on Google Play"; the site links to the Block Daily page.

## Remaining

### 1. Release signing (*Claude*, then *you* back it up)
- [x] Upload key created (`~/Keys/kallistesoft/block-daily-upload.jks`, RSA 4096, alias `upload`, SHA-256 `B1:88:E5:…:22:07:A7`) and wired into release builds through `android/key.properties` (git-ignored).
- [ ] **You:** back up the keystore file and its password (password manager plus a copy off this Mac). Losing it means you can no longer update the app.
- [ ] Add the keystore as GitHub secrets when an Android CI job is added (not before: no reason to copy the key around until then).

### 2. Create the app in Play Console (*Claude* through Chrome, *you* approve the declarations)
- [x] Created "Block Daily" (game, free, default language en-US); app ID 4973577989512842865.
- [x] `ca.kallistesoft.block_daily` is registered ("Inscrite") under Android developer verification.

### 3. First upload: internal testing (*Claude*)
- [x] Release **1 (1.0.0)** uploaded and published to internal testing; Play App Signing on. Next builds: `tools/build_release.sh` (automatic build number).
- [x] Tester list "KallisteSoft team" (jef.ottavi@gmail.com); opt-in link https://play.google.com/apps/internaltest/4701576584002610767
- [x] Installed from Play on the Pixel. Build **37 (1.0.0, with French)** published to internal testing.

### 4. Remove Ads product (*Claude*, after step 3)
- [x] `remove_ads` created and **active**: purchase option `buy`, 3,99 CAD (2,89 USD), 174 countries/regions, backward compatible.
- [x] License testers: the "KallisteSoft team" list (free test purchases).
- [x] On the Pixel: purchase removes the banner and interstitials; Restore purchase works after reinstall.

### 5. Store listing and policy forms (*Claude* drafts through Chrome, *you* review)
- [x] Short and full description: en-US, fr-FR, fr-CA. AI-content declaration: assets not labeled (real screenshots, code-drawn graphics).
- [x] Phone screenshots (EN and FR), 1024×500 feature graphic (EN and FR), 512 px icon.
- [x] Content rating: ESRB Everyone, PEGI 3 (Brazil 14+ because of the in-app purchase).
- [x] Target audience **13+** (family-friendly, not designed for children).
- [x] Ads declaration: **contains ads**.
- [x] **Data safety**: advertising ID (AdMob), Firebase installation ID (Remote Config, Crashlytics), crash logs and diagnostics (Crashlytics), purchase history (Play), approximate location from IP (ads); no account, no data sold.
- [x] Privacy policy URL: https://kallistesoft.ca/en/privacy/block-daily/
- [x] App access: no login needed.

### 6. Final checks (*you* plus *Claude*)
- [x] Play session on the Pixel (build 37 from Play): language, Remove Ads purchase and restore. Ads can only be checked after launch (AdMob limited serving).
- [ ] Release build smoke test on the emulator (startup, no crash).
- [ ] Bank account verified in the payments profile (*Google*: test deposit, then *you* confirm the amount).

### 7. Production release (*you* press the button)
- [x] Production release: build 37, all 177 countries/regions plus rest of world, release notes EN/FR; sent for review on 2026-10-24.
- [ ] *Google* review: usually 1 to 7 days for a new app; goes live automatically when approved.

### 8. Right after launch (*Claude*)
- [ ] Link the AdMob app to the Play listing (lifts limited ad serving; AdMob reviews the app).
- [ ] Check app-ads.txt is detected for Block Daily (kallistesoft.ca/app-ads.txt is live with pub-7557144664039757; set kallistesoft.ca as the developer website on the listing).
- [ ] Watch Crashlytics, AdMob fill rate and reviews during the first week.

## Later (not blocking launch)

- Automated tests: PR CI with Android builds, a release smoke test on an emulator, and integration tests (deferred on 2026-10-24).
- Play Games Services: daily challenge leaderboard and achievements (7-day streak, first 10,000-point game). Use the existing Cloud project `block-daily-b71d6`, not a new one; needs a new build and a data safety update. Play Games on PC is already on (default).
- More languages (store listing and in-app); French is done.
- iOS release (Apple developer account, AdMob iOS app, App Store Connect).
- The same branded icons for Neon Breaker, Void Raid, Neon Pop, Neon Snake and Neon Stack.
