/// 충전 기록 모델 (`charge_logs` 테이블)
class ChargeLog {
  static const List<String> locationTypes = [
    '수퍼차저',
    '집밥(완속)',
    '공용급속',
    '기타',
  ];

  final int? id;
  final DateTime date;
  final String locationType; // '수퍼차저' | '집밥(완속)' | '공용급속' | '기타'
  final double addedEnergyKwh;
  final int unitPriceKrw;
  final int totalCostKrw;
  final int startSoc;
  final int endSoc;

  const ChargeLog({
    this.id,
    required this.date,
    required this.locationType,
    required this.addedEnergyKwh,
    required this.unitPriceKrw,
    required this.totalCostKrw,
    required this.startSoc,
    required this.endSoc,
  });

  int get socAdded => endSoc - startSoc;

  ChargeLog copyWith({
    int? id,
    DateTime? date,
    String? locationType,
    double? addedEnergyKwh,
    int? unitPriceKrw,
    int? totalCostKrw,
    int? startSoc,
    int? endSoc,
  }) {
    return ChargeLog(
      id: id ?? this.id,
      date: date ?? this.date,
      locationType: locationType ?? this.locationType,
      addedEnergyKwh: addedEnergyKwh ?? this.addedEnergyKwh,
      unitPriceKrw: unitPriceKrw ?? this.unitPriceKrw,
      totalCostKrw: totalCostKrw ?? this.totalCostKrw,
      startSoc: startSoc ?? this.startSoc,
      endSoc: endSoc ?? this.endSoc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'location_type': locationType,
      'added_energy_kwh': addedEnergyKwh,
      'unit_price_krw': unitPriceKrw,
      'total_cost_krw': totalCostKrw,
      'start_soc': startSoc,
      'end_soc': endSoc,
    };
  }

  factory ChargeLog.fromMap(Map<String, dynamic> map) {
    return ChargeLog(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      locationType: (map['location_type'] as String?) ?? '기타',
      addedEnergyKwh: (map['added_energy_kwh'] as num).toDouble(),
      unitPriceKrw: (map['unit_price_krw'] as num).toInt(),
      totalCostKrw: (map['total_cost_krw'] as num).toInt(),
      startSoc: (map['start_soc'] as num).toInt(),
      endSoc: (map['end_soc'] as num).toInt(),
    );
  }
}
