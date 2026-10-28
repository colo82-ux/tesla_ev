import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/tesla_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/unit_converter.dart';
import '../../providers/app_providers.dart';

/// 1. 대시보드 (Home 탭)
/// - 상단: 배터리 잔량(SoC %), 주행 가능 거리, 누적 주행거리(Odometer), 마지막 동기화 시각 및 [지금 동기화] 버튼
/// - 중단: 이번 달 평균 전비(km/kWh), 총 주행거리(km), 총 충전 비용(원), 1km당 주행 원가 요약 카드
/// - 하단: 최근 7일간의 일별 전비 추이 꺾은선 차트 (`fl_chart`)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(teslaAppProvider);
    final notifier = ref.read(teslaAppProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.electric_car_rounded,
              color: TeslaColors.teslaRed,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('테슬라_ev'),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: TeslaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: TeslaColors.border),
                ),
                child: Text(
                  appState.activeSyncMode.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: TeslaColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '데이터 새로고침',
            onPressed: () => notifier.loadAll(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout.constrainMaxWidth(
              child: RefreshIndicator(
                onRefresh: () async {
                  final result = await notifier.syncNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. 상단: 차량 배터리 상태 & 누적 주행거리 & 차량 모델/이름 카드
                    _VehicleStatusHeroCard(state: appState),
                    const SizedBox(height: 20),

                    // 2. 중단: 핵심 요약 카드 (전비, 총 주행거리, 총 충전비용, 1km당 주행원가, 타이어 공기압, 소프트웨어 버전)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '운행 및 차량 정보',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: TeslaColors.textPrimary,
                          ),
                        ),
                        Text(
                          '총 ${appState.drives.length}회 트립 누적',
                          style: const TextStyle(
                            fontSize: 12,
                            color: TeslaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MonthlySummaryGrid(state: appState),
                    const SizedBox(height: 24),

                    // 3. 중단 2: 최근 7일간 일별 전비 추이 꺾은선 차트 (fl_chart)
                    const Text(
                      '최근 7일 일별 전비 추이 (km/kWh)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TeslaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Last7DaysEfficiencyChartCard(
                      points: appState.last7DaysEfficiency,
                      avgEfficiency: appState.monthlyAvgEfficiencyKmKwh,
                    ),
                    const SizedBox(height: 24),

                    // 4. 하단: 월별 차량 지출 차트 (최근 6개월 / 1년 선택 가능)
                    _MonthlyExpenseSection(state: appState),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _VehicleStatusHeroCard extends StatelessWidget {
  final TeslaAppState state;

  const _VehicleStatusHeroCard({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final snap = state.snapshot;
    final socColor = snap.soc >= 50
        ? TeslaColors.batteryGreen
        : (snap.soc >= 20 ? TeslaColors.warningAmber : TeslaColors.teslaRed);

    final lastSyncStr = state.lastSyncTime != null
        ? UnitConverter.formatDateTime(state.lastSyncTime!)
        : '동기화 기록 없음';

    final isAsleep =
        snap.vehicleState == 'asleep' || snap.vehicleState == 'offline';
    final stateColor = isAsleep
        ? TeslaColors.warningAmber
        : (snap.vehicleState == 'charging'
            ? TeslaColors.batteryGreen
            : (snap.vehicleState == 'driving'
                ? TeslaColors.electricBlue
                : TeslaColors.batteryGreen));

    final String stateText;
    if (snap.vehicleState == 'offline') {
      stateText =
          '오프라인 (절전 중) · 외기 ${UnitConverter.formatDecimal1(snap.outsideTemp)}°C';
    } else if (snap.vehicleState == 'asleep') {
      stateText =
          '절전 모드 (Asleep) · 외기 ${UnitConverter.formatDecimal1(snap.outsideTemp)}°C';
    } else if (snap.vehicleState == 'charging') {
      stateText = '충전 중 (Charging)';
    } else if (snap.vehicleState == 'driving') {
      stateText = '주행 중 (Driving)';
    } else {
      stateText =
          '온라인 (Online) · 외기 ${UnitConverter.formatDecimal1(snap.outsideTemp)}°C';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 배지 및 차량 모델명 & 차량 이름 (Model Y - 찌이)
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stateColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stateText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: TeslaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: TeslaColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TeslaColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.directions_car_rounded,
                        size: 15,
                        color: TeslaColors.teslaRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${snap.carModel} - ${snap.carName}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: TeslaColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 배터리 잔량(SoC %) 및 주행 가능 거리, 누적 주행거리
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${snap.soc}%',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.5,
                    color: socColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주행 가능 거리 ${UnitConverter.formatDecimal1(snap.estimatedRangeKm)} km',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: TeslaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '누적 주행거리(Odometer) ${UnitConverter.formatDecimal1(snap.odometerKm)} km',
                        style: const TextStyle(
                          fontSize: 13,
                          color: TeslaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 배터리 게이지 바
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (snap.soc / 100.0).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: TeslaColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(socColor),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '마지막 동기화: $lastSyncStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: TeslaColors.textMuted,
                  ),
                ),
                const Text(
                  '↓ 아래로 당겨 동기화',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: TeslaColors.electricBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlySummaryGrid extends StatelessWidget {
  final TeslaAppState state;

  const _MonthlySummaryGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveLayout.getGridCrossAxisCount(
      context,
      phoneCount: 2,
      foldCount: 4,
    );

    final snap = state.snapshot;
    final cards = [
      _MetricCardData(
        title: '이번 달 평균 전비',
        value:
            '${UnitConverter.formatDecimal2(state.monthlyAvgEfficiencyKmKwh)} km/kWh',
        subtitle:
            '환산 ${UnitConverter.formatDecimal1(UnitConverter.kmPerKwhToWhPerKm(state.monthlyAvgEfficiencyKmKwh))} Wh/km',
        icon: Icons.bolt_rounded,
        accentColor: TeslaColors.batteryGreen,
      ),
      _MetricCardData(
        title: '총 주행거리',
        value: '${UnitConverter.formatDecimal1(state.monthlyTotalDistanceKm)} km',
        subtitle:
            '소모 전력 ${UnitConverter.formatDecimal1(state.monthlyTotalUsedKwh)} kWh',
        icon: Icons.route_rounded,
        accentColor: TeslaColors.electricBlue,
      ),
      _MetricCardData(
        title: '총 충전 비용',
        value: UnitConverter.formatKrw(state.monthlyTotalChargeCostKrw),
        subtitle: '충전 ${state.charges.length}회 누적',
        icon: Icons.ev_station_rounded,
        accentColor: TeslaColors.warningAmber,
      ),
      _MetricCardData(
        title: '1km당 주행 원가',
        value: '${UnitConverter.formatDecimal1(state.monthlyCostPerKmKrw)} 원/km',
        subtitle: '내연기관 대비 약 70% 절감',
        icon: Icons.savings_rounded,
        accentColor: TeslaColors.teslaRed,
      ),
      _MetricCardData(
        title: '차량 실내 / 외기 온도',
        value:
            '${snap.insideTemp.toStringAsFixed(1)}°C / ${snap.outsideTemp.toStringAsFixed(1)}°C',
        subtitle:
            '실내 ${snap.insideTemp.toStringAsFixed(1)}°C · 외기 ${snap.outsideTemp.toStringAsFixed(1)}°C',
        icon: Icons.thermostat_rounded,
        accentColor: TeslaColors.electricBlue,
      ),
      _MetricCardData(
        title: '소프트웨어 현재 버전',
        value: snap.softwareVersion,
        subtitle: 'OTA 펌웨어 자동 동기화',
        icon: Icons.system_update_rounded,
        accentColor: TeslaColors.purpleAccent,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 122,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: TeslaColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(item.icon, color: item.accentColor, size: 18),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: TeslaColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: TeslaColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class _Last7DaysEfficiencyChartCard extends StatelessWidget {
  final List<DailyEfficiencyPoint> points;
  final double avgEfficiency;

  const _Last7DaysEfficiencyChartCard({
    required this.points,
    required this.avgEfficiency,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    double maxPointEff = 0.0;
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].avgEfficiencyKmKwh));
      if (points[i].avgEfficiencyKmKwh > maxPointEff) {
        maxPointEff = points[i].avgEfficiencyKmKwh;
      }
    }

    // 데이터 최대값에 +1 적용 (데이터가 없거나 낮은 경우에도 기본 최소 10.0 확보)
    final double calculatedMaxY =
        (maxPointEff > 0 && (maxPointEff + 1.0) > 10.0)
            ? (maxPointEff + 1.0).ceilToDouble()
            : 10.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '일별 평균 전비 (km/kWh)',
                  style: TextStyle(
                    fontSize: 13,
                    color: TeslaColors.textSecondary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: TeslaColors.electricBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '평균 ${UnitConverter.formatDecimal2(avgEfficiency)} km/kWh',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: TeslaColors.electricBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 210,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: calculatedMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2.0,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: TeslaColors.border,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 2.0,
                        getTitlesWidget: (val, meta) {
                          return Text(
                            val.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 11,
                              color: TeslaColors.textMuted,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final dt = points[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${dt.month}/${dt.day}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: TeslaColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          final p = points[idx];
                          return LineTooltipItem(
                            '${p.date.month}/${p.date.day}\n${p.avgEfficiencyKmKwh.toStringAsFixed(2)} km/kWh\n(${p.distanceKm.toStringAsFixed(1)}km 주행)',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.28,
                      color: TeslaColors.teslaRed,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: TeslaColors.teslaRed,
                          strokeWidth: 2,
                          strokeColor: TeslaColors.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: TeslaColors.teslaRed.withOpacity(0.14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 대시보드 하단: 월별 지출 추이 차트 (최근 6개월 / 최근 1년 선택 가능)
class _MonthlyExpenseSection extends StatefulWidget {
  final TeslaAppState state;

  const _MonthlyExpenseSection({required this.state});

  @override
  State<_MonthlyExpenseSection> createState() => _MonthlyExpenseSectionState();
}

class _MonthlyExpenseSectionState extends State<_MonthlyExpenseSection> {
  int _selectedMonths = 6; // 기본 6개월, 12개월(1년) 토글 지원

  @override
  Widget build(BuildContext context) {
    final points = widget.state.getMonthlyExpenses(months: _selectedMonths);
    final totalPeriodKrw = points.fold<int>(0, (s, p) => s + p.totalKrw);
    final avgMonthlyKrw =
        points.isEmpty ? 0 : (totalPeriodKrw / points.length).round();

    final maxTotal = points.fold<int>(
      100000,
      (prev, e) => e.totalKrw > prev ? e.totalKrw : prev,
    );
    // 차트 상단 여유 공간 확보 (만원 단위 올림)
    final maxYManWon = ((maxTotal / 10000.0) * 1.25).ceilToDouble().clamp(10.0, 500.0);
    final intervalManWon = (maxYManWon / 4.0).ceilToDouble().clamp(2.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const Text(
              '월별 지출 추이 (충전비 + 유지비)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TeslaColors.textPrimary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('최근 6개월', style: TextStyle(fontSize: 11)),
                  selected: _selectedMonths == 6,
                  onSelected: (_) => setState(() => _selectedMonths = 6),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('최근 1년', style: TextStyle(fontSize: 11)),
                  selected: _selectedMonths == 12,
                  onSelected: (_) => setState(() => _selectedMonths = 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendDot(
                          color: TeslaColors.batteryGreen,
                          label: '충전비',
                        ),
                        const SizedBox(width: 12),
                        _LegendDot(
                          color: TeslaColors.warningAmber,
                          label: '유지/기타(보험·세차·주차)',
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TeslaColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '월평균 ${UnitConverter.formatKrw(avgMonthlyKrw)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: TeslaColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 210,
                  child: BarChart(
                    BarChartData(
                      maxY: maxYManWon,
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: intervalManWon,
                        getDrawingHorizontalLine: (value) => const FlLine(
                          color: TeslaColors.border,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: intervalManWon,
                            getTitlesWidget: (val, meta) {
                              return Text(
                                '${val.toInt()}만',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: TeslaColors.textMuted,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= points.length) {
                                return const SizedBox.shrink();
                              }
                              final p = points[idx];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${p.month}월',
                                  style: TextStyle(
                                    fontSize: _selectedMonths == 12 ? 10 : 11,
                                    color: TeslaColors.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final p = points[group.x];
                            return BarTooltipItem(
                              '${p.year}년 ${p.month}월\n'
                              '총 ${UnitConverter.formatKrw(p.totalKrw)}\n'
                              '충전비: ${UnitConverter.formatKrw(p.chargeCostKrw)}\n'
                              '유지비: ${UnitConverter.formatKrw(p.otherExpenseKrw)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            );
                          },
                        ),
                      ),
                      barGroups: List.generate(points.length, (idx) {
                        final p = points[idx];
                        final chargeMan = p.chargeCostKrw / 10000.0;
                        final totalMan = p.totalKrw / 10000.0;

                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: totalMan,
                              width: _selectedMonths == 12 ? 14 : 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(5),
                              ),
                              rodStackItems: [
                                BarChartRodStackItem(
                                  0,
                                  chargeMan,
                                  TeslaColors.batteryGreen,
                                ),
                                BarChartRodStackItem(
                                  chargeMan,
                                  totalMan,
                                  TeslaColors.warningAmber,
                                ),
                              ],
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxYManWon,
                                color: TeslaColors.surfaceElevated,
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: TeslaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
