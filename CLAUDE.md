# Jaarama — consignes pour les sessions de travail

- Documentation, commentaires et messages d'erreur affichés : en français.
- Les règles de points vivent dans PostgreSQL (`supabase/migrations`). Les applications appellent les fonctions, elles n'écrivent jamais directement dans `point_entries`.
- Une migration publiée ne se modifie pas : on en ajoute une nouvelle.
- Toute fonction métier nouvelle ou modifiée reçoit des tests dans `supabase/tests`. Lancer `scripts/test-db.sh` avant de pousser.
- Le format du QR est défini deux fois : `private.qr_signature` (SQL) et `QrToken` (Dart). Les modifier ensemble et mettre à jour le vecteur de test commun.
- Les erreurs métier sont des codes stables ; tout nouveau code est ajouté à `JaaramaError`.
- Décisions et questions ouvertes : `docs/decisions.md`.
