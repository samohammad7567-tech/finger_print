# GuardSync — HR Completeness & UI Enhancement Plan

## Context

GuardSync is a single-PC Windows attendance app (SQLite + ZKTeco terminal,
Arabic-primary, 265 Dart files). Two separate problems were found.

**1. The design system is built but almost unused.** `lib/core/style/` holds a
complete, carefully documented desktop design system — a 23-step type scale
(`AppTextStyles`), desktop metrics (`AppDimens`), a plane/shadow vocabulary
(`MyEffects`), and 57 semantic colour tokens (`MyColors`). Measured adoption
across the 219 files in `lib/features`:

| Token source | Feature files using it |
|---|---|
| `context.color` (`MyColors`) | 80 |
| `AppTextStyles` | **0** |
| `AppDimens` | **0** |
| `context.effects` (`MyEffects`) | **0** |

Instead there are **315 raw `fontSize:` literals** in 13 ad-hoc sizes, hard-coded
`EdgeInsets`/radii, 24 files with a bare `CircularProgressIndicator`, and 12
files using `SnackBar` while `AppToast` exists. The `sidebar*` and `statusbar*`
token families — 14 colours — are referenced by nothing at all, because the
236px navigation rail that `AppDimens` documents as the app shell was never
built; both shells are mobile-style `AppBar` + `bottomNavigationBar`.

A side effect: **7 admin routes are registered but unreachable** —
`/admin` (dashboard), `/admin/permissions`, `/admin/reports`,
`/admin/attendance` are not linked from anywhere, and the bottom bar has four
destinations commented out in `admin_shell.dart:107-111` because three tabs is
all it fits.

**2. HR's actual work is not modelled.** The attendance engine is strong —
`AttendanceDayTotals` already computes late minutes, early-out minutes, worked
time, overtime, breaks and 8 `AttendanceFlag`s per day. What sits above it is
not:

- "Vacation" is a `permission_requests` row with a rule hard-coded as
  `count >= 2` per month (`admin_permissions_cubit.dart:102`). No leave types,
  no entitlement, no balance, no carry-over, no approval state.
- An attendance correction is allowed **once, on the day itself only**
  (`attendance_local_data_source.dart:537-540`). A punch discovered wrong at
  month end cannot be fixed at all, and there is no manual entry for a day the
  terminal missed entirely.
- Employees carry no `hire_date`, contract dates, ID/Iqama or passport expiry,
  nationality, or salary — so no expiry warnings and no payroll basis.
- No payroll-ready monthly summary: the Excel export is a punch dump, not
  per-employee totals with deductions.
- `corrected_by` on one column is the only audit trail in the app.
- `users.role` is only `admin`/`guard`; no HR role, no user management.
- A shift is fixed per employee (`employees.shift_id`) — no roster or rotation.

**Intended outcome:** HR can run a full month end-to-end inside the app —
records, leave, corrections, payroll summary — and every screen reads as one
product, using the theme that already exists.

---

## Non-negotiables

1. **The theme does not change.** No edits to `colors_light.dart`,
   `colors_dark.dart`, `app_effects.dart`, `app_dimens.dart`,
   `app_text_styles.dart`, or `app_theme.dart` — except *adding* a token when a
   genuinely new need appears, never altering an existing value. The work is
   *adopting* the theme, not revising it.
2. Every new string goes into `assets/translations/ar.json`, `en.json`, and
   `LangKeys`. No raw `'key'.tr()`.
3. Layer rules hold: dumb widgets, Cubit-owned state, data-source-owned
   persistence, thin repos, no `domain/`.
4. Relative imports inside `lib/`. UI files ≤150 lines.
5. Every migration is additive and in-place (`ALTER TABLE` / `CREATE TABLE IF
   NOT EXISTS`), following the existing `if (from < N)` blocks. An install that
   never opens a new screen must behave exactly as before.

---

## Workstream A — Adopt the design system (no behaviour change)

Mechanical, file-by-file, lowest risk, highest visual payoff.

**A1. Type scale.** Replace every raw `TextStyle(fontSize: …)` in
`lib/features/**` with the nearest existing token. Fixed mapping:

| literal | token | literal | token |
|---|---|---|---|
| 9, 10 | `AppTextStyles.micro` / `sectionLabel` / `monoMicro` | 15 | `brand` |
| 11 | `statLabel` (labels) / `meta` (values) | 16, 17 | `subheading` |
| 12 | `caption` / `captionMedium` / `mono` | 18, 20 | `heading` |
| 13 | `body` / `bodyMedium` / `cardTitle` | 22, 24 | `title` |
| 14 | `control` / `controlSemiBold` | 36 | `display` / `statValue` |

Column headers in tables → `columnHeader`. Times, durations and staff numbers →
`mono` / `monoMeta` (the mono faces exist precisely so digits align in the dense
tables). Colour comes from `context.color`, never
`Theme.of(context).colorScheme` (25 files still do) and never `Colors.*`.

**A2. Metrics.** Replace literal paddings, gaps and radii with `AppDimens`:
`pagePadding`/`pagePaddingTop`/`pagePaddingBottom` for page scroll padding,
`cardPadding`/`cardHeaderPaddingV` inside cards, `cardGap`/`sectionGap` between
them, `space*` for everything else, `radius*` for corners, `controlHeight*` and
`icon*` for controls and icons.

**A3. Loading / empty / error states.** Per the loading rules in CLAUDE.md:

- Replace the 24 bare `CircularProgressIndicator` full-screen centres with
  **skeletons that mirror the real layout**. Add to `lib/core/widgets/`:
  `app_skeleton.dart` (shimmer box honouring `MediaQuery.disableAnimations`),
  `app_table_skeleton.dart` (rows at `AppDimens.tableRowHeight`),
  `app_card_skeleton.dart`. These are new *components*, not new tokens — they
  are built from `MyColors.muted` and `AppDimens`.
- Replace the 12 `SnackBar` call sites with the existing `AppToast`.
- Every list gets `AppEmptyState`; every failure gets a localized error state
  with a retry that calls back into the Cubit.
- Button-level actions keep their inline spinner (`AppButton` already does
  this) — no full-screen block for a per-row operation.

**A4. Rewrite the three legacy bodies.** `admin_reports_body.dart`,
`admin_permissions_body.dart` and `dashboard_body.dart` predate the design
system (inline `TextStyle`, `SnackBar`, `GlassCard` with ad-hoc padding).
Rebuild them against the tokens and split into `widgets/` to land under 150
lines.

Representative files (the pattern repeats across all of `lib/features`):
`admin/presentation/refactor/{admin_reports_body,admin_dashboard_body,employee_management_body,punch_report_body}.dart`,
`admin/presentation/widgets/punch_report_*.dart`,
`dashboard/presentation/widgets/{stat_card,dashboard_hero,quick_actions}.dart`,
`device/presentation/widgets/device_*.dart`,
`backup/presentation/widgets/*.dart`.

---

## Workstream B — The desktop shell the design system describes

Build the layout `AppDimens` documents, which makes every route reachable and
puts the 14 unused `sidebar*`/`statusbar*` tokens to work.

New in `lib/core/widgets/shell/`:

- `app_nav_rail.dart` — `AppDimens.sidebarWidth` (236) expanded /
  `sidebarCollapsedWidth` (58) collapsed, painted with
  `context.effects.sidebarGradient`, destinations grouped with
  `sidebarGroupLabel`, active row using `railHighlight` +
  `sidebarActiveForeground`, hover via `sidebarHover`. Collapse state persisted
  through `SettingsLocalDataSource` (SharedPreferences).
- `app_top_bar.dart` — `topBarHeight` (48), first 236px filled with the rail
  colour so brand and rail read as one column (as the `AppDimens` doc-comment
  specifies). Carries global search, the notification bell, theme and language.
- `app_status_bar.dart` — `statusBarHeight` (26): device connection state, last
  sync time, record count, logged-in user.

Then rewrite `admin_shell.dart` and `settings/presentation/refactor/app_shell.dart`
as `Row(rail, Column(topBar, header, content, statusBar))`, and **uncomment and
restore every destination**, grouped:

- *Daily work* — Dashboard, Employees, Attendance, Punch report
- *HR* — Leave, Permissions, Roster, Payroll summary
- *Configure* — Work schedule, Shifts, Holidays, Departments
- *System* — Device, Users, Audit log, Backup, Settings

`AppPageHeader` (already exists) becomes the per-page header at
`pageHeaderHeight` (68). Keep `GoRouter` paths unchanged; add routes only for
the new screens.

---

## Workstream C — Employee records & expiry alerts

**Schema v11** — additive columns on `employees` (all nullable, so existing rows
are untouched): `hire_date`, `contract_start`, `contract_end`, `nationality`,
`national_id`, `national_id_expiry`, `passport_no`, `passport_expiry`,
`insurance_expiry`, `basic_salary` (REAL), `bank_iban`, `emergency_contact`,
`emergency_phone`, `job_grade`, `termination_date`, `termination_reason`.
Plus `CREATE INDEX ix_employees_expiry ON employees (contract_end)`.

- `employee_model.dart` gains the fields with `fromJson`/`toJson`.
- `employee_form_sheet.dart` (349 lines today) splits into tabbed sections under
  `admin/presentation/widgets/employee_form/`: Identity, Employment, Documents,
  Payroll — each its own file, each ≤150 lines.
- New `features/hr_alerts/` (data source + cubit + widgets): a document-expiry
  board that lists what expires in the next N days (N from settings), with
  `AppStatusChip` severities drawn from `MyColors.warning` / `destructive`.
  Surfaced as a card on the admin dashboard and as a rail destination.
- `employee_import_excel_data_source.dart` and the template gain the new
  columns, so HR can bulk-load existing staff files.

---

## Workstream D — Leave management

Replaces the `count >= 2` rule. Hourly permissions stay in
`permission_requests`; day-scale leave becomes its own feature.

**Schema v12** — three tables:

```
leave_types(id, name_ar, name_en, is_paid, annual_days,
            allows_carry_over, max_carry_over_days, affects_attendance,
            color_key, created_at)
leave_balances(id, employee_id, leave_type_id, year,
               entitled_days, carried_days, used_days, adjustment_days,
               updated_at)            -- UNIQUE(employee_id, leave_type_id, year)
leave_requests(id, employee_id, leave_type_id, start_date, end_date,
               days_count, reason, status, requested_by, decided_by,
               decided_at, decision_note, attachment_path,
               created_at, updated_at)
```
Indexes on `leave_requests(employee_id, start_date)` and `(status)`;
`leave_balances(employee_id, year)`.

Seeded types (annual, sick, unpaid, emergency, maternity) — Arabic and English
names in the seed, not in translations, since HR may rename them.

New feature `features/leave/`:

- `leave_local_data_source.dart` owns all of it: day counting that **excludes
  rest days and holidays** by reusing `WorkSchedule.parseRestDays` /
  `HolidaysRepo` and the existing `WorkingDayKind` logic in
  `core/utils/attendance_utils.dart`; overlap rejection; balance debit/credit in
  one transaction with the status change; year-end carry-over capped at
  `max_carry_over_days`.
- `leave_cubit.dart` — list/filter/approve/reject/adjust, emitting error keys.
- Screens: `leave_screen.dart` (requests table + balances panel),
  `leave_calendar_body.dart` (month grid of who is off — reuses the rail/table
  tokens), `leave_type_form` for configuring types and entitlements.
- **Attendance integration:** `AttendanceDayTotals` and `computeDayStatus` gain
  an approved-leave input so a leave day is not counted as an absence. This is
  the one change to existing attendance logic and must be additive — a day with
  no leave row resolves exactly as it does today. Add
  `AttendanceStatus.onLeave` and `WorkingDayKind.leave`.

---

## Workstream E — Corrections, manual entry, and the audit log

**Schema v13** — `audit_log(id, at, actor_user_id, actor_name, action, entity,
entity_id, employee_id, before_json, after_json, note)` with indexes on
`(at)`, `(entity, entity_id)`, `(employee_id)`.

**Schema v14** — on `attendance_records`: `correction_count INTEGER NOT NULL
DEFAULT 0`, `last_correction_reason TEXT`, `is_manual INTEGER NOT NULL DEFAULT 0`.
Plus `attendance_periods(year_month, closed_at, closed_by)` — a closed month is
the new lock, replacing "today only".

Changes in `attendance_local_data_source.dart`:

- `correctPunches` drops the `canCorrectOn(now)` and `isCorrected` refusals and
  instead refuses a day inside a **closed period**. A reason becomes required.
  `corrected_at`/`corrected_by` keep their current meaning (last correction) so
  the device fold's existing skip rule is unchanged; `correction_count`
  increments. Keep `errorCorrectionOrder`/`errorCorrectionTime` validation as
  it is.
- New `createManualRecord(...)` for a day the terminal never saw, writing
  `is_manual = 1`, `source = 'manual'`, and judging the day through the same
  `_scheduleFor` path so a hand-entered day is graded identically.
- New `core/audit/audit_writer.dart`, injected into the data sources that
  mutate HR-visible state (attendance corrections, leave decisions, employee
  edits, user changes, device resets, period close). Writes inside the caller's
  transaction so an audit row cannot survive a rolled-back change.

UI: extend `punch_correction_sheet.dart` with a required reason field and a
correction-history list; new `features/audit/` read-only screen with filters by
actor, entity, employee and date range.

---

## Workstream F — Payroll-ready monthly summary

The report HR hands to finance. No new tables — it aggregates what exists.

- `features/payroll/data/models/monthly_summary_row.dart`: employee, scheduled
  days, worked days, absent days, paid-leave days, unpaid-leave days, holiday
  and rest days, late occurrences and total late minutes, early-out occurrences
  and minutes, overtime minutes, missing-punch count, correction count, and the
  derived deduction figures.
- `payroll_summary_data_source.dart` builds a month by iterating each employee's
  dates through the **existing** `AttendanceDayTotals` and `WorkingDayKind`
  logic plus the new leave rows — no second grading implementation.
- Deduction policy in `SettingsLocalDataSource` (SharedPreferences, not schema):
  late-minute rounding, grace already handled by the shift, absence =
  `basic_salary / 30`, overtime multiplier, whether unpaid leave deducts.
  Policy is configured on the payroll screen, shown in the export header, and
  every figure in the table is traceable to a day.
- Exports reuse the existing engines rather than new ones:
  `core/pdf/report_pdf_engine.dart` (`writeTable`, already handles Arabic
  shaping and font fallback) for the signature-ready per-employee timesheet,
  and the `excel` path modelled on `monthly_punches_excel_data_source.dart` for
  the finance workbook — one summary sheet plus one sheet per department.
- Screen: `payroll_screen.dart` with month picker, department filter, the
  summary table, and a per-employee drill-down to the day rows behind each
  total.

---

## Workstream G — Roles and user management

- **Schema v15** — on `users`: `must_change_password INTEGER NOT NULL DEFAULT 0`,
  `last_login_at TEXT`. `role` already exists; add the `hr` value.
- `core/auth/app_role.dart`: `admin` (everything), `hr` (employees, leave,
  corrections, reports, payroll — not device resets, not backup/erase, not user
  management), `guard` (check-in only, as today).
- `AuthCubit` exposes the capability set; the rail filters destinations from it
  and `AppRouter.redirect` enforces it server-side-equivalently (the redirect is
  the gate, a hidden rail item is only a courtesy).
- New `features/users/`: list, create, reset password, deactivate — reusing
  `auth_local_data_source.dart`'s existing salt+hash routine. Every change
  writes an audit row.

---

## Workstream H — Shift roster

- **Schema v16** —
  `shift_assignments(id, employee_id, date, shift_id, created_at)` with
  `UNIQUE(employee_id, date)` and an index on `(date)`.
- `_scheduleFor(employeeId)` in `attendance_local_data_source.dart` gains a date
  argument and resolves **assignment for that date → `employees.shift_id` →
  company default**. With no assignment rows, behaviour is byte-identical to
  today.
- `roster_screen.dart`: a month × employee grid, cells painted from the shift's
  colour, with bulk paint (select a range + a shift), copy-previous-week, and
  conflict warnings against approved leave.

---

## Cross-cutting details that are easy to miss

- **`backup_data_source.dart:27-34`** holds an explicit erase-table list. Every
  new table (`leave_*`, `audit_log`, `shift_assignments`, `attendance_periods`)
  must be added there, and to the footprint counts at lines 106-110 — otherwise
  "erase all data" silently leaves HR data behind.
- `AppDatabase._schemaVersion` goes 10 → 16, one `if (from < N)` block per
  workstream, in the order C → D → E → G → H. `_requiredTables` stays as the
  three-table sanity set.
- `restoreFrom` already refuses a newer-schema backup and runs migrations on an
  older one — no change needed, but restoring a v10 backup into a v16 build must
  be tested.
- `error_mapper.dart` gains the new stable error keys; `vacationLimitError`
  stays until the leave feature replaces its call site.
- `monthly_punches_excel_data_source.dart` and `report_pdf_engine.dart` are the
  export primitives to extend — do not write a third exporter.

---

## Execution order

Each phase ends compiling, analysing clean, and runnable.

| Phase | Content | Why here |
|---|---|---|
| 1 | A3 skeleton/empty/error components + A1/A2 on `core/widgets` and the admin feature | Establishes the pattern on the busiest screens |
| 2 | B — rail shell, status bar, all destinations restored | Makes everything else reachable |
| 3 | A1/A2/A4 across the remaining features | Mechanical sweep, now against a settled shell |
| 4 | E — audit log + corrections + manual entry | Highest-value HR fix; audit is a dependency of D and G |
| 5 | C — employee records + expiry board | Payroll needs `basic_salary` and `hire_date` |
| 6 | D — leave management | Payroll needs leave days |
| 7 | F — payroll summary + exports | Consumes C, D, E |
| 8 | G — roles and users | Gates everything built above |
| 9 | H — roster | Independent; last because it touches `_scheduleFor` |

---

## Verification

**Per phase**

- `flutter analyze` — zero new issues; result stated in the report.
- `flutter pub get` only (no `build_runner` in this project — models are
  hand-written `fromJson`/`toJson`; this is stated per phase).
- `flutter run -d windows`, then walk the touched screens in **both themes**
  (`/admin/settings` toggle) and **both locales** (Arabic RTL and English LTR).
- Resize to `AppDimens.minWindowWidth` (1024) and to the rail-collapsed state —
  no horizontal overflow, no truncated numbers.

**Migration safety (before each schema phase)**

1. Back up the live DB from the Backup screen on the current build.
2. Run the new build against that file; confirm the upgrade path and that
   existing attendance, statuses and reports read identically.
3. Restore the pre-upgrade backup into the new build and confirm migrations
   re-run cleanly.

**Functional checks**

- *Corrections*: correct a day from last month with a reason → status and flags
  recompute, an audit row appears, the figure moves in the monthly summary.
  Close the period → the same correction is refused with a localized message.
- *Leave*: give an employee 21 annual days, approve a 5-day request spanning a
  rest day and a holiday → `days_count` excludes both, balance drops by the
  working days only, those days show as leave (not absence) in the punch report
  and the payroll summary.
- *Payroll*: a month with a late arrival, an early out, an unpaid leave day, an
  absence and overtime → each figure in the summary matches the day rows in the
  drill-down, and the exported PDF and `.xlsx` agree with the screen.
- *Expiry*: set a contract end 20 days out → appears on the expiry board and the
  dashboard card at the right severity.
- *Roles*: sign in as `hr` → device reset, backup/erase and user management are
  absent from the rail **and** refused by direct URL.
- *Roster*: assign a different shift for one date → that day is graded by the
  assigned shift; remove it → graded by the employee's shift again.
- *Erase*: run "erase all data" → every new table is empty (the
  `backup_data_source` list is the thing being tested).

**Theme guard**

`git diff --stat lib/core/style/` must show no changes to colour, dimension,
effect or text-style **values**; additions only, and only where justified in the
report.
