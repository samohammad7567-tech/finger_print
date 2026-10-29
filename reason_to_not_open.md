# Why SecureAttend-1.0.0-Setup.exe installs but the app takes forever to open

**Short answer: the app code, not `scrip.iss`.**

The installer is sound — it carries every file the app needs, and the payload is
now verified at build time. The delay is in `lib/main.dart`: the app was talking
to the fingerprint terminal over the network *before* it drew its first frame,
and the Windows runner keeps its window hidden until that frame exists. So the
process was running with nothing at all on screen for anywhere between 3 seconds
and forever, depending on how the machine's network answers.

That "depending on the machine" part is also why it looked like a Windows
version problem. It is not. It is a network-reachability problem that varies
from PC to PC.

---

## 1. The window is hidden until Dart's first frame

`windows/runner/flutter_window.cpp`:

```cpp
flutter_controller_->engine()->SetNextFrameCallback([&]() {
  this->Show();
});
```

This is stock Flutter. The Win32 window is created immediately but stays
**hidden** until Flutter renders once — which cannot happen before `runApp()`.

Everything `main()` awaited before `runApp()` was therefore dead time with:

- no window,
- no taskbar button,
- no splash, no error, nothing.

The person double-clicks the icon, sees nothing happen, double-clicks again, and
reports "it doesn't open on this computer." Task Manager shows `attendence.exe`
running the whole time.

**This single fact is what turned a slow startup into an apparent failure to
launch.**

---

## 2. What `main()` was awaiting

```dart
await setupServiceLocator();                   // disk — fine
await getIt<AuthCubit>().loadInitialState();   // disk — fine
await getIt<DeviceCubit>().load();             // <- NETWORK. This is the problem.
await GoogleFonts.pendingFonts()
    .timeout(const Duration(seconds: 3));      // <- NETWORK. Also a problem.
runApp(...);                                   // first frame finally possible
```

### 2a. The terminal handshake — up to 34 seconds, or unbounded

`DeviceCubit.load()` -> `_restartLiveCapture()` -> `ZkLiveCaptureDataSource.start()`
-> `ZKTeco.connect()`.

`connect()` in `flutter_zkteco` 1.2.0 is **not** bounded by the `timeout:` passed
to the `ZKTeco` constructor. It runs four steps in sequence
(`lib/src/connect.dart`, `lib/src/util.dart`, `lib/src/finger_bridge.dart`):

| Step | Code | Cost when the terminal is not reachable |
|---|---|---|
| 1. ICMP ping | `Process.run('ping', ['-n','1', ip])` | up to **4 s** (Windows default `-w 4000`), plus process-spawn cost, which on a machine with aggressive real-time AV is another 0.5–1 s |
| 2. TCP probe | `Socket.connect(..., timeout: 10s)` | up to **10 s** — hard-coded in the package, ignores your settings |
| 3. Real socket | `Socket.connect(..., timeout: self.timeout)` | up to **20 s** (the value this app passes) |
| 4. `CMD_CONNECT` | `await streamController.stream.first` | **no timeout at all — waits forever** |

Worst bounded case: **~34 seconds of blank screen on every launch.**

Step 4 is worse than slow — it is a permanent hang. If the terminal accepts the
TCP connection and then says nothing, that `await` never completes. A ZKTeco unit
allows exactly one SDK session at a time, so this happens whenever another PC (or
a leftover session from a previous crash) already holds the device. A firewall
that *drops* packets instead of *refusing* them does the same thing. In that
state the app never opened at all.

And `skipPing` defaults to `false` in `DeviceSettingsModel`, so step 1 ran on
every launch for everyone.

### 2b. Why it behaved differently on different PCs

Nothing here depends on the Windows version. It depends on what the network does
with a packet aimed at the terminal's IP:

| Machine's situation | What happens |
|---|---|
| Same subnet as the terminal, terminal on | connect succeeds in ~1 s — fast, looks fine (**this is the developer machine**) |
| Terminal switched off, same subnet | ARP fails fast -> ~2–6 s |
| Different subnet / VLAN, router sends ICMP unreachable | fast reject, ~2–6 s |
| Firewall silently **drops** (the common corporate default) | full 34 s |
| Wi-Fi still associating at login (autostart task) | full 34 s |
| Terminal reachable but its one session is taken | **hangs forever — never opens** |

That is the whole "works on some Windows versions and not others" report. It is
"works on some *networks* and not others," and the same PC can flip between the
two on different days.

### 2c. Google Fonts — 3 s on every offline launch

`pubspec.yaml` bundles **no font files**. The entire type scale in
`lib/core/style/theme/app_text_styles.dart` goes through `google_fonts`, which
downloads IBM Plex Sans, IBM Plex Sans Arabic, Spectral and IBM Plex Mono from
`fonts.gstatic.com` at runtime.

`main()` awaited `GoogleFonts.pendingFonts()` with a 3-second timeout before
`runApp()`. On a machine with internet that has run the app before, the fonts are
cached on disk and this is instant. On a staff machine with no internet, or
behind a proxy that drops rather than refuses, **the fetch can never succeed, so
the full 3 seconds was paid on every single launch, forever**, and the fonts fell
back to Segoe UI anyway — so the app paid the delay *and* lost the typography.

Worth being concrete about what that cost beyond the seconds. `google_fonts`
registers each face under its own variant-qualified family name, which is why
`AppTheme` had to read `AppTextStyles.body.fontFamily` back out of a resolved
style instead of naming "IBM Plex Sans". When the fetch failed, every one of
those names resolved to nothing: the whole app — dense attendance tables,
tabular figures, the Arabic UI — fell through to Segoe UI, at synthesised
weights. The product looked different on a staff machine than it did on the
developer's, every single time.

### 2d. The rest

`setupServiceLocator()` does SharedPreferences, opens and migrates the SQLite
catalogue, seeds the default admin and runs `closeFinishedDays()`. This is local
disk, bounded, and legitimately needed before the first screen. It is not the
problem, but it sat on top of everything above.

---

## 3. What is *not* the problem

Checked and cleared, so nobody re-investigates these:

- **Missing DLLs.** Every import of `attendence.exe`,
  `file_selector_windows_plugin.dll` and `sqlite3.dll` is satisfied by the
  installed payload: `MSVCP140.dll`, `VCRUNTIME140.dll` and `VCRUNTIME140_1.dll`
  ship app-local; the `api-ms-win-crt-*` imports resolve against the Universal
  CRT that every supported Windows build carries; the rest are `KERNEL32`,
  `USER32`, `ole32`, `SHELL32`, `ADVAPI32` and `dwmapi` from System32.
- **The app-local VC++ runtime being too new.** The shipped v145 (14.51) CRT
  imports only `api-ms-win-crt-*` and two KERNEL32 functions
  (`CreateThreadpoolWork`, `GetSystemTimePreciseAsFileTime`), both present since
  Windows 8. It does not need a newer OS than the installer already requires.
- **Compression.** `lzma2/max` is decompressed once at install time, not at
  launch.
- **The database location.** Per-user under `%APPDATA%\com.example\attendence`,
  which a `PrivilegesRequired=lowest` install can always write.

---

## 4. Genuine Windows-version limits in `scrip.iss` (by design)

These are real refusals, they are correct, and they are worth knowing when
someone says "it won't install":

```ini
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
```

The installer will **refuse to run at all**, with a message and no install, on:

- Windows 7, Windows 8, Windows 8.1
- Windows 10 older than version 1809 (builds 1507 / 1607 / 1703 / 1709 / 1803)
- Windows Server 2016 (build 14393)
- any 32-bit Windows

This is not a bug — Flutter's Windows desktop target requires Windows 10 1809 or
later, and there is no 32-bit Flutter Windows build. If a machine falls into that
list, the answer is to update Windows, not to change the installer.

**Two more things that look like "it doesn't run":**

- **SmartScreen.** The installer is unsigned, so Windows shows
  *"Windows protected your PC"* and hides the Run button behind *More info*.
  Staff read that as "it won't install." Fixing it properly means an
  Authenticode code-signing certificate; an EV certificate clears SmartScreen
  immediately, a standard one clears it once enough installs build reputation.
- **Windows Firewall.** The first outbound connection to the terminal can raise
  a firewall prompt. A standard (non-admin) user cannot approve it, so it is
  dismissed and the connection is silently blocked from then on — which used to
  mean the full 34-second stall on every launch.

---

## 5. The fix

### `lib/main.dart` — nothing that can touch the network runs before the first frame

- `getIt<DeviceCubit>().load()` is no longer awaited before `runApp()`. It is
  scheduled with `addPostFrameCallback` and left running in the background, so
  the terminal link comes up *underneath a window that is already on screen*.
  `DeviceCubit` is a singleton and the device screen renders from its state, so
  the UI updates as the link establishes — exactly as it already did when the
  user opened the device screen by hand.
- The Google Fonts pre-warm is **gone entirely**, along with the `google_fonts`
  dependency — the faces are bundled now (below), so there is nothing to wait
  for. Flutter reads them out of the asset bundle when the first text is laid
  out.

**Result: the window now appears in roughly the time it takes to open the SQLite
file — measured at 131 ms to input-idle on the release build — on every machine,
whether or not the terminal is reachable and whether or not there is internet.**

### The fonts are bundled

`assets/fonts` now holds all 17 faces (3.0 MB), declared in the `fonts:` section
of `pubspec.yaml`:

| Family | Weights | Notes |
|---|---|---|
| IBM Plex Sans | 400, 500, 600, 700 + 400 italic | the interface |
| IBM Plex Sans Arabic | 400, 500, 600, 700 | the Arabic companion every fallback chain points at |
| IBM Plex Mono | 400, 500, 600, 700 | hashes, IDs, paths, timestamps |
| Spectral | 400, 500, 600, 700 | the serif ranks |

400/500/600/700 for each because the scale asks for regular, medium and
semibold, and the widgets use `FontWeight.bold` directly in 65 places. A
declared weight means Flutter uses the drawn face instead of synthesising one
from the regular.

`lib/core/style/theme/app_text_styles.dart` lost its `_resolve` /
`_fallbackFor` indirection — the 23 styles are plain `const TextStyle`s naming
the families directly, which is exactly what the file's own doc comment always
said it would look like "with the files sitting in `assets/fonts`". `AppTheme`
no longer has to read the family name back out of a resolved style.

`tool/fetch_fonts.ps1` fetches the set from the Google Fonts CSS API and is
checked in, so the bundle is reproducible rather than a folder of files with no
provenance. It takes static TTFs rather than the variable versions on purpose:
Flutter maps `fontWeight` onto a variable font's `wght` axis inconsistently
across platforms, which is the same class of machine-to-machine difference this
whole exercise is about. Both OFL 1.1 licences ship verbatim beside the faces
(`OFL-IBMPlex.txt`, `OFL-Spectral.txt`); they are not declared as assets, so
they stay out of the build.

Cost: the installer went from 12.6 MB to **13.2 MB**. The app now makes no
network request at all except to the fingerprint terminal itself.

### `lib/features/device/data/data_source/zk_live_capture_data_source.dart`

`ZKTeco.connect()` is now bounded by a 35-second timeout. On timeout the
half-open socket is destroyed — so the terminal's single session is released for
the next attempt instead of being held by a client that stopped listening — and
the existing 20-second retry is armed. The unbounded `CMD_CONNECT` wait can no
longer leave live capture permanently dead for the life of the process.

### `lib/features/device/data/data_source/zk_device_data_source.dart`

The same 35-second bound on `connect()` in `_connectAndRun`. This path runs
behind `ZkDeviceGate`, so an unbounded hang there did not just break one
operation — it held the gate lock and blocked **every** later device operation,
including the auto-sync timer and the "Test connection" button, for the rest of
the session.

### `scrip.iss`

Added `vcruntime140_threads.dll` and `concrt140.dll` (both
`skipifsourcedoesntexist`). The v145 toolset split parts of the runtime into new
DLLs, and which ones the runner references changes when Visual Studio updates on
the build machine. A DLL the exe imports and the installer does not carry is
invisible here — a developer machine has the system-wide redistributable to fall
back on — and fatal on a clean staff machine: the process dies with `0xc0000135`
before `wWinMain`, no window, no error dialog.

### `build_installer.ps1`

Added a payload verification step. It parses the PE import directory of
`attendence.exe` and every shipped DLL, and fails the build if any import is
satisfied by neither the payload, nor `System32`, nor the `api-ms-win-*` API
sets. That is the one failure this build could not previously see in its own
output, and it is precisely the "works on my machine" class of bug. A good build
now prints `==> imports satisfied by the payload`.

---

## 6. Recommended follow-ups (not done — they change product behaviour)

1. **Default `skipPing` to `true`.** Most office networks block ICMP while
   leaving port 4370 open, so the ping is a 4-second tax that usually tells you
   nothing. It no longer blocks the window, but it still delays the first sync.
   Existing installs keep their stored setting; only new installs would change.
2. **Sign the installer.** Removes the SmartScreen wall described above.
3. **Show the link state in the UI.** Now that the terminal connects after the
   window opens, the device screen should make "connecting…" visible for those
   few seconds rather than looking briefly disconnected.

---

## الخلاصة بالعربية

المشكلة في كود التطبيق وليست في ملف `scrip.iss`.

كان التطبيق يحاول الاتصال بجهاز البصمة عبر الشبكة **قبل** رسم أول شاشة، ونافذة
Flutter على ويندوز تبقى مخفية حتى تُرسم أول شاشة. النتيجة: البرنامج يعمل في
الخلفية بدون أي نافذة لمدة تصل إلى ٣٤ ثانية — وإلى ما لا نهاية إذا كان الجهاز
مشغولاً بجلسة أخرى أو خلف جدار حماية يُسقط الحزم بصمت. لهذا بدا الأمر وكأنه
اختلاف في إصدارات ويندوز، بينما هو في الحقيقة اختلاف في الشبكة من جهاز لآخر.

كذلك كان التطبيق يُنزّل خطوطه من الإنترنت عند كل تشغيل، فينتظر ٣ ثوانٍ إضافية
ثم يعرض كل الواجهة بخط Segoe UI على أي جهاز بلا إنترنت — أي أنه كان يدفع
التأخير ويخسر التنسيق معًا.

أُصلح الأمر بثلاثة أشياء: نقل الاتصال بالجهاز إلى ما بعد ظهور النافذة، ووضع حدّ
زمني (٣٥ ثانية) للاتصال الذي كان بلا حدّ، وتضمين الخطوط الأربعة داخل التطبيق
(‏٣ ميجابايت في `assets/fonts`) بدل تنزيلها. النافذة الآن تظهر خلال أقل من
ثانية على أي جهاز، والتطبيق لم يعد يتصل بأي شيء عبر الإنترنت سوى جهاز البصمة
نفسه.

ملاحظة: المثبّت يرفض العمل عمداً على ويندوز ٧ و ٨٫١ وعلى ويندوز ١٠ الأقدم من
الإصدار 1809 وعلى النسخ ٣٢-بت — هذا شرط من Flutter نفسه ولا يمكن تجاوزه.
