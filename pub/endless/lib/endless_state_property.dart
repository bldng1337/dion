// ignore_for_file: prefer_void_to_null

import 'package:state_property/state_property.dart';
import 'package:flutter/material.dart' hide WidgetStateProperty;

enum EndlessState {
  /// Whether the endless scroll view currently has no items.
  empty,

  /// Whether the endless scroll view is currently loading items.
  loading,

  /// Whether the endless scroll view has finished loading all items. Determined when loading
  /// items returns fewer items than the expected size.
  done,

  /// Whether the endless scroll view will clear its current items on next load set when
  /// [EndlessStreamController.clear] is called with the [lazy] specification.
  willClear
}

class EndlessStateProperty extends WidgetStateProperty<EndlessState> {
  EndlessStateProperty(resolve) : super(resolve);

  /// The most flexible state property that allows for dynamically resolving the builder
  /// function based on the state of the scroll view.
  static EndlessStateProperty resolveWith(
          StatefulWidgetResolver<EndlessState> builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.resolveWith<EndlessState, Widget?>(
                (states) => builder(context, states)),
      );

  /// Resolves the given builder in all cases regardless of the state of the scroll view.
  static EndlessStateProperty all(StatelessWidgetResolver builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.all<EndlessState, Widget?>(() => builder(context)),
      );

  /// Resolves the given builder if the scroll view is currently in the loading state.
  static EndlessStateProperty loading(StatelessWidgetResolver builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.resolveState<EndlessState, Widget?>(
          () => builder(context),
          EndlessState.loading,
        ),
      );

  /// Resolves the given builder if the scroll view is currently in the empty state.
  static EndlessStateProperty empty(StatelessWidgetResolver builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.resolveState<EndlessState, Widget?>(
          () => builder(context),
          EndlessState.empty,
        ),
      );

  /// Resolves the given builder if the scroll view will clear its current items on next load.
  static EndlessStateProperty willClear(StatelessWidgetResolver builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.resolveState<EndlessState, Widget?>(
          () => builder(context),
          EndlessState.willClear,
        ),
      );

  /// Resolves the given builder if the scroll view is currently in the done state.
  static EndlessStateProperty done(StatelessWidgetResolver builder) =>
      EndlessStateProperty(
        (BuildContext context) =>
            StateProperty.resolveState<EndlessState, Widget?>(
          () => builder(context),
          EndlessState.done,
        ),
      );

  /// Resolves `null` as the value regardless of the state of the scroll view.
  static EndlessStateProperty never() =>
      EndlessStateProperty((_context) => StateProperty.never<EndlessState>());
}

/// If a builder exists, then use the default state property for that builder.
/// Otherwise if no builder was provided, provide a never state property since
/// the client has no builder for that state.
EndlessStateProperty _resolveBuilderToStateProperty(
  StatelessWidgetResolver? builder,
  EndlessStateProperty Function(StatelessWidgetResolver builder) resolver,
) {
  if (builder != null) {
    return resolver(builder);
  }

  return EndlessStateProperty.never();
}

EndlessStateProperty resolveHeaderBuilderToStateProperty(
  StatelessWidgetResolver? builder,
) {
  return _resolveBuilderToStateProperty(
    builder,
    EndlessStateProperty.all,
  );
}

EndlessStateProperty resolveEmptyBuilderToStateProperty(
  StatelessWidgetResolver? builder,
) {
  return _resolveBuilderToStateProperty(
    builder,
    (StatelessWidgetResolver builder) =>
        EndlessStateProperty.resolveWith((context, states) {
      if (states.contains(EndlessState.empty) &&
          !states.contains(EndlessState.loading)) {
        return builder(context);
      }
      return null;
    }),
  );
}

EndlessStateProperty resolveLoadingBuilderToStateProperty(
  StatelessWidgetResolver? builder,
) {
  return _resolveBuilderToStateProperty(
    builder,
    EndlessStateProperty.loading,
  );
}

EndlessStateProperty resolveLoadMoreBuilderToStateProperty(
  StatelessWidgetResolver? builder,
) {
  return _resolveBuilderToStateProperty(
    builder,
    (StatelessWidgetResolver builder) =>
        EndlessStateProperty.resolveWith((context, states) {
      if (states.intersection({
        EndlessState.done,
        EndlessState.loading,
        EndlessState.empty,
      }).isEmpty) {
        return builder(context);
      }
      return null;
    }),
  );
}

EndlessStateProperty resolveFooterBuilderToStateProperty(
    StatelessWidgetResolver? builder) {
  return _resolveBuilderToStateProperty(
    builder,
    EndlessStateProperty.all,
  );
}
