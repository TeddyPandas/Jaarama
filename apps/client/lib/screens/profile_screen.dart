import 'package:flutter/material.dart';
import 'package:jaarama_core/jaarama_core.dart';

import '../demo/demo_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final DemoProfile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _promotions = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Prénom'),
            subtitle: Text(widget.profile.firstName),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Numéro'),
            subtitle: Text(formatSenegalPhone(widget.profile.phone)),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: const Text('Recevoir les promotions'),
            subtitle: const Text(
                'Les restaurants dont vous avez la carte peuvent vous écrire.'),
            value: _promotions,
            onChanged: (v) => setState(() => _promotions = v),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(
              'Supprimer mes données',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Désactivé en mode démo.'),
            enabled: false,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Jaarama · version de démonstration\n'
              'Aucune donnée ne quitte ce téléphone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
