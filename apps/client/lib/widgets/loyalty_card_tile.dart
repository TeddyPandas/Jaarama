import 'package:flutter/material.dart';

import '../demo/demo_data.dart';

/// Carte de fidélité aux couleurs du restaurant.
class LoyaltyCardTile extends StatelessWidget {
  const LoyaltyCardTile({super.key, required this.card, this.onTap});

  final DemoCard card;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final next = card.nextReward;
    final progress = next == null ? 1.0 : card.balance / next.cost;

    return Material(
      color: card.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RestaurantAvatar(card: card),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.restaurant,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          card.tagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${card.balance}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      Text(
                        card.balance > 1 ? 'points' : 'point',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                next == null
                    ? 'Toutes les récompenses sont disponibles'
                    : 'Encore ${next.cost - card.balance} pour : ${next.name}',
                style: const TextStyle(color: Colors.white),
              ),
              if (card.unlockedCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    card.unlockedCount > 1
                        ? '${card.unlockedCount} récompenses disponibles'
                        : '1 récompense disponible',
                    style: TextStyle(
                      color: card.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille aux initiales, en attendant les logos des restaurants.
class RestaurantAvatar extends StatelessWidget {
  const RestaurantAvatar({super.key, required this.card, this.size = 44});

  final DemoCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Text(
        card.initials,
        style: TextStyle(
          color: card.color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
