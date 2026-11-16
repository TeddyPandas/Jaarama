# Architecture

## Vue d'ensemble

```
Application client ─┐
Application marchand ┼──► Supabase ──► Firebase Cloud Messaging (notifications)
Page web de carte* ──┘    │            Fournisseur SMS (codes de connexion)
                          │            WhatsApp Cloud API* (campagnes)
                          ├─ Authentification par numéro et code
                          ├─ PostgreSQL : registre de points, règles d'accès
                          ├─ Fonctions métier (SQL) et fonctions serveur
                          └─ Stockage : logos des restaurants
* hors MVP
```

Aucune application ne modifie un solde. Elles appellent des fonctions de la base qui vérifient les droits, appliquent les plafonds et écrivent dans le registre.

## Modèle de données

| Table | Rôle |
| --- | --- |
| `restaurants` | Nom, logo, couleur, règles : points par passage, plafond journalier, délai hors ligne |
| `staff` | Lien utilisateur ↔ restaurant, rôle `owner`, `manager` ou `cashier` |
| `customers` | Fiche client par numéro ; `user_id` vide tant que le client n'a pas l'application |
| `cards` | Une carte par couple client–restaurant |
| `point_entries` | Registre en ajout seul : chaque crédit ou débit est une ligne |
| `rewards` | Récompenses proposées par un restaurant |
| `redemptions` | Échanges effectués |
| `marketing_consents` | Consentement du client aux messages promotionnels, par restaurant |
| `card_balances` (vue) | Solde et dernier passage, calculés à la lecture |

Le solde n'est jamais stocké. Une erreur se corrige par une écriture inverse (type `adjustment`, pas encore exposé), jamais par une modification. Un déclencheur refuse toute mise à jour ou suppression du registre, sauf pendant l'effacement d'un compte client.

## Fonctions exposées

| Fonction | Appelant | Effet |
| --- | --- | --- |
| `register_customer(restaurant, phone, first_name)` | Personnel | Inscrit un client par numéro et crée sa carte |
| `credit_visit(restaurant, client_op_id, occurred_at, qr_token \| phone)` | Personnel | Crédite un passage |
| `redeem_reward(restaurant, reward, client_op_id, qr_token \| phone)` | Personnel | Échange des points ; réseau requis |
| `restaurant_customers(restaurant)` | Propriétaire, gérant | Liste des clients, numéros masqués |
| `add_staff_member(restaurant, phone, role)` | Propriétaire | Ajoute un caissier ou un gérant |
| `set_staff_active(restaurant, user, active)` | Propriétaire | Désactive ou réactive un membre |
| `claim_customer_profile(first_name)` | Client connecté | Relie le compte à sa fiche, renvoie le secret du QR |
| `delete_my_customer_data()` | Client connecté | Efface fiche, cartes et historique |

Les erreurs remontent sous forme de codes stables (`forbidden`, `daily_limit_reached`, `qr_expired`…), traduits en français par `JaaramaError` dans le package partagé.

## QR client

Le QR est `JRM1.<customer_id>.<fenêtre>.<signature>` :

- la fenêtre change toutes les 30 secondes ;
- la signature est un HMAC-SHA256 avec un secret propre au client, remis par `claim_customer_profile` ;
- le téléphone du client calcule le QR sans réseau ;
- la base accepte un écart de deux fenêtres (une minute) pour absorber les horloges mal réglées ;
- une même fenêtre ne peut créditer qu'une fois une carte donnée : une capture d'écran est inutile.

Les implémentations SQL (`private.qr_signature`) et Dart (`QrToken`) sont tenues identiques par un vecteur de test commun.

## Hors ligne côté caissier

Chaque crédit porte un `client_op_id` généré par l'appareil et l'heure du scan (`occurred_at`). L'application garde les crédits dans une file locale et les envoie au retour du réseau :

- un renvoi du même `client_op_id` renvoie le résultat déjà enregistré, sans double crédit ;
- un crédit plus vieux que `max_offline_hours` (24 h par défaut) est refusé ;
- une erreur métier (plafond atteint, QR déjà utilisé) est définitive et doit être montrée au caissier ; seules les erreurs réseau sont retentées.

L'échange de récompense exige le réseau, pour ne jamais dépenser des points deux fois.

## Anti-fraude

| Risque | Protection |
| --- | --- |
| Crédits multiples le même jour | Plafond `max_visits_per_day` par carte, heure de Dakar |
| Deux caissiers simultanés | Verrou sur la carte pendant le crédit et l'échange |
| QR partagé ou rejoué | Fenêtre de 30 s, usage unique par carte |
| Caissier qui crédite ses proches par numéro | Plafond journalier ; chaque ligne garde le caissier. Alertes au gérant : à faire |
| Échange par numéro sans le client | **À durcir** : confirmation par code SMS envisagée |
| Lecture des données d'un autre restaurant | Règles d'accès par ligne, testées |
| Lecture du secret QR d'un client | Colonne non lisible ; remise uniquement au titulaire |
