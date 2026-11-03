import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../logic/phase5.dart';

/// Reads the fitness band's data from Android Health Connect (free; the
/// band's own app writes into it). Read-only: the app never writes health
/// data. Behind an interface so tests and phones without a band work.
enum BandStatus {
  /// Health Connect is not installed or needs an update (Android 13 and older).
  needsHealthConnect,

  /// Installed, but he hasn't allowed this app to read it yet.
  notConnected,
  connected,
}

class BandData {
  const BandData({
    this.sleep = const [],
    this.steps = const [],
    this.resting = const [],
  });
  final List<Span> sleep;
  final List<Span> steps;
  final List<({DateTime at, int bpm})> resting;
}

abstract class BandReader {
  Future<BandStatus> status();

  /// Opens Health Connect's own permission screen.
  Future<bool> connect();

  /// Opens the Play Store page for Health Connect.
  Future<void> installHealthConnect();

  Future<BandData> read(DateTime from, DateTime to);
}

class HealthConnectBand implements BandReader {
  final Health _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.STEPS,
    HealthDataType.RESTING_HEART_RATE,
  ];
  static const _access = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<BandStatus> status() async {
    if (kIsWeb) return BandStatus.needsHealthConnect;
    try {
      await _configure();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        return BandStatus.needsHealthConnect;
      }
      final ok = await _health.hasPermissions(_types, permissions: _access);
      return ok == true ? BandStatus.connected : BandStatus.notConnected;
    } catch (e) {
      debugPrint('Health Connect status failed: $e');
      return BandStatus.needsHealthConnect;
    }
  }

  @override
  Future<bool> connect() async {
    try {
      await _configure();
      return await _health.requestAuthorization(_types, permissions: _access);
    } catch (e) {
      debugPrint('Health Connect permission failed: $e');
      return false;
    }
  }

  @override
  Future<void> installHealthConnect() => _health.installHealthConnect();

  @override
  Future<BandData> read(DateTime from, DateTime to) async {
    await _configure();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: from,
      endTime: to,
    );
    int n(HealthDataPoint p) {
      final v = p.value;
      return v is NumericHealthValue ? v.numericValue.round() : 0;
    }

    return BandData(
      sleep: [
        for (final p in points.where(
          (p) => p.type == HealthDataType.SLEEP_SESSION,
        ))
          Span(p.dateFrom, p.dateTo),
      ],
      steps: [
        for (final p in points.where((p) => p.type == HealthDataType.STEPS))
          Span(p.dateFrom, p.dateTo, n(p)),
      ],
      resting: [
        for (final p in points.where(
          (p) => p.type == HealthDataType.RESTING_HEART_RATE,
        ))
          (at: p.dateFrom, bpm: n(p)),
      ],
    );
  }
}

/// For tests and for phones with no band.
class FakeBand implements BandReader {
  FakeBand({
    this.state = BandStatus.notConnected,
    this.data = const BandData(),
  });
  BandStatus state;
  BandData data;
  int connects = 0;

  @override
  Future<BandStatus> status() async => state;
  @override
  Future<bool> connect() async {
    connects++;
    state = BandStatus.connected;
    return true;
  }

  @override
  Future<void> installHealthConnect() async {}
  @override
  Future<BandData> read(DateTime from, DateTime to) async => data;
}
