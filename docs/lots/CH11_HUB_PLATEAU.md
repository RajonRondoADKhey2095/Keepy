# Hub — du menu 2D au plateau 3D, décor, extensions, MultiMesh

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 10 section(s), 2143 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## ÉCRAN HUB « KEEPY'S MEMORIAL QUEST » : la redirection post-connexion ne mène plus à Keepy Chased directement (18 août 2026)

Branche `claude/keepy-memorial-quest-hub-o3hcb6`. **Préparation Quizz, pas
un changement de gameplay** : aucune scène de jeu, aucun collider, aucune
constante, aucun `.glb`, aucun autoload touché. Deux fichiers créés
(`scenes/Hub.tscn`, `scripts/ui/Hub.gd`), **une seule destination
déplacée** dans `scripts/ui/LoginScreen.gd`.

```
run/main_scene = res://scenes/LoginScreen.tscn     (inchangé)
        │  session Google valide
        ▼
res://scenes/Hub.tscn                              <-- NOUVEAU
        ├── « Keepy Chased » -> res://scenes/TitleScreen.tscn   (inchangé)
        └── « Keepy Quizz »  -> DÉSACTIVÉ, « Bientot disponible »
```

⚠️ **`scenes/TitleScreen.tscn` est BYTE-INTOUCHÉ**, vérifié et pas
affirmé (`git diff` vide sur ce fichier) — y compris son script. C'était
la contrainte explicite du lot : Chased reste exactement le jeu validé en
production, et il reste chargeable seul. Un second bouton posé sur
`TitleScreen` aurait fait lire Quizz comme un MODE de Chased plutôt que
comme un sous-jeu frère, et n'aurait laissé aucune place à un troisième.

**Le seul point d'arrivée post-connexion codé en dur du dépôt était
`LoginScreen.gd`**, et c'est **mesuré par `grep`, pas supposé** : les
seules autres occurrences de `TitleScreen` sont la scène elle-même, trois
commentaires (`SwampIdentityAudit.gd`, qui n'échantillonne PAS cet écran
depuis le 14 août et charge `Game.tscn`), un commentaire de
`firestore.rules`, et `README.md`. `TITLE_SCENE` devient donc `HUB_SCENE`,
`_go_to_title()` devient `_go_to_hub()`, et **toute la décision
signed-in / signed-out, le garde `_leaving`, les codes d'erreur et le
chemin hors-web sont intouchés**.

⚠️ **Dette de doc PRÉ-EXISTANTE, signalée et NON corrigée ici** :
`README.md` dit encore que le projet démarre sur `scenes/TitleScreen.tscn`
— faux depuis le gate Google Sign-In du 17 août, donc antérieur à ce lot
et sans rapport avec lui. Laissé à son propre lot plutôt que corrigé en
douce dans un commit atomique qui ne parle pas de ça.

**Le bouton Quizz est inerte, et l'inertie est GATÉE plutôt que
stylistique.** `QuizzButton` porte `disabled = true` dans la scène, **rien
n'est connecté à son signal `pressed`**, et `Hub._ready()` `push_error` si
ce `disabled` disparaît. Motif : un bouton ré-activé sans être connecté
serait un contrôle MORT — silencieux, indiscernable à l'œil d'un bouton
« bientôt » simplement grisé. Même discipline que l'assertion nombre de
pastilles de `HUD.gd` (elle `push_error`, elle ne devine pas). Retirer
cette assertion fait partie du branchement du vrai gameplay, pas d'un lot
séparé.

**Trois décisions de Mathieu verrouillées dans `docs/QUIZZ_SPEC.md`** (le
document de conception Quizz, écrit le matin même avec ces trois points
OUVERTS — §10.1, §10.2, volet partage de §10.5) : hub séparé (livré,
chemins de branchement exacts au nouveau **§7.1**) ; écran de jeu Quizz en
**hôte unique + panneaux par format** ; `visibility` **`'private'` et rien
d'autre, décision actée et pas un état d'attente**. Les paragraphes
concernés sont amendés sur place et barrés, pas supprimés — une session
future doit voir la décision, pas un blanc.

⚠️ **Ce lot est posé sur `claude/quizz-schema-design-u1wixk`**, la branche
docs-only qui apporte `docs/QUIZZ_SPEC.md` (un seul commit, `6f16d8d`, sur
la même base `6d57fd4`) et qui n'était **pas encore mergée sur `staging`**
au moment de partir. Sans elle, la tâche « mets à jour QUIZZ_SPEC.md »
n'avait pas de fichier. Fast-forward, **aucun fichier en commun avec ce
lot**, donc zéro conflit — mais le merge `staging` de ce lot emporte ce
commit de doc avec lui, et c'est dit ici plutôt que découvert dans un
`git log`.

**Validation** : import headless **exit 0** ; boot headless de
`res://scenes/Hub.tscn` seule (`--quit-after 2`) **exit 0**, aucune erreur
de parse ni de nœud manquant (les chemins `@onready` sont donc réels, pas
plausibles) ; export Web release **exit 0**. Mise en page **mesurée** par
sonde jetable (jamais commitée) sur la scène instanciée, pas estimée —
voir le rapport de lot pour les rects réels et la marge restante en bas
d'écran.

**Sondes : aucune n'est concernée, et c'est VÉRIFIÉ, pas supposé** —
`grep` sur `scripts/dev/` : **aucune sonde ne charge `LoginScreen.tscn`
ni `Hub.tscn`**, et aucun `.tscn` de sonde ne les embarque. La seule
mention de `LoginScreen` du dépôt hors `scripts/ui/` est
`run/main_scene` dans `project.godot`, que les sondes contournent par
construction (chacune lance sa propre scène). `SwampIdentityAudit` charge
`Game.tscn` et ne cite `TitleScreen` que dans des commentaires expliquant
pourquoi elle ne l'échantillonne plus. Rejouées quand même :
`ProbeTimeoutAudit` (33 sondes armées), `AssetContractAudit` (12/12
visuels, 0/10 colliders déplacés), `DeathModelAudit`, `ChargerShapeProbe`.

**Reste ouvert — jugement device, seul juge** : que la connexion Google
mène bien au hub sur `keepy-staging.vercel.app`, que « Keepy Chased »
lance la run exactement comme avant, et que le bouton Quizz grisé se lise
comme « bientôt » et non comme « cassé ». **`main` n'est PAS touché par ce
lot** : il déplace le flux de connexion validé en production, donc le
palier 2 est gaté par Mathieu après test device explicite sur staging.

### Merge en production (18 août 2026, autorisation explicite de Mathieu)

`staging` (`7b54201`) → `main`, commit de merge **`6dd4bd5`**, `--no-ff`,
aucun conflit, après validation device sur `keepy-staging.vercel.app` :
connexion → hub affiché correctement, « Keepy Chased » lance la run
normalement, « Keepy Quizz » visible et grisé « Bientot disponible », sans
erreur ni état cassé. **Le hub est EN PRODUCTION** — le flux de connexion
livré aux joueurs est désormais `LoginScreen` → `Hub` → `TitleScreen`, et
non plus `LoginScreen` → `TitleScreen`.

**Règle n°1 vérifiée AU DÉBUT, pas à la fin** (leçon de l'incident du
11 août) : `git fetch --all --prune` puis tri de toutes les refs distantes
par date de commit — la plus récente du dépôt EST `origin/staging`
(11:22:58 UTC), immédiatement suivie de la branche du lot hub
(`claude/keepy-memorial-quest-hub-o3hcb6`, 11:22:40). **Aucune session
concurrente.**

**`main` était strictement en retard** (`staging..main` VIDE) et l'arbre du
commit de merge est **byte-identique à `staging`**, vérifié AVANT le push
et pas supposé : `git diff HEAD origin/staging` vide **et même hash d'arbre
des deux côtés (`fba9a254faae6fec76aa62794d839fbed7d97f01`)**. Ce qui part
en prod est donc littéralement l'arbre validé sur device. Merge `--no-ff`
quand même, comme tous les merges de prod de ce dépôt — un fast-forward ne
laisse aucun point de décision lisible dans l'historique.

⚠️ **`firestore-rules.yml` NE S'EST PAS DÉCLENCHÉ, et c'est vérifié sur le
workflow lui-même, pas déduit du diff.** Deux mesures indépendantes :
1. `git diff --name-only origin/main origin/staging` rend **5 fichiers**
   (`CLAUDE.md`, `docs/QUIZZ_SPEC.md`, `scenes/Hub.tscn`,
   `scripts/ui/Hub.gd`, `scripts/ui/LoginScreen.gd`) — **`firestore.rules`
   n'y est pas**, et le trigger de ce workflow est
   `paths: ['firestore.rules']`.
2. La liste des runs de `firestore-rules.yml` rend **`total_count: 2`** —
   le run **#1** (`9029bfe`, tentative 4) et le run **#2** (`8b70b24`),
   tous deux d'hier/ce matin. **Aucun run sur `6dd4bd5`.**
Le ruleset live de `keepy-8df91` est donc inchangé : c'est toujours celui
publié par le run #2 à 10:32:59 UTC. **Rien de ce lot ne touche à l'auth
Firestore.**

CI **web-build run #145** (id `32133921735`, tentative 1) **verte en
3 min 29 s** (11:52:45 → 11:56:14 UTC) — `Deploy to Vercel
[PRODUCTION -- main]` **succès**, `[STAGING -- staging]` correctement
**skipped** (push sur `main`). Le log porte lui-même `▲ Aliased
https://keepy-ten.vercel.app`.

**Fingerprint vérifié sur le site LIVE, requête fraîche** (`keepy-ten.
vercel.app`, via le fetch Vercel — l'egress direct de ce sandbox reste
bloqué en 403 CONNECT sur ce domaine, re-testé et pas supposé) :
**HTTP 200**, **`x-vercel-cache: MISS`**, **`age: 0`**, `last-modified`
collé à l'instant de la requête (l'index est servi en `no-cache,
must-revalidate`) — trois signaux indépendants qui disent que ce n'est pas
une réponse de cache, comme l'exige la leçon déjà payée deux fois ici.
`GODOT_CONFIG.fileSizes` = **`index.pck 5 451 008` / `index.wasm
35 376 909`**. Le `wasm` est **identique au bit près** au fingerprint
consigné pour tous les lots qui ne touchent pas le code moteur — et c'est
LUI la preuve d'identité, jamais le `.pck`.

**Chaîne de preuve du déploiement, lue sur l'API Vercel** (indépendante du
CDN) : le déploiement production courant est
`dpl_4YsvDd8W1YsZ62Zh6kDVFAkqkdkR`, `state: READY`, `target: production`,
`meta.gitRootDirectory = build/web` (**donc la CI, pas le natif**),
`githubCommitSha = 6dd4bd58…`, `githubCommitMessage = "merge: Keepy's
Memorial Quest hub to production"`.

⚠️ **Ce que ces mesures prouvent, dit précisément plutôt que gonflé** :
elles établissent la chaîne **commit → build → déploiement → origine
réellement servie**. **Le hub lui-même est dessiné par Godot dans le
canvas** — aucune de ces mesures ne le « voit », exactement comme au merge
du gate Google Sign-In. Corroboration seulement, pas preuve : le `.pck`
passe de **5 445 248** (dernier chiffre prod connu) à **5 451 008**
(**+5 760 octets**), cohérent avec l'ajout de `Hub.tscn` + `Hub.gd` — mais
la taille du `.pck` n'est **pas** stable d'un export à l'autre du même
commit (avertissement permanent déjà consigné), donc elle n'est offerte ni
comme preuve d'identité ni comme preuve de contenu. Le hub était validé
sur device sur `staging`, et l'arbre servi en prod est byte-identique à
celui-là.

⚠️ **La fenêtre de ~3 min de 404 s'est reproduite à l'identique — attendue,
pas un signal d'alarme.** Mesurée sur les deux déploiements réels de ce
push, et non déduite : le déploiement **NATIF** Vercel
(`dpl_28Ad4h57j1Xw6WxsqN6kcLTtAXzb`, reconnaissable à son
`meta.branchAlias = keepy-git-main-…`) a pris la prod à **11:52:45**, la
**CI** l'a remplacée à **11:56:03** — **~3 min 18 s** pendant lesquelles la
prod servait le dépôt BRUT (pas d'`index.html` à la racine → 404). Ça se
répare tout seul et personne ne le voit, mais c'est réel : voir la section
« DEUX déploiements se disputent la PROD » pour le détail et le fait que
seul un réglage en Console Vercel (Settings → Git) l'éliminerait. **Ne
jamais lire un fingerprint sans regarder l'heure du dernier déploiement.**

**Aucune sonde rejouée localement, pour cause de non-applicabilité ET
d'outillage absent — dit plutôt que déguisé en preuve.** Le lot hub avait
déjà **vérifié par `grep`, pas supposé**, qu'aucune sonde de
`scripts/dev/` ne charge `LoginScreen.tscn` ni `Hub.tscn` (chacune lance sa
propre scène et contourne `run/main_scene` par construction), et il avait
rejoué `ProbeTimeoutAudit` / `AssetContractAudit` / `DeathModelAudit` /
`ChargerShapeProbe` verts sur l'arbre exact qui est mergé ici. **Aucun
Godot n'est installé dans CE sandbox** (ni éditeur ni templates), donc
aucune sonde ne pouvait y tourner de toute façon. La seule validation
structurelle pertinente — que l'import + l'export headless chargent et
empaquettent l'intégralité des scènes sans erreur — **a eu lieu et
réussi** : c'est exactement ce que fait le job CI (`Import project
resources` + `Export Web build`, tous deux verts sur ce commit précis).

**Reste ouvert** : rien sur le hub lui-même — il est validé device et en
production. Le reste est inchangé et appartient à d'autres lots : le
rafraîchissement du token (`onIdTokenChanged`, jamais rebranché) ; la dette
de doc de `README.md` (il dit encore que le projet démarre sur
`TitleScreen.tscn`) ; la redondance de titres de l'écran-titre ; et la
fenêtre de 404 à chaque push sur `main`.

## HUB PLATEAU 3D : les trois boutons deviennent trois portails, Keepy s'y rend PAR BONDS (23 aout 2026)

Branche `claude/hub-plateau-3d-bonds-wzt2oa`, partie de `staging` (`d68a157`
-- `main` etait un merge de `staging` au MEME arbre `c2d587f5`, verifie et
pas suppose). `scenes/HubWorld.tscn` remplace `scenes/Hub.tscn` comme point
d'arrivee post-connexion : un plateau 3D, trois portails, et Keepy qui se
deplace vers le point tape.

⚠️ **`scenes/Hub.tscn` et `scripts/ui/Hub.gd` sont DELIBEREMENT CONSERVES.**
C'est le rollback, et un ecran par lequel passe l'acces a TOUS les jeux ne
doit pas perdre sa version precedente dans le commit qui livre son
remplacant. Les trois appelants (`LoginScreen.gd`, `QuizzHomeScreen.gd`,
`BattleArena.gd`) pointent desormais sur `HubWorld.tscn`.

### ETAPE 0 -- l'inventaire du `.glb`, MESURE avant d'ecrire une ligne

`assets/models/keepy_squirrel_hero.glb`, parse du JSON du conteneur :
**aucun skeleton** (`skins` absent), **1 seul noeud** (`Mesh1.0`), **1 seul
mesh, 1 seule primitive**, **0 animation**, `KHR_materials_unlit`.

⚠️ **La queue N'EST PAS un noeud separe** -- elle est dans la meme primitive
que le corps. L'oscillation de queue contre-phase prevue au brief **n'a donc
pas ete tentee** : il n'y a rien a animer independamment, et decouper la
geometrie serait un lot d'asset, pas un lot de gameplay. Signale, pas
contourne.

Consequence structurante : **tout est PROCEDURAL**, sur des transforms --
meme technique que `scripts/battle/FighterView.gd`, sur le meme asset, a
travers le meme `ModelSlot`.

### DECISION PERMANENTE : le layout est une RESOURCE, jamais des transforms de scene

`resources/hub/hub_layout.tres` (`scripts/hub/HubLayout.gd`, un
`Array[Dictionary]`) porte **la totalite du placement** : 3 portails +
12 props. `scenes/HubWorld.tscn` porte la **STRUCTURE** (viewport, camera,
Keepy, les parents vides, l'UI de secours) et **ne nomme aucune coordonnee
monde**. `HubBuilder.gd` instancie au `_ready()`.

**Pourquoi c'est une regle et pas un gout** : `Hub.tscn` posait ses trois
entrees dans un container, leurs positions etaient une consequence du
layout, il n'y avait rien a regler. Un plateau 3D a le probleme inverse --
chaque prop a une position choisie a la main, et la premiere version est
toujours fausse sur device. Baker ces nombres dans la scene ferait de chaque
passe de reglage un diff sur le fichier qui porte AUSSI le viewport, la
camera et le menu de secours : un mauvais merge la coute l'ecran entier, pas
un rocher. **Deplacer un portail = editer des chiffres dans un fichier
texte.** Toute session future qui ajoute un prop l'ajoute au `.tres`.

`HubBuilder` **valide et saute** une entree malformee avec un `push_error`
plutot que de planter : une faute de frappe dans un fichier de decor ne doit
jamais etre la raison pour laquelle un joueur ne peut plus atteindre ses
jeux. Les meshes de props sont construits en code depuis des primitives, a
tessellation EXPLICITE (le piege §7.2 des collectibles), **unshaded** comme
toute surface de ce projet -- la scene n'a aucune `DirectionalLight3D`.

### ⚠️ LA REGLE QUI DONNE DU POIDS : un tap PENDANT un bond ne l'interrompt JAMAIS

`KeepyHopper.gd`. Un tap remplace la DESTINATION ; le changement est honore
**a l'atterrissage suivant**, jamais en vol. C'est toute la difference entre
un personnage qui a du poids et un curseur : une redirection en l'air ferait
pivoter Keepy en pleine parabole, et un joueur qui tape plusieurs fois de
suite le verrait vibrer sur place au lieu d'avancer. Le cout est au pire
`HOP_DURATION` (0,35 s) de reactivite. **La file est de PROFONDEUR UN** : la
seule destination interessante est la derniere.

**Un seul tween par bond**, sur un 0..1 normalise (`tween_method`), pas trois
`tween_property` paralleles -- l'arc est une parabole et le squash est
lineaire par morceaux, ce qu'aucun tween de propriete n'exprime. Trois canaux
ecrits depuis le MEME `t`, donc ils ne peuvent pas deriver l'un de l'autre :
position (`4t(1-t)`, exactement 0 aux deux bouts, donc pas de flottement par
arrondi), **squash-and-stretch** (compression au decollage ET a
l'atterrissage -- c'est ce canal qui porte le poids, et c'est pourquoi un
modele sans squelette suffit), et un pitch avant qui revient a plat a la
frame d'atterrissage.

Le corps s'oriente **avant** de quitter le sol (`_face`, ecriture directe et
non tween) : une rotation etalee sur le bond serait exactement le pilotage en
l'air que la regle ci-dessus refuse.

### Les portails ne declenchent PAS sur un overlap, et le router n'est PAS un autoload

`HubPortal` (Area3D) repond a « ce point d'atterrissage est-il dans moi ? »,
question posee uniquement sur `KeepyHopper.hop_landed`. Un `body_entered`
serait faux : un bond vise AU-DELA d'un portail traverse son volume en plein
vol, et le joueur serait avale en passant. `monitoring` et `monitorable` sont
**coupes** -- la forme reste la source unique de verite du rayon (lu sur le
`CylinderShape3D`, jamais duplique en constante), et rien ne peut recabler
`body_entered` par inadvertance. Cue d'approche : pulse en boucle sur
l'anneau, avec hysteresis (2,2 R / 2,6 R) pour qu'un Keepy pose sur la
frontiere ne fasse pas clignoter le portail a chaque bond.

`HubRouter` est un **noeud local de `HubWorld.tscn`**, pas un autoload : une
table de routage qui gagne un deuxieme appelant cesse d'etre un detail du hub
et devient un framework. Il porte aussi le garde `_leaving` (deux portails
atteints la meme frame ne doivent pas empiler deux chargements).

### ⚠️ PIEGE GODOT MESURE, ET IL ECHOUE EN SILENCE : un export de NOEUD TYPE ecrit A LA MAIN dans un `.tscn` NE SE RESOUT PAS

`@export var camera: Camera3D` avec `camera = NodePath("...")` dans le
fichier de scene rend **`null` au chargement**. La sonde de ce lot a obtenu
`null` sur les trois references de `HubTapInput` et **chaque tap mourait sur
le garde** -- aucune erreur, aucun crash, juste un plateau ou rien ne repond.
L'editeur peuple cette forme par une machinerie qu'un `.tscn` ecrit a la main
ne porte pas. **Parade adoptee : `@export var x_path: NodePath` + resolution
dans `_ready()` avec un cast et un `push_error`.** Toujours un chemin dont
l'auteur de scene est proprietaire, jamais un `get_node("../../X")` en dur.
**A connaitre avant d'ecrire un `.tscn` a la main dans ce depot.**

### Framing et sol : MESURES aux deux ratios, pas estimes

`HubCamera` suit la position AU SOL de Keepy (le y de l'arc est jete) a offset
fixe et **rotation FIXE, jamais un `look_at`** : un `look_at` reaimant chaque
frame sur une cible qui oscille de 0,6 unite par bond ferait tanguer
l'horizon entier au rythme des bonds -- bien plus visible que le personnage.
Lissage exponentiel, donc independant du framerate.

Offset `(0, 7,6, 8,9)` a **-34 deg**, `keep_aspect = KEEP_WIDTH`, `fov 45` --
**choisi par mesure** (sonde jetable, supprimee avant commit ;
`ProbeTimeoutAudit` revient a **37 sondes**) :

| offset | Keepy | portails lateraux |
|---|---|---|
| (0, 9,0, 10,5) | 104 px | labels a l'ecran |
| **(0, 7,6, 8,9) -- livre** | **124 px** | **pads a 7,8 % et 92,2 % de la largeur** |
| (0, 6,6, 7,7) | 144 px | **labels HORS CADRE** |

Verifie a **1080x1920 ET 1170x2532** : les trois labels et les trois pads
sont dans le cadre aux deux ratios, Keepy a 51-58 % de la hauteur.

⚠️ **Le sol fait 600x600 et `fog_light_color` EGALE `background_color`**
(le `SWAMP_SKY` `Color(0.062, 0.115, 0.044)`), et ce n'est pas decoratif :
a `-34 deg` avec la vfov portrait (72,7 deg a `KEEP_WIDTH`), **le haut du
cadre passe AU-DESSUS de l'horizon** (composante y du rayon `+0.041` en
1080x1920, `+0.137` en 1170x2532). Un sol trop court laissait donc voir son
bord franc : mesure a 26x26, l'arete tombait a 39 % de la hauteur d'ecran.
Avec la brume qui converge vers la couleur de fond, la jonction sol/ciel est
invisible par construction, quelle que soit la taille. Brume a **0,016** :
17 % sur Keepy, 25 % sur le portail central -- de la profondeur, pas un
delavage (les rayons de portail restent ambre).

`PLATEAU_HALF_EXTENT = 11` borne les taps. Verifie : le carre +-11 tombe
juste hors cadre lateralement, donc la borne est en pratique « le plateau
visible ». Un tap au-dela est **clampe, jamais ignore** -- un tap pres de
l'horizon est un joueur qui demande a aller aussi loin qu'il peut, et le
refuser en silence se lit comme un ecran casse.

### Le menu de secours n'est pas du poids mort

Un ecran 3D peut echouer la ou une liste de boutons ne peut pas : un contexte
WebGL qui ne revient jamais, un viewport noir, une projection de tap fausse a
un certain ratio. N'importe lequel echouerait sur le SEUL ecran par lequel
tous les jeux sont atteints. `FallbackMenu` porte les trois memes appels de
navigation, un petit bouton « Menu » a l'ecart -- le pire cas est un ecran
laid, pas un jeu inaccessible.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length` -- **50 276 070**
et **1 073 228 327**, aucune troncature). Import headless **exit 0** (24
`.scn`). Boot headless de `HubWorld.tscn` **exit 0, 0 erreur de parse**.
Export Web release **exit 0, 0 erreur, 0 warning** -- **les 8 scripts de
`scripts/hub/` sont compiles en `.gdc` dans le `.pck`**, ce qui est la preuve
qu'aucun n'a d'erreur GDScript. `index.wasm` **35 376 909** octets / md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b` -- identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur. `index.pck` 5 796 560 (export
unique et propre, `build/` supprime avant -- mise en garde permanente sur son
instabilite). Piege payload tenu : **0** ligne `Storing File` pour
`assets_source`, `scripts/dev`, `docs`, `web` ou `build`, sur 211 lignes.
**Aucune reference de `scripts/hub/` vers `scripts/dev/`** (grep, pas suppose)
-- `scripts/dev/*` est exclu du pack, une telle reference ne casserait QUE
dans le build web.

Sondes : `ProbeTimeoutAudit` (**37 sondes scenes**, retour exact a la
baseline), `AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**. Non-applicabilite
verifiee : aucune sonde de `scripts/dev/` ne charge `Hub.tscn`,
`HubWorld.tscn` ni `LoginScreen.tscn`.

⚠️ **Piege deja documente, re-rencontre a la lettre** : une sonde jetable dont
le SCRIPT ne parse pas ne tombe pas vite, elle traine jusqu'au timeout (la
scene ne se charge jamais, donc rien n'arme quoi que ce soit). Symptome ici :
sortie vide et `exit 124` a 200 s, cause reelle une seule ligne
`var err := 99.0 if ... else ...` (type non inferable). **Rediriger vers un
fichier et lire le log**, plutot que de conclure a un blocage.

### Ce que la sonde jetable a mesure (supprimee avant commit)

- **Round-trip du tap : erreur 0,00000** sur quatre cibles, et quatre taps aux
  extremes du cadre (pres de l'horizon, les deux coins bas) tous clampes dans
  le plateau, aucun avale en silence.
- **Apex du bond 0,599** contre `HOP_HEIGHT` 0,6.
- **Les pieds reposent a y = -0,0000** (AABB du modele installe + transform du
  slot), donc `model_offset (0, -0,2246, 0)` et le slot a `y = 0,9` -- les
  memes chiffres que `resources/battle/keepy.tres`, repris par mesure et non
  recopies a l'aveugle.
- **La regle de commit tient, prouvee dans le sens qui compte** : depart vers
  le portail Quizz, redirection **en plein vol** (frame 6) vers Battle, et le
  joueur atterrit sur **Battle** apres 5 bonds -- l'ordre `hop_landed` puis
  `_advance()` fait qu'un portail atteint route avant d'etre depasse par une
  destination au-dela.
- **`entered` contient exactement UNE entree**, et `change_scene_to_file` a
  reellement tourne (la scene a ete remplacee sous la sonde).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que le bond se lit comme un bond** a vitesse reelle au pouce, et
   est-ce que le squash donne du poids plutot que l'air d'un modele qui
   clignote ? Aucune sonde ne le dit, c'est tout l'objet du lot.
2. **La commit-au-bond (0,35 s) se sent-elle comme du poids ou comme du
   retard** quand on tape plusieurs fois de suite ?
3. **Keepy fait 124 px de haut** sur 1920 : mesure comme le maximum
   atteignable sans perdre un label de portail, mais lisible n'est pas mesure.
4. **Pas de queue animee** (Etape 0 : elle n'est pas un noeud separe).
5. **Aucun son, aucun asset Meshy neuf, aucune persistance** : hors perimetre.
6. Derive de doc pre-existante non corrigee ici : `scripts/autoload/Quizz.gd`
   dit encore que le bouton Quizz de `Hub.tscn` est `disabled` et connecte a
   rien -- faux depuis des semaines, et sans rapport avec ce lot.

### Deploiement staging du hub plateau (palier 1, automatique)

`staging` **`8fdb591`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `b01d7948` des deux cotes, verifie AVANT le push).
CI run **#196** (id `32646438061`) **verte** (14:46:02 -> 14:49:27 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement **skipped**. **`main` NON touche** (`origin/main` toujours
`ea722bd`, verifie apres le push) : palier 2, gate Mathieu apres validation
device.

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
`index.service.worker.js` de `keepy-staging.vercel.app` lu AVANT le merge et
APRES :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #194, lot 12 docs) | `1787432682` | 22 aout **21:04:42** |
| **apres (ce lot, run #196)** | **`1787496537`** | 23 aout **14:48:57** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #196**, et les deux
lectures portent `x-vercel-cache: MISS` + `age: 0` -- ce n'est pas une reponse
de cache. L'alias sert bien le build du plateau.

### ⚠️ SECOND PIEGE GODOT, MEME FAMILLE QUE LE PREMIER, ET IL AVALAIT CHAQUE TAP : un `Control` plein ecran laisse a `MOUSE_FILTER_STOP` (23 aout 2026)

Branche `claude/hub-portal-transition-bug-vcf47y`, partie de `staging`
(`b64eb37`). Retour device : « Keepy se deplace par bonds mais atterrir dans
un anneau ne declenche aucune transition ». **Un seul changement de
comportement : `mouse_filter = 2` sur le noeud racine de `HubWorld.tscn`.**

⚠️ **`_unhandled_input` s'execute APRES le picking GUI.** Tout `Control`
sous le doigt dont le `mouse_filter` vaut `STOP` consomme l'evenement et
appelle `set_input_as_handled()` ; plus rien en aval ne le voit — **aucune
erreur, aucun warning, juste un plateau qui ignore les taps**. La racine de
`HubWorld.tscn` est un `Control` plein ecran laisse au **DEFAUT de `Control`,
qui est `MOUSE_FILTER_STOP`** : elle avalait donc chaque tap avant
`HubTapInput`. Meme famille que le piege `@export`/`NodePath` de la section
ci-dessus — un cablage qui echoue en silence dans un `.tscn` ecrit a la main.

**MESURE EN A/B, pas deduit** — meme scene, meme binaire, fenetre REELLE
1170x2532 (`xvfb-run --rendering-driver opengl3`), un vrai
`InputEventScreenTouch` injecte sur le pixel de l'anneau :

| `HubWorld.mouse_filter` | `tapped_ground` emis | verdict |
|---|---|---|
| `0` = STOP (livre) | **0 fois** (touch ET souris) | le tap n'arrive JAMAIS |
| `2` = IGNORE (ce lot) | 2 fois (touch) / 1 fois (souris) | chaine complete verte |

⚠️ **`--headless` NE PEUT PAS voir ce defaut, et c'est le piege dans le
piege.** Le display server dummy rapporte une fenetre **0x0**, donc
`get_final_transform()` vaut 1/30 et un evenement injecte atterrit
hors-ecran : `gui_find_control` ne trouve rien, personne ne consomme, et
`_unhandled_input` se declenche — **un vert que le device n'a pas**. Une
sonde headless du lot precedent avait ainsi valide la chaine complete
(portails construits, `hop_landed` connecte, `portal_entered` cable,
`change_scene_to_file` execute) : tout cela etait vrai, et le tap n'arrivait
quand meme pas. **Toute sonde qui injecte un evenement de pointeur doit
tourner en FENETRE REELLE.**

**Ce que le diagnostic a INNOCENTE, mesure et pas suppose** — aucun de ces
points n'avait besoin d'etre touche : `hop_landed` est emis a chaque
atterrissage avec la position monde ; son unique auditeur est bien
`HubWorld._on_hop_landed` ; `landed_within` compare en X/Z contre le rayon lu
sur le `CylinderShape3D` (**1,35**, jamais duplique en constante) ;
`portal_entered` a exactement un auditeur par portail ; `HubRouter.ROUTES`
resout les trois `game_id` ; et **aucun `@export` de type noeud n'a ete
reintroduit** (les trois references de `HubTapInput` et celle de `HubCamera`
sont bien des `NodePath` resolus en `_ready()`). Verifie aussi **sur le
`.pck` exporte** : `hub_layout.tres` est converti en `.res` binaire a
l'export et le round-trip preserve les `StringName` de `type`/`game_id`.

**Preuve, TROIS portails testes un par un** (sonde jetable, fenetre reelle,
tap sur le pixel de l'anneau, supprimee avant commit — `ProbeTimeoutAudit`
revient a **37 sondes**) : le tap arrive, vise a **0,17-0,19 m** du centre
(rayon 1,35), et `change_scene_to_file` aboutit reellement sur
`TitleScreen.tscn` / `QuizzHomeScreen.tscn` / `Battle.tscn`. **Rouge d'abord**
sur l'arbre pre-fix, sur l'assertion qui compte (« le tap atteint
HubTapInput »), avant d'etre vert.

**Le bouton « Menu » de secours n'est PAS abime** : `IGNORE` ne retire que la
racine du picking, ses enfants sont piques normalement — mesure, 1 pression
recue et **0 tap parasite** sur le sol. `KeepyHopper` est **intouche**, et
aucun `body_entered`/`monitoring` n'est reintroduit.

⚠️ **Derive de doc corrigee au passage, elle etait FAUSSE** : l'en-tete de
`HubTapInput.gd` affirmait « exactement un des deux evenements arrive par
geste, pas de double-fire a garder ». Mesure : `emulate_mouse_from_touch`
vaut **true** par defaut, donc un doigt produit un touch release **ET** une
souris synthetisee, et `tapped_ground` part **deux fois**. Inoffensif
(`hop_to` est de profondeur un, le second appel redit la meme destination),
mais l'affirmation ne tenait pas.

⚠️ **DEUX POINTS OUVERTS, mesures et deliberement NON corriges ici.**
1. **Le rapport device dit « Keepy se deplace par bonds », or la mesure dit
   qu'aucun tap n'arrivait** — ces deux faits ne se recouvrent pas. Le fix
   est necessaire dans les deux lectures (il est la seule difference entre
   une chaine morte et une chaine verte, prouvee des deux cotes), mais si
   Keepy bougeait REELLEMENT avant, alors un second facteur reste a trouver
   et le prochain test device le dira.
2. **Le LABEL flottant est un piege de visee**, mesure : il est a
   `y = 1,55`, donc un tap dessus retombe **3,7-3,8 m AU-DELA** du portail
   (parallaxe a -34 deg). Balayage sur 108 taps realistes (6 departs x 6
   points de visee x 3 portails) : **9 ne tombent jamais dans le disque de
   declenchement**, tous par le label ou le bord de l'anneau, et tous
   marginaux (1,41-1,78 contre 1,35). Non corrige — bouger le rayon ou
   viser le sol sous le label est un reglage de gameplay qui merite sa
   propre passe device.


### Deploiement staging du fix mouse_filter (palier 1, automatique)

`staging` **`1c960c3`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `f899cc64` des deux cotes, verifie AVANT le push).
CI run **#200** (id `32659662717`). **`main` NON touche** (`origin/main`
toujours `ea722bd`, verifie apres le push) : palier 2, gate Mathieu apres
validation device.

**Verifie SUR LE SERVICE, dans les DEUX sens** — `CACHE_VERSION` de
`index.service.worker.js` de `keepy-staging.vercel.app` lu avant et apres :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #199, SwampPalette) | `1787502474` | 23 aout **16:27:54** |
| **apres (ce lot, run #200)** | **`1787511598`** | 23 aout **18:59:58** |

L'epoch d'apres tombe dans la fenetre du run #200 (demarre 18:56:55), avec
`x-vercel-cache: MISS` et `age: 0` — l'alias sert bien le build du fix.
⚠️ L'API GitHub Actions est restee **figee sur `in_progress`** pendant tout ce
temps, `updated_at` bloque a 18:56:59 : enieme reproduction du piege deja
consigne, et c'est encore le `CACHE_VERSION` servi qui a tranche.

### RETOUR CHASED CASSE, ET LA CAUSE N'ETAIT PAS UN CHEMIN A CORRIGER (23 aout 2026)

Branche `claude/keepy-hub-return-portal-phv4hm`, partie de `staging`
(`d2e5233`). Retour device : depuis le plateau, entrer dans Keepy Chased
est un aller simple — plus aucun moyen de revenir sans recharger la page.
Quizz revient bien, Battle non teste.

⚠️ **LE BALAYAGE COMPLET DU DEPOT SUR `Hub.tscn` NE TROUVE AUCUN CHEMIN
CHASED A CORRIGER — parce qu'il n'y en a jamais eu un.** C'est le
diagnostic entier du lot, et il inverse la premisse du brief (« mettre a
jour tout chemin de retour trouve »). Mesure, pas suppose :

| sous-jeu | sortie vers le hub, AVANT ce lot |
|---|---|
| Quizz | `QuizzHomeScreen.gd:63` — `BackButton` du header, **deja** repointe sur `HubWorld.tscn` |
| Battle | `BattleArena.gd:60` `HUB_SCENE` + `:259` `_on_quit()` — **deja** repointe, correct, aucun defaut latent |
| **Chased** | **AUCUNE.** `TitleScreen.gd` ne fait que `change_scene_to_file("res://scenes/Game.tscn")` (vers l'AVANT) ; `GameOverScreen.gd:189` n'offre que `_on_retry_pressed()` -> `GameState.start_run()` |

Le lot plateau avait donc raison de ne modifier que trois fichiers
(`LoginScreen.gd`, `QuizzHomeScreen.gd`, `BattleArena.gd`) : ce sont les
trois seuls qui **nommaient** une scene de hub. Chased n'en nommait
aucune, donc il n'est pas apparu dans le `grep` du lot precedent — et il
etait deja sans retour AVANT le plateau, simplement invisible tant que le
hub etait l'ecran d'ou l'on venait et ou le bouton retour du navigateur
suffisait. **Le fix est un chemin de retour NEUF, pas un chemin corrige.**

**Balayage complet re-verifie apres ce lot** : les seules occurrences
restantes de la chaine `Hub.tscn` hors `HubWorld.tscn` sont des
commentaires historiques (`HubWorld.gd`, `HubLayout.gd`, `Quizz.gd`,
`LoginScreen.gd`) plus `scenes/Hub.tscn` et `scripts/ui/Hub.gd`
eux-memes. **Aucun code vivant ne route vers l'ancien hub.**
`scenes/Hub.tscn` reste dans le depot, intouche : c'est le rollback, comme
le lot plateau l'avait pose.

**Deux sorties ajoutees, une par point de blocage** — une seule n'aurait
pas suffi, parce qu'une run se termine sur `GameOverScreen` et pas sur
`TitleScreen` :

* `scenes/TitleScreen.tscn` + `TitleScreen.gd` : bouton **`< Hub`** en haut
  a gauche, meme role que le `BackButton` du header de Quizz.
* `scenes/GameOverScreen.tscn` + `GameOverScreen.gd` : bouton **`Retour au
  hub`** sous `Rejouer`. Sans lui, mourir enfermait le joueur dans une
  boucle « Rejouer » infinie. Aucun `GameState` reset avant de partir :
  `Game.tscn` appelle `start_run()` dans son propre `_ready()`, donc
  reinitialiser ici ne ferait que doubler ce travail dans la scene qu'on
  s'apprete a liberer.

### UN BOND QUI ATTERRIT DANS UN ANNEAU NE LANCE PLUS LE JEU : `HubConfirmDialog`

Un bond est vise par un **tap sur le sol**, et un tap n'est pas precis :
un joueur qui traverse le plateau pouvait atterrir dans un portail qu'il
comptait seulement survoler et se retrouver dans un sous-jeu sans avoir eu
un mot a dire — sur Chased, sans retour, c'etait une impasse. Depuis ce
lot, **un atterrissage PROPOSE, il n'entre plus** : `portal_entered` ouvre
une popup (nom du jeu + `Jouer` / `Annuler`), et seul `Jouer` route.

⚠️ **Le ROUTAGE est inchange, seulement retarde d'un tap.** `HubRouter`
reste la seule table `game_id -> scene` et le seul appelant de
`change_scene_to_file`. `HubConfirmDialog.gd` **ne contient aucune logique
de routage** : il recoit un `game_id`, le rend tel quel sur
`confirmed(game_id)`, et ne le lit jamais. Ajouter un 4e jeu touche
`HubRouter.ROUTES` et le layout `.tres`, pas ce fichier.

**Le nom affiche vient du portail lui-meme**, pas d'une table ici :
`HubPortal.display_label()` relit le `Label3D` que `HubBuilder` a deja
rempli depuis `resources/hub/hub_layout.tres`. Le signal devient donc
`portal_entered(game_id: StringName, label: String)` — les deux valeurs
sont la donnee propre du portail. Une seconde table de noms serait une
copie libre de deriver du panneau plante sur le plateau.

**Le menu de secours route TOUJOURS DIRECTEMENT, volontairement.** Appuyer
sur un bouton libelle « Keepy Quizz » est deja un choix explicite ; y
ajouter une confirmation serait une seconde popup posant la question de la
premiere, sur le chemin qui existe justement pour etre le simple quand le
3D a echoue.

**`Annuler` ne recule pas Keepy.** Se tenir dans un portail est une
position legale du plateau ; repousser le joueur repondrait par un
mouvement qu'il n'a pas demande a une question qu'il vient de decliner. La
popup ne se rouvre qu'au PROCHAIN atterrissage, donc taper ailleurs suffit
a repartir. Un tap sur le scrim ne fait rien non plus — ni valider ni
annuler : un doigt egare a cote du panneau ne doit pas pouvoir repondre a
la place du joueur, dans un sens comme dans l'autre.

### ⚠️ TROISIEME PASSAGE SUR LE PIEGE `mouse_filter`, ET IL COURT DANS L'AUTRE SENS

Les deux fois precedentes, un `Control` a `MOUSE_FILTER_STOP` **avalait**
les taps du plateau. Ici le danger est inverse : `HubTapInput` ecoute dans
`_unhandled_input`, donc tout ce que la popup **n'avale pas** atteint le
plateau et fait bondir Keepy sous une popup ouverte.

**Mesure sur Godot 4.3 dans ce sandbox, pas lue de memoire** (`ClassDB`
instancie chaque type, `mouse_filter` imprime) :

| type | defaut mesure |
|---|---|
| `Control`, `ColorRect`, `PanelContainer`, `Button` | **0 = STOP** |
| `VBoxContainer`, `TextureRect` | 1 = PASS |
| `Label` | 2 = IGNORE |

Le defaut est donc deja correct — et il n'est **deliberement pas laisse au
defaut** : `HubConfirmDialog.tscn` ecrit `mouse_filter = 0` explicitement
sur sa racine, son `Scrim` et son `Panel`, et `_ready()` re-affirme
`MOUSE_FILTER_STOP` sur la racine. Les deux devraient etre casses ensemble
pour que la popup redevienne traversante. **Ceinture et bretelles
par-dessus** : `HubWorld._on_tapped_ground` refuse aussi tout tap sol tant
que `_confirm.is_open()` (le meme garde que le menu de secours utilise
deja), et `_on_hop_landed` refuse d'ouvrir une seconde fois pour un bond
deja en l'air. Ces gardes ne devraient jamais tirer ; la panne qu'elles
couvrent est **silencieuse**, et c'est la moitie la moins chere de ne pas
la decouvrir sur device.

**`HubConfirmDialog.tscn` est instancie EN DERNIER dans `HubWorld.tscn`** :
le picking GUI parcourt l'arbre en ordre inverse, donc la popup recoit
l'evenement avant `FallbackButton` et `FallbackMenu`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles confirmees contre le `Content-Length` —
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0**, **24 `.scn`** (import complet verifie, pas suppose : le piege du
faux-rouge par import tronque est controle). Export Web release **exit 0**.
`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 807 744 (export unique et propre, `build/` supprime avant — a lire avec
la mise en garde permanente sur son instabilite). Piege payload tenu :
**0** ligne `Storing File` pour `scripts/dev`, `assets_source`, `docs`,
`web` ou `build`.

**Boot headless des 7 scenes concernees** (`--quit-after 2`) : `HubWorld`,
`HubConfirmDialog`, `TitleScreen`, `GameOverScreen`, `Hub` (le rollback,
toujours chargeable), `Battle`, `QuizzHomeScreen` — **exit 0, 0 erreur
GDScript** partout.

**Sonde jetable** (`scripts/dev/HubConfirmProbe.tscn`, jamais commitee,
supprimee avant le commit — `ProbeTimeoutAudit` revient a **37 scenes de
sonde**, le chiffre de `origin/staging`). Elle pilote la **scene livree**
`HubWorld.tscn`, jamais un stub : **47 assertions, 0 echec, exit 0**.
PHASE A contrat de scene et les trois `mouse_filter` ; PHASE B les 3 routes
intactes ; PHASE C **un atterrissage sur chacun des 3 portails ouvre la
popup, titre lu sur le `Label3D` du portail, et ne route RIEN** ; PHASE D
tap sol ignore popup ouverte (Keepy immobile) + pas de re-ciblage ; PHASE E
Annuler ferme, ne route pas, ne bouge pas Keepy ; PHASE F le plateau
reaccepte les taps apres Annuler ; PHASE G `Jouer` emet exactement le bon
`game_id`, popup deja cachee au moment de l'emission ; PHASE H les 3 routes
pointent sur des scenes qui existent ; PHASE I **les trois sous-jeux ont un
retour vers `HubWorld.tscn`**, lu sur les scenes et les scripts livres.

⚠️ **PHASE G a d'abord PROUVE le routage en se suicidant** : le vrai
handler de `HubWorld` laisse branche fait changer de scene pour de vrai, ce
qui libere la sonde en pleine assertion (`get_tree()` null, mesure). La
phase asserte donc d'abord que `_on_confirm_accepted`/`_on_confirm_cancelled`
SONT branches, puis debranche le premier — la chaine reste prouvee de bout
en bout sans que la sonde se detruise.

⚠️ **Piege d'outillage rencontre : `godot4 --script` NE CHARGE PAS LES
AUTOLOADS.** Une premiere version de la sonde en `SceneTree`/`--script` est
morte sur `Identifier not found: SafeArea` dans `HubWorld.gd` — un faux
rouge qui ressemble a une erreur de compilation du jeu. Toute sonde de ce
depot doit etre une `.tscn` lancee comme scene principale, ce que la
convention maison fait deja partout.

**Sondes permanentes rejouees, toutes exit 0** : `ProbeTimeoutAudit`
(**37 scenes de sonde**, toutes armees), `AssetContractAudit` (**12/12
visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe`. **Non-applicabilite VERIFIEE par grep, pas supposee** :
aucune sonde de `scripts/dev/` ne charge `HubWorld.tscn`,
`HubConfirmDialog.tscn`, `TitleScreen.tscn` ni `GameOverScreen.tscn` — la
seule mention est dans des COMMENTAIRES de `SwampIdentityAudit.gd`, qui
explique justement depuis le 14 aout pourquoi il n'echantillonne plus
l'ecran-titre.

### Reste ouvert -- jugement device, seul juge

1. **Le retour de Chased fonctionne-t-il vraiment sur telephone**, depuis
   l'ecran-titre ET depuis l'ecran de fin de partie. C'est le bug qui a
   ouvert le lot, et aucune sonde ne rend ce jugement.
2. **La popup se lit-elle comme une question**, ou comme un ecran de plus
   entre le joueur et son jeu ? Un bond reussi qui debouche sur une
   confirmation est un frottement volontaire ; s'il agace plus qu'il ne
   protege, le reglage est de la retirer du portail deja survole plutot que
   de la raccourcir.
3. **`Annuler` laisse Keepy DANS l'anneau**, donc le portail continue de
   pulser sous lui. Mesure comme sans effet mecanique (la popup ne se
   rouvre qu'au prochain atterrissage), mais l'effet visuel « je suis
   toujours dessus » n'a pas ete juge a l'oeil.
4. **Battle n'avait pas ete teste sur device** avant ce lot ; son retour est
   verifie STRUCTURELLEMENT ici (`BattleArena.HUB_SCENE`, PHASE I) et
   toujours pas a la main.

### Deploiement staging du retour Chased + popup (palier 1, automatique)

`staging` **`05fe613`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `2eb7e122` des deux cotes, verifie
AVANT le push). CI run **#202** (id `32663818628`). **`main` NON touche**
(`origin/main` toujours `ea722bd`, verifie apres le push) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE, dans les DEUX sens** — `CACHE_VERSION` de
`index.service.worker.js` de `keepy-staging.vercel.app` :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #201) | `1787512074` | 23 aout **19:07:54** |
| **apres (ce lot, run #202)** | **`1787516270`** | 23 aout **20:17:50** |

L'epoch d'apres tombe dans la fenetre du run #202 (demarre 20:14:50), avec
`x-vercel-cache: MISS` et `age: 0` — l'alias sert bien le build du lot.
⚠️ Le « avant » n'est pas lu de memoire : il a ete relu sur le service a
20:16:22 puis a 20:18:09, **toujours l'ancienne valeur**, ce qui prouve
aussi que le job tournait REELLEMENT au lieu d'etre un cache perime.
⚠️ L'API GitHub Actions est restee **figee sur `in_progress`**,
`updated_at` bloque a 20:14:54 sur tous les appels : enieme reproduction du
piege deja consigne, et c'est encore le `CACHE_VERSION` servi qui a
tranche, dans les deux sens.

## HUB : DENSIFICATION DU DECOR -- nouveau type `flower`, 15 -> 53 entrees, zone jouable INCHANGEE (24 aout 2026)

Branche `claude/hub-decor-densification-rcnrj5`, partie de `main`
(`fe1d110`, le commit de doc du merge de prod du hub plateau). **Lot
purement VISUEL** : `PLATEAU_HALF_EXTENT` (11.0), `HOP_DISTANCE` (1.5) et
`HubCamera.OFFSET` sont **intouches**, verifie par `git diff` -- les trois
fichiers qui les portent (`HubTapInput.gd`, `KeepyHopper.gd`,
`HubCamera.gd`) ne sont pas dans le diff du tout.

### RECON : `HubCamera` SUIT bien Keepy, elle n'est pas statique

Reponse a la question qui conditionne le lot B, avec le code exact :
`HubCamera.gd` porte un `_process(delta)` qui recalcule sa position
**chaque frame** depuis le joueur --

```gdscript
func _process(delta: float) -> void:
	if target == null: return
	var weight: float = 1.0 - exp(-FOLLOW_LAMBDA * delta)
	global_position = global_position.lerp(_wanted(), weight)

func _wanted() -> Vector3:
	var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
	return ground + OFFSET
```

`target` est resolu dans `_ready()` depuis `target_path`, que
`HubWorld.tscn` pose a `NodePath("../Keepy")` -- donc la cible EST le
`KeepyHopper`. Trois proprietes a connaitre pour le lot B : le suivi est
**exponentiel donc independant du framerate** (`FOLLOW_LAMBDA = 5.0`) ;
la **rotation est FIXE**, jamais un `look_at` (un re-visage chaque frame
sur une cible qui oscille de 0,6 unite par bond ferait tanguer l'horizon
entier) ; et le y de Keepy est **jete** -- la camera suit sa position AU
SOL, pas sa position dans l'arc.

### Nouveau type `&"flower"` -- deux primitives, trois teintes

`_make_flower(entry)` dans `HubBuilder.gd`, meme doctrine que les props
existants : primitives Godot uniquement (aucun `.glb`, aucun credit Meshy
depense), `StandardMaterial3D` **unshaded** (la scene n'a aucune
`DirectionalLight3D`, donc une surface eclairee ne rendrait plus la
couleur qu'on a ecrite), et tessellation basse **explicite** -- tige
`CylinderMesh` a `radial_segments = 6`, corolle `SphereMesh` aplatie a
`radial_segments = 8` / `rings = 3`. C'est le piege §7.2 des
collectibles, ferme a la source plutot que decouvert au budget.

**Trois teintes de corolle, pas une** : un champ monochrome se lit comme
une instance repetee, ce qu'il est litteralement. Le champ optionnel
`"variant": int` choisit l'index dans `FLOWER_PETAL_COLORS` ; **hors
plage ou absent retombe sur 0**, donc un layout ecrit sans ce champ
construit quand meme.

⚠️ **`FLOWER_STEM_COLOR` et `FLOWER_PETAL_COLORS` restent LOCALES a
`HubBuilder.gd`, deliberement.** `SwampPalette.gd` porte l'identite que
Chased et le plateau PARTAGENT ; son propre en-tete range les couleurs de
props du hub comme "hub-local, not shared identity", au meme titre que
`TRUNK`/`CROWN`/`ROCK`/`BUSH` deja en place. Les migrer serait promouvoir
du decor local au rang d'identite partagee, et donner a une future
retouche de fleur le pouvoir de deplacer une couleur que
`DarkPaletteAudit` mesure.

### Garde-fou de bornes : la constante est LUE, jamais recopiee

`HubBuilder._build()` `push_warning` si une entree sort du clamp de tap,
avec son index, son type et sa position. **L'entree est CONSERVEE**, pas
rejetee : du decor lointain est une chose legitime a vouloir, alors qu'un
prop qu'on croit atteignable et qui ne l'est pas est un defaut silencieux.

Le bound vient de `HubTapInput.PLATEAU_HALF_EXTENT` (`class_name`, donc
la reference resout statiquement) et **n'est pas duplique** : deux copies
d'une limite de zone jouable, c'est comme ca qu'elles divergent.

### 15 -> 53 entrees, toutes verifiees contre trois contraintes

3 portails + 50 props : **14 `tree`, 8 `rock`, 13 `bush`, 15 `flower`**
(cible indicative 14/8/14/16 ; deux placements de grappe ont echoue le
test de separation et n'ont pas ete forces).

Les trois contraintes sont **mesurees sur le jeu de positions genere**,
pas supposees :

| contrainte | exigee | mesuree |
|---|---|---|
| dans le plateau | `<= 10.4` | **max 10.13** |
| loin d'un centre de portail | `>= 2.0` | **min 2.147** |
| loin du spawn de Keepy | `>= 1.5` | **min 3.043** |

Le rayon de declenchement d'un portail est **1,35** (lu sur le
`CylinderShape3D` de `HubPortal.tscn`, jamais recopie) : les 2,0 laissent
donc 0,65 de marge autour de l'anneau ou un bond atterrit. Le spawn de
Keepy est l'origine -- le noeud `Keepy` de `HubWorld.tscn` ne porte aucun
transform.

**La zone AVANT / SOUS les portails (z positif, cote camera) est
desormais peuplee** : c'etait le vide reellement visible a l'ecran, la
totalite des 15 entrees d'origine vivant a `z <= 3.3` cote proche et
surtout au fond. Buissons et fleurs sont poses en **grappes de 3 a 5**
autour d'ancres choisies, avec jitter -- un semis regulier se lit comme
un placeholder. `scale` couvre **0,64 a 1,38** et `rotation_y` est libre
sur 360 degres.

### Cout : 92 `MeshInstance3D`, sous le seuil de 120

Compte exact des noeuds que `HubBuilder` construit (un `tree` = 2, un
`rock` = 1, un `bush` = 2, une `flower` = 2) : **92**, plus les meshes
internes des 3 portails, qui viennent de `HubPortal.tscn` et non du
builder. **Aucun `MultiMeshInstance3D` dans ce lot** -- a ~50 props
statiques unshaded low-poly l'instance individuelle tient, et le refactor
serait premature. Le chiffre est sous les 120 qui auraient valu alerte,
donc rien a signaler au lot B sur cet axe ; c'est en revanche le nombre a
reprendre comme base si la densite doit encore monter.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles confirmees contre le `Content-Length` --
**50 276 070** et **1 073 228 327** octets, aucune troncature). Import
headless **exit 0**, **24 `.scn`** (import complet verifie et pas
suppose : le piege du faux-rouge par import tronque est controle),
**0 erreur**. Boot headless de `HubWorld.tscn` (`--quit-after 3`)
**exit 0**, aucune erreur de parse -- et **aucun `push_warning` de
bornes**, ce qui est la confirmation a l'execution que les 53 entrees
sont dans le plateau. Export Web release **exit 0**, aucune erreur
GDScript.

`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** ; `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur, coherent : ce
lot n'ajoute qu'une fonction de builder et des chiffres dans un `.tres`.
`index.pck` 5 813 936 octets (export unique et propre, `build/` supprime
avant -- a lire avec la mise en garde permanente sur son instabilite,
jamais offert comme preuve). **Piege payload tenu** : **0** ligne
`Storing File` pour `assets_source`, `scripts/dev`, `docs`, `web` ou
`build`.

**Sondes rejouees, toutes exit 0** : `ProbeTimeoutAudit` (**37 sondes
scenes**, toutes armees -- chiffre inchange, ce lot n'ajoute aucune
sonde), `AssetContractAudit` (**12/12 visuels, 0/10 colliders
deplaces**), `DeathModelAudit`, `ChargerShapeProbe`.
**Non-applicabilite VERIFIEE par grep, pas supposee** : aucune sonde de
`scripts/dev/` ne reference `HubWorld`, `HubBuilder` ni `hub_layout` --
elles ne peuvent pas voir ce lot, elles peuvent seulement attester qu'il
n'a rien casse ailleurs.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que le plateau se lit comme un lieu** plutot que comme trois
   portails sur un terrain vide ? C'est tout l'objet du lot, et aucune
   sonde ne le dit.
2. **Les fleurs sont-elles lisibles a la taille reelle** ? Une corolle de
   0,15 d'unite de rayon sur un Keepy mesure a 124 px de haut est petite ;
   son contraste contre le sol vert n'a **pas** ete mesure au pixel, il a
   ete choisi a l'oeil sur des valeurs claires (jaune, rose, mauve pale)
   contre un sol a `Color(0.2, 0.4, 0.15)`.
3. **La densite pres du chemin** : rien ne bloque un bond (les props n'ont
   aucun collider), mais un plateau plus charge peut rendre la lecture du
   sol plus difficile au moment de viser un tap.
4. `MultiMeshInstance3D` non fait, deliberement (92 instances, seuil 120).

### Deploiement staging de la densification (palier 1, automatique)

`staging` **`12386bf`**. CI run **#208** (id `32785607895`) **verte**
(22:38:35 -> 22:41:14 UTC) -- `Deploy to Vercel [STAGING -- staging]`
succes a 22:41:12, `[PRODUCTION -- main]` correctement **skipped**.
**`main` NON touche** (`origin/main` toujours `fe1d110`, verifie apres le
push) : palier 2, gate Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
`CACHE_VERSION` de `index.service.worker.js` de
`keepy-staging.vercel.app` :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #204, 23 aout) | `1787517625` | 23 aout **20:40:25** |
| **apres (ce lot, run #208)** | **`1787611249`** | 24 aout **22:40:49** |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build` du
run #208** (22:40:46 -> 22:40:50), avec `x-vercel-cache: MISS` et
`age: 0`. Le « avant » a ete relu **quatre fois pendant que le job
tournait**, toujours a l'ancienne valeur : le job avancait donc REELLEMENT
au lieu d'etre un cache perime, et la bascule est prouvee dans les deux
sens.

⚠️ **Le run #207 (le merge du code) est `cancelled`, et ce n'est PAS un
echec** : `web-build.yml` porte `cancel-in-progress: true` sur sa
`concurrency`, donc le push du commit de doc (#208) a tue #207 en cours
d'import. #208 construit le MEME arbre plus `CLAUDE.md` -- qui n'est pas
une ressource Godot -- donc le contenu de jeu deploye est bien celui du
lot. **Consequence pour un futur lot : pousser le code puis la doc coup
sur coup annule le premier run**, et un lecteur qui ne regarde que le
numero de run le lirait comme un echec.

## HUB : LE PLATEAU PASSE DE 11 A 15, ET GAGNE QUATRE LANDMARKS D'ORIENTATION (25 aout 2026)

Branche `claude/plateau-extension-landmarks-6dxwge`, partie de `main`
(`33f7aa4`, le merge du lot A de densification). **Lot purement VISUEL et de
zone jouable** : `HubCamera.OFFSET`, `FOLLOW_LAMBDA`, `fov`, la rotation de
camera et `KeepyHopper.HOP_DISTANCE` sont **INTOUCHES**, verifie par
`git diff` -- `HubCamera.gd` et `KeepyHopper.gd` ne sont pas dans le diff du
tout.

### RECON BLOQUANTE -- les trois questions, repondues par mesure

**R1. PORTEE DU FOG -- le landmark n'est PAS efface, avec une grosse marge.**
`fog_mode` n'est ecrit nulle part dans `HubWorld.tscn`, donc c'est le DEFAUT,
**mesure et pas suppose** (`Environment.new()` en headless) : `fog_mode = 0`
= EXPONENTIEL, `fog_height_density = 0` (aucun fog de hauteur qui viendrait
s'ajouter). La formule appliquee par le shader Godot 4.3 dans ce mode est
`amount = 1 - exp(-distance * fog_density)`, avec `hub_fog_density = 0.016`
(lu dans `swamp_palette.tres`, jamais recopie) :

| distance camera | occlusion |
|---|---|
| 10 u | 14,8 % |
| 20 u | 27,4 % |
| **28 u** *(landmark vu du bord oppose)* | **36,1 %** |
| 43,3 u | **50 %** |
| 143,9 u | **90 %** |

Le 50 % n'est atteint qu'a **43,3 unites** et le 90 % a **143,9**. Un
landmark a rayon 12,6 vu depuis le bord oppose est a ~28 unites de la
camera et garde donc **64 % de sa propre couleur**. Aucune reduction de
`hub_fog_density` n'a ete necessaire, et aucun rayon n'a eu a etre reduit :
la condition de blocage du brief (« si le fog efface au-dela de ~25
unites ») **ne se declenche pas**.

**R2. HORIZON -- aucun bord de sol n'est jamais visible, et le haut du cadre
etait DEJA du ciel avant ce lot.** Mesure sur la scene reelle, camera figee
a `(15, 7.6, 8.9)` (Keepy au NOUVEAU bord), `_process` de `HubCamera` coupe
et `SubViewportContainer.stretch` desactive -- sans ces deux precautions la
camera lerpe pendant la mesure et les coins ne sortent plus symetriques,
piege rencontre au premier essai :

| viewport | haut-centre | bas-centre |
|---|---|---|
| 1080x1920 | `dir.y = +0,0413` (**+2,37 deg**) -> **CIEL** | -70,34 deg -> sol a 8,1 u, `max\|axe\| = 15,0` |
| 1170x2532 | `dir.y = +0,1370` (**+7,87 deg**) -> **CIEL** | -75,85 deg -> sol a 7,8 u, `max\|axe\| = 15,0` |

Les `+0,041` et `+0,137` **reproduisent au chiffre pres** ceux deja
consignes pour ce hub, ce qui valide le banc avant qu'on lui fasse
confiance. Le rayon de sol le plus lointain atteint `max\|axe\| = 28,5`
contre les **+-300** du `PlaneMesh` 600x600 : marge d'un facteur 10, le
bord est hors de portee. Et la jonction sol/ciel reste invisible par
construction, `hub_fog_light_color` valant exactement `sky_shallow`.
⚠️ **Point important : ce n'est PAS un cas de cadrage nouveau.** La camera
suit Keepy en x/z, donc la vue depuis `x = 15` a exactement la meme FORME
que depuis `x = 0` -- seul le contenu du monde sous elle change. Elargir le
plateau ne peut structurellement pas ouvrir un bord.

**R3. CADRAGE DES PORTAILS -- la lecture du brief est JUSTE, `OFFSET` n'a
rien a re-mesurer.** Les trois portails restent a `(-5,4, -4,6)`,
`(0, -7,2)` et `(5,4, -4,6)` : ce lot n'y touche pas. Le calibrage documente
de `OFFSET` porte sur la lisibilite d'un label de portail **quand Keepy est
pres de lui**, et la camera etant un suivi 1:1 cette situation est
identique avant et apres. Rien a bouger.

### La constante a exactement TROIS lecteurs, verifie par grep

`PLATEAU_HALF_EXTENT` : sa declaration, les deux `clampf` de
`HubTapInput._handle_point`, et la lecture de `HubBuilder` pour son
avertissement de bornes. **Aucune valeur `11.0` dupliquee ailleurs** dans
`scripts/hub/`, `scenes/Hub*.tscn` ni `resources/hub/`. Le passage a
**15.0** suit donc automatiquement des deux cotes -- c'est precisement
pourquoi le lot A avait refuse d'en faire une seconde copie.

### Le nouveau type `&"landmark"` -- la HAUTEUR ne suffit pas

`_make_landmark()` dans `HubBuilder.gd`, meme doctrine que l'existant :
primitives Godot seules (**aucun `.glb`, aucun credit Meshy depense**),
`StandardMaterial3D` **unshaded**, tessellation basse **explicite** (piege
7.2 des collectibles). Couleurs en constantes **LOCALES** (`LANDMARK_*`),
rien migre vers `SwampPalette` -- son propre en-tete range ce genre de
couleur comme decor hub-local, au meme titre que `TRUNK`/`ROCK`/`BUSH` et
les teintes de fleurs du lot A.

**Hauteur mesuree sur la scene construite : 8,45 / 8,40 / 8,06 unites**
contre **2,85** pour le prop ordinaire le plus haut (l'arbre) -- soit
**2,96x**, la cible de ~3x. Mais la hauteur seule ne suffit pas : un arbre
agrandi reste de forme d'arbre et se lit comme « encore du decor ». Chaque
variante est donc une **SILHOUETTE differente**, et c'est ce qui porte
l'orientation -- distinguer deux landmarks l'un de l'autre, pas simplement
en avoir quatre.

| `variant` | silhouette | meshes |
|---|---|---|
| **0** spire | une aiguille : fut elance + trois cones empiles, etroit | 4 |
| **1** cairn | un empilement de blocs tournes, large et gris | 5 |
| **2** twin slabs | deux dalles verticales de hauteurs inegales | 3 |

Hors plage retombe sur 0, meme regle que `flower`.

⚠️ **LES COULEURS SONT DELIBEREMENT CLAIRES, et c'est une consequence
directe de R2.** Le haut d'un landmark depasse la ligne d'horizon (le haut
du cadre est a +2,4 deg au-dessus de l'horizontale), donc il est lu **contre
le CIEL** -- et le ciel ici est le vert marecage quasi noir
(`sky_shallow`, luminance ~0,099). Une silhouette sombre contre un ciel
sombre n'est pas un repere, c'est un trou. Les deux familles se separent
aussi par la TEINTE et pas seulement par la valeur : spire vert clair
`(0.38, 0.58, 0.30)`, pierre grise `(0.44..0.56)` -- un second axe de
distinction quand la silhouette est vue de trop loin pour etre lue.

⚠️ **`_mesh_node` gagne un quatrieme parametre `rotation_deg`, avec un
defaut `Vector3.ZERO`** : purement additif, les quatre appelants existants
sont inchanges. Il est necessaire parce qu'un cairn est fait de blocs
tournes et une dalle est inclinee -- un offset seul ne l'exprime pas.

### Placement -- les trois contraintes MESUREES, pas supposees

Quatre landmarks a azimuts distincts (N/E/S/O), rayon ~12,6, compatible avec
R1 :

| landmark | position | variant | echelle |
|---|---|---|---|
| N | `(0, -12,60)` | 0 spire | 1,00 |
| E | `(12,70, 0,55)` | 1 cairn | 1,00 |
| S | `(0,60, 12,60)` | 2 slabs | 0,92 |
| O | `(-12,75, -0,40)` | 1 cairn | 0,86 |

| contrainte | exigee | mesuree |
|---|---|---|
| `\|x\|`, `\|z\|` | <= 14,2 | **13,96** (max sur TOUTES les entrees neuves) |
| landmark -> centre de portail | >= 3,0 | **5,400** |
| landmark -> prop existant | >= 2,0 | **2,980** |

Avec trois silhouettes pour quatre azimuts, **aucun landmark n'est
identique a un voisin** : la seule paire repetee est les deux cairns, et
ils sont E et O, donc diametralement opposes -- ~25 unites d'ecart, jamais
vus ensemble dans un cadre, et differant encore par l'echelle (1,00 contre
0,86) et la rotation. C'est
pour ca que trois variantes ont ete ecrites plutot que les deux minimum
demandees : avec deux, une paire adjacente aurait ete identique.

### La couronne 10,4 -> 14,2 : 34 props, DELIBEREMENT plus clairsemee

| type | ajoutes |
|---|---|
| flower | 10 (3 grappes + une) |
| bush | 8 (3 grappes) |
| tree | 8 |
| rock | 8 |

Grappes de 3 a 5 pour `bush`/`flower`, `scale` **0,62 a 1,36**,
`rotation_y` libre sur 360 deg -- jamais un semis regulier, doctrine du
lot A.

**Densite degressive, mesuree** : le coeur porte **50 props sur 432 u2**
(11,6 pour 100 u2), la couronne **34 sur 374 u2** (**9,1 pour 100 u2**),
soit **1,27x plus clairsemee**. Un plateau uniformement dense supprime
toute lisibilite de direction, ce qui detruirait l'utilite meme des
landmarks que ce lot ajoute.

Separations mesurees sur le jeu complet : couronne -> prop existant
**1,866**, couronne -> landmark **2,728**, couronne -> couronne **0,805**
(les membres d'une meme grappe, volontairement proches -- le lot A a des
paires a 0,555, c'est la meme lecture).

⚠️ **Le garde-fou de bornes n'a PAS declenche** : le boot headless de
`HubWorld.tscn` ne produit **aucun** `push_warning` « outside the +-15.0
plateau ». C'est la confirmation A L'EXECUTION que les 91 entrees sont
atteignables, et pas seulement le resultat du script de placement.

### COUT : 169 MeshInstance3D construites par HubBuilder -- AU-DESSUS DU SEUIL

Compte reel, mesure par une sonde jetable qui parcourt le sous-arbre `Props`
de la scene livree : **175 au total, dont 6 appartiennent aux trois
`HubPortal.tscn`** (2 chacun, mesure et pas deduit). **HubBuilder en
construit donc 169**, contre 92 au lot A.

| source | meshes |
|---|---|
| lot A (14 tree, 8 rock, 13 bush, 15 flower) | 92 |
| 4 landmarks (spire 4 + cairn 5 + slabs 3 + cairn 5) | **17** |
| couronne (8 tree, 8 rock, 8 bush, 10 flower) | **60** |
| **total HubBuilder** | **169** |

⚠️ **169 DEPASSE le seuil de 160, et c'est signale comme le brief le
demande : le refactor `MultiMeshInstance3D` devient a ARBITRER.** Non fait
ici, deliberement -- ce lot n'a aucune mesure de perf sur device pour dire
qu'il est necessaire, et le faire en meme temps que l'extension rendrait
toute regression future ambigue. Ce que l'arbitrage aurait a peser : les
props sont statiques, unshaded et low-poly, donc parfaitement eligibles ;
mais un `MultiMesh` par type retirerait la rotation et l'echelle
par-instance de leur forme actuelle et demanderait de re-cabler le
garde-fou de bornes, qui inspecte des noeuds.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** --
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0**, **24 `.scn`** (import complet verifie, pas suppose --
le piege du faux-rouge par import tronque est controle). Boot headless de
`HubWorld.tscn` **exit 0**, aucune erreur de parse, aucun `push_warning`.
Export Web release **exit 0**, **0 erreur**.

`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** ; `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 821 280 (export unique et propre, `build/` supprime avant -- a lire avec
la mise en garde permanente sur son instabilite, jamais offert comme
preuve). **Piege payload tenu** : **0** ligne `Storing File` pour
`assets_source`, `scripts/dev`, `docs`, `web` ou `build`.

**Sondes rejouees, toutes exit 0** : `ProbeTimeoutAudit` (**37 sondes
scenes**, retour exact a la baseline apres suppression des sondes
jetables), `AssetContractAudit` (**12/12 visuels, 0/10 colliders
deplaces**), `DeathModelAudit`, `ChargerShapeProbe`.
**Non-applicabilite VERIFIEE par grep, pas supposee** : aucune sonde de
`scripts/dev/` ne reference `HubWorld`, `HubBuilder`, `HubTapInput` ni
`hub_layout` -- elles ne peuvent pas voir ce lot, elles peuvent seulement
attester qu'il n'a rien casse ailleurs.

### Reste ouvert -- jugement device, seul juge

1. **Un plateau de 30x30 se traverse-t-il encore agreablement ?**
   `HOP_DISTANCE` reste a 1,5, donc aller d'un bord a l'autre coute
   desormais ~20 bonds la ou il en coutait ~15. Mesure, assume, et c'est le
   risque principal du lot : rien ne dit que la traversee ne devient pas
   fastidieuse.
2. **Les landmarks se lisent-ils comme des reperes** a 28 unites sous 36 %
   de fog, sur un vrai telephone ? La geometrie et le contraste sont
   mesures ; la lisibilite ne l'est pas.
3. **Les trois silhouettes sont-elles reellement distinguables** a cette
   distance, ou se reduisent-elles a « trois taches claires » ?
4. **169 MeshInstance3D** -- au-dessus du seuil, `MultiMeshInstance3D` a
   arbitrer (section ci-dessus).

### Deploiement staging (palier 1, automatique)

`staging` **`8fe6c5e`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `2ff97fa9` des deux cotes, verifie AVANT
le push). CI run **#211** (id `32813373828`), demarre 05:34:33 UTC.
**`main` NON touche** (`origin/main` toujours `33f7aa4`) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
`CACHE_VERSION` de `index.service.worker.js` de `keepy-staging.vercel.app` :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #209, lot A) | `1787611489` | 24 aout **22:44:49** |
| **apres (ce lot, run #211)** | **`1787636255`** | 25 aout **05:37:35** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #211**, avec
`x-vercel-cache: MISS` et `age: 0`. Le « avant » a ete relu **pendant que
le job tournait** (05:36:43, toujours l'ancienne valeur) : le job avancait
donc REELLEMENT au lieu d'etre un cache perime, et la bascule est prouvee
dans les deux sens.

⚠️ **Le commit de doc est pousse APRES la fin du run #211, deliberement** :
`web-build.yml` porte `cancel-in-progress: true`, donc pousser code puis doc
coup sur coup annule le premier run -- exactement le piege consigne au
lot A, ou le run #207 apparait `cancelled` sans etre un echec.

## HUB : LE PLATEAU PASSE DE 15 A 25, QUATRE LANDMARKS DE PLUS, ET UNE COURONNE EXTERIEURE VOLONTAIREMENT MAIGRE (25 aout 2026)

Branche `claude/plateau-extension-visibility-2rtora`, partie de `staging`
(`3061637`). **Lot purement VISUEL et de zone jouable** : `HubCamera.OFFSET`,
`FOLLOW_LAMBDA`, `fov`, la rotation de camera et `KeepyHopper.HOP_DISTANCE`
sont **INTOUCHES**, verifie par `git diff` -- `HubCamera.gd`, `KeepyHopper.gd`
et `HubWorld.tscn` ne sont pas dans le diff du tout. **DEUX fichiers touches,
UNE seule ligne de code** : `git diff --stat origin/staging` rend
`hub_layout.tres` (+279) et `HubTapInput.gd` (+27/-8, dont **une** ligne non
commentaire : la constante).

⚠️ **Ecart de ref au demarrage, benin et signale plutot que passe sous
silence** : le brief annoncait `origin/staging = 8fe6c5e`, la mesure donne
**`3061637`**. `8fe6c5e` EST bien le merge du lot B et il est ancetre de
`origin/staging` ; les deux commits d'ecart sont **doc seule**
(`git diff --stat 8fe6c5e origin/staging` = `CLAUDE.md` uniquement). Parti de
`3061637`. `origin/main` (`33f7aa4`) est strictement en retard, le lot B n'est
donc toujours pas en prod, conforme au brief.

### R1 -- UN TAP ACHETE TOUT LE VOYAGE : c'est une CHAINE, pas un bond

C'etait la question decisive du lot, et la reponse est dans deux lignes du
code livre. `KeepyHopper.hop_to()` ne fait que **poser une destination** :

```gdscript
func hop_to(point: Vector3) -> void:
	_target = Vector3(point.x, 0.0, point.z)
	_has_target = true
	if not _hopping:
		_advance()
```

et `_on_hop_finished()` **se rappelle lui-meme** a chaque atterrissage :

```gdscript
	hop_landed.emit(global_position)
	_advance()          # <- la chaine
```

`_advance()` ne s'arrete que quand `delta.length() <= ARRIVE_EPSILON` (0,45).
`HubTapInput._handle_point` emet **un** `tapped_ground` par tap, et
`HubWorld._on_tapped_ground` appelle **un** `hop_to`. Donc : **un tap, une
destination, autant de bonds qu'il faut, automatiquement.**

**Mesure sur le hopper LIVRE, a `--fixed-fps 60`, pas un calcul** (sonde
jetable, supprimee avant commit) :

| trajet | distance | bonds | frames | secondes |
|---|---|---|---|---|
| **(0,0) -> (25,0)** *(la mesure que le brief nomme)* | 25,0 u | **17** | 357 | **5,95 s** |
| (0,0) -> (0,-25) | 25,0 u | 17 | 357 | 5,95 s |
| (0,0) -> (25,25) | 35,4 u | 24 | 504 | 8,40 s |
| **(-25,-25) -> (25,25)** *(diagonale complete)* | 70,7 u | **47** | 987 | **16,45 s** |

`HOP_DURATION = 0,35 s`, `HOP_DISTANCE = 1,5`, `ARRIVE_EPSILON = 0,45`.

**SEUIL D'ARBITRAGE : PASSE.** La mesure que le brief designe explicitement --
centre `(0,0)` vers le bord `(25,0)` -- coute **5,95 s** et, selon l'axe,
**1 a 6 taps**. Les deux plafonds (12 s, 15 taps) sont tenus avec une large
marge, donc **pas de STOP** et aucune option chiffree a arbitrer pour ce
trajet-la.

⚠️ **MAIS le pire cas depasse, et il est publie tel quel plutot qu'enjolive :
la diagonale complete (-25,-25) -> (25,25) coute 16,45 s**, au-dessus des
12 s. Un bord a bord droit (50 u) coute 11,90 s, juste dessous. Rien n'a ete
tranche la-dessus -- **decision de Mathieu**, et les leviers sont chiffres :
porter `HOP_DISTANCE` de 1,5 a 2,0 ramenerait la diagonale a **12,60 s** et a
2,5 a **10,15 s** ; raccourcir `HOP_DURATION` de 0,35 a 0,28 la ramenerait a
**13,16 s**. **Aucun des deux n'est fait ici** : le brief les met hors
perimetre, et les deux changent le FEEL d'un mouvement valide sur device.

⚠️ **LE VRAI COUT DE L'ELARGISSEMENT N'EST PAS LE NOMBRE DE BONDS, C'EST
L'ASYMETRIE DE VISEE -- mesure, et ce n'etait pas dans le brief.** La camera
garde un fov **HORIZONTAL** de 45 deg (`keep_aspect = KEEP_WIDTH`), donc :

| direction | portee d'UN SEUL tap | taps pour 25 u |
|---|---|---|
| vers l'AVANT (-Z) | **tout le plateau** (le bord est dans le frustum) | **1** |
| de COTE (+X) | **4,82 u** | **6** |

Identique a 1080x1920 et 1170x2532 (le `KEEP_WIDTH` ne change que la vfov).
Un joueur qui va tout droit paie un tap ; un joueur qui longe le bord en paie
six. **C'est ca qui se degradera si le plateau s'elargit encore**, pas la
duree.

⚠️ **Pas de falaise de precision au bord** : le tap qui demande 25 u devant
tombe a **y = 450 px sur 1920**, tres loin de la ligne d'horizon a **81 px**.
Viser loin ne demande donc pas de viser un pixel.

### R2 -- aucun bord de sol, et le landmark a 22 u n'est pas efface

Banc camera-figee du lot B repris tel quel (`_process` de `HubCamera` coupe,
`SubViewportContainer.stretch` desactive -- sans les deux la camera lerpe
pendant la mesure et les coins ne sortent plus symetriques), aux deux ratios,
Keepy pose au NOUVEAU coin :

| viewport | keepy | haut du cadre | sol le plus lointain atteint |
|---|---|---|---|
| 1080x1920 | (0,0) | **+2,37 deg -> CIEL** | `max\|axe\|` 22,1 |
| 1080x1920 | (25,25) | +2,37 deg -> CIEL | 37,4 |
| 1080x1920 | (0,-25) / (-25,-25) | +2,37 deg -> CIEL | 47,1 |
| 1170x2532 | (0,0) | **+7,87 deg -> CIEL** | 34,8 |
| 1170x2532 | (25,25) | +7,87 deg -> CIEL | 41,8 |
| 1170x2532 | (0,-25) / (-25,-25) | +7,87 deg -> CIEL | **59,8** |

Les `+2,37` et `+7,87` **reproduisent au centieme** ceux deja consignes pour
ce hub, ce qui valide le banc avant qu'on lui fasse confiance. Le pire rayon
atteint **59,8** contre les **+-300** du `PlaneMesh` 600x600 : **facteur 5 de
marge**, le bord est hors de portee. Et la jonction sol/ciel reste invisible
**par construction** -- `fog_light_color == background_color`, verifie a
l'execution (`identical=true`), pas lu dans la scene.

⚠️ **Ce n'est toujours PAS un cas de cadrage nouveau** : la camera suit Keepy
en x/z, donc la vue depuis le bord a exactement la meme FORME que depuis le
centre ; seul le monde sous elle change. Elargir le plateau ne peut
structurellement pas ouvrir un bord.

**Fog, lu sur l'`Environment` reel** : `fog_mode = 0` (EXPONENTIEL),
`fog_height_density = 0`, `fog_density = 0,016`, donc
`occlusion = 1 - exp(-d * 0,016)` :

| distance | 10 u | 20 u | 30 u | 34 u | 43,3 u | 70 u | 144 u | 275 u |
|---|---|---|---|---|---|---|---|---|
| occlusion | 14,8 % | 27,4 % | 38,1 % | 42,0 % | **50 %** | 67,4 % | 90 % | 98,8 % |

Les quatre landmarks neufs (rayon 20,9 a 22,1) mesures sur la scene
construite : **36,6 a 37,0 % de fog vus depuis le centre** -- donc ils gardent
~63 % de leur propre couleur, **la meme marge que les 36,1 % du lot B**. Vus
depuis le point diametralement oppose ils montent a 44,3-55,3 %, mais a cette
distance c'est le landmark de mi-parcours (rayon 12,6) qui sert de repere
proche. **La condition de blocage du brief (« si le fog efface au-dela de
~25 unites ») ne se declenche pas**, et `hub_fog_density` n'a pas ete touche.

### R3 -- LE PLAFOND DE 260 EST LA CONTRAINTE QUI MORD, et de tres loin

Projection faite AVANT de placer quoi que ce soit, sur les densites reelles
mesurees (aire en CARRES, la metrique du clamp per-axe, et les densites
comptent les props ordinaires -- ni portails ni landmarks, convention du
lot B, reproduite ici a l'identique : coeur 11,56 et couronne B 9,09) :

| scenario pour la couronne 14,2 -> 24 (1 497 u2) | props | meshes ajoutees | **total** |
|---|---|---|---|
| a la densite du COEUR (11,56/100u2) | 173 | +313 | **482** |
| a la MOITIE de la couronne B (4,55/100u2) | 68 | +138 | **307** |
| **livre** | **51** | **+90** | **259** |

**Les deux scenarios du brief creveraient le plafond**, le second inclus.
Conformement a la consigne (« REDUIRE le nombre de props plutot que de
depasser »), c'est la densite qui a cede.

### Ce qui est livre

`PLATEAU_HALF_EXTENT` **15,0 -> 25,0**. La constante a toujours **exactement
trois lecteurs** (sa declaration, les deux `clampf` de `_handle_point`, la
lecture de `HubBuilder` pour son avertissement de bornes) -- **verifie par
grep, aucune valeur `15.0` dupliquee** dans `scripts/hub/`, `scenes/Hub*.tscn`
ni `resources/hub/`. Le garde-fou suit donc automatiquement, et **le boot
headless de `HubWorld.tscn` ne produit AUCUN `push_warning`** : la
confirmation A L'EXECUTION que les 146 entrees sont atteignables.

**Quatre landmarks de plus, rayon 20,9 a 22,1, azimuts 47 / 133 / 227,5 /
313** -- intercales entre les quatre du lot B (N/E/S/O, rayon ~12,6, **non
deplaces**, ils deviennent des reperes de mi-parcours). Aucun nouveau type,
les trois silhouettes existantes sont reutilisees.

⚠️ **Le choix de silhouette n'est PAS arbitraire, il est FORCE.** Avec trois
silhouettes et deux voisins par insertion, chaque variante est la seule qui
differe des deux cotes -- et le resultat laisse **aucune paire adjacente
identique sur les huit positions** :

| azimut | 0 | **47** | 92,5 | **133** | 177,3 | **227,5** | 271,8 | **313** |
|---|---|---|---|---|---|---|---|---|
| silhouette | spire | **slabs** | cairn | **spire** | slabs | **spire** | cairn | **slabs** |
| rayon | 12,60 | **21,40** | 12,71 | **22,10** | 12,61 | **20,90** | 12,76 | **21,80** |

**Couronne C : 51 props sur 1 497 u2.** Densites mesurees des trois zones,
avec la convention du lot B :

| zone | props | aire | **props / 100 u2** | vs couronne B |
|---|---|---|---|---|
| coeur, cheb <= 10,4 | 50 | 432,6 | **11,56** | -- |
| couronne B, 10,4 < cheb <= 14,2 | 34 | 373,9 | **9,09** | reference |
| **couronne C, 14,2 < cheb <= 24** | **51** | 1 497,4 | **3,41** | **2,67x plus clairsemee** |

⚠️ **La cible etait 2x plus clairsemee (4,55), le livre est a 2,67x -- ecart
assume et dit franchement.** Le plafond de 260 est ce qui l'impose : a
4,55/100u2 il faudrait 68 props pour 77 meshes disponibles, soit 1,13 mesh
par prop, c'est-a-dire **une couronne entierement en rochers**. L'ecart va
d'ailleurs dans le sens de l'objectif de design du brief (« que s'eloigner du
centre se RESSENTE comme s'eloigner ») : il rend l'exterieur plus vide, pas
moins.

⚠️ **AUCUNE fleur dans la couronne C, et c'est un choix, pas un oubli.** Une
corolle de 0,15 de rayon sur une tige de 0,42 fait quelques pixels a 20+
unites sous 40 % de fog : elle depenserait **deux meshes pour rien**. Le mix
livre privilegie ce qui se lit de loin et ce qui coute peu : **17 arbres**
(2 meshes, la silhouette la plus lisible a distance), **26 rochers**
(1 mesh, le corps le moins cher), **8 buissons** (2 meshes). Grappes plutot
que semis regulier, `scale` **0,64 a 1,38**, `rotation_y` libre sur 360 deg.

**Separations mesurees sur le jeu complet** : neuf -> prop existant **2,234**,
neuf -> landmark du lot B **4,042**, neuf -> landmark neuf **3,484**,
neuf -> portail **10,417**, neuf -> neuf **0,763** (membres d'une meme
grappe, volontairement proches -- meme lecture qu'aux lots A et B).
`max |x| = 23,95`, `max |z| = 23,88`, sous le plafond de 24,2.

### COUT : 259 MeshInstance3D, sous le plafond dur de 260

Compte **reel**, mesure par une sonde jetable qui parcourt le sous-arbre
`Props` de la scene livree, pas deduit du layout :

| source | meshes |
|---|---|
| Props, sous-arbre complet | 265 |
| dont appartenant aux trois `HubPortal.tscn` | 6 |
| **construites par HubBuilder** | **259** *(plafond 260)* |

Detail : 169 (lot B) + 14 (les 4 landmarks neufs : slabs 3 + spire 4 +
spire 4 + slabs 3) + 76 (couronne C : 17x2 + 26x1 + 8x2).

⚠️ **`MultiMeshInstance3D` toujours PAS fait, et l'arbitrage reste ouvert
depuis le lot B.** Le brief l'interdit explicitement dans ce lot. Ce qu'il
faudra peser le jour venu, inchange : les props sont statiques, unshaded et
low-poly donc parfaitement eligibles, mais un `MultiMesh` par type retirerait
la rotation et l'echelle par-instance et demanderait de recabler le garde-fou
de bornes, qui inspecte des noeuds. **Le prochain lot qui veut densifier
devra le faire d'abord** : il ne reste qu'une mesh de marge.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** --
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0**, **24 `.scn`** (import complet verifie, pas suppose --
le piege du faux-rouge par import tronque est controle). Boot headless de
`HubWorld.tscn` **exit 0**, aucune erreur de parse, **aucun `push_warning`**.
Export Web release **exit 0**, **0 erreur**.

`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** ; `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur, coherent avec un
diff d'une constante et d'un fichier de donnees. `index.pck` 5 828 208
(export unique et propre, `build/` supprime avant -- a lire avec la mise en
garde permanente sur son instabilite, jamais offert comme preuve). **Piege
payload tenu** : **0** ligne `Storing File` pour `assets_source`,
`scripts/dev`, `docs`, `web` ou `build`, sur 219 lignes.

**Sondes rejouees, toutes exit 0** : `ProbeTimeoutAudit` (**37 sondes
scenes**, retour exact a la baseline apres suppression de la sonde jetable),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`. **Non-applicabilite VERIFIEE par
grep, pas supposee** : aucune sonde de `scripts/dev/` ne reference
`HubWorld`, `HubBuilder`, `HubTapInput`, `HubCamera`, `KeepyHopper`,
`HubPortal`, `HubLayout` ni `hub_layout` -- elles ne peuvent pas voir ce lot,
elles peuvent seulement attester qu'il n'a rien casse ailleurs.

⚠️ **Piege de sonde rencontre, a connaitre** : une fonction de phase qui
contient un `await` est une COROUTINE, et l'appeler sans `await` la fait
tourner EN PARALLELE de la suite. La premiere version du banc a mesure R2 et
R1 en meme temps, et R1 deplacait la camera que R2 lisait -- les trois
positions de test ont rendu le meme chiffre, ce qui avait l'air d'un resultat
et n'en etait pas. Corrige en `await _phase_r2()`.

### Deploiement staging (palier 1, automatique)

`staging` **`f43c898`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `13bb8e01` des deux cotes, verifie AVANT
le push). CI run **#213** (id `32819621857`) **verte** (07:01:54 -> 07:05:00
UTC) -- `Deploy to Vercel [STAGING -- staging]` **succes**,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche.**

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** --
`CACHE_VERSION` de `index.service.worker.js` de `keepy-staging.vercel.app`,
lu avant le merge puis apres :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #212, lot B docs) | `1787636616` | **05:43:36** |
| **apres (ce lot, run #213)** | **`1787641474`** | **07:04:34** |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build`** du run
#213 (07:04:30 -> 07:04:35), avec `x-vercel-cache: MISS` et `age: 0` sur les
deux lectures. L'alias sert bien ce build.

⚠️ **Le commit de doc est pousse APRES la fin du run de code** (07:05:00),
pour ne pas annuler ce run -- `web-build.yml` porte `cancel-in-progress:
true`, piege deja paye au lot A.

### Reste ouvert -- jugement device, seul juge

1. **La diagonale a 16,45 s depasse le seuil de 12 s.** Mesuree, publiee,
   **non tranchee** : les leviers (`HOP_DISTANCE` 2,0 -> 12,60 s, 2,5 ->
   10,15 s ; `HOP_DURATION` 0,28 -> 13,16 s) sont chiffres et attendent la
   decision de Mathieu. Le trajet que le brief nomme, lui, passe largement.
2. **Six taps pour 25 unites de COTE contre un seul vers l'avant.** C'est le
   vrai cout de l'elargissement, et aucune sonde ne dit si ca se sent comme
   une camera qui suit ou comme un jeu qui resiste.
3. **Un plateau de 50x50 se lit-il encore comme un lieu, ou comme un desert ?**
   La couronne C est a 3,41 props/100u2, un tiers de la densite du coeur --
   c'est l'intention, mais rien ne dit qu'elle ne bascule pas en vide.
4. **Les landmarks a 21-22 u se lisent-ils comme des reperes** sous 37 % de
   fog, et les trois silhouettes restent-elles distinguables a cette distance
   ou se reduisent-elles a « des taches claires » ? Question deja ouverte au
   lot B, posee ici a une distance 1,7x plus grande.
5. **259 MeshInstance3D, une de marge.** Le refactor `MultiMeshInstance3D`
   n'est plus reportable si un lot futur veut densifier.

## HUB : LE DECOR PASSE EN MultiMeshInstance3D -- PHASE 0, la recon et la baseline (25 aout 2026)

Branche `claude/hub-decor-refactor-props-jxfu6a`, partie de `main`
(`77548dc`). Le lot C (plateau 25) est **deja en prod** : `main..staging`
est VIDE et `main` porte le merge en plus, donc `origin/main` est la ref la
plus a jour du depot. Aucune session concurrente (les refs les plus recentes
sont toutes cette chaine de lots).

Le lot precedent se termine sur « **259 MeshInstance3D, une de marge** ». Ce
lot ouvre le budget avant d'ajouter quoi que ce soit, et cette section
consigne la mesure d'AVANT -- elle est ecrite avant que la moindre ligne de
`HubBuilder.gd` ne bouge, pour qu'il n'y ait pas a la reconstituer apres coup.

### BASELINE MESUREE, sur la scene livree et pas deduite du layout

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles confirmees contre le `Content-Length`** --
50 276 070 et 1 073 228 327 octets, aucune troncature). Import headless
**exit 0**, **24 `.scn`**, 0 erreur. Sonde jetable qui instancie
`HubWorld.tscn` cinq fois et compte le sous-arbre `Props` :

| mesure | valeur |
|---|---|
| `MeshInstance3D` dans `Props` (total) | **265** |
| dont a l'interieur des 3 `HubPortal.tscn` | 6 |
| **construites par `HubBuilder`** | **259** |
| `MultiMeshInstance3D` | **0** |
| `instantiate()` + `_ready()` (5 passes) | **moyenne 19,8 ms** (min 13,3 / max 42,8) |

Le 259 **reproduit au noeud pres** le chiffre publie par le lot C, ce qui
valide la sonde avant qu'on lui fasse confiance sur l'apres. Detail par type,
recompte sur le `.tres` (146 entrees) :

| type | entrees | meshes / entree | total |
|---|---|---|---|
| tree | 39 | 2 (fut + houppier) | 78 |
| rock | 42 | 1 | 42 |
| bush | 29 | 2 (une seule mesh, deux offsets) | 58 |
| flower | 25 | 2 (tige + corolle) | 50 |
| landmark | 8 | 4 / 5 / 3 selon la silhouette | 31 |
| **HubBuilder** | **143** | | **259** |
| portal | 3 | 2 (dans `HubPortal.tscn`) | 6 |

⚠️ **Pas de proxy FPS.** Ce sandbox rend en llvmpipe sous xvfb ; un chiffre
d'images par seconde mesure la ferme de CPU, pas le telephone. Ce qui est
mesure a la place est ce qui est reellement comparable d'un arbre a l'autre :
le nombre de noeuds de dessin et le cout de construction de l'ecran.

### ⚠️ LE NOMBRE DE MULTIMESH N'EST PAS LE NOMBRE DE TYPES -- il est de HUIT

L'unite de batch est la paire **(mesh, couleur)**, et elle ne coincide avec
aucun type semantique :

| batch | mesh | instances |
|---|---|---|
| `TreeTrunk` | `CylinderMesh` 0,16/0,24 x 1,5 | 39 |
| `TreeCrown` | `SphereMesh` r 0,95 h 1,7 | 39 |
| `Rock` | `SphereMesh` r 0,6 h 0,8 | 42 |
| `Bush` | `SphereMesh` r 0,5 h 0,7 | **58** *(2 lobes par buisson, MEME mesh)* |
| `FlowerStem` | `CylinderMesh` 0,025/0,035 x 0,42 | 25 |
| `FlowerPetal0/1/2` | `SphereMesh` r 0,15 h 0,14 | 8 / 8 / 9 |

Trois faits que seule la lecture du code donne : **un arbre alimente DEUX
batches** (fut et houppier sont deux meshes) ; **un buisson alimente DEUX
INSTANCES d'un seul batch** (ses deux lobes partagent la meme `SphereMesh` a
deux offsets, `_make_bush` reutilise litteralement la variable) ; et **la
corolle se scinde en TROIS** parce que ses trois teintes sont trois dessins
differents. Les trois `SphereMesh` d'arbre/rocher/buisson ont des rayons et
des tessellations differents : ce sont bien trois meshes, pas une.

### AUCUNE COLLISION N'EST PERDUE -- verifie par grep, pas suppose

`grep -rn "CollisionShape3D\|StaticBody3D\|Area3D\|RigidBody3D\|CharacterBody3D"`
sur `scripts/hub/` et les scenes du hub ne rend que **`HubPortal`** (un
`Area3D` avec son `Shape`). `tree` / `rock` / `bush` / `flower` sont des
`Node3D` + `MeshInstance3D`, rien d'autre. Le sol n'est pas un collider non
plus : `HubTapInput` intersecte un `Plane` mathematique plutot que de lancer
un raycast, et son propre commentaire dit pourquoi. **Le passage en MultiMesh
ne peut donc rien coster en collision**, et les portails -- les seuls noeuds
qui en ont une, et les seuls auxquels `HubWorld` connecte un signal --
restent des noeuds individuels.

### ⚠️ LA DOC ETAIT FAUSSE SUR LE GARDE-FOU DE BORNES

Le lot C ecrit qu'un refactor MultiMesh « demanderait de re-cabler le
garde-fou de bornes, **qui inspecte des noeuds** ». **C'est faux, et c'est le
code qui le dit** : le garde-fou vit dans `HubBuilder._build()` et lit
`entry.get("position")` **dans le dictionnaire du layout**, avant meme que le
noeud n'existe --

```gdscript
var where: Vector3 = entry.get("position", Vector3.ZERO)
var bound: float = HubTapInput.PLATEAU_HALF_EXTENT
if absf(where.x) > bound or absf(where.z) > bound:
    push_warning(...)
```

Il est donc **pilote par la DONNEE et pas par l'arbre de scene**, et un prop
batche le franchit exactement comme un prop-noeud. **Rien a recabler.** Le
seul soin a prendre est de garder l'ORDRE des messages : le garde-fou tire
apres que le type a ete reconnu, donc un type inconnu produit un
`push_error` et **aucun** avertissement de bornes -- une inversion changerait
stderr sans changer le jeu.

### Ce que la phase 0 laisse comme decisions, prises et non subies

* **Couleur par instance ecartee.** `MultiMesh.use_colors` +
  `vertex_color_use_as_albedo` fondrait `FlowerPetal0/1/2` en un seul noeud.
  Non retenu : ca ferait diverger le materiau livre de celui que ce fichier
  construisait, sur un lot que personne ne peut regarder avant staging, pour
  economiser deux noeuds sur un budget que ce lot vide de toute facon. Trois
  noeuds portant le materiau exact d'avant, c'est la version dont la parite
  se PROUVE.
* **`custom_aabb` pose explicitement.** `MultiMesh.custom_aabb` existe bien
  en 4.3 (verifie a l'execution, pas lu de memoire). Une AABB fausse ou
  perimee fait disparaitre tout un batch quand la camera tourne, **sans
  aucune erreur attachee** -- l'union exacte est bon marche a calculer ici,
  donc elle est ecrite plutot que laissee au calcul implicite.

### PHASE 1 -- le decor passe en MultiMesh : 259 -> 39 noeuds de dessin, a PARITE STRICTE

`tree` / `rock` / `bush` / `flower` sont desormais accumules dans **un
`MultiMeshInstance3D` par paire (mesh, couleur)**, remplis en seconde passe
une fois toutes les entrees lues. `portal` et `landmark` restent des noeuds
individuels : le premier est un `Area3D` auquel `HubWorld` connecte un
signal (un MultiMesh n'a aucun noeud par instance a connecter), le second
echangerait 31 noeuds contre ~12 en perdant la lisibilite par variante.

| | avant | apres |
|---|---|---|
| `MeshInstance3D` construites par `HubBuilder` | **259** | **31** *(les 8 landmarks seuls)* |
| `MultiMeshInstance3D` | 0 | **8** |
| instances dessinees par MultiMesh | 0 | **228** |
| **noeuds de dessin, total** | **259** | **39** |
| `instantiate()` + `_ready()`, MEME renderer | **40,0 ms** | **29,5 ms** *(-26 %)* |

⚠️ **Les 19,8 ms de la baseline headless et ces 40,0 ms sont le MEME arbre**
-- la baseline avait ete prise en `--headless` (driver DUMMY) et l'apres sous
`xvfb` + `opengl3`. Les deux chiffres du tableau sont donc **remesures des
deux cotes sous le meme renderer** plutot que compares a travers deux
drivers. Ne jamais comparer un temps de build headless a un temps xvfb.

### La parite est PROUVEE instance par instance, pas deduite du compte

Un compte de noeuds qui baisse est facile a obtenir en dessinant la mauvaise
chose. Sonde jetable (supprimee avant le commit -- `ProbeTimeoutAudit`
revient a **37 sondes**) qui reconstruit, pour **chacune des 135 entrees
scatter**, le placement d'AVANT avec un vrai `Node3D` + enfant, lit le
`global_transform` de cet enfant, et exige que l'instance batchee le
reproduise :

| assertion | resultat |
|---|---|
| le placement compose == ce qu'un `Node3D` vivant donne (135 props) | **OK**, ecart pire **6,7e-7** |
| chaque batch a exactement les instances de son type | **OK** (39/39/42/58/25/8/8/9) |
| aucun noeud de batch en trop | **OK** (8 construits, 8 attendus) |
| **chaque instance est exactement ou son ancien noeud etait** | **OK**, ecart pire **0,000000000** |
| chaque batch porte un `StandardMaterial3D` UNSHADED | **OK** |
| le `custom_aabb` de chaque batch enclot toutes ses instances | **OK** |
| les couleurs de batch == les constantes remplacees | **OK** |

Le calcul de placement est **exact et pas approche** : `Transform3D(
Basis.from_euler(y).scaled(uniform), where)` est ce que `Node3D` compose,
**parce que le `scale` du layout est un flottant UNIFORME** -- rotation et
echelle uniforme commutent, donc l'ambiguite « de quel cote Godot applique
l'echelle » disparait. Ce n'est pas argumente, c'est asserte contre un vrai
noeud.

### ⚠️ DEUX PIEGES MESURES, dont un qui aurait dessine TOUT LE DECOR A L'ORIGINE

1. **`MultiMesh.transform_format` vaut `TRANSFORM_2D` (0) PAR DEFAUT en
   Godot 4.3, PAS `TRANSFORM_3D`.** Mesure sur quatre ordres d'ecriture :
   seul `transform_format` -> `mesh` -> `instance_count` rend
   `get_instance_transform(0) = (1,2,3)` ; les trois autres rendent
   `(0,0,0)` avec `fmt=0`. Un `MultiMesh` laisse au defaut **jette toutes
   les transforms qu'on lui ecrit et dessine le batch entier a l'origine** --
   c'est-a-dire un plateau ou tout le decor est empile sous les pieds de
   Keepy. `HubBuilder` pose donc `transform_format` en PREMIERE ligne, et
   le commentaire dit pourquoi.
2. **`--headless` ne peut PAS lire une instance de MultiMesh.** Le driver
   DUMMY n'en conserve rien : la sonde de parite a d'abord rapporte un
   ecart de **33,7** avec des transforms toutes a l'identite, sur un code
   qui etait juste. Ce qui l'a prouve : le `custom_aabb`, calcule dans la
   MEME boucle a partir des memes transforms, sortait CORRECT (bornes
   `-19,18..24,55`) -- donc les valeurs etaient bonnes a l'ecriture et
   perdues a la relecture. Rejouee sous `xvfb-run --rendering-driver
   opengl3` : **0 echec, ecart 0,000000000**. Meme famille que le piege
   `--headless` deja consigne pour les sondes a pixels, sur un autre
   sous-systeme. **Toute sonde qui lit un MultiMesh doit tourner sous
   xvfb.**

### Deux choix pris et non subis

* **Couleur par instance ECARTEE.** `MultiMesh.use_colors` +
  `vertex_color_use_as_albedo` fondrait `FlowerPetal0/1/2` en un seul
  noeud. Non retenu : ca ferait diverger le materiau livre de celui que ce
  fichier construisait, **sur un lot que personne ne peut regarder avant
  staging**, pour economiser deux noeuds sur un budget que ce lot vide de
  toute facon. Trois noeuds portant le materiau exact d'avant, c'est la
  version dont la parite se PROUVE.
* **`custom_aabb` ecrit explicitement.** L'union exacte des AABB
  d'instances est calculee dans la boucle de remplissage. Une AABB fausse
  ou perimee fait disparaitre **tout un batch** quand la camera tourne,
  **sans aucune erreur attachee** -- le pire mode de panne possible sur un
  ecran qu'on ne peut pas regarder avant staging.

### Le garde-fou de bornes n'a RIEN eu a recabler

Consequence directe du constat de phase 0 : il lit le dictionnaire du
layout, pas l'arbre de scene. Le seul soin pris est de le laisser **APRES**
le dispatch de type, pour qu'un type inconnu produise toujours une erreur et
**aucun** avertissement -- l'ordre des lignes de stderr est preserve.

## HUB : DEUX NOUVEAUX TYPES -- la souche et la mare (25 aout 2026)

Meme branche, commit distinct, depensant le budget que la phase 1 libere.

**`stump`** -- une seule `CylinderMesh` (0,34/0,44 x 0,55, 8 segments) dans
le **`TRUNK_COLOR` des arbres**, aucun nouvel asset et **aucun second
materiau** : partager la couleur d'ecorce est ce qui fait lire une souche
comme ce qu'un arbre a laisse derriere lui plutot que comme un prop sans
rapport. Pas de disque plus clair sur la face coupee -- ce serait un second
materiau pour une surface que la camera, a -34 deg et 7,6 unites de haut,
voit presque par la tranche. **14 sur le plateau**, posees a cote de
grappes d'arbres existantes et en rive de la mare.

**`pond`** -- **une seule instance**, loin dans la couronne exterieure
(**(20,70 ; 7,40)**, rayon 22,0, azimut ~110 deg), comme point de
destination. **Deux disques plats et pas un** : une berge opaque legerement
plus large (r 3,62) sous une eau alpha (r 3,20), pour que la surface
transparente ait un bord ou finir au lieu de s'arreter sur l'herbe nue.
`CylinderMesh` et non `PlaneMesh` -- un plan est simple face, et un
spectateur qui verrait cet ecran depuis sous l'horizon trouverait la mare
simplement absente.

⚠️ **`transparency` doit etre DEMANDEE.** Le canal alpha d'`albedo_color`
est **entierement ignore** tant que `transparency` reste a `DISABLED` : la
mare rendrait en turquoise plat opaque, **sans aucune erreur pour le dire**.
`BaseMaterial3D.TRANSPARENCY_ALPHA` est pose explicitement. C'est la SEULE
surface alpha du plateau.

Les hauteurs sont ce qui la sort d'un z-fight : le sol est un `PlaneMesh` a
**exactement y = 0**, le dessous de la berge est a **0,005** et celui de
l'eau a **0,02** -- ni l'un ni l'autre n'est jamais coplanaire avec lui.

**Teinte bleu-vert et pas bleue** : le sol est vert marecage et le ciel un
vert quasi noir ; un bleu sature serait la seule chose de cet ecran sans
aucun rapport avec le reste.

### Placement VERIFIE contre toutes les entrees existantes, pas a l'oeil

| contrainte | mesuree |
|---|---|
| souche -> prop existant le plus proche | **1,734** |
| souche -> souche | **3,598** |
| centre de la mare -> prop existant | **6,900** |
| rive de l'eau (r 3,2) -> souche la plus proche | **>= 3,45** *(aucun chevauchement)* |
| `max abs(x)` / `max abs(z)` sur les 161 entrees | **23,95 / 23,88** *(borne 25,0)* |

Le garde-fou de bornes reste donc **silencieux au boot** -- confirmation A
L'EXECUTION que les 161 entrees sont atteignables, et pas seulement le
resultat du script de placement.

### Les deux nouveaux types restent HORS MultiMesh, et le volume est publie

La mare est une instance unique : il n'y a rien a batcher. Les 14 souches
sont a une mesh chacune, donc les batcher economiserait **13 noeuds sur les
~220 que la phase 1 libere** -- mesure et laisse individuel jusqu'a ce que
le compte rende l'indirection payante. `HubLayout.gd` documente desormais
quels types sont batches, avec la consequence utile : ajouter cent fleurs
coute cent instances et **zero** noeud, ajouter cent souches coute cent
noeuds.

### BUDGET FINAL

| | lot C (avant) | ce lot |
|---|---|---|
| `MeshInstance3D` construites par `HubBuilder` | **259** | **47** *(31 landmarks + 14 souches + 2 mare)* |
| `MultiMeshInstance3D` | 0 | **8** |
| **noeuds de dessin, total** | **259** | **55** |
| marge sous le plafond de 260 | **1** | **205** |
| entrees de layout | 146 | **161** |
| `instantiate()` + `_ready()` (xvfb) | 40,0 ms | **28,8 ms** |

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles confirmees contre le `Content-Length`). Import
headless **exit 0**, **24 `.scn`**. Boot headless de `HubWorld.tscn`
**exit 0, 0 erreur, 0 `push_warning`**. Export Web release **exit 0**,
**0 erreur**. `index.wasm` **35 376 909 octets** / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 833 152 (export unique et propre, `build/` supprime avant -- a lire avec
la mise en garde permanente sur son instabilite). **Piege payload tenu** :
**0** ligne `Storing File` pour `assets_source`, `scripts/dev`, `docs`,
`web` ou `build`, sur 219.

Sondes : `ProbeTimeoutAudit` (**37 sondes scenes**, retour exact a la
baseline apres suppression des deux sondes jetables), `AssetContractAudit`
(**12/12 visuels, 0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe` -- **toutes exit 0**, et **byte-identiques entre l'arbre
de phase 1 et l'arbre final** sur les deux flux, ce qui dit que la phase 2
est un no-op pour elles. **Non-applicabilite VERIFIEE par grep** : aucune
sonde de `scripts/dev/` ne reference `HubWorld`, `HubBuilder`,
`HubTapInput` ni `hub_layout`. **Aucun diff contre `origin/main` n'a ete
joue pour ces quatre sondes** -- elles ne chargent aucune scene de hub, donc
il n'y avait rien a comparer ; c'est dit plutot que sous-entendu.

⚠️ **TROIS RENDUS REELS CAPTURES** (1080x1920, `xvfb-run
--rendering-driver opengl3`, sonde jetable supprimee avant commit), parce
qu'aucune validation device n'etait possible ce soir : centre du plateau,
mare, champ de souches. Les trois confirment A L'OEIL ce que les chiffres
disaient -- les trois portails et leurs labels, les arbres, les rochers,
les fleurs dans leurs **trois** teintes, les landmarks, et la mare avec sa
berge et ses cinq souches de rive. **Rien ne manque et rien n'est empile a
l'origine**, ce qui est la forme visible qu'aurait prise le piege
`transform_format` s'il n'avait pas ete ferme.

### Reste ouvert -- jugement device, seul juge

1. **Aucune mesure de performance REELLE.** Ce sandbox rend en llvmpipe :
   les 40,0 -> 28,8 ms mesurent un cout de CONSTRUCTION, pas un framerate,
   et le gain attendu du batch est au DESSIN (8 draw calls la ou il y en
   avait 228). **Rien ici ne dit que le plateau tourne mieux sur un
   telephone** -- c'est precisement ce que le test device doit repondre.
2. **La mare se lit-elle comme de l'eau** a vitesse reelle sur un ecran de
   telephone, ou comme un disque sombre ? L'alpha 0,55 et la berge sont des
   choix, pas des mesures.
3. **Est-ce qu'une souche se lit comme une souche** dans la couleur exacte
   d'un tronc, sans face coupee differenciee ?
4. **La mare est a 6 taps de cote** (azimut 110 deg) : c'est un point de
   destination lointain par conception, mais l'asymetrie de visee deja
   consignee au lot C s'applique en plein a elle.
5. **205 noeuds de marge** sous le plafond. Le prochain lot qui densifie
   n'a plus le refactor MultiMesh devant lui.

### Deploiement staging (palier 1, automatique)

`staging` **`98a7ac9`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `4a89fd38` des deux cotes, verifie AVANT
le push). CI run **#216** (id `32827408790`). **`main` NON touche**
(`origin/main` toujours `77548dc`, verifie apres le push) : palier 2, gate
Mathieu apres validation device.

**Verifie SUR LE SERVICE et DANS LES DEUX SENS** -- `CACHE_VERSION` de
`index.service.worker.js` de `keepy-staging.vercel.app` :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #214, lot C docs) | `1787641860` | **07:11:00** |
| **apres (ce lot, run #216)** | **`1787647099`** | **08:38:19** |

L'epoch d'apres tombe dans la fenetre du run #216 (demarre 08:35:27), avec
`x-vercel-cache: MISS` et `age: 0`. L'ancienne valeur a ete **relue a
08:36:18 pendant que le job tournait** (toujours `1787641860`,
`x-vercel-cache: HIT`) : le job avancait donc REELLEMENT au lieu d'etre un
cache perime, et la bascule est prouvee dans les deux sens.

## MERGE EN PRODUCTION (25 aout 2026, autorisation explicite de Mathieu) -- CLARIFICATION `stump`

`staging` (`f046c7c`) -> `main`, apres validation device (screenshot) du lot
MultiMesh. Perimetre confirme par diff avant merge :
`git diff --name-only origin/main..origin/staging` = exactement
`CLAUDE.md`, `resources/hub/hub_layout.tres`, `scripts/hub/HubBuilder.gd`,
`scripts/hub/HubLayout.gd` -- `HubTapInput.gd`, `HubCamera.gd`,
`KeepyHopper.gd`, `HubWorld.tscn` et `firestore.rules` **absents**, verifie
par grep sur ce diff plutot que suppose.

**Clarification demandee sur `&"stump"`, repondue par citation du code, pas
par supposition.** `HubBuilder.gd` place le type dans sa liste "WHAT STAYS
AN INDIVIDUAL NODE, and why" :

```
##   stump     14 on the plateau at one mesh each. Batching would save 13
##             nodes out of the ~220 this change frees; measured and left
##             individual until the count makes the indirection worth it.
```

Et `_make_stump()` porte lui-meme la raison de couleur -- qui **N'EST PAS**
celle qui l'exclut du batch :

```gdscript
## A cut trunk. Deliberately ONE mesh in the trees' own bark colour: a
## stump is what a tree leaves behind, so sharing the colour is what makes
## the pair read as a story rather than as two unrelated props.
```

**Reponse** : `stump` n'a **aucune** couleur variable par instance -- une
seule teinte fixe, `TRUNK_COLOR`, partagee avec le tronc de `tree` par
choix narratif (« la souche est ce que l'arbre laisse derriere lui »). Rien
dans ce choix de couleur n'empeche le batching -- une teinte unique est au
contraire le cas le plus simple a batcher, exactement celui deja traite
pour `rock`. **La seule raison de son exclusion est un calcul cout/benefice
sur le nombre de noeuds** : 14 instances a un seul mesh chacune ne
represente que 13 noeuds economisables sur les ~220 que ce lot libere deja
par ailleurs, et la session a juge l'indirection non rentable a ce compte
la. **Note pour la prochaine session qui voudrait densifier les souches** :
des que leur nombre depasse largement 14 (donc que le gain en noeuds
depasse la charge d'indirection), `stump` peut etre batche exactement comme
`rock` l'est deja -- meme mesh, meme couleur fixe, aucune replanification
de couleur necessaire avant de le faire.

## MESURE DE REFERENCE PERF DU HUB, avant tout ajout Meshy (25 aout 2026)

Branche `claude/hub-perf-baseline-qoo6dq`, partie de `main` (`ffcc552`).
Baseline reproductible du plateau (temps de construction, noeuds de dessin,
FPS simulee wall-clock, poids d'export) prise juste apres le refactor
MultiMesh, avant tout `.glb` Meshy sur le hub. Detail chiffre, methode
exacte et tableau de comparaisons pour chaque ajout futur :
`docs/HUB_PERF_BASELINE.md`. Sonde permanente dediee
`scripts/dev/HubPerfBaseline.gd`/`.tscn` (exclue du build comme tout
`scripts/dev/*`), n'asserte rien et sort toujours en 0 -- c'est une mesure,
pas un contrat.

## LOT E : LE BOND ACCELERE — `HOP_DURATION` 0,35 -> 0,28, RAYON ET FOULEE INCHANGES (25 aout 2026)

Branche `claude/keepy-hop-duration-tuning-t85q7q`, partie de `staging`
(**`1b9933e`**, exactement la ref annoncee par le brief — pas d'ecart de
base cette fois, contrairement aux lots C et D). Regle n°1 verifiee AU
DEBUT : `git fetch --all --prune` puis tri de toutes les refs distantes par
date — la plus recente est `claude/keepy-plateau-radius-35-3sq42r` (le lot
D, **deja merge dans `staging`**, verifie par `git merge-base
--is-ancestor` et pas suppose), **aucune session concurrente**.

**UN SEUL fichier de jeu touche, UNE SEULE ligne de code.**
`git diff --stat` contre `origin/staging` ne rapporte que
`scripts/hub/KeepyHopper.gd` (une constante + des commentaires),
`docs/HUB_PERF_BASELINE.md` et ce document. **`HubTapInput.gd`
(`PLATEAU_HALF_EXTENT` reste 25,0), `HubCamera.gd`, `HubBuilder.gd`,
`hub_layout.tres` et `HubWorld.tscn` ne sont PAS dans le diff du tout.**

### PHASE 1 — RECON : `HOP_DURATION` a EXACTEMENT UN consommateur fonctionnel

Verifie par `grep` sur tout le depot avant de toucher la constante, comme
le brief l'exigeait, et cite plutot que resume :

```gdscript
_hop_tween = create_tween()
_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)   # <- le seul
_hop_tween.finished.connect(_on_hop_finished, CONNECT_ONE_SHOT)
```

**Aucune scene, aucun autre script, AUCUNE SONDE ne lit cette constante** —
`grep "HOP_DURATION"` sur `scripts/dev/` rend **zero** occurrence, et
`grep "hop"` sur le meme dossier n'en rend aucune non plus. Les deux seules
autres references du fichier etaient deux mentions litterales « 0.35s »
**dans son propre en-tete**, reecrites pour nommer la constante au lieu de
recopier sa valeur — c'est-a-dire exactement la derive que ce lot aurait
sinon laissee derriere lui.

⚠️ **DEUX consequences reelles, MESUREES plutot que supposees — aucune des
deux n'est un couplage cache qui aurait justifie un STOP, mais les deux
sont reelles et sont dites plutot que passees sous silence :**

1. **Le recoil d'atterrissage est 0,12 s de TEMPS ABSOLU**, pas une
   fraction du bond (`recoil.tween_property(_body, "scale", _base_scale,
   0.12)`). Il passe donc de **34 % a 43 %** d'un bond. Il reste plus court
   qu'un bond, donc le squash de decollage du bond suivant l'ecrase
   toujours comme avant — mais **c'est la premiere chose a regarder si
   cette valeur descend un jour nettement plus bas.**
2. **La camera traine 24 % plus loin.** `HubCamera` suit la position AU SOL
   avec un lerp exponentiel (`FOLLOW_LAMBDA = 5.0`), donc une cible plus
   rapide est une cible plus distancee. **Mesure sur la camera livree, lerp
   VIVANT, trajet centre -> (25,0) : ecart maximal 0,893 u -> 1,110 u
   (+24,3 %)** — coherent avec les +25 % de vitesse au sol
   (`1,5 / 0,28` contre `1,5 / 0,35`). `HubCamera.gd` est **intouche** :
   c'est une consequence de la vitesse, c'est-a-dire precisement ce que le
   lot change, pas un reglage a rattraper.

### PHASE 2 — MESURE : le nombre de BONDS ne bouge pas, seules les secondes bougent

Methode des lots C et D reprise a l'identique — hopper **LIVRE** (la scene
`HubWorld.tscn` reelle, jamais un fixture), chaine de bonds reelle,
`--fixed-fps 60`, comptage des `hop_landed` ET des frames entre `hop_to()`
et `became_idle`. **Les deux trajets de reference ont ete rejoues sur
l'ANCIENNE valeur d'abord, pour valider le banc avant de lui faire
confiance sur la nouvelle** : il reproduit les chiffres publies **au bond,
a la frame et au millieme de seconde pres**.

| trajet | dist | bonds | 0,35 (frames / s) | **0,28 (frames / s)** |
|---|---|---|---|---|
| centre -> (25,0) | 25,00 u | **17** | 357 / **5,950 s** *(publie lot C/D : 17 / 5,95)* | 289 / **4,817 s** |
| (-25,-25) -> (25,25) | 70,71 u | **47** | 987 / **16,450 s** *(publie lot C/D : 47 / 16,45)* | 799 / **13,317 s** |

**Le nombre de bonds est IDENTIQUE sur les deux trajets (17 et 47).** C'est
le controle que le brief demandait, et il passe : `HOP_DISTANCE` est
intouche, donc seul le temps par bond a bouge. **Pas de STOP.** Gains :
**-1,133 s (-19,0 %)** et **-3,133 s (-19,0 %)**.

⚠️ **LA PROJECTION DU LOT D ETAIT NOMINALE, ET LA MESURE LA DEPASSE DE
0,157 s — a connaitre avant de citer un chiffre projete comme un resultat.**
Le lot D annoncait 13,16 s pour la diagonale au rayon 25, ce qui est
`47 x 0,28` — une multiplication. **La mesure donne 13,317 s**, et l'ecart
n'est pas du bruit, c'est de la **quantification** : 0,35 s vaut exactement
**21 frames** a 60 fps, 0,28 s en vaut **16,8**, donc le tween se termine a
la frame **17** et un bond occupe reellement **0,2833 s**. Chaque trajet
coute donc **~1,19 % de plus** que l'arithmetique nominale. C'est faible,
mais c'est la raison pour laquelle les deux valeurs livrees dans le
commentaire de la constante sont **4,817 / 13,317** et non 4,76 / 13,16 —
**un futur reglage doit citer la ligne MESUREE.**

### PHASE 3 — SONDES ET NON-REGRESSION

* **`ProbeTimeoutAudit` : exit 0, `38 probe scenes`** — retour exact a la
  baseline de `origin/staging` apres suppression de la sonde jetable.
* **`AssetContractAudit` : exit 0**, 12/12 visuels swappes, **0/10
  colliders deplaces**.
* **Aucune sonde existante ne suppose une duree de bond** — `grep -E
  "0\.35|HOP_DURATION|hop"` sur `scripts/dev/*.gd` : **zero occurrence**
  liee au hopper. **Non-applicabilite verifiee, pas supposee** : la seule
  sonde de `scripts/dev/` qui charge `HubWorld.tscn` est
  `HubPerfBaseline`, et elle **ne tape jamais**, donc Keepy ne bouge pas
  pendant son echantillon et elle ne peut structurellement pas voir un
  bond.
* **`HubPerfBaseline` rejouee 3 fois** sous `xvfb --rendering-driver
  opengl3` (jamais `--headless`, qui forcerait le driver DUMMY — piege deja
  consigne), et **`docs/HUB_PERF_BASELINE.md` recoit sa premiere ligne de
  COMPARAISON** sous la ligne de baseline. **Draw nodes 55 / 61,
  IDENTIQUES a la baseline sur les trois runs** — c'est le seul chiffre
  exact du tableau, et c'est celui qui doit ne pas bouger. Construction
  47,8-65,3 ms, FPS moyen 15,1-16,7, FPS min 8,7-10,4 : tout chevauche la
  baseline (45,3-52,4 / 14,5-16,4 / 7,7-12,4) sauf **un run de
  construction a 65,3 ms**, au-dessus — publie tel quel plutot que lisse,
  c'est le bruit de CPU partagee que ce fichier documente deja.

⚠️ **Ce que la ligne perf ne dit PAS, et il faut le dire avant qu'on la
lise a l'envers** : elle n'est **pas** une preuve que le hub tourne mieux.
La sonde ne tape jamais, donc elle ne mesure aucun bond ; ce lot ne change
ni un noeud, ni un mesh, ni un materiau. La ligne existe pour attester
qu'il **n'a rien coute**, pas qu'il a gagne quoi que ce soit.

### Build et export

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** —
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0**, **24 `.scn`** (import complet verifie et pas
suppose — le piege du faux-rouge par import tronque est controle), **0
erreur**. Boot headless de `HubWorld.tscn`, `Hub.tscn` (le rollback) et
`TitleScreen.tscn` : **0 erreur** chacun. Export Web release **exit 0, 0
erreur**.

`index.wasm` **35 376 909 octets**, md5
**`af4a8fc2925d992348eb30deeeb54360`** ; `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — **identiques au fingerprint deja
consigne** pour tout lot qui ne touche pas le code moteur, coherent avec un
diff d'un seul flottant. `index.pck` **5 833 088** (export unique et
propre, `build/` supprime avant — 16 octets sous la baseline, a lire avec
la mise en garde permanente sur son instabilite, **jamais offert comme
preuve**). **Piege payload tenu** : **0** ligne `Storing File` pour
`assets_source`, `scripts/dev`, `docs`, `web` ou `build`, sur 219.

**La sonde de mesure etait JETABLE et est supprimee avant tout commit** —
c'est ce que `ProbeTimeoutAudit` a 38 confirme.

### Reste ouvert — jugement device, seul juge, et il pese plus lourd ici

1. **Le bond a-t-il encore du POIDS ?** C'est tout l'objet du lot et aucune
   sonde ne peut y repondre. `KeepyHopper.gd` decrit lui-meme le squash
   comme « toute la difference entre un personnage qui a du poids et un
   curseur » ; ce lot raccourcit de 19 % l'intervalle sur lequel cette
   enveloppe se joue. **C'est le seul risque reel du lot, et il porte sur
   TOUT le hub, pas seulement sur les longs trajets.**
2. **Le recoil occupe 43 % d'un bond** au lieu de 34 %. Argumente comme
   inoffensif (il reste plus court qu'un bond), pas juge a l'oeil.
3. **La camera traine 1,110 u au lieu de 0,893 u.** Mesure ; personne n'a
   regarde si ca se lit comme une camera qui suit ou comme une camera en
   retard.
4. **La reactivite au tap tombe de 0,35 s a 0,28 s au pire cas** — c'est un
   gain, mais il vient du meme changement que le point 1 : les deux ne
   peuvent pas etre regles separement.
5. Inchange et toujours ouvert par ailleurs : les **~5-6 taps lateraux**
   pour traverser (le vrai cout d'un plateau large, deja mesure au lot D),
   et l'arbitrage du rayon 35 que le lot D a laisse a Mathieu.

### Deploiement staging du lot E (palier 1, automatique)

`staging` **`e838169`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `d554baf4` des deux cotes, verifie AVANT
le push). CI run **#223** (id `32843414686`) **verte** (11:39:10 -> 11:42:33
UTC), `conclusion: success`. **`main` NON touche** (`origin/main` toujours
`ffcc552`, verifie apres le push) : palier 2 gate par Mathieu, et il pese
**plus lourd que d'habitude ici** — ce lot change le RESSENTI du deplacement
partout dans le hub, pas seulement sur les longs trajets.

**Verifie SUR LE SERVICE, pas dans le log CI** — `CACHE_VERSION` de
`index.service.worker.js` de `keepy-staging.vercel.app` :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #222) | `1787657053` | **11:24:13** |
| **apres (ce lot, run #223)** | **`1787658121`** | **11:42:01** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #223**, avec
`x-vercel-cache: MISS` et `age: 0` sur les deux lectures utiles.

⚠️ **Le piege de lecture consigne au lot D s'est reproduit a l'identique et
a ete refuse plutot que compte** : une relecture faite ~2 min apres le push
est revenue `x-vercel-cache: HIT` avec **`age: 172`** — une copie CDN figee
AVANT le deploiement. **Un HIT avec un `age` non nul n'est pas une mesure de
fraicheur**, donc cette lecture n'a pas ete comptee comme la lecture
« pendant que le job tourne » ; c'est la lecture MISS/age 0 qui tranche.

