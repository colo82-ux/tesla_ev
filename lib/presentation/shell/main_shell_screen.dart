import 'package:flutter/material.dart';
import '../../core/theme/tesla_theme.dart';
import '../../core/utils/responsive_layout.dart';
import '../efficiency/efficiency_screen.dart';
import '../home/home_screen.dart';
import '../ledger/ledger_screen.dart';
import '../settings/settings_screen.dart';

/// 4개 핵심 탭을 담는 메인 쉘 화면
/// - 스마트폰(기본): 하단 Bottom NavigationBar (4탭)
/// - 갤럭시 폴드 펼침/태블릿 대화면(>=600dp): 좌측 NavigationRail 반응형 전환
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    EfficiencyScreen(),
    LedgerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isFoldUnfolded = ResponsiveLayout.isFoldUnfolded(context);

    if (isFoldUnfolded) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                setState(() => _currentIndex = idx);
              },
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TeslaColors.teslaRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.electric_car_rounded,
                        color: TeslaColors.teslaRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '테슬라_ev',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: TeslaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.speed_outlined),
                  selectedIcon: Icon(Icons.speed_rounded),
                  label: Text('대시보드'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: Text('전비 분석'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: Text('차계부&충전'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.build_circle_outlined),
                  selectedIcon: Icon(Icons.build_circle_rounded),
                  label: Text('소모품&설정'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: TeslaColors.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed_rounded),
              label: '대시보드',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: '전비 분석',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: '차계부&충전',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_circle_outlined),
              selectedIcon: Icon(Icons.build_circle_rounded),
              label: '소모품&설정',
            ),
          ],
        ),
      ),
    );
  }
}
