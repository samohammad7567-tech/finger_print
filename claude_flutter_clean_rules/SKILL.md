---
name: flutter-clean-refactor
summary: Clean Flutter refactor and feature implementation rules based on Mohammad's PharmaChain and Fruite Hub apps, using the reusable Core Kit conventions.
---

# Flutter Clean Refactor Skill

Use this skill when working on Mohammad's Flutter apps or new Flutter projects that should follow the same style as PharmaChain and Fruite Hub.

## Main Instruction

Refactor and implement Flutter code with dumb UI, Cubit-owned behavior, data-source-owned data logic, thin repos, small files, reusable Core Kit widgets/services, consistent theme, localization, and responsive layout.

## Architecture

Use only:

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

Do not create domain/entity/use_case/repo_interface/repo_impl layers.

## Use the Core Kit First

Before adding custom code, look for reusable Core Kit parts:

- theme
- language
- AppCacheService
- AppPreferencesCubit
- ShowToast/AppToast
- AppButton/AppPrimaryButton
- AppTextField/AppPasswordField/AppSearchField
- AppNetworkImage/ProductImage
- AppEmptyState/AppErrorState/AppLoadingOverlay
- AppBottomSheetHeader
- AppPagePadding/AppScaffold
- AppValidators
- AuthErrorMapper
- FirebaseAuthService/FirestoreService/SupabaseStorageService patterns

## File Size Rule

Keep UI files small:

- screens: 30-70 lines
- refactor/widgets: 80-120 lines
- hard maximum for UI/common widget files: 150 lines

Split large UI methods into dedicated widgets or refactor files.

## UI Rule

UI only displays state and forwards actions.

UI must not contain:

- Firebase/Auth/Firestore/Supabase/SharedPreferences calls
- business calculations
- filtering logic
- status transition logic
- backend error mapping
- duplicated validation
- complex model creation

## Cubit Rule

Cubit owns:

- load/refresh
- filter/search state
- selected values
- action methods
- stable error keys
- UI-ready display data

## Data Rule

Data sources own:

- backend/local persistence calls
- validation that protects data
- normalization
- transactions
- duplicate checks
- status transitions

Repos delegate to data sources.

## Required Checks

Before finishing:

- no package project imports inside lib
- no backend calls in presentation/common UI widgets
- no missing localization keys
- no UI file over 150 lines unless justified
- JSON files valid
- build_runner requirement stated
- flutter analyze result stated if available
