# Keepy — CLAUDE.md

> **Ce fichier a été réorganisé par le LOT H (2 septembre 2026).** Il ne
> contient plus que la **doctrine permanente** et l'**index des chantiers**.
> Le récit intégral de chaque lot vit désormais sous `docs/lots/`, **verbatim** :
> rien n'a été résumé, condensé ni supprimé — c'est un déplacement, pas une
> purge. Table complète : `docs/lots/INDEX.md`.
>
> ⚠️ **L'écriture additive stricte redevient la règle à partir d'ici.** Le
> LOT H est l'exception explicite et unique qui a réorganisé ce fichier ;
> **ne pas appliquer cette exception à un futur lot sans autorisation
> nouvelle**. Un lot ajoute désormais sa section au fichier de son chantier
> sous `docs/lots/`, et ne touche ce fichier-ci que s'il découvre une
> **doctrine réellement nouvelle**.

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

1. **Fence à 4 backticks, toujours — jamais de Markdown brut.** Le rapport
   de fin de tâche ou de batch doit toujours être fourni ENVELOPPÉ dans un
   fence à 4 backticks (jamais du Markdown rendu directement dans la
   réponse), pour permettre la copie en un tap sur iPhone. Le rapport reste
   un bloc unique, jamais paginé en plusieurs messages ni plusieurs blocs.
   Cette règle est permanente, sans exception, et ne connaît **aucune
   distinction avec la convention Keepr** sur ce point — même exigence des
   deux côtés. (Corrigé le 17 août 2026 : une formulation antérieure avait
   pu se lire à l'envers — comme si un bloc Markdown simple, non enveloppé,
   suffisait. Ce n'a jamais été l'intention ; ce paragraphe la clarifie sans
   ambiguïté possible.)
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


### Historique des incidents de concurrence — QUATRE, et l'outillage n'en a signalé aucun

| date | ce qui s'est passé | ce qui a tranché |
|---|---|---|
| 6 août 2026 | deux sessions poussent un `CLAUDE.md` quasi-identique sur `main` à 40 s d'intervalle | le `push` rejeté de la seconde |
| 11 août 2026 | même brief donné deux fois ; ~3 h de travail dupliqué, **mesures identiques des deux côtés** | un `git fetch` fait **à la fin** |
| 21 août 2026 | lot 7 Battle brieffé deux fois ; la seconde session a fait le `fetch` **au début** et n'a produit **aucun doublon** | le tri des refs par date |
| 25 août 2026 | recon lot G stream brieffée deux fois, deux noms de branche **à un suffixe près** | la comparaison des **ARBRES** |

⚠️ **RIEN DANS L'OUTILLAGE NE SIGNALE UNE COLLISION.** Les quatre fois, le
seul indice était une branche distante dont le nom ressemblait au sien.
**Comparer les ARBRES (`git rev-parse <ref>^{tree}`, `git merge-base
--is-ancestor`), jamais les NOMS** : deux branches peuvent différer d'un
suffixe et porter le même arbre (donc être déjà mergées), et un `git log`
dont les trois premières lignes ne montrent pas ses propres commits n'est
**pas** une divergence — c'est une question d'ANCESTRALITÉ, et
`merge-base --is-ancestor` y répond en une commande.

**Faire ce `fetch` AU DÉBUT, pas à la fin.** C'est la seule mesure qui a
jamais réduit le coût d'une collision à zéro.

## Déploiement — DEUX PALIERS, et un seul des deux est gaté

Deux branches permanentes, deux alias Vercel :

- **`https://keepy-staging.vercel.app`** — build de `staging`.
- **`https://keepy-ten.vercel.app`** — la PRODUCTION, alimentée uniquement
  par `main`.

- **Palier 1 — feature branch → `staging` : AUTOMATIQUE PAR DÉFAUT, aucune
  autorisation à demander.** Dès qu'un lot est techniquement valide (build et
  export headless verts, sondes gatées vertes), la session merge sur
  `staging` et pousse, **sans attendre ni solliciter la permission**.
  `staging` est un bac à sable ; une erreur y coûte un commit de plus.
  **Le seul gate de ce palier est TECHNIQUE, jamais humain.**
- **Palier 2 — `staging` → `main` : GATÉ, sans exception.** Seule une
  autorisation explicite de Mathieu, donnée **après validation device sur
  `keepy-staging.vercel.app`**, fait passer du code sur `main` — un push sur
  `main` est une mise en production immédiate.

⚠️ **Sur `staging`, merger n'est pas une option offerte : c'est l'étape
terminale normale d'un lot valide.** Demander la permission pour ce palier
est un défaut de process, au même titre que merger sur `main` sans l'avoir
demandée. (Ambiguïté levée le 12 août 2026 après qu'une session ait attendu
un feu vert pour un lot pourtant vert.)

**Jamais de fast-forward vers `main`** : un `--no-ff` laisse un point de
décision lisible dans l'historique. Avant tout merge de prod, vérifier que
**l'arbre du commit de merge est byte-identique à celui de `staging`**
(`git diff HEAD origin/staging` vide **et** même hash d'arbre des deux
côtés) — ce qui part en prod doit être littéralement l'arbre validé, pas
une recomposition.

### Exception actée et permanente : les `.glb` bruts vont DIRECTEMENT sur `main`

Un `.glb` sorti de Meshy pèse 12 à 27 Mo et ne peut pas transiter par une
session agentique. Mathieu le pousse lui-même depuis l'interface web GitHub
ou VS Code, sans branche ni PR. **C'est une exception explicite et permanente
à « jamais de push direct sur `main` », et elle est BORNÉE aux binaires
d'asset bruts sous `assets_source/`** : elle ne couvre aucun fichier de code,
de scène ou de configuration.

Ce qu'elle implique, et qui n'est pas négociable :

* **Un `.glb` sur `main` n'est PAS un asset validé** — il est déposé, pas
  intégré.
* **Le contenu réel est à MESURER, jamais à lire dans le nom de fichier.**
  Un lot annoncé « 7 fichiers, 6 sujets » a mesuré **6 fichiers, 5 payloads
  distincts, 4 sujets** — un doublon byte-identique, et deux sujets annoncés
  qui n'existaient pas. Le chemin annoncé est faux aussi souvent que le
  contenu (`assets_source/hazards/` annoncé, `assets_source/ennemis/` réel).
* **Le travail d'intégration, lui, reste sur une branche**, avec la règle
  standard `staging` → validation device → `main`.
* **Conséquence pour une session** : si un lot nomme un asset dans son brief,
  **vérifier par ARBRE que cet asset existe sur sa propre base** — il peut
  n'exister que sur une branche non mergée (cas du lot A ours, qui a coûté
  un merge préalable au lot B).

⚠️ **Un `main` en avance de quelques commits sur `staging` n'est donc pas
une divergence alarmante** : c'est le plus souvent un dépôt de `.glb` bruts.
Le vérifier (`git diff --stat` sur la plage) avant de s'arrêter.

## Vérifier un déploiement SUR LE SERVICE, jamais dans le log CI seul

Un log CI vert dit que la CI a réussi ; il ne dit pas quel build l'alias
sert. **Deux marqueurs indépendants, lus AUX DEUX BOUTS** (avant le merge et
après), c'est la forme la plus forte que ce fichier documente :

| marqueur | ce qu'il vaut |
|---|---|
| **`CACHE_VERSION`** de `index.service.worker.js` | un **epoch posé à l'export** : il doit tomber **à l'intérieur de la fenêtre de l'étape `Export Web build`** du run. Le discriminateur le moins cher (~5 Ko à relire). |
| **`index.wasm`** (taille + md5) | **LA PREUVE D'IDENTITÉ.** Vaut **35 376 909** octets / md5 `af4a8fc2925d992348eb30deeeb54360` pour tout lot qui ne touche pas le code moteur ; `index.js` md5 `4e08904b1b7107858246af44b602067b`. |
| **`index.pck`** | **marqueur « un nouveau build est servi », JAMAIS une preuve d'identité** — voir ci-dessous. |

⚠️ **`index.pck` N'EST PAS STABLE EN TAILLE d'un export à l'autre du MÊME
commit.** Mesuré : trois exports locaux consécutifs donnent trois chiffres,
et **16 octets d'écart ont été observés sur un commit de COMMENTAIRE SEUL**.
La variance vient de la passe de compression VRAM de Godot sur les textures.
**Une coïncidence entre le `.pck` local et le `.pck` servi ne prouve rien** —
`index.wasm` est le contrôle d'identité, et lui seul.

⚠️ **UN `HIT` AVEC UN `age` NON NUL N'EST PAS UNE MESURE DE FRAÎCHEUR.**
Seule une lecture **`x-vercel-cache: MISS` avec `age: 0`** compte. Piège
rencontré et refusé une dizaine de fois : une lecture qui porte encore
l'ancienne valeur peut se lire comme « le déploiement n'a pas pris » alors
que ce n'est qu'une copie de bord figée — **et c'est souvent SA PROPRE
lecture précédente qui a rempli ce cache**. Un paramètre de requête différent
ne le buste pas toujours ; il faut en changer réellement la valeur.

⚠️ **L'egress direct vers `*.vercel.app` est REFUSÉ par le proxy de ce
sandbox** (`http_code 000`, exit 56, re-testé et pas supposé). Le canal MCP
Vercel est le seul disponible. **Corollaire mortel** : une boucle d'attente
`until [ "$(curl … | grep X)" != "ancienne" ]` sort **immédiatement** en
annonçant un changement, parce qu'elle compare sur une chaîne **VIDE**.
**Une garde d'attente qui ne vérifie pas qu'elle a RÉELLEMENT lu quelque
chose confond « ça a changé » et « je n'ai rien reçu ».**

### ⚠️ Les API de CI et de déploiement servent des ÉTATS PÉRIMÉS

**GitHub Actions** : un poll peut rendre `status: "in_progress"` **des
dizaines de minutes après** la fin réelle du job, avec des réponses
**byte-identiques** d'un appel à l'autre — `filter: "latest"` compris.
Observé sur au moins six runs. **Le seul champ digne de foi est
`completed_at`** (et `conclusion`) : s'il est renseigné, l'étape EST finie,
quoi que dise `status`. Ne jamais lire un état de CI sans regarder son
horodatage, et poller sur les DEUX terminaux (`success` ET `failure`).

⚠️ **`workflow_jobs_filter: {"filter": "latest"}` N'EST PAS LE REMÈDE.**
Observé une fois débloquant, observé au moins deux fois **figé de la même
façon** — et une fois c'est `{"filter": "all"}` qui a rendu l'état réel
pendant que `"latest"` mentait. **Le paramètre n'est ni la cause ni la
cure ; seul un SECOND SIGNAL INDÉPENDANT tranche** (le `CACHE_VERSION`
réellement servi, qui a d'ailleurs tranché **dans les deux sens** : « c'est
encore l'ancien build, donc le job tourne vraiment » puis « il a basculé »).

⚠️ **L'API VERCEL AUSSI** sert des réponses périmées (~25 min observées).
Un unique `status=completed` n'est pas une preuve.

⚠️ **ET LE PIÈGE COURT DANS L'AUTRE SENS — l'écarter AVANT d'accuser
l'API.** Deux appels byte-identiques figés sur « Import project resources »
ont exactement la forme du piège, et l'import de ce projet dure réellement
**2 à 4 minutes**. Un `Checkout` a réellement duré 3 min 49 s sur ce dépôt
de 230 Mo. **Regarder l'horloge coûte une commande** ; c'est aussi ce qui a
révélé, plusieurs fois, qu'un `sleep` lancé en arrière-plan puis relu
immédiatement faisait passer 2 minutes pour 40.

### ⚠️ DEUX déploiements se disputent la PROD à chaque push sur `main`

Le projet Vercel a l'intégration GitHub **native** active EN PLUS du
déploiement CI, et les deux ciblent `production` :

| source | reconnaissable à | ce qu'elle sert | délai |
|---|---|---|---|
| **native** | `meta.branchAlias` présent | le **dépôt BRUT** — pas d'`index.html` à la racine → **404** | quelques secondes |
| **CI** | `meta.gitRootDirectory = build/web` | le vrai export Godot | ~3 min |

**Chaque push sur `main` met donc la prod en 404 pendant ~3 minutes**, et un
merge de prod en fait deux (le merge puis le commit de doc). Ça se répare
tout seul — mais **si la CI échoue APRÈS que le natif ait déposé, la prod
RESTE en 404** jusqu'au push suivant, et rien ne l'alerte. **Ne jamais lire
un fingerprint sans regarder l'heure du dernier déploiement.** Non corrigé
(Settings → Git du projet Vercel, action Console de Mathieu).

⚠️ **`web-build.yml` porte `cancel-in-progress: true`** : pousser le code
puis la doc coup sur coup **annule le premier run**. Un run `cancelled`
n'est donc pas un échec, et le second construit le même arbre de jeu
(`CLAUDE.md` n'étant pas une ressource Godot). Pousser la doc **après** la
fin du run de code, ou l'assumer.

## Pièges d'outillage — chacun a coûté au moins un run, plusieurs en ont coûté plusieurs

### `--headless` FORCE le driver DUMMY, et il produit des FAUX VERTS

⚠️ **`--headless` écrase `--rendering-driver opengl3`, en silence.**
`get_image()` rend alors une surface vide : tous les échantillons lisent
`(0,0,0)`, tous les ratios calculent 1,00:1, **et la sonde SORT EN 0**. Faux
vert complet, rencontré pour de vrai.

Le driver DUMMY casse au moins **quatre** choses distinctes, chacune trouvée
séparément :

1. **les pixels** — toute sonde qui échantillonne une frame ;
2. **les transforms de `MultiMesh`** — relire une instance rend l'identité,
   avec un écart mesuré à 33,7 alors que le code était juste (le
   `custom_aabb`, calculé dans la MÊME boucle, sortait correct : c'est ce qui
   l'a prouvé) ;
3. **la taille du viewport** — rapportée **0x0** (ou 1920x1920), donc
   `unproject_position` et tout `_handle_point` piloté par un point d'écran
   **sortent avant de projeter quoi que ce soit** et chaque check passe **en
   ne s'exécutant jamais** ;
4. **la compilation des shaders** — un boot headless ne compile rien, donc il
   ne prouve **aucun** `SHADER ERROR`.

**Règle** : toute sonde qui lit un pixel, une instance de `MultiMesh`, un
point d'écran ou un shader se lance **sous `xvfb-run --rendering-driver
opengl3`**, jamais `--headless` seul. Et **le rect du conteneur est ASSERTÉ
non dégénéré** dans la sonde, pour qu'elle échoue bruyamment au lieu de
passer gratuitement.

⚠️ **L'inverse est vrai aussi** : une sonde qui ne lit **que** des transforms
(`unproject_position` est un calcul pur, `PursuerFramingAudit`,
`DecorStabilityAudit`, `LakeMoveReconProbe`) doit tourner **EN HEADLESS** —
sous llvmpipe elle dépasse 10 minutes sans finir alors qu'elle rend son
verdict en secondes.

### ⚠️ L'ORDRE DES FLAGS — les flags moteur AVANT le `--`

```
godot4 --headless --fixed-fps 60 --path . res://scripts/dev/X.tscn -- --seed=20260806
```

`--fixed-fps` placé **après** le `--` est ignoré par le moteur : la
simulation tourne à ~1× le temps réel, et une sonde à 900 s simulés met
~15 minutes — **symptôme identique à un blocage, cause totalement
différente**. Le watchdog le dit lui-même (« NOT STUCK, JUST SLOW »).

⚠️ **CE PIÈGE FABRIQUE DES FAUX ROUGES, pas seulement de la lenteur.**
`SeesawProbe` sans `--fixed-fps 60` rapporte la diagonale à **4,983 s / 8,150 s
/ 45,033 s** selon la charge au lieu du **18,700 s** publié, et **échoue**.
Rencontré au moins quatre fois, sur des lots différents. Un banc de traversée
sans ce flag ne mesure pas le jeu, il mesure la machine.

### ⚠️ Une sonde dont le SCRIPT ne PARSE pas ne tombe pas vite : elle traîne jusqu'au timeout

Une erreur de parse GDScript empêche la scène de se charger, donc
`ProbeWatchdog.arm()` n'est **jamais atteint** — il n'y a pas de watchdog du
tout, et le process tourne à vide (15 min observées) **sans une seule ligne
de sortie**. Parade : un `--headless --quit-after 2` sur la scène **avant**
tout run long, qui fait apparaître `Parse Error` en quelques secondes.
Rencontré au moins trois fois, dont une sur `ProbeWatchdog.abort_if_exceeded(dl)`
(statique) au lieu de `dl.abort_if_exceeded()`.

⚠️ **Et rediriger vers un fichier plutôt que de piper vers `head`** : un
`| head -20` en bout de pipe **avale** le `SCRIPT ERROR` (`head` ne peut pas
flusher), donc le process a l'air lent au lieu d'avoir l'air cassé.

### ⚠️ `pgrep -f` PEUT S'ATTENDRE LUI-MÊME, INDÉFINIMENT

Mesuré : **onze** boucles de poll ont survécu à leur travail de **1 h 44**,
avec **zéro** process `godot4` vivant. `pgrep -f` compare au
`/proc/*/cmdline` complet et n'exclut **que son propre PID**, jamais le shell
qui l'a lancé :

```
while pgrep -f "path . --import" >/dev/null; do sleep 10; done
```

matche sa PROPRE ligne `bash -c ... while pgrep -f "path . --import" ...`.
**La panne est silencieuse et ressemble exactement à du travail encore en
cours.**

| boucle | résultat |
|---|---|
| `while pgrep -f "SENTINEL"` | **exit 124 (timeout)** — boucle infinie |
| `while pgrep -f "[S]ENTINEL"` | **exit 0** — détecte correctement l'absence |

⚠️ **Le crochet est NÉCESSAIRE ET NON SUFFISANT** : il ferme « je me matche
moi-même », il ne fait **rien** contre un shell **ANCÊTRE** dont la ligne de
commande porte le texte nu — ce qui, sous l'outil Bash agentique où plusieurs
commandes partagent un même `bash -c`, est le cas COURANT. Re-rencontré
après le correctif, avec un motif crocheté et aucun process réel.

**Parade** : `scripts/dev/wait_for_probe.sh --pid <PID>` (aucun matching de
texte), ou son mode motif qui **refuse** un motif non crocheté et retire les
PID ancêtres. **Ne plus écrire de `while pgrep` inline.** Idem pour
`pkill -f 'Godot_v4.3'`, qui **tue son propre shell** — forme crochetée
obligatoire.

### ⚠️ Un téléchargement peut arriver TRONQUÉ SANS ERREUR `curl`

Le `.tpz` des templates d'export est arrivé tronqué **quatre fois** avec un
exit 0 : **318 289 257**, **517 025 792**, **925 499 392** octets contre les
**1 073 228 327** annoncés par le `Content-Length`. Le symptôme apparaît bien
plus loin, en `End-of-central-directory signature not found` d'`unzip`, ce
qui **ressemble à une release cassée en amont**. **Toujours vérifier la
taille contre le `Content-Length` avant d'extraire** (éditeur : 50 276 070).

### ⚠️ Un import Godot TRONQUÉ produit un FAUX ROUGE de sonde

Une comparaison baseline/branche a rendu 3 sondes sur 4 « DIFFERS », dont
`AssetContractAudit` annonçant `[-- ]` là où la branche lit `[glb]` : de quoi
croire à une régression d'assets. **L'import du worktree de baseline avait
été coupé** (5 puis 21 `.scn` sur 24) — les `.glb` manquaient, donc la
baseline mesurait des placeholders. Le `stderr` le disait
(`Cannot open file '…-*.glb-*.scn'`), le `stdout` non.

**COMPTER LES `.scn` DE `.godot/imported/` DES DEUX CÔTÉS AVANT DE COMPARER
QUOI QUE CE SOIT.** Un import complet de ce projet prend plusieurs minutes et
**ne signale pas lui-même qu'il a été interrompu**.

⚠️ **Corollaire, payé une fois** : une notification de tâche de fond
« terminée » atteste que le mécanisme d'arrière-plan a rendu la main, **pas**
que le processus a fini son travail. Vérifier par `ps aux` ou par un artefact
réel (le compte de `.scn`) — sans quoi on relance un second import dans le
MÊME worktree et les deux écrivent en concurrence dans `.godot/imported/`.

⚠️ **Et comparer les TAILLES de sortie avant les contenus** : un run tué en
cours (1009 octets contre 2670) se lit exactement comme un diff réel. Deux
sondes gameplay seedées sont sorties « différentes » pour cette seule raison.

### ⚠️ AUTO-CONTAMINATION : `rm -rf build/` avant tout export

`export_filter="all_resources"` scanne tout `res://`, **`build/` compris**.
Un second export sans nettoyage fait réimporter les PNG écrits par le
PREMIER (`build/web/index.icon.png`…) comme de NOUVELLES ressources, qui se
retrouvent packées : **+564 Ko observés**, et **7 lignes `Storing File:
res://build/*`** dans un log. `.gitignore` exclut `/build/`, donc le risque
n'existe **que localement** (la CI part d'un checkout frais) — mais toute
session qui exporte plusieurs fois doit faire `rm -rf build .godot` entre
deux, avant toute comparaison de taille de `.pck`.

⚠️ **`godot4 --export-release` NE CRÉE PAS le dossier de destination** et
échoue en `Target folder does not exist` : un `rm -rf build` doit être suivi
d'un `mkdir -p build/web`.

### ⚠️ Petits pièges shell qui ont chacun coûté un run

* **`grep -E '\t'` ne veut pas dire TAB** — GNU `grep -E` traite `\t` comme
  un `t` littéral. Utiliser `awk -F'\t'` et comparer les champs.
* **Le `cd` d'une commande précédente PERSISTE** : une sonde a tourné avec
  `--path .` depuis `build/web`, donc sans `project.godot` — **20 minutes à
  ne rien mesurer, sans une seule ligne d'erreur**. Chemins absolus.
* **`sleep` en avant-plan est bloqué** dans ce sandbox : lancé en
  arrière-plan puis relu immédiatement, il fait passer 2 minutes pour 40.
  Comparer `date -u` à l'en-tête `date` de la réponse HTTP, ou `ps -eo etimes`.
* **`nohup … &` survit à son shell** : deux scripts de sondes ont tourné en
  parallèle en écrivant dans les mêmes fichiers `/tmp` — 17 lignes de diff
  qui n'étaient que de la corruption mutuelle.
* **Ne pas éditer un `.gd` pendant qu'un `--import` tourne** : cascade de
  `Could not find type` sur une classe qui existe, parce que l'import a
  scanné le consommateur avant que le `class_name` soit sur le disque.
* **Un `class_name` neuf n'est pas visible avant un ré-import.**

## Pièges Godot 4.3 — tous SILENCIEUX, aucun ne lève

### ⚠️ `MultiMesh.transform_format` vaut `TRANSFORM_2D` (0) PAR DÉFAUT

Un batch laissé dessus **jette toutes les transforms qu'on lui écrit et
dessine tout à l'origine** — c'est-à-dire, sur le plateau, tout le décor
empilé sous les pieds de Keepy. Mesuré sur quatre ordres d'écriture : seul
`transform_format` → `mesh` → `instance_count` rend la bonne valeur ; les
trois autres rendent `(0,0,0)` avec `fmt=0`. **Le poser en PREMIÈRE ligne.**

**Et écrire `custom_aabb` explicitement** : une AABB fausse ou périmée fait
disparaître **tout un batch** quand la camera tourne, **sans aucune erreur**.

### ⚠️ Le canal alpha d'`albedo_color` est IGNORÉ tant que `transparency` reste `DISABLED`

Une surface d'eau rendrait en turquoise **opaque plat**, sans aucune erreur
pour le dire. `BaseMaterial3D.TRANSPARENCY_ALPHA` est posé **explicitement**
partout où un alpha compte.

### ⚠️ Écrire `ALPHA` dans un shader COÛTE L'ÉCRITURE DE PROFONDEUR

Assigner `ALPHA` classe le matériau dans la passe TRANSPARENTE, qui n'écrit
pas la profondeur par défaut. Avec `cull_disabled` sur un **corps fermé**, la
face ARRIÈRE repeint la face avant **dans l'ordre du buffer d'indices** —
ordre FIXE, alors que quel-côté-est-loin ne l'est pas. D'où une image **juste
de face et fausse dès qu'on tourne** : 94 px de différence à yaw 0 contre
**25 202** à yaw 135.

**Mesuré, pas déduit** : `depth_draw_always` et « retirer l'écriture d'ALPHA »
donnent le MÊME résultat au pixel près aux huit azimuts — c'est ce qui épingle
la cause sur le depth write. **Retirer l'écriture** plutôt que forcer la
profondeur : forcer laisserait le matériau dans la file alpha, trié comme un
objet entier contre d'autres transparents.

⚠️ **ET LA TRANSPARENCE DE CE PROJET EST DÉJÀ PASSÉE VERTE DANS CE SANDBOX
ET CASSÉE SUR DEVICE UNE FOIS.** llvmpipe/`opengl3` de BUREAU contre WebGL2
sous Safari : deux compilateurs GLSL et surtout **deux implémentations de tri
des transparents**. Tout lot qui touche à l'alpha doit être testé sur device
**à plusieurs azimuts**, pas de face seulement.

### ⚠️ `MeshInstance3D.get_aabb()` ne dit PAS la taille d'un rig animé

Un `.glb` Mixamo porte un nœud `Armature` à `scale [0.01, 0.01, 0.01]` :
l'accessor POSITION donne une étendue brute de **1,700000**, donc
`get_aabb()` à travers l'armature rend **0,017000** — un facteur 100. La
mesure honnête vient de `Skeleton3D.get_bone_global_pose()` sur les os en
pose de repos : **1,671335**.

⚠️ **ET IL FAUT MESURER DANS L'ESPACE PROPRE DU RIG.**
`skel.global_transform` porte **déjà** l'échelle appliquée au Rig, donc
mesurer à travers lui puis multiplier par cette échelle l'applique **DEUX
FOIS** — le bug a été fait deux fois avant d'être compris, avec un
mauvais diagnostic entre les deux (« l'engine utilise les
`inverseBindMatrices` »). Ce qui l'a révélé : l'étendue **bougeait AVEC
l'échelle** (`1.851959 / 1.108066 = 1.671335` et
`1.705802 / 1.020617 = 1.671335`, le même nombre des deux côtés). Corriger
par `rig.global_transform.affine_inverse()`.

⚠️ **C'est l'assertion de la sonde qui a attrapé ce bug** : l'échelle est
**re-mesurée contre le rig vivant à chaque run** et `push_error` en cas de
dérive. Elle a payé dès le premier boot.

### ⚠️ Un `@export` de NOEUD TYPÉ écrit à la main dans un `.tscn` NE SE RÉSOUT PAS

`@export var camera: Camera3D` avec `camera = NodePath("...")` rend **`null`
au chargement** — l'éditeur peuple cette forme par une machinerie qu'un
`.tscn` écrit à la main ne porte pas. Résultat : chaque tap mourait sur un
garde, **aucune erreur, aucun crash**, juste un plateau où rien ne répond.
**Parade : `@export var x_path: NodePath` + résolution dans `_ready()` avec
un cast et un `push_error`.**

### ⚠️ `mouse_filter` : le DÉFAUT de `Control` est `STOP`, et il AVALE les taps

`_unhandled_input` s'exécute **APRÈS** le picking GUI : tout `Control` sous
le doigt à `MOUSE_FILTER_STOP` consomme l'événement, appelle
`set_input_as_handled()`, et plus rien en aval ne le voit — **aucune erreur,
juste un plateau qui ignore chaque tap**. Une racine `Control` plein écran
laissée au défaut avalait donc tout. Défauts **mesurés** en 4.3 :
`Control`/`ColorRect`/`PanelContainer`/`Button` = **STOP (0)**,
`VBoxContainer`/`TextureRect` = PASS (1), `Label` = IGNORE (2).

⚠️ **Et le piège court dans l'AUTRE SENS** : une popup qui n'avale PAS
laisse le tap atteindre le plateau et fait bondir le personnage sous elle.
Poser `STOP` **explicitement** plutôt que compter sur le défaut, et doubler
d'un garde côté logique — la panne couverte est silencieuse.

⚠️ **`iframe.onload` se déclenche AUSSI quand COEP a bloqué l'embed** —
aucune exception, aucune erreur console. Inutilisable comme signal de santé.

### ⚠️ Autres pièges d'API mesurés

* **`Object.get("UNE_CONST")` rend `null`** — une constante GDScript n'est
  pas une propriété. Ni erreur ni warning. Lire
  `get_script().get_script_constant_map()`.
* **Un lambda GDScript capture une variable LOCALE PAR VALEUR** : le lambda
  écrit sa propre COPIE, la boucle d'attente ne voit jamais le changement, et
  chaque itération tourne jusqu'à son plafond. **Un membre de classe et une
  méthode nommée, jamais un lambda, pour tout drapeau qu'une boucle attend.**
  Rencontré au moins trois fois.
* **Une fonction de phase qui contient un `await` est une COROUTINE** :
  l'appeler sans `await` la fait tourner **EN PARALLÈLE** de la suite. Deux
  phases ont ainsi mesuré la même chose en se marchant dessus, et trois
  planches de plongeoir ont été testées **concurremment sur un seul corps**.
* **`SubViewportContainer.stretch = true` IGNORE un `vp.size` explicite**
  (simple `WARNING`) : l'aspect mesuré est celui de la fenêtre. Une passe a
  rendu des chiffres **identiques pour deux ratios**, ce qui ressemblait à un
  résultat.
* **`godot4 --script` NE CHARGE PAS LES AUTOLOADS** — `Identifier not found:
  SafeArea`, un faux rouge qui ressemble à une erreur de compilation. Toute
  sonde est une `.tscn` lancée comme scène principale.
* **`emulate_mouse_from_touch` vaut `true` par défaut** : **UN** tap physique
  produit **DEUX** événements (touch réel + souris synthétisée) dans la même
  passe. Un hotspot dont la branche « déjà assez près » entre immédiatement
  dans un état busy **doit AUSSI être gardé dans le fallback sol**, sinon le
  second dispatch arrache le personnage de la pose que le premier vient de
  poser — lu comme un tremblement.
* **`change_scene_to_packed` met `current_scene` à NULL immédiatement** et
  n'installe la nouvelle qu'en fin de frame d'idle ; `set_current_scene`
  refuse un nœud qui n'est pas enfant direct de `root` (erreur poussée,
  `current_scene` intacte) ; et `root` est occupé à monter ses enfants
  pendant le `_ready()` de la scène principale, donc `add_child` y échoue net
  — une sonde a alors mesuré un plateau **VIDE**.
* **Trois lignes d'erreur stderr sont BÉNIGNES et PRÉ-EXISTANTES** :
  `Parameter "m" is null` (driver dummy, à la libération des nœuds, **APRÈS**
  le verdict), `Function blocked during in/out signal` (`set_monitoring`), et
  le bruit ALSA `audio_driver_alsa.cpp:90` sous xvfb. Vérifiées contre une
  baseline, pas supposées.
* **Toute sonde qui joue un cue audio puis quitte** doit attendre en temps
  RÉEL avant de sortir, sinon elle s'ajoute `ObjectDB instances leaked at
  exit` **après** son propre verdict et casse la comparaison byte-identique.

## Doctrine de conception — ce que ce dépôt a appris en payant

### ⚠️ ROUGE AVANT VERT — une assertion qui n'a jamais échoué ne prouve rien

Toute assertion neuve est **vérifiée capable d'échouer** avant d'être crue
sur son succès : le correctif est neutralisé, la sonde doit sortir ROUGE
**sur les assertions attendues et pas d'autres**, puis le fichier est
restauré et vérifié **byte-identique** (`cmp`). Rencontré des dizaines de
fois ; à chaque fois où ça a été fait, ça a soit confirmé le fix, soit
trouvé un défaut dans la sonde elle-même.

**Le nombre d'échecs attendus fait partie de l'assertion** : neutraliser un
accesseur a produit **UN seul** rouge là où DEUX étaient attendus, ce qui a
révélé qu'un champ était lu **en direct** à un endroit et **par l'accesseur**
à l'autre — un vrai défaut, trouvé par la passe rouge et pas par relecture.

### ⚠️ BLIND CHECK — une assertion d'ÉGALITÉ ou d'ABSENCE doit d'abord prouver qu'elle sait VOIR

« Rien n'a bougé », « aucun anneau n'est apparu », « ces deux rendus sont
identiques » passent **GRATUITEMENT** contre un mécanisme jamais câblé. La
sonde doit donc d'abord faire tirer la chose, mesurer que le nombre BOUGE,
et seulement ensuite asserter qu'il ne bouge pas dans l'autre cas.

Mesuré : dans un run délibérément cassé, **trois assertions sont passées
VERTES** — « le sol n'est jamais bloquant », « il redevient opaque », « il
ressort de la passe transparente » — contre un mécanisme qui n'avait jamais
été câblé. **C'est littéralement pourquoi le blind check n'est pas
optionnel.** Ordonner les phases en conséquence : le POSITIF d'abord, les
refus ensuite.

### ⚠️ UN FIXTURE QUI DIVERGE DU RÉEL SUR UN AXE NE PROTÈGE PAS DE CET AXE

`SubstituteModel.tscn` imitait un modèle importé par sa STRUCTURE DE NŒUDS
et pas du tout par sa LIAISON DE MATÉRIAU — c'est-à-dire précisément l'axe
sur lequel vivait le défaut. Un matériau atteint une surface par DEUX
chemins : un *auteur de scène* écrit un `surface_material_override/0`, un
*importeur* écrit **sur la SURFACE DU MESH** et ne pose **jamais** d'override.
La rampe d'alarme serait donc devenue un **no-op silencieux** au premier
`.glb`, sans erreur ni sonde rouge.

**Cette divergence est invisible tant que personne ne la nomme.** Corollaires
appliqués depuis : une sonde lit **ce que le slot DESSINE**, jamais la
variable qu'on vient d'écrire ; une phase rejoue le contrat sur la scène
**telle qu'elle est livrée**, sans fixture ; et une transcription d'algorithme
(spline, placement) est **confrontée au maillage construit** plutôt que crue.

### ⚠️ MESURER, PAS SUPPOSER — les prémisses de brief tombent, presque à chaque lot

Ce fichier documente des dizaines de prémisses annoncées qui n'ont pas
survécu à la mesure : un décompte d'assets faux sur les trois axes à la fois,
un `cap 1 200` qui était en réalité 4 000-5 258, un « TORUS PERCÉ » qui était
**plein en silhouette** (0,00 % d'aire ouverte), un « le lit est plus haut que
la mezzanine » où **les deux sont la même surface**, un « 3 sites appelants »
qui en avait quatre, un « l'échelle déclenche immédiatement » alors qu'elle
fait déjà l'inverse, un seuil P2 « r=20 » pour lequel **aucun centre n'existe**.

**Règle** : reproduire d'abord un chiffre déjà au dossier avec le banc qu'on
s'apprête à utiliser. Un banc incapable de restituer la diagonale à 66 hops /
18,700 s n'a pas qualité à publier un chiffre neuf.

⚠️ **Et un nombre COPIÉ d'ailleurs mérite plus de défiance qu'un nombre
mesuré ici** — surtout quand il est **UNE MOITIÉ d'une somme** : le lift de
Keepy est `0,9` (le slot) `+ (-0,2246)` (l'offset). Copier le second seul, et
le multiplier par une échelle que l'original ne multiplie pas, a enterré le
personnage sous **68 % de sa taille**. Une moitié de somme se lit comme un
nombre complet et **ne se signale jamais**.

### ⚠️ LA MÉTRIQUE PEUT ÊTRE LA MAUVAISE, ET LE CHIFFRE VERT AVEC

Deux fois au moins, un plafond gaté mesurait autre chose que la propriété
qu'il prétendait défendre :

* le **baiser** gatait un chevauchement **corps entier** (19,8 % contre 25 %,
  marge confortable) alors que la propriété voulue était « ne pas enterrer sa
  TÊTE » — re-mesuré sur la zone tête, le contact valait **0,0 %**. Le rapport
  device « aucune différence perçue » était exact.
* le **hotspot du lit** gatait un balayage de HAUTEUR à la colonne du lit,
  alors que ce qu'un joueur vise est **l'ANNEAU DESSINÉ** — re-mesuré en
  azimut, la couverture valait **0,00 % (0/72)**.

**Quand un fix mesuré ne produit aucune différence sur device, suspecter la
MÉTRIQUE avant de re-régler la valeur** — et produire des **rendus offscreen
comparatifs**, la méthode qui a fermé les deux cas.

### ⚠️ NE JAMAIS FAIRE TAIRE UNE ASSERTION QUI ÉCHOUE SUR DU CODE « CORRECT »

`CabinProbe` PHASE T avait **trouvé** l'entonnoir du clamp, et le raisonnement
qui l'a fait taire (« 0,65 u d'une porte EST à la porte, la réponse est
juste ») était faux : le point n'y était pas parce qu'on l'avait visé, mais
parce qu'un demi-plan hors-carte NON BORNÉ était replié dessus. Le filtre a
survécu **un lot entier** avant que le device le redise.

**Une sonde qui échoue sur du code qu'on croit correct est une QUESTION, pas
une nuisance.** La faire taire par un filtre supprime le seul témoin du
défaut.

### ⚠️ AIM contre DESTINATION CLAMPÉE — le clamp est un ENTONNOIR

Une seule variable répondait à DEUX questions : `clamp_to()` répond « où
peut-il se TENIR », un test de prop répond « qu'est-ce que le joueur a VOULU
dire ». Lire la seconde sur la première fait que **tout tap sur du sol qui
n'existe pas est tiré vers le sol le plus proche** — et si un prop s'y trouve,
**tout le demi-plan derrière lui se met à signifier ce prop**. Mesuré :
**15,26 % de tout le sol visible** voulait dire « entre », et **89,2 %** de
ces pixels visaient du sol inexistant, jusqu'à **49,8 u hors carte**.

**Tout test de prop lit `aim` (non clampé) ; seule la destination émise reste
clampée.** Écrit une fois pour tous les props, parce que l'entonnoir est une
propriété du fait d'être **PRÈS D'UN BORD**, pas d'être une cabane.

### ⚠️ PATRON BATEAU contre PATRON ÉCHELLE — le second a coûté DEUX bugs

* **Patron BATEAU** : la cible **SE RETIRE** du tap pendant l'interaction
  (`is_available()` → faux), donc un tap retombe **À TRAVERS** vers le chemin
  sol et **DEVIENT** la sortie. Un joueur garde toujours un moyen de dire
  quelque chose.
* **Patron ÉCHELLE** : la cible n'émet jamais rien de différent, et l'appelant
  **jette** le signal. Inoffensif pour une planche dont le seul autre sens est
  déjà traité par état — **désastreux** partout ailleurs : un joueur **enfermé
  dans un prop qui avale chacun de ses taps, sans aucune sortie**.

**Le patron ÉCHELLE est BANNI pour toute nouvelle interaction.** Mesuré :
neutraliser le retrait fait échouer 3 assertions dont « un tap SUR le seuil a
terminé la visite », avec le personnage **toujours dedans 240 frames plus
tard**.

### ⚠️ UNE MARCHE DE LONGUEUR NULLE N'ÉMET PAS D'ATTERRISSAGE

`_advance()` termine une marche plus courte qu'`ARRIVE_EPSILON` (0,45) par
**`became_idle`** et **jamais** `hop_landed`. Une branche câblée sur le seul
atterrissage **ne fait donc rien** quand le joueur est déjà sur place — et
laisse son intention armée. **Ce défaut a SHIPPÉ sur la porte de la cabane**,
atteignable dès le premier tap de chaque visite (le pas de porte était le
point de spawn).

**Tout hotspot doit appeler son `_try_*()` IMMÉDIATEMENT après `hop_to()`**,
en plus de le câbler sur l'atterrissage. Et **l'intention doit SURVIVRE à un
atterrissage de passage** : une version qui la lâchait au premier atterrissage
laissait le personnage debout à côté de la chose sans l'avoir utilisée, et sa
sonde était **verte par chance** — jusqu'à ce qu'une marche passe à deux hops.

⚠️ **Une marche finit PRÈS de sa cible, jamais DESSUS** (0,401 court mesuré) :
tout point d'interaction fixe doit **SNAPPER**, sinon l'écart dépend du côté
d'où l'on arrive.

### ⚠️ UN FAIT EST PUBLIÉ UNE FOIS, JAMAIS RECOPIÉ

Une position, un rayon, une échelle calculés quelque part sont **publiés par
un accesseur** (`pond_centre()`, `stream_spine()`, `magpie_local_pose()`,
`diving_boards()`, `islets()`) et lus par tous les autres — jamais retapés.
Ce dépôt a payé pour : un pas de porte qui ne scalait pas avec sa cabane
(3,68 u **dans** le tronc à l'échelle 3,5), deux `LAKE_WATER_RADIUS`
homonymes dans deux fichiers pour **deux corps différents**, et un rayon de
déclenchement dupliqué entre le disque testé et le disque dessiné.

⚠️ **Corollaire** : quand deux vues d'un même objet existent, **c'est le
repère PARTAGÉ qu'on publie** (unités modèle), pas une position monde — sinon
un rapport d'échelle 7/11 se recopie faux et ne se voit jamais, les deux vues
n'étant **jamais à l'écran ensemble**.

### ⚠️ UNE TABLE EST UNE LISTE DÈS LE PREMIER COMMIT

Le plongeoir avait une géométrie générique mais un **singleton** en aval : une
seconde planche était **dessinée et jamais grimpable**, et défaire ça a coûté
son propre lot. Depuis, tout registre de prop interactif est un `Array` dès le
premier, avec **une seule entrée dedans**.

### ⚠️ CE QUI RESTE UN NOEUD INDIVIDUEL, ET POURQUOI

Le décor du hub est batché en `MultiMeshInstance3D` par paire **(mesh,
couleur)** — jamais par type sémantique : un arbre alimente DEUX batches, un
buisson alimente DEUX INSTANCES d'UN batch, une fleur se scinde en TROIS
corolles. Restent individuels : ce dont il n'y a qu'**UN** (rien à répéter),
ce qui porte un **signal** (`Area3D` de portail), et ce dont le **batch serait
niché sous un pivot mobile** (les transforms d'un batch racine sont cuites en
MONDE, donc des barres déposées là resteraient immobiles pendant que le manège
tourne).

⚠️ **Un compteur de draw nodes qui ne cherche que des `MeshInstance3D` rate
les batches nichés** — trou trouvé quand deux sondes se sont contredites
(124 contre 123).

### ⚠️ SONDE JETABLE = SUPPRIMÉE AVANT LE COMMIT

`ProbeTimeoutAudit` doit revenir **exactement** à son chiffre de baseline. Une
sonde de mesure ponctuelle n'entre pas dans le dépôt ; une sonde qui gate un
contrat permanent y entre et compte.

## Piège payload — `export_filter="all_resources"` embarque TOUT

**Toute ressource du projet part dans le build, qu'une scène la référence ou
non.** Mesuré : les originaux Meshy bruts d'`assets_source/` coûtaient
**35,84 Mo de charge morte** téléchargée par chaque joueur mobile ; le `.pck`
est passé de 43,35 Mo à 4,23 Mo en les excluant.

`exclude_filter` couvre aujourd'hui **`scripts/dev/*`, `assets_source/*`,
`docs/*`, `web/*`, `firebase.json`** — chacun ajouté après une mesure, pas par
précaution : `docs/*` fermait 414 862 octets de `.ctex` pour **une seule
planche de couleur**, et `firebase.json` était **réellement packé** (Godot
importe les `.json` comme ressources ; `vercel.json` fuit d'ailleurs de la
même façon, signalé et non corrigé).

⚠️ **VÉRIFIER SUR LE PACK, PAS SUR LE FILTRE** : compter les lignes
`Storing File:` du log `savepack`. Une chaîne de chemin peut apparaître dans
le `.pck` via `res://.godot/uid_cache.bin` **sans qu'aucun fichier ne soit
stocké** — le contrôle qui compte est l'absence de ligne `Storing File`, et
un `grep` sur le pack seul produit des faux positifs **dans les deux sens**
(le canal `.gdc` n'est pas greppable : quatre fonctions **qui survivent**
rendent 0 occurrence elles aussi — un blind check l'a prouvé avant que le
zéro soit compté).

⚠️ **Corollaires mesurés** :
* **Désactiver un map à l'import ne réduit RIEN** — un `.ctex` non référencé
  est packé quand même. Pour économiser, il faut **retirer le map du `.glb`**.
* **`config/icon` embarque SON FICHIER SOURCE BRUT en plus de son `.ctex`**,
  spécifiquement (la génération du favicon HTML5 le relit hors pipeline).
  C'est le seul cas où compresser le PNG source compte.
* **Un `.glb` déjà livré et réutilisé coûte ZÉRO payload** — une ressource
  n'est packée qu'**une fois**. Donc **ne pas le décimer** : une copie décimée
  est un fichier de PLUS.

## Règles d'art — permanentes

### ⚠️ TOUT ASSET EST UNLIT, ET RIEN N'ATTEINT PLUS SA COULEUR

`KHR_materials_unlit` est posé **à la main** sur chaque `.glb` livré — **aucune
source Meshy ne le déclare** (`extensionsUsed` absent partout), donc ne jamais
lire un `.glb` d'`assets/models/` comme une preuve de ce que Meshy produit.

Depuis la suppression du grade plein écran, **plus rien ne post-traite la
frame** : ni lumière (l'asset est unlit), ni pass écran (il n'y en a plus).
**La couleur qu'un `.glb` porte est littéralement celle qui s'affiche, pour
toujours** — un asset importé avec une teinte diurne restera diurne au milieu
du marécage. Le corriger À LA SOURCE, ou appliquer un matériau depuis le code.

⚠️ **Conséquences en cascade, chacune mesurée** :
* **La moitié ÉMISSION d'une rampe est INERTE** sur une surface unshaded : un
  cue d'émission **ne peut pas vivre sur le slot du tout** (d'où les yeux du
  poursuivant, nœuds engine-side). Cue émission → nœud séparé ; cue albédo →
  matériau du slot.
* **L'importeur glTF ne lie JAMAIS `normal_texture` ni `metallic_texture` sur
  un matériau UNLIT** — elles lisent `null` dès l'import. Les retirer du
  `.glb` est **prouvé au pixel** (rendus byte-identiques aux quatre azimuts)
  et a économisé jusqu'à **10,7 Mo** sur un seul asset.
* **Passer un placeholder de LIT à UNLIT supprime une multiplication par
  l'ambiante** : reporter la couleur telle quelle **ne tient pas le ratio**.
  Trois hazards ont dû être re-résolus, avec un modèle qui reproduisait la
  baseline à 0,005 point près — c'est ce qui lui a donné le droit de PRÉDIRE
  l'échec au lieu de le découvrir.
* **Le placeholder DOIT suivre le `.glb`** : le laisser divergent
  reconstruirait le piège « fixture qui diverge du réel » dans le dépôt qui le
  documente.

### ⚠️ LA PALETTE EST COUPÉE EN DEUX BANDES PAR LE SOL

Le sol de Chased rend à **luminance relative 0,150** : franchir 3,0:1 exige
**L ≥ 0,549** ou **L ≤ 0,0165**. **Aucun ton MOYEN ne passe, à aucune teinte.**
Le plafond sombre dépend fortement de la saturation (0,136 en gris neutre,
0,166 à la teinte du rat, 0,289 au rouge saturé). **Résoudre en LUMINANCE,
jamais en HSV.**

⚠️ **Le sol du HUB est un autre nombre** (`L = 0,0799` mesuré au rendu, pas
l'albédo) : le 0,549 y reste valable comme cible d'ALBÉDO, mais le plancher
rendu vaut `L ≥ 0,3397`. Ne pas transporter un seuil d'un écran à l'autre.

⚠️ **Le WCAG ne score AUCUNE séparation À L'INTÉRIEUR d'une bande** — seule la
teinte y travaille, et **aucune sonde du dépôt ne la mesure**. Deux objets de
la même bande peuvent être à 1,04:1 et parfaitement distincts, ou
indiscernables ; c'est la teinte et la silhouette qui tranchent, et elles ne
sont pas gatées.

⚠️ **À alpha < 1, AUCUNE eau ne peut atteindre 3,0:1** — c'est l'alpha qui
plafonne, pas la couleur. Et **le rendu n'est PAS AFFINE en alpha** : un
modèle calé sur DEUX points a sous-estimé les quatre plans d'eau. **Tout
réglage d'alpha passe par un BALAYAGE direct, jamais par une forme fermée.**

### ⚠️ MESURER UNE COULEUR : masque, pas fenêtre — et dominant OU moyenne selon le corps

Un hazard plat unlit remplit sa fenêtre d'UNE valeur : son **dominant
d'histogramme EST sa couleur**. Ça ne transporte pas :

* une **fenêtre fixe** dérape dès que la silhouette change (le rondin JUMP a
  lu 3,28 → 3,02 pour **54 px de SOL** entrés dans la fenêtre — un artefact
  de mesure, pas un changement de couleur) ;
* un **treillis d'ailes** laisse passer le fond (**61 %** d'objet seulement) ;
* une eau **alpha se mélange sur sa berge**, et un modèle texturé étale **95
  couleurs sur 121 pixels** — aucun dominant.

**Parade** : une passe d'identification rend la cible en blanc opaque, fog
coupé, le reste en noir ; un pixel appartient au corps **ssi il revient
exactement (255,255,255)**. Publier **les deux** chiffres (dominant et
moyenne) quand ils divergent, plus la part de pixels d'objet — c'est ce qui
distingue « la couleur a changé » de « la fenêtre est contaminée ».

### ⚠️ TESSELLATION EXPLICITE, TOUJOURS

Une primitive laissée au défaut de Godot coûte des milliers de triangles : un
`SphereMesh` de collectible **4 224**, un `TorusMesh` **4 096**, deux sphères
d'yeux placeholder **8 448** à elles seules. **Remplacer une telle primitive
par un asset importé est une BAISSE** de triangles, pas une hausse —
l'inverse de l'intuition. Budgéter chaque asset contre son **cap unitaire**,
jamais contre une ligne famille.

**La déviation de facette est ABSOLUE et grandit avec le rayon** : les 24
segments d'un disque de 3,2 donnent une sagitta de 0,027, les mêmes 24
segments à 8,0 donnent 0,068 — visiblement facetté. Calibrer sur la taille.

### ⚠️ LE DÉCIMATEUR NE TRANSPORTE PAS LES UV

Aucune texture ne survit à une décimation, **à aucun budget de triangles**.
Un sujet dont le caractère tient à sa couleur (l'arbre feuillu décor) devient
un blob **moins lisible que la primitive qu'il remplace** ; un sujet dont le
caractère tient à sa silhouette y gagne. **Juger sur RENDU, pas sur
prédiction.** Et le LOD se choisit sur ce que les triangles ACHÈTENT : pour un
ajouré, l'**aire ouverte enclose** (dont la chute distingue « refermé » de
« tombé en morceaux ») ; pour un sujet à extrémités, la **demi-largeur par
bande**.

## Discipline de lecture sélective — ne pas recréer le problème que le LOT H a fermé

Le LOT H a coupé ce fichier de ~26 000 lignes relues par défaut à chaque
session à moins de 1 000 lignes de doctrine, avec le détail déplacé sous
`docs/lots/CHxx_NOM.md`. **Ce découpage ne vaut que si la lecture qui suit
reste sélective** — rien n'empêche mécaniquement une session de relire les
vingt fichiers de chantier par réflexe, ou de traiter `docs/PROBE_AUDIT.md`
et `docs/MESHY_SPEC.md` comme des lectures obligatoires de session. Cette
règle existe pour fermer ce trou-là.

1. **`docs/lots/CHxx_NOM.md`** : lire **uniquement** le ou les fichiers du
   chantier concerné par la tâche en cours. Ne jamais lire les vingt par
   réflexe. Se référer à [`docs/lots/INDEX.md`](docs/lots/INDEX.md) pour
   identifier lequel concerne la tâche avant d'ouvrir quoi que ce soit.
2. **`docs/PROBE_AUDIT.md`** : lire **uniquement** si la tâche touche la
   fiabilité des sondes/probes elles-mêmes (faux verts, timeouts, dérive de
   fixture). Ce n'est plus une lecture systématique de session.
3. **`docs/MESHY_SPEC.md`** : lire **uniquement** si la tâche touche le
   pipeline d'assets Meshy (import, décimation, budget triangles/texture).
   Ce n'est plus une lecture systématique de session.
4. **Pour tout fichier dépassant ~500 lignes dont seule une partie concerne
   la tâche** (nommément `CH10_BATTLE.md`, `CH18_CABANE_NAV.md`,
   `CH19_PIE.md`, `CH01_MESHY.md`, `CH11_HUB_PLATEAU.md`, et tout futur
   fichier de taille comparable) : lire par **plage de lignes ciblée**
   (`Read` avec `offset`/`limit`, ou `Grep` puis un extrait autour du
   résultat), jamais le fichier entier d'un coup — sauf si la tâche exige
   explicitement une revue complète du chantier.
5. Cette règle n'est pas une préférence de style : elle existe précisément
   pour empêcher qu'une future session ne recrée, fichier par fichier, le
   problème que le LOT H a été chargé de résoudre.

## Index des chantiers

Le récit intégral de chaque lot vit sous `docs/lots/`. **Rien n'y a été
résumé** : les fichiers ci-dessous contiennent les sections d'origine
verbatim, dans leur ordre chronologique. Table détaillée avec les statuts :
[`docs/lots/INDEX.md`](docs/lots/INDEX.md).

⚠️ **Un lot ajoute désormais sa section au fichier de SON chantier**, pas à
ce fichier-ci. Ce fichier ne reçoit une ligne que si le lot découvre une
**doctrine réellement nouvelle** — un piège qu'aucun exemplaire ci-dessus ne
couvre déjà, ou une règle de conception qui vaut pour tout lot futur.

| # | Chantier | Fichier | Sections | Lignes | Période |
|---|---|---|---|---|---|
| CH01 | Pipeline assets Meshy — les six hazards et leurs recolorisations | [`CH01_MESHY.md`](docs/lots/CH01_MESHY.md) | 14 | 2132 | 11 → 13 août |
| CH02 | Palette marécage — direction artistique permanente et `SwampPalette` | [`CH02_PALETTE.md`](docs/lots/CH02_PALETTE.md) | 3 | 541 | 11 → 23 août |
| CH03 | Sondes — budget temps, watchdog, `ProbeTimeoutAudit` | [`CH03_SONDES.md`](docs/lots/CH03_SONDES.md) | 1 | 109 | 9 août |
| CH04 | Keepy Chased — décor procédural, modèle de mort, poursuivant, audio | [`CH04_CHASED.md`](docs/lots/CH04_CHASED.md) | 5 | 411 | 9 → 10 août |
| CH05 | Déploiement — paliers staging/main, CI, API périmées | [`CH05_DEPLOIEMENT.md`](docs/lots/CH05_DEPLOIEMENT.md) | 3 | 149 | 8 → 17 août |
| CH06 | Écrans 2D — titre, logo, icône PWA, safe-area, letterbox | [`CH06_UI_ECRANS.md`](docs/lots/CH06_UI_ECRANS.md) | 7 | 950 | 14 → 19 août |
| CH07 | Google Sign-In — proxy `/__/auth/*`, COOP/COEP, rafraîchissement du token | [`CH07_AUTH.md`](docs/lots/CH07_AUTH.md) | 3 | 678 | 17 → 18 août |
| CH08 | Firestore — rules versionnées, durcissement auth, plan Firebase | [`CH08_FIRESTORE.md`](docs/lots/CH08_FIRESTORE.md) | 6 | 1153 | 18 → 22 août |
| CH09 | Keepy Quizz — autoload CRUD et premier écran | [`CH09_QUIZZ.md`](docs/lots/CH09_QUIZZ.md) | 2 | 440 | 18 août |
| CH10 | Keepy Battle — lots 1 à 12 | [`CH10_BATTLE.md`](docs/lots/CH10_BATTLE.md) | 13 | 3185 | 20 → 22 août |
| CH11 | Hub — du menu 2D au plateau 3D, décor, extensions, MultiMesh | [`CH11_HUB_PLATEAU.md`](docs/lots/CH11_HUB_PLATEAU.md) | 10 | 2149 | 18 → 25 août |
| CH12 | Eau — géométrie des cinq corps, lake, stream, spawn-lake | [`CH12_EAU_GEOMETRIE.md`](docs/lots/CH12_EAU_GEOMETRIE.md) | 5 | 1431 | 25 → 26 août |
| CH13 | Eau — rendu : teinte de Keepy, ligne de flottaison, impact | [`CH13_EAU_RENDU.md`](docs/lots/CH13_EAU_RENDU.md) | 4 | 1014 | 27 août |
| CH14 | Bateau — le ruisseau devient ridable | [`CH14_BATEAU.md`](docs/lots/CH14_BATEAU.md) | 2 | 500 | 26 août |
| CH15 | Plongeoir — la chaîne complète et sa généralisation | [`CH15_PLONGEOIR.md`](docs/lots/CH15_PLONGEOIR.md) | 2 | 270 | 27 août |
| CH16 | Tourniquet, balançoire et lobe nord | [`CH16_TOURNIQUET_BALANCOIRE.md`](docs/lots/CH16_TOURNIQUET_BALANCOIRE.md) | 4 | 1243 | 28 août |
| CH17 | Hibou — prop statique et vol en boucle | [`CH17_HIBOU.md`](docs/lots/CH17_HIBOU.md) | 3 | 949 | 28 août |
| CH18 | Cabane et navigation multi-niveaux | [`CH18_CABANE_NAV.md`](docs/lots/CH18_CABANE_NAV.md) | 13 | 3026 | 28 → 31 août |
| CH19 | Pie, baiser et hotspot du lit | [`CH19_PIE.md`](docs/lots/CH19_PIE.md) | 11 | 2244 | 31 août → 1 sept |
| CH20 | Ours — lots A à F, du rig animé au siège de balançoire | [`CH20_OURS.md`](docs/lots/CH20_OURS.md) | 7 | 1256 | 1 → 2 sept |

**Archive** — chantiers clos, sans objet ou historiques. **Déplacés
intégralement, jamais condensés** : une approche abandonnée garde sa mesure,
parce que c'est la mesure qui explique pourquoi elle a été abandonnée.

| Fichier | Sections | Lignes | Contenu |
|---|---|---|---|
| [`A01_MODE_SOMBRE_ET_F10.md`](docs/lots/ARCHIVE/A01_MODE_SOMBRE_ET_F10.md) | 2 | 286 | mode sombre par inversion plein écran (supprimé), et les deux décisions de teinte F10 rendues sans objet par la refonte marécage |
| [`A02_CLASSEMENT_PWA_CLOS.md`](docs/lots/ARCHIVE/A02_CLASSEMENT_PWA_CLOS.md) | 2 | 235 | l'enquête `accept_gzip`, close et validée device des deux côtés |
| [`A03_INCIDENTS_INFRA_RESOLUS.md`](docs/lots/ARCHIVE/A03_INCIDENTS_INFRA_RESOLUS.md) | 2 | 174 | `vercel alias set` « Not able to load user », et le blocage GitHub Actions transitoire |
| [`A04_AUTH_IMPASSES.md`](docs/lots/ARCHIVE/A04_AUTH_IMPASSES.md) | 2 | 288 | `signInWithRedirect` puis `signInWithPopup` — les deux impasses, avec leurs mesures |
| [`A05_RECONS_SANS_SUITE.md`](docs/lots/ARCHIVE/A05_RECONS_SANS_SUITE.md) | 8 | 1768 | recons pures qui n'ont produit aucun code, et lots arrêtés en recon sur un seuil franchi |

⚠️ **Une section d'archive n'est pas une section fausse.** Elle décrit un
état du jeu qui n'existe plus, ou une piste que la mesure a fermée. La
relire avant de rouvrir la même piste coûte moins cher que de la refaire :
c'est exactement ce qui a évité un troisième balayage de `knee_mid` et une
seconde recolorisation de repos du rat.
