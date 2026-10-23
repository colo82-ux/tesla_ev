/// 차량 현재 상태 스냅샷 및 주차 중 대기 전력 손실(Vampire Drain) 모델
class VehicleSnapshot {
  final DateTime timestamp;
  final int soc; // 배터리 잔량 (%)
  final double estimatedRangeKm; // 주행 가능 거리 (km)
  final double odometerKm; // 누적 주행거리 (km)
  final double outsideTemp; // 외기온도 (°C)
  final String vehicleState; // 'online' | 'asleep' | 'driving' | 'charging'

  const VehicleSnapshot({
    required this.timestamp,
    required this.soc,
    required this.estimatedRangeKm,
    required this.odometerKm,
    required this.outsideTemp,
    required this.vehicleState,
  });

  VehicleSnapshot copyWith({
    DateTime? timestamp,
    int? soc,
    double? estimatedRangeKm,
    double? odometerKm,
    double? outsideTemp,
    String? vehicleState,
  }) {
    return VehicleSnapshot(
      timestamp: timestamp ?? this.timestamp,
      soc: soc ?? this.soc,
      estimatedRangeKm: estimatedRangeKm ?? this.estimatedRangeKm,
      odometerKm: odometerKm ?? this.odometerKm,
      outsideTemp: outsideTemp ?? this.outsideTemp,
      vehicleState: vehicleState ?? this.vehicleState,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'soc': soc,
      'estimated_range_km': estimatedRangeKm,
      'odometer_km': odometerKm,
      'outside_temp': outsideTemp,
      'vehicle_state': vehicleState,
    };
  }

  factory VehicleSnapshot.fromMap(Map<String, dynamic> map) {
    return VehicleSnapshot(
      timestamp: DateTime.parse(map['timestamp'] as String),
      soc: (map['soc'] as num).toInt(),
      estimatedRangeKm: (map['estimated_range_km'] as num).toDouble(),
      odometerKm: (map['odometer_km'] as num).toDouble(),
      outsideTemp: (map['outside_temp'] as num).toDouble(),
      vehicleState: (map['vehicle_state'] as String?) ?? 'online',
    );
  }
}

/// 주차 중 대기 전력 소모(Vampire Drain) 기록 모델 (`vampire_drain_logs` 테이블)
class VampireDrainLog {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final int startSoc;
  final int endSoc;
  final double lostEnergyKwh;
  final double lostRangeKm;
  final bool sentryModeActive;

  const VampireDrainLog({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.startSoc,
    required this.endSoc,
    required this.lostEnergyKwh,
    required this.lostRangeKm,
    required this.sentryModeActive,
  });

  double get parkedHours =>
      endTime.difference(startTime).inMinutes / 60.0;

  /// 시간당 손실 전력 (kWh / h)
  double get drainKwhPerHour =>
      parkedHours > 0 ? lostEnergyKwh / parkedHours : 0.0;

  /// 일일(24h) 환산 손실 SoC (%)
  double get drainSocPerDay =>
      parkedHours > 0 ? ((startSoc - endSoc) / parkedHours) * 24.0 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'start_soc': startSoc,
      'end_soc': endSoc,
      'lost_energy_kwh': lostEnergyKwh,
      'lost_range_km': lostRangeKm,
      'sentry_mode_active': sentryModeActive ? 1 : 0,
    };
  }

  factory VampireDrainLog.fromMap(Map<String, dynamic> map) {
    return VampireDrainLog(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      startSoc: (map['start_soc'] as num).toInt(),
      endSoc: (map['end_soc'] as num).toInt(),
      lostEnergyKwh: (map['lost_energy_kwh'] as num).toDouble(),
      lostRangeKm: (map['lost_range_km'] as num).toDouble(),
      sentryModeActive: (map['sentry_mode_active'] as num).toInt() == 1,
    );
  }
}
