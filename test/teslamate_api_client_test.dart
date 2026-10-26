import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TeslaMate HTML 파싱 정규식 검증', () {
    const htmlSample = '''
      <table class="table is-narrow is-fullwidth thead-transparent">
        <tbody style="font-variant-numeric: tabular-nums;">
          <tr>
            <td class="has-text-weight-medium">Status</td>
            <td>
              offline for 5&nbsp;h<span class="duration-extended">,&nbsp;46&nbsp;min</span>
            </td>
          </tr>
          <tr>
            <td class="has-text-weight-medium">Range (rated)</td>
            <td>320.45&nbsp;km</td>
          </tr>
          <tr>
            <td class="has-text-weight-medium">State of Charge</td>
            <td>
              <span class="has-tooltip-top has-tooltip-right-desktop" data-tooltip="≈ 427&nbsp;km at 100%">
                75%
              </span>
            </td>
          </tr>
          <tr>
            <td class="has-text-weight-medium">Mileage</td>
            <td>8838&nbsp;km</td>
          </tr>
        </tbody>
      </table>
    ''';

    test('tooltip의 100%가 아닌 실제 태그 내부의 75%를 정확히 추출한다', () {
      final socMatch = RegExp(
        r'State of Charge[\s\S]*?>\s*(\d+)\s*%\s*<',
        caseSensitive: false,
      ).firstMatch(htmlSample);

      expect(socMatch, isNotNull);
      expect(int.parse(socMatch!.group(1)!), 75);
    });

    test('Mileage에서 8838km를 정확히 추출한다', () {
      final odoMatch = RegExp(
        r'Mileage[\s\S]*?<td>\s*([\d\.,]+)',
        caseSensitive: false,
      ).firstMatch(htmlSample);

      expect(odoMatch, isNotNull);
      expect(double.parse(odoMatch!.group(1)!.replaceAll(',', '')), 8838.0);
    });

    test('Range에서 320.45km를 정확히 추출한다', () {
      final rangeMatch = RegExp(
        r'Range\s*\([^\)]*\)[\s\S]*?<td>\s*([\d\.,]+)',
        caseSensitive: false,
      ).firstMatch(htmlSample);

      expect(rangeMatch, isNotNull);
      expect(double.parse(rangeMatch!.group(1)!.replaceAll(',', '')), 320.45);
    });
  });
}
