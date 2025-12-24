### Entry Point

The app bootstraps in [`lib/main.dart`](lib/main.dart). The Services get initialized in [`lib/views/loading.dart`](lib/views/loading.dart).

## Code Organization

The app is organized into folders under `lib/`, each named after a major component(e.g. for Data the path is `lib/data`). Except for routes which are defined in [`lib/routes.dart`](lib/routes.dart).

### Data

Data contains data models (e.g., entries, sources) plus serialization and migration logic. For dataclasses that are saved to the database we use `DBConstClass` and `DBModifiableClass` of [metis](https://github.com/bldng1337/metis).

### Services

Services are singletons that live for the lifetime of the app (e.g. Database, ExtensionManager). They are initialized in [`lib/views/loading.dart`](lib/views/loading.dart).
They get accessed via `locate<SERVICE>()` or `locateAsync<SERVICE>()`. `locateAsync<SERVICE>()` should only be used in the initialization of services so dependent services wait for one another. The DI implementation is in [`lib/utils/service.dart`](lib/utils/service.dart).

### Lifetime Management

The app uses a `DisposeScope` pattern to manage the lifecycle of objects that need to be disposed, such as controllers or streams, especially within widgets. This ensures that resources are properly cleaned up when a widget is removed from the widget tree, preventing memory leaks.

In Widgets use `StateDisposeScopeMixin` to create a DisposeScope named scope tied to the widgets life cycle. This mixin automatically disposes of the scope when the widget is disposed.

To bind a disposable object to the scope, use `disposable.disposedBy(scope)`. This registers the disposable with the scope, ensuring that its `dispose()` method will be called when the scope is disposed.

### State Management

For state management we use Flutter's built-in mechanisms as we don't have really dynamic data. For instances where we have more complex state or need to share mutable state between multiple widgets, we use `ValueNotifier` and `ChangeNotifier`. Additionally, for cases where we want to support listening to only to specific events we use `KeyedChangeNotifier` mixin from [`lib/utils/change.dart`](lib/utils/change.dart). This allows widgets to listen only to the parts of state they care about.
For cases where you need to observe changes to a `Listenable` (such as a `ValueNotifier` or `ChangeNotifier`) and automatically manage the listener's lifecycle, use the `Observer` class from [`lib/utils/observer.dart`](lib/utils/observer.dart). `Observer` allows you to register a callback that is invoked whenever the `Listenable` changes, and can be easily disposed of using the `DisposeScope` pattern. To swap/update the Listeners of an existing Observer use `swapListener(newListener)`. This automatically updates the Listener if they are different to the current one. (Note: Observer calls your callback on init by default to disable this behavior set `callOnInit` to false in the constructor) There is also a `KeyObserver` for listening to hardware keyboard events in a disposable way. 

### Utils

Contains helpers and utilities.

### Views

Views contain screens/pages. They should generally only use `lib/widgets/*` or foundational widgets but it is not 100% enforced right now see **Widgets** below.

### Widgets

Contains utility widgets and wrapper widgets for material/cupertino widgets. Should generally be able to switch between themes but this is not completely implemented right now because I want to wait for https://github.com/flutter/flutter/issues/101479 to finish.

## Tests

Tests live in `integration_test`. Currently only integration tests are used/work for unit tests would need https://github.com/orgs/dart-lang/projects/99/views/1 (Well for the rust parts but I would like that it works for everything before using it).
