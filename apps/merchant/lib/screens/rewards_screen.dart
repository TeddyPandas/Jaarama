import 'package:flutter/material.dart';

import '../demo/demo_store.dart';

/// Récompenses du restaurant, gérées par le propriétaire ou le gérant.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, required this.store});

  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Récompenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addReward(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            for (final r in store.rewards)
              SwitchListTile(
                secondary: const Icon(Icons.redeem),
                title: Text(r.name),
                subtitle: Text('${r.cost} points'
                    '${r.active ? '' : ' · désactivée'}'),
                value: r.active,
                onChanged: (v) => store.setRewardActive(r, v),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReward(BuildContext context) async {
    final name = TextEditingController();
    final cost = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouvelle récompense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cost,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Points nécessaires',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final points = int.tryParse(cost.text.trim());
                if (name.text.trim().isEmpty || points == null || points <= 0) {
                  setState(() => error = 'Nom et nombre de points requis');
                  return;
                }
                store.addReward(name.text.trim(), points);
                Navigator.of(context).pop();
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
