The app is organized into folders under `lib/`, each named after a major component(e.g. for Data the path is `lib/data`). Except for routes which are defined in `lib/routes.dart`.

### Entry Point

The app bootstraps in `lib/main.dart`. The Services get initialized in `lib/views/loading.dart`.

### Data

Data contains data models (e.g., entries, sources) plus serialization and migration logic. For dataclasses that are saved to the database we use `DBConstClass` and `DBModifiableClass` of [metis](https://github.com/bldng1337/metis).


### Services

Services are singletons that live for the lifetime of the app (e.g. Database, Extensions or Tasks). They are initialized in `lib/views/loading.dart`.
They get accessed via `locate<SERVICE>()` or `locateAsync<SERVICE>()`. `locateAsync<SERVICE>()` should only be used in the initialization of services so dependent services wait for one another. The DI implementation is in `lib/utils/service.dart`.

### State Management

For state management we use flutters built in mechanisms as we dont have really dynamic data. For Instances where we have more complex state or have to share mutable state between multiple widgets we use `ValueNotifier` and `ChangeNotifier`.

### Utils

Contains helpers and utilities.

### Views

Views contain screens/pages. They should generally only use `lib/widgets/*` or foundational widgets but it is not 100% enforced right now see **Widgets** below.

### Widgets

Contains utility widgets and wrapper widgets for material/cupertino widgets. Should generally be able to switch between themes but this is not completely implemented right now because I want to wait for https://github.com/flutter/flutter/issues/101479 to finish.

## Tests

Tests live in `integration_test`. Currently only integration tests are used/work for unit tests would need https://github.com/orgs/dart-lang/projects/99/views/1 (Well for the rust parts but I would like that it works for everything before using it).
