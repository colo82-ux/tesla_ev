/// 충전 단가 프리셋 모델 (집밥 완속, 수퍼차저, 공용급속 등)
class ChargePreset {
  final String name;
  final String locationType; // '수퍼차저' | '집밥(완속)' | '공용급속' | '기타'
  final int unitPriceKrw;

  const ChargePreset({
    required this.name,
    required this.locationType,
    required this.unitPriceKrw,
  });

  static const List<ChargePreset> defaultPresets = [
    ChargePreset(
      name: '집밥 완속 (심야/아파트)',
      locationType: '집밥(완속)',
      unitPriceKrw: 250,
    ),
    ChargePreset(
      name: '회사 완속 충전',
      locationType: '회사(완속)',
      unitPriceKrw: 200,
    ),
    ChargePreset(
      name: '테슬라 수퍼차저',
      locationType: '수퍼차저',
      unitPriceKrw: 420,
    ),
    ChargePreset(
      name: '환경부/공용 급속',
      locationType: '공용급속',
      unitPriceKrw: 347,
    ),
    ChargePreset(
      name: '기타 충전소',
      locationType: '기타',
      unitPriceKrw: 300,
    ),
  ];

  ChargePreset copyWith({
    String? name,
    String? locationType,
    int? unitPriceKrw,
  }) {
    return ChargePreset(
      name: name ?? this.name,
      locationType: locationType ?? this.locationType,
      unitPriceKrw: unitPriceKrw ?? this.unitPriceKrw,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location_type': locationType,
      'unit_price_krw': unitPriceKrw,
    };
  }

  factory ChargePreset.fromMap(Map<String, dynamic> map) {
    return ChargePreset(
      name: map['name'] as String,
      locationType: map['location_type'] as String,
      unitPriceKrw: (map['unit_price_krw'] as num).toInt(),
    );
  }
}
