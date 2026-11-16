# Décisions

## Prises

| Date | Décision | Raison |
| --- | --- | --- |
| 2026-11-15 | Marché initial : Dakar, restaurants | Choix du porteur de projet |
| 2026-11-15 | Application mobile dédiée, Flutter, Android et iOS | Une base de code ; iOS pèse 20 à 30 % du trafic mobile au Sénégal |
| 2026-11-15 | Le caissier scanne le téléphone du client | Empêche le client de se créditer seul |
| 2026-11-16 | Supabase (PostgreSQL) comme backend | Registre transactionnel, droits par ligne, authentification par téléphone |
| 2026-11-16 | Logique de points dans la base, pas dans les applications | Impossible à contourner depuis un appareil modifié |
| 2026-11-16 | Registre en ajout seul, solde calculé | Traçabilité complète, corrections visibles |
| 2026-11-16 | Un QR par client, valable dans tous les restaurants | Un seul écran à montrer ; la carte est créée au premier scan |
| 2026-11-16 | Pas de points contre avis Google | Interdit par les règles de Google |
| 2026-11-16 | Logo validé : le J aux mains qui se serrent, avec motif, cœur et étoiles ; version vectorielle retracée | Choix du porteur de projet |
| 2026-11-16 | La signature « La fidélité qui dit merci » est retirée du logo et sera affichée dans l'application (écran d'accueil, à propos) | Logo plus compact ; la phrase reste visible dans l'usage |

## Hypothèses retenues par défaut, en attente de validation

Chacune est un réglage, pas un choix figé dans le code.

| Sujet | Valeur par défaut | Où la changer |
| --- | --- | --- |
| Règle de points | 1 point par passage, sans montant | `restaurants.points_per_visit` |
| Plafond journalier | 1 passage par client et par jour | `restaurants.max_visits_per_day` |
| Délai hors ligne | 24 heures | `restaurants.max_offline_hours` |
| Inscription sans application | Autorisée, par numéro | `register_customer` |
| Création des restaurants et des propriétaires | Par l'administrateur de la plateforme | Console Supabase |

## Ouvertes

1. Modèle économique : qui paie, combien, comment.
2. Appareil du caissier : téléphone personnel ou fourni par le restaurant.
3. Durée de validité des points.
4. Échange par numéro : faut-il un code SMS de confirmation au client ?
5. Effacement d'un client : l'historique du restaurant disparaît aussi. Faut-il plutôt anonymiser ?
6. Fournisseur de SMS pour les codes de connexion.
7. Région d'hébergement Supabase et formalités auprès de la CDP.
8. Structure juridique, nécessaire aux stores et à l'encaissement.
