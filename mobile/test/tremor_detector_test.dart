import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/motion_processor.dart';

void main() {
  test('brief shake does not confirm tremor', () {
    final det = TremorDetector(sustainedMinMs: 2000);
    var t = DateTime(2026, 1, 1);

    for (var i = 0; i < 30; i++) {
      det.onAvm(45, t);
      t = t.add(const Duration(milliseconds: 50));
    }
    expect(det.tremorConfirmed, isFalse);

    t = t.add(const Duration(milliseconds: 600));
    det.onAvm(5, t);
    expect(det.tremorConfirmed, isFalse);
  });

  test('sustained shake confirms tremor', () {
    final det = TremorDetector(sustainedMinMs: 2000);
    var t = DateTime(2026, 1, 1);

    for (var i = 0; i < 50; i++) {
      det.onAvm(48, t);
      t = t.add(const Duration(milliseconds: 50));
    }

    expect(det.tremorConfirmed, isTrue);
    expect(det.sustainedMs, greaterThanOrEqualTo(2000));
  });
}
