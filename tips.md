# Tips — turning this into a tool the company can run on

Written against the code as it stands today. Every item names the file it
touches and says *why it matters here*, not in general. Effort is rough:
**S** ≈ under a day, **M** ≈ a few days, **L** ≈ a week or more.

The app is already solid on the hard part — pulling a ZKTeco terminal, folding
raw punches into days, and judging them against per-employee shifts. What is
missing is mostly around the edges of that: the days nobody scanned, the
calendar, and everything an admin needs once the numbers leave the screen.

---

## Tier 1 — the data is incomplete until these are fixed

These are not features. They are gaps that make the numbers wrong or missing,
and they undercut every report built on top.

### 1.1 ~~An absence is never recorded~~ — **DONE**

Nothing in the app ever writes an `absent` row for somebody who simply did not
come in.

- `DeviceSyncDataSource._foldDay` only creates a record when punches exist for
  that employee and date.
- `AdminAttendanceCubit.loadMonth` counts `absentDays` by looping
  `empRecords` — rows that already exist.
- The `absent` status is only ever produced two ways: an admin picking it by
  hand on the check-in screen, or somebody scanning in *after* their day had
  already ended (`AttendanceDayTotals.isAbsentArrival`).

So the most important fact about an employee — **they were not here** —
produces no row, appears nowhere in the punch report, and counts as zero in the
monthly summary. A person who never turns up all month looks identical to a
person with no data yet.

**Built.** `DayClosingDataSource` + `DayClosingRepo`:

- Runs at startup and after every device sync (punches first, so only genuinely
  empty days are closed). A marker in preferences means it does a few queries
  and stops, rather than rescanning history each launch.
- Only ever *adds* a row where there is none — a punch, a manual entry and a
  correction are all untouchable, and re-running it is free.
- Skips, per employee: anybody added after the date, anybody whose own shift
  rests then, anybody on a holiday, anybody on approved vacation, and anybody
  inactive.
- **Refuses to close a date nothing at all was recorded on.** A whole workforce
  absent on one day almost always means an outage, not an absence.
- Rows are marked `source = 'system'`. If punches arrive later, the fold
  reclaims the row and hands it back to `'device'`, so a day that turned out to
  be worked can never be cleared by `reopenRange`.

First run reaches back 62 days, bounded — but the no-evidence guard means days
before the app was in use cost one query and write nothing.

### 1.2 ~~There is no weekend or holiday calendar~~ — **DONE**

Grepping the whole of `lib/` for weekend/holiday concepts returns one comment
and nothing else. Every calendar day is treated as a working day.

Today this is masked by 1.1: since no-show days produce no rows, Fridays and
Saturdays are silently ignored. The moment you add absence closing, **every
weekend becomes an absence for everybody**.

**Built.** Two pieces, both admin-maintained:

- Weekly rest days on `WorkSchedule.restDays`, set per shift and on the company
  default (Admin → Settings → Work hours / Shifts).
- A `holidays` table with a date *range* per entry, on its own screen
  (Admin → Settings → Holidays).
- One predicate, `WorkCalendar.kindOf`, consulted by the punch report, the
  monthly summary and the Excel export. A holiday outranks a rest day.
- `AttendanceDayTotals.dayKind` suppresses the late / early-out / absent
  judgements on a day off and flags it as worked-on-a-rest-day instead.

**1.1 is now unblocked** — absence closing can be written against
`WorkCalendar` without turning every weekend into an absence.

Original plan, for reference:

- **Weekly rest days** per shift (a bitmask or a set of weekday numbers on the
  `shifts` row). Different shifts genuinely rest on different days.
- **A holidays table** — date, name, and whether it is paid. Eid, National Day,
  and company shutdowns.

Then one predicate — `isWorkingDay(employee, date)` — that the absence pass,
the monthly summary, and the Excel export all consult. Put it next to
`WorkSchedule` so there is exactly one answer.

### 1.3 Overnight shifts cannot be expressed — **M/L**

`WorkSchedule.isValid` requires `workEndMinutes > workStartMinutes`, and
`ShiftsLocalDataSource._validate` refuses anything else. A 22:00 → 06:00 guard
shift — the obvious case for a company running multiple shifts — cannot be
entered at all.

The blocker is not validation, it is the fold: `_foldDay` groups punches by
calendar date (`punch_time LIKE '$date%'`), so a night shift's punches land in
two different days and neither reads correctly.

**Fix:** give the shift an "ends next day" flag, and make the fold group by
*shift window* rather than calendar date — a punch belongs to the day whose
window contains it. Attribute the record to the date the shift *started*.
Worth scoping properly; it touches the most delicate code in the app.

### 1.4 Corrections are too rigid for real payroll — **S**

`AttendanceRecordModel.canCorrectOn` allows one correction, on the day itself.
You already hit this wall while testing, and payroll disputes surface days or
weeks later — exactly when the rule forbids fixing them.

**Fix:** keep the audit trail, drop the one-shot limit. Move from two columns
(`corrected_at`, `corrected_by`) to a `punch_corrections` table — one row per
edit, holding before/after times, who, when, and a required reason. Then:

- Corrections stay possible until the month is **locked** (see 2.4).
- The report shows the correction count, and the history is inspectable.
- The device fold keeps skipping any day carrying corrections, as it does now.

This is strictly better than the current rule: more useful *and* more
accountable.

### 1.5 Only one user account can ever exist — **S**

`AuthCubit.register` exists but nothing in the UI calls it. There is no account
management screen. In practice the whole company shares the seeded admin login.

That makes `correctedBy` — and the password gate in front of it — close to
meaningless: every correction is signed "Administrator", and the password
everyone knows is the one that authorises it.

**Fix:** an admin-only Users screen (create, disable, reset password, set
role). The data layer already supports it — `AuthLocalDataSource` has
`register`, `changePassword`, and an `is_active` column. It is mostly UI.

---

## Tier 2 — from a record-keeper to a management tool

Tier 1 makes the data true. This tier makes it *useful*.

### 2.1 ~~Per-employee pattern summary~~ — **DONE**

The flags now show what was unusual about each *day*. What an admin actually
asks is "how is this person doing this month?"

**Built.** A "By employee" card above the punch report table:

- One line per person, **sorted worst-first** — days flagged, then a chip per
  flag with its count, then total late and early-out minutes.
- Chips are ordered by severity, not frequency, so one absence is not buried
  under six latenesses.
- An **"Issues only" toggle** in the filter bar, showing the count beside it.
  It narrows the table, the totals *and* the exports together, and needs no
  reload — the range is already in hand.
- Working a rest day or a holiday is recorded but is **not** counted as an
  issue: they did nothing wrong by coming in.

`EmployeePattern` (in `presentation/refactor/`) is pure derivation over
`AttendanceDayTotals` — no new arithmetic, nothing stored.

### 2.2 Thresholds that raise a flag on their own — **M**

`AdminNotificationsRepo` and the early-leave threshold already exist
(`CheckInCubit._checkEarlyLeaveThreshold`). Generalise it into admin-set rules:

> "3 lates in a rolling 30 days" · "2 consecutive absences" · "no check-out
> twice in a week"

Surface them on the admin dashboard as a short "needs attention" list. This is
the difference between a system you have to interrogate and one that tells you
where to look.

### 2.3 Payroll-ready export — **M**

The Excel export is a faithful log. Payroll needs a summary line per employee:
normal hours, approved overtime hours, unpaid absence days, total late minutes,
and a deductions column driven by company rules.

Add it as a second sheet in the existing workbook
(`MonthlyPunchesExcelDataSource` already writes multiple sheets), and make the
column mapping configurable so it can be pasted straight into whatever payroll
system the company uses.

### 2.4 Month locking — **S**

Once payroll has run, that month must stop moving. Add a `locked_months` table
(year, month, locked_by, locked_at). While a month is locked: no corrections,
no re-fold, no absence closing. Unlocking is an explicit, logged admin action.

This is what makes 1.4's relaxed correction rule safe.

### 2.5 Overtime approval — **S/M**

`AttendanceDayTotals.overtime` counts overtime automatically from the times.
Nobody approves it. Somebody who lingers past the overtime hour earns it by
accident.

Add an approval state per day's overtime — pending / approved / rejected — and
have payroll totals count only approved hours. Keep the derived figure visible
as "claimed" beside it.

### 2.6 Leave balances — **M**

`permission_requests` records vacations but tracks no entitlement. Nobody can
answer "how many days does he have left?"

Add an annual entitlement per employee and a running balance, with the existing
permission rows drawing it down. Show the balance when a vacation permission is
being entered.

### 2.7 Roles beyond admin and guard — **M**

The `role` column only ever holds `admin` or `guard`, and the router splits on
`isAdmin`. A department head who should see their own team — and nobody else —
has no place to stand.

Add a **supervisor** role scoped to one or more departments: read-only reports
for their people, no employee editing, no settings.

---

## Tier 3 — before this runs the company's payroll

### 3.1 Backups are manual, and this is the only copy — **S, urgent**

There is no server. `guardsync.db` on one PC is the entire attendance history
of the company, and it is backed up only when somebody remembers to open the
Backup screen and click.

**Fix:** a scheduled automatic backup — on app close and daily — to a second
location (network share or external drive), keeping the last N copies dated.
`AppDatabase.backupTo` already does the WAL checkpoint and copy correctly; it
just needs a scheduler and a retention rule.

Also add a **restore** path and, more importantly, *test it*. An untested
backup is a guess.

### 3.2 The app still identifies itself as `com.example` — **S**

`android/app/build.gradle.kts` (`applicationId`), `linux/CMakeLists.txt`
(`APPLICATION_ID`), and `windows/runner/Runner.rc` (`CompanyName`,
`LegalCopyright`) all still carry the Flutter template defaults.

On Windows this decides where the database lives —
`%APPDATA%\com.example\attendence\guardsync.db`. Change it **before** wider
deployment, and plan to migrate the existing file when you do, or the app will
come up looking at an empty database.

### 3.3 The seeded admin password is the email address — **S, urgent**

`service_locator.dart`:

```dart
const _seedAdminPassword = String.fromEnvironment(
  'SEED_ADMIN_PASSWORD',
  defaultValue: 'mohammadwork199700@gmail.com',
);
```

Anyone who has seen the login screen can guess it, and it is committed to the
repository. The `--dart-define` override is the right mechanism, but the
default is what actually ships unless every build remembers to set it.

**Fix:** force a password change on first sign-in of a seeded account, and
refuse to seed at all in release builds without an explicit define.

### 3.4 Password hashing freezes the UI — **S**

`AuthLocalDataSource._hash` runs 120,000 PBKDF2 iterations on the main isolate.
Sign-in and the new correction password gate both pay it — roughly a second
where the window stops responding and the spinner does not animate.

**Fix:** move `_hash` into `compute()` / an isolate. Small change, affects
login and the confirm dialog together.

### 3.5 An audit log for everything, not just corrections — **M**

Corrections leave a trail. Deleting an employee, deleting a shift, changing the
work hours, and dismissing a device user do not — and each of them silently
changes what past days mean.

**Fix:** one `audit_log` table (who, when, what, before, after) written from
the data sources, with an admin-only viewer. In a system that decides pay, "who
changed this and when" needs an answer that does not depend on memory.

---

## Tier 4 — technical debt worth clearing

### 4.1 A failing test is being carried — **S**

`test/zk_punch_parser_test.dart: refuses a buffer that decoded into rubbish`
has been failing throughout recent work. It asserts that a misaligned buffer
yields nothing, and the parser currently returns eight punches instead.

If the parser is genuinely accepting skewed reads, that is fabricated
attendance data reaching the database — worth diagnosing on its own merits, not
just to get the suite green. Either way, a permanently red suite trains
everyone to ignore it.

### 4.2 Reports load the whole range into memory — **M**

`PunchReportCubit.load` reads every record in the range and builds a
`PunchReportRow` for each; `exportMonthlyExcel` reads a whole month for every
employee. Fine for 40 people. At 300 people over a year it will crawl.

**Fix:** paginate the table and aggregate in SQL rather than in Dart for the
summary figures. Not urgent — but know where the ceiling is before you hit it.

### 4.3 `device_punches` grows without bound — **S**

Every sync re-reads the terminal's whole buffer, deduplicated by
`ix_punch_unique`. The raw log is deliberately never rewritten, which is right —
but it also never ages out.

**Fix:** archive punches older than a locked month into a side table or a
separate file, keeping the folded records. Keeps the working database small and
backups fast.

### 4.4 Employee number reuse — **S**

`app_sequences` correctly stops numbers being reissued. Worth confirming the
same guarantee holds for the Excel import path, which can supply its own
numbers.

---

## Suggested order

1. **3.1** automatic backups and **3.3** the seeded password — the two that can
   cost you the whole database or the whole audit trail.
2. ~~**1.2** the working-day calendar, then **1.1** absence closing~~ — both
   done. Absences are recorded and weekends are not.
3. **1.5** real user accounts, so 1.4's audit trail means something.
4. **1.4** corrections with history, then **2.4** month locking to bound them.
5. **2.1** the per-employee summary — the smallest change with the most visible
   payoff for an admin.
6. **3.2** the app identifier, before the install base grows enough to make
   migrating the database file painful.
7. Everything else by whichever pain is loudest.

---

## What is already good, and worth not breaking

Worth stating, because these are the parts most likely to be damaged by a
careless change later:

- **One place decides what a day means.** `AttendanceDayTotals` is read by the
  punch report, the monthly summary and both exports, so they cannot disagree.
  Keep new figures there rather than recomputing them per screen.
- **Derived, not stored.** Absence, status and the new day flags are worked out
  from the times on read, so a record folded under older rules reads correctly
  immediately and cannot contradict its own punches. Resist adding columns that
  cache these.
- **Raw punches are never rewritten.** `device_punches` is the ground truth and
  the fold is idempotent, so a day can always be rebuilt.
- **Errors are localization keys all the way up.** Data sources throw
  `ApiException(LangKeys.x)`, cubits carry the key, the UI translates. One
  error path, no stray English in an Arabic build.
- **Arabic is a first-class language, not a translation layer.** Keep adding
  both JSON files and the `LangKeys` constant together.
