import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import '../widgets/demo_banner.dart';
import '../widgets/loyalty_card_tile.dart';
import 'card_detail_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.cards, required this.onShowQr});

  final List<DemoCard> cards;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour ${demoProfile.firstName}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const DemoBanner(),
          const SizedBox(height: 16),
          Text('${cards.length} cartes de fidélité',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final card in cards) ...[
            LoyaltyCardTile(
              card: card,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CardDetailScreen(card: card),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onShowQr,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Montrer mon QR au comptoir'),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre QR est le même dans tous les restaurants. '
            'Une nouvelle carte se crée au premier passage.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
