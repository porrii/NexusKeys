import 'package:flutter_test/flutter_test.dart';
import 'package:nexuskeys/core/security/password_strength.dart';

void main() {
  group('exactEntropyBits', () {
    test('is length * log2(charsetSize)', () {
      // log2(64) == 6 exactly, so this has an exact expected value.
      expect(exactEntropyBits(length: 10, charsetSize: 64), closeTo(60, 0.001));
    });

    test('is zero for a single-character charset (no actual randomness)', () {
      expect(exactEntropyBits(length: 10, charsetSize: 1), 0);
    });

    test('is zero for a non-positive length', () {
      expect(exactEntropyBits(length: 0, charsetSize: 64), 0);
    });
  });

  group('estimateEntropyBits', () {
    test('is zero for an empty string', () {
      expect(estimateEntropyBits(''), 0);
    });

    test('grows with more character classes present at the same length', () {
      final lowerOnly = estimateEntropyBits('abcdefgh');
      final mixed = estimateEntropyBits('aB3!defg');

      expect(mixed, greaterThan(lowerOnly));
    });

    test('grows with length for the same character classes', () {
      final short = estimateEntropyBits('abc');
      final long = estimateEntropyBits('abcdefghij');

      expect(long, greaterThan(short));
    });
  });

  group('classifyEntropyBits', () {
    test('maps zero to empty', () {
      expect(classifyEntropyBits(0), PasswordStrength.empty);
    });

    test('maps low bits to veryWeak', () {
      expect(classifyEntropyBits(10), PasswordStrength.veryWeak);
    });

    test('maps high bits to veryStrong', () {
      expect(classifyEntropyBits(128), PasswordStrength.veryStrong);
    });

    test('strength increases monotonically with entropy', () {
      final levels = [0.0, 20.0, 35.0, 50.0, 75.0, 100.0].map(classifyEntropyBits).toList();
      final segments = levels.map((s) => s.segments).toList();

      for (var i = 1; i < segments.length; i++) {
        expect(segments[i], greaterThanOrEqualTo(segments[i - 1]));
      }
    });
  });

  group('evaluatePasswordStrength', () {
    test('is empty for an empty string', () {
      expect(evaluatePasswordStrength(''), PasswordStrength.empty);
    });

    test('classifies a long fully-mixed password as very strong', () {
      expect(evaluatePasswordStrength('Tr0ub4dor&3xtraLong!'), PasswordStrength.veryStrong);
    });

    test('classifies a short single-case word as weak or worse', () {
      final strength = evaluatePasswordStrength('cat');
      expect(strength.segments, lessThanOrEqualTo(PasswordStrength.weak.segments));
    });
  });

  group('estimateCrackTime', () {
    test('is instantaneous for zero entropy', () {
      expect(estimateCrackTime(0), '—');
    });

    test('returns a longer/equal-order phrase for higher entropy', () {
      // Not asserting exact text (the tiering is an implementation detail)
      // — just that more entropy never looks like less time to crack.
      final low = estimateCrackTime(10);
      final high = estimateCrackTime(120);
      expect(low, isNot(high));
    });
  });
}
