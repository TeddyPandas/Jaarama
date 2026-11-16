# Identité visuelle Jaarama

Logo validé le 16/11/2026 : le J formé de deux bras qui se serrent la main, motif tissé sur le crochet, cœur, QR, étoiles et points. Les fichiers vectoriels sont retracés fidèlement à partir de l'original (`source/logo-original.jpg`).

**Règle** : le logo ne contient que le J et le nom « Jaarama ». La signature **« La fidélité qui dit merci »** n'en fait plus partie ; elle est affichée dans l'application (écran d'accueil, à propos) et peut accompagner le logo dans la communication.

## Fichiers

| Fichier | Usage |
| --- | --- |
| `logo/svg/jaarama-logo.svg` | Logo : le J et le nom, fond transparent |
| `logo/svg/jaarama-logo-fond-creme.svg` | Logo sur fond crème |
| `logo/svg/jaarama-symbole.svg` | Le J seul |
| `logo/svg/jaarama-nom.svg` | Le nom seul |
| `logo/svg/jaarama-icone.svg`, `jaarama-icone-blanc.svg` | Icône d'application, fond crème ou blanc (l'OS arrondit les coins) |
| `logo/svg/jaarama-adaptive-foreground.svg` | Premier plan de l'icône adaptative Android, fond `#FDF3E5` |
| `logo/png/` | Icônes 1024, 512, 192, 96, 48 px ; logos en 2140 px de large |
| `jaarama-ouverture.gif` | Aperçu de l'animation d'ouverture de l'application |

Les vidéos sont dans `videos/` :

| Vidéo | Format | Usage |
| --- | --- | --- |
| `jaarama-intro-16x9.mp4` | 1280×720, 10 s, avec musique | Présentation, YouTube, écran |
| `jaarama-carre-1080.mp4` | 1080×1080, 10 s | Publications Instagram, Facebook |
| `jaarama-vertical-1080x1920.mp4` | 1080×1920, 10 s, signature en fin | Statuts WhatsApp, stories, TikTok |
| `jaarama-ouverture-1080x1920.mp4` | 1080×1920, 2,6 s, sans son | Référence de l'animation d'ouverture de l'application |

Les vidéos réutilisent le début d'une animation générée (bol, tourbillon, J qui sort) jusqu'à 3,1 s, puis passent sur le logo vectoriel : à la fin, exactement les éléments du logo, sans doublons.

## Couleurs

| Nom | Hex | Usage |
| --- | --- | --- |
| Vert | `#226A68` | Barre du J |
| Vert texte | `#20504B` | Nom, titres, texte |
| Or | `#CD9F30` | Bras du haut, accents |
| Terracotta | `#B95426` | Bras du bas, accents |
| Crème | `#FDF3E5` | Fonds |

Police d'interface proposée : Nunito (Google Fonts, licence libre), à valider.

## Animation d'ouverture dans l'application

Le fichier vidéo sert de référence. Dans l'application, recréer le mouvement en Flutter à partir des couches SVG : le J entre (0 à 0,8 s), les éléments du décor apparaissent du centre vers l'extérieur (0,6 à 1,2 s), puis le nom monte (1,05 à 1,65 s).

## Limites connues

- Le relief de l'original est rendu par paliers de couleur : très agrandi (enseigne, grande affiche), les bandes se voient. Faire lisser le fichier par un graphiste pour ces usages.
- À 48 px, le cœur et le QR ne se lisent plus. Une icône simplifiée pourra être dessinée si besoin.
