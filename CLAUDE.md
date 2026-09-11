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

### Historique des promotions palier 2

Journal court, un dépôt par promotion — le récit complet de chaque lot reste
dans `docs/lots/`, ceci n'en est jamais un résumé.

| date | lots promus | autorisation |
|---|---|---|
| 6 sept 2026 | V7b, V8 (karting lot 2), CH29 (la Crique), CH30 (conduite unifiée), CH31 (rebalance difficulté) | Mathieu, après validation device sur `keepy-staging.vercel.app` |
| 10 sept 2026 (09:14) | CH64 (skatepark mini-jeu : toggles supprimés, caméra calmée, tricks au cercle, béton) — `b04f292` | Mathieu, après validation device sur `keepy-staging.vercel.app` |
| 10 sept 2026 (14:35) | CH65 (le toucher de la planche : rampe de throttle, filtre du doigt, plafond de lacet, poussée sur le nez, grip latérale) — `28adc89` | Mathieu, après validation device sur `keepy-staging.vercel.app` |

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

### ⚠️ ET IL Y A UN TROISIÈME CAS : UNE SONDE QUI MESURE DU **TEMPS CPU** VA EN HEADLESS

Écrit au CH56, contre une consigne de brief et sur une mesure. La règle
ci-dessus a deux branches (des pixels → `xvfb`, des transforms → headless)
et le temps n'est ni l'un ni l'autre. Mesuré sur `PhysicsCostProbe` :
sous `xvfb --rendering-driver opengl3`, llvmpipe redessine une fenêtre
1080×1920 **vide** à **chaque itération**, pour **~8,5 ms avec ±2 ms de
tremblement** — alors que la grandeur mesurée (cent corps physiques
mobiles) vaut **2,1 ms en tout**. Le signe du signal a **changé d'un run à
l'autre** (+0,2593 puis −3,4524 ms), et deux assertions sont sorties
ROUGES sur un banc parfaitement sain. En headless, le même signal sort à
**+0,2266 pour un tremblement de 0,0213**.

Le driver DUMMY ne peut pas tromper une telle sonde **à condition que ses
témoins n'aient rien à voir avec le rendu** : au CH56 ce sont le registre
du `PhysicsServer3D` par RID et une requête d'espace vivante, dont aucun
ne lit un pixel. C'est cette condition qu'il faut énoncer, pas le driver.

⚠️ **ET UN BANC DONT LE PLANCHER DÉPASSE SON SIGNAL DOIT RENDRE UNE
ABSENCE DE VERDICT, JAMAIS UN ROUGE.** C'est le raisonnement de
`ProbeWatchdog` pour son code 2 (« un timeout n'est ni 0 ni 1 [...] un
appelant qui le traiterait comme une assertion échouée rapporterait une
trouvaille que la sonde n'a jamais faite »), appliqué à une autre absence :
un banc plus bruyant que ce qu'il mesure n'a **rien vérifié et rien
réfuté**. La parade est une **phase de RÉSOLUTION en tête** — mesurer le
plus petit delta qu'on compte publier, le comparer au tremblement de ces
deux stations, et **sortir sur un code distinct** si la pièce ne le voit
pas. Elle coûte une minute et elle évite dix minutes de chiffres dont les
barres d'erreur les recouvrent.

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

### ⚠️ UN VERDICT `INCONCLUSIVE` PROPRE N'EST PAS UN GEL -- `ps` ET LE LOG TRANCHENT

CH32 (6 septembre 2026) : `LakeZoneProbe` et `V6CrittersProbe`, relancées
isolément après un rejeu de promotion qui les avait rapportées
« inconcluantes », ont produit exactement le message `INCONCLUSIVE` que
`ProbeWatchdog` est censé produire -- à leur propre budget pile (900 s et
600 s), après une progression RÉELLE et continue (dizaines de checks verts
sur plusieurs phases, la diagonale publiée à 66 hops / 18,700 s reproduite
au chiffre près). `ps` montrait tout ce temps un CPU réel (175-196 %, deux
threads), et le log continuait de grandir jusqu'à quelques secondes avant
la coupure.

Ce n'est PAS le signe d'un défaut : c'est ce sandbox qui n'a pas de GPU
matériel. `--rendering-driver opengl3` sous `xvfb-run` retombe sur Mesa
llvmpipe (rasterisation logicielle), et une phase qui fait marcher le
`KeepyHopper` réel sur ~10 trajets rendus de plusieurs secondes chacun ne
tient simplement pas dans le budget. `ProbeWatchdog` a fait exactement ce
pour quoi il existe.

**Règle de diagnostic, avant de soupçonner un défaut** : un vrai gel (clock
figé, deadlock, attente infinie sur un signal) montre un CPU proche de 0 %
et un log qui s'arrête NET, souvent dès le début de la phase en cause. Une
sonde simplement trop lente pour ce sandbox montre un CPU actif et un log
qui continue de grandir jusqu'au bout du budget. Les deux ne se distinguent
qu'en relisant `ps` et la queue du log AVANT de conclure -- jamais à la
seule lecture du mot `INCONCLUSIVE` ou `timeout`.

⚠️ **Et un `.tscn` de `scripts/dev/` sans script attaché n'est pas un
probe.** `SubstituteModel.tscn` (fixture nue pour `AssetContractAudit`,
explicitement exclue par `ProbeTimeoutAudit.gd`) boucle indéfiniment si on
la lance comme scène principale -- rien n'y appelle jamais
`get_tree().quit()`. Un outillage qui énumère les sondes d'un dossier par
un glob de `.tscn` doit consulter la même liste d'exclusion que
`ProbeTimeoutAudit`, sous peine de compter une fixture pour une sonde
gelée.

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
* **Vérifier qu'un process est mort par le MAUVAIS NOM.** Le binaire est
  souvent lancé par un symlink (`godot4` → `Godot_v4.3-stable_linux.x86_64`) :
  un `ps | grep "[G]odot"` rend alors **zéro** sur un process bien vivant, et
  « c'est fini » se lit exactement comme « c'est mort ». Grepper le nom
  RÉELLEMENT invoqué, ou mieux `pgrep -x`.
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

### ⚠️ AGRANDIR `instance_count` EFFACE TOUTES LES TRANSFORMS DÉJÀ ÉCRITES

Mesuré (CH23 lot 6, sous xvfb + `opengl3`) sur le batch `Rock` du hub :
porter `instance_count` de **48 à 49** rend **0 transform sur 48**
survivantes — le buffer est réalloué et remis à zéro — et `custom_aabb` ne
suit pas. Aucune erreur, aucun avertissement.

**Conséquence de conception** : on n'« ajoute » pas une instance à un batch
partagé depuis l'extérieur. Il faudrait ré-écrire tout le contenu du batch
et lui recalculer son AABB, c'est-à-dire posséder les données de celui qui
l'a rempli. Un prop qui veut de la géométrie répétée porte **son propre
`MultiMesh`**, en réutilisant le mesh et le matériau publiés (patron déjà
documenté pour les barres du tourniquet).

⚠️ **Et une sonde qui teste ça se corrompt elle-même si elle ne sauvegarde
qu'une transform** : la première version l'a fait, et toutes ses phases
suivantes ont mesuré 48 rochers empilés à l'origine. **Seul le blind check
l'a vu** (un point censé être À L'INTÉRIEUR d'un rocher a rapporté 1,942 u
au lieu de 0,000).

### ⚠️ L'AABB D'UNE AABB TRANSFORMÉE N'EST PAS UNE MESURE DE LA FORME

Une **BOÎTE** tournée à 45° a une boîte englobante plus grande — même quand
le corps à l'intérieur est une **sphère**. Toute mesure de silhouette,
d'emprise ou de hauteur prise sur `xform * mesh.get_aabb()` porte donc
cette inflation, qui grandit avec l'assiette et ne se signale jamais.

Mesuré trois fois dans un seul lot (CH23 lot 6) : un blind check
« une sphère à échelle uniforme yawée 8 fois a UNE silhouette » sorti à
**0,2006 de dispersion d'artefact pur** (0,0000 une fois refait sur les
sommets) ; une emprise d'anneau lue **1,752 u** contre **1,487 u** réels ;
et surtout un **enfouissement calculé dans le CONSTRUCTEUR** qui donnait
0,162 à 0,257 au lieu des 0,26 demandés — une profondeur fausse et
différente pour chaque pièce, variant avec son inclinaison.

**Règle** : tout ce qui porte sur ce qu'un joueur VOIT ou sur la façon dont
une pièce POSE au sol se mesure sur les **sommets réels transformés**
(`Mesh.get_faces()`), jamais sur une AABB transformée. L'AABB reste bonne
pour un `custom_aabb` de batch — où elle doit justement être conservatrice.

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

### ⚠️ ET LES OS NE SONT PAS LA SILHOUETTE — 0,164 u d'écart, mesuré

Corollaire du piège ci-dessus, et il coupe dans l'autre sens : une fois
qu'on a renoncé à `get_aabb()` pour `get_bone_global_pose()`, il reste que
**les os sont des ARTICULATIONS, pas la surface qu'un joueur voit**. Sur le
blaireau en pose de suspension, la semelle DESSINÉE pend **0,158 u sous
l'os le plus bas** (0,164 mesuré en pose de repos) : fourrure, pied,
maillage au-delà de la cheville.

Ce que ça a coûté, à l'intérieur d'un seul lot : un balayage d'angle lu sur
les os a désigné 30° comme « la marge la plus faible qui soit réelle,
+0,184 » ; le MÊME 30° relu sur les vertices skinnés laissait **+0,019**,
deux centimètres. La réponse a bougé de 10°.

**Règle** : un contrat qui porte sur ce qu'un joueur VOIT (dégagement au
sol, silhouette, chevauchement) se mesure sur les **VERTICES SKINNÉS À LA
MAIN** contre la pose vivante — `Skin.get_bind_pose()` composé avec
`get_bone_global_pose()` de chaque os, pondéré par `ARRAY_WEIGHTS`. Les os
restent le bon instrument pour ce qu'une sonde gatée doit échantillonner à
chaque frame (c'est bon marché) ; la silhouette se lit **une fois**, au bon
moment, et c'est elle qui gate. Publier les DEUX, et asserter qu'elles
**diffèrent** — sans quoi la seconde constante est décorative et le lot
suivant regatera la mauvaise.

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

### ⚠️ GODOT TIENT LES FACES HORAIRES POUR FACES AVANT — un ruban CCW disparaît

Mesuré, pas déduit (carte blanche v2) : le ruban du ruisseau était enroulé
en **anti-horaire vu de dessus** (normale du premier triangle `(0, 1, 0)`
par la règle de la main droite). Tant qu'il était dessiné par un
`StandardMaterial3D` en `CULL_DISABLED`, personne ne l'avait jamais vu. Le
premier shader en `cull_back` a fait disparaître **le ruban entier** :
nœud visible dans l'arbre, AABB juste, matériau juste, **zéro pixel**, et
**aucune erreur d'aucune sorte**.

**Règle** : tout ruban construit à la main (`SurfaceTool`, `ArrayMesh`,
tout `PackedVector3Array` d'indices écrit par du code) est enroulé
**HORAIRE vu de la face qu'on veut voir**. Le contrôle coûte une sonde
jetable de dix lignes : lire la normale du premier triangle et la comparer
au côté attendu.

⚠️ **Et ce piège se cache derrière `CULL_DISABLED`.** Un ruban CCW qui
« marche » aujourd'hui ne prouve rien : il marche parce que rien ne cull.
Le jour où un lot lui donne un shader — et `CLAUDE.md` documente déjà
pourquoi un shader finit par arriver sur toute surface d'eau — il devient
invisible d'un coup, et le symptôme ne ressemble pas à un problème
d'enroulement.

⚠️ **ET LE CONTRÔLE « lire la normale et la comparer au côté attendu » NE
SUFFIT PAS — le côté attendu se prend dans le MOTEUR, jamais dans les
maths.** Payé au CH39, sur un terrain et pas un ruban. `MountainProbe`
PHASE C vérifiait l'enroulement des **1 680** triangles de la crête ouest,
sur chacun, avec le bon commentaire au-dessus (« Godot takes CLOCKWISE
faces for FRONT faces ») — et le code exigeait `n.y > 0` pour
`n = (b−a) × (c−a)`, c'est-à-dire la convention **MATHÉMATIQUE** du haut,
qui est la **négation exacte** de la règle citée. Verte 1 680 fois sur 1 680
sur une colline que Godot jetait entièrement.

**Le produit vectoriel main droite d'une surface de SOL marchable vaut
−Y dans ce moteur**, parce qu'une face avant est horaire vue de l'œil et
que l'œil est au-dessus. Une assertion d'orientation ne se relit donc pas :
elle se **rend**. Le contrôle qui tranche est `cull_back` contre
`cull_disabled` sur le même cadre — **s'ils ne couvrent pas les mêmes
pixels, le maillage est retourné** — et il n'a aucun seuil à régler, donc
il vaut à toute station sur toute forme. Mesuré : 14 pixels contre
317 646 depuis une station debout sur la colline.

⚠️ **Le symptôme ne ressemble pas non plus à un enroulement, et il MENT
DANS LE BON SENS** : les seuls triangles qui survivent sont ceux qui
tournent le **DOS** à l'œil, c'est-à-dire le flanc lointain, vu **à travers**
le flanc proche invisible. De trente unités ça se lit comme un dôme propre
et ça valide la forme ; debout dessus, il n'y a plus rien. Une session qui
n'a regardé que la vue de loin conclut que le relief marche.

⚠️ **ET CE CONTRÔLE A UN ANGLE MORT, MESURÉ AU CH53 : UN SOLIDE CONVEXE
FERMÉ RETOURNÉ COUVRE EXACTEMENT LA MÊME SILHOUETTE.** La passe rouge d'un
park de cinq modules, convention d'enroulement inversée, a rendu **quatre
rouges sur cinq attendus** : le survivant était un rail — trois boîtes —
à **0,9977** de ses pixels conservés. Ce n'est pas un défaut du rail :
sous `cull_back`, un corps fermé à l'envers montre l'INTÉRIEUR de sa paroi
lointaine au lieu de l'EXTÉRIEUR de sa paroi proche, et un aplat non
éclairé ne distingue pas les deux. **Un comptage de pixels est un test de
SILHOUETTE, et une silhouette ne change pas sous inversion** ; seuls les
corps OUVERTS (un dessous absent) s'effondrent. C'est la règle « le nombre
d'échecs attendus fait partie de l'assertion » qui a transformé ça en
trouvaille au lieu d'un haussement d'épaules.

**Le complément, et il ferme le cas sur toute forme** : un shader encode
la profondeur en espace vue ; rendu `cull_back` un corps bien enroulé
montre sa surface **PROCHE**, rendu `cull_front` la **LOINTAINE**, et
l'inversion échange les deux. La moyenne encodée sous `cull_back` doit
donc être **plus petite** que sous `cull_front` — un **SIGNE**, sans seuil
à régler. Re-neutralisé, les **cinq** modules sortent inversés, rail
compris. Et la garde qui va avec : **asserter que les DEUX passes peignent
quelque chose**, sinon un corps disparu passe le test de signe faute
d'échantillons.

### ⚠️ LES NORMALES D'UN MAILLAGE SONT UN TÉMOIN INDÉPENDANT DE SA GÉOMÉTRIE

Écrit au CH60, et le témoin criait depuis **sept lots**. Le quarterpipe du
skatepark était construit comme sa propre **TRANSPOSÉE** : le profil livré
montait à **86,25°** là où le rider arrive et s'aplatissait à **3,75°** au
lip — une bosse convexe, pas une transition — parce que les deux
composantes d'un `Vector2` de profil étaient consommées à l'envers. Le
commentaire au-dessus décrivait la forme que le code ne construisait pas,
et nommait un centre d'arc qui n'était pas celui du cercle paramétré.

**Ce qui l'a prouvé n'est pas une relecture** : ce sont les **normales de
sommet**, écrites dans la boucle suivante et jamais touchées. Elles sont
exactement celles du profil CORRIGÉ. Mesuré facette par facette sur le
maillage livré : **86,25° d'écart** entre la normale stockée et la vraie
normale de face, **en miroir exact** — la normale stockée de la facette *k*
est la vraie normale de la facette *25 − k*. Après correction : **3,75°**,
une demi-facette, c'est-à-dire ce qu'une normale lisse contre une facette
plate DOIT valoir.

**Règle** : positions et normales d'un maillage construit par code sont
**deux lectures d'une même forme**, écrites par deux bouts de code
différents. Les confronter (`(b−a)×(c−a)` contre `ARRAY_NORMAL`, en tenant
compte de la convention horaire de ce moteur) coûte une boucle et attrape
une transposition qu'aucune relecture du profil n'attrape. Publier le pire
écart, et le gater à une **demi-facette** : au-delà, ce n'est pas de
l'ombrage lisse, c'est un désaccord.

⚠️ **Et le symptôme visuel n'est PAS celui qu'on attend.** Ce projet est
unlit — mais le shader décor est un **toon shader qui lit `NORMAL`**
(`ndl = dot(n, sun_dir)`). Le park a donc été **OMBRÉ comme un quarterpipe
tout en étant DESSINÉ comme une bosse** : la silhouette était plausible,
l'AABB juste, le compte de triangles juste, et rien ne signalait quoi que
ce soit. Corriger a coûté **une ligne** et **zéro triangle, zéro primitive,
zéro draw call** (mesuré des deux côtés) — la seule chose qui bouge est
0,4 à 0,7 % des pixels de la frame.

### ⚠️ UN TEST VALIDE SUR UNE CLASSE DE FORMES EST UN TIRAGE AU SORT SUR UNE AUTRE, ET IL NE L'ANNONCE PAS

Dix-neuvième faux-signal du dépôt, CH60, et il vivait dans une sonde que
deux lots avaient déjà signée.

`SkateparkProbe` PHASE W porte un sous-test de **signe de profondeur**
ajouté au CH53 pour combler une cécité réelle du juge CH39 : un corps
**fermé CONVEXE** rendu à l'envers couvre **exactement la même
silhouette**, donc un comptage de pixels ne peut pas le voir. Le sous-test
dit de lui-même qu'« il marche sur un corps fermé convexe ». C'est vrai —
et c'est **toute** sa validité : il suppose qu'aucune surface ne peut
tourner le dos à la caméra tout en étant **plus proche** qu'une surface de
face. Un corps **concave** casse exactement cette hypothèse.

Le jour où un module est devenu concave, il a rougi à **0,2836 contre
0,2831** : une égalité à 0,18 % publiée comme un maillage à l'envers.

**Il n'a pas été fait taire — il a été MESURÉ** (le dépôt interdit le
premier, voici ce que le second donne). Module reconstruit **à l'envers**,
les deux tests relus à **cinq stations** :

| module concave | ratio conservé | signe de profondeur, par station |
|---|---|---|
| correct | **1,0000** ×5 | ok, ok, ok, INVERTED, INVERTED |
| à l'envers | **0,575 – 0,729** | ok, ok, INVERTED ×3 |

**Les deux ensembles de verdicts SE RECOUVRENT** : le sous-test ne
distingue pas les deux cas, sa réponse suit la **STATION**. Le juge CH39,
lui, les sépare complètement — un corps **concave** ne garde pas sa
silhouette sous inversion, donc la cécité que le sous-test couvrait ne
s'applique tout simplement pas à cette forme.

⚠️ **Et ce n'était pas la forme neuve qui était spéciale.** Le même
balayage a pris le **BOL**, une cuvette concave livrée depuis CH53 et que
le lot ne touchait pas, rapportant `INVERTED` à **0,2503 contre 0,2490**
depuis une station que la sonde n'utilisait pas. **L'invalidité était déjà
dans le dépôt** ; la forme neuve s'est seulement trouvée là où elle tire.

**Règle, et elle vaut pour tout test dont la validité repose sur une
propriété de forme** (convexité, fermeture, monotonie, connexité) :

1. **La propriété se nomme dans le test**, pas seulement dans son
   commentaire.
2. **Le test publie son propre plancher** — deux lectures d'un même état,
   rien touché — et **RETURN AUCUN VERDICT** en dessous. C'est la règle
   CH56 « une sonde dont le plancher dépasse sa grandeur doit rendre une
   absence de verdict », appliquée à un signe et pas à une durée.
3. **Ce qu'il décline est passé à un autre test, et le passage de relais
   est PROUVÉ dans le même run** par une passe rouge sur cette forme-là.
   « L'autre test le couvre » est une affirmation sur une CLASSE ; elle se
   mesure sur l'OBJET.
4. **Un garde empêche « non résolu » de devenir une porte de sortie** : le
   test doit encore résoudre sur au moins un sujet, sinon l'exemption
   devient l'issue de tout le monde et le silence est revenu par la porte
   de derrière.

⚠️ **Corollaire de gate, tiré du même lot** : un objet **grimpable** ne se
gate pas sur sa hauteur **DESSINÉE**. `floor_max_angle` (45° par défaut)
décide de la dernière facette sur laquelle un corps a le droit de se
tenir : sur un quarterpipe, c'est **P6 sur 12**, soit **29 % de la montée**
— mesuré 0,582 pour un lip de 2,10 et 0,391 pour un lip de 1,45. Un gate
écrit au lip exige une performance qu'aucun corps cinématique sans inertie
stockée ne peut faire, et il n'a pas tort sur la géométrie : il répond à
une autre question.

### ⚠️ LE COMPTEUR DU MOTEUR NE COMPTE QUE L'OPAQUE, ET AU LOD QU'IL A CHOISI

`RenderingServer.viewport_get_render_info(..., PRIMITIVES_IN_FRAME)` n'est
pas « le nombre de triangles de la scène ». Mesuré au spawn du hub cozy,
trois chiffres pour la MÊME frame :

| lecture | valeur | ce qu'elle compte |
|---|---|---|
| `gpu` (compteur moteur) | **52 472** | la liste **OPAQUE seulement** — l'eau, les ombres, la pluie, les papillons sont dans la liste alpha et n'y sont **PAS** — et **au LOD que le moteur a choisi** (les GLB importés portent des LOD automatiques, et à 11,7 u de caméra il en sert un plus grossier) |
| `lod0 cadre` (replay AABB × frustum) | **102 803** | ce qui serait demandé au GPU si aucun LOD ne s'appliquait, toutes listes |
| `scene` | **175 000** environ | tous les triangles de la scène, cadre ou pas |

**Ce chiffre a réfuté une ligne déjà écrite dans ce dépôt** : un « 175 k
triangles » cité comme la charge de la frame était en réalité **52 k
primitives rendues**. Un plafond de perf gaté sur le mauvais des trois est
un plafond qui ne défend rien.

**Règle** : un plafond de charge se gate sur la ligne **`gpu`** — celle que
le device affichera — avec le replay LOD0 comme borne haute et le compte de
scène comme information seulement. Publier les trois, jamais un seul :
« le shader est cher », « le prop est cher » et « la scène est grosse » ne
sont pas la même phrase, exactement comme pour le coût par fragment.

⚠️ **Et un 0 sur cette ligne se PUBLIE comme un 0.** Le backend
Compatibility remplit ces compteurs sur GL de bureau ; rien ne garantit
qu'il le fasse sous WebGL2. Un overlay qui masquerait un 0 laisserait
croire à une frame gratuite.

⚠️ **ET IL COMPTE CE QUI EST SOUMIS, PAS CE QUI EST DESSINÉ — un objet
entièrement CULLÉ y pèse son plein tarif.** Le back-face culling est en
aval de ce compteur. Au CH39, la crête ouest soumettait ses **1 680**
triangles à chaque frame, en payait le coût, et n'en dessinait **aucun** :
la ligne de sonde « and the ridge DOES cost something (a 0 would mean it
never drew) » était **vraie** et signifiait **l'inverse** de ce qu'on y
lisait. Un delta de primitives prouve donc qu'un objet est SOUMIS ; il ne
prouve jamais qu'il est VISIBLE.

⚠️ **Corollaire, et c'est la leçon du lot** : un objet **VISUEL** ne se gate
pas sur de la géométrie et un compteur. Sept phases — containment,
raccord C0, sommets, triangulation, pentes, ligne de vue, budget, traversée
marchée — sont sorties ALL GREEN sur un relief invisible, chacune pour sa
propre raison : celles qui raycastent lisent la **grille** (une requête ne
sait rien du côté d'un triangle qui fait face à l'œil), celles qui comptent
lisent le **soumis**. **Toute sonde d'un objet destiné à être VU doit lire
au moins un PIXEL**, par une passe d'identification masquée (la cible dans
une couleur que rien d'autre ne porte, `fog_disabled`, appartenance ssi la
couleur revient exactement) — jamais une fenêtre, et jamais un seuil qu'il
faudrait re-régler à chaque station.

### ⚠️ `visibility_range_end` FONCTIONNE en Compatibility — mais seulement en `DISABLED`

Utile et non évident : le renderer Compatibility n'implémente pas le fondu
de LOD, ce qui donne l'impression que `visibility_range` n'y sert à rien.
Il sert : avec **`visibility_range_fade_mode = DISABLED`**, c'est du
**culling CPU pur**, et il fonctionne. Mesuré sur les batches du scatter :
poser `visibility_range_end` à 82 u (95 u pour les familles d'automne, dont
la bande orange fait partie du cadre du spawn par conception) a coupé la
frame de la lande de **plus de 20 000 primitives**.

Le bon réglage est celui que **le brouillard a déjà effacé** : avec
`fog_density = 0.016` exponentiel, 82 u valent 73 % d'occlusion. Couper
plus près se voit ; couper là où le fog a déjà tout mangé ne se voit pas et
se paie en frame.

### ⚠️ APRÈS `set_anchors_preset()`, `position` EST UN OFFSET DEPUIS L'ANCRE

Un `Control` ancré en `PRESET_CENTER_TOP` puis écrit `position =
Vector2(540 − 190, 150)` ne se pose pas à x = 350 : il se pose à
**540 + 350 = 890** sur un canvas de 1080, et sa moitié droite est
coupée par le bord — **sans erreur, sans warning, et invisible en
headless** (le canvas y fait 1920 de large, donc tout « tient »). Payé
sur device (V7, panneau chrono du kart lu coupé par Mathieu) et vu par
personne en sandbox pendant deux lots. Écrire l'offset (`−largeur / 2`),
et gater le rect **contre la bande de 1080 px centrée sur le milieu du
canvas**, jamais contre le canvas headless nu.

### ⚠️ UN MOT DE CONVENTION DE CÔTÉ NE VAUT RIEN SANS UNE CAPTURE

`(tan.z, 0, −tan.x)` est le côté +x d'un corps face à +z. V7 l'a appelé
« droite de la marche » ; la capture de la grille du kart (voie −3,6
dessinée sur le kerb DROIT, caméra derrière le kart) a montré que c'est
la **GAUCHE** sous cette caméra. Le nombre n'a jamais été faux (grille,
`on_track`, `lateral`, tout est symétrique), le MOT l'était — et l'IA du
lot 2 l'avait cru : biais de virage inversé, sanglier à l'intérieur,
chat à l'extérieur, aucune sonde rouge. Toute constante qui a un SENS
(intérieur/extérieur, devant/derrière, gauche/droite) se gate sur une
lecture du côté réel, jamais sur le commentaire qui le nomme.

### ⚠️ DEUX FACES COPLANAIRES QUI SE RENCONTRENT PAR LA TRANCHE DONNENT UN CONTACT DÉGÉNÉRÉ — ET SA NORMALE EST HORIZONTALE

Premier collider réel du hub (CH57), et le symptôme ne ressemble pas à sa
cause. La planche devait monter sur la funbox ; elle s'est arrêtée à
**3,72 u**, c'est-à-dire **exactement sa propre demi-longueur (0,46)**
avant le pied de la rampe. Elle ne traversait pas et ne montait pas : elle
**s'arrêtait à côté** — le troisième des trois résultats possibles, et le
seul qu'aucune assertion de HAUTEUR seule ne distingue du deuxième.

Le vidage des contacts **par tick** donne la cause en un nombre :

```
t20  pos (0.000, 0.0000, 48.2809)  floor=false wall=true
     n=(0, 0, 1) d=0.0009   n=(0, 0, 1) d=0.0001
```

La normale de contact est **`(0, 0, 1)`** — un **MUR VERTICAL** — contre
une rampe dont la vraie normale est `(0 ; 0,861164 ; 0,508327)`. Cette
vraie normale n'est apparue **qu'une frame sur trente**, noyée sous deux
contacts de mur sur la même frame.

Le mécanisme : la pièce de rampe s'effile en une **arête d'épaisseur nulle
à y = 0**, et le dessous de la boîte est une **face plate à y = 0**. Les
deux sont **COPLANAIRES**, donc la direction de translation minimale qui
les sépare est **horizontale** — et le moteur classe une pente de **30,6°**
en mur de **90°**. Ni le hull, ni l'enroulement, ni la couche de collision,
ni `floor_max_angle` n'y étaient pour quelque chose : **c'est la PLANÉITÉ
du dessous** qui l'était.

**Règle** : un corps censé MONTER une géométrie posée sur le même plan que
lui **ne peut pas avoir de face inférieure plate à ce plan**. Une capsule
couchée (ou toute forme dont le dessous est une ligne ou un point) donne
la vraie normale de pente **dès le premier contact** — mesuré, même
station, même run : `floor=true` avec `n=(0 ; 0,861164 ; 0,508327)` au
premier tick, puis 0,047 → 0,881 en quatorze ticks. Bonus non négociable
au passage : la tangente d'une capsule est à **exactement y = 0** dans
l'espace du corps, donc un corps posé sur une surface a son **ORIGINE à la
hauteur de cette surface**, sans facteur de correction — ce qui permet de
gater le trajet contre la cote **authored** de la pièce et non contre un
epsilon réglé sur l'artefact.

⚠️ **Et c'est un piège de MOTEUR, donc il ne se relit pas : il se VIDE.**
L'angle de la rampe était juste, `floor_max_angle` était juste, la sonde
était juste — et le seul instrument qui l'a nommé est l'impression de
`get_slide_collision().get_normal()` **à chaque tick**. C'est le pendant
collision de CH39 (« une assertion d'orientation ne se relit pas, elle se
rend ») : quand un moteur contredit une géométrie qu'on a vérifiée, ce
qu'il faut lire est ce que le MOTEUR a calculé, pas ce que la géométrie
dit.

### ⚠️ `Mesh.get_faces()` APLATIT TOUTES LES SURFACES — donc il annule D5

Corollaire exact de « le décor d'un solide va dans une seconde surface »,
et il vit **dans les instruments**, pas dans les assets. D5 met le coping,
les cornières et toute garniture DESSINÉE ET NON SOLIDE en surface 1
précisément pour que la surface 0 soit le solide. `Mesh.get_faces()` rend
les triangles de **toutes** les surfaces dans un seul tableau : un test
« ce point est-il dans le solide DESSINÉ ? » écrit dessus compare le
mauvais ensemble, et il le fait silencieusement.

Mesuré au CH69, sur une phase que trois lots avaient signée : le
classificateur par parité de rayon de `SkatePhysicsProbe` PHASE V lisait
`get_faces()`. Sur les quarterpipes, qui portent UN tube de coping, la
grille de 13×9×13 ne tombait jamais dedans et la phase sortait à 0
désaccord. Sur le bol, qui en porte un par secteur d'azimut, elle a rendu
**2 « dessiné seulement » et 2 « serveur seulement » sur 1 521** — quatre
échantillons qui étaient l'INSTRUMENT et pas le collider, et qui avaient
exactement la forme d'un collider troué.

**Règle** : tout test qui compare un solide au serveur de physique
reconstruit ses triangles depuis **`surface_get_arrays(0)`** et son AABB de
même. Le corollaire vaut pour l'AABB : `Mesh.get_aabb()` couvre le décor,
qui a le droit de dépasser du béton — une mesure d'emprise prise dessus
mesure la garniture.

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
* **Un `Tween` qui finit au milieu d'une frame SNAPPE à sa fin et laisse
  UNE frame courte** : un segment de 1,6 u à 10 u/s dure 9,6 frames, la
  10ᵉ ne parcourt que 0,6 frame de distance — lu `6.0` entre des `10.0`
  sur un roulement plat (CH54). À pied le rebond le cache, et c'est dans
  les chiffres de traversée publiés (le « ~1,2 % de plus que
  l'arithmétique » de `HOP_DURATION`). Mesuré : `get_total_elapsed_time()`
  INCLUT le delta entier de la dernière frame (0,16667 pour 0,16), et
  `custom_step(over)` sur le tween suivant, dans la MÊME frame, absorbe
  le dépassement. Le report ne s'applique qu'en glisse : le faire à pied
  raccourcirait chaque traversée publiée.
* **`edit/loop_mode=0` dans un `.import` de WAV ne veut PAS dire « pas de
  boucle »** — il veut dire **« Detect From WAV »**, et un WAV généré sans
  chunk de boucle retombe alors sur DISABLED. L'énumération de
  l'importeur 4.3 est `0 Detect From WAV / 1 Disabled / 2 Forward /
  3 Ping-Pong / 4 Backward` : une boucle demande **2**. Le symptôme est un
  son en boucle qui s'arrête à la fin du sample, sans erreur. Le code qui
  joue le sample **asserte** `loop_mode != LOOP_DISABLED` plutôt que de
  faire confiance au fichier `.import`, qu'un ré-import régénère.
* **`KartTouchInput.input.brake` posé UNE FOIS hors boucle ne tient pas** :
  `_physics_process` le réécrit CHAQUE frame sur l'état du clavier
  (`_brake_index < 0` → faux en headless, aucune touche pressée), donc un
  `touch.input.brake = true` posé avant une boucle d'attente est défait
  avant que le véhicule ne le lise. CH33, sur `SailBoatProbe` — deux
  assertions de frein sorties fausses avant correction. Le poser DANS la
  boucle, à chaque itération, avant l'`await` (`CoveProbe`'s propre test
  de frein du char à voile le fait déjà ainsi).

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

### ⚠️ UN SEUIL QUI NE SÉPARE PAS LE CORRECTIF DE SON ABSENCE REND UNE PASSE ROUGE VERTE

Complément exact de « le nombre d'échecs attendus fait partie de
l'assertion », et il ferme le trou que celle-là laisse : on peut prédire
le bon NOMBRE de rouges et n'en obtenir AUCUN, parce que le seuil est
plus large que l'effet.

Mesuré au CH65, deux fois dans le même lot. Un gate de dérive écrit à
25° : le correctif mesure 8,9°, sa neutralisation **19,5°** — les deux
sous le seuil, donc la passe rouge est revenue **ALL GREEN** sur un
mécanisme entièrement débranché. Un gate de plafond écrit à
`croisière × 1,02` : neutralisé, la planche atteint **10,011 u/s** contre
une croisière de 10,0 — le plafond EST franchi, et le gate ne le voit pas.

**Règle** : un seuil se choisit en mesurant la grandeur **des deux
côtés** — avec le correctif et sans — et il doit tomber **entre les
deux**, pas au-delà des deux. Un seuil rond choisi avant la passe rouge
est un seuil choisi sans la seule donnée qui le détermine. Et quand la
grandeur est un CONTRAT énoncé (« la croisière reste le plafond »), le
seuil est le contrat **littéralement**, la marge n'étant que du flottant :
10,011 n'est à l'intérieur d'aucune lecture de « plafond 10,0 ».

⚠️ **Corollaire, et c'est ce que la passe a livré de plus utile** : la
neutralisation qui revient verte dit aussi **à qui revient le mérite**.
Ici elle a montré que 75,5 → 19,5° de dérive venait d'un AUTRE changement
du même lot (la poussée déplacée sur le nez du véhicule) et que le terme
soupçonné n'achetait que 19,5 → 8,9. Sans elle, le lot aurait crédité une
constante d'une correction qu'elle n'a pas faite, et le lot suivant aurait
été surpris par ce que la retirer coûte.

### ⚠️ UN SCAN QUI REND « AUCUNE POSITION » NE DIT PAS QUEL LEVIER TIRER — IL FAUT RETIRER LES CONTRAINTES UNE PAR UNE

Écrit au CH68, et ça a réfuté un angle de brief entier **sans qu'une
ligne de code soit touchée**.

CH67 avait cherché une place pour le bol du skatepark sous trois
contraintes simultanées, n'en avait trouvé aucune, et l'avait rapporté
honnêtement. Le lot suivant a donc hérité d'un ensemble vide — c'est-à-dire
d'**aucune direction** : rien dans « aucune position » ne dit laquelle des
trois contraintes est le mur, et le brief de CH68 a naturellement désigné
la plus spectaculaire (la retombée du grand quarterpipe) comme celle à
desserrer.

Le même balayage, relancé en **retirant chaque contrainte à son tour**,
répond en une colonne :

| on retire | positions restantes |
|---|---|
| le chevauchement | **2 071** |
| l'emprise du parking | 56 |
| **la retombée** | **56** |
| la région | 56 |
| **la dalle du park** | **4 489** |

**Retirer la retombée ENTIÈREMENT ne change rien : 56 avant, 56 après.**
L'angle qui allait coûter un lot — ajuster une trajectoire de pop sans
casser un modèle validé device — n'ouvrait **pas une seule position**. Ce
qui contraignait était ailleurs, et la même colonne le nomme.

**Règle** : un balayage sous N contraintes publie **N+1 comptes** — le
compte global et le compte en retirant chacune. Un ensemble vide est un
RÉSULTAT ; « laquelle le rend vide » est le résultat UTILE, et il coûte
une boucle de plus sur des candidats déjà calculés. Corollaires payés dans
le même lot :

* **une contrainte qui ne retranche rien doit être dite inactive**, sinon
  elle se transmet de brief en brief comme si elle coûtait quelque chose ;
* **une contrainte que le lot précédent n'a pas énoncée peut être LE mur**
  (ici la dalle de béton : 56 avec, 4 489 sans) — donc énumérer d'abord ce
  que la chose doit satisfaire, et seulement ensuite balayer ;
* et **un seuil de contrainte se mesure d'abord contre l'ÉTAT LIVRÉ**. La
  première rédaction de « le bol tient sur sa dalle » **condamnait le bol
  expédié**, qui déborde déjà de 0,100 u. Un seuil qui refuse ce qui tourne
  aujourd'hui ne prouve pas moins que rien : il prouve à l'envers, et tout
  ensemble vide qu'il produit est un artefact.

### ⚠️ UN BANC QUI GARE UN CORPS SANS DIRE DANS QUEL SENS MESURE UNE COURBE

Gratuit tant qu'un corps s'oriente instantanément ; faux le jour où
quelque chose borne son taux de rotation — et ce jour-là il ne se
signale pas, il rend des chiffres plausibles.

Mesuré au CH65 sur **trois bancs distincts**, tous écrits quand la
planche prenait le cap du doigt en une frame. `SkateInertiaProbe` gare nez
au nord et vise le sud : le run-up **authored à 3,20 u** a mesuré
**9,798 u**, parce que le trajet était devenu un demi-tour de 2,1 s suivi
d'un arc. `SkatePhysicsProbe` posait `rotation.y = 0` pour toutes ses
courses : celles qui arrivent par l'est ont lu la face de la funbox à
**x = −8,03** au lieu de 2,20, et un run neutralisé est passé à **3,009 u**
d'un volume qu'il devait traverser — deux lectures qui ressemblent
exactement à des défauts de collider.

**Règle** : un banc qui pose un corps et l'envoie quelque part **dit son
orientation de départ**, au même titre qu'il dit sa position. Le
corollaire vaut pour tout ce qui devient une variable le jour où une
contrainte apparaît : ce qu'un banc n'énonce pas, il l'hérite.

⚠️ **Et sous une caméra de POURSUITE, un doigt tenu à contre-sens n'est
pas un demi-tour, c'est un CERCLE** — la caméra lace avec le corps, donc
le cap demandé tourne avec le nez et il n'existe aucun point fixe où
arriver. Tracé tick par tick au CH65 : (0,0,−1) → (1,0,−1) → (1,0,0) →
(0,0,1). Un banc qui gate « la distance parcourue à contre-sens » gate un
ARC, et il a rapporté 10,467 u sur un corps qui faisait exactement ce
qu'il fallait. Ce qui se gate est la propriété réelle — ici « il ne dépense
pas sa poussée tant qu'il est pointé ailleurs » — lue sur une fenêtre où
elle a un sens.

### ⚠️ UNE CONSTANTE DÉRIVÉE D'UN LAYOUT FAIT D'UN DÉPLACEMENT DE PROP UN CHANGEMENT DE TOUCHER

Ce dépôt préfère partout une constante **dérivée** à une constante tapée,
et il a raison : « déplace un module et ceci suit ; retape-le ici et ça ne
suit pas ». Le prix de cette vertu n'avait jamais été écrit — une dérivation
est un CANAL, et un canal transporte aussi ce qu'on ne voulait pas envoyer.

CH67 l'avait rencontré et n'avait pas pu le nommer : il signale que
« déplacer le bol — sa POSITION seule, `pieces_for` remis à vide — déplace
les vitesses d'arrivée de `SkateInertiaProbe` PHASE E de +0,13 u/s sur les
quatre échelons », isolé par élimination, « le mécanisme n'est PAS
établi ». **CH69 l'établit, et la chaîne fait trois appels** :

```
HubSkatepark.park_span()          # la plus grande paire de modules
  -> HubTransport.skate_coast_u() # ... est la distance de roue libre
    -> SkateBoardBody.configure() # ... d'où la décélération est RÉSOLUE
```

Déplacer un module change la paire la plus large du park, donc la distance
de coast, donc la décélération, donc la vitesse à laquelle la planche
ARRIVE partout. Mesuré aux deux bouts d'un lot de layout : `park_span`
**18,043 → 23,201 u (+28,6 %)**, arrivées `2,98/5,09/7,02/8,97` →
`3,21/5,28/7,27/9,19 u/s`, et la retombée du grand quarterpipe déplacée de
**1,27 u**. Aucune ligne de conduite n'a été touchée.

**Règle** : un lot de LAYOUT publie ce que ses déplacements font aux
constantes dérivées — la liste se trouve en greppant les accesseurs que le
layout publie — et il mesure la grandeur d'aval **aux deux bouts**. Une
sonde ne signe pas un ressenti (CH62) : ce genre de propagation se NOMME
dans le rapport et se valide device, jamais en vert de banc.

⚠️ **ET LE COROLLAIRE DE MÉTHODE : UN OPTIMUM SE POSE EXACTEMENT SUR LA
CONTRAINTE QUI LE BORNE.** Un balayage qui minimise un coût rend, par
construction, un point à distance ZÉRO de sa contrainte active — et si
cette contrainte est aussi un GATE, le gate naît sur sa propre limite.
Mesuré dans le même lot : la place retenue pour un prop est sortie à
**13 millimètres** de la contrainte de séparation des disques de score,
c'est-à-dire verte et sans marge. La parade est d'optimiser contre la
contrainte **majorée d'une marge PUBLIÉE et argumentée** (ici
`KeepyHopper.ARRIVE_EPSILON`, la distance à laquelle une glisse se
termine) : le minimum se déplace de 0,75 u, coûte le même béton, et le
gate cesse d'être un tirage au sort.

### ⚠️ UN ÉTALON QUI PARTAGE LE CONTRÔLEUR DE CE QU'IL MESURE NE MESURE RIEN

Le banc de difficulté du karting a été vert pendant tout un lot sur une
course que Mathieu gagnait d'un tour. La cause n'était ni un seuil, ni une
constante : le « pilote humain de référence » contre lequel la difficulté
était calibrée était **un profil du même contrôleur que les adversaires**,
avec le même profil de vitesse, tiré de la même table. Mesuré : il tournait
**24,400 s contre les 23,350 s de l'adversaire qu'il mesurait**.

Un dénominateur pris DANS la population qu'il évalue ne peut pas voir que
cette population est lente — il bouge avec elle. Le banc ne mentait sur
aucun de ses chiffres ; il répondait à une autre question que celle posée.

**Règle** : un étalon de difficulté, de performance ou de confort est
construit **contre un modèle qui ne partage pas le mécanisme évalué**, et
on le vérifie en le faisant tourner sur le même banc que la population :
s'il se classe au milieu, il n'est pas un étalon, il est un concurrent.
Corollaire du même lot : un « plancher physique » dérivé de ce même
contrôleur n'était pas le plancher du CIRCUIT mais celui du MODÈLE DE
CONDUITE — 21,633 s annoncés contre 18,583 s réellement pilotés, et
12,111 s de plein gaz géométrique. **Un plancher se PILOTE, il ne se
déduit pas** : le plus grand facteur d'allure qui tienne encore la piste.

### ⚠️ UNE SIMULATION À LATENCE PARFAITE MENT, ET ELLE MENT DANS LE BON SENS

Un modèle de joueur qui décide à 60 Hz et dont les commandes arrivent au
même frame n'est pas un joueur lent-mais-propre : c'est un **asservissement
sans retard**, et un retard dans une boucle de contre-réaction est ce qui
produit la sur-correction qu'un vrai pouce produit. Mesuré : couper la
ligne à retard du même modèle déplace la médiane de **1,383 s au tour** et
supprime complètement le louvoiement.

**Règle** : tout modèle de joueur porte une latence et un bruit gaussien,
la latence est tirée **une fois par RUN** (c'est une propriété des mains et
du téléphone ; la re-tirer chaque frame la moyenne et la fait disparaître),
et le résultat se publie en **DISTRIBUTION** sur n ≥ 300, jamais en un
tour. Et le banc **prouve d'abord que la latence est câblée** — une
population témoin à latence nulle doit sortir mesurablement plus rapide —
sans quoi chaque chiffre produit par cet étalon passe gratuitement contre
une ligne à retard jamais branchée.

### ⚠️ UN PROFIL CALCULÉ SUR UNE GÉOMÉTRIE QUE L'ACTEUR NE SUIT PAS

Le profil de vitesse des adversaires était bâti sur la courbure de l'axe du
circuit pendant qu'ils roulaient sur une ligne décalée jusqu'à 3,9 u — sur
un ruban de 10 u. Conséquence mesurée : **tout le plateau était épinglé au
même 4,17 u/s** au virage le plus serré, y compris le profil dont les pneus
ne lâchent jamais. Aucune erreur, aucun avertissement : juste un plafond
partagé que personne n'avait cherché.

**Règle** : une limite dérivée d'une géométrie (courbure, longueur d'arc,
pente) se calcule sur **la géométrie effectivement parcourue**, et le plan
qui la définit doit être **atteignable** par le taux auquel l'acteur peut
s'y rendre — sinon le profil promet un rayon qui n'existe pas. Corollaire
payé dans le même lot : un paramètre de trajectoire réglé à l'époque où le
profil ignorait la ligne devient **faux** dès que le profil la regarde (un
balancement de ligne était gratuit, il ne l'est plus), et il inverse la
personnalité qu'il était censé porter.

### ⚠️ UN TEST DE SIGNE NE VOIT PAS QUELLE BRANCHE A TOURNÉ

Mesuré au CH43, sur la passe rouge d'un garde-fou. Le contrat était « un
glissement vers le bas sur un véhicule lancé FREINE, il ne bascule pas en
marche arrière », et l'assertion évidente — « aucune vitesse négative avant
l'arrêt » — est restée **VERTE sur du code dont le garde-fou avait été
entièrement supprimé**.

La raison est arithmétique et elle se généralise : les deux branches
descendaient toutes les deux, simplement à des taux différents (le frein à
15,0 u/s², la rampe de marche arrière à 6,0). Un véhicule sans garde-fou ne
passe **toujours pas** négatif avant d'avoir traversé la bande — il met
seulement deux fois et demie plus longtemps. Le SIGNE de la valeur ne
distingue donc rien du tout, et il n'y avait rien de faux dans la mesure : elle
répondait à une autre question que celle posée.

Ce qui l'a attrapé : prédire, pour chaque frame, ce que **chacune** des deux
branches aurait produit à partir de la vitesse d'entrée, et exiger que la
sortie corresponde à l'une d'elles à 1e-4 près — donc classer la frame par
l'ARITHMÉTIQUE et non par le résultat. Le même instrument encadre alors le
seuil gratuitement (la dernière frame d'une branche et la première de l'autre),
ce qui est comment CH43 a mesuré `REVERSE_ENGAGE_SPEED` sur le véhicule au lieu
de le relire dans la constante — et la passe rouge le prouve : branche gatée à
0,9 avec la constante lisant toujours 0,3, l'encadrement mesuré **s'est déplacé
à 0,9**.

**Règle** : quand ce qu'on veut prouver est « c'est CE chemin qui a tourné »,
gater sur la valeur observable (un signe, un minimum, une distance) est un
proxy, et un proxy qui passe gratuitement dès que les deux chemins partagent la
direction du résultat. Prédire les deux et exiger la correspondance. Corollaire
de sûreté : la classification doit pouvoir répondre **« ni l'un ni l'autre »**
(compter ces frames et gater à zéro), et refuser de classer quand les deux
prédictions sont plus proches que le bruit — sans quoi un jour où deux taux
coïncident, chaque verdict devient un tirage au sort publié comme une mesure.

### ⚠️ UNE ASSERTION SUR UNE VALEUR TENUE PEUT RELIRE L'ASSERTION PRÉCÉDENTE

Seizième faux-signal du dépôt, CH43, et il vivait **dans la sonde**. Un
`KartInput` est une valeur TENUE par conception (personne ne l'efface entre
deux événements), et une phase qui vérifie une suite de gestes sur un même
écrivain hérite donc, à chaque assertion, de ce que la précédente a laissé.
La dernière vérification souris lisait un `reverse` que la vérification du
bouton droit, deux lignes plus haut, avait laissé à 1,0 — elle est passée
VERTE contre l'écrivain qu'elle était censée refuser.

**Règle** : toute assertion sur un état TENU (un input, un drapeau de mode, un
registre de sauvegarde) porte son propre remise à zéro **gatée** — écrire zéro
ne suffit pas, il faut asserter qu'on l'a lu à zéro — juste avant le geste qui
doit l'écrire. Et c'est la **passe rouge** qui a trouvé celui-ci, pas une
relecture : une neutralisation ne teste pas seulement le correctif, elle teste
la sonde.

### ⚠️ `%e` N'EST PAS UNE CONVERSION `%` DE GDSCRIPT, ET L'ÉCHEC EST SILENCIEUX CÔTÉ APPELANT

`"%.2e" % x` pousse `unsupported format character` sur **stderr** et rend une
chaîne qui n'est pas celle qu'on a écrite — mesuré au CH43 : deux assertions
ont imprimé le message d'une AUTRE assertion, avec leur booléen pourtant
correct. Un rouge portant le libellé d'un autre contrôle est pire qu'un rouge
muet : il envoie diagnostiquer la mauvaise chose. Les conversions sûres sont
`%d`, `%f`/`%.Nf`, `%s`, `%x` — et une sortie de sonde se relit une fois pour
vérifier que chaque libellé correspond à son test.

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

### ⚠️ UN SEUIL SUR UNE GRANDEUR QUI N'EXISTE QUE SI UN ÉVÉNEMENT A EU LIEU PASSE GRATUITEMENT QUAND IL N'A PAS EU LIEU

Cousin du blind check, et il ferme un trou que celui-là laisse : le blind
check demande à une assertion d'ÉGALITÉ ou d'ABSENCE de prouver qu'elle
sait voir. Celui-ci vise une assertion de VALEUR — et la valeur en question
est **conditionnée par un événement**, si bien que sa valeur par défaut
tombe du bon côté du seuil.

Mesuré au CH69, dans la sonde du lot. Le contrat était « la planche entre
dans le bol EN ROULANT, elle ne saute pas par-dessus la lèvre », et
l'assertion « la hauteur au franchissement du rim est ≤ 0,02 ». La sonde
notait cette hauteur en repérant la frame où le rayon passe sous celui du
rim ; **quand le franchissement n'arrive jamais**, la variable restait à sa
valeur initiale et la sonde imprimait `y au rim 0,0000` — c'est-à-dire le
verdict le plus vert possible pour un run où la planche s'était arrêtée
dehors.

**Règle** : toute grandeur qui n'a de sens qu'APRÈS un événement se publie
avec le booléen « l'événement a eu lieu », et le gate exige **les deux**.
La forme se reconnaît à un initialiseur : `var t := -1`, `var y := 0.0`,
`var best := INF` — si la valeur initiale satisfait le seuil, l'assertion
ne teste rien. (C'est la même famille que « une moyenne qui décrit un ÉTAT
se prend sur la fenêtre où cet état tient » : une mesure prise là où son
sujet n'existe pas n'est pas une mesure.)

### ⚠️ UN DELTA « AVEC / SANS » NE VAUT RIEN SANS LE PLANCHER DE BRUIT DU BANC

Onzième faux-vert du dépôt (CH40), et c'est le **complément exact** du blind
check : celui-là ferme les assertions d'ÉGALITÉ et d'ABSENCE, celui-ci ferme
les assertions de PRÉSENCE mesurées par une DIFFÉRENCE.

La forme est partout dans ce dépôt : « cacher l'objet, relire la MÊME frame,
la différence est son coût ». Mesuré : avec la passe qui plante les props
neutralisée, la liste des nœuds à cacher était **VIDE**, donc l'étape
« cacher » ne cachait **rien** — et le compteur bougeait quand même de
**+64 primitives** entre deux lectures. L'assertion « l'objet coûte quelque
chose (un 0 voudrait dire qu'il n'a jamais été dessiné) » est donc revenue
**VERTE sur une colline nue**. Le compteur n'était pas faux ; il n'était
simplement **branché sur rien**.

Deux gardes, et il faut les deux :

1. **Asserter qu'il y a quelque chose à éteindre** — `nodes.size() > 0` — au
   même titre qu'on asserte qu'un compteur est rempli.
2. **Publier le plancher de bruit du banc** : deux lectures de plus au même
   poste, **rien touché**, et exiger que le delta le dépasse. Mesuré ici
   jusqu'à **140 primitives** d'écart à la caméra haute contre un signal de
   1 854 — sans ce chiffre, aucun delta inférieur à 140 n'est un résultat.

C'est la même exigence que « publier le SPREAD à côté de la moyenne » pour
un banc de coût de shader, et pour la même raison : **le plancher de bruit
est la seule chose qui dise si un écart est un effet ou un artefact.**

### ⚠️ UNE LISTE DE CE QUI N'EST PAS LE SUJET EST FAUSSE AU PREMIER NOM OUBLIÉ

Corollaire de « un fait est publié une fois, jamais recopié », côté LECTEUR.
Une sonde qui devait compter le décor au sol a d'abord listé les nœuds qui
**ne sont pas** du décor pour compter tous les autres. Elle disait
`"Butterflies"` ; le nœud s'appelle `"Butterflies1"`. Un essaim volant à
1,06 u au-dessus de la colline a donc été compté comme du décor **enterré**,
et la sonde est sortie rouge sur du code correct.

**Le producteur publie ce qu'il a construit ; le lecteur ne le reconnaît
jamais.** Ici `CozyScatter.batch_nodes()` rend la liste que `_flush` a
réellement bâtie. Une liste d'exclusion est un pari sur l'exhaustivité d'un
inventaire fait ailleurs, et elle a tort le jour où quelqu'un ajoute le
douzième nœud — silencieusement, et dans le sens qui invente une régression.

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

### ⚠️ UN `float` GDSCRIPT EST UN FLOAT64, `rotation.y` EST UN FLOAT32

Trouvé au CH30 en extrayant la cinématique du kart dans un composant
partagé, sur une extraction qui devait être — et qui est — un
**déplacement pur**. Les statements étaient les mêmes, dans le même
ordre, sur les mêmes valeurs. La trace divergeait quand même : dernier
chiffre imprimé dès la frame 30, **0,070 u à la frame 1200**, et 17 ms sur
trois tours.

La cause n'est pas un algorithme, c'est un **TYPE**. `rotation.y` est une
composante de `Vector3`, donc un **float32** dans un build simple
précision (celui de Godot officiel, et celui du web) : `rotation.y -= x`
**tronque à 32 bits à chaque frame physique**, et l'a toujours fait. Un
`float` GDScript est un **float64**. Porter la même valeur dans une
variable locale garde donc silencieusement 29 bits que le code livré
n'avait jamais eus.

Sur une boucle qui reboucle (une poursuite pure : le braquage écrit la
trajectoire, la trajectoire écrit le braquage), ce bit se voit en trente
frames. **Parade** : écrire la valeur à travers une composante de
`Vector3` (`_yaw32.y = ...; yaw = _yaw32.y`), qui tronque exactement là
où le nœud le fait.

⚠️ **Et c'est pourquoi une extraction se prouve par TRACE et jamais par
relecture de diff.** Aucune lecture du patch ne pouvait montrer ça : la
question n'était pas dans la source, elle était dans le moteur.

### ⚠️ UN CHIFFRE FANTÔME SURVIT AUX SESSIONS — le rayon de structure est 1,932 u

Un « **4,03 u**, déjà mesuré sur `DivingBoard` » a été transporté de brief en
brief pendant **plusieurs sessions**, présenté comme un acquis. **Grep
exhaustif du dépôt — `.gd`, `.md`, `.tscn`, `.json` : ZÉRO occurrence.** Il
n'a jamais existé nulle part. Le seul rayon jamais publié pour cette famille
est **1,932 u**, mesuré sur l'arbre construit, deux fois, dans deux sessions
différentes.

Ce que le fantôme aurait coûté : au point P1 de la tyrolienne, une emprise de
4,03 u mordait de **1,9 u** dans le décor voisin — et rien dans ce moteur ne
se plaint qu'un prop en chevauche un autre. Le premier symptôme aurait été
une capture d'écran sur device.

**Un chiffre qui n'a pas de SOURCE dans le dépôt n'a pas de valeur, quel que
soit le nombre de briefs qui le répètent.** Un chiffre répété est un chiffre
répété, pas un chiffre mesuré : le grep qui le cherche coûte une commande, et
le seul chiffre utilisable est celui qu'on peut rouvrir à l'endroit où il a
été mesuré. Corollaire du même lot : une expression fermée « évidente » pour
un rayon circonscrit s'est révélée fausse de **3 cm** parce qu'elle oubliait
qu'une pièce INCLINÉE pose au sol un coin plus reculé que sa projection
droite — trouvé par une sonde qui mesure les **huit coins transformés** de
chaque pièce dessinée, jamais par relecture de la formule.

### ⚠️ UN COÛT MESURÉ NÉGATIF N'EST PAS DU BRUIT — C'EST UN CONTRÔLE FAUX

Un banc qui rend une charge de travail **plus rapide que son témoin** ne
mesure pas ce qu'il croit. Deux versions consécutives d'un banc de coût de
shader l'ont fait, avec **deux causes différentes**, et c'est le signe
négatif qui a livré les deux :

1. **Le témoin ombrait plus de fragments que le candidat.** Les shaders
   mesurés `discard` la moitié de leur quad, le témoin couvrait tout : le
   banc comparait de la **COUVERTURE**, pas du coût — et flattait
   précisément le candidat à la silhouette la plus découpée. Parade :
   neutraliser les `discard` **dans la source livrée** (remplacement
   textuel), pour que toutes les passes ombrent le même nombre de
   fragments.
2. **Le témoin était un AUTRE PROGRAMME.** Un `StandardMaterial3D` compile
   le programme spatial complet de Godot ; un candidat écrit en
   `shader_type spatial; render_mode unshaded` est un programme minimal.
   « Le même dessin sans les maths » n'était donc pas le même dessin.
   Parade : **construire le témoin DEPUIS la source livrée** — le vrai
   shader, corps de `fragment()` remplacé par une écriture constante,
   mêmes `render_mode`, même `vertex()`, mêmes uniformes. Le delta est
   alors exactement les maths.

**Et publier le SPREAD à côté de la moyenne.** Trois passes par candidat :
le plancher de bruit du banc est la seule chose qui dise si un écart entre
deux candidats est un effet ou un artefact. Mesuré une fois : des maths de
+1,058 / +1,248 / +1,622 ms séparées du témoin, mais **PAS séparables
entre elles** derrière un plancher de 0,712 ms. Un classement aurait été
inventé ; « ce banc ne les sépare pas » est le résultat.

⚠️ **Et un coût par fragment ne devient un coût par frame qu'une fois
multiplié par la COUVERTURE RÉELLE.** Le même shader à 4-6 ns/fragment
coûte **0,015 ms** sur un prop qui occupe 0,16 % de l'écran et serait une
tout autre facture en plein cadre. Publier les deux, jamais le premier
seul : « le shader est cher » et « le prop est cher » ne sont pas la même
phrase.

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

### ⚠️ UN BRAQUAGE TENU DESSINE UN CERCLE, ET UN CERCLE FINIT OÙ IL COMMENCE

Écrit au CH42, et c'est une mesure de « est-il bloqué ? » qui a fabriqué
**quatre fausses épingles** avant d'être vue. La sonde notait « bloqué » par
la **distance au point de départ après 600 frames**. Tracé : l'échantillon
qui « a parcouru 0,570 u en 10 s » passe 4,7 s sur son mur, se dégage,
parcourt une boucle de **36,7 u à 352,7° de braquage tenu**, et **revient
exactement d'où il part**. Un véhicule libre et un véhicule épinglé rendent
alors le même chiffre.

**Règle** : un run se note sur la **PREMIÈRE FRAME où il atteint un rayon
d'échappement** — le plus loin qu'il soit allé et en combien de temps —
jamais sur l'endroit où il se trouve quand le chronomètre s'arrête. La
famille est plus large que le braquage : toute trajectoire bouclée (orbite,
va-et-vient, pendule) a cette propriété, et une position finale ne distingue
pas « il n'a pas bougé » de « il est revenu ».

⚠️ **Et le corollaire a coûté deux versions de la même phase** : une moyenne
qui décrit un ÉTAT (« sur le mur ») doit être prise **sur la fenêtre où cet
état tient**, jamais sur le run entier. Moyennée sur tout le run — donc
majoritairement sur la boucle libre à 6 u/s — la vitesse avant donnait un
gain de braquage de **0,59 à 0,67**, un nombre qui dit que le véhicule braque
parfaitement bien, pris sur les secondes où il n'est pas bloqué. **Une cause
mesurée sur des frames qui ne sont pas une instance de l'effet n'est pas une
cause.**

### ⚠️ LE GAIN DE BRAQUAGE EST PROPORTIONNEL À `v_fwd`, DONC UN MUR SUPPRIME LA DIRECTION

`VehicleDrive` fait tourner le cap à `|v_fwd| / steer_full_speed` de la
vitesse de lacet pleine — **`v_fwd`, la composante AVANT, pas la vitesse**.
Contre un mur, la composante avant est exactement ce que le mur mange : le
véhicule peut glisser le long du bord à 1 u/s en n'ayant que 0,08 u/s
d'avant, et **braque alors à 2,8 % du braquage à fond**. Mesuré au CH42 sur
la crête ouest : 600 frames de braquage à fond, excursion maximale **1,04 u**,
contre **59 frames** pour parcourir 4 u en terrain libre.

Ce n'est **pas** un défaut de mur — le prédicat de bornage a été vérifié
correct sur 28/28 points intérieurs et 28/28 points extérieurs — et ce n'est
pas non plus un coin étroit : le coin est inéchappable **parce que le lacet
y est nul**. Rien ne le signale : ni erreur, ni sonde rouge.

**Conséquence permanente** : tout véhicule de ce dépôt a besoin d'un input
qui produise une vitesse **NÉGATIVE** — c'est la seule commande qui rende de
l'autorité de braquage contre un mur. C'est la troisième fois que ce dépôt
paie la même arithmétique (`SandYacht._wall` étape 3, l'ordre force/`step()`
du CH41, et ceci) ; les deux premières fois elle a été traitée comme un
accident local.

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

### ⚠️ UN CORPS QUI QUITTE LE SOL N'EST PLUS LÀ OÙ ON LE TAPE — la parallaxe est mesurée

`HubCamera` ne monte **jamais** (`OFFSET` est une constante et elle suit le
point SOL) et **tout tap se résout sur `HubSurface`**. Un corps qui se tient
**au-dessus** du plan de sol est donc **DESSINÉ** là où le sol sous lui n'est
pas, et l'écart grandit avec la hauteur. Mesuré au CH58 sur la planche :

| station | où se résout un doigt visant ses pieds dessinés |
|---|---|
| sol plat | **0,133 u** |
| deck de la funbox (0,85 u) | **1,501 u** |

contre un rayon de self-tap de **0,90 u**. Donc « taper sur soi pour
descendre » marchait sur la pelouse et **ne marchait pas sur le seul module
que le chantier existe pour grimper** — sans erreur, et sans qu'aucune sonde
le voie, parce que la sonde tapait la position **PLATE**, c'est-à-dire une
question qu'aucun doigt ne peut poser (la forme exacte du hotspot du lit :
« la métrique peut être la mauvaise, et le chiffre vert avec »).

**Règle** : tout test « ce tap le désigne LUI » lit le point **DESSINÉ** —
le rayon caméra à travers sa position réelle, rencontré avec `HubSurface` —
jamais sa position plate, dès lors que le corps peut se tenir au-dessus du
sol. C'est la règle AIM appliquée au CAVALIER au lieu d'un prop : seule la
**destination** reste clampée. Un véhicule qui ne quitte jamais le sol n'en
a pas besoin (le sautillon lit toujours le plat, délibérément) ; **le jour où
un véhicule livré peut se tenir sur quelque chose, il y entre.**

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

⚠️ **ET SA PORTÉE EST EXACTEMENT LE ROUTAGE DU TAP — RIEN D'AUTRE**
(recon tyrolienne, 3 septembre 2026, ambiguïté levée sur demande). Le patron
ÉCHELLE nomme **un canal de tap dédié, émis inconditionnellement, dont
l'écouteur jette le signal**. L'interdiction atteint donc **ce qui possède un
canal de tap**, et seulement cela : un escalier, une passerelle, une rampe
que le personnage GRAVIT dans une chorégraphie n'émet aucun signal, n'a pas
d'`is_available()` à mal câbler, et **ne peut pas être un patron ÉCHELLE** —
c'est la même classe que les barreaux du plongeoir, de la géométrie le long
de laquelle un corps est ÉCRIT.

⚠️ **MAIS UNE INTERACTION MULTI-TEMPS REFAIT LE SYMPTÔME SANS LE NOM.**
Tourniquet, balançoire et hibou partagent « taps pendant : interceptés,
jamais une destination ». Reprendre ça sur une séquence de plusieurs
secondes (marcher jusqu'au pied → monter → attendre un second acteur →
voyager) rend au joueur une fenêtre entière où **chaque tap est jeté**.
**Le rejet n'est légitime que quand le trajet est BORNÉ par un tween qui se
termine toujours à un point connu** — c'est ce que « une planche dont le seul
autre sens est déjà traité par état » dit réellement, et c'est la seule
raison pour laquelle la branche hibou a le droit de ne rien faire. Toute
phase NON bornée (une marche d'approche) doit rester une phase où le tap
retombe et **annule l'intention**.

### ⚠️ UN ÉTAT PARTAGÉ N'EST PAS UNE PERMISSION PARTAGÉE — le PATRON ÉCHELLE s'atteint PAR HÉRITAGE

Écrit au CH58, après que le patron interdit ait été **expédié sur device**
sans que personne ne l'écrive. `ON_CARRIER` a cinq usagers ; la licence de
**JETER** un tap n'en est pas une propriété. `CLAUDE.md` ne l'accorde qu'à un
trajet **BORNÉ** — « un tween qui se termine toujours à un point connu » —
et la montgolfière, la tyrolienne et la boucle du hibou le sont. La planche
physique du CH57 ne l'est **pas** : elle reste immobile sous le joueur
jusqu'à ce qu'il en décide. Elle a hérité du `return` de la montgolfière
**parce qu'elle passe par le même état**, et la branche que CH57 lui avait
écrite — correcte en elle-même — vivait **quarante-sept lignes plus bas**,
donc en code mort. Sur device : mount normal, puis **plus un seul tap reçu**,
aucune erreur, le menu toujours réactif. Sortie par rechargement de page.

**Aucun des deux fichiers lu seul ne le montrait**, et c'est ce qui rend le
piège général : un `return` correct dans son contexte devient un avaleur de
taps dès qu'un second usager arrive dans l'état, et le nouvel usager n'a
aucune raison de relire le garde d'un autre.

**Règle** : tout garde qui JETTE une entrée se teste sur la **LICENCE**, pas
sur l'ÉTAT — la condition s'écrit avec la propriété qui l'autorise
(« le trajet est-il borné ? »), et l'exception porte le renvoi croisé vers
la branche qu'elle débloque. Corollaire de contrôle : quand la branche d'un
prop est plus bas dans le même `match` d'états qu'un `return` qui peut la
précéder, **elle est présumée morte jusqu'à ce qu'une sonde la traverse
par le vrai canal**.

### ⚠️ ET LA SONDE DU LOT NE POUVAIT PAS LE VOIR — elle appelait l'API, jamais le canal

Dix-huitième faux-signal du dépôt, et le complément exact de « un fixture
qui diverge du réel sur un axe ne protège pas de cet axe ». `SkatePhysicsProbe`
est sortie **43 assertions vertes** sur une planche dont **aucun tap
n'arrivait**, parce qu'elle la conduit par `mount_board()` et
`set_board_target()` **en direct** : le chemin de tap livré — le seul qu'un
joueur possède — est hors de tout ce qu'elle mesure. L'axe n'était ni la
géométrie, ni la physique, ni le rendu : c'était le **ROUTAGE**.

**Règle** : une sonde qui gate une INTERACTION entre par le canal du joueur
— le signal réel sur le nœud réel, et au moins une phase depuis une **vraie
coordonnée écran** — et n'appelle l'API du prop que pour LIRE le résultat.
Une sonde qui appelle la fonction qu'un tap aurait appelée mesure la
fonction, pas l'interaction, et les deux ne tombent jamais en panne
ensemble.

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

### ⚠️ UN TIRAGE AJOUTÉ DANS UN FLUX RNG PARTAGÉ DÉPLACE TOUT CE QUI SUIT

CH53, et le symptôme était à soixante unités du code modifié. Une garde de
densité posée sur les cellules NORD a été écrite sur le patron de la garde
de domaine voisine — `if ... and _rng.randf() > KEEP: continue`. Correcte,
bornée au nord, et pourtant la frame du **SPAWN** est sortie à **+308
primitives** contre la référence.

La cause n'est pas dans ce qui a été rejeté : c'est que **consommer un
`randf()` de plus sur un candidat déplace le flux pour TOUS les candidats
suivants**, où qu'ils tombent. Le tapis du sud n'a pas été aminci — il a
été **rebattu**. Rien n'était faux ; ce n'était simplement plus le même
tapis, et la comparaison croisée sur laquelle reposait le financement du
lot était polluée par un terme que personne n'avait demandé.

**Parade** : une décision de garde qui doit rester locale se prend sur un
**hachage de la position** et ne touche pas le flux — le patron que
`CozyScatter._cell_variant` utilisait déjà pour choisir une variante.
Mesuré : le spawn est passé de **+308 à −23** et le sud est redevenu
byte-identique. Le résidu de −23 vient d'un `footprint` neuf qui rejette
des candidats (donc leur saute deux tirages), et **ça, c'est irréductible**
— tout prop ajouté dans ce hub l'a toujours fait.

⚠️ **Corollaire de méthode** : quand un lot mesure un delta entre deux
arbres, une station **hors du sujet** (ici le spawn) est le témoin qui
révèle ce genre de fuite. Ne jamais ne mesurer que les stations que le lot
prétend améliorer.

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

### ⚠️ UN POINT SOL S'ÉCRIT `(x, h, z)`, ET IL A UNE SEULE ORTHOGRAPHE

Corollaire direct de la règle ci-dessus, écrit au CH37 quand le hub a
cessé de supposer que le sol est à `y = 0`. `HubSurface.ground(flat)`
publie le point sol ; **aucun site ne compose `height_at` avec un
`Vector3(x, h, z)` écrit à la main**, pas plus qu'on ne recopie un rayon.
La règle est uniforme et sans exception utile : **aucun littéral `0.0` de
ligne de base ne survit** dans un fichier qui écrit une position au sol —
y compris là où la valeur est morte aujourd'hui, parce que c'est
exactement le littéral qu'un lot ultérieur oubliera.

⚠️ **Et un point sol N'EST PAS un vecteur de déplacement.** Le premier
plan de bascule gardait `_target` porteur de sa hauteur et `here` plat, en
appelant leur différence « un delta XZ ». Ça ne tient pas : le delta gagne
un `y`, le pas se raccourcit sur une pente — or `HOP_DISTANCE`, la
diagonale à 66 hops et toutes les mesures de traversée de ce dépôt sont
des distances **XZ** — et surtout **le test d'arrivée cesse de
fonctionner** : `here` étant plat, une cible 3 u plus haut garde un
`delta.y` de 3 pour toujours et la marche **ne se termine jamais**. Un
delta se prend entre deux points de la MÊME nature, et une composante
verticale qu'on ne veut pas se jette **explicitement**, jamais par
omission. Le défaut est **inerte tant que `h ≡ 0`** : c'est précisément
ce qui le rend invisible au lot qui l'introduit.

### ⚠️ UN SOL UNLIT N'A PAS DE PENTE — le relief se lit par SILHOUETTE

Mesuré au CH35-C sur 50 captures offscreen (4 buttes de même empreinte,
15° / 30° / 45° / 48,5°, plus une mesa, SUN et RAIN). Deux résultats qui
vont contre l'intuition :

* **l'étirement 1/cos des textures est INVISIBLE à 15°, 30° et 45°** —
  toutes les textures du sol sont des bruits ISOTROPES (patch 26 u,
  détail 5,5, mottle 1,7, cellules 2,6), et un ×1,41 sur un bruit isotrope
  ne se lit pas. Il devient visible vers 60-66° et gênant à 80° (rideau
  strié) ;
* **le vrai défaut est l'absence d'ombrage.** L'asset est unlit et rien ne
  post-traite la frame, donc **un flanc n'a AUCUN indice de pente** : une
  pente uniforme de 35° face caméra est indiscernable d'un sol plat, à
  ceci près que l'horizon devient une règle droite en haut du cadre — un
  « mur vert ».

Le relief ne se lit donc QUE par (a) une crête qui se découpe sur un
fond, (b) l'occlusion des props, (c) l'horizon qui monte. **Conséquences
de conception, permanentes** : chaque station marchable doit voir une
crête contre un fond ; **30° pour tout sol MARCHABLE**, 45° toléré sur des
flancs NON marchables et courts (< 8 u de dénivelé), **> 55° INTERDIT**
avec `cozy_ground` (une falaise exige un autre matériau ou un habillage de
props) ; et **aucune bande de couleur ne traverse un versant** — sans
ombrage cette ligne serait le SEUL trait du flanc, et un versant bicolore
lit comme deux terrasses (`HubSurface.register_domain` refuse une AABB qui
coupe une bande `CozyPalette`).

⚠️ **Et le cadre figé plafonne tout ça** : à 30 u devant Keepy le plafond
vaut ≈ 9,2 u, un sommet de 12 u n'entre dans le cadre qu'à ≈ 97 u où le
haze est à 88 %. **Avec cette caméra, un sommet de montagne n'est JAMAIS à
l'image** ; la masse lisible depuis un pied est de **≤ 9 u de dénivelé à
30 u**. Et llvmpipe prouve la GÉOMÉTRIE et le CADRAGE, pas le shading
WebGL2 de Safari iOS : les planches restent à confronter sur device.

### ⚠️ LE CADRE DU HUB EST ÉTROIT, ET C'EST LUI QUI DÉCIDE OÙ UN PROP VA

`HubWorld.tscn` pose `keep_aspect = 0` (**KEEP_WIDTH**) et `fov = 45` : les
45° sont donc l'angle **HORIZONTAL**, demi-angle 22,5°, sur une surface
1080×1920. Conséquence mesurée : **un prop planté à plus de ~3 u de côté de
Keepy au spawn n'est PAS à l'écran.** Un site choisi sur le seul dégagement
au sol est sorti à l'écran **(1316, 1046) sur 1080 de large** — hors cadre,
sans que rien ne le signale.

**Tout placement de prop destiné à être VU depuis une position donnée se
vérifie par `unproject_position()` sur la vraie caméra**, jamais par un
balayage de dégagement seul. Et le balayage doit porter le terme de cadre
comme une contrainte, pas comme une vérification a posteriori.

⚠️ **COROLLAIRE SUR LES TRAJETS : la caméra ne tourne JAMAIS**, donc elle ne
peut pas tenir les deux bouts d'une longue course. Avec `fog_density = 0.016`
exponentiel, une arrivée à 38 u est déjà à **45,6 %** d'occlusion
(`1 − exp(−38×0,016)`), et une chute de 3,6 u sur 38 u donne **5,4°** de
pente — à l'image, un fil horizontal en haut du cadre. **Mesuré par rendu,
pas déduit** : trois courses au corridor parfaitement vert ont été refusées
sur cette seule base. La bande où une descente LIT comme une descente sur ce
plateau est de l'ordre de **14 à 22 u**, à une pente de 13° et plus.

### ⚠️ OÙ UN VÉHICULE EST GARÉ DÉCIDE DANS QUEL SENS ON ROULE, DONC CE QU'ON VOIT

Corollaire opérationnel de « la caméra ne montre que des z inférieurs au
sien », et il coûte zéro à appliquer si on y pense au bon moment. Écrit au
CH53, sur un skatepark.

La place naturelle d'une planche, d'un kart ou d'une luge est **là où le
joueur arrive**. Rendue, c'est souvent la mauvaise : un joueur qui monte du
côté de l'arrivée roule **en s'éloignant** de l'objectif, dans un décor
entièrement derrière lui. Garé de l'AUTRE côté du contenu, il le traverse
**vers** la caméra et tout est dans le cadre devant lui. Mêmes objets,
même caméra, lecture opposée — et le seul changement est une constante de
position.

Mesuré : cinq modules, `unproject_position` sur la caméra livrée. Garé au
sud, **1 module sur 5** dans le cadre depuis le point de montage et trois
qui ne peignaient **aucun pixel**. Garé au nord, **5 sur 5**.

⚠️ **Et la borne de largeur n'est pas une règle de pouce.** Avec
`keep_aspect = 0` (KEEP_WIDTH) et `fov = 45`, les 45° sont l'angle
**HORIZONTAL**, donc un objet en `z` est dans le cadre depuis un joueur en
`z_p` ssi `|x| ≤ tan(22,5°) · (z_p + 8,9 − z)` **et** `z < z_p + 8,9`. Au
z du joueur cela vaut **±3,69 u** exactement. Un contenu qui doit se lire
d'un coup d'œil est donc **ÉTROIT et LONG**, jamais large — et ça se
vérifie par `unproject`, pas par un plan dessiné à plat.

### ⚠️ QUELLE CAMÉRA POUR QUOI — UN CRITÈRE UNIQUE, PLUS UNE PILE D'EXCEPTIONS

Écrit au CH30, sur décision de Mathieu, **en remplacement de l'empilement
d'exceptions** (« le kart est la seule exception licenciée », puis « le
char à voile est la deuxième exception assumée »). Deux exceptions
nommées, c'est déjà une règle qui n'a pas été écrite ; la voici, et elle
s'étend au véhicule suivant sans nouvelle autorisation :

| ce que le joueur fait | caméra |
|---|---|
| il **PILOTE en continu** un véhicule (appui maintenu, direction au pouce) | **POURSUITE** — `HubCamera.enter_drive()` |
| il se **DÉPLACE À PIED** (tap-to-move) | **FIGÉE** — `HubCamera.OFFSET` |
| il fait un **RIDE À TRAJET FIXE** (montgolfière, tyrolienne, plongeoir, manège, hibou, arbre) | **FIGÉE** |

Le critère est **le pilotage continu**, pas le véhicule : ce qui décide
est « le joueur choisit la direction frame par frame », et c'est
exactement la condition sous laquelle un cadre figé devient illisible —
le trajet sort du cadre et le joueur pilote de mémoire. Un ride borné par
un tween qui finit toujours à un point connu n'a pas ce problème : sa
trajectoire est écrite, donc cadrable.

**Corollaire, et c'est là que le prochain lot paiera** : une caméra de
poursuite montre le décor sous des azimuts que le cadre figé n'a jamais
montrés, et TOUT ce que ce dépôt a calibré l'a été pour le cadre figé.
Tout véhicule nouvellement piloté en continu doit donc passer un audit du
type `ChaseAudit` (CH30) : enroulement des rubans construits à la main,
`visibility_range_end` contre la portée réelle de la poursuite, luminance
des assets vus de PRÈS, et un balayage rendu par zone × azimut × météo.
Le CH30 y a trouvé deux défauts réels dans un hub que deux audits
visuels antérieurs avaient déclaré sain.

⚠️ **ET LA CAMÉRA NE S'APPROCHE JAMAIS : `HubCamera.OFFSET` EST UNE
CONSTANTE `(0 ; 7,6 ; 8,9)`.** Elle est à **11,703 u des pieds de Keepy**
et n'en bouge pas d'un pouce — marcher vers un prop ne zoome pas dessus, ça
le fait glisser vers le BAS du cadre pendant que la caméra garde sa
distance. **Il n'existe donc AUCUN axe « de près / de loin » sur ce
plateau** : une question de lisibilité « à distance » y est une question de
place dans le cadre et de fog traversé, jamais de grossissement. Payé au
lot CH23-2, où « lisibilité de près » a d'abord été lu comme un axe de
distance caméra : les deux stations mesurées sont sorties à **12,633 u et
18,302 u de la flamme**, et la densité de texels d'un billboard n'y bouge
que de 5,19 à 6,50 — un asset texturé de ce hub ne peut donc **jamais** être
agrandi, il est toujours minifié, et son seul risque est le scintillement.

### ⚠️ QUATRIÈME LIGNE DE LA TABLE : UN RIDE À TRAJET FIXE PEUT AVOIR UN **POINT DE VUE**, AU CHOIX DU JOUEUR

Exception écrite au CH72, sur demande explicite, et elle **ne rouvre pas
D6**. La table plus haut dit « ride à trajet fixe → caméra FIGÉE », et
c'est toujours le **DÉFAUT** : un trajet du parc d'attractions s'ouvre et
se ferme sur la pose fixe, inchangée. Ce qu'un tap achète pendant le
trajet est un **POINT DE VUE**, pas une conduite.

Le critère de la table — « le joueur choisit la direction frame par
frame » — reste **FAUX** ici : le rail et le mât écrivent la trajectoire,
le joueur n'en change rien. C'est pourquoi ceci est une quatrième ligne et
non une troisième exception à la deuxième.

| ce que le joueur fait | caméra |
|---|---|
| ride à trajet fixe, **par défaut** | **FIGÉE** |
| ride à trajet fixe, **après un tap sur lui-même** | **POV** — la tête, lacet seulement |

Ce que l'exception exige, et chaque clause a été payée :

* **La pose est un NŒUD DE TÊTE, jamais une reconstruction.**
  `KeepyHopper.head_anchor()` pend du nœud de **lacet**, jamais du slot du
  modèle — le slot porte le tangage du saut, l'écrasement et **l'échelle**.
  Tout ce qu'un porteur écrit atteint alors les yeux gratuitement, et un
  POV sur un chariot regarde où va le chariot sans que la caméra sache
  qu'un chariot existe.
* **LACET SEULEMENT, et reconstruit dans la caméra.** L'horizon est rebâti
  depuis le cap, donc aucun futur écrivain sur ce nœud ne peut incliner
  l'image. Le seul tangage est celui que le ride **AUTORISE**, un nombre
  publié par ride. Un POV qui roule est le terme qui rend un ride nauséeux,
  et le CH64 a déjà payé ce prix une fois.
* **LA SORTIE EST UN TAP N'IMPORTE OÙ**, le précédent CH64 de la planche
  mot pour mot : sous une caméra où aucun pixel ne veut dire « lui », le
  geste ne peut pas être un tap sur un corps.
* **ET CE TAP DOIT ÊTRE INTERROGÉ AU-DESSUS DU RETOUR HORIZON.** Piège
  fermé au CH72, et il expédiait le **patron ÉCHELLE** : sous un POV la
  caméra est la tête du rider, la bande haute de l'image vise l'horizon ou
  au-dessus, `HubSurface.intersect_ray` y rend `null` et
  `HubTapInput._handle_point` abandonne trois lignes plus loin. Chacun de
  ces taps est **avalé**, et ce tap est la **seule** sortie : un joueur qui
  regarde le ciel est enfermé dans ses propres yeux, le menu toujours
  réactif. Toute question qui n'a pas besoin d'un point au SOL se pose
  **avant** ce retour, et se gate en tapant **le haut de l'écran** — un tap
  sur la bande basse passe dans les deux cas.
* **LE POV NE SURVIT JAMAIS AU TRAJET.** Laissé ouvert, le joueur arpente
  le plateau depuis l'intérieur de sa tête et le canal de tap, gaté sur
  « un ride tourne », ne peut plus l'éteindre.
* **ET LE BANC NE SIGNE PAS LE CONFORT** (CH62). Il signe que la pose est
  bornée, qu'elle ne roule pas, qu'elle est câblée au vrai canal du doigt,
  que le trajet continue à travers la bascule, et ce que ça coûte. Le FOV,
  le tangage et la nausée sont un appel device.

### ⚠️ UN RIDE VERTICAL PEUT DÉPASSER LE PLAFOND DU CADRE — LA CAMÉRA MONTE, EN OFFSET BORNÉ SUR LA POSE FIXE

Ce fichier disait déjà que `HubCamera.FRAME_TOP_AT_APLOMB` plafonne un ride
vertical et que « la réponse à *je veux plus haut que ça* reste une caméra
qui monte, c'est-à-dire un autre lot ». **CH72 est ce lot**, et la porte
qu'il ouvre est la plus étroite possible : un **OFFSET VERTICAL BORNÉ
ajouté à la CIBLE du lerp de la pose fixe** — la forme du ride mode CH62,
qui échoue à tous les tests d'une caméra de poursuite (pas de lacet, pas de
`look_at`, aucun cap retardé, `far` intact, `_hub_basis` jamais écrit).
L'horizon ne peut pas bouger, qui est la raison d'être de la pose fixe.

**Mesuré, et c'est ce qui rend la chose gratuite** : on lève la caméra et le
rider du MÊME `dy`, et la tête atterrit au pixel **(270, 121)** à `dy` = 0,
3, 6, 10 et 14 — **le cadrage est INVARIANT**. La hauteur ne coûte rien à
l'image.

Trois clauses, chacune payée au CH72 :

1. **C'est un OFFSET, pas une variable d'ombre.** Il s'ajoute à `_wanted()`
   dans le `global_position.lerp(...)` que le hub a toujours eu, donc un
   écrivain extérieur reste un écrivain extérieur — la discipline qu'un lot
   a déjà cassée contre `CabinProbe`.
2. **Le lerp TRAÎNE, et ça se mesure au lieu d'être supposé petit.** Une
   nacelle qui tombe à 14,2 u/s contre une constante de temps de 0,2 s
   laisse **2,398 u** de retard mesuré : le rider glisse vers le bas du
   cadre et la caméra le rattrape. Gater la tête dans le cadre à **chaque
   frame**, jamais en moyenne.
3. **UN GATE « le siège est sous le plafond » DEVIENT FAUX ET SE RÉ-VISE** —
   il ne se relâche pas et il ne se fait pas taire. La propriété qui survit
   à la hauteur est **« le ride ne se tient jamais plus haut que le lift
   qu'il demande »** (`siège − lift ≤ plafond`), ligne **identique à
   l'ancienne dès que le lift est nul**, donc pour tout ride qui ne monte
   pas. Et elle se double d'un **blind check à l'exécution** : rejouer le
   MÊME trajet avec le lift épinglé à zéro et **exiger que la tête sorte** —
   mesuré 473 frames sur 713.

⚠️ **ET LE LIFT N'EST PAS QU'UN TERME DE CADRAGE : C'EST UN TERME
D'ATTEIGNABILITÉ.** Trouvé par une passe rouge qui a rendu **7 rouges pour 2
prédits**, et les cinq extras avaient une cause unique. Un corps hors du
cadre n'est pas seulement invisible : `unproject_position` le projette
**hors du conteneur**, et `HubTapInput._handle_point` refuse le tap sur son
propre test de rect **avant** d'interroger quoi que ce soit. Mesuré : lift
neutralisé, le rider est **6,152 u au-dessus du bord haut** et devient
**intapable** — donc toute la bascule POV meurt, pour une raison qui n'a
rien à voir avec la bascule. **Un lot qui surélève un corps interactif doit
se demander non seulement « est-il visible » mais « est-il ADRESSABLE ».**

### ⚠️ UNE BASE CONSTRUITE POUR BALAYER UN PROFIL PEUT ÊTRE MIROIR — ET ELLE EST ALORS INUTILISABLE COMME POSE

`t.cross(UP)` est la **GAUCHE** de la marche, pas sa droite :
`Basis(t.cross(UP), up, t)` a un déterminant de **−1**. Trouvé au CH72 sur
la frame qui pose les rails du parc depuis CH71.

**C'est inoffensif pour un balayage symétrique et l'a toujours été** — les
rails sont posés à `−gauge/2` et `+gauge/2` autour de l'axe, donc échanger
gauche et droite ne fait que les renommer, et un tube à six pans balayé
autour d'un axe radial retourné est le même hexagone tourné. Mais **une base
miroir donnée à un `Node3D` n'est pas une rotation**, et le lacet que Godot
en décompose ne veut rien dire.

La base droitière est `Basis(UP.cross(t), t.cross(UP.cross(t)), t)` —
`X = Y × Z`, l'identité que la base de lacet de Godot satisfait. **Deux
frames, deux noms, et la distinction se GATE** (le déterminant de chacune),
jamais laissée à un commentaire.

### ⚠️ UN PORTEUR REMET SON LACET AU RIDER VERBATIM — DONC LA CONVENTION DE FACE EST CELLE DU RIDER, PAS CELLE DU PORTEUR

`KeepyHopper.follow_carrier()` fait `_yaw.rotation_degrees.y =
_carrier.global_rotation_degrees.y`, et le modèle regarde **+Z** à lacet
nul. **L'axe qu'un rider regarde est donc le +Z de son porteur**, et un
porteur posé par `Basis.looking_at(t, UP)` met **−Z** sur la tangente —
c'est ce que `looking_at` veut dire — donc le rider regarde `−t`.

Mesuré au CH72 sur 900 frames d'un vrai trajet lancé au vrai canal du
doigt : **180,00° à la première frame, 179,90 de moyenne, 180,00 au
maximum**. Il montait la côte, prenait les deux virages et descendait la
drop entièrement à l'envers, sans une erreur et sans une sonde rouge.

**Règle** : tout porteur qui transmet son lacet se pose avec **+Z sur la
direction que le rider doit regarder**, et ça se **MESURE** — la facette +Z
du nœud de lacet du rider contre la direction de marche, à chaque frame —
jamais relu dans le code qui l'écrit. C'est « une assertion d'orientation ne
se relit pas : elle se rend », appliquée à un cap plutôt qu'à un enroulement.

⚠️ **Et la frame qui TERMINE un trajet mesure le PAS DE DESCENTE, pas le
trajet.** `leave_carrier` démarre le saut vers le quai et `_face` y écrit
déjà le cap de la marche : une lecture prise là a rendu **90,07° sur une
frame en 900** — exactement l'angle entre la tangente à la gare et la marche
sur le deck — sur un chariot qui avait regardé droit les 899 autres.
Ré-interroger l'état **après l'`await`** avant de mesurer.

### ⚠️ UNE SONDE QUI PREND UN PLANCHER DE BRUIT EN PIXELS DOIT ÉPINGLER LA MÉTÉO

Complément direct de « `paused` n'arrête pas le `TIME` d'un shader » (CH48)
et de « une sonde à séquence temporelle se rejoue à charge comparable »
(CH37). `CozyWeather.CYCLE` fait 70 s de soleil, 40 de pluie, 30 d'orage,
50 de soleil, 40 de neige — et la pluie, l'orage et la neige **traversent la
pause**. Une sonde à qui on ajoute des phases sort donc du soleil
d'ouverture, et son **plancher de bruit** part avec.

Mesuré au CH72, même station, deux arbres : plancher **347 px** sur la
baseline, **24 752 px** sur la branche — un facteur **SOIXANTE-DIX**, sur un
instrument dont le métier est d'être plus silencieux que son sujet. Le sujet
peignait *plus* de pixels qu'avant (64 511 contre 24 899) ; c'est la RÈGLE
qui avait molli, et le gate est sorti rouge sur un lot qui avait rendu la
chose **plus** visible.

**Règle** : toute sonde qui lit des pixels ou des primitives épingle la
météo (`CozyWeather.force`) en tête de run et attend la transition. Rien
qu'un tel banc mesure n'est fonction de la météo, et un verdict qui dépend
de la durée des phases précédentes n'est pas reproductible.

### ⚠️ UN GATE DE CAPTURE NE GATE RIEN DANS UN MONDE QUI CONTIENT UN ACTEUR EN MARCHE

Mesuré au CH37, sur un gate que le plan du lot prescrivait explicitement
(« `CozyCapture` 5 stations × SUN/RAIN : md5 identiques »). Les dix md5
ont divergé entre les deux arbres — dix sur dix. Ce n'était pas une fuite :
**deux runs du MÊME arbre, mêmes arguments, rendent deux md5 différents**,
et le relevé chiffré de `ChaseAudit` fait pareil (**170 lignes divergent
sur un seul arbre**, contre 272 entre deux, pendant que son VERDICT 13/0
PASS ne bouge pas).

La cause est le hub : **depuis le CH25 l'ours MARCHE** vers le feu. Sa pose
dépend du nombre de frames réellement simulées avant la capture, donc de la
CHARGE DE LA MACHINE, et sa pose colore le pixel central et tous les
compteurs de frame. Mesuré : entre deux runs de la même référence l'ours se
déplace de **1,27 u**, contre **0,17 u** entre les deux arbres — **le bruit
est plus grand que le signal**.

**Règle** : avant de lire une divergence de capture comme une régression,
**retourner la métrique contre elle-même** — deux runs du même arbre, dans
les mêmes conditions de charge. Un gate qui ne se reproduit pas sur un seul
arbre ne peut rien dire de deux. Et le repli existe et est bon marché :
`CozyCapture` imprime déjà `COZY_STATS`, qui décrit la SCÈNE (350 batches,
4 572 instances, 341 029 triangles, la pose de Keepy, le teint du sol) et
non les pixels — hors des champs pilotés par l'acteur en marche, il est
**strictement déterministe**, et c'est lui qu'il faut comparer.

⚠️ **Le même piège a fait diverger `CabinProbe` de 8 rouges à 2** au CH37,
pour la seule raison que les deux runs avaient partagé la machine. Rejouée
SEULE sur chaque arbre : **2 rouges des deux côtés, les mêmes lignes, les
mêmes nombres.** Une sonde à séquence temporelle se rejoue à charge
comparable, ou son verdict n'est pas comparable.

⚠️ **Corollaire de station** : ne jamais planter le point d'observation
**SUR** le prop mesuré. Une passe de lisibilité a posé Keepy exactement au
site, donc **DEBOUT DANS** le candidat du créneau central, qui a peint
**50 pixels** contre 3 916 pour son voisin — lisible comme « ce candidat
est invisible », en réalité « son propre personnage l'occulte ».

⚠️ **ET UN JEU DE CONTRAINTES DE DÉGAGEMENT NE VOIT PAS UNE OCCULTATION.**
Le site retenu par le balayage était à 2,358 u au sol du portail Quizz, et
son mât passe pourtant **devant l'anneau et le label** de ce portail : les
deux sont sur la même ligne de caméra. Un dégagement est une distance au
SOL ; « qu'est-ce que ça cache » est une question d'IMAGE, et seul un rendu
y répond.

### ⚠️ UNE STRUCTURE POSÉE SUR UN BORD DÉBORDE — ça se répare dans la RÉGION

Un prop dont le layout fixe le centre **exactement sur** la limite du monde
jouable met fatalement des parties de lui-même **au-delà**, et personne
n'est prévenu : ni erreur, ni sonde rouge, ni build cassé. Sur device ça ne
se lit même pas comme un bug — c'est une structure dont on ne peut pas faire
le tour, parce que chaque tap derrière elle est rabattu sur le bord.

Mesuré sur la tour nord de la tyrolienne (P2 pile sur `PLATEAU_HALF_EXTENT`) :
l'escalier débordait de **1,682 u**, et **même les jambes arrière** de
**0,547 u** — cinq points au sol, **zéro** dans la région.

**La réparation va dans la RÉGION, pas dans le bâtisseur.** Réorienter la
seule structure fautive casse la symétrie « un bâtisseur, N instances, une
règle de facing » ET ne règle que la partie la plus visible du débord.

Le patron, et il est réutilisable tel quel :

1. **Un lobe DÉDIÉ centré sur la structure**, uni à la région — pas un
   élargissement du lobe de bord existant, qui peut être à des dizaines
   d'unités (le lobe nord était à 25,2 u pour un rayon 12).
2. **Une TABLE dès la première entrée**, jamais un second scalaire.
3. **Le rayon est MESURÉ contre les parties AU SOL telles que construites**,
   et il vise la MARGE, pas le minimum : viser l'emprise circonscrite laisse
   un liseré, pas de la place pour manœuvrer. Compter au moins un
   `KEEPY_CLEARANCE` au-delà de la partie la plus large.
4. **La traversée pire cas est RE-MARCHÉE, pas déduite.** L'argument « un
   lobe sur un bord n'allonge aucune diagonale entre coins » est vrai et
   reste **à vérifier à chaque fois** : la cible est le point du disque le
   plus éloigné **DU COIN OPPOSÉ**, jamais sa pointe — viser la pointe
   mesure un trajet plus court et l'appelle le pire.
5. **Le centre est une seconde orthographe du layout** (la région ne peut pas
   lire le layout : le bâtisseur lui demande `contains()` PENDANT qu'il
   construit). Régime des centres de lacs : littéral **gaté** contre l'objet
   réellement construit, jamais littéral cru.
6. **Blind check obligatoire** : « tout est couvert » est une assertion de
   COUVERTURE, qui passe gratuitement. Rejouer l'ANCIENNE région dans la
   sonde et exiger qu'elle échoue d'abord — et l'y réécrire à la main plutôt
   que d'ajouter un interrupteur dans la région, parce qu'une sonde capable
   d'éteindre la région livrée est une sonde capable de la laisser éteinte.

⚠️ **Et regarder ce que la région débloque AILLEURS.** Le même lobe a réparé
un défaut que personne n'avait cherché : l'anneau de dépôt de fin de trajet
(`_ride_exit_point`, qui **jette** tout candidat hors région) avait tout son
arc nord amputé à P2 — un rider ne pouvait être déposé que côté plateau.

### ⚠️ UN LOBE SUR UN BORD NE COÛTE RIEN ; UN RECTANGLE SUR UN BORD, SI

Précision d'une doctrine déjà écrite, payée au CH38. « Un lobe bolté près
d'un BORD n'ajoute aucune longueur à une diagonale entre COINS » est vrai
d'un **disque centré SUR le bord** — la moitié intérieure ne sert à rien,
et la pointe extérieure reste plus près des coins opposés que ces coins ne
le sont entre eux. Ce n'est **pas** vrai d'un **rectangle** accolé au même
bord : ses deux coins extérieurs deviennent la nouvelle pire paire, et le
coût grandit avec sa largeur, pas avec sa surface.

Mesuré : un rectangle de 28 u accolé au bord ouest du carré porte la pire
traversée de **18,700 s à 20,967 s** ; le même à 36 u de large sort à
**22,383 s**, au-dessus des 22 s que le hub se tient. Le plafond de
traversée est donc ce qui **cape la largeur d'une extension de bord** — et,
en cascade, la HAUTEUR de tout relief qu'on y pose, une pente marchable
n'étant qu'un rapport entre les deux.

**Règle** : toute extension de région se price sur ses **coins**, contre le
coin le plus éloigné de la région existante, avant que sa forme soit
dessinée — et le chiffre se **marche** ensuite sur le vrai hopper, jamais
seulement au ratio s/u. Corollaire du même lot : la marche a reproduit la
diagonale publiée **à la frame près** (1 122 frames, 18,700 s), ce qui est
la seule chose qui donne au banc le droit de publier le chiffre neuf.

### ⚠️ DEUX BOSSES QUI SE RECOUVRENT ADDITIONNENT LEURS GRADIENTS

Un relief composé de plusieurs bosses ne se gate pas bosse par bosse. Deux
cosinus surélevés dont les supports se chevauchent additionnent leurs
**pentes** là où ils se croisent, et le résultat dépasse chacun d'eux :
mesuré au CH38, une bosse à 23° et une à 17° ont rendu **33,0°** dans leur
recouvrement — au-dessus du plafond de 30° que CH35-C fixe pour un sol
unlit, alors que les deux prises isolément passaient largement.

**Règle** : une pente se mesure sur les **triangles réellement dessinés**
de la grille assemblée, jamais sur la fonction analytique d'une bosse ni
sur la somme de leurs maxima. Et si la silhouette veut deux sommets, ils
s'écartent : au CH38 la seconde bosse a fini à 12,04 u de la première, la
distance à laquelle son gradient ne rencontre plus celui de la grande. Un
budget de pente dépensé dans un recouvrement n'achète aucune silhouette.

### ⚠️ UN APPUI PARTAGÉ NE VEUT PAS DIRE UNE POSE PARTAGÉE

Deux corps accrochés au MÊME objet physique partagent la géométrie de cet
objet, et **rien d'autre**. Sur la tyrolienne, `bar_drop` et
`hang_clearance` décrivent une barre unique — la ligne de crown à 1,71 que
le chariot tend aux deux passagers — et elles restent partagées. Ce qui est
**par corps**, c'est la POSE accrochée à cette ligne, et il en faut DEUX
nombres par passager, pas un :

* **où est son crown au-dessus de son propre nœud**, DANS LA POSE OÙ IL EST
  TENU — jamais sa hauteur DEBOUT. Les deux coïncident pour un corps qui
  pend droit (Keepy), ce qui rend la formule juste **par accident** de son
  côté et masque le défaut jusqu'au premier passager incliné ;
* **où est son point le plus bas par rapport à ce nœud**, qui n'est zéro
  que pour ce même corps droit.

Mesuré : passer la hauteur debout d'un corps incliné comme offset de crown
l'a enterré **0,45 u sous le sol pendant les 4 s du trajet**, sans erreur
ni crash. Une sonde qui lit le NŒUD au lieu de la SEMELLE ne le voit pas —
le nœud était à +0,007, positif, vert.

**Corollaire pour un troisième passager** : il apporte ses deux offsets,
la barre n'en apporte aucun, et la fonction de siège prend un **offset de
crown** — jamais une hauteur de corps.

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

### ⚠️ UN RIDE VERTICAL COÛTE UN ÉTAT ; UNE MIGRATION MULTI-ALTITUDE COÛTE LA NAVIGATION

Question posée à chaque fois que le monde doit gagner de la hauteur —
grimper un arbre, une tour, une falaise. Les deux réponses ne sont pas du
même ordre de grandeur, et ce dépôt a maintenant les deux au dossier.

**La migration multi-altitude** (`CH18` cabane) change ce que « le sol »
veut dire : la région, le clamp, le test de prop, la caméra et chaque
hotspot doivent tous apprendre qu'il existe plusieurs plans. C'est un
chantier entier, et il a coûté treize sections.

**Le ride vertical** ne change rien de tout ça. Le personnage est **écrit le
long d'une géométrie** dans l'espace LOCAL du porteur et relu par
`to_global()` ; le sol reste un seul plan, la région reste plate, aucun
autre état n'est touché. `ON_TREE` fait 8 phases et ~330 lignes dans
`KeepyHopper`, et les cinq perchoirs d'origine sont sortis **14 assertions
sur 14 identiques** après la généralisation à 53 arbres.

**Règle** : tant que ce qu'on veut est « le personnage MONTE et redescend »,
c'est un ride, pas une altitude. On ne paie la navigation multi-altitude que
lorsque le joueur doit **se déplacer librement** en haut.

⚠️ **Et c'est la CAMÉRA qui plafonne un ride vertical, pas la géométrie.**
`HubCamera` suit le point SOL de Keepy et ne monte jamais (voir
`HubCamera.OFFSET`) : le rayon haut du cadre croise son aplomb à
**y = 7,968 u** (`HubCamera.FRAME_TOP_AT_APLOMB`, mesuré). Avec la tête à
1,7 u au-dessus du siège et 0,4 u de marge, un siège à plus de **5,868 u**
sort la tête du cadre — et la réponse à « je veux plus haut que ça » reste
une caméra qui monte, c'est-à-dire un autre lot.

⚠️ **CE PLAFOND A VALU 6,96 u PENDANT DEUX LOTS, ET C'ÉTAIT FAUX DE
1,008 u** (corrigé au CH36, mesuré deux fois). La ligne disait
`y = 7,6 − 8,9 · tan(40,5° − 36,4°)`, où 40,5° = `atan(7,6/8,9)` est le
tangage qu'aurait une caméra qui **REGARDE** le point-sol de Keepy.
`HubCamera` est à **rotation FIXE** et la scène lui donne **34,0°**
(`asin(0,55919)`, `HubWorld.tscn`) : 34,0° est **plus petit** que le
demi-angle vertical (36,37° à 1080×1920 en `KEEP_WIDTH`), donc le rayon
haut sort de l'objectif **vers le haut** et le signe du terme s'inverse.
Le `SEAT_MAX_Y` qui en dérivait excluait **6 arbres** parfaitement
cadrables (11, 15, 41, 42, 45, 47 — re-admis au CH36, rendus à l'appui).

**Règle** : une constante de cadrage se **RELIT sur la caméra livrée**
(`unproject_position` en bissection, confirmée par `project_position`),
jamais recalculée depuis un angle écrit à la main — une forme fermée qui
suppose un `look_at` inexistant est juste au signe près et **ne se
signale jamais**. Et une constante que rien ne relit survit aux lots :
celle-ci n'était gatée par **aucune** sonde. `FrameCeilingProbe` la relit
désormais à chaque run, et gate au passage la tête de chaque arbre
grimpable.

### ⚠️ UN NOEUD PORTEUR NE PORTE JAMAIS L'ÉCHELLE DE L'INSTANCE QU'IL REPRÉSENTE

Corollaire du patron ci-dessus, et il mord silencieusement. Adopter une
instance de `MultiMesh` pour la rendre interactive se fait par un `Node3D`
**VIDE** qui reprend **rotation et translation, jamais l'échelle**.

La raison est que toute constante de chorégraphie est en **unités
personnage** — écart de prise 0,28, balancement 0,07, dégagement au pied
0,42 — et qu'elles traversent `to_global()`. Sur un décor dont les
instances vont de l'échelle **0,40 à 1,50**, un porteur qui porterait
l'échelle multiplierait chacune de ces constantes par elle : la même
chorégraphie serait ratatinée sur un petit arbre et démesurée sur un grand,
sans une seule erreur pour le dire. La géométrie de l'instance, elle, est
multipliée par l'échelle **explicitement**, une fois, là où elle est
mesurée.

### ⚠️ LE TRONC D'UN ARBRE À HOUPPIER PLEIN EST INVISIBLE DEPUIS LA CAMÉRA DU HUB

Trouvé **par capture, pas par raisonnement**, et c'est le point : une
première version faisait grimper Keepy le long du tronc puis sauter à
travers la couronne. À l'image, il **disparaissait 1,3 seconde** (frames 70
à 110) et réapparaissait assis au sommet. La couronne (r ≈ 1,3 u dès
y ≈ 1,3) recouvre entièrement le tronc pour tout rayon qui monte à 40° vers
+z, ce qui est exactement l'assiette de cette caméra.

**Règle** : toute chorégraphie écrite « sur le tronc » d'un sujet à
houppier plein est une chorégraphie **hors champ**. La montée passe par le
**flanc de la couronne**, en profil. Et la vérification est un **rendu**,
jamais une relecture : la pose a été fausse trois fois de suite sur capture
— inclinaison du corps sur la pente qui enfouissait la tête dans les
feuilles, puis le même signe qui l'enterrait en descente tête en bas —
avant d'être juste, et aucune de ces trois erreurs n'était visible dans le
code.

### ⚠️ UN `tint` QUI MULTIPLIE LA COULEUR DE SOMMET NE PEUT PAS RECOLORER

Un uniforme de teinte appliqué en multiplication sur `COLOR` **assombrit ou
éclaircit dans la teinte du sommet** — il ne la déplace pas. Mesuré deux
fois dans la même nuit : teinter des feuilles d'automne vers le vert a
produit des **losanges olive-brun** illisibles, et il a fallu trois GLB
verts ; à l'inverse, un or obtenu avec des composantes **supérieures à 1**
(1,9 ; 1,7 ; 0,45) fonctionne, parce qu'il ÉCLAIRCIT un brun vers le jaune
au lieu de le déplacer.

**Règle** : une couleur qui doit changer de TEINTE change de `.glb`. Un
`tint` multiplicatif sert à faire varier une même famille, pas à en fonder
une autre. (Même famille de piège que « la couleur qu'un `.glb` porte est
littéralement celle qui s'affiche » : depuis la suppression du grade plein
écran, rien ne post-traite la frame.)

### ⚠️ UNE FORCE INJECTÉE AVANT `step()` GÈLE LE VÉHICULE FACE À LA MONTÉE

Trouvé au CH41 sur le premier véhicule à rouler sur une pente, et c'est une
**correction mesurée** à ce que `docs/lots/CH35_MULTI_ALTITUDE.md` Q2
prescrivait noir sur blanc (« pente = force injectée dans `velocity` AVANT
step »). Mesuré : **0,000 u/s et 0,00 u parcourus en 240 frames**, à l'arrêt
face au flanc le plus raide.

Le mécanisme n'est dans aucune constante. La force rend `v_fwd` **négatif**
avant que `VehicleDrive` ne le regarde ; le modèle prend alors sa branche
« reversing and the throttle comes back » — `move_toward(v_fwd, 0.0,
brake_decel * delta)` — qui ramène le recul à **exactement zéro et jamais
au-delà** ; la branche d'accélération n'est **jamais atteinte** ; et à
vitesse nulle ce modèle ne donne **aucune autorité de braquage** (son
`ratio`). Un joueur garé sur un flanc, sans direction et sans sortie :
**c'est le blocage de `SandYacht._wall` étape 3, atteint par l'ordre des
opérations au lieu d'un mur.**

**Règle** : une force extérieure se compose **APRÈS** `step()`, dans la
vélocité que le modèle vient d'écrire — ce que `SailBoat` fait déjà pour son
échouage (« appliquée à la vélocité APRÈS step(), jamais un clamp de
position »). Rien d'autre ne bouge : la vitesse terminale reste
`cap + force / off_lambda` dans les deux ordres, et le coût est **une frame
de retard**, soit 0,17 u/s sur le sol le plus raide de cette carte.

⚠️ **Corollaire, et il se gate** : au repos le modèle offre
`cap × accel_lambda` d'accélération et la pente pousse
`gain × g·sinθ·cosθ`. Si la seconde l'emporte, le véhicule ne peut pas
quitter l'arrêt en montée **quel que soit l'ordre**. Les deux se publient
par accesseur et l'inégalité se gate sur la pente la plus raide que la
surface possède réellement (`SledBody.climb_authority()` / `slope_force()` :
10,53 contre 13,60, 77 % utilisés). Un réglage de feeling qui la casse
échoue bruyamment au lieu d'expédier une colline piège.

### ⚠️ UNE JAMBE DE MESURE A/B CHANGE DE RÉGIME EN COURS DE ROUTE

Une comparaison symétrique (descente contre montée, avec contre sans) est
juste **tant que chaque jambe reste dans le régime qu'elle prétend
mesurer**. Mesuré au CH41 : la jambe « montée » à 240 frames a rendu
**19,597 u/s, PLUS RAPIDE que la descente**. Le chiffre n'était pas faux —
en 4 s la luge avait grimpé le flanc, **franchi le sommet** et dévalait
l'autre versant. La lecture était honnête et répondait à une autre question.

**Règle** : toute jambe d'un couple A/B publie la grandeur qui la définit
**aux DEUX bouts**, et la phase gate que son SIGNE n'a pas basculé. Sortir
du régime par le bas (atteindre le plat) n'est pas un basculement ; devenir
l'autre régime en est un. Sans ce garde, un banc symétrique peut rendre
exactement l'inverse de son résultat et rester crédible.

### ⚠️ UN DELTA SOUS SON PLANCHER DE BRUIT N'EST PAS UNE MESURE NON PLUS

Moitié manquante de la doctrine CH40 (« un delta sans son plancher ne vaut
rien »). Mesuré au CH41 : un prop de **60 triangles** relu par la méthode
« cacher et relire » rend **+640 primitives** à une station dont le
tremblement propre vaut **340** — et **exactement +60** aux onze stations
sur seize où le compteur est **parfaitement immobile**. Le hub dérive de
quelques centaines de primitives entre deux frames intouchées (papillons,
précipitations, critters) : une balance aussi bruyante ne peut pas peser 60
triangles.

**Règle** : le coût se lit **là où l'instrument est immobile**, la mesure
est gatée **par station** contre le tremblement **de cette station**, et les
stations bruyantes sont **imprimées et laissées en dehors du gate** — avec
la raison écrite. Un gate global (pire delta contre pire tremblement) est
soit gratuit, soit faux.

### ⚠️ UN TEST D'ENROULEMENT CONTRE UN CENTRE DE MASSE SUPPOSE LA CONVEXITÉ

« La normale sortante est celle qui s'éloigne du milieu » est vraie d'une
pièce convexe et **fausse d'un assemblage**. Mesuré au CH41 : la première
sonde a déclaré **46 triangles sur 60** mal enroulés sur un mesh que le
rendu venait de prouver juste au pixel (`cull_back` et `cull_disabled`
couvrant les **mêmes 13 190 pixels**) — le dessous de la plate-forme et les
flancs intérieurs des patins pointent tous vers le milieu de l'assemblage.

**Règle** : chaque **pièce convexe** est testée contre **son propre** centre,
et le groupement est **publié par le constructeur** (`PIECE_TRIS`,
`PIECE_COUNT`) puis **asserté** par la sonde, jamais deviné. Et le rendu
`cull_back` contre `cull_disabled` reste le juge : c'est lui qui a tranché
ici, parce que le shader décor est `cull_disabled` et qu'une coque à
l'envers y serait **invisible en tant que défaut**, en sandbox comme sur
device.

### ⚠️ UN DÉMONTAGE DE PORTEUR QUI SAUTE N'ÉMET NI `became_idle` NI `carrier_dismounted`

`KeepyHopper.leave_carrier()` pose `_has_target = false`, et `_advance()` —
seul émetteur de `became_idle` — **sort à sa première ligne** quand il n'y a
pas de cible. Un démontage qui parcourt une distance n'émet donc que
`hop_landed` ; `carrier_dismounted` n'est émis que par la branche de
**distance nulle**. Une sonde qui attend `became_idle` après un
`leave_carrier` **expire** pendant que le personnage est bel et bien revenu
sur ses pieds. Constaté au CH41 ; partagé par le char à voile et le voilier,
**signalé et non corrigé** (le changer toucherait deux conduites validées
device). Lire l'ÉTAT (`is_on_carrier` / `is_hopping`), pas le signal.

### ⚠️ UNE SONDE QUI NE COMPARE CHAQUE CHOSE QU'À ELLE-MÊME NE PEUT PAS VOIR QUE DEUX CHOSES SE RESSEMBLENT

CH46 est sorti **69 assertions vertes** sur une minimap que Mathieu, device
en main, n'a pas su lire. Les 69 étaient vraies. Le défaut n'était dans
aucune d'elles : il était dans ce qu'**aucune** ne demandait. Chaque
marqueur était comparé **à sa propre teinte**, jamais à celle d'un autre
type — et deux des quatre types partageaient **la même cellule d'atlas**,
disque de rayon 3,9, au pixel près. Une sonde qui pose à chaque objet la
question « es-tu bien toi-même ? » répond oui à un jeu d'objets
identiques.

**Règle** : dès qu'un contrat porte sur le fait que N choses sont
DISTINCTES — quatre marqueurs, trois états d'un HUD, deux poses — c'est la
matrice des **N(N−1)/2 paires** qui se gate, et elle se **publie en
entier**. Un seul « écart minimum » cache quelle paire est la faible, et
c'est toujours celle-là qui casse la prochaine fois.

⚠️ **Et la séparation se mesure en COUVERTURE, jamais en TON.** Ce dépôt
documente déjà que le WCAG ne score aucune séparation à l'intérieur d'une
bande de luminance et qu'aucune sonde d'ici ne mesure la teinte : une
distinction à quatre par la couleur est condamnée d'avance sur ce sol.
Ce qui se mesure est **quelle part de sa boîte une icône encre**, lue
comme une DIFFÉRENCE contre une frame où la chose a été **retirée** de la
scène — ce qui rend le nombre indépendant du ton de l'objet ET du fond
sous lui. Un test de ton absolu mesure le fond autant que l'objet.

### ⚠️ UN MARQUEUR POSÉ SUR UN CONTRÔLEUR N'EST PAS POSÉ SUR CE QU'IL REPRÉSENTE

`HubBoar`, `HubCat`, `HubFawn`, `HubBeaver` sont des **nœuds vides** qui
construisent l'animal et ne bougent jamais de l'origine du monde ; la bête
est leur enfant `HubCritter`. CH46 y a écrit `mark(self)`. Résultat mesuré
sur 900 frames simulées : **sept des neuf marqueurs PNJ épinglés sur
(0, 0, 0)**, sous le marqueur du joueur, pendant toute la session — sans
erreur, sans sonde rouge, et **au pixel ça ressemble à un marqueur**.

**Règle** : tout enregistrement dans un registre — groupe de carte, liste
de sauvegarde, table d'émetteurs — qui prend `self` dans un fichier où
`self` est un contrôleur enregistre **le mauvais nœud**. Inscrire le corps
qui BOUGE, à son site de construction, et le gater : quel nœud porte
l'inscription n'est pas une propriété DESSINÉE, donc **aucun pixel ne peut
la voir** et l'assertion doit être structurelle et se dire structurelle.

⚠️ **Corollaire de méthode** : deux lectures d'un monde **byte-identiques**
à 900 frames d'écart ne prouvent pas qu'il est stable — elles passent
gratuitement contre un monde qui n'a jamais tourné. Publier un **témoin**
(compteur de frames, horloge, état d'un acteur censé bouger) avec les deux
lectures, sinon « rien n'a bougé » et « rien ne tourne » se lisent pareil.

### ⚠️ UN SEUIL ÉCRIT EN « CELLULES » CESSE DE SÉPARER QUOI QUE CE SOIT LE JOUR OÙ LA CELLULE GRANDIT

CH46 excluait un marqueur de son test de rendu quand un marqueur dessiné
après lui était « à moins d'`ICON_PX` » — juste, parce que sa cellule
d'atlas **était** son encre. CH47 a porté la cellule de 14 à 25 px pour y
loger quatre tailles d'icône : le même seuil a alors exclu **les quatorze**
marqueurs de lieux, et la phase est sortie **0 sur 0**, c'est-à-dire le vert
le plus vide qui soit.

**Règle** : un seuil de test s'écrit dans l'unité de **ce qu'il mesure**
(ici l'encre réellement dessinée, relue sur l'atlas cuit), jamais dans
celle du conteneur qui la porte. Et tout test « tous ceux qui restent
passent » se double d'un garde **`tried > 0`** — c'est ce garde, écrit par
CH46 pour une autre raison, qui a attrapé celui-ci.

### ⚠️ UNE IMAGE MULTICOLORE NE PEUT PAS SIGNER UN CONTRAT DE CONTRASTE — À AUCUNE DÉSATURATION

Écrit au CH48, sur un balayage complet et non sur un raisonnement. Le brief
demandait la désaturation minimale des aplats qui laisserait des vignettes
en couleurs réelles atteindre le plancher de 3,0:1. Balayé de w = 0,0 à
w = 1,0 — bandes lavées jusqu'au **blanc pur** — **la pire vignette ne
dépasse jamais 2,6 % de son encre au-dessus du plancher.**

Ce n'est pas le lavage qui échoue. **Un RATIO de contraste est un ton contre
un ton** ; un blaireau a une fourrure blanche ET un masque noir, et quelle
que soit la luminance d'une bande, l'un des deux en est proche. 3,0:1 est un
contrat qu'un **aplat** d'icône peut signer et qu'une **photographie** ne
peut pas.

**Règle** : dès qu'un marqueur porte une IMAGE plutôt qu'un ton, le plancher
de contraste est porté par une pièce d'un seul ton — un plateau sombre, un
contour noir — et l'image n'a plus à franchir que **cette pièce**, qui est un
ton fixe connu. Mesuré au CH48 : plateau `(0,07 ; 0,08 ; 0,09)`, L = 0,0070,
pire ratio **4,38:1** contre les huit bandes peintes ; de 47,2 % à 100 % de
l'encre de chaque vignette franchit ce plateau.

⚠️ **Et le contour doit rester NOIR même quand on veut y mettre une couleur
de rang.** CH48 a d'abord donné au plateau UN liséré, dans le ton du type ;
les tons de rang 1 sont CLAIRS par construction (0,8392 et 0,6476) et les
bandes de ce hub aussi, donc **43 échantillons de périmètre sur 68 sont
tombés sous 3,0:1**. La couleur du rang va **à l'intérieur** d'une keyline
noire, jamais à sa place.

### ⚠️ DÉSATURER À CLARTÉ CONSTANTE EST NEUTRE EN CONTRASTE — C'EST DE L'ARITHMÉTIQUE

Le WCAG note la **luminance relative**. Tirer une couleur vers son propre
gris ne la déplace donc quasiment pas : mesuré sur `GRASS_A`, **L 0,4717 à
saturation pleine, 0,4491 en gris complet**. Une demande de « désaturer pour
que les marqueurs ressortent » est une demande sur la **CHROMA**, pas sur le
contraste, et les deux se règlent par deux leviers différents.

**UNE seule opération sert les deux** : un lavage **vers le blanc**.
`lerp(c, blanc, w)` laisse à une bande exactement **(1 − w)** de sa chroma ET
lui monte la luminance. Le réglage se dérive alors par deux bornes mesurées :

* **plancher** — la bande la plus criarde ne doit plus crier plus fort que la
  chroma moyenne des marqueurs (`w ≥ 1 − chroma_marqueurs / chroma_bande`) ;
* **plafond** — la paire de bandes que le plan sépare PAR LE TON la plus
  serrée doit rester au-dessus de la limite de résolution du plan (son propre
  saignement d'alpha : `w ≤ 1 − bleed / d_min`).

Au CH48 : `[0,3382 ; 0,6545]`, et le lot livre le plancher.

⚠️ **Et une paire déjà sous le saignement AVANT le lavage n'est pas de son
fait** : `GRASS_A`/`LAWN_A` sont à 0,0640 pour un saignement de 0,08 — ces
deux bandes n'ont **jamais** été séparées par le ton, c'est la haie tracée
entre elles qui le fait. L'exclure **par son nom** et asserter qu'elle reste
la plus serrée, sinon une SECONDE paire tombée sous le seuil se cache
derrière elle.

### ⚠️ UNE MÉTRIQUE D'AIRE NE SÉPARE PAS DEUX IMAGES, ET NE PEUT PAS NOMMER UNE TAILLE

Deux faits mesurés au CH48, sur la métrique que CH46 et CH47 avaient rendue
canonique (`|couverture(A) − couverture(B)|`) :

1. **Elle lit ~0 pour deux glyphes de même gabarit**, quelles que soient les
   images dedans — et **0,0000 pour deux glyphes IDENTIQUES, en appelant ça
   une réussite**. Une aire scalaire ne distingue pas deux images, seulement
   deux empreintes. La remplacer par une couverture de **DÉSACCORD** : quelle
   part de la boîte les deux cartes d'encre ne partagent pas, chacune lue
   contre sa propre ligne de base. Mesuré au CH48 : 0,0230 sur la métrique
   d'aire contre **0,5721** sur le désaccord, pour la même paire.
2. **Elle ne dégrade pas avec la taille — elle EMPIRE quand l'icône
   grandit** (pire paire 0,551 à 16 px contre 0,483 à 64 px : à 16 px une
   plus grande part de la boîte est du bord, où deux sujets diffèrent).
   **Un critère qui s'améliore quand l'image rétrécit ne peut pas nommer une
   taille minimale**, et le dire fait partie du résultat.

Ce qui dégrade monotoniquement, c'est **ce qui survit au
sous-échantillonnage** : descendre à S, remonter, comparer au rendu de
référence. Le barreau se choisit alors sans seuil inventé — **le dernier qui
rende encore au moins la moitié de ce que rendait le premier pixel**.

### ⚠️ UN GLYPHE POSÉ SUR UNE POSITION FRACTIONNAIRE PERD SES DÉTAILS DE 1 À 2 PIXELS

CH47 en connaissait la moitié (« le cœur pleinement opaque du point fait
neuf pixels AVANT le placement sous-pixel du widget », et sa sonde en a lu
quatre). CH48 l'a retrouvé par l'autre bout : un anneau de 2 px **culminait
à 0,835 de son ton au lieu de 1,000** sur les seuls glyphes dont la position
était fractionnaire, et la sonde a lu **ZÉRO** pixel du ton sur quatre
d'entre eux alors que l'anneau était parfaitement visible sur la capture.

**Règle** : tout glyphe d'atlas dessiné 1:1 se pose sur un **pixel entier**
(`.round()` sur l'origine du rect). Le coût est au plus un demi-pixel de
position ; le gain est que chaque détail de 1 à 2 px — un contour, un
liséré, la keyline qui porte le contrat de contraste — rend à pleine
intensité. Sans quoi c'est l'ASSERTION qui est réglée sur l'artefact, et
c'est le mauvais bout.

### ⚠️ UNE PROPRIÉTÉ LUE AU BAKE EST PÉRIMÉE POUR TOUT CE QUI ARRIVE APRÈS

Un atlas cuit à la première frame ne peut pas porter une information qui
dépend de l'arbre construit, parce que l'arbre n'a pas fini de se construire.
Mesuré au CH48 : la couleur de type cuite dans chaque portrait a laissé
**quatre entités** — celles qui rejoignent leur groupe après le bake — avec
le liséré NOIR de repli, et la sonde l'a lu comme « 0 px du ton », sur une
carte par ailleurs juste.

Un repaint-sur-changement referme le symptôme et se re-gagne à chaque fois
que l'ordre de construction bouge. **La parade est de sortir l'information
de la cellule** : la cuire en BLANC dans une cellule à elle et la teinter au
`modulate` **au moment du dessin**, là où la question a toujours une réponse
juste. Ça coûte un quad de plus par glyphe, de la même texture, donc rien en
draw calls.

### ⚠️ UN BAKE OFFSCREEN SE HEURTE À TROIS TERMES DE DISTANCE, PAS UN

Photographier une entité du monde construit pour en faire une vignette
paraît neutre. Au CH48, une seule assertion — « le même sujet vu de 5 u et
de 9 u est une seule image » — est sortie **ROUGE sur 17 sujets sur 22**, et
il a fallu **trois** causes distinctes pour la refermer :

1. **le monde n'était pas figé** (les acteurs bougent : deux prises à
   quatre frames d'écart sont deux poses) ;
2. **`visibility_range_end` est un cull de DISTANCE** — un sujet
   photographié au-delà du sien n'est pas une image sombre, c'est **aucune
   image** ; à lui seul, 16 rouges sont tombés à 6 ;
3. **`haze` et `rim` sont deux vrais termes de distance du rendu livré**
   (`rim` reconstruit un vecteur de vue depuis `VIEW`, qui reste positionnel
   **même sous une caméra orthographique**).

**Règle** : un bake d'entité se prend à la **distance propre de la caméra du
jeu** (`HubCamera.OFFSET.length()`, 11,7034 u — la seule distance d'où un
joueur voit quoi que ce soit sur ce plateau), le monde **figé**, les culls de
distance neutralisés, et ce qu'on choisit de couper est **énoncé** plutôt que
subi. Corollaire : le `TIME` d'un shader **n'est pas arrêté par
`SceneTree.paused`** — une voile en mouvement faisait différer deux prises
d'un canal entier (pic 1,000).

### ⚠️ UN OUTIL QUI ÉTIQUETTE SES SUJETS PAR « PARENT/CLASSE » PEUT SE COLLISIONNER, ET LA COLLISION SE LIT COMME UNE MESURE

CH46 avait déjà noté que cinq des marqueurs du hub n'ont **aucun nom**
(`@Node3D@228`). Le repli naturel — « parent/classe » — a fait porter à
l'ours et au blaireau **la même étiquette** ; la seconde prise a écrasé la
première dans le dictionnaire, et la matrice de séparation a rapporté la
paire à **0,0000** : deux maillages de 5846 et 5623 triangles déclarés
identiques parce qu'ils étaient la même image stockée. **Un défaut d'outil
qui ressemble exactement à une trouvaille.**

**Règle** : tout outil qui indexe des sujets par étiquette **asserte
l'unicité de ses étiquettes** avant de publier quoi que ce soit, et le repli
pour un nœud anonyme est son **fichier de scène** (`scene_file_path`), la
seule identité qu'il porte encore.


### ⚠️ « QUI NE LIT AUCUN PIXEL TOURNE EN HEADLESS » EST FAUX — L'AXE EST CE QU'ON RELIT DU MOTEUR

Précision d'une règle déjà écrite, et elle a coûté un faux-vert complet au
CH50. Ce fichier dit qu'une sonde qui ne lit **que des transforms**
(`unproject_position`, `PursuerFramingAudit`) doit tourner **en headless**,
parce que llvmpipe la fait dépasser dix minutes. C'est vrai — et une sonde
neuve s'en est autorisée pour lire des instances de `MultiMesh`.

`unproject_position` est un **calcul pur** ; `get_instance_transform()` est
une **relecture du moteur**, et c'est le point 2 de la liste du driver
dummy. Mesuré sur le hub livré, même arbre, même commande, seul le driver
change :

| driver | instances | non-identité |
|---|---|---|
| `--headless` | 2 743 | **0** |
| `xvfb` + `--rendering-driver opengl3` | 2 743 | **2 743** |

La sonde a donc compté **zéro** décor sur le sol qu'elle testait, et son
assertion d'ABSENCE (« rien en dehors ») est sortie **VERTE**, parce que
zéro la satisfait aussi.

**Règle** : l'axe n'est pas « pixels ou pas », c'est **« qu'est-ce que je
relis du moteur »**. Une sonde qui relit un `MultiMesh`, un viewport ou un
shader a besoin d'un vrai driver même sans échantillonner un fragment ; le
coût llvmpipe se paie en **rétrécissant le `SubViewport`** (96 × 160
suffit), pas en retombant sur le dummy. Et la parade vit **dans la sonde**,
jamais dans son en-tête : un **contrôle d'instrument** qui exige que les
transforms relues soient non-identité, et qui échoue bruyamment au lieu de
compter un zéro tranquille.

### ⚠️ UNE FAMILLE DE BATCH REMPLIE PAR PLUSIEURS PASSES AUX RÈGLES DIFFÉRENTES

Le mur forestier et les quatre haies partagent la famille `wall_near`, et
**n'obéissent pas au même filtre** : le mur d'anneau refuse tout candidat à
moins de `WALL_CLEARANCE` du sol marchable, une haie ne teste rien de tel —
elle **borde** un bord de couloir, s'en écarter est la seule chose qu'elle
ne doit pas faire.

Un gate écrit sur la FAMILLE mesure donc la mauvaise population. Au CH50 il
est sorti **rouge sur 42 arbres**, et l'explication écrite pour ce rouge
(« le filtre livré échantillonne huit points, un arbre peut passer dessous »)
était **fausse** : recalculée arbre par arbre, elle montrait que **41 des 42
auraient été rejetés**. Séparées par la CELLULE de la clé de batch, il en
restait **1**, et celui-là passait bien le filtre 8 points.

**Règle** : compter chaque passe séparément — et **asserter que la somme est
le total de la famille**, sans quoi une cellule que le lecteur ne connaît pas
sort des arbres du gate en silence. Un rouge portant la mauvaise explication
envoie diagnostiquer la mauvaise chose ; c'est pire qu'un rouge muet.

### ⚠️ UN GATE DE CONTRASTE DONT L'ENCRE EST NOIRE PAR CONSTRUCTION EST UN TEST DU SOL

Dix-huitième faux-signal du dépôt, CH50, et c'est une **loterie publiée
comme un contrat**. `MinimapProbe` asserte « le bord de la plaque franchit
3,0:1 tout autour ». Or son échantillon d'encre est le **minimum** sur la
coque, donc le liséré **NOIR** par construction — la sonde asserte ailleurs
que chaque cellule en porte un. Contre une encre noire, WCAG vaut
`(L + 0,05) / 0,05` : **3,0:1 exige que le SOL soit à L ≥ 0,10**, et rien
d'autre n'entre dans le calcul.

L'assertion mesure donc la luminance du **plan**, en portant le nom du
marqueur — et elle passe ou échoue selon **où un marqueur atterrit**.
Balayage du plan rendu : `origin/main` porte **166 px (0,21 %)** de sol peint
sous L 0,10, le plus sombre à **L 0,0656 = exactement 2,31:1**. Élargir le
cadre a déplacé une plaque sur cette bande, et la loterie a été perdue.

**Règle** : quand une des deux moitiés d'un ratio est **fixée par
construction**, le gate porte sur l'autre moitié — le dire, et gater ce qui
est défendable (*la part du périmètre qui tombe sur du sol inatteignable
reste petite*) plutôt qu'un seuil que le dessin du marqueur ne peut pas
atteindre. C'est le pendant de « la métrique peut être la mauvaise, et le
chiffre vert avec » : ici la métrique est fausse **et le chiffre était vert
par chance de placement**.

### ⚠️ UNE EXEMPTION « SAUF LÀ OÙ X COUVRE DÉJÀ » SE RECONSTRUIT ET SE GATE

Corollaire opérationnel de « une liste de ce qui n'est pas le sujet est
fausse au premier nom oublié », côté ASSERTION DE FRONTIÈRE. Deux sondes
écrivaient « juste en dehors du bord, c'est non marchable **sauf là où le
CARRÉ couvre déjà** » — vrai tant que le carré était le seul autre terme à
atteindre ce bord. CH50 en a ajouté un, et le lobe de structure P2 de CH21
en était déjà un troisième, court de **quatre azimuts sur 721**.

**Règle** : l'exemption se prend dans ce que la région **PUBLIE**, et — c'est
la moitié qui compte — la sonde **asserte que cette reconstruction reproduit
`contains()` sur chaque échantillon** (721/721, 360/360). Le prochain terme
d'union échoue alors **bruyamment là**, au lieu d'être oublié en silence.

### ⚠️ UNE VITESSE N'EST PAS UNE CONDUITE — UN PROFIL L'EST

CH54, sur le skate CH53. Mathieu, device en main : « il est sur le skate
mais il ne le conduit pas ». Le tracé (`SkateDriveProbe`, taps par le
vrai canal) a lu **16,0 u à 7,941 u/s dès la frame 1**, arrêt sec, six
arcs de 1,30 u — le câblage était juste, le véhicule bougeait, et il
bougeait exactement comme la balle avec une planche dessinée dessous.
Un multiplicateur de vitesse (× 1,48 la marche) n'a pas suffi à se lire
comme une conduite ; ce qui se lit est un **profil** : un départ qui
monte, une croisière propre, un arrêt qui s'étale, une relance après un
demi-tour. Les trois manquaient, et aucune assertion « il va plus vite
qu'à pied » ne les aurait vus.

**Règle** : un véhicule se spécifie et se gate sur son profil de vitesse
(premières frames, frame d'atteinte de la croisière, dernières frames,
continuité aux frontières de segment), jamais sur sa seule vitesse de
pointe. Et un tel retour device se tranche **par tracé de position frame
par frame** avant d'écrire une ligne : H1 (rien ne bouge) et H2 (ça
bouge sans se lire) ont des correctifs opposés, et la lecture du code ne
les distingue pas — tout y était correct.

⚠️ **Corollaire mesuré dans le même lot** : une conduite plus lente de
bout en bout que la chose qu'elle remplace n'est pas une conduite. Les
rampes coûtent ; la première croisière (9,0) rendait 2,233 s sur 16 u
contre 2,100 s pour le rebond. Publier le temps DE BOUT EN BOUT à côté de
la croisière.

### ⚠️ UNE SONDE NE PEUT PAS JUGER UN GAME FEEL — ET UNE PHASE QUI PRÉTEND LE FAIRE EST LE PROCHAIN FAUX-SIGNAL

Écrit au CH62, après un verdict device — « je ne vois pas de différence,
je n'arrive pas à m'amuser » — rendu sur un build dont **toutes les
sondes étaient vertes et dont toutes les mesures étaient justes**. CH61
avait mesuré 0,098 u de montée à 2,98 u/s contre 1,106 u à 8,97 u/s, un
ordre de grandeur ; la physique faisait exactement ce que les chiffres
disaient. Rien à l'écran ne la restituait.

**Un banc headless ne voit ni une sensation, ni un plaisir, ni une
lisibilité.** Ce qu'il peut signer, et c'est déjà beaucoup :

* qu'une réponse est une **COURBE** — bornée, monotone, continue — et
  **qu'elle BOUGE** (le spread se gate AVANT la monotonie : une constante
  est monotone, bornée et sans palier) ;
* qu'un effet est **CÂBLÉ** à cette courbe — en relisant la valeur **sur
  l'objet vivant** (`camera.fov` tel que le moteur le tient, le
  `pitch_scale` du player, le `rush` que le nœud va dessiner) pendant que
  le vrai mécanisme tourne. **Rappeler l'API et la comparer à elle-même
  est une tautologie qui reste verte sur un effet débranché** — c'est le
  18e faux-signal du dépôt ;
* que **rien ne tourne** hors de l'interrupteur ;
* **ce que ça coûte**, et qu'un effet DESSINÉ dessine réellement des
  PIXELS (CH39).

Ce qu'il ne peut pas signer se **dit dans le rapport**, à la première
ligne du fichier de sonde comme à la première ligne du rapport de lot. Un
feu vert qui sous-entend « c'est agréable » sur un lot de game feel est
le pire faux-signal possible, parce que le lot d'avant était vert partout
et faux quand même.

⚠️ **Corollaire de forme** : une géométrie d'overlay écrite en PIXELS
ABSOLUS n'a pas la même force sur deux écrans. Mesuré au CH62 : le même
champ de traînées encrait **0,694 %** d'une surface headless de 1920 de
haut et **1,233 %** de la fenêtre xvfb — deux fois plus fort d'un côté,
sans rien pour dire lequel le téléphone aurait. Toute dimension d'un
effet plein cadre est une **FRACTION du contrôle**, et sa couverture est
publiée comme une constante.

### ⚠️ UNE LECTURE RÉPÉTÉE NE DÉTECTE PAS UNE VALEUR PÉRIMÉE

Complément exact de « un delta sans son plancher ne vaut rien » (CH40) et
de « le coût se lit là où l'instrument est immobile » (CH41), et il ferme
le trou que ces deux-là laissent : **les deux se défendent par une
LECTURE RÉPÉTÉE, et une valeur périmée se répète parfaitement.**

Mesuré au CH62, monde gelé par `get_tree().paused` : le compteur de
primitives lit **85 812 deux fois de suite, tremblement ZÉRO**. On
déplace la caméra de 2,3 u et on la remet exactement où elle était : il
lit **86 127 deux fois de suite, tremblement zéro encore**. **Deux états
parfaitement stables pour UNE seule pose**, et le premier est faux.

La cause est structurelle : **un moteur ne réévalue pas ce qu'une caméra
gelée voit tant qu'elle ne BOUGE pas.** Un plancher de bruit pris sur
deux lectures dos à dos mesure la stabilité du cache, pas celle de la
scène.

**Parade** : une configuration n'est **jamais lue là où on la trouve**.
On l'emmène ailleurs, on donne des frames, on la repose sur la
configuration à mesurer, on redonne des frames, et seulement là on lit —
deux fois, les deux publiées.

⚠️ **Et même avec ça, le compteur reste DÉPENDANT DU CHEMIN** : la même
pose lit 86 432 quand c'est le jeu qui a mis la caméra là et 86 133 quand
c'est le protocole de secousse, les deux se répétant exactement. Un
compteur de frame gelé se publie donc comme un **ORDRE DE GRANDEUR**,
jamais comme un chiffre à l'unité — et une décomposition dont les parties
ne somment pas au tout se **refuse** au lieu de se publier (mesuré :
+203 et +1 460 pour deux termes qui valent +8 165 ensemble).

⚠️ **Corollaire, payé dans le même lot** : un banc qui bascule un objet
entre deux lectures pendant que le MONDE tourne mesure le monde. Éteindre
un quad de deux triangles « coûtait » **+5 747 primitives** — la vraie
mesure était le déplacement de la caméra entre deux captures espacées de
trois frames. **Geler d'abord**, et se rappeler que `paused` n'arrête pas
le `TIME` d'un shader (CH48) : un plancher de PIXELS reste nécessaire, et
il se prend avec un seuil (0,02 pleine échelle a suffi) plutôt qu'en
inégalité stricte, sinon il vaut 85 % de la surface.

### ⚠️ UN PARCOURS DE BANC QUI NE TIENT PAS DANS LA RÉGION MESURE UN RUN QUI N'A JAMAIS EU LIEU

`HubRegion` est un mur pour tout véhicule de ce dépôt, et le mur
**REFUSE le pas ET EFFACE LA CIBLE** (`SandYacht._wall`, `SledBody._wall`,
`SkateBoardBody._fence`). Un banc qui gare son sujet hors région, ou qui
lui donne une course d'élan qui déborde, ne mesure donc pas un run lent :
il mesure **l'absence de run**, et toutes ses lectures sont vraies.

Mesuré au CH62 : une approche tapée de 9 u vers un module à (5 ; 54) part
de z = 63,7, hors du lobe skate (centre (0 ; 35), r 28, qui atteint
z = 62,55 à x = 5). Sortie : `air ticks 0 | peak lift 0,000 | camera climb
0,000` — trois zéros qui se lisent exactement comme « l'effet n'est pas
câblé ».

**Règle** : toute course de banc **vérifie `HubRegion.contains()` sur son
point de départ** et se raccourcit jusqu'à tenir, puis **gate qu'elle est
restée assez longue** pour être une instance de ce qu'elle mesure. Un
départ hors région n'est pas un run court, c'est un run absent.

### ⚠️ UN CAP SUR L'ORBITE NE BORNE PAS LE LACET D'UN LOOK-AT

Mesuré au CH64, sur la caméra de poursuite calmée de la planche. Un taux
de lacet maximal posé sur l'angle d'orbite (`_drive_heading`) a laissé
passer **170 °/s** la première seconde d'un doigt tenu plein travers : la
pose est un `look_at`, et un look_at lace avec la POSITION de la cible
quoi que fasse l'orbite. Un cap qui doit borner ce qu'un joueur VOIT
s'applique **sur la pose finie**, image par image (lire le lacet du
transform, le comparer au précédent, ramener au cap par rotation autour
de Y) — jamais sur une variable intermédiaire dont la pose n'est qu'une
fonction parmi d'autres.

⚠️ **Et une pose de poursuite près d'un BORD est dans les arbres-murs.**
`CozyScatter` plante des arbres le long du bord de la région ; une planche
au bord nord du park face au sud met la caméra 7,6 u derrière elle, HORS
région, plein cadre de feuillage. La pose se clampe à la région et se tire
vers la cible — **jamais jusque DESSUS** : à distance nulle le look_at est
dégénéré et la cible est sous le bord bas du cadre (0 pixel mesuré).
Garder au moins un demi-unité derrière, et faire converger la visée vers
la cible quand la distance tenue diminue. Le gate est un rendu : la
cible peinte, ses pixels EXIGÉS à chaque bord (ChaseAudit PHASE CALM).

### ⚠️ UN BANC DONT LE DOIGT SAUTE FABRIQUE DU VIRAGE

Un reconnaisseur de cercle par NOMBRE DE TOURS (somme des angles signés
entre segments successifs du doigt) compte honnêtement **tout** segment,
y compris celui qu'un banc fabrique en téléportant son doigt de « tenu en
haut » à « départ du cercle » : 140 px d'un coup, soit −170° de virage
avant la première boucle, et un cercle réel lu comme un crochet. Un banc
qui dessine un geste part de **là où le doigt EST**, jamais d'une
constante — un pouce ne se téléporte pas. (CH64, `SkateTrickProbe`, une
passe rouge devenue verte pour cette raison avant d'être comprise.)

### ⚠️ LE DÉCOR D'UN SOLIDE VA DANS UNE SECONDE SURFACE

`SkatePhysicsProbe` PHASE G gate que l'union des pièces convexes d'un
module EST l'ensemble de ses sommets dessinés — le gate qui attrape un
dessiné qui diverge de son solide. Un tube de coping ajouté à la surface 0
l'a rougi, correctement. Toute géométrie DESSINÉE ET NON SOLIDE (coping,
cornière, garniture) va dans une **seconde surface** du même `ArrayMesh`
(même matériau, un draw call de plus) : la surface 0 reste le solide, et
les bancs qui pricent un collider (`PhysicsCostProbe`) ne lisent
qu'elle. Et `triangle_count()` publie les DEUX comptes, jamais un seul.

### ⚠️ UN GESTE NE SE PROUVE PAS SUR UN POP SYNTHÉTIQUE — IL SE MESURE CONTRE LA FENÊTRE QUE LE JEU LUI OUVRE

Écrit au CH66, après que CH64 ait livré des tricks à **54 assertions
vertes** que Mathieu n'a jamais vus tirer sur device. Rien n'était faux :
le reconnaisseur, l'air armé, la coupe à l'atterrissage, le flip, le HUD
et le son étaient chacun prouvés — sur un `velocity.y = 6,0` posé à la
main (0,46 s d'air) et un cercle livré **trois points par tick** (une
boucle en 0,2 s). Mesuré sur la vraie rampe, par le vrai canal : le grand
quarterpipe sortait la planche à **3,76 u/s**, 0,13 u au-dessus de sa
lèvre, pour **10 ticks armés — 0,17 s**. Le geste, pricé sur le
reconnaisseur lui-même, coûte **224,8 px** de pouce (300° à r 40, segments
de 8 px), soit 0,56 s à 400 px/s, plus ~0,2 s pour VOIR le décollage.
Aucune assertion ne compare ces deux nombres ; aucune ne pouvait rougir.

**Règle** : toute mécanique déclenchée par un geste DANS une fenêtre
(un air, un timing, un QTE) se gate sur l'inégalité **fenêtre mesurée sur
le chemin réel ≥ réaction + coût du geste**, les deux côtés publiés dans
la même sonde, contre un pouce de référence ÉNONCÉ (rayon, vitesse,
réaction) et non contre le pouce parfait d'un banc. Le coût du geste se
prend sur le reconnaisseur livré (nourrir des points jusqu'au tick où il
tire), jamais sur la formule qu'on croit qu'il implémente. Et une passe de
bout en bout — vraie rampe, vrai writer, pouce de référence — doit
produire le trick, avec un NÉGATIF (un pouce plus lent que la fenêtre)
qui ne le produit pas, sinon le gate est gratuit.

⚠️ **Corollaire de pop** : un impulse « au décollage » n'est un ollie que
depuis une surface qu'on RIDAIT (n ticks d'appui, tolérant aux
scintillements de `is_on_floor` aux joints de facettes) et depuis la
LÈVRE (dernière normale d'appui à moins de 10° de la verticale, la
dernière facette de la transition et jamais celle du dessous). Mesuré,
en trois temps : sans garde d'appui, une capsule qui frôle l'arête de la
lèvre un tick en sortant pope DEUX fois (+10 u/s, pic 5,3 u) ; à 60°,
une capsule poussée dans une cuvette ne pope plus depuis ses bosses de
9-45°, mais une planche en roue libre à un mètre sous la lèvre du grand
quarterpipe (facette de 61°) pope du mur, retombe dans la transition, et
casse la signature d'énergie de `SkateInertiaProbe` (ratio 2,014 contre
1,165) ; à 80°, les deux rampes et le bol popent de leur dernière facette
et de nulle part ailleurs. Une géométrie qui rend un seuil juste
s'ASSERTE (la dernière facette passe, celle du dessous non), elle ne se
lit pas dans le commentaire du seuil.

### ⚠️ LE PROP D'OÙ UNE MARCHE PART N'EST PAS UN OBSTACLE POUR ELLE

Écrit au CH67, et la panne ressemble **exactement** à un site qui ne peut
pas marcher. Un balayage d'itinéraire qui refuse tout segment passant à
moins de `KEEPY_CLEARANCE` d'un prop publié échoue à son **PREMIER
échantillon**, pour **tous** les azimuts, quand l'acteur se repose à 1,5 u
d'une balançoire dont le rayon d'empreinte publié est 1,80. Le verdict
sorti est « AUCUN AZIMUT VALIDE » — c'est-à-dire le mot qu'on emploierait
pour dire « ce site est impossible » — alors que la marche est parfaitement
propre.

CH25 ne l'avait jamais rencontré parce que son propre balayage listait le
**décor** et rien d'autre ; le jour où la liste est devenue « tout ce que
les bâtisseurs PUBLIENT » (ce qui est le bon réflexe, cf. « le producteur
publie ce qu'il a construit »), le prop de départ y est entré avec.

**Règle** : tout test de trajet exempte ce qui contient déjà son point de
DÉPART, et **compte les exemptions qu'il accorde** — sans quoi l'exemption
redevient la porte de sortie de tout le monde. Corollaire de méthode : un
screening grossier et un test fin qui se **contredisent** ne sont pas deux
opinions, c'est une mesure et un artefact ; le premier réflexe est de
chercher ce que le fin voit que le grossier ne voit pas.

### ⚠️ UNE JAMBE QUI FRANCHIT UN SEUIL DE MÉCANISME N'EST PLUS COMPARABLE

Corollaire exact de « une jambe de mesure A/B change de régime en cours de
route » (CH41), appliqué non plus à une DIRECTION mais à un **mécanisme
qui s'ajoute**. Mesuré au CH67 sur `SkateInertiaProbe` PHASE E2, dont le
contrat est « la hauteur atteinte est réglée par l'ÉNERGIE et non par la
FORME » : les deux lois décrivent une planche qui CONVERTIT son arrivée en
hauteur sur la transition. Une planche qui atteint la LÈVRE cesse de
convertir et reçoit `POP_SPEED` **EN PLUS** — un ollie, 5 u/s verticaux
que l'arrivée n'a pas payés. Son pic ne répond à aucune des deux lois, et
le ratio calculé à travers ce basculement est sorti à **1,618 contre un
plafond de 1,25** sur un mécanisme parfaitement sain.

**Règle** : une comparaison entre deux jambes **exclut et PUBLIE** tout
échelon où l'une des deux a franchi un seuil qui ajoute un terme, et un
garde exige qu'il reste assez d'échelons pour que la comparaison en soit
une. Mesuré des deux côtés : sur l'arbre de référence aucun échelon ne
franchit (4/4 comparables), sur celui qui a bougé un seul le franchit
(3/4) — c'est cette différence, et non le ratio, qui était la trouvaille.

### ⚠️ UN VERDICT LU SOUS LE MAUVAIS DRIVER N'EST PAS UN VERDICT

Ce fichier documente longuement quel driver une sonde exige. Le CH67 a
payé le pendant opérationnel : `SkateDriveProbe`, une sonde **xvfb**,
lancée par erreur en `--headless` dans un lot de table croisée, est sortie
à **12 rouges** — et ses phases d'instrument, elles, étaient VERTES (« the
container has a real rect », « the parked board projects inside »), ce qui
donne à la sortie toute l'apparence d'une régression circonstanciée.
Relancée sous `xvfb --rendering-driver opengl3` : **ALL GREEN**.

**Règle** : le driver de chaque sonde est une propriété DE LA SONDE et se
lit dans son en-tête avant de la lancer, jamais après avoir lu son
verdict. Une table croisée qui mélange les deux publie des rouges qui
n'existent pas, et c'est le genre de rouge qu'un lot suivant corrige.

### ⚠️ UN PARAMÈTRE DE GOÛT CESSE D'EN ÊTRE UN DÈS QU'UN AUTRE LOT S'APPUIE DESSUS — ET RIEN NE LE MARQUE

Écrit au CH70, sur une réouverture autorisée qui s'est terminée en
refus. `HubTransport.SKATE_CRUISE` a été authored au CH54 comme un
**goût** — « 10,0 u/s est ×1,87 la marche, le park fait 10 u de long,
donc une nuance en dessous » — et son bloc de commentaire dit
explicitement que c'est un chiffre de ressenti. Sept lots plus tard, le
baisser de 35 % **éteint la couche de tricks entière**.

Le mécanisme n'est écrit nulle part parce que personne ne l'a écrit :
la montée d'une transition est plafonnée par la croisière
(`SkateBoardBody.drive()` n'ajoute rien au-delà de `_cruise`), donc la
croisière décide si la planche **ATTEINT une lèvre**. Sans lèvre, pas de
`POP_SPEED` ; sans pop, pas d'aire ; sans aire, aucun trick. CH66 a
mesuré la fenêtre requise (**0,762 s**) et l'a rendue atteignable — et
ce faisant il a transformé, en silence, un goût en **plancher**.

Balayé, huit valeurs, une ligne changée à chaque fois :

| croisière | 6,5 | 7,5 | 8,5 | 9,0 | 9,5 | **10,0** |
|---|---|---|---|---|---|---|
| fenêtre, grand quarterpipe | 0,000 | 0,017 | 0,000 | 0,000 | 0,700 | **0,817 s** |
| rouges `SkateAirProbe` | 18 | 18 | 9 | 7 | 1 | **0** |

**Le premier échelon qui tient le contrat est la valeur livrée, et il le
tient avec 7 % de marge.** Ce n'est donc pas « 35 % c'est trop » : cette
constante ne peut pas baisser **du tout**.

**Règle** : avant de rouvrir une constante qu'un lot ancien a posée comme
un goût, **BALAYER sa plage et publier ce qui rougit à chaque échelon** —
la question n'est pas « de combien la bouge-t-on » mais « qui s'est
appuyé dessus depuis ». Un `grep` du nom ne suffit pas : ici aucun
fichier ne lit `SKATE_CRUISE` pour décider d'une lèvre, le couplage passe
par la **PHYSIQUE** (un plafond de vitesse contre une hauteur authored) et
seul un balayage le voit. Corollaires payés dans le même lot :

* **le chiffre de baseline d'un brief est un chiffre recopié**, donc
  périmé jusqu'à preuve du contraire : `push 17,2165` valait déjà
  16,4253 depuis CH69, et la sonde qui le gatait en littéral était ROUGE
  sur l'arbre livré sans que personne ne la relise (la table croisée du
  lot précédent ne l'incluait pas) ;
* **une sonde qui gate « près de la croisière » avec un littéral** (ici
  `speed_at_foot > 8.0`) est une seconde orthographe de la constante, et
  elle rougit pour la mauvaise raison au premier changement ;
* et **un balayage qui refuse est un RÉSULTAT** : ce qui est livrable
  est alors la table, pas le changement.

### ⚠️ UN FOOTPRINT TESTÉ AVANT LES TIRAGES REBAT LE TAPIS ; TESTÉ APRÈS, IL NE TOUCHE QUE CE QU'IL COUVRE

Écrit au CH71, et ça précise le « irréductible » de CH53. Le CH53 avait
mesuré qu'un prop neuf dont l'empreinte rejette des candidats du
`_sprinkle` leur fait **sauter leurs deux tirages** (échelle, lacet) et
déplace tout le flux RNG d'après — « tout prop ajouté dans ce hub l'a
toujours fait ». Vrai pour un test fait dans `_blocked()`, qui court
AVANT les tirages. Mesuré au CH71 sur le parc d'attractions, empreintes
dans `_blocked()` : grass 1 022 → 985, **bush 22 → 7**, flower 114 → 112
— quinze buissons de moins dans TOUT le hub pour une réserve qui en
couvre deux, c'est-à-dire un tapis rebattu, pas aminci.

**Le même test déplacé APRÈS les tirages** (dans `_sprinkle`, après
`s` et `yaw`) : un candidat rejeté a consommé exactement ce qu'un candidat
placé consomme, le flux est intact, et le tapis hors des disques est
**byte-identique** (bush 22 → 22, grass 1 022 → 990, 307 batches des deux
côtés). C'est le raisonnement de `_keep_hash` appliqué à une empreinte :
**une garde qui doit rester locale ne touche pas le flux.** Règle : toute
empreinte qu'un lot ajoute sur le plateau se teste après les tirages,
jamais dans `_blocked()` — sauf si le lot VEUT rebattre le tapis, et alors
il le dit.

### ⚠️ UNE ROTATION RIGIDE D'UN RIG DE CAMÉRA REND TROIS PROPRIÉTÉS GRATUITEMENT — ET LA PREMIÈRE EST L'INERTIE AU REPOS

Écrit au CH73, en rendant orientable une pose que ce dépôt tenait pour
FIXE depuis le premier lot du hub. La forme qui a rendu ça sûr n'est pas
un réglage : c'est que **les deux moitiés de la pose tournent de la MÊME
rotation**, autour du point que la caméra suit.

```
position = ground + R * OFFSET
basis    = R * _hub_basis
```

Trois propriétés en tombent, aucune réglée, chacune gatée :

1. **à angle nul R est l'IDENTITÉ**, donc tout le code ajouté est
   arithmétiquement inerte sur un arbre où personne n'a touché la
   commande — c'est la forme qui permet d'affirmer « le cadre livré est
   byte-identique » comme un fait et non comme une promesse. Le corollaire
   d'écriture est que **chaque site s'en garde explicitement** (`if
   orbit_is_rest(): return`), sur le patron du no-op de `_apply_pov` :
   écrire la même valeur est arithmétiquement neutre mais un `slerp`
   aller-retour dérive sur une longue session ;
2. **la distance est invariante** — `|R·v| = |v|` pour toute rotation.
   Quand un brief interdit d'ajouter un zoom, cette forme le rend
   impossible **par accident** plutôt que par convention ;
3. **tout désaccord authored entre la position et la visée est
   TRANSPORTÉ.** `HubCamera` ne regarde pas Keepy (6,5° d'écart entre
   l'élévation de l'`OFFSET` et le tangage de la scène, CH36), et une
   rotation rigide préserve ce cadrage à tous les angles — là où un
   `look_at` recalculé l'aurait effacé.

⚠️ **ET LE ROULIS EST NUL PAR ARITHMÉTIQUE, PAS PAR CLAMP** : si le basis
authored est une rotation pure autour de X et que le pivot l'est aussi,
le produit vaut `Ry(lacet) · Rx(−tangage)`, dont le vecteur haut reste
dans le plan vertical. Mesuré sur toute la bande : pire `|basis.x.y|` =
**0,000000000**. Un roulis nul par construction vaut mieux qu'un roulis
clampé, et CH64 a déjà payé la nausée une fois.

⚠️ **LES DEUX MOITIÉS RETARDENT ENSEMBLE OU LE RIG N'EST PLUS RIGIDE.**
La position du hub est lissée ; un basis qui snapperait viserait où la
caméra **va être** au lieu d'où elle **est**, et le sujet sortirait du
cadre pendant un geste rapide pour y revenir après. Même poids, même
retard, même forme.

⚠️ **Corollaire de bornes, et il a réfuté le critère qu'on cherchait en
premier** : sous rotation rigide le cadrage est INVARIANT, donc « le
sujet sort du cadre » ne borne **rien** — mesuré aux quatre-vingt-dix pas
d'un balayage au degré, la couronne est dans le cadre partout. Et le
balayage n'a montré **aucun genou** sur la fraction d'écran adressable
(93,3 % au repos, 66,7 à −22, 40,0 à −40). Une borne se pose alors sur
une **PROPRIÉTÉ re-mesurable** et pas sur un nombre lu sur une courbe :
ici le dégagement au sol contre la taille du personnage, le tangage
encore descendant, et — en haut — le **rayon horizontal non nul**, parce
qu'au zénith un lacet est une rotation autour d'un axe colinéaire au
bras et **ne déplace la caméra nulle part**, ce qui rend la commande
morte sans rien pour le dire au joueur.

### ⚠️ UN SEUIL DE GESTE SE REPREND D'OÙ IL EST PUBLIÉ — MAIS PAS FORCÉMENT TOUT LE JEU DE CONSTANTES

Complément de « un fait est publié une fois, jamais recopié », côté
INPUT, et il coupe dans les deux sens. Au CH73, `SkateTouchInput` publiait
déjà `SLOP_PX = 16,0` et `TAP_MAX_S = 0,45` comme réponse du dépôt à « ce
qui sépare un tap d'un drag ».

**`SLOP_PX` se reprend** : son propre commentaire le justifie en termes de
**pouce et de téléphone** (« un peu plus d'un millimètre »), pas de
planche. C'est le même fait, et une seconde orthographe serait un défaut
qui attend la première passe de réglage.

**`TAP_MAX_S` se refuse**, et c'est la moitié qui compte. Sur la planche,
un doigt TENU a un **second sens** — c'est l'accélérateur — donc la limite
de temps sépare deux gestes **réels**. Dans l'écran qui reprenait la
constante, un doigt tenu n'a aucun autre sens : la limite n'y aurait
inventé qu'un **troisième résultat** (presser, attendre, lever, RIEN)
sans aucun retour pour l'expliquer.

**Règle** : on reprend une constante de geste quand la PROPRIÉTÉ
qu'elle mesure existe dans le nouveau contexte, pas parce qu'elle est
voisine de celle qu'on reprend. Deux constantes publiées ensemble ne
forment pas un lot indivisible, et l'argument se prend dans **ce que le
geste peut vouloir dire d'autre ici**.

⚠️ **ET UNE CONSTANTE EN TEMPS RÉEL REND UN BANC DÉPENDANT DE LA
CHARGE.** `TAP_MAX_S` se lit sur `Time.get_ticks_msec()` ; `--fixed-fps`
ne fixe que le pas de **simulation**. Mesuré sous llvmpipe : **une frame
vaut ~0,14 s de temps réel**, donc le tap de six frames d'une sonde dure
**0,824 s** et tombe hors d'une fenêtre de 0,450. L'assertion passait ou
échouait **selon la charge machine**, et a envoyé une passe rouge
diagnostiquer un défaut inexistant. C'est « une sonde à séquence
temporelle se rejoue à charge comparable » arrivant par le CODE au lieu
du banc — et c'est une **preuve** à l'appui d'une décision, jamais sa
raison : un seuil ne se retire pas parce qu'un banc le gêne.

### ⚠️ UN DOUBLE DISPATCH SE NEUTRALISE PAR L'INTÉGRATION, PAS PAR UNE RÉCLAMATION DE CANAL — ET LA PASSE ROUGE EST CE QUI L'A DIT

Vingtième faux-signal du dépôt, CH73, et il est du genre **« le mécanisme
crédité n'est pas celui qui travaille »** — la même famille que le CH65
(« la neutralisation qui revient verte dit à qui revient le mérite »),
sur un axe d'entrée.

Ce fichier documente que `emulate_mouse_from_touch` fait arriver un doigt
**deux fois**, et que `HubTapInput` ne peut pas filtrer
`DEVICE_ID_EMULATION` comme le font `KartTouchInput` et `SkateTouchInput`,
parce que sur navigateur desktop la classe souris est la **seule**. Un
geste continu ajouté là est donc exposé à un **gain doublé sur téléphone**.

La parade écrite fut une **réclamation de canal** : le premier appui
réclame le geste, la classe jumelle est ignorée. Neutralisée, la sonde
est revenue **ALL GREEN** — zéro rouge pour deux prédits.

**Ce qui neutralise réellement le doublement est la façon d'intégrer.**
Une commande qui intègre la différence entre échantillons **CONSÉCUTIFS**
(`at − dernier`) encaisse un jumeau livré au **MÊME pixel** comme un
delta puis **exactement zéro** : le doublement ne peut pas se produire,
quelle que soit la réclamation. Une commande écrite en **offset depuis
l'ancre** double, elle, et bien pire (mesuré : le même pixel deux fois
sort au **double**, et la sur-intégration fait franchir ±π au lacet, donc
`wrapf` **inverse le signe**).

Deux règles :

1. **Toute commande continue pilotée au doigt s'intègre par delta entre
   échantillons consécutifs**, jamais en offset depuis l'ancre — c'est ce
   qui la rend immune au double dispatch, et au passage ce qui fait qu'un
   doigt revenu à son point de départ ramène la commande avec lui.
2. **Un garde qu'une neutralisation ne parvient pas à faire rougir n'est
   pas gaté**, et le dire vaut mieux que le prétendre (précédent explicite
   de `SkateTouchInput` sur son propre filtre). Chercher alors ce qu'il
   achète **vraiment** : ici, que `_dragged` survive au geste par
   conception (les deux relâchements d'un jumeau doivent lire le même
   latch) rend une **souris déplacée sans bouton enfoncé** capable de
   piloter la commande avec un échantillon périmé. **Un survol n'est pas
   un geste** — un défaut desktop, invisible depuis le téléphone que le
   garde était censé défendre, et c'est lui qui gate désormais.

⚠️ **Corollaire de latch, et il est contre-intuitif** : un latch de geste
partagé par deux classes d'événements se remet à zéro sur l'**APPUI qui
réclame**, jamais sur un relâchement. Effacé au relâchement, il est déjà
vide pour le jumeau, qui relit alors un drag comme un tap — exactement le
défaut que le seuil existe pour fermer, rentrant par la porte de derrière.

### ⚠️ UNE ASSERTION DE STABILITÉ PRISE AVANT LA FIN DE LA CONVERGENCE MESURE LA CONVERGENCE

CH73, sur une assertion neuve qui est sortie ROUGE sur du code juste — et
elle n'a pas été faite taire.

Le contrat était « collant » : la caméra reste exactement où on l'a
laissée, aucun recentrage, aucune interpolation de retour. Écrit comme
« la pose 600 frames plus tard est la pose 60 frames après le lever », il
échoue — parce que la pose était encore en train d'**ARRIVER** : le lissage
a une constante de temps de 0,2 s, donc un échantillon pris une seconde
après le geste porte encore `exp(−5) = 0,67 %` de l'erreur.

**Converger vers ce que l'utilisateur a demandé n'est pas un retour**, et
une assertion incapable de distinguer les deux ne teste pas le contrat.
Ce qu'un état « collant » interdit est la convergence vers l'état
**AUTHORED** : les deux distances se mesurent et se **publient**
(0,00000° de la pose laissée contre 114,51° de la pose d'origine), avec
un instrument qui exige que les deux références soient réellement
différentes — sans quoi la seconde moitié passerait à vide.

**Règle** : une assertion « rien ne bouge plus » sur un système lissé
nomme **vers quoi** il ne doit pas bouger, jamais « il ne bouge plus du
tout ». La forme se reconnaît à ce qu'elle compare deux échantillons de
la MÊME grandeur au lieu de comparer la grandeur à ses deux attracteurs.

### ⚠️ SONDE JETABLE = SUPPRIMÉE AVANT LE COMMIT

`ProbeTimeoutAudit` doit revenir **exactement** à son chiffre de baseline. Une
sonde de mesure ponctuelle n'entre pas dans le dépôt ; une sonde qui gate un
contrat permanent y entre et compte.

### ⚠️ UNE VARIABLE-OMBRE D'UNE PROPRIÉTÉ DE NŒUD N'EST PAS LA PROPRIÉTÉ

Lisser une propriété de nœud (`global_position`) et lisser une **copie**
privée qu'on recopie ensuite dedans (`_hub_position` → `global_position`)
produisent la MÊME trajectoire tant que personne d'autre n'écrit cette
propriété — et divergent net dès que quelqu'un le fait : une sonde qui gare
la caméra à la main, un autre nœud, un `snap`. Trouvé sur `HubCamera` en
mode conduite (V7 karting) : `CabinProbe` posait la caméra au-dessus d'un
seuil et laissait le suivi la tenir là ; avec la variable-ombre, le suivi
ramenait la caméra depuis le spawn à chaque frame, le seuil se projetait
hors du conteneur et cinq taps de seuil étaient jetés — **aucune erreur**,
juste un signal vide. C'est exactement un changement de comportement hors
du mode qui l'a introduit, et rien dans la sonde du mode lui-même ne pouvait
le voir (elle ne gare jamais la caméra à la main).

**Règle** : si un lissage doit rester local à un mode, isoler la variable
d'ombre à CE mode et laisser la propriété réelle lissée directement partout
ailleurs — jamais l'inverse (propriété toujours recopiée depuis l'ombre).

### ⚠️ LA SONDE D'UN LOT NE VOIT PAS LES RÉGRESSIONS DES AUTRES LOTS

Une sonde écrite pour le lot en cours mesure ce que CE lot fait ; elle ne
rejoue pas les usages des lots précédents, et un chiffre vert dessus ne dit
rien du reste du hub. La régression `HubCamera` ci-dessus (99/99 sur
`KartProbe`, verte) n'a été trouvée qu'en rejouant la table des rides
existants — les mêmes sondes que la fermeture du lot précédent — sur DEUX
arbres : la branche du lot et une référence `origin/staging` importée à
part. Le compte de rouges a divergé (1 sur la référence, 6 sur la branche) ;
c'est la COMPARAISON qui a tranché, pas la couleur d'une sonde isolée.

**Règle** : avant de fermer un lot qui touche un mode partagé (caméra,
sauvegarde, entrée), rejouer la table des rides/sondes existants sur les
DEUX arbres (branche et référence importée à part), jamais sur la branche
seule.

### ⚠️ LA CAMÉRA SE TIENT 8,9 u AU NORD DE KEEPY — RIEN DE HAUT DANS CETTE BANDE

Corollaire de `HubCamera.OFFSET (0 ; 7,6 ; 8,9)` que le dépôt n'avait
jamais écrit : tout ce qui est planté **entre 0 et ~10 u au NORD (+z) d'un
sol marchable** se retrouve **entre l'objectif et le corps** dès que le
joueur s'approche de ce bord, et remplit le cadre. Mesuré trois fois sur
la Crique (CH29) : une ligne de palmiers 1,3 u dans le bord nord, puis la
même ligne 2,2 u au-delà du bord, puis un parasol 1,4 u dans le bord — les
trois ont rendu une couronne ou une toile **plein cadre** sur capture
(« corridor », « dock »). Et cette bande n'est **jamais** dans l'image :
la caméra ne montre que des z inférieurs au sien.

**Règle** : tout prop plus haut que l'herbe se pose à **≥ 10 u au sud** du
bord nord d'une zone (ou d'un couloir) ; le semis y est interdit
(`CozyScatter.COVE_CAMERA_BAND`). Un couloir qui débouche vers l'est ou
l'ouest est le pire cas : le joueur y marche à z constant, la caméra
balaie toute la bande.

### ⚠️ UNE ZONE LATÉRALE N'EST VISIBLE QUE DEPUIS SON ENTRÉE

La caméra ne tourne pas et le cadre fait ~7 u de large au z de Keepy
(demi-angle 22,5°, `0,414 × D`). Mesuré (`CoveRecon`, `unproject_position`
sur la vraie caméra) : depuis la Lande à 22 u de côté, **rien** de la
Crique n'est dans l'image, phare de 9 u compris ; depuis l'embouchure du
couloir, le phare l'est parce qu'il est à **12 u de côté pour 28 u
devant**. Et la mer, centrée 8 u trop à l'est, était hors cadre **depuis
la plage elle-même** — déplacée après mesure, pas après relecture.

**Règle** : le repère d'une zone hors chaîne se place à moins de
**0,4 × (distance devant + 8,9)** de côté par rapport à l'axe d'approche,
et le contenu de la zone (l'eau, ici) à moins de ~8 u du point où le
joueur se tiendra. Le « macro » d'une zone latérale est son entrée.

### ⚠️ UNE MARCHE DE LONGUEUR NULLE ÉMET `became_idle` — ET CE SIGNAL EFFACE

Pendant de la doctrine « une marche de longueur nulle n'émet pas
d'atterrissage » : elle émet `became_idle` **synchroniquement, dans
`hop_to()` même**, et `_on_keepy_idle` efface toutes les intentions. Une
intention **armée avant** `hop_to()` est donc morte avant le `_try_*()`
immédiat qui la suit. Payé sur les châteaux de sable (CH29) : le 2e tap,
fait depuis le point d'approche, ne construisait rien, et seule la sonde
l'a vu (0,620 au lieu de 0,84). **Armer l'intention APRÈS `hop_to()`**,
puis tenter immédiatement — dans cet ordre, pour tout hotspot.

### ⚠️ EN HEADLESS, `is_position_in_frustum` EST TOUJOURS FAUX — les règles hors-champ tirent en continu

Le viewport 0×0 du driver dummy (déjà documenté pour `unproject`) a un
second effet : toute règle « loin ET hors champ » (re-mouillage des
montgolfières, re-garage de la balle) se déclenche **à chaque frame**.
Une sonde à phases qui suppose « la montgolfière attend au dock 0 » est
vraie phase par phase et fausse en un seul run (`CoveProbe`, 163 checks :
1 rouge en run complet, 0 par phase). **Garer explicitement** ce que la
phase suppose garé, ou lire l'état au lieu de le supposer.

### ⚠️ LES COULEURS DE SOMMET S'INTERPOLENT ENTRE ANNEAUX

Un cylindre de 6 u avec deux anneaux de sommets (bas, haut) peint « en
bandes » rouge/blanc par une fonction de `y` rend **entièrement rouge** :
il n'y a que deux couleurs à interpoler. Le phare de la Crique l'a payé
sur planche (Godot, première passe). **Une bande de couleur exige ses
propres anneaux** — un segment de cylindre par bande.

### ⚠️ LE GRAPHE DES ZONES N'EST PLUS UNE CHAÎNE

`HubWorld._gates_between` était une liste `[CORRIDOR, MOOR, CIRCUIT]`
indexée par numéro de zone, et son propre commentaire annonçait qu'une
zone hors chaîne exigerait autre chose. La Crique (zone 4) pend de la
Lande (2) : deux **tables** (`BRANCH_OF`, `BRANCH_GATE`) et une règle
(porte de la branche d'abord si on en part, en dernier si on y va). Un
second embranchement est une ligne ; **une zone qui pendrait d'une
branche** demanderait un vrai parcours d'arbre, et c'est là que la table
cesse de suffire.

### ⚠️ `draw_circle` NE SE BATCHE PAS ; UN ATLAS UNIQUE BATCHE TOUT, FOND COMPRIS

CH44 avait mesuré un `Control._draw` de minimap à **+2 619 primitives et
+43 draw calls pour 40 marqueurs** et nommé la cause : `draw_circle` émet
une commande POLYGONE, et un polygone ne se batche pas — **un draw call PAR
MARQUEUR**, linéaire en nombre et sans rapport avec la surface couverte.

CH46 a mesuré l'autre bout, sur le même banc et dans le même run (même
scène, même fond, seul le type de commande change) :

| approche | Δ `engine_total_prims` | Δ `engine_total_calls` |
|---|---|---|
| **atlas** — 1 quad de fond + 37 marqueurs en `draw_texture_rect_region`, **une seule texture** | **+76** | **+1** |
| **cercles** — le même quad de fond + 37 `draw_circle` | **+2 370** | **+38** |

**UN seul draw call pour toute une carte, fond compris.** Le renderer canvas
coalesce des quads consécutifs qui partagent texture, matériau et type de
primitive ; le nombre de marqueurs devient gratuit. Le corollaire de
conception : **le fond va DANS l'atlas**, pas dans une seconde texture — une
image supplémentaire coûte un batch de plus à elle seule.

⚠️ **Et la teinte par marqueur est gratuite** : l'argument `modulate` de
`draw_texture_rect_region` est une couleur de SOMMET, il ne casse pas le
batch. Ce qui le casse, c'est changer de texture, ou insérer un
`draw_set_transform`.

### ⚠️ `modulate` MULTIPLIE — UN CONTOUR NOIR SURVIT À N'IMPORTE QUELLE TEINTE

Corollaire de l'entrée ci-dessus, et il répond **par construction** à un
problème que ce fichier documentait comme non gaté (« le WCAG ne score
AUCUNE séparation À L'INTÉRIEUR d'une bande, et aucune sonde du dépôt ne
mesure la teinte »).

Une icône cuite en **forme BLANCHE à contour NOIR** et teintée par
`modulate` rend un remplissage de la couleur voulue **et un contour resté
noir** : `noir × couleur = noir`, quelle que soit la couleur. Un marqueur
garde donc une arête sombre franche contre l'herbe, le sable, la bruyère,
la pelouse ou la mer — sans une seule décision de contraste par type et
sans table de tons à maintenir.

⚠️ **Ça ne dispense PAS de mesurer les tons entre eux.** Un marqueur joueur
crème `(1,00 ; 0,99 ; 0,90)` rend à **0,03** du trait de circuit d'une
minimap `(0,97 ; 0,96 ; 0,87)` : le contour noir sauve la lisibilité de la
FORME, pas la lecture du TYPE. Trouvé par le balayage aveugle d'une sonde,
pas par relecture, et corrigé en déplaçant le ton (jaune chaud, 0,71 d'écart
en bleu).

### ⚠️ UNE FRONTIÈRE EST DEUX CHOSES : UN TRAIT, ET LE REMPLISSAGE QU'IL SÉPARE

**DIX-SEPTIÈME faux-vert du dépôt, CH46, et il était dans la sonde du lot.**

La minimap doit dessiner les frontières de zone **peintes**
(`CozyPalette.*_EDGE_Z`) et non les **logiques** (`HubRegion.*_MAX.y`), qui
en diffèrent de 2 à 4 u. La sonde lisait, dans une colonne rendue, le plus
grand saut de couleur autour du z attendu, le reconvertissait en z monde et
le comparait aux deux candidats. Verte, précise, avec des chiffres au
centième.

La passe rouge a réécrit la fonction de teinte pour mélanger ses **bandes**
sur les bords logiques — la substitution exacte que le contrat interdit — et
la phase est ressortie **ALL GREEN, 0 rouge**. Parce que le saut mesuré
n'était pas le changement de bande : c'était le **TRAIT** sombre tracé
séparément au z peint, que la neutralisation n'avait pas touché.

**Règle** : quand une limite est dessinée à la fois comme un trait et comme
un changement de remplissage, les deux se gatent **séparément** — et on le
prouve en neutralisant chacun des deux à son tour, en exigeant que la passe
rouge de l'un laisse les assertions de l'autre **vertes**. Deux passes qui
ne se recouvrent pas, c'est la preuve que les deux moitiés sont réellement
couvertes ; une seule passe qui rougit tout ne distingue rien.

⚠️ **Généralisation, parce que la forme se reverra** : ce que le joueur lit
d'un coup d'œil est presque toujours le REMPLISSAGE (une aire, une teinte,
une silhouette), et ce qu'une sonde trouve le plus facilement est le TRAIT
(un maximum local, un gradient, une arête). Gater le second en croyant tenir
le premier est un faux-vert qui a l'air d'une mesure fine.

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

Skill disponible : [`blender-cozy-keepy`](.claude/skills/blender-cozy-keepy/SKILL.md) — direction artistique et pipeline Blender (bpy headless) pour l'environnement 3D de Keepy.

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
| CH21 | Tyrolienne — recon : patron de tap, cadre caméra, rig à deux corps | [`CH21_TYROLIENNE.md`](docs/lots/CH21_TYROLIENNE.md) | 1 | 369 | 3 sept |
| CH22 | Audit visuel du hub — recon pure, puis application de la liste A (A1/A2/A3/A6) et mesure de la pire frame | [`CH22_HUB_VISUEL.md`](docs/lots/CH22_HUB_VISUEL.md) | 2 | 1147 | 4 sept |
| CH23 | Feu de camp — recon VFX, objet définitif (sprite E + bûcher), revert de couleur, puis cercle de pierres | [`CH23_FEU_VFX.md`](docs/lots/CH23_FEU_VFX.md) | 6 | 1505 | 4 sept |
| CH24 | Feu de camp interactif — recon puis LOT 1 : canal de tap `tapped_campfire`, aller-retour du blaireau, point d'arrivée de la recon rejoué sur le segment complet et corrigé après un croisement trouvé avec l'anneau de pierres | [`CH24_FEU_INTERACTIF.md`](docs/lots/CH24_FEU_INTERACTIF.md) | 12 | 222 | 4 sept |
| CH25 | L'ours rejoint le blaireau au feu — recon puis LOT 1 : recon reprouvée par un second script indépendant (même candidat d'arrivée, même conclusion sur le relèvement direct écarté), `BEAR_CAMPFIRE_WALK_RATE` calculé pour synchroniser l'arrivée des deux acteurs, ce qui a débusqué et corrigé à la racine un glissement de pieds de principe dans `HubActorWalker` (un seul taux par acteur pour toute sa vie, avant ce lot), gate balançoire et synchronisation des deux acteurs par un état partagé unique câblés | [`CH25_OURS_FEU.md`](docs/lots/CH25_OURS_FEU.md) | 9 | 407 | 4 sept |
| CH27 | Karting — lot 1 (circuit, conduite libre, chrono) et **lot 2** (V8 : HUD conduite centré, trois adversaires IA à personnalités, course à feux, classement, collisions, piste à 10 u, chat/castor/faon à la masse de Keepy — récit dans `docs/CARTE_BLANCHE_JOURNAL.md`, section « V8 — KARTING LOT 2 ») | [`CH27_KARTING_LOT1.md`](docs/lots/CH27_KARTING_LOT1.md) | 8 | 170 | 5 sept |
| CH29 | La Crique — cinquième zone à l'est de la Lande (couloir piéton, porte (41, −96)), mer, phare, châteaux de sable qui fondent sous la pluie, phare qui s'allume, ligne de montgolfière Corail plateau → Crique, **char à voile** (glisse libre au sol, vitesse au vent), `WorldSave` schéma 2 avec migration, graphe des zones en arbre, terrier + `ModelSlot` inerte pour un futur habitant | [`CH29_CRIQUE.md`](docs/lots/CH29_CRIQUE.md) | 1 | — | 5 → 6 sept |
| CH30 | Conduite unifiée — la difficulté du karting **mesurée** avant d'être touchée (`RaceBalanceProbe` : la laisse est inerte, `a_lat` sature sur la limite de braquage, l'échelle est compressive), trois presets `KartDifficulty` calibrés sur un plancher mesuré et commutables derrière `?keepydev=1`, relevé dev des tours ; extraction de `VehicleDrive` prouvée **byte-identique** par `KartTraceProbe` sur les deux arbres ; **char à voile piloté en continu** avec la caméra de poursuite, garde circuit ; `ChaseAudit` (160 frames, 5 zones × 8 azimuts × 4 météos) et les deux défauts qu'il a trouvés | [`CH30_CONDUITE.md`](docs/lots/CH30_CONDUITE.md) | 5 | 431 | 6 sept |
| CH39 | Le relief invisible — diagnostic avant correctif : les cinq hypothèses du brief tranchées une par une, puis la **cause prouvée à variable unique** (le treillis de la crête était enroulé à l'envers, `cull_back` jetait toute la colline, 14 pixels contre 317 646), le **dixième faux-vert** nommé sur cinq mécanismes empilés, et `MountainProbe` PHASE G — un gate de PIXELS sans seuil | [`CH39_RELIEF_DIAGNOSTIC.md`](docs/lots/CH39_RELIEF_DIAGNOSTIC.md) | 1 | 181 | 7 sept |
| CH26 | Le monde cozy — direction VOIE A, météo, transport, trois zones, persistance locale, grimper universel, récolte ; puis le **lot de cadrage** qui a retiré le bypass d'authentification (`Auth.gd` et `LoginScreen.gd` re-vérifiés byte-identiques à `origin/main`), restauré `web-build.yml`, remplacé les poignées de test par une graine de RNG, re-gaté les trois outils de développement sur `DevTools.enabled()` (liste blanche) au lieu d'un nom d'hôte, et borné les sondes conservées par `ProbeWatchdog` | [`CH26_MONDE_COZY.md`](docs/lots/CH26_MONDE_COZY.md) | 1 | 182 | 4 → 5 sept |
| CH37 | Socle multi-altitude, LOT 1 SURFACE — `HubSurface` publié (requête pure au patron `HubWater`), `ground(flat)` comme orthographe unique du point sol, grille float32 refusée sinon, raccord C0 exact au périmètre, AABB disjointes, aucune bande `CozyPalette` traversante ; six vagues branchées (marche, caméra, tap, retours au sol, pluie/ombre) et **zéro domaine enregistré en jeu**, donc un no-op arithmétique prouvé sur les deux arbres ; `SurfaceProbe` phases A → G avec blind check en tête de chaque phase | [`CH37_SURFACE.md`](docs/lots/CH37_SURFACE.md) | 1 | — | 7 sept |
| CH50 | Extension zone 0 nord — le sol du skatepark : disque r=28 unioné sur le milieu du bord nord (le MÊME centre que le lobe CH16, qu'il avale à tous les centres que le budget autorise, donc « goulot entre les deux disques » n'est pas une forme dessinable), pire paire créée 106,590 u / **20,117 s** qui PERD contre celle de CH38 (111,414 u / 20,967 s) donc pire traversée du hub inchangée, diagonale reproduite à la frame près (1 122 frames / 18,700 s) ; `COVER_MAX.y` 47 → 63 et les TROIS orthographes du littéral 50 du mur unifiées en un `WALL_NEAR_Z` dérivé (68) ; trois passes rouges (9 / 3 / 3) et le couplage tapis-mur prouvé par les deux dernières ; faux-vert du lot : la sonde en `--headless` lisait **2 743 transforms de `MultiMesh` sur 2 743 en identité** et comptait zéro en vert ; table des sondes rejouée sur deux arbres, parité rétablie, plus la trouvaille que le gate de contraste des plaques CH48 est un test du SOL (`origin/main` porte déjà 0,21 % de sol peint sous L 0,10, son plus sombre à 2,31:1 exactement) | [`CH50_ZONE0_NORD.md`](docs/lots/CH50_ZONE0_NORD.md) | 1 | 402 | 8 sept |
| CH69 | **Le bol devient physique : 0,40 u de dalle, une porte de trois secteurs, et le couplage non elucide de CH67 ELUCIDE.** Balayage de **19 865 candidats** contre SEPT contraintes a la fois -- chevauchement nul, degagement >= `DECK_LENGTH` **0,92 u** (le plancher defendable la ou CH68 s'arretait sur un jugement), empreinte du parking, retombee, region sur 36 points de rim, rim SUR la dalle (K5 passe d'une TOLERANCE de 0,100 u a une MARGE de 0,050 : la dalle etant le levier, la tolerance qui ne condamnait pas le bol livre n'a plus de raison d'etre), et **K6 venu d'une SONDE et pas du balayage** (`SkateparkProbe` G5 a rougi a **-0,209 u** sur la premiere reponse, les disques de score se recouvrant ; re-balaye avec les disques tenus a `ARRIVE_EPSILON` -- la premiere reponse sous un K6 nu etait disjointe de **TREIZE MILLIMETRES**, un gate ne sur sa propre limite). ⚠️ **La dalle n'a PAS besoin de grandir pour que le bol soit legal** (une place a 0 u2 existe, degagement 0,450) : les 0,40 u achetent le DEGAGEMENT, 0,450 -> **0,950 u**. ⚠️ **La moitie NORD a ete mesuree, pas ecartee** : possible a **80,16 u2 (+20,5 %)** pour un bol que la camera montre depuis **2 stations sur 133** contre **30**. Livre : bol a **(-6,75 ; 45,00)**, dalle en deux COINS x[-10,40 ; 10,00] z[41 ; 59] (une taille centree ne sait pas grandir d'un seul cote), **roll-in de trois secteurs ni dessines ni solides** (0,942 u d'arc chacun contre un deck de 0,92 : un est une fente ; trois donnent 2,83 u) qui **n'introduit aucune position de sommet neuve** -- les deux jambages sont l'eventail dont les pieces sont taillees -- donc PHASE G reste le MEME test a 105 pieces au lieu de 120, et le park s'ALLEGE de 65 triangles. `pieces_for` rend l'anneau ; PHASE X gate toujours « sans piece SSI chevauchement ». PHASE Y roule le collider **LIVRE** (corps temporaire supprime, AABB prouvee sans intrus) et gagne la ROULADE PAR LA PORTE au vrai canal du doigt : rim franchi **a y 0,0000**, r 0,030 atteint, 0 pop, 0 fence, contre un blind check **arrete a r 4,035** sur un secteur plein. **CH67 § 4 ferme** : `park_span() -> skate_coast_u() -> configure()`, donc **18,043 -> 23,201 u de roue libre (+28,6 %)**, arrivees +0,22 u/s, retombee deplacee de 1,27 u -- un changement de TOUCHER a valider device. Quatre defauts d'instrument trouves, chacun avec l'allure d'un resultat : `Mesh.get_faces()` aplatit la surface de decor de D5 (4 echantillons faux sur 1 521), une jambe re-garee sans re-montage (max r 0,000 sur un bol qui marche), un **seuil sur une hauteur qui n'existe que si le rim a ete franchi** (valeur par defaut 0,0000 = vert gratuit), et PHASE E qui lancait le bol depuis un pied exterieur qu'il n'a pas. Trois passes rouges (**1 / 2 + arret d'instrument / 9 pour 6 predits**, les trois extras etant le meme chevauchement vu par V[3] et par le blind check de V). Table croisee sur deux arbres, `SeesawProbe` **2 rouges pre-existants en parite exacte**, `ProbeTimeoutAudit` **de retour a 98**. | [`CH69_BOL_PHYSIQUE.md`](docs/lots/CH69_BOL_PHYSIQUE.md) | 8 | 440 | 10 sept |
| CH70 | **La croisière du skate rouverte sur autorisation explicite, et REFUSÉE PAR LA MESURE.** Réouverture volontaire d'une décision verrouillée depuis CH61 → CH69, sur un retour device répété. Deux prémisses du brief tuées au recon, avant toute ligne de code : (a) `push`/`brake` **ne sont pas des constantes** — `configure()` les résout depuis quatre distances, et l'arithmétique du solveur dit que `drag_k` ne dépend pas de la croisière tandis que `roll_stop`/`push`/`brake` sont en **cruise²**, donc ×0,65 sur la croisière fait **×0,4225** sur les accélérations (ce qui est la BONNE réponse : c'est ce qui conserve les 3,2 u authored de CH54 ; forcer ×0,65 aurait exigé un run-up de **1,844 u**, un départ PLUS sec) ; (b) les baselines `17,2165 / 10,3433` du brief sont celles du `park_span()` **d'avant CH69** — le vrai arbre livré lit **16,4253 / 11,0800**, et `SkateFeelProbe` PHASE W les gatait en littéral, donc **ROUGE depuis CH69** (120 OK / 1 RED sur `origin/staging` intact, la table croisée de CH69 n'incluant pas cette sonde). ⚠️ **Le changement a été fait, mesuré, et non expédié** : à 6,5 la planche culmine à **0,999 u** sur une lèvre de 2,10 et **0,903 u** sur une lèvre de 1,45 — elle n'atteint plus AUCUNE lèvre, la fenêtre CH66 vaut **0,000 s** contre 0,762 exigées, et `SkateAirProbe` sort **18 rouges**. Balayage de huit valeurs : **le premier échelon qui tient le contrat est 10,0, avec 0,055 s de marge** — la croisière ne peut pas baisser du tout sur le park tel qu'il est authored, c'est la PAIRE (croisière, hauteur de lèvre) qui est le paramètre. Livré : la mesure, plus PHASE W refaite en gate **DÉRIVÉ** (planche de référence configurée depuis les entrées publiées + blind check par planche-leurre), passe rouge à **1 rouge sur 1 prédit** et fichier restauré byte-identique. Deux rouges rapportés sans être corrigés (un littéral `8.0` qui voulait dire « près de la croisière », un gate E[3] déjà posé sur sa propre limite) et un troisième identifié **charge machine** et rejoué vert. Table croisée sur deux arbres, **154 `.scn`** des deux côtés. | [`CH70_CROISIERE_SKATE.md`](docs/lots/CH70_CROISIERE_SKATE.md) | 5 | 238 | 11 sept |
| CH71 | **Le parc d'attractions : une montagne russe et une tour de chute, JOUABLES, sur la lisière est du plateau.** Recon mesurée en jeu autour de l'ancre de Mathieu (35,2 ; 27,7) : dans la région par 0,051 u (le rebord du lobe skate), zone 0, aucun prop de layout à moins de 12 u, mur d'arbres à x ≥ 36,6, budget reproduit (scene 360 849 / TOTAL 62 321, le plafond de 50 k déjà dépassé de 23 %). **Tout construit À L'INTÉRIEUR de la région** (bande x [29,0 ; 35,0]) : aucun lobe, pire traversée inchangée (21,817 s), aucun arbre du mur touché — le lobe alternatif était chiffré (r 10,2 = la pire paire CH67). Boucle Catmull-Rom de 51,165 u, crête à 5,027, montée au treuil vers le NORD (aveugle), descente vers le SUD dans le cadre ; vitesse = PROFIL par phase (treuil 2,2 / énergie à g 9,8 / freinage en gare), **frein au doigt tenu** (−3,0 par unité, plancher 1,2 : trajet BORNÉ, licence de jeter un tap), 9,19 u/s libre contre 5,91 freiné. Tour de 6,6 u : montée 0,9 u/s, 1,6 s, chute libre à −8,33 u/s, frein DÉRIVÉ à 3,04 g. Sièges ≤ 5,868 (couronne + 0,4 sous `FRAME_TOP_AT_APLOMB`), couronne déprojetée à chaque frame. D5 : 37 `BoxShape3D`, un corps. ⚠️ **Un footprint testé APRÈS les tirages RNG ne rebat pas le tapis** (bush 22 → 22 au lieu de 22 → 7 dans `_blocked()`), doctrine ajoutée. `FunfairProbe` 78 / 0 par le vrai canal de tap, passe rouge **5 / 5 prédits**, budget +4 068 aux stations du parc et **+0 au spawn**. Deux recensements littéraux (`SkatePhysicsProbe` « SIX corps », `MinimapProbe` roster 39) faits lire le producteur ; CabinProbe ne se reproduit pas sur un seul arbre (phase baiser). | [`CH71_PARC_ATTRACTION.md`](docs/lots/CH71_PARC_ATTRACTION.md) | 12 | 516 | 11 sept |

| CH73 | **La caméra du hub devient orientable au doigt, à pied, et elle reste où on la laisse.** Recon bloquante, et **deux prémisses du brief tombent**. (a) ⚠️ **Il n'existait AUCUN seuil tap/drag dans `HubTapInput`** — ni temps ni pixels : toute release appelait `_handle_point` inconditionnellement, donc un drag envoyait Keepy là où le doigt se **LEVAIT** (le header du fichier dit l'inverse, et il parle de la *press*). Le seuil est **créé**, en lisant `SkateTouchInput.SLOP_PX` (16 px, justifié par son propre commentaire en termes de **pouce et de téléphone**, pas de planche) ; ⚠️ **son jumeau `TAP_MAX_S` est REFUSÉ** — sur la planche un doigt tenu est l'accélérateur et la limite sépare deux gestes réels, dans le hub elle n'inventerait qu'un troisième résultat (presser, attendre, lever, RIEN) sans aucun retour ; mesuré au passage que la constante est en temps **RÉEL**, donc sous llvmpipe (une frame = ~0,14 s) le tap de six frames d'une sonde dure **0,824 s** et une assertion passait **selon la charge machine**. (b) ⚠️ **La dette du double relâchement interfère dans DEUX sens** (gain **doublé** sur téléphone, et un latch effacé au relâchement fait relire un drag comme un tap par le jumeau) : **non corrigée** (hors scope, le filtre `DEVICE_ID_EMULATION` casserait le desktop) mais neutralisée par la FORME et gatée. Mécanique : **rotation rigide du rig entier** autour du point sol — `position = ground + R·OFFSET`, `basis = R·_hub_basis` — d'où trois propriétés **gratuites et gatées** : identité à angle nul (donc cadre livré byte-identique), **distance invariante** (11,7034 u : un zoom devient impossible à ajouter par accident), et le désaccord authored de 6,5° du CH36 **transporté**, donc le cadrage tient à tous les lacets ; **roulis exactement nul par arithmétique** (pire `\|basis.x.y\|` = 0,000000000). `_hub_basis` **toujours jamais écrit** (lecture dérivée). Bornes **mesurées** par balayage au degré : ⚠️ **la couronne est dans le cadre aux 90 pas** (le cadrage est invariant, donc « il sort du cadre » ne borne rien) et **aucun genou** sur la fraction adressable (93,3 % au repos → 40,0 à −40), donc chaque borne est ancrée sur une **propriété re-mesurable** — basse **−23,0°** (dégagement **3,5183 u**, plus du double de la couronne de 1,7 ; tangage encore **11,0°** descendant), haute **+43,0°** (rayon horizontal **1,3249 u** : au zénith un lacet ne déplace la caméra **nulle part** et la commande serait morte). ⚠️ **Le balayage a réfuté le soupçon du lot** : la caméra vers l'horizon coûte **+3,9 %** (74 538 contre 71 764), pas les 123 515 de la pose de conduite — **`far` n'est PAS touché**. `OrbitCameraProbe` (permanente, xvfb + opengl3, **jamais headless**) : **56 assertions, 7 phases, tout par `Input.parse_input_event`**, `orbit_by` appelé nulle part sauf par le moteur. **Sept passes rouges** — 1/1, **1 pour 1 après qu'une première rédaction soit revenue ALL GREEN**, 5 pour 3, 4/4, 4/4, 3/3, 1/1 — dont deux ont trouvé des défauts **DANS LA SONDE** : la passe 1 a rendu **4 rouges pour 1 prédit** (trois instruments dépendaient d'où Keepy se trouvait), et ⚠️ **la passe 2 est revenue ALL GREEN**, révélant que le doublement est neutralisé par l'**INTÉGRATION PAR DELTA** et non par la réclamation de canal — d'où D5 (le même pixel deux fois vaut un pas) et D4 (**un survol n'est pas un geste** : défaut *desktop*, invisible depuis le téléphone que le garde défendait). ⚠️ Une assertion de stabilité est sortie **ROUGE sur du code juste** et n'a pas été faite taire : la pose **ARRIVAIT** (0,67 % d'erreur résiduelle à 1 s) — réécrite pour nommer **vers quoi** elle ne doit pas converger, elle publie **0,00000° de l'orbite laissée contre 114,51° de la pose authored**. Table croisée deux arbres, **154 `.scn`** des deux côtés, `ProbeTimeoutAudit` **99 → 100** (+1, la sonde de recon jetable supprimée). | [`CH73_CAMERA_ORBITABLE.md`](docs/lots/CH73_CAMERA_ORBITABLE.md) | 9 | 412 | 11 sept |
| CH67 | Zone navigable du hub — `SKATE_LOBE_RADIUS` 28 → 36 sur un balayage MARCHÉ (38 sort à 22,100 s, le chiffre que le lot D avait déjà refusé), pire traversée du hub qui PASSE au lobe (21,817 s, dit et gaté) ; limite rendue lisible par un liseré peint dans le shader du sol, teinte choisie **en luminance** (le béton pâle évident lit 1,18:1 contre l'herbe claire) et gatée au PIXEL contre son propre plancher de bruit ; balançoire et ours sortis du couloir de course sur un scan à quatre contraintes simultanées, les deux constantes de l'ours re-dérivées ; **le bol construit, prouvé, puis retiré sur une mesure** (il passe sous la retombée du grand quarterpipe et rend le double pop que CH66 avait tué) | [`CH67_ZONE_NAVIGABLE.md`](docs/lots/CH67_ZONE_NAVIGABLE.md) | 8 | 392 | 10 sept |
| CH68 | Les deux zones « non physiques » n'en font qu'une — RECON PURE, zero code de jeu. Zone 1 identifiee par enumeration, passe masquee au pixel et balayage de 72 azimuts lances DEUX FOIS (physique et triangles de la surface 0) : **6 azimuts fantomes, tous le bol**, 31 ou physique et dessin sont egaux au millimetre, et le « mur gris » du retour device est le DOS du petit quarterpipe, **solide**. Confirme par le canal du joueur avec blind check : la planche **traverse le bol** (0,199 u de l'axe, zero contact) et le meme geste sur un module solide est ARRETE. **Les deux zones sont le meme objet.** Zone 2 : les deux angles du brief mesures — (a) 56 positions sur la dalle, **0 sur 56** avec 1 u de degagement, 4 489 des qu'on lache la dalle ; **(b) REFUTE — retirer la contrainte de retombee laisse 56 avant, 56 apres** ; le bol n'est pas cable | [`CH68_ZONES_NON_PHYSIQUES.md`](docs/lots/CH68_ZONES_NON_PHYSIQUES.md) | 5 | 336 | 10 sept |

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
