import 'package:flutter/material.dart';

import 'demo/demo_data.dart';
import 'screens/my_qr_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/wallet_screen.dart';

void main() => runApp(const JaaramaClientApp());

const brandGreen = Color(0xFF0B6E4F);

/// Application client : portefeuille de cartes, QR, récompenses.
/// Version de démonstration : données fictives, aucune connexion au serveur.
class JaaramaClientApp extends StatelessWidget {
  const JaaramaClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jaarama',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: brandGreen),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final cards = buildDemoCards();
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      WalletScreen(cards: cards, onShowQr: () => setState(() => tab = 1)),
      const MyQrScreen(profile: demoProfile),
      const ProfileScreen(profile: demoProfile),
    ];

    return Scaffold(
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wallet_outlined),
            selectedIcon: Icon(Icons.wallet),
            label: 'Mes cartes',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined),
            selectedIcon: Icon(Icons.qr_code_2),
            label: 'Mon QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
