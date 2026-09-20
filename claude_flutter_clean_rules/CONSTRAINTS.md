# Flutter Clean Architecture Constraints

Use these constraints for every Flutter project refactor or feature implementation based on the user's two reference projects:

- PharmaChain / Pharmacy management app
- Fruite Hub / Ecommerce fruit app
- Reusable Flutter Core Kit extracted from both apps

## Main Goal

Make the UI layer dumb. UI must only display state and forward user actions to Cubit/Bloc.

Do not put business logic, Firebase logic, filtering logic, validation logic, calculations, status transitions, data normalization, data parsing, or repeated helper methods inside widgets.

## Required Feature Structure

Use this structure only:

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

Do not create:

```text
domain/
entities/
use_cases/
abstract domain repositories
repo_interface
repo_impl
presentations/
core/cubits for feature cubits
```

## Layer Ownership

### UI Layer

UI can:

- build widgets
- display state
- call Cubit methods
- show dialogs/bottom sheets
- use LayoutBuilder for responsive layout
- show toast messages from state results
- own simple TextEditingControllers in forms

UI must not:

- call Firebase, Firestore, Auth, Supabase, SharedPreferences, or APIs directly
- calculate totals or stock changes
- filter lists directly
- map backend errors
- decide business status transitions
- build backend models with complex logic
- parse dates/times except simple display formatting when unavoidable
- contain long switch statements for business behavior
- contain repeated validation logic
- contain many private builder methods such as _buildHeader, _buildCard, _buildForm inside one large screen file

### Cubit / Bloc Layer

Cubit owns screen behavior:

- initial loading
- refresh
- selected filters and search state
- submit/loading flags
- optimistic updates when useful
- error key normalization from exceptions
- preparing UI-ready data
- exposing state that UI renders directly
- keeping old data if refresh fails

### Data Layer

Remote/local data sources own data behavior:

- Firebase/Auth/Firestore/Supabase/SharedPreferences calls
- transactions
- deterministic document IDs
- timestamps
- duplicate checks
- backend validation
- status transition validation
- stock movements / inventory updates
- normalization before saving
- local persistence for favorites/theme/language/cart if needed

### Repos

Repos are thin. They expose clean methods to Cubit and delegate to data sources. Do not put UI logic in repos.

### Models

Models represent backend/local data and may use json_serializable/freezed if the project already does.

Models should:

- include fromJson/fromFirestore and toJson/toFirestoreJson when needed
- remove id/created_at/updated_at before writes when needed
- handle Timestamp safely
- include copyWith only when useful

## Refactor Folder Purpose

Use `presentation/refactor` for:

- large body sections
- view data classes
- display mappers
- UI-ready card data
- form controllers/helpers
- constants
- status label/action helpers if presentation-only
- page content split files

## Widgets Folder Purpose

Use `presentation/widgets` for:

- small dumb components
- cards
- tables
- bottom sheets
- rows
- chips
- form fields
- empty/loading/error views

## File Size Rules

Target limits:

```text
screens file: 30-70 lines
body/refactor file: 80-120 lines
widget file: 80-120 lines
max allowed for UI/common widget files: 150 lines only if necessary
Cubit files may exceed 150 if the state behavior requires it
```

If a UI file grows too large, split it into smaller widgets or refactor files.

## Imports

Prefer relative imports inside `lib`.

Do not use project package imports inside lib:

```dart
import 'package:project_name/features/...';
```

Use relative imports instead.

## Localization

All user-facing text must use the project's localization system.

For EasyLocalization projects:

```dart
'key'.tr()
```

For custom LangKeys projects:

```dart
context.translate(LangKeys.someKey)
```

Do not keep hardcoded UI strings such as:

```text
Save
Error
No data found
Dashboard
Cart is empty
```

Add missing keys to the proper translation files.

## Theme and Reusable Core Kit

Use the reusable core kit extracted from PharmaChain and Fruite Hub when possible.

Prefer shared/custom widgets such as:

- AppButton / AppPrimaryButton
- AppTextField
- AppPasswordField
- AppSearchField
- AppDropdownField
- AppSwitchField
- AppDateField
- AppTimeField
- AppNetworkImage / ProductImage
- AppCard
- AppStatusChip
- AppQuantityStepper
- AppBottomSheetHeader
- AppPageHeader
- AppEmptyState
- AppErrorState
- AppLoadingOverlay
- AppScaffold
- AppPagePadding
- ShowToast / AppToast

Keep light/dark theme consistency using context theme/color extensions where available.

## Responsive Rules

Avoid overflow. Use:

- SingleChildScrollView
- RefreshIndicator
- LayoutBuilder
- Wrap
- Flexible / Expanded only in constrained Row/Column
- shrinkWrap for nested lists/grids
- NeverScrollableScrollPhysics for inner lists
- FittedBox only for compact values/chips that may overflow
- maxLines + overflow on text widgets
- SafeArea where needed

Do not use Expanded inside unconstrained scrollable areas incorrectly.

## Forms

Forms should use reusable fields.

UI validation should only cover immediate field validation:

- required name
- valid email
- valid phone
- simple date/time format

Complex model creation, trimming, empty-to-null conversion, and validation helpers should move into helper/controller classes when the form becomes large.

Backend/data validation belongs in the data source.

## Navigation

Use the routing system already used by the project.

- Prefer `push` when opening a screen from a card so back returns to the previous screen.
- Use `go` only when replacing the active navigation branch is intended.
- Route query params should be parsed by the route/screen and passed to Cubit.
- UI cards should receive prepared route strings or callbacks, not build business route logic from labels.

## Toast and Error Handling

Use the shared toast helper instead of scattered SnackBars where the app already uses it.

Exceptions from data layer should be normalized into stable error keys.

UI should translate error keys and display them.

Avoid duplicated error mapping functions in widgets.

## Favorite / Cart Patterns

Favorites:

- Use a dedicated FavoritesCubit or feature cubit.
- Favorite icon must rebuild from state.
- Persist favorites locally or remotely via data source/repo.
- Add a Favorites screen/tab using the same theme.

Cart:

- Cart screen must rebuild from CartCubit/CartEntityCubit state, not stale GetIt/static data.
- Add empty cart screen.
- Invalid images must use AppNetworkImage/ProductImage fallback.

## Profile Image Pattern

Profile image update should:

- use an image picker/storage service if available
- upload through data source/service
- wait for backend profile update
- update cached/local user data
- emit Cubit success/error states
- show toast from UI listener

## Build Runner

Mention whether build_runner is needed.

Run build_runner only if Freezed/json_serializable generated model/state files changed.

## Validation Checklist Before Delivering

Check:

- no project package imports inside lib
- no Firebase/Auth/Firestore/Supabase calls in presentation/common UI widgets
- no UI/common widget file over 150 lines unless justified
- localization JSON is valid
- no missing localization keys
- no missing part files
- patch applies cleanly if providing patch
- build_runner needed or not needed
- flutter analyze if available; if unavailable, say so honestly
