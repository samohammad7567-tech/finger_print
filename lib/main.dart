import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/di/service_locator.dart';
import 'core/style/theme/app_text_styles.dart';
import 'core/utils/app_bloc_observer.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/device/presentation/cubit/device_cubit.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();
  await EasyLocalization.ensureInitialized();
  // Day and month names in a locale other than the default are unavailable
  // until this runs — the reports name the day of the week in both languages.
  await initializeDateFormatting();
  // Opens the SQLite database and seeds the first admin.
  await setupServiceLocator();
  await getIt<AuthCubit>().loadInitialState();

  // Arms the terminal's auto-sync timer at launch, so punches keep arriving
  // without anyone opening the device screen first.
  await getIt<DeviceCubit>().load();

  // Touching the scale registers the faces with `google_fonts`, which fetches
  // them on first run. Waiting for that means the first frame is already set
  // in IBM Plex instead of flashing the system fallback and re-laying-out —
  // but it is a *network* call, so it is bounded: a machine that is offline or
  // behind a slow proxy shows the app on the fallback face rather than sitting
  // on a blank window until the request gives up.
  AppTextStyles.body;
  AppTextStyles.brand;
  AppTextStyles.mono;
  await GoogleFonts.pendingFonts().timeout(
    const Duration(seconds: 3),
    onTimeout: () => const <void>[],
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const GuardSyncApp(),
    ),
  );
}
