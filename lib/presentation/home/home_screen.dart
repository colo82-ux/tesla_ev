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
                  await notifier.syncNow();
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. 상단: 차량 배터리 상태 & 누적 주행거리 & [지금 동기화] 카드
                    _VehicleStatusHeroCard(
                      state: appState,
                      onSyncPressed: () async {
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
                    ),
                    const SizedBox(height: 20),

                    // 2. 중단: 이번 달 핵심 요약 카드 (전비, 총 주행거리, 총 충전비용, 1km당 주행원가)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이번 달 운행 및 비용 요약',
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

                    // 3. 하단: 최근 7일간 일별 전비 추이 꺾은선 차트 (fl_chart)
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
                  ],
                ),
              ),
            ),
    );
  }
}

class _VehicleStatusHeroCard extends StatelessWidget {
  final TeslaAppState state;
  final VoidCallback onSyncPressed;

  const _VehicleStatusHeroCard({
    required this.state,
    required this.onSyncPressed,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 배지 및 마지막 동기화 시각 + [지금 동기화] 버튼
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
                        color: snap.vehicleState == 'asleep'
                            ? TeslaColors.warningAmber
                            : TeslaColors.batteryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      snap.vehicleState == 'asleep'
                          ? '절전 모드 (Asleep)'
                          : '온라인 (Online) · 외기 ${UnitConverter.formatDecimal1(snap.outsideTemp)}°C',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: TeslaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: state.isSyncing ? null : onSyncPressed,
                  icon: state.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: Text(state.isSyncing ? '동기화 중...' : '지금 동기화'),
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
                  'Offline-first SQLite',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].avgEfficiencyKmKwh));
    }

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
                  maxY: 9.0,
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
