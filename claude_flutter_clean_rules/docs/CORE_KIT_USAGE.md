# How to Use the Reusable Flutter Core Kit

Copy these folders from the Core Kit into a new project:

```text
lib/core
lib/features/settings
assets/translations
```

Add dependencies from `pubspec_dependencies.yaml` into the new project's `pubspec.yaml`.

Typical packages:

```yaml
dependencies:
  flutter_bloc:
  get_it:
  shared_preferences:
  easy_localization:
  firebase_core:
  firebase_auth:
  cloud_firestore:
  supabase_flutter:
  fluttertoast:
```

Keep only the packages the project actually uses.

## Main Setup

Initialize localization, service locator, Firebase/Supabase if needed, then provide AppPreferencesCubit above MaterialApp.

Use:

- AppTheme.light
- AppTheme.dark
- themeMode from AppPreferencesCubit
- EasyLocalization or the project's custom localization system

## New Feature Template

```text
lib/features/products/
  data/
    data_source/products_remote_data_source.dart
    models/product_model.dart
    repos/products_repo.dart
  presentation/
    cubit/products_cubit.dart
    refactor/products_body.dart
    screens/products_screen.dart
    widgets/product_card.dart
```
