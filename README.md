# Jaarama

Cartes de fidélité numériques pour les restaurants de Dakar.

Le client présente son téléphone au comptoir, le caissier scanne et crédite un passage. Le client accumule une carte par restaurant dans un seul portefeuille, et échange ses points contre des récompenses. Un client sans smartphone ou sans l'application peut être inscrit avec son seul numéro.

> *Jaarama* : « merci » en pulaar.

## Structure

```
apps/
  client/          Application client (Flutter) : portefeuille, QR, récompenses
  merchant/        Application marchand (Flutter) : scan, crédit, espace gérant
packages/
  jaarama_core/    Dart pur, partagé : jeton QR, numéros, codes d'erreur
supabase/
  migrations/      Schéma, règles d'accès et fonctions métier (PostgreSQL)
  tests/           Tests de la base, exécutables sur un PostgreSQL nu
scripts/
  test-db.sh       Applique les migrations et lance les tests
docs/
  architecture.md  Comment les pièces s'articulent
  decisions.md     Décisions prises et questions ouvertes
```

## État

| Partie | État |
| --- | --- |
| Schéma, règles d'accès, crédit, échange, inscription par numéro | Fait, testé |
| Package partagé : jeton QR, numéros, erreurs | Fait, tests écrits |
| Applications Flutter | Mode démo sur données fictives ; APK publiés automatiquement |
| Connexion à Supabase depuis les applications | À faire |

## Démarrer

### Base de données

Prérequis : un serveur PostgreSQL 15 ou plus.

```bash
PGHOST=localhost PGUSER=postgres PGPASSWORD=... scripts/test-db.sh
```

Pour déployer sur un projet Supabase :

```bash
supabase init          # garde le dossier migrations existant
supabase link --project-ref <ref>
supabase db push
```

Le fichier `supabase/tests/00_supabase_shim.sql` ne sert qu'aux tests locaux : ne jamais l'appliquer sur Supabase.

### Applications

Les dossiers de plateforme (`android/`, `ios/`) ne sont pas versionnés pour l'instant. Pour les générer :

```bash
cd apps/client   && flutter create --platforms=android,ios --org sn.jaarama .
cd apps/merchant && flutter create --platforms=android,ios --org sn.jaarama .
```

`flutter create` ne remplace pas les fichiers existants (`lib/main.dart`, `pubspec.yaml`). Vérifier l'identifiant d'organisation avant la première publication : il ne peut plus changer ensuite.

### Package partagé

```bash
cd packages/jaarama_core && dart pub get && dart test
```

## APK de démonstration

À chaque modification des applications sur `main`, GitHub Actions compile les deux applications en mode démo (données fictives, sans serveur) et les dépose dans la Release [« demo »](https://github.com/TeddyPandas/jaarama/releases/tag/demo), remplacée à chaque fois. Compilation manuelle : onglet Actions, « APK de démonstration », « Run workflow ».

## Intégration continue

GitHub Actions lance à chaque push sur `main` et à chaque pull request : les tests de la base sur PostgreSQL 16, l'analyse et les tests du package partagé, l'analyse des deux applications.
