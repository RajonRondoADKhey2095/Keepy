# Carte blanche — qualité visuelle de l'environnement (journal)

Branche jetable `claude/carte-blanche-cozy-02o8dm`, jamais mergée. Append seulement.

## Ouverture

- **Base** : `a05ceba` (`origin/main` HEAD au 5 sept 2026 00:30 UTC, arbre `3e3f1a2`, byte-identique).
- **Preview** : `https://keepy-cozy.vercel.app` (alias dédié posé par le workflow sur cette branche ; ni `keepy-staging` ni `keepy-ten` touchés). Preuve de déploiement : voir checkpoint 0.
- **Blender** : en cours (timebox 15 min, verdict au checkpoint 0).
- **Palette** : choix au checkpoint 0, après lecture de CH11/CH22.

## Checkpoint 0 — déploiement preview

- Le workflow `web-build.yml` ne déclenchait que sur `main` et `staging`. Ajouté sur cette branche : déclencheur `push` sur `claude/carte-blanche-cozy-02o8dm` et un step de déploiement preview qui réutilise les secrets existants et pose l'alias `keepy-cozy.vercel.app` (même mécanisme que staging).
- Ce commit ne contient aucun changement de jeu : il sert uniquement à prouver la chaîne build → deploy → alias.
