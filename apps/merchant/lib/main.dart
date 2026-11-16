import 'package:flutter/material.dart';

import 'demo/demo_store.dart';
import 'screens/counter_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/rewards_screen.dart';

void main() => runApp(const JaaramaMerchantApp());

const brandGreen = Color(0xFF0B6E4F);

/// État partagé du mode démo.
final store = DemoStore();

/// Application marchand : caissier (scan, crédit, échange) et gérant
/// (clients, récompenses). Version de démonstration, sans serveur.
class JaaramaMerchantApp extends StatelessWidget {
  const JaaramaMerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaarama Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: brandGreen),
      home: const MerchantShell(),
    );
  }
}

class MerchantShell extends StatefulWidget {
  const MerchantShell({super.key});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      CounterScreen(store: store),
      CustomersScreen(store: store),
      RewardsScreen(store: store),
    ];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Comptoir',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.redeem_outlined),
            selectedIcon: Icon(Icons.redeem),
            label: 'Récompenses',
          ),
        ],
      ),
    );
  }
}
