import 'package:jaarama_core/jaarama_core.dart';
import 'package:test/test.dart';

void main() {
  // Vecteurs calculés avec private.qr_signature() dans PostgreSQL :
  // le QR généré par l'application doit être accepté par la base.
  final secret = hexToBytes(
      '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
  const customerId = '11111111-2222-3333-4444-555555555555';

  group('QrToken.signature', () {
    test('identique à la base, fenêtre 59000000', () {
      expect(QrToken.signature(secret, customerId, 59000000),
          '4a7468cb1c4d3d17dfa7');
    });

    test('identique à la base, fenêtre 59000001', () {
      expect(QrToken.signature(secret, customerId, 59000001),
          '91e6d71a417efa2949f9');
    });

    test('insensible à la casse de l\'identifiant', () {
      expect(QrToken.signature(secret, customerId.toUpperCase(), 59000000),
          '4a7468cb1c4d3d17dfa7');
    });
  });

  group('QrToken.build', () {
    test('assemble préfixe, client, fenêtre et signature', () {
      final at = DateTime.fromMillisecondsSinceEpoch(59000000 * 30 * 1000 + 12000,
          isUtc: true);
      expect(QrToken.build(customerId: customerId, secret: secret, at: at),
          'JRM1.$customerId.59000000.4a7468cb1c4d3d17dfa7');
    });

    test('change toutes les 30 secondes', () {
      final t0 = DateTime.utc(2026, 11, 16, 12, 0, 0);
      expect(QrToken.stepAt(t0.add(const Duration(seconds: 29))), QrToken.stepAt(t0));
      expect(QrToken.stepAt(t0.add(const Duration(seconds: 30))), QrToken.stepAt(t0) + 1);
    });

    test('compte à rebours', () {
      final t0 = DateTime.utc(2026, 11, 16, 12, 0, 10);
      expect(QrToken.remaining(t0), const Duration(seconds: 20));
    });
  });

  test('hexToBytes refuse une longueur impaire', () {
    expect(() => hexToBytes('abc'), throwsFormatException);
  });
}
