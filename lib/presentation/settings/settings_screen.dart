import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/theme/tesla_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/maintenance_item.dart';
import '../../providers/app_providers.dart';

/// 4. 소모품 & 설정 (Settings 탭)
/// - 누적 주행거리 기반 소모품 교체 도래 알림 프로그레스 바
/// - TeslaMate 서버 URL / API Token 및 Tesla Direct API Token 입력 폼 (Secure Storage 저장)
/// - 로컬 SQLite DB 백업(JSON/CSV 내보내기) 및 복원 기능
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _teslamateUrlCtrl = TextEditingController();
  final _teslamateTokenCtrl = TextEditingController();
  final _teslamateCarIdCtrl = TextEditingController(text: '1');

  final _teslaDirectTokenCtrl = TextEditingController();
  final _teslaVehicleIdCtrl = TextEditingController();
  bool _preventWakeUp = true;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStoredApiConfigs();
  }

  Future<void> _loadStoredApiConfigs() async {
    final storage = ref.read(secureStorageProvider);
    final tmUrl = await storage.getTeslaMateBaseUrl();
    final tmToken = await storage.getTeslaMateToken();
    final tmCarId = await storage.getTeslaMateCarId();

    final directToken = await storage.getTeslaDirectToken();
    final vehicleId = await storage.getTeslaVehicleId();
    final preventWake = await storage.getPreventWakeUp();

    if (!mounted) return;
    setState(() {
      _teslamateUrlCtrl.text = tmUrl;
      _teslamateTokenCtrl.text = tmToken;
      _teslamateCarIdCtrl.text = tmCarId.toString();
      _teslaDirectTokenCtrl.text = directToken;
      _teslaVehicleIdCtrl.text = vehicleId;
      _preventWakeUp = preventWake;
      _configLoaded = true;
    });
  }

  @override
  void dispose() {
    _teslamateUrlCtrl.dispose();
    _teslamateTokenCtrl.dispose();
    _teslamateCarIdCtrl.dispose();
    _teslaDirectTokenCtrl.dispose();
    _teslaVehicleIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(teslaAppProvider);
    final notifier = ref.read(teslaAppProvider.notifier);
    final currentOdo = appState.snapshot.odometerKm;

    return Scaffold(
      appBar: AppBar(
        title: const Text('소모품 & 연동 설정'),
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout.constrainMaxWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. 누적 주행거리 기반 소모품 교체 도래 알림 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '소모품 교체 주기 알림',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: TeslaColors.textPrimary,
                            ),
                          ),
                          Text(
                            '현재 누적 주행거리: ${UnitConverter.formatDecimal1(currentOdo)} km 기준',
                            style: const TextStyle(
                              fontSize: 12,
                              color: TeslaColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _showAddMaintenanceDialog(context, currentOdo),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('소모품 추가'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...appState.maintenanceItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MaintenanceProgressCard(
                        item: item,
                        currentOdoKm: currentOdo,
                        onMarkReplaced: () async {
                          await notifier.markMaintenanceReplacedNow(item);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${item.itemName} 교체 이력이 현재 주행거리(${currentOdo}km)로 갱신되었습니다.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // 2. 외부 데이터 연동 모듈 설정 (TeslaMate REST API & Tesla Fleet API)
                  const Text(
                    '외부 데이터 동기화 연동 설정 (Secure Storage)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TeslaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '활성 동기화 모드 선택',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TeslaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<SyncMode>(
                              segments: const [
                                ButtonSegment(
                                  value: SyncMode.teslamate,
                                  icon: Icon(Icons.dns_rounded, size: 16),
                                  label: Text(
                                    'TeslaMate API',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                ButtonSegment(
                                  value: SyncMode.directFleet,
                                  icon:
                                      Icon(Icons.cloud_sync_rounded, size: 16),
                                  label: Text(
                                    'Tesla Fleet API',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              selected: {appState.activeSyncMode},
                              onSelectionChanged: (s) {
                                notifier.setSyncMode(s.first);
                              },
                            ),
                          ),
                          const Divider(height: 28),

                          // 모드 A 설정 폼
                          const Text(
                            '모드 A: TeslaMate REST API 설정',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TeslaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'GET /api/v1/cars/{id}/drives 및 /charges 호출 · Wh/km → km/kWh 자동 변환',
                            style: TextStyle(
                              fontSize: 11,
                              color: TeslaColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _teslamateUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'TeslaMate Base URL',
                              hintText: 'https://teslamate.example.com',
                              prefixIcon: Icon(Icons.link_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _teslamateTokenCtrl,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'TeslaMate Bearer Token',
                                    prefixIcon: Icon(Icons.key_rounded),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _teslamateCarIdCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Car ID',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 28),

                          // 모드 B 설정 폼
                          const Text(
                            '모드 B: Tesla 공식 Fleet API 직접 호출 설정',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: TeslaColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'GET /api/1/vehicles/{id}/vehicle_data 단발성 호출 및 스냅샷 비교',
                            style: TextStyle(
                              fontSize: 11,
                              color: TeslaColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _teslaDirectTokenCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Tesla Fleet API Access Token',
                              prefixIcon: Icon(Icons.vpn_key_rounded),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _teslaVehicleIdCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vehicle ID (VIN 또는 테슬라 차량 ID)',
                              prefixIcon: Icon(Icons.directions_car_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              '차량 절전(asleep) 상태 시 깨우지 않기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              '주차 중 불필요한 웨이크업으로 인한 Vampire Drain(대기전력 손실) 방지',
                              style: TextStyle(
                                fontSize: 11,
                                color: TeslaColors.textSecondary,
                              ),
                            ),
                            value: _preventWakeUp,
                            activeColor: TeslaColors.batteryGreen,
                            onChanged: (val) {
                              setState(() => _preventWakeUp = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: !_configLoaded
                                  ? null
                                  : () async {
                                      final storage =
                                          ref.read(secureStorageProvider);
                                      await storage.saveTeslaMateConfig(
                                        baseUrl: _teslamateUrlCtrl.text,
                                        apiToken: _teslamateTokenCtrl.text,
                                        carId: int.tryParse(
                                              _teslamateCarIdCtrl.text,
                                            ) ??
                                            1,
                                      );
                                      await storage.saveTeslaDirectConfig(
                                        accessToken: _teslaDirectTokenCtrl.text,
                                        vehicleId: _teslaVehicleIdCtrl.text,
                                        preventWakeUp: _preventWakeUp,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'API 엔드포인트 및 토큰이 Secure Storage에 안전하게 저장되었습니다.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.lock_outline_rounded,
                                  size: 18),
                              label: const Text('API 연동 설정 저장'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. 로컬 SQLite DB 백업(JSON/CSV 내보내기) 및 복원 섹션
                  const Text(
                    '로컬 SQLite 데이터베이스 백업 및 복원',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TeslaColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '모든 주행/충전/지출/소모품 데이터는 스마트폰 내장 SQLite에 오프라인 우선으로 저장됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: TeslaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _exportJsonBackup(context),
                                icon: const Icon(Icons.data_object_rounded,
                                    size: 18),
                                label: const Text('JSON 전체 백업 내보내기'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _exportCsvSummary(context),
                                icon: const Icon(Icons.table_chart_outlined,
                                    size: 18),
                                label: const Text('CSV 스프레드시트 내보내기'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _restoreFromJsonFile(context),
                                icon: const Icon(
                                    Icons.settings_backup_restore_rounded,
                                    size: 18),
                                label: const Text('JSON 백업 파일 복원'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await notifier.clearAllSampleLogs();
                                  await notifier.syncNow();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '샘플(더미) 기록을 모두 비우고 실제 차량 데이터로 동기화했습니다.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                    Icons.cleaning_services_rounded,
                                    size: 18),
                                label: const Text('샘플 기록 비우기 (실차 전용)'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await notifier.resetWithMockData();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '현실적인 테슬라 주행/충전 더미 데이터(Mock Data)가 재생성되었습니다.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.auto_fix_high_rounded,
                                    size: 18),
                                label: const Text('더미 데이터 재생성'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Future<void> _exportJsonBackup(BuildContext context) async {
    try {
      final file = await DatabaseHelper.instance.exportBackupJsonFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '테슬라_ev 로컬 SQLite JSON 백업',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 백업 생성 완료: $e')),
        );
      }
    }
  }

  Future<void> _exportCsvSummary(BuildContext context) async {
    try {
      final file = await DatabaseHelper.instance.exportSummaryCsvFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '테슬라_ev 주행/충전/지출 CSV 내보내기',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 내보내기 완료: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromJsonFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      await ref.read(teslaAppProvider.notifier).restoreFromJson(content);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('JSON 백업 파일로부터 로컬 SQLite DB 복원이 완료되었습니다.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showAddMaintenanceDialog(BuildContext context, double currentOdo) {
    final nameCtrl = TextEditingController();
    final cycleKmCtrl = TextEditingController(text: '15000');
    final cycleMonthsCtrl = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TeslaColors.surface,
        title: const Text('소모품 관리 항목 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '소모품명 (예: 타이어 교체, 냉각수 점검)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cycleKmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '교체 주기 주행거리 (km)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cycleMonthsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '교체 주기 기간 (개월)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final cycleKm = double.tryParse(cycleKmCtrl.text) ?? 15000;
              final cycleMonths = int.tryParse(cycleMonthsCtrl.text) ?? 12;

              await ref.read(teslaAppProvider.notifier).saveMaintenanceItem(
                    MaintenanceItem(
                      itemName: nameCtrl.text.trim(),
                      lastReplacedOdoKm: currentOdo,
                      lastReplacedDate: DateTime.now(),
                      replaceCycleKm: cycleKm,
                      replaceCycleMonths: cycleMonths,
                    ),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceProgressCard extends StatelessWidget {
  final MaintenanceItem item;
  final double currentOdoKm;
  final VoidCallback onMarkReplaced;

  const _MaintenanceProgressCard({
    required this.item,
    required this.currentOdoKm,
    required this.onMarkReplaced,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = item.getOverallProgress(currentOdoKm, now);
    final remainingKm = item.getRemainingKm(currentOdoKm);
    final percent = (progress * 100).clamp(0, 100).round();

    final statusColor = progress >= 0.90
        ? TeslaColors.teslaRed
        : (progress >= 0.75
            ? TeslaColors.warningAmber
            : TeslaColors.batteryGreen);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.itemName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: TeslaColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    progress >= 0.90
                        ? '교체 시기 도래 ($percent%)'
                        : '도래율 $percent%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: TeslaColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '최근 교체: ${UnitConverter.formatNumber(item.lastReplacedOdoKm)}km · '
                    '권장 주기: 매 ${UnitConverter.formatNumber(item.replaceCycleKm)}km / ${item.replaceCycleMonths}개월 '
                    '(잔여 ${remainingKm > 0 ? "${UnitConverter.formatNumber(remainingKm)}km" : "초과"})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: TeslaColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onMarkReplaced,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: TeslaColors.electricBlue,
                  ),
                  child: const Text('교체 완료 기록'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
