import 'dart:async';

class ServiceWaiter {
  late final Completer<void> wait;
  ServiceWaiter() {
    wait = Completer();
  }
}

final service = Service();

void register<T>(T service) {
  return Service().register<T>(service);
}

T locate<T>() {
  return Service().locate<T>();
}

Future<T> locateAsync<T>() {
  return Service().locateAsync<T>();
}

void remove<T>() {
  return Service().remove<T>();
}

bool has<T>() {
  return Service().has<T>();
}

class Service {
  static final Service _instance = Service._internal();
  final _services = <Type, dynamic>{};

  void register<T>(T service) {
    if (_services[T] is ServiceWaiter) {
      (_services[T] as ServiceWaiter).wait.complete();
    }
    _services[T] = service;
  }

  T locate<T>() {
    // final service = _services[T];
    // if (service == null) {
    //   throw Exception('Service not found');
    // }
    // if (service is ServiceWaiter) {
    //   throw Exception('Service not found');
    // }
    return _services[T] as T;
  }

  Future<T> locateAsync<T>() async {
    if (_services[T] == null) {
      _services[T] = ServiceWaiter();
    }
    if (_services[T] is ServiceWaiter) {
      await _services[T].wait.future;
    }
    return _services[T] as T;
  }

  void remove<T>() {
    _services.remove(T);
  }

  bool has<T>() {
    return _services[T] != null && _services[T] is! ServiceWaiter;
  }

  factory Service() {
    return _instance;
  }

  Service._internal() {
    //init
  }
}
