import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/di/service_locator.dart';
import 'core/utils/app_bloc_observer.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/device/presentation/cubit/device_cubit.dart';
import 'app.dart';

/// Nothing awaited before [runApp] touches the network.
///
/// The Windows runner keeps its window hidden until Flutter renders its first
/// frame (`SetNextFrameCallback(Show)` in `windows/runner/flutter_window.cpp`),
/// and the first frame cannot happen before [runApp]. Every millisecond spent
/// here is therefore a millisecond where the process is running and the screen
/// is empty — no window, no taskbar button, nothing for the person who
/// double-clicked the icon to look at. Work that can stall on a socket belongs
/// after the first frame, where the UI can show it happening — and work that
/// only needs a file belongs in the asset bundle, not on a font CDN.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();
  await EasyLocalization.ensureInitialized();
  // Day and month names in a locale other than the default are unavailable
  // until this runs — the reports name the day of the week in both languages.
  await initializeDateFormatting();
  // Opens the SQLite database and seeds the first admin. Local disk only.
  await setupServiceLocator();
  await getIt<AuthCubit>().loadInitialState();

  // The four families the scale is set in are bundled under `assets/fonts`, so
  // there is nothing to pre-warm and nothing to wait for: Flutter reads them
  // out of the asset bundle when the first text is laid out. This used to be a
  // three-second `GoogleFonts.pendingFonts()` await, paid on every launch of
  // every machine that could not reach fonts.gstatic.com — which is most staff
  // machines — and paid for nothing, since the app then rendered in Segoe UI
  // anyway.

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const GuardSyncApp(),
    ),
  );

  // Arms the terminal's auto-sync timer and opens the live-capture session, so
  // punches keep arriving without anyone opening the device screen first.
  //
  // Deliberately after the first frame and deliberately not awaited: reaching
  // the terminal is a ping, a TCP probe and a session handshake against a
  // device that may be switched off, on another subnet, or behind a firewall
  // that drops silently. Awaiting it here used to hold the window closed for
  // the length of all three. The cubit is a singleton and the device screen
  // renders from its state, so the link comes up underneath a running UI.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(getIt<DeviceCubit>().load());
  });
}
