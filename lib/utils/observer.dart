import 'package:flutter/foundation.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';

class Observer implements Disposable {
  final Function() callback;
  late final Listenable notifier;
  Observer(this.callback, List<ChangeNotifier> notifiers) {
    if (notifiers.length > 1) {
      notifier = Listenable.merge(notifiers);
    } else {
      notifier = notifiers[0];
    }
    notifier.addListener(callback);
  }

  @override
  void disposedBy(DisposeScope disposeScope) {
    disposeScope.addDispose(dispose);
  }

  @override
  Future<void> dispose() {
    notifier.removeListener(callback);
    return Future.value();
  }
}
