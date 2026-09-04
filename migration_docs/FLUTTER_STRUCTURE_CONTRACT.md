# Flutter structure contract for the 1:1 migration

## Allowed architectural change

Streamlit’s monolithic `app.py` may be separated by feature in Flutter. This is an implementation-only change: the output must retain the Streamlit page’s labels, order, controls, data behavior, and role boundaries.

## Existing structure

The current project already has `core/auth`, `core/network`, `core/theme`, `core/utils`, `features/auth`, `features/co`, and `features/shared`. The shared CO shell is `features/shared/presentation/co_app_scaffold.dart`; it is not a generic all-role navigation implementation.

## Required feature convention

For a Streamlit route, use the smallest necessary structure:

```text
features/<feature>/
  presentation/   # exact UI layout, widgets, routing state
  application/    # page/controller state only when required
  data/           # transport DTOs and API client adapter
```

Do not create a feature until its parity document is complete. Do not put financial calculations, ledger postings, projection rebuilds, or reversal execution in Flutter; call the backend contract that implements the existing Streamlit operation.

## Shared UI boundary

Only extract a shared widget after the same Streamlit visual and behavioral pattern has been evidenced in at least two routes. Shared widgets must take data/state from their feature; they must not contain invented defaults or business rules.

## Navigation boundary

Replace the current CO-only active-page dispatcher with a role-aware dispatcher only after every displayed destination has a complete feature and a parity document. The canonical menu remains `RBACScopeService.ROLE_NAVIGATION` as reproduced in `MIGRATION_AUTHORITY.md`.

## Definition of done

A structural split is successful only when it is invisible to users: the migrated page matches the Streamlit route in visuals, interactions, validation, data, and permissions.
