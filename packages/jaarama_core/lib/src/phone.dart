/// Normalise un numéro mobile sénégalais au format `+2217XXXXXXXX`.
///
/// Même règle que `public.normalize_phone_sn` côté base : accepte
/// « 77 123 45 67 », « 221771234567 », « +221 77... » et « 00221... ».
/// Renvoie `null` si le numéro n'est pas un mobile sénégalais.
String? normalizeSenegalPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.length == 9) digits = '221$digits';
  if (!RegExp(r'^2217[0-9]{8}$').hasMatch(digits)) return null;
  return '+$digits';
}

/// Affichage lisible : `+221 77 123 45 67`.
String formatSenegalPhone(String normalized) {
  final d = normalized.replaceAll('+', '');
  if (d.length != 12) return normalized;
  return '+${d.substring(0, 3)} ${d.substring(3, 5)} ${d.substring(5, 8)} '
      '${d.substring(8, 10)} ${d.substring(10, 12)}';
}
