import 'package:flutter/material.dart';

/// 갤럭시 폴드 대화면 및 태블릿 반응형 레이아웃 유틸리티
class ResponsiveLayout {
  ResponsiveLayout._();

  /// 폴드 펼침 화면(Unfolded) 기준 너비 브레이크포인트 (600dp 이상)
  static const double foldableBreakpoint = 600.0;

  /// 와이드 태블릿/데스크톱 기준 브레이크포인트 (900dp 이상)
  static const double wideBreakpoint = 900.0;

  static bool isFoldUnfolded(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= foldableBreakpoint;
  }

  static bool isWideScreen(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= wideBreakpoint;
  }

  /// 화면 너비에 따라 그리드 컬럼 수를 반환합니다.
  static int getGridCrossAxisCount(
    BuildContext context, {
    int phoneCount = 2,
    int foldCount = 4,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= foldableBreakpoint) return foldCount;
    return phoneCount;
  }

  /// 대화면에서 컨텐츠가 지나치게 늘어나는 것을 방지하는 래퍼
  static Widget constrainMaxWidth({
    required Widget child,
    double maxWidth = 1100,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
