import 'package:flutter/material.dart';
import 'package:jaarama_core/jaarama_core.dart';

/// Données fictives du mode démo. Aucun restaurant ni client réel.
/// Remplacées par les données Supabase quand le projet sera branché.

class DemoProfile {
  const DemoProfile({
    required this.customerId,
    required this.firstName,
    required this.phone,
    required this.qrSecretHex,
  });

  final String customerId;
  final String firstName;
  final String phone;
  final String qrSecretHex;

  List<int> get qrSecret => hexToBytes(qrSecretHex);
}

class DemoReward {
  const DemoReward(this.name, this.cost);

  final String name;
  final int cost;
}

class DemoEntry {
  const DemoEntry(this.at, this.delta, this.label);

  final DateTime at;
  final int delta;
  final String label;
}

class DemoCard {
  const DemoCard({
    required this.restaurant,
    required this.tagline,
    required this.initials,
    required this.color,
    required this.rewards,
    required this.history,
  });

  final String restaurant;
  final String tagline;
  final String initials;
  final Color color;
  final List<DemoReward> rewards;
  final List<DemoEntry> history;

  int get balance => history.fold(0, (sum, e) => sum + e.delta);

  int get visits => history.where((e) => e.delta > 0).length;

  /// Première récompense pas encore atteinte, ou null si toutes le sont.
  DemoReward? get nextReward {
    final locked = rewards.where((r) => r.cost > balance).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    return locked.isEmpty ? null : locked.first;
  }

  int get unlockedCount => rewards.where((r) => r.cost <= balance).length;
}

const demoProfile = DemoProfile(
  customerId: '5f1c2a9e-8d3b-4c7a-9e21-3b6d0f4a7c18',
  firstName: 'Moussa',
  phone: '+221770000101',
  qrSecretHex:
      '9c4e1f7a2b8d0e6c3a5f9b1d7e2c4a8f6b0d3e9a1c5f7b2e8d4a6c0f3b9e1d5a',
);

List<DemoCard> buildDemoCards() {
  final now = DateTime.now();
  DateTime ago(int days, [int hour = 13]) =>
      DateTime(now.year, now.month, now.day - days, hour, 20);

  return [
    DemoCard(
      restaurant: 'Chez Fatou',
      tagline: 'Cuisine sénégalaise',
      initials: 'CF',
      color: const Color(0xFF0B6E4F),
      rewards: const [
        DemoReward('Bissap offert', 3),
        DemoReward('Dessert offert', 6),
        DemoReward('Thiéboudienne offerte', 10),
      ],
      history: [
        DemoEntry(ago(27), 1, 'Passage'),
        DemoEntry(ago(21), 1, 'Passage'),
        DemoEntry(ago(18), 1, 'Passage'),
        DemoEntry(ago(14, 20), -3, 'Bissap offert'),
        DemoEntry(ago(12), 1, 'Passage'),
        DemoEntry(ago(9), 1, 'Passage'),
        DemoEntry(ago(6), 1, 'Passage'),
        DemoEntry(ago(3), 1, 'Passage'),
        DemoEntry(ago(1), 1, 'Passage'),
      ],
    ),
    DemoCard(
      restaurant: 'Le Baobab Café',
      tagline: 'Café et petit-déjeuner',
      initials: 'BC',
      color: const Color(0xFF8A4B1F),
      rewards: const [
        DemoReward('Café touba offert', 5),
        DemoReward('Petit-déjeuner offert', 12),
      ],
      history: [
        DemoEntry(ago(10, 8), 1, 'Passage'),
        DemoEntry(ago(8, 8), 1, 'Passage'),
        DemoEntry(ago(7, 9), 1, 'Passage'),
        DemoEntry(ago(4, 8), 1, 'Passage'),
        DemoEntry(ago(2, 8), 1, 'Passage'),
      ],
    ),
    DemoCard(
      restaurant: 'Teranga Grill',
      tagline: 'Grillades',
      initials: 'TG',
      color: const Color(0xFF7A1F3D),
      rewards: const [
        DemoReward('Boisson offerte', 4),
        DemoReward('Brochettes offertes', 8),
      ],
      history: [
        DemoEntry(ago(5, 21), 1, 'Passage'),
      ],
    ),
  ];
}
