/// Codes d'erreur renvoyés par les fonctions de la base.
///
/// Les fonctions lèvent des exceptions dont le message est un code stable ;
/// les applications les traduisent ici, en un seul endroit.
enum JaaramaError {
  forbidden('forbidden', 'Vous n\'avez pas les droits pour cette action.'),
  dailyLimitReached('daily_limit_reached',
      'Ce client a déjà été crédité aujourd\'hui.'),
  qrAlreadyUsed('qr_already_used',
      'Ce QR a déjà été utilisé. Demandez au client de rafraîchir son écran.'),
  qrExpired('qr_expired',
      'QR expiré. Vérifiez l\'heure du téléphone du client et réessayez.'),
  invalidQr('invalid_qr', 'QR non reconnu.'),
  customerNotFound('customer_not_found',
      'Aucun client avec ce numéro. Inscrivez-le d\'abord.'),
  cardNotFound('card_not_found', 'Ce client n\'a pas de carte dans ce restaurant.'),
  insufficientPoints('insufficient_points',
      'Points insuffisants pour cette récompense.'),
  rewardNotFound('reward_not_found', 'Récompense introuvable ou désactivée.'),
  occurredAtOutOfRange('occurred_at_out_of_range',
      'Opération trop ancienne pour être synchronisée, ou heure de l\'appareil incorrecte.'),
  invalidPhone('invalid_phone', 'Numéro de téléphone invalide.'),
  userNotFound('user_not_found',
      'Cette personne doit d\'abord créer son compte dans l\'application marchand.'),
  phoneAlreadyLinked('phone_already_linked',
      'Ce numéro est déjà relié à un autre compte.'),
  clientOpIdConflict('client_op_id_conflict',
      'Conflit d\'opération. Réessayez.'),
  unknown('unknown', 'Une erreur est survenue. Réessayez.');

  const JaaramaError(this.code, this.message);

  /// Code renvoyé par la base.
  final String code;

  /// Message à afficher, en français.
  final String message;

  /// Retrouve l'erreur à partir du message d'exception de la base.
  static JaaramaError fromCode(String? code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return unknown;
  }

  /// L'opération peut-elle être retentée plus tard depuis la file hors ligne ?
  /// Les erreurs métier sont définitives ; seules les erreurs inconnues
  /// (réseau, serveur) justifient un nouvel essai.
  bool get isRetryable => this == unknown;
}
