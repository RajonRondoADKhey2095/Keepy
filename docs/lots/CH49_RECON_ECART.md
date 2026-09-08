# CH49 — Recon pure : écart staging / main (8 septembre 2026)

Recon git seule, sans implémentation, sans merge, sans fichier de gameplay
touché. Objectif : établir l'état réel de l'écart entre `origin/staging` et
`origin/main`, sur la base d'un brief antérieur qui annonçait 71 fichiers
main-only issus de V7b/V8/CH29/CH30/CH31.

## Point de divergence

`git merge-base origin/staging origin/main` = `89366a56325931d6907d88e83b3b8ec6ec9b6229`
— « docs: promotion journal entry and INDEX.md status for palier 2
(V7b/V8/CH29/CH30/CH31) », 2026-09-06 13:21:49. C'est très exactement le
commit de journal qui clôt la promotion palier 2 documentée dans le
tableau d'historique de `CLAUDE.md` (6 sept 2026). **Les cinq lots
V7b/V8/CH29/CH30/CH31 ne sont donc PAS en attente de promotion : ils sont
déjà communs aux deux branches**, à la racine de la comparaison.

## Ce que le brief précédent supposait, et ce que la mesure montre

Le brief supposait 71 fichiers présents sur `main` et absents de `staging`.
Mesuré ce jour : **`origin/main` n'a qu'UN SEUL commit et UN SEUL fichier
en avance sur le merge-base** — `.github/workflows/vercel-storage-audit.yml`
(commit `08229cc`), un workflow CI `workflow_dispatch` en lecture seule.
Le message de ce commit se documente lui-même intégralement : cherry-pick
délibéré d'un seul fichier depuis `claude/vercel-deployment-purge-t3dudc`,
autorisé explicitement par Mathieu, aucun fichier de jeu touché. **Ce n'est
ni un squash ni une PR jamais redescendue** — c'est un geste ponctuel et
documenté, sans rapport avec les 71 fichiers annoncés.

Conclusion : soit le brief précédent décrivait un état antérieur à la
promotion palier 2 du 6 septembre (auquel cas la mesure d'aujourd'hui l'a
rendu obsolète), soit sa prémisse était fausse dès l'origine. Impossible de
trancher laquelle depuis l'historique disponible — **non établi** — mais
l'état ACTUEL, lui, est mesuré avec certitude : main-only = 1 fichier CI.

## Ce que staging a et main n'a pas

91 commits, 75 fichiers, +17941/-217 lignes depuis le merge-base. Couvre
les chantiers CH32 à CH48 (fiabilité sondes, voilier CH33, multi-altitude
CH35, surface CH37, montagne/relief CH38-40, luge CH41, marche arrière
CH42-43, minimap CH44 puis CH46-48). Répartition : 17 fichiers `docs/`,
19 sondes `scripts/dev/`, 34 scripts gameplay hors dev, 9 scènes `.tscn`,
2 `assets/`, 1 CI (`web-build.yml`, sparse-checkout de `assets_source/`),
plus `CLAUDE.md`.

## Cas dangereux (fichier modifié des deux côtés)

**Liste vide.** Le seul fichier main-only (`vercel-storage-audit.yml`)
n'apparaît dans aucun des 75 fichiers touchés côté staging (vérifié par
`comm -12` sur les deux listes triées). Aucun fichier n'a divergé de façon
concurrente depuis le merge-base.

## Recommandation (non exécutée)

Le merge-base contient déjà toute l'histoire commune utile ; main n'ajoute
qu'un fichier CI isolé, sans recoupement avec le travail staging. Un
`git merge --no-ff origin/staging` depuis `main` n'a donc, sur la seule
base de cette mesure, aucun conflit textuel attendu. Reste gaté par la
doctrine palier 2 (`CLAUDE.md`) : autorisation explicite de Mathieu après
validation device sur `keepy-staging.vercel.app`, non contournable ici.
Un rebase n'a pas d'utilité (aucune réécriture d'historique nécessaire,
et interdite sur une branche partagée). Un cherry-pick fichier par fichier
des « 71 fichiers » n'a plus d'objet : il n'y en a qu'un.
