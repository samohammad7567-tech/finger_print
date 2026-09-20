import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Where the ASP.NET Core API lives.
///
/// Override at build time so a device build never has to be edited by hand:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return '$_devHost/api';
  }

  /// The Android emulator reaches the host machine through 10.0.2.2, every
  /// other local target reaches it as localhost.
  static String get _devHost {
    if (kIsWeb) return 'http://localhost:5080';
    if (Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://localhost:5080';
  }
}
