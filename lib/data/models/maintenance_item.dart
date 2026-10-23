/// 소모품 관리 모델 (`maintenance_items` 테이블)
class MaintenanceItem {
  final int? id;
  final String itemName;
  final double lastReplacedOdoKm;
  final DateTime lastReplacedDate;
  final double replaceCycleKm;
  final int replaceCycleMonths;

  const MaintenanceItem({
    this.id,
    required this.itemName,
    required this.lastReplacedOdoKm,
    required this.lastReplacedDate,
    required this.replaceCycleKm,
    required this.replaceCycleMonths,
  });

  /// 누적 주행거리 기준 진행률 (0.0 ~ 1.0+)
  double getOdoProgress(double currentOdoKm) {
    if (replaceCycleKm <= 0) return 0.0;
    final drivenSinceReplace = (currentOdoKm - lastReplacedOdoKm).clamp(0.0, 999999.0);
    return drivenSinceReplace / replaceCycleKm;
  }

  /// 경과 개월 기준 진행률 (0.0 ~ 1.0+)
  double getDateProgress(DateTime now) {
    if (replaceCycleMonths <= 0) return 0.0;
    final daysElapsed = now.difference(lastReplacedDate).inDays.clamp(0, 99999);
    final cycleDays = replaceCycleMonths * 30.4;
    return daysElapsed / cycleDays;
  }

  /// 주행거리 진행률과 기간 진행률 중 더 높은 도래율 반환
  double getOverallProgress(double currentOdoKm, DateTime now) {
    final odoP = getOdoProgress(currentOdoKm);
    final dateP = getDateProgress(now);
    return odoP > dateP ? odoP : dateP;
  }

  /// 다음 교체 권장 주행거리(km)
  double get nextReplaceOdoKm => lastReplacedOdoKm + replaceCycleKm;

  /// 남은 주행거리(km)
  double getRemainingKm(double currentOdoKm) => nextReplaceOdoKm - currentOdoKm;

  /// 다음 교체 권장 일자
  DateTime get nextReplaceDate => DateTime(
        lastReplacedDate.year,
        lastReplacedDate.month + replaceCycleMonths,
        lastReplacedDate.day,
      );

  MaintenanceItem copyWith({
    int? id,
    String? itemName,
    double? lastReplacedOdoKm,
    DateTime? lastReplacedDate,
    double? replaceCycleKm,
    int? replaceCycleMonths,
  }) {
    return MaintenanceItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      lastReplacedOdoKm: lastReplacedOdoKm ?? this.lastReplacedOdoKm,
      lastReplacedDate: lastReplacedDate ?? this.lastReplacedDate,
      replaceCycleKm: replaceCycleKm ?? this.replaceCycleKm,
      replaceCycleMonths: replaceCycleMonths ?? this.replaceCycleMonths,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'item_name': itemName,
      'last_replaced_odo_km': lastReplacedOdoKm,
      'last_replaced_date': lastReplacedDate.toIso8601String(),
      'replace_cycle_km': replaceCycleKm,
      'replace_cycle_months': replaceCycleMonths,
    };
  }

  factory MaintenanceItem.fromMap(Map<String, dynamic> map) {
    return MaintenanceItem(
      id: map['id'] as int?,
      itemName: map['item_name'] as String,
      lastReplacedOdoKm: (map['last_replaced_odo_km'] as num).toDouble(),
      lastReplacedDate: DateTime.parse(map['last_replaced_date'] as String),
      replaceCycleKm: (map['replace_cycle_km'] as num).toDouble(),
      replaceCycleMonths: (map['replace_cycle_months'] as num).toInt(),
    );
  }
}
