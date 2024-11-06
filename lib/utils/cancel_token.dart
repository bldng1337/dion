import 'package:dionysos/service/source_extension.dart';
import 'package:flutter_dispose_scope/flutter_dispose_scope.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

extension ChangeNotifierDisposed on CancelToken {
  void disposedBy(DisposeScope scope) {
    scope.addDispose(() async {
      await cancel();
      dispose();
    });
  }
}

extension rChangeNotifierDisposed on rhttp.CancelToken {
  void disposedBy(DisposeScope scope) {
    scope.addDispose(() async {
      await cancel();
    });
  }
}
