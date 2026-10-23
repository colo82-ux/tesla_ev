/// 주행 기록 모델 (`drive_logs` 테이블)
class DriveLog {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double usedEnergyKwh;
  final double efficiencyKmKwh;
  final double outsideTempAvg;
  final int startSoc;
  final int endSoc;
  final String source; // 'teslamate' | 'direct_api' | 'manual'

  const DriveLog({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.usedEnergyKwh,
    required this.efficiencyKmKwh,
    required this.outsideTempAvg,
    required this.startSoc,
    required this.endSoc,
    required this.source,
  });

  Duration get duration => endTime.difference(startTime);

  int get socDelta => startSoc - endSoc;

  DriveLog copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceKm,
    double? usedEnergyKwh,
    double? efficiencyKmKwh,
    double? outsideTempAvg,
    int? startSoc,
    int? endSoc,
    String? source,
  }) {
    return DriveLog(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      usedEnergyKwh: usedEnergyKwh ?? this.usedEnergyKwh,
      efficiencyKmKwh: efficiencyKmKwh ?? this.efficiencyKmKwh,
      outsideTempAvg: outsideTempAvg ?? this.outsideTempAvg,
      startSoc: startSoc ?? this.startSoc,
      endSoc: endSoc ?? this.endSoc,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'distance_km': distanceKm,
      'used_energy_kwh': usedEnergyKwh,
      'efficiency_km_kwh': efficiencyKmKwh,
      'outside_temp_avg': outsideTempAvg,
      'start_soc': startSoc,
      'end_soc': endSoc,
      'source': source,
    };
  }

  factory DriveLog.fromMap(Map<String, dynamic> map) {
    return DriveLog(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      distanceKm: (map['distance_km'] as num).toDouble(),
      usedEnergyKwh: (map['used_energy_kwh'] as num).toDouble(),
      efficiencyKmKwh: (map['efficiency_km_kwh'] as num).toDouble(),
      outsideTempAvg: (map['outside_temp_avg'] as num).toDouble(),
      startSoc: (map['start_soc'] as num).toInt(),
      endSoc: (map['end_soc'] as num).toInt(),
      source: (map['source'] as String?) ?? 'manual',
    );
  }
}
