import 'package:flutter/material.dart';

import '../demo/demo_store.dart';

/// Écran du caissier : identifier le client, créditer, échanger.
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key, required this.store});

  final DemoStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.restaurantName),
        actions: [
          IconButton(
            tooltip: 'Réinitialiser la démo',
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              store.reset();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Démo réinitialisée')),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DemoNotice(),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(label: 'Passages', value: store.visitsToday),
                const SizedBox(width: 8),
                _Stat(label: 'Nouveaux', value: store.newCustomersToday),
                const SizedBox(width: 8),
                _Stat(label: 'Échanges', value: store.redemptionsToday),
              ],
            ),
            const SizedBox(height: 4),
            Text("Aujourd'hui", style: theme.textTheme.bodySmall),
            const SizedBox(height: 28),
            SizedBox(
              height: 64,
              child: FilledButton.icon(
                onPressed: () => _simulateScan(context),
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text('Scanner le QR du client',
                    style: TextStyle(fontSize: 17)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _enterPhone(context),
                icon: const Icon(Icons.dialpad),
                label: const Text('Client sans application : saisir son numéro'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Règle : ${store.pointsPerVisit} point par passage, '
              '${store.maxVisitsPerDay} passage crédité par client et par jour.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// En démo, la caméra est remplacée par le choix du client au comptoir.
  Future<void> _simulateScan(BuildContext context) async {
    final customer = await showModalBottomSheet<DemoCustomer>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Simulation du scan'),
              subtitle: Text(
                  'Qui présente son QR ? La vraie version ouvrira la caméra.'),
            ),
            for (final c in store.customersWithApp)
              ListTile(
                leading: CircleAvatar(child: Text(c.displayName[0])),
                title: Text(c.displayName),
                subtitle: Text('${c.balance} points'),
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
    if (customer == null || !context.mounted) return;
    await _showOutcome(context, store.credit(customer));
  }

  Future<void> _enterPhone(BuildContext context) async {
    final phone = TextEditingController();
    final name = TextEditingController();
    String? error;

    final outcome = await showDialog<CreditOutcome>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Numéro du client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro',
                  hintText: '77 123 45 67',
                  prefixText: '+221 ',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Prénom (si nouveau client)',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Essayez 77 000 01 03 (Awa, cliente existante) '
                'ou un numéro inconnu pour une inscription.',
                style: TextStyle(fontSize: 12),
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
                final result = store.creditByPhone(phone.text, name.text);
                if (result.error != null && result.customer == null) {
                  setState(() => error = result.error!.message);
                  return;
                }
                Navigator.of(context).pop(result);
              },
              child: const Text('Créditer'),
            ),
          ],
        ),
      ),
    );
    if (outcome == null || !context.mounted) return;
    await _showOutcome(context, outcome);
  }

  Future<void> _showOutcome(BuildContext context, CreditOutcome outcome) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => _OutcomeBody(store: store, outcome: outcome),
          ),
        ),
      ),
    );
  }
}

class _OutcomeBody extends StatelessWidget {
  const _OutcomeBody({required this.store, required this.outcome});

  final DemoStore store;
  final CreditOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = outcome.customer;

    if (!outcome.ok) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 56, color: scheme.error),
          const SizedBox(height: 12),
          if (c != null)
            Text(c.displayName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(outcome.error!.message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          if (c != null) ..._rewardSection(context, c),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, size: 56, color: scheme.primary),
        const SizedBox(height: 12),
        Text(c!.displayName, style: theme.textTheme.titleLarge),
        if (outcome.isNewCustomer)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Nouveau client inscrit',
                style: TextStyle(color: scheme.primary)),
          ),
        const SizedBox(height: 8),
        Text('+${store.pointsPerVisit} point',
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
        Text('Solde : ${c.balance} points'),
        const SizedBox(height: 20),
        ..._rewardSection(context, c),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Terminé'),
        ),
      ],
    );
  }

  List<Widget> _rewardSection(BuildContext context, DemoCustomer c) {
    final available = store.availableRewards(c);
    if (available.isEmpty) return const [];
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text('Récompenses disponibles',
            style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final r in available)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.redeem),
          title: Text(r.name),
          subtitle: Text('${r.cost} points'),
          trailing: OutlinedButton(
            onPressed: () {
              final error = store.redeem(c, r);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(error?.message ??
                    '${r.name} pour ${c.displayName}. Solde : ${c.balance}'),
              ));
            },
            child: const Text('Échanger'),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text('$value', style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mode démo : clients fictifs, rien n\'est envoyé.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
