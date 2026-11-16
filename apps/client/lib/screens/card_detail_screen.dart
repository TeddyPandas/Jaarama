import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import '../widgets/loyalty_card_tile.dart';

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({super.key, required this.card});

  final DemoCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = [...card.history]..sort((a, b) => b.at.compareTo(a.at));

    return Scaffold(
      appBar: AppBar(title: Text(card.restaurant)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoyaltyCardTile(card: card),
          const SizedBox(height: 24),
          Text('Récompenses', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Montrez votre QR au caissier pour échanger vos points.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final reward in card.rewards)
            _RewardRow(reward: reward, balance: card.balance, color: card.color),
          const SizedBox(height: 24),
          Text('Historique · ${card.visits} passages',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in history) _HistoryRow(entry: entry),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.reward,
    required this.balance,
    required this.color,
  });

  final DemoReward reward;
  final int balance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final unlocked = balance >= reward.cost;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          unlocked ? Icons.redeem : Icons.lock_outline,
          color: unlocked ? color : Theme.of(context).disabledColor,
        ),
        title: Text(reward.name),
        subtitle: Text(unlocked
            ? 'Disponible'
            : 'Encore ${reward.cost - balance} points'),
        trailing: Text(
          '${reward.cost} pts',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final DemoEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.delta > 0;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            positive ? scheme.primaryContainer : scheme.secondaryContainer,
        child: Icon(
          positive ? Icons.add : Icons.redeem,
          color: positive
              ? scheme.onPrimaryContainer
              : scheme.onSecondaryContainer,
        ),
      ),
      title: Text(entry.label),
      subtitle: Text(formatDay(entry.at)),
      trailing: Text(
        positive ? '+${entry.delta}' : '${entry.delta}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: positive ? scheme.primary : scheme.secondary,
        ),
      ),
    );
  }
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// « 12 novembre à 13h20 », sans dépendre d'un package de dates.
String formatDay(DateTime d) {
  final minutes = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} à ${d.hour}h$minutes';
}
