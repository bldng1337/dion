class Result<T> {
  final T? value;
  final Object? error;
  final StackTrace? trace;
  const Result(this.value, this.error, {this.trace});
  const Result.error(this.error, {this.trace}) : value = null;
  const Result.value(this.value)
      : error = null,
        trace = null;
  factory Result.tryRun(T Function() f) {
    try {
      return Result.value(f());
    } catch (e, s) {
      return Result.error(e, trace: s);
    }
  }

  bool get isError => error != null;
  bool get isSuccess => !isError;

  T getOrElse(T Function() defaultValue) {
    if (isError) {
      return defaultValue();
    }
    return value!;
  }

  T getOrThrow() {
    if (isError) {
      throw error!;
    }
    return value!;
  }

  R build<R>(R Function(T value) valueMapper,
      R Function(Object error,StackTrace? trace) errorMapper,) {
    if (isError) {
      return errorMapper(error!,trace);
    }
    return valueMapper(value as T);
  }

  Result<T> map(T Function(T value) mapper) {
    if (isError) {
      return this;
    }
    return Result(mapper(value as T), error);
  }

  Result<T> mapError(Object Function(Object error,StackTrace? trace) mapper) {
    if (isError) {
      return Result(value, mapper(error!,trace));
    }
    return this;
  }

  @override
  String toString() {
    if (isError) {
      return 'Result.error($error,$trace)';
    }
    return 'Result.value($value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Result<T> && other.value == value && other.error == error;
  }

  @override
  int get hashCode => Object.hash(value, error);
}
