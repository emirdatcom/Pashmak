/// Time source; tests use [FakeClock].
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  FakeClock(this._now);
  DateTime _now;
  @override
  DateTime now() => _now;
  void set(DateTime t) => _now = t;
  void advance(Duration d) => _now = _now.add(d);
}
