import 'dart:convert';

import 'package:crypto/crypto.dart';

/// QR affiché par l'application client et vérifié par la base
/// (`private.verify_qr`).
///
/// Format : `JRM1.<customer_id>.<step>.<signature>`
/// - `step` : numéro de la fenêtre de 30 s depuis l'époque Unix ;
/// - `signature` : HMAC-SHA256 de `"<customer_id>:<step>"` avec le secret du
///   client, tronqué à 20 caractères hexadécimaux.
///
/// Le calcul ne demande pas de réseau : le QR s'affiche même hors connexion.
/// Toute modification doit être reportée dans
/// `supabase/migrations/*_init.sql` (`private.qr_signature`).
abstract final class QrToken {
  static const String prefix = 'JRM1';
  static const int stepSeconds = 30;

  /// Fenêtre de 30 s contenant [time].
  static int stepAt(DateTime time) =>
      time.toUtc().millisecondsSinceEpoch ~/ (stepSeconds * 1000);

  /// Signature d'une fenêtre pour un client.
  static String signature(List<int> secret, String customerId, int step) {
    final message = utf8.encode('${customerId.toLowerCase()}:$step');
    return Hmac(sha256, secret).convert(message).toString().substring(0, 20);
  }

  /// QR à afficher à l'instant [at].
  static String build({
    required String customerId,
    required List<int> secret,
    required DateTime at,
  }) {
    final step = stepAt(at);
    final id = customerId.toLowerCase();
    return '$prefix.$id.$step.${signature(secret, id, step)}';
  }

  /// Temps restant avant le renouvellement du QR, pour le compte à rebours.
  static Duration remaining(DateTime at) {
    final ms = at.toUtc().millisecondsSinceEpoch % (stepSeconds * 1000);
    return Duration(milliseconds: stepSeconds * 1000 - ms);
  }
}

/// Convertit le secret renvoyé par `claim_customer_profile` (hexadécimal).
List<int> hexToBytes(String hex) {
  if (hex.length.isOdd) {
    throw const FormatException('Longueur hexadécimale impaire');
  }
  return [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];
}
