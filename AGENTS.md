# AGENTS.md

dion (Dart package name `dionysos`, so imports are `package:dionysos/...`) is an extensible media reader — video player and comic/novel reader — built with Flutter for Windows and Android. Some runtime behavior is not in this repo: it is consumed as the `rdion_runtime` package from a separate Rust repository.

## Where things live

Everything is under `lib/`, organized by role:

- `lib/data/` — data models plus their serialization and migration. Persisted dataclasses use metis (`DBConstClass` / `DBModifiableClass`).
- `lib/service/` — services that live for the entire runtime of the app (database, network, extensions, downloads, ...). One service per concern.
- `lib/views/` — screens/pages, grouped by feature. Views compose `lib/widgets` (and foundation widgets) rather than raw Material/Cupertino.
- `lib/widgets/` — reusable, theme-aware widgets that wrap Material/Cupertino so the app can render in either theme mode (material and cupertino variants; not every widget covers both yet).
- `lib/utils/` — cross-cutting helpers: the service locator, logging, disposable listeners/observers, design tokens, theming, small utilities.
- Routes are defined centrally in `lib/routes.dart`; the app entry point is `lib/main.dart`, and services start up during the loading screen.

Platform folders (`android/`, `windows/`, ...) hold only embedding/plugin configuration; feature logic goes in `lib/`. Rough layering: `views`/`widgets` use `service`s, services use `data`; never the reverse.

## Services and lifetime

- Services are singletons registered in the small service locator in `lib/utils/service.dart` (`register` / `locate`). They live for the whole app runtime and are never disposed — do not add teardown logic to them.
- Services initialize sequentially during startup, before the main UI takes over. A new service follows the existing pattern: a static `ensureInitialized()` that constructs the instance and registers it.
- A service that depends on another service during startup waits with `locateAsync<T>()`; `locateAsync` belongs in service initialization only. Everywhere else use `locate<T>()`.

## State, subscriptions and disposal

- No external state-management package. Local widget state uses `setState`; shared or complex state uses `ValueNotifier` / `ChangeNotifier`.
- Anything disposable created inside a widget (controllers, timers, subscriptions, listeners) is bound to the widget's `DisposeScope` with `disposedBy(scope)`. The scope comes from `StateDisposeScopeMixin` on the widget's `State` and is disposed automatically with the widget. Prefer this over manual `dispose()` calls in widget lifecycle methods.
- Register listeners through the disposable helpers in `lib/utils` instead of raw `addListener` / `removeListener`: `Observer` wraps a `Listenable` callback as a disposable — it calls back on init and post-frame by default (`callOnInit`, `callIndirectly`) and `swapListener` re-binds it to a new `Listenable` later. `KeyedChangeNotifier` lets listeners subscribe to specific events instead of every change, and `KeyObserver` does the same disposable pattern for hardware keyboard events.
- After an `await` inside a `State`, call `safeSetState` (extension in `lib/utils/safe_set_state.dart`) instead of `setState` — it no-ops when the widget unmounted across the async boundary.

## Style

- The analyzer runs `package:lint/strict.yaml`; keep code warning-free. Targeted `// ignore:` with a reason is fine, weakening rules project-wide is not.
- Use the design tokens from `lib/utils/design_tokens.dart` instead of hard-coded values: `DionSpacing`, `DionRadius`, `DionDuration`, `DionColors`, `DionTypography`, plus a `BuildContext` extension exposing dark/light-aware colors.
- Comments are for the unintuitive: constraints, workarounds, or reasons the obvious approach was not used — things that cannot be gathered from names or the surrounding code. Use them sparingly. No narration of what the next line does, no restating names.
- Log through the shared `logger` from `lib/utils/log.dart`, not `print` / `debugPrint`.

## Testing

Tests live in `integration_test/` and run against a device or emulator (`flutter test integration_test -d <device>`); purely device-independent tests go in `test/`. Unit tests are not broadly used yet — the tooling doesn't cover the Rust parts (pending upstream dart-lang work), so integration tests are the default.
