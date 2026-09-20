# GuardSync — Attendance Management System

A Flutter **Windows desktop** app that reads attendance directly from a ZKTeco
fingerprint terminal on the local network and stores everything in a local
SQLite file. No server, no database to provision, no network beyond the LAN.

```
attendence/
  lib/          Flutter app (data source → repo → cubit → UI)
  backend/      Unused. Kept from the previous client/server design — see below.
```

## Running

```bash
flutter pub get
flutter run -d windows
```

On first launch the app creates its database and seeds one admin account:

| Email | Password |
| --- | --- |
| `admin@guardsync.local` | `Admin@12345` |

**Change this before any real deployment.** Override the seed at build time:

```bash
flutter build windows --release \
  --dart-define=SEED_ADMIN_EMAIL=you@company.com \
  --dart-define=SEED_ADMIN_PASSWORD='a-strong-password'
```

The seed only runs when the account table is empty, so it never overwrites
existing users.

## The ZKTeco terminal

Configure it under **Admin → Settings → Fingerprint Terminal**.

| Setting | Notes |
| --- | --- |
| IP address | The terminal's address on the LAN, e.g. `192.168.1.201` |
| Port | `4370` on every ZKTeco standalone unit unless changed in its Comm menu |
| Comm key | Empty on a factory-default device |
| Use TCP | On for modern firmware; turn off for older UDP-only units |
| Skip ping check | Turn on when the network blocks ICMP but 4370 is open |
| Automatic sync | Off, or every 5–60 minutes |

**Test connection** confirms the terminal answers and reports its name, serial,
firmware and clock. A clock more than two minutes out is flagged, with a button
to set it from this PC — punch timestamps come from the device, so drift files
attendance under the wrong time and, past midnight, the wrong day.

### How punches become attendance

The terminal records **six punch modes**. The operator picks one on the keypad
before scanning, and each fills its own column:

| Mode | Code | Column |
| --- | --- | --- |
| Check In | 0 | `check_in_time` |
| Check Out | 1 | `check_out_time` |
| Break Out | 2 | `break_out_time` |
| Break In | 3 | `break_in_time` |
| Overtime In | 4 | `overtime_in_time` |
| Overtime Out | 5 | `overtime_out_time` |

"In" modes take the earliest scan of that mode and "out" modes the latest, so
repeated breaks collapse to the first departure and the last return.

The fold also:

- **falls back** when a day carries no mode at all — every terminal reports 0 on
  every scan when nobody pressed a mode key, which is how an untouched backlog
  looks. Those days use earliest-scan-as-arrival, latest-as-departure so they
  still produce a usable record. Any typed punch on a day disables the fallback;
- collapses repeat scans inside a 60-second window, so a reader that fires three
  times on one finger does not look like a shift;
- computes `present` / `late` / `early_leave` / `travel_permission` with the same
  rules the manual screens use, evaluated against **the punch's own date** rather
  than today, so a backlog pulled after a weekend is graded correctly;
- widens an existing manual record rather than replacing it — earliest arrival
  and latest departure win, while notes and guard name are left untouched.

### Identity: `userId`, not `uid`

The terminal exposes two numbers per person and they are **not interchangeable**.
On the unit here they are not even in the same order:

| `uid` (enrolment slot) | `userId` (what attendance records use) | Name |
| --- | --- | --- |
| 2 | 3 | ابو خالد |
| 3 | 2 | ابو عمرو |
| 4 | 1 | ابو يوسف |

Attendance records identify people by **`userId`**, so that is what lands in
`employees.device_user_id`. The `flutter_zkteco` package cannot supply it: its
own `setUser` writes `userid` at byte 48 of the 72-byte record, but its reader
takes it from bytes 68–72 — inside the trailing padding — so every user comes
back with an empty id. Falling back to `uid` would file each person's attendance
under someone else. `ZkUserParser` therefore reads the raw buffer directly.

Names are stored on the device in **Windows-1256**, not UTF-8, and arrive as
mojibake ("ÇÈæ ÎÇáÏ") unless re-decoded — `core/utils/cp1256.dart` handles that.

### The punch report

**Admin → Settings → Punch Report** is the six-column table: one row per person
per day, with worked time (arrival to departure, minus a completed break) and
overtime totalled at the top. Filter by date range or employee; **Copy as CSV**
puts the whole table on the clipboard for a spreadsheet.

Every raw punch is stored in `device_punches` under a unique
`(device_user_id, punch_time)` index. The device returns its whole buffer on
every read, so this is what makes a re-sync idempotent.

### Employee mapping

Sync **imports employees automatically**: anyone enrolled on the terminal who is
not already in the app gets an employee record, using the device's own name.
Existing employees are never overwritten — an admin's edits outrank the keypad.
Turn this off under "Import employees from device" to map people by hand.

Punches for an ID nobody is mapped to are **kept, not discarded**. They appear
under "Unmapped device users" on the terminal screen, and mapping one applies its
entire backlog immediately. Enrolling someone on the device before adding them to
the app loses nothing.

## Backup

All data lives in one file on this PC:

```
%APPDATA%\com.example\attendence\guardsync.db
```

**Admin → Settings → Backup** writes a timestamped copy to
`Documents\GuardSync Backups\`. There is no server holding a second copy — if
this machine is lost or reimaged without a backup, the history goes with it. The
terminal retains its own punch log, so attendance could be partly rebuilt, but
employees, permissions and notes exist only here.

## Layers

| Layer | Responsibility |
| --- | --- |
| `core/database/app_database.dart` | Opens SQLite (via `sqflite_common_ffi`), owns the schema, writes backups |
| `features/*/data/data_source/*_local_data_source.dart` | All SQL. Failures become `ApiException` carrying a `LangKeys` value |
| `features/device/data/data_source/zk_device_data_source.dart` | The only code that opens a socket to the terminal |
| `features/device/data/data_source/device_sync_data_source.dart` | Punches → day records |
| `features/*/data/repos/*` | Thin delegation |
| `features/*/presentation/cubit/*` | Loading, filters, error keys, UI-ready state |

Data sources kept the exact method signatures of the HTTP ones they replaced, so
the repos, cubits and screens were unaffected by the move off the API.

## Localization

Arabic is primary. Every user-visible string is a key in both
`assets/translations/ar.json` and `en.json`, declared in
`lib/core/localization/lang_keys.dart`, used via `LangKeys.x.tr()` — never a raw
string. Error keys follow the same rule, so a device or database failure is
translated like any other text.

## Tests

```bash
flutter test
```

`test/device_sync_test.dart` covers the fold — ordering, debounce, idempotent
re-sync, the housing and Thursday-travel rules, unmapped-then-mapped recovery,
and the manual-record merge — none of which need the hardware present.

## About `backend/`

The app previously ran against an ASP.NET Core API on PostgreSQL. That folder is
no longer referenced by any Dart code and nothing starts it. It is **not tracked
in git**, so it exists only on this disk — it was left in place deliberately
rather than deleted. Remove it once you are sure the local build is what you
want to keep.
