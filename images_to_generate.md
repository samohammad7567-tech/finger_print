# SecureAttend — Image Generation Brief

Every image the app needs, written as a ready-to-paste prompt.

**Product:** SecureAttend — an attendance and workforce-records system for a
security-guarded site. Two audiences in one binary: a **guard** at the gate
(check-in / check-out / mark absent) and a **manager** (employees, permissions,
shifts, holidays, reports, ZKTeco fingerprint terminal, backup).
**Platforms:** Windows desktop (primary, Inno Setup installer) + Android.
**Languages:** Arabic (primary) and English — so **no text inside any image**.
**Themes:** light and dark; both must be served.

---

## 0. The design system these images must obey

The palette is already fixed in `lib/core/style/colors/colors_light.dart` and
`colors_dark.dart`. Nothing generated should introduce a hue outside it.

| Role | Hex | Name to use in prompts |
|------|-----|------------------------|
| Deepest teal — rail, status bar | `#002623` | deepest teal |
| Brand teal — actions, focus | `#054239` | brand teal |
| Mid teal — decorative tint | `#428177` | mid teal |
| Gold — warning family | `#988561` | antique gold |
| Sand — active mark on dark | `#B9A779` | sand |
| Cream — the canvas | `#EDEBE0` | warm cream |
| Off-white — cards | `#FAF9F4` | bone white |
| Warm grey — secondary ink | `#3D3A3B` | warm grey |
| Warm near-black — body ink | `#241E1F` | warm near-black |
| Burgundy — destructive | `#6B1F2A` | burgundy |
| Green — success | `#2C7355` | archive green |
| Dark ground | `#001A18` | near-black teal |

**The identity, in one line:** *an archive, not a dashboard.* Warm cream ground,
warm-black ink, flat fills, hairline rules, no drop shadows on resting surfaces,
no glow, no glass. Think a well-printed ledger, an embassy document, a brass
plate — not a SaaS landing page.

### THE STYLE BLOCK — paste this into every prompt below

> Flat vector illustration, editorial / technical-manual style. Strictly limited
> palette: warm cream `#EDEBE0`, bone white `#FAF9F4`, deepest teal `#002623`,
> brand teal `#054239`, mid teal `#428177`, antique gold `#988561`, sand
> `#B9A779`, warm near-black `#241E1F`. Crisp 2px uniform line weight, geometric
> construction, generous negative space, subtle letterpress-style stipple or
> hatching for shading instead of gradients. Perfectly centred, front-on or mild
> isometric. No text, no letters, no numbers, no logos, no watermarks, no
> signature. No drop shadows, no glow, no bevel, no gloss, no 3D render, no
> photorealism, no gradient mesh, no neon, no purple, no orange, no bright blue.

### UNIVERSAL NEGATIVE PROMPT

> text, letters, words, numbers, typography, watermark, signature, logo,
> photorealistic, 3D render, ray tracing, glossy, glassmorphism, neon, glow,
> drop shadow, bevel, gradient mesh, purple, magenta, orange, bright saturated
> blue, cyberpunk, stock-photo people, clip art, cluttered, busy background,
> border frame, UI chrome, mockup device frame

### Delivery rules

- **Format:** PNG with real alpha for anything that sits on a themed surface.
  WebP (quality 90) is fine for backgrounds and marketing art.
- **Flutter density:** ship `assets/images/<name>.png` plus
  `assets/images/2.0x/<name>.png` and `3.0x/<name>.png`, or ship a single
  3× master and let Flutter downscale.
- **Register the folder** in `pubspec.yaml` — it currently lists only
  `assets/translations/`:
  ```yaml
  flutter:
    assets:
      - assets/translations/
      - assets/images/
      - assets/images/brand/
      - assets/images/empty/
      - assets/images/device/
      - assets/images/texture/
      - assets/images/avatar/
      - assets/images/onboarding/
      - assets/images/print/
  ```
- **Dark theme:** anything whose ink is warm-near-black needs a second pass with
  ink at warm cream `#EDEBE0` on transparent — suffix `_dark`.
- **RTL:** illustrations must be composition-symmetric or mirror-safe, because
  the whole UI flips for Arabic. Avoid a strong left-to-right reading arrow.

---

## A. Brand identity

Right now the brand is a bare `Icons.shield` in three places
(`login_body.dart:96`, `admin_shell.dart:57`) plus an `app_icon.ico` stub.
This group replaces that with a real mark.

### A1 — `brand/logo_mark.png`
- **Replaces:** `Icons.shield` in `lib/features/auth/presentation/refactor/login_body.dart:96` (80×80 rounded container) and `lib/features/admin/presentation/refactor/admin_shell.dart:57` (32×32).
- **Size:** 1024×1024 PNG, transparent. Must stay legible at 16px.
- **Prompt:**
  > A minimal geometric emblem for a security attendance system: a shield
  > silhouette whose lower half resolves into three horizontal ledger rules, and
  > whose upper half holds a single fingerprint whorl reduced to four concentric
  > arcs. Solid fill in brand teal `#054239` with the arcs and rules cut out as
  > negative space, one hairline accent arc in sand `#B9A779`. Absolutely
  > symmetrical, engraved-seal simplicity, reads clearly at 16 pixels.
  > [STYLE BLOCK]
- **Also generate:** `brand/logo_mark_cream.png` — identical geometry filled warm cream `#EDEBE0`, for placement on the deep teal rail.

### A2 — `brand/logo_lockup.png`
- **Where:** README banner, installer, login card header, PDF cover.
- **Size:** 2400×600 PNG transparent.
- **Prompt:**
  > The A1 shield-and-ledger emblem at left, with a clear empty rectangular
  > space to its right sized for a wordmark — leave that area completely empty
  > and transparent. Emblem in brand teal `#054239`. A single hairline vertical
  > rule in warm grey `#3D3A3B` at 20% opacity separating the emblem from the
  > empty area. Nothing else in frame. [STYLE BLOCK]
- **Note:** the wordmark is set in the app's own type, not generated — that is why the right side stays empty.

### A3 — `brand/app_icon_master.png`
- **Feeds:** `windows/runner/resources/app_icon.ico` (256/128/64/48/32/16) and the macOS/Linux bundles.
- **Size:** 1024×1024 PNG, **full-bleed, no transparency**.
- **Prompt:**
  > A desktop application icon, full-bleed square with softly rounded corners.
  > Ground is a flat deepest teal `#002623` field with an extremely subtle
  > engraved concentric-arc guilloche at 6% opacity in mid teal `#428177`.
  > Centred on it, at 62% of the canvas, the shield-and-ledger emblem in warm
  > cream `#EDEBE0` with one accent arc in sand `#B9A779`. Flat, no shadow, no
  > highlight sweep, no glass dome. Crisp edges suitable for 16px rendering.
  > [STYLE BLOCK]

### A4 — Android adaptive icon (two files)
- **Targets:** `android/app/src/main/res/mipmap-*/` foreground + `drawable/` background.
- **`brand/android_icon_foreground.png`** — 1024×1024 PNG transparent:
  > The shield-and-ledger emblem in warm cream `#EDEBE0` with one sand
  > `#B9A779` accent arc, centred, occupying only the middle 60% of the canvas
  > with the outer 20% margin on all sides fully transparent and empty (Android
  > adaptive-icon safe zone). Nothing else. [STYLE BLOCK]
- **`brand/android_icon_background.png`** — 1024×1024 PNG opaque:
  > A flat deepest teal `#002623` square, edge to edge, carrying a barely
  > perceptible engraved concentric-arc guilloche at 5% opacity in mid teal
  > `#428177`, centred and radiating from the middle. No subject, no focal
  > point, safe to be cropped to any mask shape. [STYLE BLOCK]

### A5 — `brand/logo_mono_print.png`
- **Where:** PDF report header in `lib/core/pdf/report_pdf_engine.dart:124` (`_header`), which currently prints no mark at all.
- **Size:** 1200×1200 PNG transparent, single ink.
- **Prompt:**
  > The shield-and-ledger emblem rendered as a single-ink engraving in warm
  > near-black `#241E1F` only — no second colour, no tints, no greys. Line work
  > thickened slightly for 300dpi print and for faxing. Pure ink-and-
  > transparent, nothing anti-aliased into colour. [STYLE BLOCK]

---

## B. Login & authentication

`login_body.dart` currently paints a flat `context.color.background` behind the
sign-in card. On a 1920px desktop window that is a lot of empty cream.

### B1 — `login_panel_wide.webp`
- **Where:** the left half of the desktop login window (`login_body.dart`, `_buildContent`).
- **Size:** 1600×2000 WebP (portrait, covers a half-window at any height).
- **Prompt:**
  > A calm architectural vignette for a security-attendance login screen: the
  > guardhouse side of a site gate rendered in flat planes — a boom barrier at
  > rest, a low wall, a wall-mounted biometric terminal, and a tall narrow
  > window — drawn in deepest teal `#002623` and brand teal `#054239` silhouette
  > against a warm cream `#EDEBE0` sky. A single antique gold `#988561` hairline
  > marks the horizon. Deep empty cream space occupies the upper 55% of the frame
  > so an interface card can sit over it. Quiet dawn stillness, no people, no
  > vehicles. [STYLE BLOCK]
- **Dark pass:** `login_panel_wide_dark.webp` — same composition, ground near-black teal `#001A18`, silhouettes mid teal `#428177`, horizon line sand `#B9A779`.

### B2 — `login_bg_portrait.webp`
- **Where:** the same screen on Android portrait.
- **Size:** 1242×2688 WebP.
- **Prompt:**
  > A vertical background for a mobile sign-in screen. Warm cream `#EDEBE0`
  > ground. Across the bottom third only, a flat silhouette skyline of a fenced
  > industrial compound — perimeter fence posts, a gate, one floodlight mast —
  > in deepest teal `#002623`. The upper two thirds are almost entirely empty
  > cream, carrying only a single very faint concentric-arc guilloche at 5%
  > opacity in mid teal `#428177`, centred near the top. Nothing must compete
  > with an interface card placed over the middle. [STYLE BLOCK]
- **Dark pass:** `login_bg_portrait_dark.webp`.

### B3 — `empty/admin_lock.png`
- **Where:** `lib/features/auth/presentation/widgets/admin_password_dialog.dart` — elevating a guard session to manager.
- **Size:** 800×800 PNG transparent.
- **Prompt:**
  > A single flat-vector brass padlock of old institutional design, body drawn in
  > antique gold `#988561` with a brand teal `#054239` shackle, hanging on a
  > hasp fixed to two hairline ledger rules. The keyhole is a small negative-
  > space circle. Front-on, symmetrical, isolated on transparency. Restrained
  > and official, not playful. [STYLE BLOCK]

---

## C. Empty states

`lib/core/widgets/app_empty_state.dart` takes an `IconData` in a 64×64 tinted
box. Add an optional `String? image` to it and these replace the icon on the
larger screens (keep the icon fallback for dense lists).

**Shared spec for every C image:** 800×800 PNG, transparent, subject filling
~70% of frame, plus a `_dark` pass with ink switched to warm cream `#EDEBE0`.

### C1 — `empty/no_employees.png`
- **Where:** `lib/features/admin/presentation/refactor/employee_management_body.dart`.
- **Prompt:**
  > An open personnel ledger lying flat, both pages blank and ruled with
  > hairlines, a paper-clipped empty ID card resting on the right page with a
  > blank portrait rectangle where a photo would go. Ledger board in brand teal
  > `#054239`, pages bone white `#FAF9F4`, rules warm grey `#3D3A3B`, the ID
  > card's clip in antique gold `#988561`. Mild isometric view from above.
  > [STYLE BLOCK]

### C2 — `empty/no_attendance_today.png`
- **Where:** `lib/features/attendance/presentation/refactor/attendance_body.dart` and `lib/features/dashboard/presentation/widgets/recent_attendance_list.dart`.
- **Prompt:**
  > A wall-mounted time-card rack with every slot empty — ten vertical bays,
  > each holding nothing, one card lying fallen at the base of the rack. Rack in
  > brand teal `#054239`, the single fallen card bone white `#FAF9F4`, hairline
  > detail in warm grey `#3D3A3B`, one antique gold `#988561` rivet. Front-on,
  > symmetrical. [STYLE BLOCK]

### C3 — `empty/no_permissions.png`
- **Where:** `lib/features/permissions/presentation/refactor/permissions_body.dart` and `lib/features/admin/presentation/refactor/admin_permissions_body.dart`.
- **Prompt:**
  > A single blank leave-request form on an empty wooden clipboard, with a rubber
  > approval stamp resting beside it, un-inked and unused, its face turned away.
  > Form bone white `#FAF9F4` with hairline rules, clipboard brand teal
  > `#054239`, stamp handle warm near-black `#241E1F` with an antique gold
  > `#988561` collar. Mild isometric. [STYLE BLOCK]

### C4 — `empty/no_departments.png`
- **Where:** `lib/features/departments/presentation/refactor/departments_body.dart:62` (replaces `Icons.apartment`).
- **Prompt:**
  > An empty organisational chart: one solid box at the top and three empty
  > dashed-outline boxes below it, joined by hairline connector lines. Filled box
  > in brand teal `#054239`, the three empty boxes drawn only as dashed warm grey
  > `#3D3A3B` outlines, connectors hairline mid teal `#428177`. Perfectly
  > symmetrical, architectural drawing feel. [STYLE BLOCK]

### C5 — `empty/no_shifts.png`
- **Where:** `lib/features/shifts/presentation/refactor/shifts_body.dart:61` (replaces `Icons.access_time`).
- **Prompt:**
  > A 24-hour analogue duty clock face with no shift bands drawn on it: a bare
  > ring of hour ticks, hands removed entirely, and an empty arc channel around
  > the rim waiting to be filled. Ring and ticks in brand teal `#054239`, the
  > empty arc channel a hairline warm grey `#3D3A3B` outline, a single antique
  > gold `#988561` tick at the top of the dial. Front-on, perfectly circular.
  > [STYLE BLOCK]

### C6 — `empty/no_holidays.png`
- **Where:** `lib/features/holidays/presentation/refactor/holidays_body.dart:55` (replaces `Icons.event_busy`).
- **Prompt:**
  > A desk calendar page showing a bare month grid with no date marked — even
  > rows of empty cells, hairline ruled, and a small empty pennant flag standing
  > in the margin beside the grid. Calendar block bone white `#FAF9F4`, its spine
  > brand teal `#054239`, grid rules warm grey `#3D3A3B`, the pennant antique
  > gold `#988561`. Mild isometric. [STYLE BLOCK]

### C7 — `empty/all_clear.png`
- **Where:** `lib/features/notifications/presentation/refactor/notifications_body.dart:61` (replaces `Icons.check_circle`; the "everything is good" state).
- **Prompt:**
  > A small brass service bell at rest with a neat ribbon tied around its
  > handle, and a single check mark engraved into the plate beneath it. Bell in
  > antique gold `#988561`, plate brand teal `#054239`, check mark and ribbon in
  > archive green `#2C7355`. Calm and resolved rather than celebratory — no
  > sparkles, no confetti, no motion lines. Front-on, symmetrical. [STYLE BLOCK]

### C8 — `empty/no_search_results.png`
- **Where:** the search field in `attendance_body.dart:43` and `lib/features/check_in/presentation/widgets/employee_search.dart`.
- **Prompt:**
  > A library card-catalogue drawer pulled open to reveal it is empty, with a
  > single magnifying glass lying across the empty drawer. Drawer front brand
  > teal `#054239` with an antique gold `#988561` pull handle, interior bone
  > white `#FAF9F4`, magnifier rim warm near-black `#241E1F` with a clear
  > un-tinted lens. Mild isometric. [STYLE BLOCK]

### C9 — `empty/no_report_data.png`
- **Where:** `lib/features/admin/presentation/refactor/admin_reports_body.dart` and `punch_report_body.dart` before a range is chosen.
- **Prompt:**
  > A blank tabular report sheet: a printed header band across the top, ruled
  > columns below it, and every data cell empty. Beside the sheet, a folded
  > ribbon marker. Sheet bone white `#FAF9F4`, header band brand teal `#054239`,
  > column rules warm grey `#3D3A3B` hairlines, ribbon antique gold `#988561`.
  > Straight-on, gently perspectived as if lying on a desk. [STYLE BLOCK]

### C10 — `empty/no_device.png`
- **Where:** `lib/features/device/presentation/widgets/device_status_card.dart` when `state.settings.isConfigured` is false (currently only `Icons.usb_off`).
- **Prompt:**
  > A wall-mounted biometric terminal with its network cable hanging loose and
  > unplugged, the coiled end resting below it, and its screen a blank dark
  > rectangle. Terminal body brand teal `#054239`, screen deepest teal
  > `#002623`, cable warm grey `#3D3A3B`, the loose RJ45 connector head antique
  > gold `#988561`. Front-on with the cable falling straight down so the image
  > mirrors safely for right-to-left layout. [STYLE BLOCK]

### C11 — `empty/no_notifications.png`
- **Where:** the guard-side `notifications_body.dart` when the list is genuinely empty (distinct from C7's "all clear").
- **Prompt:**
  > An empty pigeonhole message rack, nine square compartments, all of them
  > vacant, mounted on a plain wall plate. Rack in brand teal `#054239`,
  > compartment interiors warm cream `#EDEBE0`, one hairline antique gold
  > `#988561` rule along the bottom edge. Front-on, symmetrical, quiet.
  > [STYLE BLOCK]

---

## D. Device & biometrics (ZKTeco)

The `device` feature is the most technical screen in the product and currently
carries no visual explanation at all.

### D1 — `device/terminal_on_network.png`
- **Where:** header of `lib/features/device/presentation/refactor/device_body.dart`.
- **Size:** 1600×900 PNG transparent.
- **Prompt:**
  > A clean technical diagram, flat vector: a wall-mounted fingerprint
  > attendance terminal at one side, a desktop computer tower with monitor at
  > the other, connected by a single orthogonal cable run that passes through a
  > small network switch at the midpoint. Right-angled cable routing only, like
  > an installation manual plate. Devices in brand teal `#054239` and deepest
  > teal `#002623` on transparency, the cable a mid teal `#428177` hairline, the
  > switch marked with one antique gold `#988561` port indicator. Balanced left
  > and right so the diagram reads correctly mirrored. [STYLE BLOCK]

### D2 — `device/fingerprint_enroll.png`
- **Where:** the enrollment screen driven by `lib/features/admin/presentation/cubit/enrollment_cubit.dart`, and `employee_fingerprint_field.dart` — guidance for placing a finger.
- **Size:** 1000×1000 PNG transparent.
- **Prompt:**
  > An instructional plate showing correct finger placement on a biometric
  > sensor: a stylised index finger, drawn as flat outlined planes, pressing flat
  > and centred on a rounded rectangular sensor window, with two short hairline
  > alignment marks either side of the sensor. Finger outline in warm near-black
  > `#241E1F` with a warm cream `#EDEBE0` fill, sensor window brand teal
  > `#054239`, the whorl ridges inside the window a mid teal `#428177` spiral,
  > alignment marks antique gold `#988561`. Clinical and instructive, no hand
  > beyond the wrist, no skin tone. [STYLE BLOCK]

### D3 — `device/sync_flow.png`
- **Where:** `lib/features/device/presentation/widgets/device_sync_card.dart`.
- **Size:** 1400×700 PNG transparent.
- **Prompt:**
  > A flat technical diagram of records transferring from a biometric terminal
  > into a database: the terminal at one end, a cylindrical database stack at the
  > other, and between them a row of six small identical punch-record cards
  > spaced evenly along a hairline track. Terminal and database in brand teal
  > `#054239`, cards bone white `#FAF9F4` with warm grey `#3D3A3B` hairline
  > rules, track mid teal `#428177`, the leading card edge-marked in antique gold
  > `#988561`. Evenly spaced and axis-symmetric — no directional arrowheads, so
  > it stays correct when mirrored. [STYLE BLOCK]

### D4 — `device/clock_drift.png`
- **Where:** the `_clockWarning` branch of `device_status_card.dart` — a terminal whose clock has drifted files punches under the wrong day.
- **Size:** 800×800 PNG transparent.
- **Prompt:**
  > Two identical analogue clock faces overlapping slightly, their hands set to
  > visibly different times, with a short hairline bracket between the two hour
  > hands marking the discrepancy. Both dials bone white `#FAF9F4` with brand
  > teal `#054239` rims; the left clock's hands warm near-black `#241E1F`, the
  > right clock's hands antique gold `#988561`; the bracket a warm grey
  > `#3D3A3B` hairline. Front-on, clinical. [STYLE BLOCK]

---

## E. Surfaces, textures & the hero

`dashboard_hero.dart:50` and `guard_profile_card.dart` are flat
`context.color.primary` blocks. A texture at very low opacity gives them weight
without violating the "flat by choice" rule in `app_effects.dart`.

### E1 — `texture/paper_grain.png`
- **Where:** overlaid on `context.color.background` at 3–5% opacity, app-wide.
- **Size:** 1024×1024 PNG, **seamlessly tiling**, near-transparent.
- **Prompt:**
  > A seamless tileable paper-fibre texture, extremely subtle: fine random
  > laid-paper grain and a faint horizontal laid-line structure, as found in
  > archival cream ledger stock. Rendered as very low-contrast warm grey
  > `#3D3A3B` speckle on full transparency — no colour, no visible motif, no
  > repeating landmark, no edges or seams when tiled. Uniform density across the
  > whole square. [STYLE BLOCK]

### E2 — `texture/hero_guilloche.png`
- **Where:** inside the rounded container of `dashboard_hero.dart:50` at ~8% opacity.
- **Size:** 2000×1000 PNG transparent.
- **Prompt:**
  > An engraved security-document guilloche pattern: fine interlacing
  > concentric arc bands, the kind printed as anti-forgery ground on a
  > certificate or banknote, radiating from a point near one corner and fading
  > out across the rest of the frame. Hairlines only, drawn in mid teal
  > `#428177` on full transparency, no fills, no solid areas, no focal ornament.
  > Intended to sit at 8% opacity over a deep teal panel. [STYLE BLOCK]

### E3 — `texture/rail_watermark.png`
- **Where:** bottom of the navigation rail / the bottom-nav surface in `admin_shell.dart`, ~6% opacity.
- **Size:** 1200×1200 PNG transparent.
- **Prompt:**
  > A single very large engraved shield outline, hairline weight only, cropped by
  > the frame edge so only its upper two thirds are visible. Drawn in warm cream
  > `#EDEBE0` on full transparency, unfilled, no interior detail beyond three
  > hairline ledger rules crossing it. A watermark, not an illustration.
  > [STYLE BLOCK]

### E4 — `texture/dark_ground.webp`
- **Where:** the dark-theme scaffold background.
- **Size:** 2560×1600 WebP.
- **Prompt:**
  > A near-uniform dark field in near-black teal `#001A18`, carrying only an
  > extremely faint large-scale vignette and a barely perceptible engraved arc
  > texture in deepest teal `#002623`. No subject, no gradient banding, no
  > visible centre, safe to be cropped or tiled behind dense interface content.
  > [STYLE BLOCK]

---

## F. Avatars & placeholders

`employee_card.dart` and `guard_profile_card.dart:26` both fall back to a single
initial letter. Keep the initial as the default, but these cover the cases where
a letter is wrong or absent.

### F1 — `avatar/employee_placeholder.png`
- **Size:** 512×512 PNG transparent, square (the UI clips to a 16px-radius rounded rectangle).
- **Prompt:**
  > A neutral employee-record portrait placeholder: a simple geometric bust
  > silhouette — head and shoulders only, no facial features whatsoever — centred
  > in a square. Silhouette in mid teal `#428177` on a warm cream `#EDEBE0`
  > field, with one hairline warm grey `#3D3A3B` rule across the lower quarter
  > suggesting a name line. Strictly featureless and ungendered, no hair detail,
  > no collar detail, no skin tone. [STYLE BLOCK]
- **Dark pass:** `avatar/employee_placeholder_dark.png` — field deepest teal `#002623`, silhouette sand `#B9A779`.

### F2 — `avatar/guard_placeholder.png`
- **Where:** `guard_profile_card.dart` when the guard's name is empty.
- **Size:** 512×512 PNG transparent.
- **Prompt:**
  > The same featureless head-and-shoulders bust silhouette as a personnel
  > placeholder, but wearing a plain peaked uniform cap, no insignia. Silhouette
  > warm cream `#EDEBE0` on a brand teal `#054239` field — it sits inside a teal
  > card. Featureless, ungendered, no rank markings, no badge. [STYLE BLOCK]

---

## G. Reports & printed output

`report_pdf_engine.dart:124` builds a `_header` with a title and date range and
no mark. A printed attendance record that an employee may dispute should look
like an official document.

### G1 — `print/pdf_header_rule.png`
- **Size:** 2480×160 PNG transparent (A4 width at 300dpi).
- **Prompt:**
  > A printed document header rule: one heavy horizontal bar with a hairline
  > companion rule beneath it, and a short run of engraved guilloche arcs
  > occupying the outer sixth at each end. Bar in warm near-black `#241E1F`,
  > hairline and guilloche also in warm near-black — single ink only, no colour,
  > no greys, print-safe. Symmetrical left to right. [STYLE BLOCK]

### G2 — `print/pdf_watermark_seal.png`
- **Size:** 2000×2000 PNG transparent, single ink, intended for ~6% opacity.
- **Prompt:**
  > A circular official seal rendered as engraving outlines only: two concentric
  > hairline rings with a blank band between them for text that must be left
  > completely empty, and the shield-and-ledger emblem at the centre. Single ink
  > warm near-black `#241E1F` on transparency, unfilled, no solid areas.
  > Designed to be printed at very low opacity as a page watermark.
  > [STYLE BLOCK]

---

## H. First-run setup

Nothing in the app currently explains the setup order: connect the terminal →
import employees → define shifts and the work week. Three plates for a setup
wizard or for the top of `admin_settings_body.dart`.

**Shared spec:** 1200×800 PNG transparent, plus `_dark` pass.

### H1 — `onboarding/step_connect.png`
- **Prompt:**
  > A flat technical plate: a biometric terminal and a computer joined by a
  > single right-angled cable, with a small concentric "link established" mark at
  > the midpoint of the run. Terminal and computer in brand teal `#054239`,
  > cable mid teal `#428177` hairline, the link mark antique gold `#988561`.
  > Installation-manual clarity, axis-symmetric, no hands in frame.
  > [STYLE BLOCK]

### H2 — `onboarding/step_import.png`
- **Where:** pairs with `employee_import_button.dart` / `employee_import_excel_data_source.dart`.
- **Prompt:**
  > A flat technical plate: a spreadsheet page with a ruled grid on one side, a
  > personnel ledger with ruled pages on the other, and three small record cards
  > spaced evenly along a hairline track between them. Spreadsheet and ledger in
  > bone white `#FAF9F4` with brand teal `#054239` headers, cards warm cream
  > `#EDEBE0`, track and rules warm grey `#3D3A3B` hairlines, one antique gold
  > `#988561` accent on the leading card. No arrowheads. [STYLE BLOCK]

### H3 — `onboarding/step_schedule.png`
- **Where:** pairs with `work_schedule_body.dart` and `shifts_body.dart`.
- **Prompt:**
  > A flat technical plate: a seven-column week grid with two columns marked as
  > rest days by diagonal hatching, and beside it a 24-hour dial with one solid
  > arc band drawn on its rim representing a shift. Grid and dial in brand teal
  > `#054239` hairlines on bone white `#FAF9F4`, the rest-day hatching warm grey
  > `#3D3A3B`, the shift arc antique gold `#988561`. Architectural, symmetrical.
  > [STYLE BLOCK]

---

## I. Operational states

### I1 — `empty/backup_safe.png`
- **Where:** `lib/features/backup/presentation/refactor/backup_body.dart`.
- **Size:** 900×900 PNG transparent.
- **Prompt:**
  > An archival document box with its lid slightly ajar, containing upright
  > ledger volumes, standing on a plain plinth. Box in brand teal `#054239`,
  > ledger spines warm cream `#EDEBE0` and antique gold `#988561`, plinth warm
  > grey `#3D3A3B`, hairline detail throughout. Solid, safe, permanent —
  > institutional storage rather than cloud imagery. Mild isometric.
  > [STYLE BLOCK]

### I2 — `empty/connection_failed.png`
- **Where:** `lib/core/network/error_mapper.dart`-driven error surfaces and a failed `testConnection` in `device_status_card.dart`.
- **Size:** 900×900 PNG transparent.
- **Prompt:**
  > A single network cable severed cleanly in the middle, its two connector ends
  > drawn pulled slightly apart, with a short hairline bracket marking the gap.
  > Cable in warm grey `#3D3A3B`, both RJ45 connector heads in burgundy
  > `#6B1F2A`, the gap bracket a burgundy hairline. Horizontal and perfectly
  > symmetrical about the break. Factual, not alarming — no lightning bolts, no
  > sparks, no exclamation marks. [STYLE BLOCK]

### I3 — `empty/import_success.png`
- **Where:** `lib/features/admin/presentation/widgets/employee_import_result_dialog.dart`.
- **Size:** 900×900 PNG transparent.
- **Prompt:**
  > A neat completed stack of personnel record cards, squared off, with a
  > rubber-stamped check mark impressed on the top card. Cards bone white
  > `#FAF9F4` with warm grey `#3D3A3B` hairline rules, the stack's binding edge
  > brand teal `#054239`, the stamped check mark archive green `#2C7355` with a
  > slightly uneven ink-impression edge. Restrained completion, no celebration
  > imagery. Mild isometric. [STYLE BLOCK]

### I4 — `empty/generic_error.png`
- **Where:** last-resort error surface for any cubit emitting an unmapped error key.
- **Size:** 900×900 PNG transparent.
- **Prompt:**
  > A single ledger page torn part-way across, the tear edge irregular, the
  > ruled lines running off into the missing section. Page bone white `#FAF9F4`,
  > rules warm grey `#3D3A3B` hairlines, the torn edge outlined in burgundy
  > `#6B1F2A`. Calm and matter-of-fact, front-on, centred. No warning triangle,
  > no face, no robot, no broken-glass motif. [STYLE BLOCK]

---

## J. Splash & window chrome

### J1 — `brand/splash_android.png`
- **Feeds:** `android/app/src/main/res/drawable/` and `drawable-v21/` launch background.
- **Size:** 1242×2688 PNG opaque, plus a `values-night` variant.
- **Prompt:**
  > A vertical launch screen: a flat deepest teal `#002623` field, edge to edge,
  > with the shield-and-ledger emblem in warm cream `#EDEBE0` centred at 22% of
  > the frame width, and one hairline sand `#B9A779` rule spanning a short
  > distance directly beneath it. Nothing else — no tagline space, no ornament,
  > no vignette. [STYLE BLOCK]

### J2 — `brand/window_empty_backdrop.webp`
- **Where:** the Windows window behind a modal, and any route with no content yet.
- **Size:** 2560×1600 WebP.
- **Prompt:**
  > A near-empty warm cream `#EDEBE0` field for a desktop application backdrop,
  > carrying one very large engraved shield outline in hairline mid teal
  > `#428177` at 5% opacity, cropped by the lower-right frame edge. No subject,
  > no text area, no interface elements, nothing near the centre.
  > [STYLE BLOCK]

---

## K. Distribution & store

### K1 — `dist/installer_wizard_large.png`
- **Feeds:** Inno Setup `WizardImageFile` in `scrip.iss` (which currently sets only `SetupIconFile`).
- **Size:** 164×314 PNG **plus** the scaled set 192×386, 246×459, 273×556, 328×628, 355×700, 410×797, 615×1196.
- **Prompt:**
  > A tall narrow installer side banner. Flat deepest teal `#002623` ground with
  > an engraved concentric-arc guilloche at 8% opacity in mid teal `#428177`.
  > The shield-and-ledger emblem in warm cream `#EDEBE0` placed in the upper
  > third, a single sand `#B9A779` hairline rule beneath it, and the lower two
  > thirds left entirely plain. No text. [STYLE BLOCK]

### K2 — `dist/installer_wizard_small.png`
- **Feeds:** Inno Setup `WizardSmallImageFile`.
- **Size:** 55×55 PNG plus 64/80/92/110/119/138/206 square variants.
- **Prompt:**
  > A tiny square badge: the shield-and-ledger emblem in warm cream `#EDEBE0` on
  > a flat brand teal `#054239` square, filling 70% of the frame. Maximum
  > simplification — must remain readable at 55 pixels. No ornament, no
  > guilloche, no text. [STYLE BLOCK]

### K3 — `dist/play_feature_graphic.png`
- **Feeds:** Google Play feature graphic.
- **Size:** 1024×500 PNG, **no transparency, no text** (Play overlays the title).
- **Prompt:**
  > A wide horizontal banner. Flat deepest teal `#002623` ground with an
  > engraved guilloche at 7% opacity in mid teal `#428177`. Left of centre, the
  > shield-and-ledger emblem in warm cream `#EDEBE0`. Right of centre, three
  > flat abstract interface plates — a ruled record list, a month grid, a
  > 24-hour dial — drawn as hairline outlines in sand `#B9A779`, evenly spaced
  > and overlapping slightly. Wide empty margins top and bottom. No text.
  > [STYLE BLOCK]

### K4 — `dist/readme_banner.png`
- **Where:** top of `README.md`.
- **Size:** 2400×800 PNG.
- **Prompt:**
  > A wide repository header banner. Warm cream `#EDEBE0` ground. The
  > shield-and-ledger emblem in brand teal `#054239` at left, an empty clear
  > area at centre where a wordmark will be typeset, and at right a flat
  > technical vignette of a biometric terminal joined by a right-angled hairline
  > cable to a desktop computer, drawn in deepest teal `#002623`. One antique
  > gold `#988561` hairline runs the full width along the bottom edge. No text.
  > [STYLE BLOCK]
- **Dark pass:** `dist/readme_banner_dark.png`.

---

## L. Generation order

Do A1 first and get it right — sixteen of the images here reuse the
shield-and-ledger emblem, and they must all reuse *the same* one. Once A1 is
approved, feed it back as a reference/style image for A2–A5, E3, J1, J2, K1–K4
rather than describing the emblem again.

| Wave | Images | Why in this order |
|------|--------|-------------------|
| 1 | A1, A3, A4, A5 | The mark, and every launcher icon that depends on it |
| 2 | C1–C11 | Biggest visible lift — eleven bare `Icons.*` empty states |
| 3 | B1, B2, D1, D2 | Login and the device screen, the two least finished screens |
| 4 | E1–E4, F1, F2 | Texture and placeholders — polish over working screens |
| 5 | G1, G2, H1–H3, I1–I4 | Print output, setup guidance, operational states |
| 6 | J1, J2, K1–K4 | Splash and distribution, needed only at release |

## M. Checklist before an image is accepted

- [ ] No text, letters or digits anywhere in the raster — the UI is Arabic and English.
- [ ] Every colour traces back to the table in §0; nothing outside those hues.
- [ ] No drop shadow, glow, bevel or gradient mesh — `app_effects.dart` forbids resting shadows.
- [ ] Mirrors safely for RTL, or is composition-symmetric.
- [ ] Reads correctly at its smallest real size (16px for A1/A3, 64px for the C set).
- [ ] Alpha channel is genuinely transparent, not a baked cream rectangle.
- [ ] `_dark` pass exists wherever §0's dark rule applies.
- [ ] Filed under the right `assets/images/` subfolder and registered in `pubspec.yaml`.
