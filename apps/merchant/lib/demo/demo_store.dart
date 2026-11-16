import 'package:flutter/foundation.dart';
import 'package:jaarama_core/jaarama_core.dart';

/// État en mémoire du mode démo. Reproduit les règles de la base
/// (plafond journalier, numéros sénégalais, solde suffisant) sans serveur.
/// Sera remplacé par les appels aux fonctions Supabase.

class DemoCustomer {
  DemoCustomer({
    required this.firstName,
    required this.phone,
    required this.hasApp,
    this.balance = 0,
    this.visits = 0,
    this.lastVisit,
  });

  String? firstName;
  final String phone;
  final bool hasApp;
  int balance;
  int visits;
  DateTime? lastVisit;

  String get displayName => firstName ?? 'Client';

  /// « +221 77 *** ** 01 », comme renvoyé par restaurant_customers().
  String get maskedPhone {
    final d = phone.replaceAll('+', '');
    return '+${d.substring(0, 3)} ${d.substring(3, 5)} *** ** ${d.substring(10, 12)}';
  }
}

class DemoReward {
  DemoReward(this.name, this.cost, {this.active = true});

  String name;
  int cost;
  bool active;
}

class CreditOutcome {
  const CreditOutcome.success(this.customer, {this.isNewCustomer = false})
      : error = null;
  const CreditOutcome.failure(this.error, [this.customer])
      : isNewCustomer = false;

  final DemoCustomer? customer;
  final JaaramaError? error;
  final bool isNewCustomer;

  bool get ok => error == null;
}

class DemoStore extends ChangeNotifier {
  DemoStore() {
    _seed();
  }

  final String restaurantName = 'Chez Fatou';
  final int pointsPerVisit = 1;
  final int maxVisitsPerDay = 1;

  final List<DemoCustomer> customers = [];
  final List<DemoReward> rewards = [];
  final Map<DemoCustomer, int> _visitsToday = {};
  int newCustomersToday = 0;
  int redemptionsToday = 0;

  int get visitsToday => _visitsToday.values.fold(0, (a, b) => a + b);

  List<DemoCustomer> get customersWithApp =>
      customers.where((c) => c.hasApp).toList();

  List<DemoReward> availableRewards(DemoCustomer c) =>
      rewards.where((r) => r.active && r.cost <= c.balance).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost));

  void _seed() {
    final now = DateTime.now();
    DateTime ago(int days) => now.subtract(Duration(days: days, hours: 2));

    customers
      ..clear()
      ..addAll([
        DemoCustomer(firstName: 'Moussa', phone: '+221770000101', hasApp: true,
            balance: 5, visits: 8, lastVisit: ago(1)),
        DemoCustomer(firstName: 'Aïssatou', phone: '+221760000214', hasApp: true,
            balance: 9, visits: 12, lastVisit: ago(3)),
        DemoCustomer(firstName: 'Ibrahima', phone: '+221780000327', hasApp: true,
            balance: 2, visits: 2, lastVisit: ago(6)),
        DemoCustomer(firstName: 'Awa', phone: '+221770000103', hasApp: false,
            balance: 3, visits: 3, lastVisit: ago(2)),
        DemoCustomer(firstName: null, phone: '+221750000488', hasApp: false,
            balance: 1, visits: 1, lastVisit: ago(9)),
      ]);
    rewards
      ..clear()
      ..addAll([
        DemoReward('Bissap offert', 3),
        DemoReward('Dessert offert', 6),
        DemoReward('Thiéboudienne offerte', 10),
      ]);
    _visitsToday.clear();
    newCustomersToday = 0;
    redemptionsToday = 0;
  }

  void reset() {
    _seed();
    notifyListeners();
  }

  /// Crédite un passage, comme credit_visit().
  CreditOutcome credit(DemoCustomer c, {bool isNewCustomer = false}) {
    final today = _visitsToday[c] ?? 0;
    if (today >= maxVisitsPerDay) {
      return CreditOutcome.failure(JaaramaError.dailyLimitReached, c);
    }
    _visitsToday[c] = today + 1;
    c
      ..balance += pointsPerVisit
      ..visits += 1
      ..lastVisit = DateTime.now();
    notifyListeners();
    return CreditOutcome.success(c, isNewCustomer: isNewCustomer);
  }

  /// Inscrit si besoin puis crédite, comme register_customer() + credit_visit().
  CreditOutcome creditByPhone(String input, String? firstName) {
    final phone = normalizeSenegalPhone(input);
    if (phone == null) {
      return const CreditOutcome.failure(JaaramaError.invalidPhone);
    }
    var isNew = false;
    var customer = _findByPhone(phone);
    if (customer == null) {
      final name = firstName?.trim();
      customer = DemoCustomer(
        firstName: (name == null || name.isEmpty) ? null : name,
        phone: phone,
        hasApp: false,
      );
      customers.add(customer);
      newCustomersToday += 1;
      isNew = true;
    }
    return credit(customer, isNewCustomer: isNew);
  }

  DemoCustomer? _findByPhone(String phone) {
    for (final c in customers) {
      if (c.phone == phone) return c;
    }
    return null;
  }

  /// Échange une récompense, comme redeem_reward().
  JaaramaError? redeem(DemoCustomer c, DemoReward reward) {
    if (!reward.active) return JaaramaError.rewardNotFound;
    if (c.balance < reward.cost) return JaaramaError.insufficientPoints;
    c.balance -= reward.cost;
    redemptionsToday += 1;
    notifyListeners();
    return null;
  }

  void addReward(String name, int cost) {
    rewards.add(DemoReward(name, cost));
    rewards.sort((a, b) => a.cost.compareTo(b.cost));
    notifyListeners();
  }

  void setRewardActive(DemoReward reward, bool active) {
    reward.active = active;
    notifyListeners();
  }
}
