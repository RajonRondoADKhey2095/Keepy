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

## État du pipeline assets Meshy

Le pipeline décrit dans `docs/MESHY_SPEC.md` n'est plus au stade de spec :
deux assets réels sont intégrés et validés selon la méthode qu'il documente
(§2, §9-11) :

- **Hibou (pursuer)** — `assets/models/keepy_hibou_pursuer.glb`, installé
  dans `Pursuer/Silhouette` (2026-08-08).
- **Keepy (hero squirrel)** — `assets/models/keepy_squirrel_hero.glb`,
  installé dans `Keepy/MeshInstance3D` (2026-08-09).

Les deux matériaux sont **unlit** (`KHR_materials_unlit` posé à la main dans
le `.glb`, cf §9) — c'est la règle par défaut pour tout asset de ce projet,
pas une particularité du hibou : §8 explique pourquoi seule une surface
unshaded a une couleur *connue* après l'inversion du mode sombre.

**Piège payload, mesuré le 9 août 2026 — à connaître avant d'ajouter un
asset :** `export_presets.cfg` utilise `export_filter="all_resources"`, qui
embarque **toute** ressource du projet dans le build, qu'une scène la
référence ou non. Conséquence : les originaux Meshy bruts d'`assets_source/`
partaient dans le build web — **35,84 Mo de charge morte** téléchargée par
chaque joueur mobile, mesurée sur un arbre identique en ne changeant que le
filtre. Corrigé en ajoutant `assets_source/*` à `exclude_filter` (à côté de
`scripts/dev/*`, qui y était déjà pour la même raison). Le `.pck` est passé
de 43,35 Mo à 4,23 Mo. Corollaire pour le prochain asset : **désactiver un
map à l'import ne réduit rien** — un `.ctex` non référencé est packé quand
même ; pour économiser réellement, il faut retirer le map du `.glb`.

Voir `docs/MESHY_SPEC.md` §11 (Import log) pour les mesures, décisions et
résultats de validation de chaque asset. Le prochain asset à intégrer suit
la même méthode : recon triangle/texture avant import, recompression
Pillow si besoin, orientation vérifiée par rendu offscreen (jamais copiée
d'un asset précédent), scale calculé contre le budget §5/§7, checklist
d'acceptation §10 avant tout push.

## Deux défauts de mesure corrigés (F10, 9 août 2026) — deux décisions de
## teinte EN ATTENTE de Mathieu, aucune action code en cours

`docs/PROBE_AUDIT.md` (F10a/F10b/F10c) documente deux sondes qui mesuraient
autre chose que ce qu'annonçait leur en-tête — `PursuerContrastAudit`
échantillonnait Keepy au lieu du sol, et `StrikeFatalContrastAudit` avait un
fond irreproductible d'une exécution à l'autre (décor non seedé, puis —
cause dominante — le flash plein écran des coups gelé à mi-décroissance).
**Les deux sondes ont été corrigées, re-validées (les 7 sondes bot gated +
AssetContractAudit + ChargerShapeProbe restent byte-identiques au seed
20260806), et poussées sur `claude/f10-measurement-defects-srfh8t`.**

**Ce que la correction a mis au jour — deux vrais défauts de lisibilité,
mesurés proprement, aucun plancher déplacé pour les faire passer :**

- **Pursuer vs sol en `DARK/2` : 2,37:1 contre le plancher 2,5:1.** La
  couleur du pursuer (déjà `0,02, 0,02, 0,03`, noir pur) n'a **aucune marge
  restante** — le sweep qui a servi à calibrer le plancher 2,5 place le
  plafond atteignable en vert à 2,05, en dessous du 2,37 mesuré. Fermer ça
  exige de bouger soit l'albédo du sol, soit `GameState.DARK_TINT_AMOUNT`
  (0,55) — les deux affectent le contraste dark-mode de TOUS les objets de
  gameplay, pas seulement le pursuer. Décrit dans `docs/MESHY_SPEC.md` §8
  (note dédiée, juste après le tableau de palette).
- **Label de frappe fatale en `DARK/5` : 2,99:1 contre le plancher 3,0:1.**
  0,01 sous le seuil, désormais stable d'une exécution à l'autre (avant la
  correction, le fond mesuré incluait un flash blanc plein écran figé à une
  opacité aléatoire — la sonde ne mesurait pas encore fiablement le HUD).

**Aucune des deux ne demande de code ni de nouvelle sonde.** Ce sont des
choix de couleur/teinte réservés à Mathieu — voir `docs/PROBE_AUDIT.md`,
section « Still open after this batch », pour le détail chiffré complet.
Une fois la décision prise, il suffit de re-rouler la sonde concernée
(`PursuerContrastAudit` ou `StrikeFatalContrastAudit`) contre le nouveau
choix — rien d'autre n'a besoin de changer.

## Décor procédural : déjà en prod (correction d'une passation périmée)

**Ce fichier ne mentionnait nulle part le décor, ce qui a laissé croire à une
session ultérieure que le lot décor restait à faire. Il était déjà mergé sur
`main` avant elle.** Vérifié sur `origin/main` (pas déduit d'un récit) : le
lot complet est en place et déployé —

- **Collines de fond** — `scripts/world/Decor.gd`, nœud `World/Decor` dans
  `Game.tscn`, deux couches parallaxe à pool fixe (`6270afc`, recyclage
  corrigé par `2ffc491`).
- **Bordures de voie + variation de teinte du sol** — `TrackSegment.gd`,
  `_build_lane_curbs()` et `_reroll_ground_tint()` (`83ef8e0`).

Les trois sont arrivés en prod par le merge `9dca8fb` (« merge: bring
procedural decor environment to prod »).

**Depuis le 9 août 2026, un quatrième élément s'y ajoute : les props de bord
de piste** (arbres et rochers low-poly), branche `claude/trackside-props`.
Même cycle de vie que les bordures — construits une fois dans `_ready()` de
`TrackSegment`, seulement montrés/cachés et repositionnés par `populate()`,
recyclés avec leur tuile. **Pas** une seconde couche à la `Decor.gd` : un
prop appartient à une TUILE, une colline n'appartient à rien.

Règle qui vaut pour tout ajout de décor futur, et qui est la seule chose
réellement contraignante ici : **aucun prop ne doit empiéter sur la dalle de
6 m** (`Hitboxes.GROUND_SIZE.x`) — la contrainte porte sur le bord de la
SILHOUETTE, pas sur le centre du prop. Détail, table de contraste mesurée et
budget triangles : `docs/MESHY_SPEC.md` §8.2. Sonde dédiée :
`scripts/dev/TrackPropsAudit.tscn`.

⚠️ **Budget triangles §7 : le tableau d'origine n'était PAS une mesure.** La
re-mesure du 9 août 2026 (§7.2) montre la frame **au-dessus** de la cible de
50 000 — ~52 800 props désactivés, donc antérieurement au lot props et sans
rapport avec lui. Cause dominante : les collectibles (`Noisette.tscn` /
`Gland.tscn`) dessinent **4 224** triangles chacun (`SphereMesh` laissé à la
tessellation par défaut de Godot) là où §7 en budgétait 300. Correction
identifiée et chiffrée dans §7.2, **volontairement non faite** — elle touche
la silhouette d'un objet de gameplay **visible** et mérite sa propre revue
device. Ils restent le poste dominant : pire frame mesurée sur 11 runs après
le lot hibou ci-dessous, **57 402**, toujours 7 402 au-dessus de la cible.

⚠️ **« Le hibou pèse 15 518 triangles » est FAUX — corrigé le 9 août 2026
(§7.3). Ne pas repartir de ce chiffre.** Le `.glb` en pèse **7 070**, soit
930 SOUS son plafond de 8 000 ; il n'a jamais été hors budget et **n'a pas
été décimé**. Les 8 448 restants venaient de **deux sphères d'yeux
placeholder** (`SphereMesh` par défaut, 4 224 chacune) enfants de
`Silhouette` — 7 070 + 4 224 + 4 224 = 15 518, exactement le chiffre de §7.2,
qui comparait un total de *famille* à un budget d'*asset*. Décimer le hibou
ne pouvait pas atteindre la cible : même à zéro triangle la famille restait
à 8 448. Corrigé en passant `SphereMesh_Eye` à 16 x 8 : famille **15 518 ->
7 646**, soit **−7 872 triangles à chaque frame**. Les yeux sont sur la face
**-Z** (côté opposé à la caméra, cf. §6) et donc entièrement occultés : les
rendus offscreen avant/après aux trois poses de jeu sont **pixel-identiques**.
Les sept sondes gatées sont **byte-identiques**, 0 collider déplacé, `.pck`
+16 octets.

⚠️ **`PursuerContrastAudit` ÉCHOUE, et échouait déjà sur `origin/main`
intact** (6/6 palettes sombres sous le plancher 2,5:1, pire 1,86:1, contre
2,53:1 PASS enregistré au lot hibou du 8 août). Mesuré 3 fois avant / 3 fois
après le lot du 9 août : identique, donc **ni causé ni corrigé par lui**.
Régression pré-existante **ouverte**, suspect principal non confirmé : la
dérive de teinte du sol par segment (`_reroll_ground_tint`, §8.1), non
seedée, qui change précisément la surface contre laquelle la sonde mesure la
silhouette. C'est la lisibilité en mode sombre du poursuivant — à traiter.

## Sondes : aucune ne peut tourner indéfiniment (mesuré, 9 août 2026)

Toute sonde de `scripts/dev/` est bornée par un budget **temps réel** de
900 s. Au dépassement elle imprime un verdict **INCONCLUSIVE** explicite et
sort en **code 2** — jamais 0 (faux vert), jamais 1 (un timeout n'est pas
une violation de contrat, c'est une absence de verdict).

Deux points d'entrée, parce qu'une sonde a deux formes possibles :

| forme | mécanisme | pourquoi |
|---|---|---|
| itère des frames | `ProbeWatchdog.arm(self, LABEL)` | `_process` tourne entre les frames |
| bloque dans un seul appel | `ProbeWatchdog.deadline(LABEL)` + `abort_if_exceeded()` dans la boucle | aucune frame n'existe, la boucle doit demander elle-même |

**`arm()` seul est MUET sur une sonde bloquante** — mesuré : budget 5 s,
toujours vivante à 25 s. C'était le cas de `DecorParallaxProbe` (2000
itérations dans `_ready()`) et de `PacingProbe` (`--script`, tout dans
`_init()`). Les deux sont corrigées.

`ProbeTimeoutAudit.tscn` **rend la garantie non optionnelle** : il échoue
si une sonde n'arme aucun timeout, ou l'arme après la première instruction
de `_ready()`. Vérifié rouge avant vert. À lancer après toute modification
de `scripts/dev/` — il coûte moins d'une seconde.

⚠️ **Piège d'invocation, à connaître avant de conclure qu'une sonde
plante.** Les flags moteur vont AVANT le `--`, les args applicatifs après :

```
godot4 --headless --fixed-fps 60 --path . res://scripts/dev/X.tscn -- --seed=20260806
```

`--fixed-fps` placé après le `--` est ignoré par le moteur, la simulation
tourne à ~1x le temps réel, et une sonde à 900 s simulés met ~15 minutes —
en-tête affiché puis plus rien. **Symptôme identique à un blocage, cause
totalement différente.** Le watchdog le dit maintenant lui-même : si
l'horloge de run avance encore, il imprime « NOT STUCK, JUST SLOW » et
rappelle l'ordre des flags.

⚠️ **Correction d'une passation périmée : F6 et F7 sont CLOS, mesurés.**
Une passation les décrivait comme ouverts/bloquants. C'est faux, et
`docs/PROBE_AUDIT.md` le documentait déjà comme résolu :

- **F7** — `ChargerAudit` (27 s) et `AirEnemyLandingLaneAudit` (106 s)
  terminent et passent. Les « ~50 minutes sans finir » se reproduisent
  uniquement par l'erreur d'ordre de flags ci-dessus.
- **F6** — `AirHazardAudit` est déterministe : 20 runs à la graine
  20260806, **20/20 exit 0, un seul stdout, un seul stderr** (flux
  capturés séparément).

Base de référence re-validée : les 10 sondes gatées sont **identiques au
bit près** entre `origin/main` et la branche timeout, sur les deux flux.
Il y a **SEPT** sondes-bot gatées, pas six.

## Audio : ne coupe pas l'audio de fond (vérifié sur device, 9 août 2026)

Le projet a reçu son **premier audio** le 9 août 2026 (deux cues one-shot sur
les strikes, `assets/audio/strike_*.wav`, joués depuis `HUD.gd`). Avant ça il
n'y avait aucun `AudioStreamPlayer`, aucun bus, aucun autoload audio.

**Constat de test manuel, à ne pas re-vérifier :** l'export HTML5/WebGL Godot
de ce projet **n'interrompt pas et ne baisse pas (`duck`)** l'audio de fond
d'une autre app ou d'un autre onglet — musique, podcast. Testé à la main sur
**iOS Safari et Android**, en **prod (`keepy-ten.vercel.app`) et staging**.

**Conséquence pratique : pas besoin d'un toggle de coupure** (« couper le son
si de la musique joue ailleurs ») pour les futurs travaux SFX/audio. Le Web
Audio de la page cohabite avec l'audio de fond, c'est le comportement voulu.
Point acquis, aucune modification de code associée.

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
