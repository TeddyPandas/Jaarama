import 'package:flutter/material.dart';

void main() => runApp(const JaaramaMerchantApp());

/// Application marchand : caissier (scan, crédit, échange) et gérant
/// (récompenses, équipe, clients).
///
/// Écrans prévus (voir docs/architecture.md) :
/// connexion → choix du restaurant → scan → confirmation ; espace gérant.
class JaaramaMerchantApp extends StatelessWidget {
  const JaaramaMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaarama Pro',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF0B6E4F)),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créditer un client')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner le QR du client'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.phone),
              label: const Text('Saisir son numéro'),
            ),
          ],
        ),
      ),
    );
  }
}
