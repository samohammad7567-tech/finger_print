# Refactor Checklist

Use this checklist before delivering any Flutter changes.

## Architecture

- [ ] Feature uses data + presentation only
- [ ] No domain/entity/use_case layer added
- [ ] Repos are thin
- [ ] Data sources contain backend/local persistence logic
- [ ] Cubit owns screen behavior
- [ ] UI is dumb

## UI

- [ ] Screen files are short
- [ ] No long private builder-method chains inside UI
- [ ] Large sections split into refactor/widgets files
- [ ] Empty/loading/error states are reusable widgets
- [ ] Text has maxLines/overflow where needed
- [ ] Layout is responsive

## State

- [ ] Lists rebuild from Cubit state
- [ ] Favorite/cart/profile changes update visible UI immediately
- [ ] Refresh failure does not destroy old data where possible

## Localization and Theme

- [ ] No hardcoded user-facing strings
- [ ] Missing translation keys added
- [ ] Dark mode safe colors
- [ ] Uses shared buttons/fields/cards/toasts where possible

## Validation

- [ ] JSON translation files valid
- [ ] No invalid relative imports
- [ ] No package project imports inside lib
- [ ] No backend calls in presentation/common UI widgets
- [ ] No UI/common widget file over 150 lines unless justified
- [ ] build_runner need stated
