import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/tesla_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/drive_log.dart';
import '../../data/models/vehicle_snapshot.dart';
import '../../providers/app_providers.dart';

/// 2. 전비 분석 (Efficiency 탭)
/// - 외기온도 구간별(영하, 0~15도, 15~25도, 25도 이상) 평균 전비 비교 막대 차트
/// - 주차 중 대기 소모 전력(Vampire Drain) 통계
/// - 주행 트립별 리스트 및 평균 전비(km/kWh) 표시
class EfficiencyScreen extends ConsumerWidget {
  const EfficiencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(teslaAppProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('전비 분석 및 대기전력'),
        actions: [
          TextButton.icon(
            onPressed: () => _showAddManualDriveModal(context, ref),
            icon: const Icon(Icons.add_road_rounded, size: 18),
            label: const Text('수기 트립 추가'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: '더보기',
            onSelected: (val) async {
              if (val == 'full_sync') {
                final scaffold = ScaffoldMessenger.of(context);
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('전체 주행 기록 재동기화 중...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                final res = await ref
                    .read(teslaAppProvider.notifier)
                    .syncNow(fullSync: true);
                scaffold.showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'full_sync',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded,
                        size: 18, color: TeslaColors.electricBlue),
                    SizedBox(width: 8),
                    Text('전체 기록 다시 동기화 (복원)'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout.constrainMaxWidth(
              child: RefreshIndicator(
                onRefresh: () async {
                  final result =
                      await ref.read(teslaAppProvider.notifier).syncNow();
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
                    // 1. 외기온도 구간별 평균 전비 비교 막대 차트
                    const Text(
                      '외기온도 구간별 평균 전비 (km/kWh)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TeslaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TemperatureBracketBarChartCard(
                      bracketMap: appState.efficiencyByTempBracket,
                      overallAvg: appState.overallAvgEfficiencyKmKwh,
                    ),
                    const SizedBox(height: 24),

                    // 2. 주차 중 대기 소모 전력 (Vampire Drain) 통계
                    const Text(
                      '주차 중 대기 소모 전력 (Vampire Drain) 통계',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TeslaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _VampireDrainStatsCard(drains: appState.vampireDrains),
                    const SizedBox(height: 24),

                    // 3. 주행 트립별 상세 리스트
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '주행 트립별 상세 기록',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: TeslaColors.textPrimary,
                          ),
                        ),
                        Text(
                          '전체 평균 ${UnitConverter.formatDecimal2(appState.overallAvgEfficiencyKmKwh)} km/kWh',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TeslaColors.batteryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...appState.drives.map(
                      (drive) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DriveTripCard(
                          drive: drive,
                          onDelete: drive.id != null
                              ? () => _confirmDeleteDrive(context, ref, drive)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDeleteDrive(
    BuildContext context,
    WidgetRef ref,
    DriveLog drive,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TeslaColors.surface,
        title: const Text(
          '주행 기록 삭제',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${UnitConverter.formatDateTime(drive.startTime)} 주행 기록(${UnitConverter.formatDecimal1(drive.distanceKm)} km)을 정말 삭제하시겠습니까?\n\n※ 참고: 증분 동기화 방식이므로 삭제된 기록은 일반 동기화 시 다시 나타나지 않으며, 상단 메뉴의 [전체 기록 다시 동기화]를 통해 서버로부터 다시 복원할 수 있습니다.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TeslaColors.teslaRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && drive.id != null) {
      await ref.read(teslaAppProvider.notifier).deleteDriveLog(drive.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주행 트립 기록이 삭제되었습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddManualDriveModal(BuildContext context, WidgetRef ref) {
    final distCtrl = TextEditingController(text: '32.5');
    final kwhCtrl = TextEditingController(text: '5.0');
    final tempCtrl = TextEditingController(text: '18.0');
    final startSocCtrl = TextEditingController(text: '80');
    final endSocCtrl = TextEditingController(text: '73');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TeslaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '수기 주행 기록 추가',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: distCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '주행거리 (km)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: kwhCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '소모 전력 (kWh)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tempCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '외기온도 (°C)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: startSocCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '출발 SoC (%)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: endSocCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '도착 SoC (%)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final dist = double.tryParse(distCtrl.text) ?? 0.0;
                    final kwh = double.tryParse(kwhCtrl.text) ?? 0.0;
                    if (dist <= 0 || kwh <= 0) return;

                    final temp = double.tryParse(tempCtrl.text) ?? 18.0;
                    final sSoc = int.tryParse(startSocCtrl.text) ?? 80;
                    final eSoc = int.tryParse(endSocCtrl.text) ?? 70;
                    final now = DateTime.now();

                    await ref.read(teslaAppProvider.notifier).addDriveLog(
                          DriveLog(
                            startTime: now.subtract(const Duration(minutes: 40)),
                            endTime: now,
                            distanceKm: dist,
                            usedEnergyKwh: kwh,
                            efficiencyKmKwh:
                                UnitConverter.calculateEfficiencyKmPerKwh(
                              distanceKm: dist,
                              usedEnergyKwh: kwh,
                            ),
                            outsideTempAvg: temp,
                            startSoc: sSoc,
                            endSoc: eSoc,
                            source: 'manual',
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('주행 트립 저장'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TemperatureBracketBarChartCard extends StatelessWidget {
  final Map<TempBracket, double> bracketMap;
  final double overallAvg;

  const _TemperatureBracketBarChartCard({
    required this.bracketMap,
    required this.overallAvg,
  });

  @override
  Widget build(BuildContext context) {
    final brackets = TempBracket.values;
    final barColors = [
      const Color(0xFF38BDF8), // 영하: 아이스 블루
      TeslaColors.electricBlue, // 0~15도: 블루
      TeslaColors.batteryGreen, // 15~25도: 최적 구간 그린
      TeslaColors.warningAmber, // 25도 이상: 앰버
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '상온(15~25°C) 구간에서 배터리 효율이 가장 높으며, 영하에서는 배터리 히팅으로 전비가 하락합니다.',
              style: TextStyle(
                fontSize: 12,
                color: TeslaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: 9.0,
                  minY: 0,
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
                        reservedSize: 32,
                        interval: 2.0,
                        getTitlesWidget: (val, meta) => Text(
                          val.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 11,
                            color: TeslaColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= brackets.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              brackets[idx].label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
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
                        final bracket = brackets[group.x];
                        return BarTooltipItem(
                          '${bracket.label}\n${rod.toY.toStringAsFixed(2)} km/kWh',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(brackets.length, (idx) {
                    final value = bracketMap[brackets[idx]] ?? 0.0;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: barColors[idx],
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: 9.0,
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
    );
  }
}

class _VampireDrainStatsCard extends StatelessWidget {
  final List<VampireDrainLog> drains;

  const _VampireDrainStatsCard({required this.drains});

  @override
  Widget build(BuildContext context) {
    final totalLostKwh =
        drains.fold<double>(0.0, (s, e) => s + e.lostEnergyKwh);
    final totalLostRangeKm =
        drains.fold<double>(0.0, (s, e) => s + e.lostRangeKm);
    final avgDailySocDrain = drains.isEmpty
        ? 0.0
        : drains.fold<double>(0.0, (s, e) => s + e.drainSocPerDay) /
            drains.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _DrainMiniStat(
                    label: '누적 손실 전력',
                    value: '${UnitConverter.formatDecimal2(totalLostKwh)} kWh',
                    color: TeslaColors.warningAmber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DrainMiniStat(
                    label: '감소 주행거리',
                    value:
                        '-${UnitConverter.formatDecimal1(totalLostRangeKm)} km',
                    color: TeslaColors.teslaRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DrainMiniStat(
                    label: '일평균 손실률',
                    value:
                        '-${UnitConverter.formatDecimal1(avgDailySocDrain)}% /일',
                    color: TeslaColors.purpleAccent,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text(
              '최근 주차 중 대기 소모 이력',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TeslaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ...drains.take(3).map((d) {
              final modeColor = d.sentryModeActive
                  ? TeslaColors.teslaRed
                  : TeslaColors.batteryGreen;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: TeslaColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      d.sentryModeActive
                          ? Icons.visibility_rounded
                          : Icons.bedtime_rounded,
                      size: 18,
                      color: modeColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${UnitConverter.formatShortDate(d.startTime)} · ${d.parkedHours.toStringAsFixed(1)}시간 주차',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TeslaColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.sentryModeActive ? '감시모드 ON' : '딥슬립 (절전)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: modeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${d.startSoc}% → ${d.endSoc}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TeslaColors.warningAmber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '-${d.lostEnergyKwh} kWh',
                          style: const TextStyle(
                            fontSize: 11,
                            color: TeslaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DrainMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DrainMiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: TeslaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: TeslaColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriveTripCard extends StatelessWidget {
  final DriveLog drive;
  final VoidCallback? onDelete;

  const _DriveTripCard({
    required this.drive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final effColor = drive.efficiencyKmKwh >= 6.5
        ? TeslaColors.batteryGreen
        : (drive.efficiencyKmKwh >= 5.2
            ? TeslaColors.electricBlue
            : TeslaColors.warningAmber);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: effColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    drive.efficiencyKmKwh.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: effColor,
                    ),
                  ),
                  Text(
                    'km/kWh',
                    style: TextStyle(
                      fontSize: 10,
                      color: effColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${UnitConverter.formatDecimal1(drive.distanceKm)} km 주행',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: TeslaColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: TeslaColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          drive.source,
                          style: const TextStyle(
                            fontSize: 10,
                            color: TeslaColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '소모 ${UnitConverter.formatDecimal1(drive.usedEnergyKwh)} kWh · SoC ${drive.startSoc}%→${drive.endSoc}% · ${UnitConverter.formatDecimal1(drive.outsideTempAvg)}°C',
                    style: const TextStyle(
                      fontSize: 12,
                      color: TeslaColors.textSecondary,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${UnitConverter.formatDateTime(drive.startTime)} (${drive.duration.inMinutes}분)',
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
            if (onDelete != null)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: '삭제',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: TeslaColors.textMuted,
                  ),
                  onPressed: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
