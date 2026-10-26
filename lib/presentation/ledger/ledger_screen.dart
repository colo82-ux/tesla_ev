import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/tesla_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/utils/unit_converter.dart';
import '../../data/models/charge_log.dart';
import '../../data/models/charge_preset.dart';
import '../../data/models/expense_log.dart';
import '../../providers/app_providers.dart';

/// 통합 타임라인 아이템 래퍼 (충전 내역 + 일반 지출 내역)
class _LedgerTimelineEntry {
  final DateTime date;
  final ChargeLog? chargeLog;
  final ExpenseLog? expenseLog;

  _LedgerTimelineEntry.charge(ChargeLog log)
      : date = log.date,
        chargeLog = log,
        expenseLog = null;

  _LedgerTimelineEntry.expense(ExpenseLog log)
      : date = log.date,
        chargeLog = null,
        expenseLog = log;

  bool get isCharge => chargeLog != null;
}

/// 3. 차계부 & 충전 (Ledger 탭)
/// - 충전 내역 및 일반 지출 내역 통합 타임라인
/// - 충전 단가 프리셋 설정 기능 (집밥 완속 250원/kWh, 수퍼차저 420원/kWh 등 선택 시 충전량에 맞춰 요금 자동 계산)
/// - 플로팅 액션 버튼(+)을 통한 수기 지출/충전 빠른 입력 모달
class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  String _selectedFilter = '전체'; // '전체' | '충전 기록' | '일반 지출'

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(teslaAppProvider);

    // 통합 타임라인 구성 및 최신순 정렬
    final List<_LedgerTimelineEntry> entries = [];
    if (_selectedFilter == '전체' || _selectedFilter == '충전 기록') {
      entries.addAll(appState.charges.map(_LedgerTimelineEntry.charge));
    }
    if (_selectedFilter == '전체' || _selectedFilter == '일반 지출') {
      entries.addAll(appState.expenses.map(_LedgerTimelineEntry.expense));
    }
    entries.sort((a, b) => b.date.compareTo(a.date));

    final totalExpenseKrw =
        appState.expenses.fold<int>(0, (s, e) => s + e.amountKrw);
    final totalChargeEnergyKwh =
        appState.charges.fold<double>(0.0, (s, c) => s + c.addedEnergyKwh);

    return Scaffold(
      appBar: AppBar(
        title: const Text('차계부 & 충전'),
        actions: [
          TextButton.icon(
            onPressed: () =>
                _showPresetEditDialog(context, appState.chargePresets),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('단가 프리셋 설정'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAddModal(context, appState.chargePresets),
        icon: const Icon(Icons.add_rounded),
        label: const Text('빠른 입력'),
      ),
      body: appState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout.constrainMaxWidth(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  // 1. 상단 요약 및 충전 단가 프리셋 배너
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '누적 차계부 총 지출',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: TeslaColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        UnitConverter.formatKrw(totalExpenseKrw),
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: TeslaColors.textPrimary,
                                        ),
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
                                    const Text(
                                      '누적 총 충전 전력량',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: TeslaColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '${UnitConverter.formatDecimal1(totalChargeEnergyKwh)} kWh',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: TeslaColors.batteryGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. 통합 타임라인 헤더 및 필터 칩 (좁은 화면에서도 절대 잘리지 않도록 2단 배치)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '충전 & 지출 통합 타임라인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: TeslaColors.textPrimary,
                        ),
                      ),
                      Text(
                        '총 ${entries.length}건',
                        style: const TextStyle(
                          fontSize: 12,
                          color: TeslaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['전체', '충전 기록', '일반 지출'].map((filter) {
                      final selected = _selectedFilter == filter;
                      return ChoiceChip(
                        label: Text(
                          filter,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedFilter = filter);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // 3. 통합 타임라인 리스트
                  ...entries.map((entry) {
                    if (entry.isCharge) {
                      final c = entry.chargeLog!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ChargeTimelineCard(
                          charge: c,
                          onDelete: c.id != null
                              ? () => ref
                                  .read(teslaAppProvider.notifier)
                                  .deleteChargeLog(c.id!)
                              : null,
                        ),
                      );
                    } else {
                      final e = entry.expenseLog!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExpenseTimelineCard(
                          expense: e,
                          onDelete: e.id != null
                              ? () => ref
                                  .read(teslaAppProvider.notifier)
                                  .deleteExpenseLog(e.id!)
                              : null,
                        ),
                      );
                    }
                  }),
                ],
              ),
            ),
    );
  }

  /// 플로팅 액션 버튼(+) 수기 충전 / 지출 빠른 입력 모달
  void _showQuickAddModal(
    BuildContext context,
    List<ChargePreset> presets, {
    ChargePreset? initialPreset,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TeslaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _QuickEntryBottomSheet(
        presets: presets,
        initialPreset: initialPreset,
      ),
    );
  }

  /// 충전 단가 프리셋 설정 다이얼로그
  void _showPresetEditDialog(
    BuildContext context,
    List<ChargePreset> currentPresets,
  ) {
    final controllers = currentPresets
        .map((p) => TextEditingController(text: p.unitPriceKrw.toString()))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TeslaColors.surface,
        title: const Text('충전 단가 프리셋 설정 (원/kWh)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(currentPresets.length, (i) {
              final preset = currentPresets[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '${preset.name} (${preset.locationType})',
                    suffixText: '원/kWh',
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = <ChargePreset>[];
              for (int i = 0; i < currentPresets.length; i++) {
                final price = int.tryParse(controllers[i].text) ??
                    currentPresets[i].unitPriceKrw;
                updated.add(currentPresets[i].copyWith(unitPriceKrw: price));
              }
              await ref
                  .read(teslaAppProvider.notifier)
                  .updateChargePresets(updated);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _ChargeTimelineCard extends StatelessWidget {
  final ChargeLog charge;
  final VoidCallback? onDelete;

  const _ChargeTimelineCard({
    required this.charge,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = switch (charge.locationType) {
      '수퍼차저' => TeslaColors.teslaRed,
      '집밥(완속)' => TeslaColors.batteryGreen,
      '회사(완속)' => TeslaColors.electricBlue,
      '공용급속' => TeslaColors.purpleAccent,
      _ => TeslaColors.warningAmber,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.ev_station_rounded,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[충전] ${charge.locationType}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: TeslaColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '+${charge.addedEnergyKwh} kWh (${charge.startSoc}% → ${charge.endSoc}%) · 단가 ${charge.unitPriceKrw}원',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TeslaColors.batteryGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    UnitConverter.formatDateTime(charge.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: TeslaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  UnitConverter.formatKrw(charge.totalCostKrw),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TeslaColors.textPrimary,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: TeslaColors.textMuted,
                      ),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTimelineCard extends StatelessWidget {
  final ExpenseLog expense;
  final VoidCallback? onDelete;

  const _ExpenseTimelineCard({
    required this.expense,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TeslaColors.warningAmber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: TeslaColors.warningAmber,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '[${expense.category}] ${expense.memo}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TeslaColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    UnitConverter.formatDateTime(expense.date),
                    style: const TextStyle(
                      fontSize: 11,
                      color: TeslaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  UnitConverter.formatKrw(expense.amountKrw),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TeslaColors.warningAmber,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: TeslaColors.textMuted,
                      ),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 수기 충전 / 일반 지출 빠른 입력 모달 시트
class _QuickEntryBottomSheet extends ConsumerStatefulWidget {
  final List<ChargePreset> presets;
  final ChargePreset? initialPreset;

  const _QuickEntryBottomSheet({
    required this.presets,
    this.initialPreset,
  });

  @override
  ConsumerState<_QuickEntryBottomSheet> createState() =>
      _QuickEntryBottomSheetState();
}

class _QuickEntryBottomSheetState
    extends ConsumerState<_QuickEntryBottomSheet> {
  bool _isChargeMode = true;

  // 충전 입력 컨트롤러
  late String _selectedLocationType;
  late TextEditingController _addedKwhCtrl;
  late TextEditingController _unitPriceCtrl;
  late TextEditingController _totalCostCtrl;
  late TextEditingController _startSocCtrl;
  late TextEditingController _endSocCtrl;

  // 일반 지출 입력 컨트롤러
  String _selectedExpenseCategory = ExpenseLog.categories.first;
  final TextEditingController _expenseAmountCtrl =
      TextEditingController(text: '25000');
  final TextEditingController _expenseMemoCtrl =
      TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    final preset = widget.initialPreset ?? widget.presets.first;
    _selectedLocationType = preset.locationType;
    _addedKwhCtrl = TextEditingController(text: '35.0');
    _unitPriceCtrl =
        TextEditingController(text: preset.unitPriceKrw.toString());
    _totalCostCtrl = TextEditingController(
      text: (35.0 * preset.unitPriceKrw).round().toString(),
    );
    _startSocCtrl = TextEditingController(text: '30');
    _endSocCtrl = TextEditingController(text: '80');

    _addedKwhCtrl.addListener(_recalculateTotalCost);
    _unitPriceCtrl.addListener(_recalculateTotalCost);
  }

  void _recalculateTotalCost() {
    final kwh = double.tryParse(_addedKwhCtrl.text) ?? 0.0;
    final unitPrice = int.tryParse(_unitPriceCtrl.text) ?? 0;
    final total = (kwh * unitPrice).round();
    _totalCostCtrl.text = total.toString();
  }

  void _applyPreset(ChargePreset preset) {
    setState(() {
      _selectedLocationType = preset.locationType;
      _unitPriceCtrl.text = preset.unitPriceKrw.toString();
      _recalculateTotalCost();
    });
  }

  @override
  void dispose() {
    _addedKwhCtrl.dispose();
    _unitPriceCtrl.dispose();
    _totalCostCtrl.dispose();
    _startSocCtrl.dispose();
    _endSocCtrl.dispose();
    _expenseAmountCtrl.dispose();
    _expenseMemoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '차계부 & 충전 빠른 입력',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('충전 기록')),
                  ButtonSegment(value: false, label: Text('일반 지출')),
                ],
                selected: {_isChargeMode},
                onSelectionChanged: (s) {
                  setState(() => _isChargeMode = s.first);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_isChargeMode) ...[
              const Text(
                '충전 단가 프리셋 선택 (자동 요금 계산)',
                style: TextStyle(
                  fontSize: 12,
                  color: TeslaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.presets.map((p) {
                  final isSelected = _selectedLocationType == p.locationType;
                  return ChoiceChip(
                    label: Text('${p.locationType} (${p.unitPriceKrw}원)'),
                    selected: isSelected,
                    onSelected: (_) => _applyPreset(p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addedKwhCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '충전량 (kWh)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unitPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'kWh당 단가 (원)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _totalCostCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '총 충전요금 (자동계산, 원)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _startSocCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '시작 SoC%'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endSocCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '종료 SoC%'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final kwh = double.tryParse(_addedKwhCtrl.text) ?? 0.0;
                    if (kwh <= 0) return;
                    final unitPrice = int.tryParse(_unitPriceCtrl.text) ?? 250;
                    final totalCost = int.tryParse(_totalCostCtrl.text) ??
                        (kwh * unitPrice).round();
                    final sSoc = int.tryParse(_startSocCtrl.text) ?? 20;
                    final eSoc = int.tryParse(_endSocCtrl.text) ?? 80;

                    await ref.read(teslaAppProvider.notifier).addChargeLog(
                          ChargeLog(
                            date: DateTime.now(),
                            locationType: _selectedLocationType,
                            addedEnergyKwh: kwh,
                            unitPriceKrw: unitPrice,
                            totalCostKrw: totalCost,
                            startSoc: sSoc,
                            endSoc: eSoc,
                          ),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('충전 기록 및 차계부 저장'),
                ),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedExpenseCategory,
                decoration: const InputDecoration(labelText: '지출 카테고리'),
                items: ExpenseLog.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedExpenseCategory = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expenseAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '지출 금액 (원)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expenseMemoCtrl,
                decoration: const InputDecoration(
                  labelText: '메모 (예: 판교 노터치 세차, 고속도로 통행료 등)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(_expenseAmountCtrl.text) ?? 0;
                    if (amount <= 0) return;
                    final memo = _expenseMemoCtrl.text.trim().isEmpty
                        ? '$_selectedExpenseCategory 지출'
                        : _expenseMemoCtrl.text.trim();

                    await ref.read(teslaAppProvider.notifier).addExpenseLog(
                          ExpenseLog(
                            date: DateTime.now(),
                            category: _selectedExpenseCategory,
                            amountKrw: amount,
                            memo: memo,
                          ),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('지출 내역 저장'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
