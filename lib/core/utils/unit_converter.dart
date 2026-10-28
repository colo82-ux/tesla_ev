import 'package:intl/intl.dart';

/// 외기온도 구간 정의
enum TempBracket {
  freezing('영하 (<0°C)'),
  cold('0~15°C'),
  mild('15~25°C'),
  hot('25°C 이상');

  final String label;
  const TempBracket(this.label);
}

/// 전비 단위 변환 및 포맷팅 유틸리티
class UnitConverter {
  UnitConverter._();

  static final NumberFormat _krwFormat = NumberFormat('#,###', 'ko_KR');
  static final NumberFormat _decimal1Format = NumberFormat('#,##0.0', 'ko_KR');
  static final NumberFormat _decimal2Format = NumberFormat('#,##0.00', 'ko_KR');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _shortDateFormat = DateFormat('MM/dd (E)', 'ko_KR');

  /// TeslaMate의 Wh/km 단위를 한국 표준 전비 단위인 km/kWh로 변환합니다.
  /// 예: 150 Wh/km -> 1000 / 150 = 6.67 km/kWh
  static double whPerKmToKmPerKwh(double whPerKm) {
    if (whPerKm <= 0) return 0.0;
    return double.parse((1000.0 / whPerKm).toStringAsFixed(2));
  }

  /// km/kWh 단위를 Wh/km 단위로 역변환합니다.
  static double kmPerKwhToWhPerKm(double kmPerKwh) {
    if (kmPerKwh <= 0) return 0.0;
    return double.parse((1000.0 / kmPerKwh).toStringAsFixed(1));
  }

  /// 주행거리(km)와 소모 전력(kWh)으로 전비(km/kWh)를 계산합니다.
  static double calculateEfficiencyKmPerKwh({
    required double distanceKm,
    required double usedEnergyKwh,
  }) {
    if (distanceKm <= 0 || usedEnergyKwh <= 0) return 0.0;
    return double.parse((distanceKm / usedEnergyKwh).toStringAsFixed(2));
  }

  /// 총 충전 비용(원)과 총 주행거리(km)로 1km당 주행 원가(원/km)를 계산합니다.
  static double calculateCostPerKm({
    required int totalChargeCostKrw,
    required double totalDistanceKm,
  }) {
    if (totalDistanceKm <= 0 || totalChargeCostKrw <= 0) return 0.0;
    return double.parse((totalChargeCostKrw / totalDistanceKm).toStringAsFixed(1));
  }

  /// 외기온도(°C)를 4개 구간(영하, 0~15도, 15~25도, 25도 이상)으로 분류합니다.
  static TempBracket classifyTemperature(double tempCelsius) {
    if (tempCelsius < 0) {
      return TempBracket.freezing;
    } else if (tempCelsius < 15) {
      return TempBracket.cold;
    } else if (tempCelsius < 25) {
      return TempBracket.mild;
    } else {
      return TempBracket.hot;
    }
  }

  /// bar 또는 psi 압력을 psi 단위로 표준화하여 반환합니다 (1 bar ≈ 14.5038 psi).
  /// 만약 값이 null이거나 0 이하이면 [fallback] 값을 반환합니다.
  static double toTirePsi(num? rawPressure, {double fallback = 41.0}) {
    if (rawPressure == null || rawPressure <= 0) return fallback;
    final val = rawPressure.toDouble();
    if (val < 10.0) {
      // bar 단위 (예: 2.8 bar -> 40.6 psi)
      return double.parse((val * 14.50377).toStringAsFixed(1));
    }
    return double.parse(val.toStringAsFixed(1));
  }

  static String formatKrw(num amount) => '${_krwFormat.format(amount.round())}원';

  static String formatNumber(num value) => _krwFormat.format(value.round());

  static String formatDecimal1(num value) => _decimal1Format.format(value);

  static String formatDecimal2(num value) => _decimal2Format.format(value);

  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);

  static String formatShortDate(DateTime dt) {
    try {
      return _shortDateFormat.format(dt);
    } catch (_) {
      return DateFormat('MM/dd').format(dt);
    }
  }
}
