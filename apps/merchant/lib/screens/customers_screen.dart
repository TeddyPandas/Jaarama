import 'package:flutter/material.dart';

import '../demo/demo_store.dart';

/// Liste des clients pour le gérant. Numéros masqués, comme côté base.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key, required this.store});

  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = [...store.customers]..sort((a, b) {
              final da = a.lastVisit, db = b.lastVisit;
              if (da == null) return 1;
              if (db == null) return -1;
              return db.compareTo(da);
            });
          return ListView.separated(
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return ListTile(
                  title: Text('${list.length} clients'),
                  subtitle: Text(
                    '${list.where((c) => c.hasApp).length} avec l\'application',
                  ),
                );
              }
              final c = list[i - 1];
              return ListTile(
                leading: CircleAvatar(child: Text(c.displayName[0])),
                title: Row(
                  children: [
                    Flexible(child: Text(c.displayName)),
                    if (c.hasApp) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.smartphone, size: 16),
                    ],
                  ],
                ),
                subtitle: Text('${c.maskedPhone} · ${c.visits} passages\n'
                    'Dernier passage : ${_relative(c.lastVisit)}'),
                isThreeLine: true,
                trailing: Text(
                  '${c.balance} pts',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _relative(DateTime? d) {
  if (d == null) return 'jamais';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final days = today.difference(day).inDays;
  if (days == 0) return "aujourd'hui";
  if (days == 1) return 'hier';
  return 'il y a $days jours';
}
