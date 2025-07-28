import 'dart:math';

abstract class Ratelimit {
  bool tryAcquire();
  Duration get blocktime;
  Future<void> acquire();
}

class LeakyBucketRatelimit implements Ratelimit {
  final int _bucketsize;
  final Duration _refilltime;
  late int _bucket;
  DateTime _lastrefill = DateTime.now();
  LeakyBucketRatelimit(this._bucketsize, this._refilltime)
    : _bucket = _bucketsize;

  factory LeakyBucketRatelimit.fromRate(int persecond, {int bucketsize = 10}) =>
      LeakyBucketRatelimit(
        bucketsize,
        Duration(seconds: (bucketsize / persecond).round()),
      );

  @override
  bool tryAcquire() {
    final fillrate = _bucketsize / _refilltime.inMilliseconds;
    final refill = max(
      0,
      DateTime.now().difference(_lastrefill).inMilliseconds * fillrate,
    );
    if (refill.floor() > 0) {
      _bucket = min(refill.floor() + _bucket, _bucketsize);
      _lastrefill = DateTime.now().add(
        Duration(
          milliseconds: ((refill - refill.floorToDouble()) / fillrate).floor(),
        ),
      );
    }
    if (_bucket > 0) {
      _bucket--;
      return true;
    }
    return false;
  }

  @override
  Duration get blocktime {
    return Duration(
      milliseconds:
          (_refilltime.inMilliseconds / _bucketsize).ceil() +
          100, // +100 is a buffer
    );
  }

  @override
  Future<void> acquire() async {
    while (!tryAcquire()) {
      await Future.delayed(blocktime);
    }
  }
}
