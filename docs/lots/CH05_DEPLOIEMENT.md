# Déploiement — paliers staging/main, CI, API périmées

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 3 section(s), 143 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

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

**Règle d'usage — DEUX PALIERS, et un seul des deux est gaté** :

- **Palier 1 — feature branch → `staging` : AUTOMATIQUE PAR DÉFAUT, aucune
  autorisation à demander.** Dès qu'un lot est techniquement valide (build
  et export headless verts, sondes gatées vertes), la session merge sur
  `staging` et pousse, **sans attendre ni solliciter la permission de
  Mathieu**. `staging` est un bac à sable : son unique fonction est de
  rendre un lot jouable sur `keepy-staging.vercel.app`, une erreur y est
  peu coûteuse et se corrige par un commit de plus.
  **Le seul gate de ce palier est TECHNIQUE, jamais humain** — un lot dont
  le build casse ou dont une sonde gatée rougit ne part pas sur `staging`,
  et c'est le seul motif recevable pour ne pas merger.
- **Palier 2 — `staging` → `main` : GATÉ, sans exception.** Seule une
  autorisation explicite de Mathieu, donnée **après validation device sur
  `keepy-staging.vercel.app`**, fait passer du code sur `main` — un push
  sur `main` est une mise en production immédiate. Les deux règles de
  l'incident du 29 juillet 2026 (jamais de push direct sur `main`, jamais
  de fast-forward depuis `staging`) restent intégralement en vigueur ici.

⚠️ **CLARIFICATION D'UNE AMBIGUÏTÉ RÉELLE (12 août 2026), pas un changement
de politique.** L'intention d'origine de ce paragraphe a toujours été
« staging se merge librement », mais sa formulation (« peut pousser… sans
validation préalable ») décrivait une PERMISSION plutôt qu'un DÉFAUT — et
une session récente l'a lue comme « il est autorisé de demander », donc a
attendu un feu vert explicite avant de merger un lot pourtant vert. Le
texte ci-dessus lève l'ambiguïté : sur `staging`, merger n'est pas une
option offerte à la session, c'est **l'étape terminale normale d'un lot
valide**. Demander la permission pour ce palier est un défaut de process,
au même titre que merger sur `main` sans l'avoir demandée.

## ⚠️ L'API GitHub Actions sert des états d'étape PÉRIMÉS — lire `completed_at`, jamais l'état brut

**Règle permanente, identifiée plusieurs fois avant d'être enfin écrite ici
(12 août 2026).** Un poll de l'API GitHub Actions peut rendre `status:
"in_progress"` sur une étape — voire sur un job entier — **plusieurs dizaines
de minutes après que le job soit réellement terminé**. Ce n'est pas un job
bloqué, c'est une lecture périmée : le champ `status` d'une réponse d'API
n'est pas une observation en temps réel.

**Le seul champ digne de foi est `completed_at`** (et son frère `conclusion`).
S'il est renseigné, l'étape EST finie, quoi que dise `status`. S'il est `null`
ET que `started_at` est vieux de plusieurs minutes, alors seulement la
question « est-ce bloqué ? » se pose.

**Pourquoi ça compte ici et pas seulement en théorie** : ce repo a une CI de
~3 minutes qui déploie en production, et un merge de prod en déclenche deux
(le merge puis le commit de doc). Conclure « le job est bloqué » sur un
`status` périmé mène à exactement les deux mauvaises réactions : relancer un
workflow qui tourne déjà (donc deux déploiements concurrents sur la même
cible), ou déclarer un lot en échec alors qu'il est vert. C'est la même
famille d'erreur que la fenêtre de 404 documentée plus haut — **ne jamais
lire un état de CI ou de déploiement sans regarder son horodatage**.

Corollaire pratique : pour attendre une CI, poller `completed_at`/`conclusion`
dans une boucle qui sort sur l'un des DEUX terminaux (`success` ET `failure`),
jamais une boucle qui n'attend que le succès — le silence d'un poll ne
distingue pas « toujours en cours » de « échoué ».

**Observation du 13 août 2026 (lot découplage ENEMY/AIR_ENEMY), reproduite en
direct : le run #105 a terminé à 14:59:10 (`conclusion: success`), et TROIS
polls successifs après cette heure ont continué de renvoyer `in_progress`,
avec une réponse byte-identique à chaque fois** — y compris l'étape « Import
project resources » figée à `in_progress` alors qu'elle s'était terminée à
14:58:38. C'est exactement le mode de panne décrit ci-dessus, observé sans
ambiguïté plutôt que déduit.

⚠️ **Ce qui a débloqué la lecture : passer `workflow_jobs_filter:
{"filter": "latest"}` à `list_workflow_jobs`.** L'appel SANS ce paramètre
servait le cache périmé ; l'appel AVEC a rendu l'état réel et complet
immédiatement. **Corrélation observée UNE fois, pas une causalité prouvée** —
le temps qui passe et l'expiration naturelle du cache sont une explication
concurrente qui n'a pas été écartée. À essayer en premier quand un poll semble
figé, avant de conclure quoi que ce soit sur l'état du job ; ça ne coûte rien
et, si ça ne suffit pas, la règle `completed_at` reste seule juge.

## ⚠️ L'API VERCEL AUSSI SERT DES RÉPONSES PÉRIMÉES SUR LE STATUT D'UN DÉPLOIEMENT — même famille que GitHub Actions ci-dessus (17 août 2026)

**Pas seulement le dashboard web : l'API Vercel elle-même.** Un poll fait
juste après qu'un run CI se soit terminé (`conclusion: success`, déploiement
déjà en place) a rendu un statut « encore en cours » pendant **~25 minutes**
de plus, alors que le déploiement était déjà terminé et servait déjà le
trafic. Même mode de panne que la section GitHub Actions juste au-dessus :
un champ de statut d'API n'est pas une observation en temps réel, c'est une
lecture potentiellement mise en cache en amont.

**Conséquence pratique, identique à la règle GitHub Actions** : **un seul
poll à `status`/état « completed » ne suffit PAS comme preuve de fraîcheur**,
et **un seul appel API ne suffit pas non plus** — l'API peut être aussi
périmée que le dashboard qu'elle est censée remplacer. Avant de conclure
qu'un déploiement est fini, en échec, ou encore en cours à partir d'un appel
Vercel, recouper avec un second signal indépendant (un nouvel appel après un
délai, ou une preuve côté site réellement servi — fingerprint
`GODOT_CONFIG.fileSizes`, `x-vercel-cache`, horodatage `last-modified` —
comme déjà pratiqué ailleurs dans ce fichier pour vérifier un fingerprint de
prod). Ne jamais traiter un unique `status=completed` (ou son équivalent
Vercel) comme une preuve suffisante à lui seul — le corollaire GitHub Actions
ci-dessus (« ne jamais lire un état de CI ou de déploiement sans regarder son
horodatage ») s'applique donc aussi aux réponses de l'API Vercel, pas
seulement à celles de GitHub Actions.

