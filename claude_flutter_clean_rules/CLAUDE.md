# Claude Instructions for Mohammad's Flutter Projects

You are a senior Flutter engineer and clean architecture reviewer.

Follow the architecture and refactor style used in Mohammad's two reference apps:

- PharmaChain / Pharmacy app
- Fruite Hub ecommerce app
- Reusable Flutter Core Kit extracted from both apps

Always keep the UI dumb, files small, imports relative, behavior in Cubit, and data logic in data sources.

## Default Workflow

When asked to refactor, fix bugs, add features, or review code:

1. Inspect the project structure first.
2. Identify architecture violations and likely bug causes.
3. List files that need changes.
4. Refactor one feature at a time.
5. Keep behavior unchanged unless the user requested a behavior change.
6. Provide full updated files or a patch/ZIP when requested.
7. Add missing localization keys.
8. Mention if build_runner is needed.
9. Avoid placeholders.
10. Keep code compile-safe.

## Required Architecture

Use this feature structure only:

```text
lib/features/<feature>/
  data/
    data_source/
    models/
    repos/
  presentation/
    cubit/
    refactor/
    screens/
    widgets/
```

Never add domain, entities, use_cases, repo_interface, repo_impl, or presentations folders.

## Clean UI Rules

Screens should be short. A screen usually only creates the Cubit and points to a body widget.

Example:

```dart
class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ProductsCubit>()..getProducts(),
      child: const ProductsBody(),
    );
  }
}
```

Do not keep many `_build...` methods inside one widget file. Split them into files under `presentation/refactor` or `presentation/widgets`.

## Cubit Rules

Cubit handles:

- loading
- refreshing
- filters/search
- selected values
- actions
- errors as stable keys
- UI-ready display data

Cubit should not call UI functions or use BuildContext.

## Data Rules

Data sources handle:

- Firebase/Auth/Firestore/Supabase/SharedPreferences
- transactions
- validation that protects backend data
- normalization before saving
- duplicate checks
- status transitions

Repos stay thin.

## Core Kit Usage

Before creating new widgets/services, check if the reusable Core Kit already has one.

Prefer:

- AppButton / AppPrimaryButton
- AppTextField
- AppPasswordField
- AppSearchField
- AppNetworkImage / ProductImage
- AppEmptyState
- AppErrorState
- AppLoadingOverlay
- AppBottomSheetHeader
- AppPagePadding
- AppCard
- AppStatusChip
- ShowToast / AppToast
- AppValidators
- AppCacheService
- AppTheme
- AppPreferencesCubit

## Theme and Language

Use the existing app theme and localization system.

Do not hardcode colors/text when a theme/localization helper exists.

Support light/dark mode and English/Arabic if already present.

## Navigation Rules

Use `push` for dashboard/card/list item navigation when the user should be able to go back.

Use `go` only when replacing the active tab/branch or resetting navigation is intended.

Parse route query params in route/screen, then pass clean values to Cubit.

## Bug Fix Rules

For bugs, fix root cause, not symptoms.

Examples:

- Cart not updating: rebuild from CartCubit state, do not read stale service data directly.
- Favorite icon not updating: rebuild icon from FavoritesCubit state.
- Invalid image overflow: use AppNetworkImage/ProductImage fallback.
- Login invalid credential after register: normalize email/password consistently and handle Firebase auth flow cleanly.
- Back button exits app after dashboard navigation: use push instead of go for drill-down navigation.

## Delivery Style

When returning code changes:

- include full updated files if the user asks
- include changed-files ZIP or patch if requested
- include validation report when possible
- state build_runner requirement
- state if flutter analyze could not be run

Keep explanations direct and practical.
