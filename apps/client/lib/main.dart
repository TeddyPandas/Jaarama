import 'package:flutter/material.dart';

void main() => runApp(const JaaramaClientApp());

/// Application client : portefeuille de cartes, QR, récompenses.
///
/// Écrans prévus (voir docs/architecture.md) :
/// connexion par numéro → portefeuille → détail d'une carte → QR plein écran.
class JaaramaClientApp extends StatelessWidget {
  const JaaramaClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaarama',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0B6E4F)),
      home: const WalletScreen(),
    );
  }
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes cartes')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune carte pour l\'instant.\n'
            'Présentez votre QR au comptoir d\'un restaurant partenaire.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
