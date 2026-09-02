# Eau — rendu : teinte de Keepy, ligne de flottaison, impact

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 4 section(s), 1008 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## KEEPY SE TEINTE DANS L'EAU : 75 % vers #40E0D0, cinq corps, et DEUX chiffres de marge publies en echec avant d'etre corriges (27 aout 2026)

Branche `claude/keepy-water-tint-impl-n2wan2`, partie de `staging` (`f2f5654`).
Regle n°1 verifiee AU DEBUT : `git fetch --all --prune`, tri des refs par date,
comparaison des ARBRES et pas des noms -- `origin/main` (`a007e78`) et
`origin/staging` (`916d7d8`) portent le MEME arbre `3246b4a4`, aucune branche
ne porte ce brief, aucune session concurrente.

⚠️ **ETAPE PREALABLE : le rapport de recon avait ete laisse NON MERGE.**
`claude/keepy-water-tint-recon-mp838x` (`648bb3b`, `docs/WATER_TINT_RECON.md`,
335 lignes, doc-only) n'etait pas ancetre de `staging` -- une instruction
d'environnement contradictoire de la session precedente. Merge en PREMIER
(`f2f5654`, `--no-ff`), arbre du merge **byte-identique** a la branche recon
(`b54292ba` des deux cotes, `git diff` vide). Sans ca le rapport se perdait.

**Decision de Mathieu, non re-arbitree** : fraction **75 %** vers `#40E0D0`,
les CINQ corps traites identiquement, Keepy seul (la barque n'est PAS
teintee), squash et ligne de flottaison ecartes.

### Le mecanisme est COPIE, pas invente

`scripts/battle/FighterView.gd` teinte deja **CE MEME `.glb`** a travers un
`ModelSlot`. Son couple `_ensure_material()`/`_tint_to()` est repris tel quel
dans `HubWorld.gd` ; **`FighterView.gd` est INTOUCHE** -- on s'en inspire, on
ne le modifie pas, et les deux ecrans ne peuvent pas deriver vers deux facons
de recolorier un `.glb`.

Les deux proprietes qui portent tout, mesurees et pas supposees : l'albedo de
Keepy part a **`rgb(1,1,1)` pur** (toute sa couleur vit dans la texture), donc
ecrire l'albedo **MULTIPLIE** la texture au lieu de la remplacer -- il garde
ses marquages, ses yeux et son badge et prend la teinte par-dessus ; et le
materiau est **DUPLIQUE** avant ecriture, parce que l'importeur glTF lie UN
materiau partage sur le mesh, et que le fighter joueur de Battle est le meme
`.glb`.

### `HubWater.gd` -- un seul test pour cinq corps, aucune dimension restatee

`class_name HubWater`, `RefCounted`, construit une fois. Il repond **« Keepy
est-il mouille »** et rien d'autre : il ne refuse aucun tap, ne clampe aucune
destination. `HubRegion.contains()` garde sa propre reponse a **« Keepy
peut-il tenir ici »**, qui est une autre question (les trois corps hors grand
lac sont marchables **par conception** -- la barque s'embarque depuis la tete
du ruisseau, posee sur la rive de la mare).

Pas un seul nombre n'est reecrit : pond et petit lac viennent de
`HubBuilder.pond_centre()` / `small_lake_centre()` (**nouveaux**, du meme
patron que `boat()`/`stream_spine()` -- ils rapportent ou le disque a ete
**DESSINE**), les deux lobes de `HubRegion.lakes()`, la teinte de
`HubBuilder.POND_WATER_COLOR`, et le ruisseau de
`HubStreamRoute.distance_to()` -- l'appel que le mouillage utilise deja.

### ⚠️ TROIS PREMISSES FAUSSES, PUBLIEES EN ECHEC -- dont DEUX etaient les miennes

**1. La recon SOUS-ESTIMAIT le residu du ruisseau.** Elle mesurait 1/40 a
+0,001. Echantillonnage dense : **116/4000**.

**2. Ma propre premiere constante, `STREAM_RIM_MARGIN = 0.010`, NE CORRIGEAIT
PAS le defaut** -- et ma propre sonde la validait en vert. Sa sonde balayait
**80 echantillons**, trop peu pour tomber sur une courbe serree. Passee a
**2000 abscisses x 2 cotes**, elle mesure **3/4000 de residu a +0,010**.
Corrige a **0,020** AVANT commit, sur la mesure et pas sur la relecture.

**3. Et la CAUSE n'est pas float32 du tout.** Le ruban est **DESSINE** en
decalages perpendiculaires aux 89 samples du spine ; `distance_to()` mesure a
la **CORDE** qui les relie. Sur un virage les deux lignes different d'une
sagitta `r(1-cos(theta/2))` = **0,0195** au rayon le plus serre (1,4058, son
propre chiffre publie), du meme ordre que le debord pire mesure **0,0141**.
C'est un ecart **GEOMETRIQUE** entre ce qui est dessine et ce qui est mesure ;
il ne retrecit pas avec la precision. Les disques, eux, sont bien un cas
float32 (52 a 141 azimuts sur 360 glissent au bord exact, tous propres a un
millimetre).

| marge | span-midpoints x2000 | sommets du spine | uniforme x5000 |
|---|---|---|---|
| +0,001 | 116/4000 | 46/178 | 283/10000 |
| +0,010 | **3/4000** | **2/178** | **8/10000** |
| **+0,020** | **0/4000** | **0/178** | **0/10000** |

⚠️ **Aucune des deux marges n'est utilisee par la teinte.** Elargir le test
deplacerait la ligne d'eau elle-meme -- Keepy se lirait mouille debout sur la
berge. Ce que le chiffre du ruisseau dit vraiment, et qu'un futur appelant
doit savoir : **un point jusqu'a ~1,4 cm hors du bord dessine est rapporte
comme de l'eau sur un virage serre.**

### Le branchement : `hop_landed`, AVANT tout ce que l'atterrissage declenche

Le test tombe immediatement apres la garde `is_riding()`, **avant** les
branches embarquement / dialogue / portail -- les trois sortent en `return`,
donc une teinte placee apres cesserait de se mettre a jour sur exactement les
atterrissages qui font quelque chose, en silence et seulement parfois.

⚠️ **`_on_ride_started()` ETEINT la teinte, et ce n'est pas de la ceinture et
bretelles.** Un ride n'emet aucun atterrissage (mesure : **0 sur 91 frames**),
donc rien ne peut l'allumer en cours de traversee -- mais la coque est amarree
**SUR l'eau aux deux bouts**, donc le dernier atterrissage d'une marche
d'embarquement est mouille dans le cas ORDINAIRE, et la teinte serait portee a
bord pour toute la traversee.

### Validation

**`WaterTintProbe` (nouvelle, PERMANENTE, gatante) : 34 checks, 0 echec,
exit 0.** Elle existe parce que **tout mode de panne de cette feature est
SILENCIEUX** : materiau non resolu, accesseur de centre disparu, hook place
apres un `return` -- aucun ne leve, aucun ne casse un build, et tous
ressemblent a « la teinte n'a jamais ete allumee » sur un device. Sa PHASE C
lit l'albedo **sur les surfaces que le slot DESSINE**, jamais la variable que
`HubWorld` a ecrite : verifier la variable passerait le jour ou `ModelSlot`
cesse de lier l'override, le defaut exact qui a rendu `AlarmRampAudit`
necessaire un ecran plus loin.

⚠️ **Sa PHASE F est celle qui compte le plus pour ce lot, et elle ne parle pas
de couleur** : le hook est insere **AU-DESSUS de la boucle des portails**, et
cette boucle est ce qui fait entrer un joueur dans un sous-jeu -- toute la
raison d'etre de cet ecran. Elle mesure donc que les **3 portails ouvrent
toujours leur dialogue** (`Chased`, `Quizz`, `Battle`) **et** que la teinte a
bien ete mise a jour au passage.

**V1/V2 -- captures reelles** (`xvfb` + `opengl3`, jamais `--headless` seul),
masque par diff avec/sans Keepy (**20 275 px**), jamais une fenetre fixe :

| frame | corps | moyenne masquee |
|---|---|---|
| dry_before | LAND | **rgb(0,8521, 0,6047, 0,4910)** |
| pond / small_lake | pond / small_lake | rgb(0,3724, 0,5532, 0,4269) |
| great_lake A / B | great_lake_0 / _1 | rgb(0,3727, 0,5507, 0,4241) |
| stream | stream | rgb(0,3721, 0,5521, 0,4259) |
| **dry_after** | LAND | **rgb(0,8521, 0,6047, 0,4910)** |

Le banc **reproduit la ligne f=0 de la recon au millieme** (0,852 / 0,605 /
0,491) avant qu'on lui fasse confiance sur du neuf, et ses cinq lignes
mouillees retombent sur la ligne f=0,75 de la recon (0,373 / 0,550 / 0,423).
**Les cinq corps a la meme force** (ecart max 0,0006 en R). **`dry_after` est
identique a `dry_before` au dernier chiffre : aucun residu.** Verifie a l'oeil
aussi -- `docs/hub-shots/tint_comparison.png` : silhouette, oreilles, yeux,
badge « K » et rougeurs restent tous lisibles.

⚠️ **COUT REEL, MESURE ET NON MAQUILLE : la teinte echange du contraste de
silhouette.** Keepy sec contre l'herbe **3,25:1** ; teinte, il tombe a
**1,64-1,81:1 contre l'eau** et **1,52:1 contre l'herbe** (cas ruisseau, le
pire). C'est inherent a teindre quelqu'un vers la chose dans laquelle il se
tient, pas un defaut -- et le ratio porte sur des MOYENNES, donc il sous-estime
la lisibilite reelle que la capture montre.

**V5 -- 98 draw nodes hors portails** (104 au total, 6 dans les portails),
**inchange** : une teinte est une ecriture de propriete sur une surface qui
existe deja.

**V6, diffe contre `origin/staging` en worktree separe** (imports verifies
complets des deux cotes, **24 `.scn`**, et **tailles comparees avant les
contenus** -- la lecon du faux-rouge par troncature) : `AssetContractAudit`
(12/12 visuels, 0/10 colliders deplaces), `DeathModelAudit`,
`ChargerShapeProbe` -- **BYTE-IDENTIQUES sur les DEUX flux**.
`ProbeTimeoutAudit` differe d'**exactement les lignes ajoutees**, **48 -> 49
sondes** (la nouvelle ; les deux sondes jetables sont supprimees avant commit).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que 75 % se lit comme MOUILLE** a vitesse reelle sur un telephone,
   plutot que comme « malade » ou comme un bug de rendu ? Le chiffre est la
   decision de Mathieu prise sur une echelle rendue ; personne ne l'a encore
   vu bouger sur un ecran.
2. **Le contraste perdu** (3,25 -> 1,5-1,8:1) : mesure, argumente comme
   inherent, jamais juge a l'oeil en mouvement.
3. **Le fondu de 0,18 s** : la capture valide le POINT D'ARRIVEE (75 % atteint,
   entierement retire sur terre), pas la duree -- c'est la convention du depot
   (tout ecrit de couleur y est un tween), pas un optimum mesure.
4. **Les ~1,4 cm de debord du ruisseau** sur un virage serre : cosmetiquement
   sans effet pour une teinte, reel pour tout futur appelant.

### Deploiement staging de la teinte eau (palier 1, automatique)

`staging` **`fd81399`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `b204953c` des deux cotes ET `git diff` vide,
verifie AVANT le push). CI run **#263** (id 33064273870) **verte** --
`Import project resources` 10:44:25 -> 10:46:21, **`Export Web build`
10:46:21 -> 10:46:25**, `Deploy to Vercel [STAGING -- staging]` succes
10:46:40 -> 10:46:49, `[PRODUCTION -- main]` correctement **skipped**.
**`main` NON touche** (`origin/main` toujours `a007e78`, verifie apres le
push).

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** :

| marqueur | avant | apres |
|---|---|---|
| `CACHE_VERSION` | **`1787825206`** = 10:06:46 (run #262) | **`1787827584`** = **10:46:24** |
| `index.pck` servi | *(non lu avant le merge -- voir ci-dessous)* | **5 868 560** |
| `index.wasm` servi | -- | **35 376 909** *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de la fenetre `Export Web build`**, et
les deux lectures du `CACHE_VERSION` portent **`x-vercel-cache: MISS` avec
`age: 0`**, celle d'avant prise **avant le merge** : la bascule est donc
prouvee dans les deux sens et pas deduite du log.

⚠️ **Honnetete sur le second marqueur** : l'`index.pck` servi n'a ete lu
qu'APRES, donc il vaut comme marqueur d'etat courant, **pas** comme preuve de
transition. L'`index.wasm` servi est en revanche **identique au bit pres a
l'export local** (md5 `af4a8fc2925d992348eb30deeeb54360`) -- c'est lui la
preuve d'identite. L'`index.pck` local vaut 5 868 544 contre 5 868 560 servi,
**16 octets d'ecart** : enieme illustration de l'instabilite deja consignee,
jamais offerte comme preuve.

⚠️ **Le piege HIT/age s'est reproduit DEUX fois et a ete refuse les deux
fois** (age 58 puis 82), et **un parametre de requete different ne l'a pas
buste** -- comportement deja documente. Seule une lecture MISS/age 0 compte.

⚠️ **Piege NOUVEAU, et il aurait produit un FAUX VERT silencieux** : une
boucle d'attente `until [ "$(curl ... | grep CACHE_VERSION)" != "<ancien>" ]`
est sortie **immediatement**, en annoncant que la valeur avait change. Elle
n'avait rien lu : **l'egress direct de ce sandbox refuse `*.vercel.app`**
(`http_code 000`, exit 56, re-teste et pas suppose), donc la comparaison
portait sur une **chaine VIDE**, qui est bien differente de l'ancienne
valeur. Une garde d'attente qui ne verifie pas qu'elle a REELLEMENT lu
quelque chose confond « change » et « rien recu ». Le canal MCP Vercel est le
seul disponible ici.

⚠️ **Et une NUANCE en sens inverse sur le piege « API Actions perimee »** :
`updated_at` est reste fige pendant plusieurs minutes, ce qui en a
exactement la forme -- mais `list_workflow_jobs` montrait les etapes 1 a 8
terminees avec de vrais horodatages et l'etape 9 en cours. L'API disait
vrai : l'import a reellement pris **1 min 56 s**. « L'etape est simplement
lente » doit etre ecarte avant d'accuser l'API, comme au lot RIDE-1.

## LIGNE DE FLOTTAISON LIVREE : un shader a hauteur MONDE, la ligne aux hanches (0,45), la tete au sec (27 aout 2026)

Branche `claude/waterline-shader-impl-d87hnj`, partie de `staging`
(`c2ec912`). **TROIS fichiers** : `assets/shaders/keepy_waterline.gdshader`
(nouveau), `scripts/hub/HubWorld.gd`, `scripts/dev/WaterTintProbe.gd`.
`HubWater.gd` est **BYTE-INTOUCHE**, verifie par `git diff --stat` et pas
affirme -- il continue de repondre « est-il dans l'eau », le shader repond
« quelle partie de lui ».

⚠️ **Ecart de ref au demarrage, benin et signale plutot que tu** : le brief
annoncait `origin/staging = 1f1486f`, la mesure donne **`c2ec912`**.
`1f1486f` EST son parent (verifie par `git merge-base --is-ancestor`, pas
suppose) et le seul commit au-dessus est **doc seule**. `origin/main` =
`a007e78`, exactement comme annonce. Regle n°1 verifiee AU DEBUT : tri des
refs par date et comparaison des **ARBRES**, jamais des noms -- toutes les
branches plus recentes que `main` sont deja ancetres de `origin/staging`,
**aucune session concurrente**.

**DECISION DE MATHIEU, PRISE SUR PLANCHE, NON RE-ARBITREE ICI** : barreau
**0,45**, le rung « hips » de
`docs/color-sheets/waterline_ladder_sheet.png`. La recon recommandait
0,78-0,92 et est **ECARTEE**. Sa metrique mesurait la SURFACE teintee
(fractions 0,021 / 0,059 / 0,110 sur les barreaux bas, parce que Keepy est
modelise ASSIS et que ses jambes sont petites et auto-occultees) ; la
question posee est la LISIBILITE DE L'INTENTION, et ce sont des
PATAUGEOIRES. **Ne pas reproposer un barreau plus haut.** Nage et bateau
hors perimetre.

### Ce qui est livre

Le shader remplace **l'ecriture d'albedo**, pas `HubWater`. Variante A de
la recon, reprise telle quelle : un `varying vec3` calcule en `vertex()`
depuis `MODEL_MATRIX`, `step(v_world.y, water_y)`, `mix()` vers la teinte
de l'eau. `render_mode unshaded, cull_disabled` -- les deux sont un
**appariement mesure** au materiau remplace (`shading_mode = 0`,
`cull_mode = 2 DISABLED`) et non un choix.

| ligne | avant | apres |
|---|---|---|
| `_keepy_material` | `StandardMaterial3D` | **`ShaderMaterial`** |
| `_keepy_base_color` | source du tint | **supprime** -- le shader multiplie la texture |
| `KEEPY_WATER_TINT_FRACTION` 0,75 / `KEEPY_TINT_FADE_S` 0,18 | -- | **inchanges** |
| `_keepy_wet` / les 2 sites d'appel / le latch | -- | **inchanges** |
| `_set_keepy_wet()` | tween `albedo_color` | tween `shader_parameter/tint_fraction` |
| **nouveau** | -- | `KEEPY_WATERLINE_Y = 0.45` |

⚠️ **Le test est en coordonnees MONDE, et c'est TOUT le design.** La
version espace-modele compile, rend, et parait plausible sur une image
fixe -- c'est ce qui la rend dangereuse. La recon l'avait mesuree
(soaked a toute altitude, ligne qui remonte l'ecran 943 -> 855) ; ce lot
la re-mesure a l'envers, sur le code livre, et la ligne tient.

### V1 -- les cinq corps, MEME pose, MESURE

Chaque chiffre est un diff **PLEIN CADRE de la MEME POSE rendue deux
fois** -- teinte off, puis on -- **jamais** un diff entre deux poses (la
recon a deja publie cette erreur, qui lui avait rapporte un Keepy montant
comme « de plus en plus mouille »). **2 073 600 pixels lus**, pas un
echantillonnage : 80 points ont deja valide un vrai defaut en vert sur cet
ecran.

| corps | px teintes | 1re ligne | derniere | camera dit | ecart |
|---|---|---|---|---|---|
| pond | 2011 | 1055 | 1165 | 1069,3 | -14,3 |
| small_lake | 2033 | 1055 | 1164 | 1068,4 | -13,4 |
| great_lake_0 | 2242 | 1054 | 1170 | 1068,4 | -14,4 |
| great_lake_1 | 2239 | 1056 | 1171 | 1068,9 | -12,9 |
| stream | 2255 | 1054 | 1173 | 1070,2 | -16,2 |

**Ligne la plus haute : 1054 a 1056, soit 2 px d'ecart sur cinq corps.**
L'ecart de ~14 px avec ce que dit la camera n'est PAS une derive : un plan
horizontal ne se projette pas sur UNE ligne d'ecran (camera a -34 deg, la
bande fait 147 px de haut sur la profondeur de Keepy), et la ligne teintee
la plus haute est le cote LOIN de son corps. La recon mesurait -18 px par
le meme mecanisme.

⚠️ **Defaut de MA sonde, corrige et publie** : la premiere version emettait
`hop_landed` **sans deplacer Keepy**, donc les cinq lectures etaient la
meme pose par construction (2251 px partout, ecart 0) -- un controle propre
du gate, mais il ne le mettait dans aucune eau.

### V2 -- la ligne tient pendant un vrai hop

Hopper livre, `--fixed-fps 60` (sans ce flag un hop de 0,28 s tient en
trois frames llvmpipe et la table ne veut rien dire) :

| | y | px teintes | 1re ligne |
|---|---|---|---|
| au sol | 0,0000 | **1758** | 1050 |
| a l'apex | 0,5833 | **165** | 1048 |

**Effondrement de 91 %, et la ligne dessinee bouge de 2 px.** Le corps
traverse une ligne qui ne bouge pas.

### V3 -- la sortie d'eau, et pourquoi `HubWater` reste indispensable

Au spawn `contains() == false` et les pieds sont a `y = 0` : `tint_fraction`
lit **0,0000**. Puis, en forcant la fraction a 0,75 a ce meme endroit,
**8 529 px se teindraient**. C'est exactement pourquoi le gate de
`HubWater` n'est pas remplacable par le test de hauteur.

### V4 -- riding : 0,0000

⚠️ **Second defaut de MA sonde** : a 10 frames elle lisait **0,0051** et
appelait ca un residu. Ce n'en est pas un -- c'est ou se trouve un tween
`TRANS_SINE`/`EASE_OUT` 0,75 -> 0 a cet instant :
`0,75 * (1 - sin(0,926 * PI/2)) = 0,0051`, a la quatrieme decimale.
Echantillonne au-dela du fondu de 0,18 s : **0,0000**.

### ⚠️ V5 -- UNE constante, CINQ surfaces : l'ecart est REEL et il est publie

| corps | surface | ligne au-dessus | % de Keepy |
|---|---|---|---|
| greatlake_a | 0,0270 | 0,4230 | 31,33 % |
| greatlake_b | 0,0295 | 0,4205 | 31,15 % |
| pond | 0,0800 | 0,3700 | 27,41 % |
| small_lake | 0,0800 | 0,3700 | 27,41 % |
| stream | 0,0950 | 0,3550 | 26,29 % |

**SPREAD 0,0680 = 5,04 % de sa hauteur.** La distinction qui compte, et
que le brief demandait de trancher : **sur SON CORPS la ligne est
identique partout** (0,45 / 1,3501 = 33,33 %, et V1 le confirme au pixel :
2 px d'ecart sur cinq corps). Ce qui varie, c'est de combien elle flotte
**au-dessus de la surface dessinee**. **NON CORRIGE** : une constante par
corps est la decision de Mathieu, pas celle de ce fichier.

### ⚠️ UNE PREMISSE A MOI, PUBLIEE EN ECHEC

J'ai lu du **mouchete turquoise haut sur la queue** sur deux captures et
j'ai soupconne la ligne. **FAUX**, et la mesure l'a refute plutot que
l'inverse : une passe de MASQUE (`ALBEDO = vec3(step(...))`, aucune
texture) rend **une seule region blanche contigue aux pattes, zero
mouchetis** ; la meme image teinte **OFF** montre le meme mouchetis ; et a
`water_y = 99` le masque est **blanc plein** sur toute la silhouette, donc
le varying couvre bien tout le corps. C'etait sa fourrure -- les taches
creme sur le roux -- amplifiee par mon agrandissement NEAREST. C'est la
premisse 3 de la recon, rencontree et refutee independamment.

### `WaterTintProbe` : 34 -> 36 checks, aucun desarme

| check | ce qui lui arrive | pourquoi |
|---|---|---|
| « tints the DRAWN surfaces to 75% » | **reecrit** | lit `tint_fraction` au lieu d'un albedo |
| « a landing on land removes the tint » | **reecrit** | idem |
| « the tint was updated (dry) » x3 portails | **reecrit** | idem |
| « the wet albedo is not just the base colour » | **SUPPRIME** | assertion NEGATIVE que l'ancien lecteur satisfaisait en rendant MAGENTA sur un cast rate -- verte contre un materiau qu'elle n'avait pas lu |
| **« the DRAWN material is a ShaderMaterial »** | **NOUVEAU** | positif |
| **« carries the shipped waterline height »** | **NOUVEAU** | positif -- la hauteur n'etait pas verifiable avant, et une ligne au mauvais y est la panne la plus bruyante qui ait encore l'air de marcher |
| **« runs the waterline shader »** | **NOUVEAU** | positif |
| les 28 autres | **intouches** | appartenance, les deux marges de rim, le ride, les draw nodes, les portails |

Le lecteur `_drawn_albedo()` (MAGENTA sur echec) devient `_shader_float()`,
qui rend **`UNREADABLE = -1.0`** -- negatif exprès, puisque tout
`tint_fraction` legal est dans [0, 1] et qu'aucune comparaison ne peut le
prendre pour une vraie valeur. **Baseline 34 OK / 0 echec, apres 36 OK /
0 echec.** Les helpers couleur `_near()`/`_fmt()` sont retires : plus rien
dans ce fichier ne compare des couleurs.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
**50 276 070** et **1 073 228 327** octets, aucune troncature silencieuse).
Import headless **exit 0, 24 `.scn`, 0 erreur** (import complet verifie,
pas suppose -- un import tronque produit un faux rouge). Boot de
`HubWorld.tscn` **exit 0** en headless ET sous `xvfb`/`opengl3` : **aucun
`SHADER ERROR`**, le shader compile pour de vrai (le headless force le
driver DUMMY et ne compile rien -- il ne prouve rien tout seul). Export Web
release **exit 0**, aucune erreur GDScript ni shader.

`index.wasm` **35 376 909** octets / md5
**`af4a8fc2925d992348eb30deeeb54360`**, `index.js` md5
**`4e08904b1b7107858246af44b602067b`** -- identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
**5 874 256** (marqueur, **jamais** preuve d'identite). **Piege payload
tenu** : sur **228** lignes `Storing File`, **0** pour `scripts/dev`,
`assets_source`, `docs`, `web/` ou `firebase.json` -- et
`keepy_waterline.gdshader` **EST** packe, comme il le doit.

**Sondes diffees contre `origin/staging` en worktree separe** (imports
verifies complets des deux cotes, 24 `.scn`), graine 20260806,
`--fixed-fps 60` :

| sonde | verdict |
|---|---|
| `ProbeTimeoutAudit` | **BYTE-IDENTIQUE**, 49 sondes scenes + 1 `--script`, toutes armees |
| `AssetContractAudit` | **BYTE-IDENTIQUE**, 12/12 visuels, **0 collider deplace** |
| `DeathModelAudit` | **BYTE-IDENTIQUE** |
| `ChargerShapeProbe` | **BYTE-IDENTIQUE** |
| `LakeZoneProbe` | 25 checks, 0 echec |
| `StreamRideProbe` | 37 checks, 0 echec |
| `WaterTintProbe` | 36 checks, 0 echec (34 en baseline) |

**`scripts/dev/*.tscn` est un ensemble IDENTIQUE a `origin/staging`** --
aucune sonde ajoutee, aucune retiree, les deux jetables supprimees.

**Cout : rien de mesurable.** Trois runs `HubPerfBaseline` de chaque cote,
dans une seule session, sur une machine LAISSEE AU REPOS -- la seule
comparaison que les regles de ce fichier autorisent :

| | AVANT (`origin/staging`) | APRES |
|---|---|---|
| draw nodes hors portails | **98 / 98 / 98** | **98 / 98 / 98** |
| draw nodes, total | 104 / 104 / 104 | 104 / 104 / 104 |
| FPS simule, moyen | 14,1 / 14,3 / 14,6 | 15,3 / 15,3 / 14,6 |
| FPS simule, min | 6,6 / 12,0 / 12,1 | 11,9 / 11,5 / 11,8 |

Un echange de materiau est un echange de materiau : le meme
`MeshInstance3D` dessine la meme surface avec un autre programme. Marge
sous le plafond de 260 : inchangee.

⚠️ **La lecture honnete des lignes FPS est « les plages se chevauchent »
(14,6 apparait des DEUX cotes), PAS « c'est plus rapide ».** Ce que ces
lignes soutiennent est la revendication etroite qu'**aucun cout n'est
detectable**. ⚠️ **Et une premiere paire a ete JETEE** plutot que publiee :
mes trois runs de branche initiaux (11,2-11,4) tournaient pendant que
l'import de la baseline occupait la machine. Les comparer aurait mesure la
contention, pas le shader. **Ces chiffres ne sont comparables ni a un GPU
de telephone ni aux lignes FPS de `docs/HUB_PERF_BASELINE.md`** -- llvmpipe
est un rasteriseur logiciel, ou un `step()`/`mix()` par fragment coute
comparativement cher, donc la mesure est si tout va pessimiste.

### ⚠️ CE QUE CE LOT NE PEUT PAS PROUVER -- a redire avant tout test device

Tout ce qui precede est rendu par **llvmpipe/Mesa sous xvfb via le backend
`opengl3` DESKTOP**. Le jeu tourne en **WebGL2 dans Safari iOS**. Ce sont
deux compilateurs GLSL differents derriere la meme source
`gl_compatibility`, et **les deux points sur lesquels ce design repose sont
exactement ceux que rien ici ne prouve** : la precision d'interpolation
d'un `varying` (**`mediump` est courant en WebGL2 mobile** la ou le desktop
donne `highp`) et la disponibilite/precision de `MODEL_MATRIX` en
`vertex()`. Un world y autour de 0,45 porte en `mediump` devrait passer ;
**rien ici ne le demontre.**

**Aucune couleur mesuree ici n'est une couleur device.** Aucune capture de
ce sandbox n'est une preuve de rendu telephone. Et ce lot ne rend que des
**IMAGES FIXES** : si un bord mouille/sec se lit comme une ligne d'eau ou
comme une couture A VITESSE REELLE, et si le cycle
mouille -> sec -> mouille d'un hop en 0,28 s se lit comme de la physique ou
comme du clignotement, aucune image fixe ne peut le dire.

### Reste ouvert

1. **Jugement device**, et c'est tout l'objet du lot : est-ce que 0,45 se
   lit comme « il patauge » sur un vrai telephone.
2. **Le clignotement du hop** -- mesure (1758 -> 165 px en 0,28 s), correct,
   possiblement laid. Personne ne l'a vu en mouvement.
3. **Les 5,04 % d'ecart entre les cinq surfaces** (V5) -- mesure, publie,
   non corrige.
4. **La teinte EST la couleur de l'eau**, donc la partie immergee
   DISPARAIT dans l'eau plutot que de lire « Keepy mouille ». A 0,45 c'est
   ce qui vend la pataugeoire ; c'est une consequence, pas un reglage.

### Deploiement staging de la ligne de flottaison (palier 1, automatique)

`staging` **`c4d32f4`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature -- meme hash d'arbre `31638d07` des deux cotes ET
`git diff` vide, verifie AVANT le push). CI run **#267**
(id 33079018165) **verte** : `Import project resources` 13:51:39 ->
13:54:10, `Export Web build` **13:54:10 -> 13:54:15**, `Deploy to Vercel
[STAGING -- staging]` **succes**, `[PRODUCTION -- main]` correctement
**skipped**. **`main` NON touche** (`origin/main` toujours `a007e78`,
verifie apres le push) : palier 2, gate Mathieu apres validation device.

**Verifie SUR LE SERVICE, pas dans le log CI, et DANS LES DEUX SENS** :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #266) | `1787831980` | **11:59:40** |
| **apres (ce lot, run #267)** | **`1787838854`** | **13:54:14** |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build`** du
run #267, et **les DEUX lectures portent `x-vercel-cache: MISS` avec
`age: 0`**, la valeur d'avant ayant ete relevee **avant le merge**. La
bascule est donc prouvee dans les deux sens et pas deduite du log.

⚠️ **Un SEUL marqueur, dit plutot que sous-entendu** : contrairement a
plusieurs lots recents, `index.pck`/`index.wasm` servis n'ont pas ete
relus sur le service. Le `CACHE_VERSION` lu aux DEUX bouts en MISS/age 0
est la forme la plus forte que ce fichier documente, mais c'est un
marqueur unique et non deux marqueurs independants.

`index.wasm` de l'export local : **35 376 909** octets / md5
`af4a8fc2925d992348eb30deeeb54360` -- identique au fingerprint permanent.
`index.pck` **5 874 256**, marqueur, **jamais** preuve d'identite.

## LA LIGNE DE FLOTTAISON ETAIT UN DEFAUT DE PROFONDEUR, PAS DE REPERE : une ligne, `ALPHA = tex.a`, et elle coutait le depth write (27 aout 2026)

Branche `claude/waterline-shader-orientation-e5hnyr`, partie de `staging`
(`3e4dd35`, exactement la ref annoncee ; `main` a `a007e78`, **INTOUCHE**).
Regle n°1 verifiee AU DEBUT : tri des refs distantes par date et
comparaison des ARBRES -- `origin/staging` est la ref la plus recente du
depot et la branche du lot precedent (`c88de88`) en est deja un ancetre,
**aucune session concurrente**.

Regression constatee sur device par Mathieu (iPhone, Safari, navigation
privee, staging) : la teinte se lit correctement de face et **faux des que
Keepy n'est pas de face** -- un bloc central teinte avec la queue et le bas
qui ressortent en roux par-dessus, et un corps delave blanc-creme **sur
l'herbe**, hors de l'eau, ou la teinte est pourtant gatee a zero.

### ⚠️ LES DEUX HYPOTHESES DU BRIEF SONT L'UNE ET L'AUTRE ECARTEES

**H1 -- MODEL_MATRIX / mauvais espace : REFUTEE, par lecture ET par
mesure.** Le shader calcule bien `v_world = (MODEL_MATRIX * vec4(VERTEX,
1.0)).xyz`, c'est-a-dire l'espace MONDE, et `VERTEX` est bien en espace
modele faute de `render_mode world_vertex_coords`. La mesure le confirme
plus fort que la lecture : une fois l'etat de rendu corrige, l'image est
**identique au pixel pres a huit azimuts** a celle de la matiere d'avant --
un calcul dans le mauvais espace ne peut pas produire huit zeros.

⚠️ Et une raison de PRINCIPE qui aurait du ecarter H1 d'emblee : **le
lacet ne touche pas Y.** Keepy ne pivote qu'autour de Y (`Yaw`), donc
l'espace modele et l'espace monde ne different que par une echelle et un
decalage sur cet axe -- une bande horizontale reste horizontale a tout
lacet, dans les deux espaces. H1 ne pouvait pas expliquer une correlation
a l'orientation.

**H2 -- precision `mediump` du varying en WebGL2 mobile : NON NECESSAIRE.**
Le defaut **se reproduit integralement dans le sandbox** sous
`opengl3` bureau / llvmpipe, ou la precision n'est pas en cause. H2 n'a donc
plus rien a expliquer. Ce n'est pas une refutation -- elle n'a pas ete
testee sur device -- c'est un rasoir : la cause trouvee suffit.

### LA CAUSE : `ALPHA = tex.a` MET LE MATERIAU DANS LA PASSE TRANSPARENTE

**MESURE** : ecrire `ALPHA` coute au materiau son ecriture de profondeur.
Ce n'est pas deduit -- c'est ce que dit D4 ci-dessous, ou forcer
`depth_draw_always` TOUT EN gardant l'ecriture donne exactement le meme
resultat que retirer l'ecriture, au pixel pres, aux huit azimuts. Le seul
terme qui change entre ces deux-la est le depth write.

**MECANISME (documente, non mesure ici)** : dans Godot, assigner `ALPHA`
dans un shader spatial classe le materiau dans la passe TRANSPARENTE,
laquelle n'ecrit pas la profondeur par defaut. C'est le NOM de ce que la
mesure montre ; rien dans ce lot ne l'observe directement, et rien n'en
depend -- la mesure tient sans lui.

Avec `cull_disabled` (qui est le
bon reglage : la matiere d'origine rapporte `cull_mode = 2`), la face
ARRIERE d'un corps ferme repeint alors la face avant **dans l'ordre du
buffer d'indices**. Cet ordre est FIXE ; le cote qui est loin ne l'est pas.
D'ou une image juste a certains lacets et fausse aux autres -- exactement la
forme du rapport.

⚠️ **La matiere que ce shader remplace est OPAQUE** : `transparency = 0`,
`cull_mode = 2`, `depth_draw = 0`, `shading = 0`, `albedo = (1,1,1,1)`. Elle
n'a **jamais** utilise l'alpha de cette texture. L'ecriture etait gratuite.

### LA PREUVE, et pourquoi la metrique evidente a du etre JETEE

⚠️ **La metrique intuitive -- « tout pixel mouille est sous tout pixel sec »
-- est FAUSSE**, et l'avoir crue aurait fait rapporter la camera comme un
defaut. Un plan horizontal ne se projette pas sur une seule rangee sous une
camera inclinee : la recon avait deja mesure `y = 0.55` s'etalant sur
**147 px** de rangees a travers la seule profondeur de Keepy. Le
recouvrement de rangees a donc un PLANCHER legitime de cette taille. Il est
imprime, avec son plancher nomme, et **rien n'en est conclu**.

Ce dont tout est conclu est **la difference contre une reference a
profondeur correcte**, ou aucune geometrie de camera n'entre. Et le point
qui rend la preuve courte : **a `tint_fraction = 0` la couleur que calcule
le shader est `mix(a, a, x)`, c'est-a-dire `a`** -- arithmetiquement la meme
expression que la matiere qu'il remplace. Une difference non nulle la ne
PEUT pas etre une couleur.

**D2 -- Keepy SEC, shader a 0 contre la matiere d'origine, huit azimuts :**

| yaw | 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 |
|---|---|---|---|---|---|---|---|---|
| **avant** (px differents) | 94 | 186 | **13 438** | **25 202** | **19 329** | **17 913** | **12 883** | 278 |
| avant (pire ecart canal) | 0,56 | 0,57 | **0,89** | 0,73 | 0,71 | 0,73 | 0,89 | 0,76 |
| **apres** | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |

C'est la troisieme capture de Mathieu, chiffree : hors de l'eau, la teinte
a zero, et le shader changeait quand meme l'image de 25 202 pixels sur les
~26 000 que Keepy occupe.

**D4 -- QUEL TERME porte le defaut.** Quatre variantes du MEME calcul de
couleur, ne differant que par l'etat de rendu, chacune comparee a la
reference a profondeur correcte :

| variante | 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 |
|---|---|---|---|---|---|---|---|---|
| livre (`cull_disabled`, ecrit `ALPHA`) | 85 | 177 | 13 191 | **24 470** | 18 599 | 17 545 | 12 558 | 255 |
| **sans `ALPHA`** | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |
| **`ALPHA` + `depth_draw_always`** | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |
| `ALPHA` + `cull_back` | 12 | 43 | 915 | 1 397 | 4 362 | 4 753 | 835 | 49 |

⚠️ **Les deux lignes a zero sont DEUX SHADERS DIFFERENTS qui s'accordent au
pixel pres a huit angles.** Rien d'autre ne leur est commun que d'ecrire la
profondeur : c'est ce qui epingle la cause sur le depth write et pas sur la
couleur. La quatrieme ligne montre que couper les faces arriere **attenue
sans fermer** -- utile pour comprendre le mecanisme, inutile comme correctif.

**D1 -- la correlation a l'orientation, quantifiee.** Nombre de pixels
lus MOUILLES, dans l'eau, a `tint_fraction = 0,75` :

| yaw | 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 |
|---|---|---|---|---|---|---|---|---|
| avant, px | 2 251 | 2 838 | 9 073 | **12 084** | 10 452 | 10 298 | 8 807 | 4 523 |
| **apres, px** | 2 251 | 2 824 | 4 430 | 4 657 | 2 703 | 2 380 | 4 581 | 4 481 |
| avant, **% de sa silhouette** | 11,1 | 14,1 | 36,1 | 46,5 | 52,8 | **55,0** | 34,2 | 17,4 |
| **apres, %** | 11,1 | 14,1 | 17,6 | 17,9 | 13,6 | 12,7 | 17,8 | 17,3 |

La derniere paire de lignes est la comparaison honnete : le compte brut de
pixels bouge aussi parce que sa silhouette n'est pas la meme de face et de
profil (il a une queue). En PART de sa silhouette, la zone teintee passait
de **11,1 % a 55,0 % par le seul lacet -- un facteur 4,95**. Apres, elle
tient dans **11,1 a 17,9 %, un facteur 1,61**, et ce qui reste est la
variation legitime d'un corps qui n'est pas de revolution.

Le surplus etait sa face ARRIERE -- dont la moitie basse est sous la ligne
-- peinte par-dessus la moitie haute et seche de sa face avant. C'est mot
pour mot « un bloc central teinte avec la queue et le bas en roux
par-dessus ».

### LE CORRECTIF : retirer l'ecriture, PAS forcer la profondeur

`depth_draw_always` aplatit les memes chiffres (ligne 3 ci-dessus) et **n'est
pas ce qui est fait**. Il laisserait le materiau dans la file alpha, trie
comme un objet entier contre les cinq disques d'eau, eux-memes transparents
-- on echangerait un bug visible contre un bug latent. Retirer l'ecriture
restaure **exactement** l'etat de la matiere remplacee, et la preuve que
rien n'est perdu est que D2 tombe a **0 partout** : la texture n'avait
aucun alpha a porter.

### ⚠️ TROIS SONDES SONT PASSEES VERTES SUR CE BUG, DONT DEUX ECRITES DANS CE LOT

C'est le vrai enseignement, et il ne porte pas sur le shader.

**1. `WaterTintProbe` etait 36/36 verte avec le defaut dedans.** Elle lit
des UNIFORMES, et tous les uniformes etaient corrects : la hauteur, la
fraction, la couleur. Aucun d'eux n'a le moindre rapport avec la surface qui
gagne le pixel.

**2. La premiere PHASE G que ce lot ecrit POUR fermer ca est passee verte
sur le bug, 8/8.** Cause : PHASE D emmene Keepy a `x ~ 12` par un ride et
rien ne le ramene, donc la phase comparait deux images **qui ne contenaient
pas Keepy**. Son assertion est « ces deux rendus sont identiques », et deux
rendus d'un Keepy hors champ le sont gratuitement.

**3. La deuxieme PHASE G a echoue les huit azimuts sur un shader
CORRECT.** Ramener Keepy ne suffisait pas : `HubCamera` le poursuit par un
lerp exponentiel, donc les deux rendus d'une paire differaient par la derive
de la camera ENTRE eux. La signature est sans ambiguite une fois qu'on la
regarde -- **42 624, 30 420, 23 820, 16 315, 9 882, 6 919, 5 986, 5 015**,
une decroissance monotone qui est la camera qui se pose, pas un materiau.

**Parade, structurelle et pas cosmetique.** La phase (a) repose Keepy a
l'origine, (b) **SNAPPE** la camera a la pose qu'elle aurait atteinte et
coupe son `_process`, et (c) porte un **CONTROLE D'AVEUGLEMENT** : avant
d'avoir le droit de conclure, elle teinte Keepy et exige que le nombre
BOUGE. **Une sonde dont l'assertion est une EGALITE doit d'abord prouver
qu'elle sait voir une difference, sinon elle mesure son propre angle mort.**

⚠️ Le controle mesure **2 251 px** -- et c'est exactement le nombre de
pixels mouilles que `WaterlineOrientationProbe` compte a yaw 0 par une
toute autre voie. Deux sondes, deux mises en scene, un seul chiffre.

**Verifiee ROUGE avant d'etre verte**, camera figee, sur l'arbre reverti :

| | controle | yaw 0 | 45 | 90 | 135 | 180 | 225 | 270 | 315 | exit |
|---|---|---|---|---|---|---|---|---|---|---|
| shader d'avant | 2 291 | 94 | 185 | **13 461** | **25 342** | 19 436 | 18 078 | 12 926 | 278 | **1** |
| shader corrige | 2 251 | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** | **0** |

⚠️ **Cette ligne rouge reproduit D2 a quelques pixels pres** (94 / 186 /
13 438 / 25 202 / 19 329 / 17 913 / 12 883 / 278) alors que les deux sondes
ne partagent ni scene, ni masque, ni chemin de code. Et sa FORME est le
rapport de Mathieu : **94 px a yaw 0** -- de face, c'est juste -- contre
13 000 a 25 000 des qu'on tourne.

### ⚠️ LIMITE A NE PAS SOUS-ENTENDRE

Le sandbox rend en **llvmpipe / opengl3 BUREAU** ; le jeu tourne en **WebGL2
sous Safari iOS**. Le vert obtenu ici **ne prouve pas** le vert sur device --
c'est precisement ce qui vient d'echouer au lot precedent. Ce que ce lot
peut affirmer : le defaut se reproduit dans le sandbox, sa cause y est
isolee a un terme unique, et ce terme retire l'image redevient identique au
pixel pres a celle d'avant le shader. Ce que seul Mathieu peut trancher :
que ce soit aussi vrai sur son telephone.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, **tailles verifiees contre le `Content-Length`** :
50 276 070 et 1 073 228 327 octets, aucune troncature silencieuse). Import
headless **exit 0**, **24 `.scn`** (import complet verifie, pas suppose --
le piege du faux-rouge par import tronque est controle). Export Web release
**exit 0**, **0** ligne d'erreur ou de parse.

`index.wasm` **35 376 909** octets -- le fingerprint permanent de tout lot
qui ne touche pas le code moteur, ce qu'un shader et deux sondes sont.
`index.pck` **5 876 560**, marqueur, **jamais** preuve d'identite.

**Piege payload tenu** : sur **228** lignes `Storing File`, **0** pour
`res://scripts/dev`, `res://assets_source`, `res://docs`, `res://web/`,
`res://build` ou `firebase.json`. ⚠️ La chaine `WaterlineOrientationProbe`
apparait bien dans le `.pck` -- comme `WaterTintProbe` avant elle -- parce
que `res://.godot/uid_cache.bin` EST packe et les porte. **Aucun fichier de
`scripts/dev` n'est stocke**, ce qui est le controle qui compte ; c'est
exactement l'artefact deja consigne pour `assets_source`.
`keepy_waterline.gdshader` **est** packe, comme il le doit.

Sondes, **toutes exit 0** : `WaterTintProbe` (**48 OK, 0 echec** -- PHASE G
comprise, controle 2 251 px, pire ecart 0 px, et **98 draw nodes hors
portails**, inchange), `WaterlineOrientationProbe`, `AssetContractAudit`
(**12/12 visuels, pas un collider deplace**), `DeathModelAudit`,
`ChargerShapeProbe`, `ProbeTimeoutAudit` (**49 -> 50 sondes scenes**,
toutes armees -- le +1 est `WaterlineOrientationProbe`, et le 49 est
**MESURE sur `origin/staging` en worktree separe**, pas deduit du fait
qu'un seul `.tscn` a ete ajoute).

**Les V1-V8 du lot precedent tiennent** : PHASE A cinq corps, PHASE B les
deux marges de rim float32, PHASE C la teinte atteint le materiau DESSINE
et porte la bonne hauteur, PHASE D un ride ne teinte pas, PHASE F les trois
portails tirent encore, PHASE E 98 draw nodes.

### Deploiement staging (palier 1, automatique)

`staging` **`b9fed08`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `6bd5bde` des deux cotes ET `git diff`
vide, verifie AVANT le push). CI run **#269** (id 33083855053) **verte** --
`Deploy to Vercel [STAGING -- staging]` succes (14:47:18 -> 14:47:29),
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche**
(`origin/main` toujours `a007e78`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI, et dans les DEUX sens** :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #268) | `1787839263` | **14:01:03** |
| **apres (ce lot, run #269)** | **`1787842018`** | **14:46:58** |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build`** du run
#269 (14:46:54 -> 14:46:59), et **les DEUX lectures portent
`x-vercel-cache: MISS` avec `age: 0`**, la valeur d'avant ayant ete relevee
**avant le merge**. La bascule est donc prouvee dans les deux sens et pas
deduite du log.

⚠️ **Un SEUL marqueur, dit plutot que sous-entendu** : `index.pck` /
`index.wasm` servis n'ont pas ete relus sur le service. Le `CACHE_VERSION`
lu aux DEUX bouts en MISS/age 0 est la forme la plus forte que ce fichier
documente pour un marqueur unique, mais ce ne sont pas deux marqueurs
independants.

⚠️ **Piege de lecture rencontre, et REFUSE** : une lecture intermediaire est
revenue `HIT` avec **`age: 78`**. Elle portait encore l'ancienne valeur, ce
qui avait l'air de confirmer que le job tournait -- **ce n'est PAS une
mesure de fraicheur** et elle n'a donc rien confirme du tout. Seules les
deux lectures MISS/age 0 comptent.

⚠️ **Et l'INVERSE du piege « API Actions perimee », pour la deuxieme fois
consignee** : deux appels `list_workflow_jobs` a 30 s d'intervalle sont
revenus **byte-identiques**, figes sur « Import project resources » -- la
forme exacte du piege documente. **Ce n'en etait pas un.** L'horloge le dit :
il n'etait que 14:45, l'import avait demarre a 14:44:25, et il a reellement
dure **2 min 29 s** (14:44:25 -> 14:46:54). Verifier l'HEURE avant d'accuser
l'API reste la parade, dans les deux sens.

## L'IMPACT DANS L'EAU : une rampe de ligne de flottaison + un anneau de surface, ZERO particule (27 aout 2026)

Branche `claude/keepy-water-impact-effect-lhxhh0`, partie de `main`
(`a346912`). **UN SEUL fichier de jeu touche : `scripts/hub/HubWorld.gd`.**
`keepy_waterline.gdshader`, `HubRegion.gd`, `HubCamera.gd` et
`HubTapInput.gd` **ne sont PAS dans le diff**, verifie par
`git diff --name-only` et pas affirme.

⚠️ **ECART DE BASE SIGNALE : le lot placement N'ETAIT PAS sur `main`.**
Le brief demandait de partir de `main` « qui doit inclure le lot 3 s'il a
ete merge ». Il ne l'incluait pas : `origin/staging` etait **4 commits en
avance** avec les deux plongeoirs supplementaires (petit lac + lobe spawn),
et ce lot renomme `diving_board()` en `diving_boards()` **dans
`HubWorld.gd`**, c'est-a-dire mon fichier. Parti de `main` comme demande,
puis **`staging` merge DANS la branche feature avant la validation finale**
— donc tous les chiffres publies ici sont mesures sur l'arbre qui part,
pas sur un arbre que personne ne fera tourner. Aucun conflit : ce lot ne
touche ni `_setup_boards()` ni `_try_climb()`.

### Le declencheur : un latch, parce que le landing ne peut PAS savoir

`_on_hop_finished()` remet l'etat a `IDLE` **avant** d'emettre
`hop_landed`, et le plongeon passe par cette meme fonction volontairement
— c'est ce qui fait que la teinte d'eau et tout autre auditeur de landing
continuent de marcher a travers un plongeon sans savoir qu'un plongeoir
existe. **Un auditeur ne peut donc pas distinguer le landing d'un plongeon
de celui d'un hop ordinaire en demandant l'etat.** Le seul moyen honnete
est d'avoir ete prevenu au depart : `_dive_pending` est arme sur
`board_dived` (emis une fois dans `dive()`) et consomme dans
`_on_hop_landed`, **la ou la position ET la reponse eau sont deja en
main** — donc l'effet utilise LE MEME test d'eau que la teinte, et pas un
second qui pourrait diverger d'un float sur les cas de bord que les deux
marges de `HubWater` existent pour documenter.

Le latch est efface **quelle que soit la reponse** : un plongeon vers le
pied de l'echelle (terre ferme, l'autre cible du plongeoir) le desarme au
lieu de le laisser amorce pour le landing suivant. Gate.

### ⚠️ DEUX PREMISSES FAUSSES, ET LES DEUX ETAIENT LES MIENNES

1. **« l'uniform `water_y` ne se tweene pas ».** Mon premier run de sonde a
   rapporte `0.4500 -> 0.4500` et accuse l'uniform. **C'ETAIT LA SONDE.**
   Elle echantillonnait UN instant wall-clock a 95 % de la montee ; sous
   llvmpipe le hub tourne a ~14 fps, donc un timer de 0,0855 s et le
   premier pas de process du tween tombent sur **la meme frame**, dans un
   ordre non defini. Un `ShaderMaterial` isole pilote ce chemin de
   propriete de 0,88 a 0,48 sans broncher. Corrige en echantillonnant
   **toute la courbe** frame par frame : pic mesure **0,8172**.
   ⚠️ Le pic vaut 0,92 dans le tween ; **0,8172 est ce que
   l'echantillonnage a 14 fps attrape**, pas l'apex reel — la sonde gate
   « monte » et « ne depasse pas », pas la valeur exacte.
2. **`Object.get("UNE_CONST")` rend `null`**, silencieusement — une
   constante GDScript n'est pas une propriete. Ni erreur ni warning.
   Trouve en cherchant la cause de (1) ; ce n'etait pas la cause, mais
   c'est un vrai piege. La sonde lit desormais
   `get_script().get_script_constant_map()`.

### ⚠️ La hauteur de l'anneau, et le piege que la sonde d'isolement a attrape

Sonde jetable (supprimee avant commit) : anneau + disque d'eau seuls, 4
azimuts. **Le candidat plat rendait quasi invisible** — je l'avais pose a
`centre + 0,02` alors qu'un disque d'eau a une EPAISSEUR et que sa face
SUPERIEURE est plus haute que son centre. Il etait dessine **DANS** l'eau.

Faces superieures **MESUREES sur l'arbre construit**, pas lues dans les
constantes : **0,0270 / 0,0295 / 0,0800 / 0,0800 / 0,0950** — ce qui
reproduit exactement les cinq surfaces que le shader documente deja, et
c'est ce qui a valide le banc avant de s'en servir pour du neuf.

`SPLASH_RING_Y = 0,12` **passe au-dessus des CINQ**, et c'est une seule
inegalite qu'une sonde asserte contre l'arbre construit — ce qu'une table
par corps ne serait pas, et ce depot a deja paye pour un nombre garde dans
deux fichiers. **Le cout est reel et publie** : sur le grand lac
(surface la plus basse) l'anneau flotte **0,0930** au-dessus de l'eau, soit
6,9 % de la taille de Keepy. L'erreur est deliberement dans le sens SUR :
quelques centimetres trop haut se lit comme de l'ecume, quelques
centimetres trop bas ne se lit **pas du tout**.

### La cicatrice portee : CULL_BACK, pas CULL_DISABLED

Un tore est un **corps ferme**. La panne device du shader de flottaison
etait un materiau ecrivant ALPHA avec `cull_disabled` sur un corps ferme :
sans ecriture de profondeur, la face lointaine repeint la face proche dans
l'ordre du buffer d'indices — ordre fixe, alors que quel-cote-est-loin ne
l'est pas. Un anneau alpha a cote d'un disque d'eau alpha est le meme
voisinage. Faces arriere coupees, gate par sonde.

### Ce qui est livre

`KEEPY_SPLASH_WATERLINE_Y` 0,92 ; montee 0,09 s / descente 0,19 s
(asymetrique : un impact est un deplacement brusque puis un retour) ;
anneau `TorusMesh` **24 x 4 = 192 triangles** — stated, pas defaulted (un
`TorusMesh` laisse tranquille est 64x32 = **4096**, le piege que ce depot
a deja mesure cinq fois) ; rayon 1,15 ; ouverture 0,20 s, vie 0,34 s ;
blanc casse `rgb(0.918, 1.0, 0.988)` a 0,85.

⚠️ **AUCUN systeme de particules.** Il n'y a **pas un seul**
`GPUParticles3D` ni `CPUParticles3D` dans tout ce depot. Decision prise en
amont et non rouverte : introduire la premiere techno de rendu du projet
dans un effet que personne ne peut regarder avant staging mettrait une
techno non prouvee et un effet non prouve sur le meme commit, sans moyen
de savoir lequel des deux est en cause.

**Parente au ROOT 3D, jamais sous `Props`** : tous les comptes de draw
nodes que ce projet publie parcourent `World/Props` et rien d'autre. Un
anneau sous `Props` serait compte comme un prop pendant la fraction de
seconde ou il existe, donc le chiffre dependrait de QUAND la sonde
echantillonne.

### `WaterImpactProbe` : 24 checks, 0 echec

Gatee et pas rapportee, parce que **toute panne de ce cue est SILENCIEUSE**
— un uniform qui ne bouge pas, une rampe interrompue en haut qui laisse
Keepy trempe jusqu'aux epaules sur l'herbe pour le reste de la session, un
anneau qui fuit un noeud par plongeon. Aucune ne leve, aucune ne casse un
build, et toutes ressemblent a « l'effet n'a jamais ete branche ».

⚠️ **PHASE B ordonne ses assertions exprès** : le cas EAU est asserte
AVANT le cas TERRE, parce que « aucun anneau n'est apparu » passe
gratuitement contre un cue jamais branche. Prouver qu'il PEUT tirer est ce
qui donne le droit d'asserter qu'il n'a pas tire.

**Fuite : 20 plongeons consecutifs**, pic de 6 anneaux vivants a la fois,
**compte d'enfants du root revenu a l'identique (5 -> 5)**, 0 anneau
survivant. **Budget statique** : `Props` mesure **AVANT, PENDANT et
APRES** — 116 / 116 / 116 sur l'arbre fusionne (102 sur `main` seul, l'ecart
etant les deux plongeoirs du lot placement).

### Validation, sur l'arbre FUSIONNE

Import **exit 0, 24 `.scn`** ; boot de `HubWorld.tscn` **0 erreur** ;
export Web **exit 0, 0 ligne d'erreur**. `index.wasm` **35 376 909** / md5
**`af4a8fc2925d992348eb30deeeb54360`** et `index.js` md5
**`4e08904b1b7107858246af44b602067b`** — identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 888 448, **marqueur et jamais preuve d'identite**. Piege payload tenu :
sur 228 `Storing File`, **0** pour `scripts/dev`, `assets_source`, `docs`,
`web`, `build`.

Sondes **toutes exit 0** : `WaterImpactProbe` (24/24),
`DivingBoardProbe` (**BLIND CHECK arme et vert**), `WaterTintProbe`
(**BLIND CHECK arme : controle 2251 px, pire ecart 0 px**),
`LakeZoneProbe`, `StreamRideProbe` (37), `AssetContractAudit` (12/12
visuels, **0 collider deplace**), `DeathModelAudit`, `ChargerShapeProbe`,
`ProbeTimeoutAudit` — **51 -> 53 sondes scenes**, MESURE des deux cotes
(mes deux `.tscn` deplacees puis remises) et non deduit.

### La planche

`docs/color-sheets/water_impact_sheet.png` — 4 lignes (anneau PLAT et
anneau DEBOUT, chacun en blanc casse et en turquoise de l'eau) x 4
azimuts, plus une bande de l'effet livre a 18 / 42 / 68 / 92 % de sa vie.

⚠️ **Piege documente et dans lequel je suis tombe quand meme** : le premier
rendu avait **une seule tuile cadree sur quatre** — `HubCamera` se lerp sur
Keepy a chaque frame, donc ecrire `global_position` sans couper son
`_process` ne tient pas. Deja consigne pour ce hub ; re-consigne ici.

**Ce que la planche montre, dit franchement** : la bande LIVE se lit
nettement comme une onde qui s'ouvre ; les quatre tuiles GELEES sont
**subtiles**, et **blanc casse et turquoise y sont quasi indistinguables**
— un anneau turquoise sur de l'eau turquoise ne se separe que par l'alpha,
et le blanc casse a peine plus. Autre limite : `_set_keepy_wet(true)` y
est appele une frame avant la capture, donc le fondu de teinte de 0,18 s
n'est pas arrive — **les tuiles ne representent pas l'etat de teinte**,
seulement l'anneau.

### Reste ouvert — jugement device, seul juge

1. **Est-ce qu'un anneau qui s'ouvre en 0,34 s se lit comme une
   ECLABOUSSURE** a vitesse reelle sur un telephone ? Aucune sonde ne le
   dit, et c'est tout l'objet du lot.
2. ⚠️ **Rien ici ne prouve le rendu device.** llvmpipe / opengl3 BUREAU
   contre WebGL2 / Safari : deux compilateurs GLSL et surtout **deux
   implementations de tri des transparents**. Un anneau alpha a cote d'un
   disque d'eau alpha est exactement le voisinage ou le shader de
   flottaison etait vert dans ce sandbox jusqu'a ce qu'on le regarde sur
   un telephone **depuis un second angle**. **Test multi-azimuts
   obligatoire avant tout merge `main`.**
3. **Les 0,0930 de flottement sur le grand lac** — mesures, dans le sens
   sur, jamais juges a l'oeil.
4. **La rampe de flottaison monte a 0,92**, donc l'eau atteint brievement
   les epaules de Keepy. C'est voulu ; personne ne l'a vu bouger.
5. **La couleur et l'orientation sont un point de depart pour un appel
   device**, pas un optimum mesure — la planche existe pour etre
   redirigee, et chaque candidat est une edition de constante.

### Deploiement staging du cue d'impact (palier 1, automatique)

`staging` **`e7c54ce`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `e6c4bdc` des deux cotes ET `git diff`
vide, verifie AVANT le push). CI run **#278** (id 33117979322)
**verte** — `Import project resources` 21:24:49 -> 21:27:17, **`Export Web
build` 21:27:17 -> 21:27:22**, `Deploy to Vercel [STAGING -- staging]`
**succes**, `[PRODUCTION -- main]` correctement **skipped**. **`main` NON
touche** (`origin/main` toujours `a346912`, verifie apres le push).

**Verifie SUR LE SERVICE, pas dans le log CI** :

| | `CACHE_VERSION` | = UTC |
|---|---|---|
| avant (run #277) | `1787862057` | **20:20:57** |
| **apres (ce lot, run #278)** | **`1787866042`** | **21:27:22** |

L'epoch d'apres tombe **exactement sur la fin de l'etape `Export Web
build`** du run #278, et la lecture porte **`x-vercel-cache: MISS`,
`age: 0`**, `last-modified` colle a l'instant de la requete.

⚠️ **Honnetete sur la couverture, deux limites plutot qu'une** :
1. **La valeur AVANT vient d'un `HIT` avec `age: 3668`.** Elle est valable
   comme VALEUR — elle est anterieure au merge, donc c'est bien l'ancien
   build — mais **ce n'est PAS une mesure de fraicheur**, et elle n'est
   pas comptee comme telle.
2. **UN SEUL marqueur.** `index.pck` / `index.wasm` servis n'ont pas ete
   relus sur le service. L'`index.wasm` de l'export local vaut
   **35 376 909** / md5 `af4a8fc2925d992348eb30deeeb54360` — le
   fingerprint permanent — mais c'est une mesure locale, pas une mesure
   du service. Dit plutot que sous-entendu.

⚠️ **L'API Actions n'etait PAS perimee sur ce run, et c'est note dans ce
sens-la** : les appels successifs montraient de vraies progressions
d'etapes avec de vrais horodatages, et l'import a reellement pris
**2 min 28 s**. Le piege deja consigne existe ; il ne s'est pas produit
ici, et le verifier coute un regard a l'horloge.

