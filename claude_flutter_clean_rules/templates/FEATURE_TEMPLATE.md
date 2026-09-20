# Feature Template

Use this when adding a new feature.

```text
lib/features/<feature>/
  data/
    data_source/<feature>_remote_data_source.dart
    models/<feature>_model.dart
    repos/<feature>_repo.dart
  presentation/
    cubit/<feature>_cubit.dart
    refactor/<feature>_body.dart
    refactor/<feature>_view_data.dart
    screens/<feature>_screen.dart
    widgets/<feature>_card.dart
    widgets/<feature>_empty_view.dart
    widgets/<feature>_loading_view.dart
    widgets/<feature>_error_view.dart
```

## Screen Pattern

```dart
class FeatureScreen extends StatelessWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<FeatureCubit>()..load(),
      child: const FeatureBody(),
    );
  }
}
```
