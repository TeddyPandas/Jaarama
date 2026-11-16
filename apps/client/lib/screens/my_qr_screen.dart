import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jaarama_core/jaarama_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../demo/demo_data.dart';

/// QR à présenter au comptoir. Il est recalculé sur le téléphone toutes les
/// 30 secondes, sans réseau, avec le même algorithme que la base.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key, required this.profile});

  final DemoProfile profile;

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = QrToken.build(
      customerId: widget.profile.customerId,
      secret: widget.profile.qrSecret,
      at: _now,
    );
    final remaining = QrToken.remaining(_now).inSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon QR')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                widget.profile.firstName,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Présentez cet écran au caissier',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: token,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: remaining / QrToken.stepSeconds,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Nouveau code dans $remaining s',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text(
                'Fonctionne sans connexion. Une capture d\'écran ne sert '
                'à rien : le code change toutes les 30 secondes et ne '
                'crédite qu\'une fois.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
