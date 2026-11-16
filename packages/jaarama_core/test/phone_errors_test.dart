import 'package:jaarama_core/jaarama_core.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeSenegalPhone', () {
    for (final input in [
      '77 123 45 67',
      '771234567',
      '221771234567',
      '+221 77-123-45-67',
      '00221771234567',
    ]) {
      test('accepte « $input »', () {
        expect(normalizeSenegalPhone(input), '+221771234567');
      });
    }

    for (final input in ['33 820 00 00', '7712', '', '+33 6 12 34 56 78']) {
      test('refuse « $input »', () {
        expect(normalizeSenegalPhone(input), isNull);
      });
    }
  });

  test('formatSenegalPhone', () {
    expect(formatSenegalPhone('+221771234567'), '+221 77 123 45 67');
  });

  group('JaaramaError', () {
    test('retrouve un code connu', () {
      expect(JaaramaError.fromCode('daily_limit_reached'),
          JaaramaError.dailyLimitReached);
    });

    test('code inconnu → erreur générique, retentable', () {
      final e = JaaramaError.fromCode('timeout');
      expect(e, JaaramaError.unknown);
      expect(e.isRetryable, isTrue);
    });

    test('erreur métier non retentable', () {
      expect(JaaramaError.qrAlreadyUsed.isRetryable, isFalse);
    });
  });
}
