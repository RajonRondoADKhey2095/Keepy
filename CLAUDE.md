# Keepy — CLAUDE.md

## Une seule session agentique à la fois sur ce repo

**Ne jamais lancer deux sessions agentiques concurrentes sur ce repo — data
hazard. Incident déjà survenu le 6 août 2026.**

Ce qui s'est passé : deux sessions ont reçu la même demande (créer ce
fichier) et ont poussé sur `main` un `CLAUDE.md` quasi-identique à ~40
secondes d'intervalle (`4e02d46` à 14:16:43, puis un commit local au message
strictement identique à 14:17:23). Résolu sans casse — la seconde session a
constaté la collision au `push` rejeté, comparé les deux versions, et
abandonné son doublon au lieu de forcer par-dessus.

Pourquoi c'est un hasard et pas un simple désagrément : deux sessions ne
partagent aucun état, ni working tree ni connaissance de ce que l'autre a
déjà poussé. Elles se marchent dessus **à travers `origin`**. Les modes de
défaillance vont bien au-delà du doublon observé ici : un `push --force`
qui écrase le travail de l'autre, deux features qui divergent sur le même
fichier, ou une session qui valide (build, sondes) un arbre que l'autre a
déjà rendu obsolète — ce dernier cas étant le pire, parce qu'il produit un
rapport de validation vert sur du code qui n'est plus celui de `main`.

Règle : une session agentique à la fois. Si un doute existe sur une session
encore active, vérifier avant de coder (`git fetch` + comparer `origin/main`
à sa propre base, `git branch -r` pour des branches récentes non mergées).

Règle permanente, sans exception, pour tout rapport de fin de tâche ou de
batch produit dans ce repo :

1. **Fence à 4 backticks, toujours.** Le rapport de fin de tâche doit
   toujours être fourni dans un seul bloc de code Markdown enveloppé par un
   fence à 4 backticks, pour permettre la copie en un tap sur iPhone. Le
   rapport reste un bloc unique, jamais paginé en plusieurs messages ni
   plusieurs blocs. Cette règle est permanente, sans exception.
2. **Structure fixe**, dans cet ordre : BRANCH, COMMITS, FILES, BUILD,
   DEPLOY, VALIDATION CHECKLIST, NEXT STEPS, DOCS STATUS.
3. **UN SEUL bloc Markdown, toujours — la pagination est INTERDITE, sans
   exception.** Jamais plusieurs blocs séquentiels (jamais de
   `## Rapport (1/N)`, `(2/N)`, ...). Si le contenu naturel dépasse
   ~100 lignes, CONDENSER ou RÉSUMER pour rester dans un seul bloc — la
   contrainte "un seul bloc" prime sur l'exhaustivité du détail. Le rapport
   doit rester copiable en un seul tap sur iPhone.
4. **Vérification avant envoi.** Avant d'envoyer, relire la réponse : si le
   rapport n'est pas enveloppé dans un fence à 4 backticks, ajouter ce
   wrapper ; si elle dépasse ~100 lignes ou contient plusieurs blocs
   séquentiels, condenser jusqu'à tenir dans un seul bloc. Confirmer en une
   ligne à la fin qu'on a fait cette vérification.
5. **S'applique à chaque tâche sans exception**, y compris quand on
   redemande une reformulation d'un résultat déjà produit (pas de relance
   de recherche dans ce cas).

## Déploiement staging (validation avant merge main)

**Depuis le 8 août 2026**, une branche permanente `staging` existe en plus
de `main`. Elle a son propre déploiement Vercel, sur son propre alias
stable :

- **`https://keepy-staging.vercel.app`** — build jouable de `staging`.
- `https://keepy-ten.vercel.app` reste la prod, alimentée uniquement par
  `main`, comportement inchangé.

**Pourquoi** : avant ce chantier, `main` était le seul déclencheur de build
web CI (`.github/workflows/web-build.yml`), donc aucune feature branch ne
pouvait être validée visuellement (device/navigateur) sans passer par
`main`. `staging` sert d'étape intermédiaire — merger une feature branch
dans `staging` la rend jouable sur `keepy-staging.vercel.app` sans toucher
à la prod.

**Mécanique** : `.github/workflows/web-build.yml` déclenche désormais sur
push vers `main` OU `staging`. Le job de build Godot (import + export
web) est strictement identique dans les deux cas — seule la dernière étape
diverge, en deux steps distincts et clairement labellisés dans les logs
Actions (`[PRODUCTION -- main]` / `[STAGING -- staging]`) pour qu'un échec
de l'un ne soit jamais confondu avec un échec de l'autre :
- `main` → `vercel deploy build/web --prod` (inchangé, alias prod déjà
  attaché au projet Vercel).
- `staging` → `vercel deploy build/web` (déploiement preview, URL
  jetable) puis `vercel alias set <url> keepy-staging.vercel.app` — pour
  que l'URL de staging reste stable d'un push à l'autre, exactement comme
  la prod ne change pas d'URL à chaque déploiement.

**Note recon (8 août 2026)** : le projet Vercel `keepy` a par ailleurs
l'intégration GitHub native active en parallèle (confirmé via l'API
Vercel — `source: "git"` sur les déploiements de branche) : elle crée
automatiquement une preview par branche poussée (alias du type
`keepy-git-<branche>-....vercel.app`). **Ces previews sont mortes** :
Vercel n'a aucune notion du build Godot (pas de `package.json`, aucune
commande de build détectée), donc elles servent le dépôt brut tel quel —
il n'y a pas d'`index.html` à la racine du repo (généré uniquement sous
`build/web/` par la CI), donc ces URLs renvoient systématiquement 404.
Ne pas confondre une de ces URLs `keepy-git-...` avec `keepy-staging.
vercel.app` : seule cette dernière est pilotée par la CI et sert un
build réellement jouable.

**Règle d'usage** :
- **Claude Code peut pousser directement sur `staging`** (créer la
  branche si besoin, merger des feature branches dedans, push), sans
  validation préalable de Mathieu — c'est l'environnement de test, une
  erreur y est peu coûteuse.
- **Claude Code ne merge/push JAMAIS sur `main` sans validation
  explicite de Mathieu.** Le flux normal reste : feature branch →
  `staging` (validation device sur `keepy-staging.vercel.app`) → une fois
  validé, PR/merge vers `main` sur demande explicite.

## Incident résolu : `vercel alias set` "Not able to load user (404)" (8 août 2026)

**Symptôme** : le step `Deploy to Vercel [STAGING]` échouait de façon
identique 5 fois d'affilée sur `vercel alias set ... -T "$VERCEL_ORG_ID"`
(et ses variantes `--scope <slug>` / `--scope <team_id>` testées avant),
toujours avec `Not able to load user (404)`, alors que `vercel deploy`
juste avant réussissait sans problème avec le même token.

**Cause réelle** : le `VERCEL_TOKEN` utilisé était scope **équipe**
(`keepy`). `vercel deploy` s'appuie sur `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID`
pour résoudre le contexte projet sans jamais appeler `/user`, donc il
passait. `vercel alias set`, lui, résout systématiquement l'identité via
un appel `/user` avant d'agir — quel que soit le flag de scope fourni
(`--scope` slug, `--scope` team ID, `-T` team ID) — et ce token équipe
n'avait pas de compte utilisateur associé exploitable par cet appel,
d'où le 404 constant. Aucune combinaison de flags CLI ne pouvait
contourner ça : le problème était le *type* de token, pas sa syntaxe
d'invocation.

**Solution qui a fonctionné** : régénérer un `VERCEL_TOKEN` scope
**compte personnel** (`rajonrondoadkhey2095's projects`, pas team
`keepy`) et le mettre à jour dans le secret GitHub — code CI inchangé
(`-T "$VERCEL_ORG_ID"`). Confirmé sur le run #44 (workflow_dispatch,
commit `759a371`) : `vercel deploy` → preview OK, puis `vercel alias set`
→ `Success! https://keepy-staging.vercel.app now points to
https://keepy-lpisx5c3p-rajonrondoadkhey2095s-projects.vercel.app`.
Fetch direct de `keepy-staging.vercel.app` confirmé HTTP 200, contenu =
export web Godot réel (`<title>Keepy</title>`, canvas, `index.js`,
`GODOT_CONFIG` avec `index.pck`/`index.wasm`), pas une 404 Vercel.

**À retenir pour une session future** : si `vercel alias set` échoue à
nouveau avec `Not able to load user`, vérifier en priorité le **scope du
token** (personnel vs équipe) avant de retoucher les flags CLI — c'est
la variable qui a réellement résolu l'incident, pas `-T` vs `--scope`.
