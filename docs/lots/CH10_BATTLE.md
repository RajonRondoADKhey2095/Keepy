# Keepy Battle — lots 1 à 12

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 13 section(s), 3179 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## KEEPY BATTLE, LOT 1 : squelette jouable d'un duel 1v1, ZERO asset 3D (20 aout 2026)

Branche `claude/keepy-battle-lot-1-1yys5r`, partie de `staging` (`8272dfa`,
ou `main` et `staging` etaient alignes). **Troisieme mini-jeu du hub**, apres
Chased et Quizz. Aucun fichier de Chased ni de Quizz touche : le seul fichier
existant modifie est le Hub (plus sa `.tscn`), qui gagne une troisieme carte.

**Le but de ce lot est de valider le FEEL et l'EQUILIBRAGE AVANT de depenser
un credit Meshy** : deux capsules placeholder, rien d'autre. Les assets 3D,
les animations, les sons, la persistance Firestore, la progression, plusieurs
adversaires et les effets visuels sont HORS PERIMETRE et non faits.

### Le contrat "et dans 6 mois ?" : un adversaire = UN .tres + UN .glb, ZERO ligne de code

C'est la contrainte structurante du lot, pas un objectif de style.

* **`FighterProfile`** (`scripts/battle/FighterProfile.gd`, une `Resource`)
  porte **tout** ce qui differe entre deux combattants : hp, timings
  windup/active/recovery par action, degats, ratio de garde, duree de
  stagger, les cinq parametres d'IA, et le `.glb` futur avec ses trois
  corrections `ModelSlot` (`model_scale`, `model_rotation_degrees`,
  `model_offset`) plus la couleur du placeholder.
* **`Fighter.gd` et `FighterBrain.gd` sont GENERIQUES** : aucun `match
  species`, aucune sous-classe par animal, nulle part. Deux profils livres,
  `resources/battle/keepy.tres` et `dummy.tres` ; ils ne different que par
  des nombres.
* **Le `match` de `FighterProfile.timing_for()` est le SEUL endroit du depot
  qui associe une action a ses nombres**, et il pointe vers des CHAMPS, pas
  vers des valeurs. Une quatrieme action toucherait cette fonction et les
  exports au-dessus, rien d'autre.

### UNE seule FSM, partagee joueur et IA -- ce n'est pas une preference de style

Etats : `IDLE / WINDUP / ACTIVE / RECOVERY / STAGGER / KO`. Il n'y a pas de
"fighter joueur" et pas de "fighter IA" : il y a un `Fighter`, et quelque
chose qui appelle `request_action()` dessus. Le tap humain (les trois zones
du HUD) et le selecteur d'intention (`FighterBrain`) entrent par **la meme
fonction** et sont indiscernables ensuite.

⚠️ **La raison est un mode de panne, pas de l'elegance** : une IA qui fait
tourner son propre systeme avec ses propres timings est une IA qu'on peut
equilibrer contre des regles que le joueur ne joue pas, et la divergence
reste invisible jusqu'a ce que quelqu'un la mesure -- exactement le defaut
`SubstituteModel.tscn` deja consigne dans ce fichier. **PHASE E de la sonde
pointe le brain sur le fighter du JOUEUR et exige un vrai combat**, donc la
reciprocite est exercee et pas affirmee.

### Determinisme : ticks fixes accumules, RNG seede explicitement

`BattleArena` avance les deux fighters ET le brain par pas entiers de
`TICK_S = 1/60`, sortis d'un accumulateur -- jamais le `delta` brut de la
frame. Sur telephone le temps de frame est ce que le navigateur veut bien
donner, et une FSM avancee par ce delta a des frontieres de phase qui
tombent sur des frames differentes d'un run a l'autre : deux combats
identiques divergent, et « est-ce que cet enchainement est vraiment
imparable ou est-ce que j'ai eu une frame longue » devient sans reponse.

⚠️ **`_physics_process` donnerait aussi un pas fixe et a ete ECARTE** : il
lie le rythme du combat a un reglage projet qui appartient a Chased, donc un
changement la-bas re-equilibrerait ce jeu en silence.

**Aucun `randi()` global nulle part dans `scripts/battle/`** : un seul
`RandomNumberGenerator`, seede `base_seed + numero de round`.

⚠️ **`BattleArena` parse `--seed=` EN LIGNE au lieu d'appeler
`DevSeed.seed_value()`, qui fait exactement ca -- piege trouve en ecrivant
le lot, pas apres coup.** `export_presets.cfg` porte `scripts/dev/*` dans
son `exclude_filter`, donc `DevSeed` **n'est pas dans le pack livre**. Une
reference `class_name` depuis un script livre resout dans l'editeur ET en
headless, puis echoue **uniquement dans le build web** -- le seul endroit
que personne ne peut verifier. Verifie sur le `.pck` exporte : les deux
seules occurrences de `DevSeed` y sont dans le cache de classes globales
(qui liste deja d'autres classes `dev` sur `main` aujourd'hui), aucune
depuis `scripts/battle/`.

### Resolution des coups : du timing pur, aucune hitbox 3D

Un coup se resout UNE fois, au premier tick de la fenetre `ACTIVE` de
l'attaquant, contre l'etat du defenseur a cet instant :

| defenseur | resultat |
|---|---|
| `GUARD` en `ACTIVE` | **BLOQUE** : degats x `guard_damage_ratio` (0,25), **pas de stagger** |
| `DODGE` en `ACTIVE` | **ESQUIVE** : zero degat |
| tout le reste, **y compris `ATTACK` en `ACTIVE`** | **TOUCHE** : degats pleins + stagger |

La derniere ligne est la regle qui empeche les deux combattants de simplement
marteler l'attaque : **les frames actives d'une attaque ne defendent pas**,
donc celui qui s'engage en second encaisse l'echange. Le stagger (0,55 s) est
plus long que n'importe quelle recovery : etre touche DOIT etre pire que
rater.

La resolution vit dans `BattleArena`, **une seule fois** : un `Fighter`
annonce `strike_activated` et ne sait rien de qui est en face. Aucun des deux
ne detient de reference vers l'autre.

### Controles : TAP UNIQUEMENT, trois zones fixes, aucun geste

Trois boutons larges en bas d'ecran, rien d'autre. **Pas de swipe**, pour
deux raisons independantes : Chased possede deja le swipe comme geste de
changement de voie, donc le meme mouvement voudrait dire deux choses dans une
seule app ; et un swipe horizontal sur iOS Safari est en concurrence avec la
navigation arriere du navigateur, ce qu'une page ne gagne pas de facon fiable.

⚠️ **Les boutons restent ACTIFS pendant un engagement** au lieu de se griser :
`Fighter` bufferise un tap anticipe pendant `INPUT_BUFFER_S` (0,16 s) et le
rejoue au retour a `IDLE`, donc un tap « trop tot » est un input reel qui
fonctionne. Le griser jetterait une pression que le jeu allait honorer, et
ferait clignoter le panneau plusieurs fois par seconde.

`INPUT_BUFFER_S` est une constante de JEU et **deliberement pas un export par
profil** : c'est une propriete des controles, identique pour tout le monde ;
laisser deux combattants ne pas etre d'accord dessus serait deux jeux.

### Le point d'echange lot 3 est deja ecrit

Chaque fighter porte un noeud `Body` de type **`ModelSlot`**
(`scripts/world/ModelSlot.gd`), exactement comme `$Silhouette` de
`Pursuer.tscn`. Installer un `.glb` au lot 3 = poser `model_scene` (+ les
trois corrections) **dans le `.tres`**. Aucun noeud n'est ajoute, deplace,
renomme ni supprime, donc rien dans `Fighter.gd`, `BattleArena.gd` ou le HUD
n'a a etre re-pointe. `Fighter._apply_profile_art()` est le hand-off complet
et il est deja la.

⚠️ **Le tint du placeholder et l'install du `.glb` passent par le MEME chemin
de code** (`ModelSlot.apply_material()`, qui atteint les surfaces du modele
installe une fois qu'il existe) : un futur `.glb` herite du traitement
couleur du profil au lieu d'avoir besoin d'une seconde branche que personne
n'exerce. Materiaux **unshaded**, comme toute surface de ce projet.

### `SafeArea.fill_screen()` ici, `keep_game_framing()` chez Chased

Battle appelle `fill_screen()` comme les ecrans d'UI. Contrairement a
`Game.tscn` -- qui redemande `KEEP` parce que le budget de reaction de Chased
est cale sur un cadrage 9:16 -- Battle n'a **aucun monde defilant et aucun
budget lie a la distance** : les deux combattants sont a des marques fixes,
donc un viewport plus haut montre plus de ciel vide et ne change rien de
jouable.

⚠️ **La camera est en `keep_aspect = KEEP_WIDTH` (0), et c'est OBLIGATOIRE
ici, pas cosmetique.** En `KEEP_HEIGHT` (le defaut), le viewport plus haut
que produit `fill_screen()` **retrecit l'etendue horizontale** et les deux
combattants sortaient du cadre par les cotes. **Mesure sur la scene
construite, aux deux ratios** : etendue horizontale **identique** a 1080x1920
et 1170x2532 (x 95..985 des deux cotes), combattants degages de la barre du
haut ET de la rangee de boutons. Panneau du Hub a trois cartes : les trois
boutons a l'ecran, marge basse **128 px** en 9:16 et **228 px** sur device.

### La sonde a trouve un defaut REEL de mesure -- dans la sonde, pas dans le jeu

`scripts/dev/BattleContractProbe.tscn` (nouvelle, **36 checks, 0 echec**)
gate l'ordre et la duree des phases, la matrice de resolution complete, le
buffer d'input, et le determinisme. Elle pilote les **scripts livres**,
jamais un stub.

⚠️ **PHASE F a d'abord rapporte « le profil Keepy perd 40 fois sur 40 », et
ce chiffre ne mesurait PAS un desequilibre.** Elle ne faisait tourner un
brain que du cote adversaire -- fidele a l'arene reelle, ou l'autre cote est
un humain -- donc le fighter Keepy **ne faisait rien du tout** : un sac de
frappe immobile perd. Un chiffre profil-contre-profil demande les deux cotes
joues (`mirrored`). **Un balayage jetable a ete ecrit pour trancher plutot
que de raisonner** : a profils symetriques le resultat est ~30/60 (equilibre),
et une reaction ou un windup plus rapides **GAGNENT** (54/60, 53/60) --
l'inverse de l'hypothese de depart, qui etait que s'engager en premier
punissait. La sonde a ete corrigee, le balayage supprime avant commit.

⚠️ **Deuxieme correction dans la sonde, meme famille** : l'assertion de duree
par phase comparait a `ceil(secondes / tick)` et ignorait le report
d'overshoot que `Fighter.advance()` fait DELIBEREMENT d'une phase a la
suivante. Sans ce report chaque phase arrondirait vers le HAUT et une action
a trois phases durerait jusqu'a trois ticks de trop, differemment selon le
combattant. **L'assertion exacte porte donc sur le TOTAL** (47 ticks pour
47 nominaux) et laisse **un tick** de jeu par phase, borne parce que le
report est reapplique a chaque transition et ne s'accumule jamais.

### Equilibrage mesure, pas ressenti -- et volontairement NON gate

Trois iterations, chacune remesurees sur 40 combats seedes :

| | hp | resultat |
|---|---|---|
| depart | 100 | rounds **30,1 s** de moyenne -- trop long pour du mobile |
| apres reduction hp + resserrage du profil adverse | 60 | 39/40, **walkover** |
| **livre** | **50** | **31/40 (~78 %), moyenne 16,1 s** (min 8,0 / max 32,9) |

**PHASE F rapporte et n'asserte RIEN**, deliberement : ce qu'est un combat
juste est un jugement device, et un nombre gate ici serait un nombre regle
jusqu'a ce qu'il passe au vert -- le faux-vert que `ProbeCoverage.gd`
documente cinq fois. Retoucher l'equilibrage est une edition de `.tres`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles ; taille confirmee contre le `Content-Length`, le piege de
troncature silencieuse deja consigne). Import headless **exit 0**, export Web
release **exit 0**, boot headless de `Battle.tscn` / `BattleHUD.tscn` /
`BattleFighter.tscn` / `Hub.tscn` (`--quit-after 2`) **tous exit 0**, aucune
erreur de parse. `index.wasm` **35 376 909 octets** -- identique au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur.
`index.pck` 5 740 640 octets (export unique et propre, `build/` supprime
avant -- a lire avec la mise en garde permanente sur son instabilite).

Sondes : `BattleContractProbe` (**36/36**), `ProbeTimeoutAudit` (**34 sondes
scenes**, la nouvelle comprise, toutes armees -- 33 avant ce lot),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**. Piege payload
tenu : **0** ligne `Storing File` pour `res://scripts/dev`, `res://assets_source`,
`res://docs` ou `res://web`.

### Dette et reste ouvert

1. **Jugement device, et c'est tout l'objet du lot** : est-ce que le duel se
   lit et se joue bien au pouce sur un telephone -- lisibilite des trois
   zones, longueur des rounds, et surtout **si le windup de l'adversaire est
   assez telegraphie pour etre lu**. Aucune sonde ne le dit.
2. **DETTE ASSUMEE : les combattants ne bougent pas.** Le retour d'etat est
   porte **entierement par le HUD** (libelle d'etat par combattant + verdict
   du coup) ; les capsules sont statiques. Les effets visuels sont hors
   perimetre de ce lot, mais c'est le manque le plus probable a remonter du
   test device -- un `WINDUP` sans mouvement se lit mal a vitesse reelle. Le
   correctif naturel (une amorce de fente sur `WINDUP`/`ACTIVE`) appartient
   au lot animation, pas a une rustine ici.
3. **Un seul adversaire**, `dummy.tres`, nomme « Sparring ». Le second est un
   `.tres` de plus ; il n'y a pas d'ecran de selection, et il n'y en avait pas
   dans le perimetre.
4. **Aucune persistance** : ni score, ni progression, ni Firestore. Un round
   perdu ou gagne ne laisse aucune trace.
5. **`ai_defense_rate` est le vrai bouton de difficulte**, plus que les
   degats : le balayage montre la duree moyenne d'un round passer de 25 s a
   44 s quand il va de 0,0 a 0,8, a profils par ailleurs identiques.

## KEEPY BATTLE, LOT 2 : rendre le combat LISIBLE, toujours ZERO asset 3D (20 aout 2026)

Branche `claude/keepy-battle-readability-erclyi`, partie de `staging`
(`06c94f1`). Ferme la **dette 2 du lot 1** (« les combattants ne bougent
pas »), qui etait le blocage numero un remonte du test device. Toujours
aucun asset 3D : ce lot anime les capsules placeholder, et c'est
deliberement l'ordre choisi -- prouver qu'un duel de ce type se lit au
pouce AVANT de depenser un credit Meshy.

### Ce que la mesure a dit, et pourquoi les deux hypotheses de depart etaient a cote

Le brief posait deux hypotheses a departager par instrumentation. Aucune
des deux n'etait la bonne, et c'est le resultat le plus utile du lot.
Mesure headless sur les scripts LIVRES, avant d'ecrire une ligne :

| hypothese | verdict |
|---|---|
| **H1** le HUD ne s'abonne pas a `WINDUP` | **FAUX**. Il s'y abonne, et il l'affiche : sequence `Attaque - Prepare` -> `Attaque - Actif` -> `Attaque - Recupere` -> `Pret`, avec **19 ticks = 317 ms** passes sur « Prepare ». Le libelle n'a jamais ete desynchronise. |
| **H2** le `WINDUP` est trop court pour etre lu | **FAUX tel quel**. 317 ms n'est pas un telegraphe court -- c'est un telegraphe **invisible** : rien sur les combattants ne bougeait a aucun moment de l'attaque. |

**Le defaut n'a jamais ete « le HUD est en retard ». Il etait que les
combattants etaient muets**, et qu'un libelle de 26 px en haut de l'ecran
ne sera jamais un telegraphe quand le regard est sur deux capsules au
milieu. C'est la conclusion qui a dicte tout le lot.

Les deux captures device s'expliquent alors exactement, et par des causes
DIFFERENTES l'une de l'autre :

* **« Sparring : TOUCHE » affiche pendant que Sparring dit « Pret »** :
  `FLASH_S` valait **700 ms**, alors qu'un attaquant reste engage
  `active + recovery` = **480 ms** (Keepy) / **540 ms** (Sparring) apres
  la resolution de son coup. Le verdict **survivait a l'action qui l'avait
  produit de 160 ms**. Ni l'un ni l'autre des deux affichages n'etait faux
  -- le verdict est un rapport RETARDE, le libelle d'etat un rapport
  INSTANTANE -- mais ensemble ils se contredisent et le joueur n'a aucun
  moyen de savoir lequel croire.
* **« Attaque - Actif » a l'ecran de KO** : un coup se resout dans le
  PREMIER tick `ACTIVE` de l'attaquant, donc le perdant tombe a 0 hp sur
  ce tick-la et `BattleArena` arrete l'horloge immediatement. La FSM du
  vainqueur est **reellement figee en `ACTIVE`** et n'en sortira jamais.
  Le libelle disait la verite sur une simulation arretee.

### Le telegraphe vit sur le combattant, dans `FighterView.gd`

Un noeud `View` par combattant, enfant direct du `Fighter` dans
`BattleFighter.tscn`. **Strictement en LECTURE SEULE sur la FSM** : il
n'appelle jamais `request_action()` ni `advance()`, n'ecrit aucun champ, et
ne lit un etat que pour choisir quelle animation jouer.

| etat | ce que le joueur voit |
|---|---|
| `IDLE` | respiration lente (bob 4,5 cm), pour qu'un ecran au repos ne soit jamais mort |
| `WINDUP` (attaque) | **recul progressif + teinte qui monte vers le rouge, sur TOUTE la duree de la phase** |
| `WINDUP` (garde/esquive) | meme amorce, 3x plus discrete, **et aucune teinte** |
| `ACTIVE` attaque | fente nette vers l'adversaire (60 ms) |
| `ACTIVE` garde | encaissement bas et large (`scale.y` 0,86) |
| `ACTIVE` esquive | glissade en arriere + inclinaison |
| `RECOVERY` | retour au neutre sur la duree REELLE de la phase, donc **toujours plus lent que la fente** |
| `STAGGER` | recul profond puis oscillation amortie |
| `KO` | bascule a -82 deg, corps pose au sol |
| impact | flash **sur le combattant TOUCHE** : blanc si `HIT`, bleu froid si `BLOCKED`, **rien si `DODGED`** |

⚠️ **La couleur ne veut dire QU'UNE chose : danger entrant.** Seul un
`WINDUP` d'ATTAQUE monte vers `ALERT_COLOR`, et **progressivement**, avec
un `EASE_IN` -- l'intensite EST l'horloge que le defenseur lit. Garde et
esquive se distinguent par la SILHOUETTE, jamais par la teinte. Un
telegraphe qui partage son canal avec deux actions inoffensives est un
telegraphe qu'il faut decoder au lieu de le voir.

### Pourquoi ca anime `$Body` (le `ModelSlot`) et jamais la geometrie de la capsule

Chaque tween ecrit `position` / `rotation_degrees` / `scale` **sur le
`ModelSlot`**, et la teinte passe par `ModelSlot.apply_material()`. C'est
le contrat deja etabli du projet (`Obstacle.gd` anime deja un slot de
cette facon), et c'est ce qui rend le **lot 4 gratuit** : un `.glb`
installe dans le slot est un ENFANT du noeud que ces tweens deplacent,
donc il herite de toutes les animations sans une ligne a changer.

La teinte est le seul point qui demandait du soin a travers ce swap, et il
est traite : `_ensure_material()` **DUPLIQUE** ce que le slot dessine avant
d'y toucher (l'importeur glTF lie UN materiau partage sur le mesh -- le
mutter tinterait toutes les instances du `.glb` a la fois), et n'ecrit que
`albedo_color`, qui **MULTIPLIE** une texture d'albedo au lieu de la
remplacer. Un modele texture garde sa texture et rougit quand meme.

### Le determinisme, prouve deux fois plutot qu'affirme

**`BattleContractProbe` est BYTE-IDENTIQUE au lot 1**, meme md5 de sortie
complete (`8138c3b3e7b2493cab0f2a26c354efd4`), 36/36, avec les vues
attachees et vivantes.

⚠️ **Il n'y a PAS de bypass headless dans `FighterView`**, et c'est
delibere : sauter la couche d'animation sur une sonde headless voudrait
dire que la sonde n'exerce jamais le fichier dont toute la promesse est
qu'il ne peut pas modifier un combat -- la branche qui a le plus besoin
d'etre prouvee serait la seule ou aucune sonde n'entre. La sonde tourne
avec les tweens vivants et doit quand meme sortir la meme trace.

`BattleReadabilityProbe` (**29/29**, nouvelle) ajoute ce que la sonde de
contrat ne peut pas voir :

* **PHASE A** : le `+Z` local des deux combattants pointe bien vers
  l'adversaire, **lu dans `Battle.tscn` via `SceneState`** (dot = 1,000
  des deux cotes) et non suppose -- une rotation retournee dans la scene
  ferait partir toutes les fentes a l'envers sans que rien n'echoue. Elle
  verifie aussi que **deux fentes simultanees (0,60) ne peuvent pas
  s'interpenetrer** (1,10 entre les surfaces).
* **PHASE B** : le MEME combat, meme seed, joue une fois sans frame entre
  les ticks et une fois **avec une vraie frame entre chaque tick** (donc
  tous les tweens avancent pour de bon) -> **trace byte-identique, 666
  ticks des deux cotes**. C'est la preuve que le temps moteur ne fuit pas
  dans la FSM.
* **PHASE C** : le recul passe de 0,011 a 0,110 entre 27 % et 80 % du
  windup, et la teinte de `g=0,630` a `g=0,395` -- la lisibilite CROIT,
  elle ne claque pas.
* **PHASE D** : attaque `+0,300`, esquive `-0,280`, garde `x0,86` en
  hauteur -- trois silhouettes distinctes.
* **PHASE E** : 25 actions avortees coup sur coup laissent **3 tweens
  vivants**, pas 75 ; et un KO en pleine fente gagne sur la fente.
* **PHASE F** : les deux contradictions du HUD, en assertions.

### Les deux corrections HUD, chacune adossee a un chiffre

* **`FLASH_S` 0,70 -> 0,45 s.** Sous les deux durees d'engagement mesurees
  (480 / 540 ms), donc un verdict ne peut plus survivre a l'action qui l'a
  cause, quel que soit le combattant. ⚠️ **C'est une constante de
  PRESENTATION du HUD, pas un timing de combat** : aucune valeur
  windup/active/recovery/stagger d'aucun `.tres` n'est touchee par ce lot.
* **`show_result()` remplace les deux libelles d'etat** par « Vainqueur »
  et « K.O. ». Une fois le round fini, un affichage de phase EN COURS
  sous-entend un combat qui tourne encore ; la seule chose honnete que ces
  deux lignes peuvent dire est comment ca s'est termine. Elles repartent en
  affichage de phase au round suivant, `Fighter.reset()` emettant `IDLE`
  avant `show_fight()`.

### `settle()` : une consequence visuelle du gel de la simulation

`_running = false` tombe sur le tick du KO, c'est-a-dire le tick ou le
VAINQUEUR est entre en `ACTIVE`. Sa FSM n'emettra plus jamais de
transition, donc sans intervention sa vue tiendrait la fente gagnante,
indefiniment, a cote du panneau de resultat -- qui fait **600x440 sur un
ecran 1080x1920 et ne couvre aucun des deux combattants**. `BattleArena`
appelle donc `settle()` sur les deux vues a la fin du round : elle ramene
au repos un combattant debout et **laisse volontairement au sol celui qui
est K.O.**, sa chute ETANT le resultat qu'on montre.

### Une seule addition a `Fighter.gd`, en lecture seule

`phase_duration()` (+ `_phase_total`) : la longueur PLEINE de la phase
courante. Purement additif, aucun branchement dessus, aucun changement de
comportement -- la sonde de contrat byte-identique le prouve. Elle existe
pour que la vue anime un windup sur **exactement** sa duree sans
re-deriver le `match` action -> timings de `FighterProfile`, qui doit
rester le seul du depot.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox. Import
headless **exit 0**, export Web release **exit 0**, boot headless de
`Battle.tscn` **0 erreur**. `index.wasm` **35 376 909 octets** -- identique
au fingerprint deja consigne (aucun code moteur touche). Piege payload
tenu : **0** ligne `Storing File` pour `res://scripts/dev` ;
`scripts/battle/FighterView.gdc` bien present dans le `.pck`.

Sondes : `BattleContractProbe` **36/36 et byte-identique au lot 1**,
`BattleReadabilityProbe` **29/29**.

### Dette et reste ouvert

1. **Le jugement device reste entier, et c'est le point du lot.** Aucune
   sonde ne dit que 317 ms de windup suffisent A L'OEIL une fois le
   telegraphe visible. **Chiffre mesure a garder sous la main pour le lot
   3 : `attack_windup_s` = 0,30 (Keepy) / 0,31 (Sparring), soit 19 ticks.
   Si le test device dit que c'est encore trop serre, la valeur a essayer
   est 0,40-0,45 s** -- mais **le tuning n'est PAS fait ici**, deliberement :
   calibrer a l'aveugle contre un telegraphe qu'on ne voyait pas n'aurait
   rien mesure.
2. **La teinte suppose un `StandardMaterial3D`.** Un futur asset a
   `ShaderMaterial` perdrait la rampe rouge (et seulement elle : tout le
   telegraphe de transformation continue de se lire). `_tint_to()` devient
   un no-op silencieux dans ce cas, par construction.
3. **Les tweens tournent en temps MOTEUR, la FSM en pas fixes.** Les deux
   peuvent deriver d'une frame, et c'est autorise **precisement parce que**
   rien ne traverse de la vue vers la FSM. Ne jamais brancher un retour de
   la vue vers le combat, c'est ce qui ferait du framerate une entree du
   duel.
4. **Toujours aucun son, aucun asset 3D, aucune particule, aucune
   persistance** -- hors perimetre, inchange depuis le lot 1.

## KEEPY BATTLE LOT 3 : REGLAGE DE DIFFICULTE — 74 % -> 55 % de victoires, deux nombres dans un seul `.tres` (20 aout 2026)

Branche `claude/keepy-battle-lot3-tuning-3j5x3j`, partie de `staging`
(`903ea2f`). **Un seul fichier de jeu touche : `resources/battle/dummy.tres`,
deux valeurs.** Aucune ligne de code de gameplay, aucune scene, aucun
collider, aucun `.glb`. Retour device du lot 2 : le combat est lisible
(Mathieu voit venir l'attaque et a le temps de repondre) mais **beaucoup
trop facile**.

```
ai_aggression  0.55 -> 0.70     l'adversaire attaque plus souvent
attack_damage  11   -> 13       et chaque erreur coute plus cher :
                                5 coups propres pour un K.O. -> 4
```

### ⚠️ LE PIEGE DU LOT 1 EST RE-PROUVE, PAS SUPPOSE

Une mesure ou le brain ne tourne que d'un cote mesure un **sac de frappe**.
Verifie explicitement avant de croire le moindre chiffre, sur les memes
graines :

| cablage | victoires Keepy | actions/combat gauche | droite |
|---|---|---|---|
| un seul brain | **0/40 = 0 %** | **0,0** | 9,2 |
| **MIRROIR (les deux pilotes)** | **31/40 = 78 %** | **13,1** | 12,4 |

⚠️ **`BattleArena` ne fait tourner un brain QUE sur l'adversaire**
(`_brain.setup(opponent, ...)`) : les champs `ai_*` de **`keepy.tres` sont
MORTS dans le jeu livre** et ne servent que de joueur-etalon a la sonde.
**Les regler deplacerait l'etalon, pas le jeu** — `keepy.tres` est donc
intouche, et doit le rester.

⚠️ **Le chiffre du lot 1 (« ~78 %, 16,1 s ») est du BRUIT D'ECHANTILLONNAGE
a 40 combats.** Reproduit ici a l'identique (31/40, 16,11 s) puis remesure
a 150 combats sur deux bases de graines : **73,7 % (221/300)**. A n=40,
l'ecart-type binomial est de ~8 points. **Ne jamais conclure d'un seul
lot de 40.**

### AXE A — DEFENSE de l'adversaire (`ai_defense_rate`), 40 combats/point

| valeur | victoires Keepy | moyenne | min | max |
|---|---|---|---|---|
| 0,00 | 85 % | 11,7 s | 5,7 | 18,8 |
| 0,20 | 88 % | 13,1 s | 6,9 | 19,7 |
| 0,40 | 82 % | 14,5 s | 8,0 | 25,2 |
| **0,60 (livre)** | **78 %** | **16,1 s** | 8,0 | 32,9 |
| 0,80 | 60 % | 18,4 s | 8,2 | 32,9 |
| 1,00 | 45 % | **19,2 s** | 8,2 | 33,5 |

**L'axe A ALLONGE les rounds** exactement comme le lot 1 l'annoncait, et
c'est ce qui le disqualifie comme levier principal : le seul point qui
atteint la cible de victoires (0,80 -> 60 %) coute **18,4 s de moyenne**,
au bord du plafond de 20 s. **Non utilise, meme en appoint** — mesure a
l'appui : `def 0,70` en plus du reglage retenu ne gagne que 5 points de
difficulte pour +0,6 s (50,0 % / 14,5 s contre 55,0 % / 13,9 s).

### AXE B — AGRESSIVITE de l'adversaire, 40 combats/point

| `ai_reaction_delay_s` | victoires | moyenne | | `ai_aggression` | victoires | moyenne |
|---|---|---|---|---|---|---|
| 0,36 (livre) | 78 % | 16,1 s | | 0,55 (livre) | 78 % | 16,1 s |
| 0,30 | 60 % | 17,2 s | | 0,65 | 62 % | 15,8 s |
| 0,24 | 25 % | 16,3 s | | 0,75 | 52 % | 14,9 s |
| 0,18 | 30 % | 13,7 s | | 0,85 | 42 % | 14,9 s |
| 0,12 | 15 % | 12,3 s | | 0,95 | 35 % | 13,4 s |
| 0,06 | 8 % | 10,5 s | | | | |

⚠️ **`ai_reaction_delay_s` est une FALAISE, pas une pente** : 78 % a 0,36,
60 % a 0,30, **25 % a 0,24**. Toute la plage jouable tient dans 6
centiemes de seconde, et la non-monotonie 0,24 -> 0,18 (25 % -> 30 %)
montre que le bruit domine deja. **Levier ecarte : increglable finement.**
`ai_reaction_jitter_s` a le meme defaut (0,30 -> 78 %, 0,06 -> 38 %).

| `attack_damage` | victoires | moyenne | | `attack_recovery_s` | victoires | moyenne |
|---|---|---|---|---|---|---|
| 11 (livre) | 78 % | 16,1 s | | 0,42 (livre) | 78 % | 16,1 s |
| 13 | 70 % | 15,5 s | | 0,38 | 75 % | 16,2 s |
| 15 | 60 % | 14,7 s | | 0,34 | 78 % | 15,5 s |
| 17 | 55 % | 13,6 s | | 0,30 | 72 % | **INTERDIT** |
| 19 | 52 % | 13,4 s | | | | |

⚠️ **`attack_recovery_s` est REFUSE deux fois** : c'est un **levier nul**
(78 % a 0,42 comme a 0,34), et `BattleReadabilityProbe` PHASE F gate
`BattleHUD.FLASH_S` (450 ms) sous le plus court
`attack_active_s + attack_recovery_s` des deux profils. **Plancher dur a
0,33 s** — en dessous, le verdict « TOUCHE » survit a l'action qui l'a
produit et la sonde passe au rouge. La marge est de 30 ms et le profil
contraignant est **Keepy** (480 ms), pas l'adversaire (540 ms).

### ⚠️ `attack_windup_s` : REFUSE, et la mesure dit pourquoi

Reste a **0,30 (Keepy) / 0,31 (adversaire)**, la valeur validee sur device
au lot 2. Le raccourcir est le seul levier qui **defait le lot 2** : il
achete de la difficulte en rendant le telegraphe illisible au pouce. La
direction est confirmee par la mesure — monter le windup de l'adversaire a
**0,34 rend le combat PLUS FACILE (88 %)**, donc le descendre le durcit,
et c'est exactement pour cette raison qu'on n'y touche pas.

### ⚠️ `attack_damage` n'est PAS l'escalier arithmetique qu'il parait — mesure, pas deduit

Avec `max_hp = 50` et un chip de `ceil(dmg x 0,25)`, le nombre de coups
propres pour un K.O. est un escalier a trois marches : **11-12 -> 5 coups**,
**13-16 -> 4 coups**, **17-20 -> 3 coups**. L'arithmetique predit donc que
13 et 16 sont indiscernables. **C'est FAUX, et la mesure l'a attrape avant
qu'on l'ecrive comme un fait** : `dmg 13` donne **55,0 %** et `dmg 16`
**46,3 %** (300 combats chacun, meme marche de l'escalier). Le chip
s'accumule ENTRE les coups propres, donc `3 propres + 1 chip` tue a 16
(48+4=52) et pas a 13 (39+4=43). L'escalier gouverne le cas pur, pas le
cas mixte.

### CONFIGURATION RETENUE — 300 combats, deux bases de graines

Les combinaisons **se multiplient** : tous les candidats empiles au premier
jet ont depasse la cible (le plus doux deja a 25 %). La cible s'atteint avec
des mouvements **doux**, pas cumules.

| config | base 20260820 | base 31415926 | **poolee (300)** | moyenne |
|---|---|---|---|---|
| lot 2 livre (temoin) | 71 % | 77 % | **73,7 %** | 16,2 s |
| dmg13 seul | 64 % | 67 % | 65,3 % | 15,2 s |
| **aggr 0,70 seul** *(un cran PLUS FACILE)* | 60 % | 67 % | **63,7 %** | **15,0 s** |
| aggr 0,75 seul | 54 % | 59 % | 56,7 % | 14,7 s |
| aggr 0,65 + dmg13 | 52 % | 59 % | 55,7 % | 14,2 s |
| **aggr 0,70 + dmg13 — LIVRE** | **53 %** | **57 %** | **55,0 %** | **13,9 s** |
| **aggr 0,75 + dmg13** *(un cran PLUS DUR)* | 48 % | 50 % | **49,0 %** | **13,5 s** |
| aggr 0,70 + dmg13 + def 0,70 | 50 % | 50 % | 50,0 % | 14,5 s |

**Livre : `ai_aggression = 0.7`, `attack_damage = 13` — 55,0 %, moyenne
13,9 s, max 23,5 s.** Au centre de la cible 50-60 %, largement dans les
12-20 s, et **l'ordre des candidats est stable sur les deux bases** : la
valeur n'est pas ajustee a une graine.

**LES DEUX VOISINS SONT DES EDITIONS D'UN SEUL CHAMP, deja mesurees** —
Mathieu ajuste apres son test device sans relancer de sweep :

* **un cran plus facile** : `attack_damage` **13 -> 11** => 63,7 %, 15,0 s
* **un cran plus dur** : `ai_aggression` **0.7 -> 0.75** => 49,0 %, 13,5 s

### Validation

`BattleContractProbe` **36 checks, 0 failure, exit 0** (sa PHASE F rapporte
desormais **22/40 = 55 %, moyenne 13,85 s, max 23,53 s** — elle reproduit
au chiffre pres la prediction du sweep pour cette config a cette base, ce
qui valide que le banc d'essai jetable et la sonde livree mesuraient bien
la meme chose). `BattleReadabilityProbe` **29 checks, 0 failure, exit 0**,
**stderr BYTE-IDENTIQUE**. `ProbeTimeoutAudit` **exit 0, 35 sondes**
(retour exact a la baseline apres retrait des sondes jetables). Import
headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909 octets** — le fingerprint deja consigne pour tout lot qui ne
touche pas le code moteur. Piege payload tenu (**0** ligne `Storing File`
pour `assets_source`/`docs`/`web`).

⚠️ **LE BYTE-IDENTIQUE BOUGE, et c'est la consequence ATTRIBUEE du reglage,
pas une regression.** Le diff stdout de `BattleReadabilityProbe` fait
**exactement 3 lignes**, toutes le meme fait (le combat de la PHASE B dure
666 -> 371 ticks, trace 9238 -> 5192 caracteres) ; **la PHASE F, celle qui
gate FLASH_S, est byte-identique** puisque ni `attack_active_s` ni
`attack_recovery_s` n'ont bouge. Attribue champ par champ plutot
qu'affirme (sonde jetable, supprimee avant commit) :

| variante | ticks | **coups propres encaisses** |
|---|---|---|
| baseline lot 2 (dmg11, aggr 0,55) | 666 | **5** |
| **damage seul** (dmg13) | 582 | **4** — la marche 5 -> 4 |
| **agressivite seule** (aggr 0,70) | 462 | **5** — memes coups, plus tot |
| livre lot 3 | 371 | **4** — les deux se composent |

Chaque champ deplace exactement la quantite qu'il doit deplacer, les deux
se composent, et la ligne baseline **reproduit 666 ticks / 9238 caracteres
au caractere pres** — ce qui valide le banc d'attribution lui-meme. Rien
n'est inexplique.

### Reste ouvert

1. **Jugement device, seul juge** : aucune sonde ne dit qu'un combat a 55 %
   est AGREABLE. Et le chiffre est un **proxy** — c'est un profil pilote
   par l'IA qui joue le role du joueur, pas Mathieu au pouce. Un humain qui
   lit le telegraphe fera mieux que l'etalon ; un humain distrait fera pire.
   Les deux voisins ci-dessus existent pour ca.
2. **Asymetrie assumee** : l'adversaire tue en **4** coups propres, Keepy en
   **5** (son `attack_damage` de 12 est intouche). C'est le sens voulu d'un
   durcissement, mais c'est reel et non maquille.
3. **Le plancher de difficulte atteignable par `.tres` seul est ~45 %** :
   meme `ai_defense_rate = 1,0` ne descend qu'a 45 %, et les leviers qui
   vont plus bas sont soit interdits (windup), soit increglables (delay).
   Un adversaire nettement plus dur demanderait du CODE — un brain qui lit
   les habitudes du joueur — et donc son propre lot.

### Deploiement staging du lot 3 (palier 1, automatique)

`staging` `064e148`, CI run **#168** (id `32409539500`) **verte en 3 min 22 s**
— `Deploy to Vercel [STAGING -- staging]` **succes**,
`[PRODUCTION -- main]` correctement **skipped**. Alias confirme dans le log :
`Success! https://keepy-staging.vercel.app now points to
https://keepy-crpgv8n8c-rajonrondoadkhey2095s-projects.vercel.app`.
`main` **non touche** (palier 2, gate Mathieu).

⚠️ **LA VERIFICATION SUR LE SERVICE A FINALEMENT ETE FAITE — mais en
DEUXIEME temps, et le premier temps merite d'etre garde.** Au moment du
deploiement, les DEUX canaux qui permettent de respecter la regle « jamais le
log CI seul » etaient absents : egress direct bloque (`keepy-staging.vercel.app`,
l'URL de preview et meme `vercel.com` rendent tous `000`, CONNECT refuse par le
proxy — teste, pas suppose) et aucun outil MCP Vercel charge dans la session.
Le trou a donc ete consigne comme tel plutot que comble par le log. Un canal
Vercel est apparu plus tard dans la meme session, et la verification a ete
faite pour de vrai :

| mesure | valeur servie |
|---|---|
| `CACHE_VERSION` (`index.service.worker.js`) | **`1787255094`** = **19:44:54 UTC** |
| `GODOT_CONFIG.fileSizes.index.wasm` | **35 376 909** |
| `index.pck` | 5 749 152 |
| fraicheur | `x-vercel-cache: MISS`, `age: 0` sur les DEUX requetes |

**Le `CACHE_VERSION` tombe A L'INTERIEUR de l'etape `Export Web build` du run
#169** (19:44:50 -> 19:44:55) : l'alias sert donc bien ce build, et il a
largement AVANCE par rapport au run #167 (lot 2, export ~19:04). Le reglage
est en ligne sur staging. `index.wasm` est identique au fingerprint permanent
de tout lot qui ne touche pas le code moteur — coherent avec un diff de deux
nombres dans un `.tres`.

⚠️ **L'alias pointe sur le run #169 (le commit de doc), pas sur le #168
(le merge du reglage).** Sans consequence : `CLAUDE.md` n'est pas une ressource
Godot, donc le contenu de JEU des deux builds est identique. Mais un futur
lecteur qui chercherait le `CACHE_VERSION` du #168 ne le trouverait pas, et ce
n'est pas une anomalie.

Rappel de methode, valable pour tout futur lot : le `CACHE_VERSION` est un
epoch pose a l'export, donc c'est le discriminateur le moins cher pour savoir
quel build est reellement aliase (leçon deja consignee au lot token du
18 aout). En une ligne, quand l'egress le permet :

```
curl -s https://keepy-staging.vercel.app/index.service.worker.js | grep CACHE_VERSION
```

Un `CACHE_VERSION` inchange voudrait dire que l'alias n'a pas bascule, malgre
le `Success!` du log — exactement le cas que la regle « jamais le log seul »
existe pour attraper.

## KEEPY BATTLE LOT 4 : LA FEINTE -- et le vrai defaut dominant n'etait pas l'esquive (21 aout 2026)

Branche `claude/keepy-lot4-feint-2my13e`, partie de `main` (`9b7f338`, ou
`main` et `staging` ont le MEME arbre `34db3682`). Retour device du lot 3 :
« j'esquive facilement ses coups » -- l'esquive est une reponse universelle
sans risque. Diagnostic du brief : une option domine, donc les deux autres
sont mortes.

**Le brief avait raison sur le symptome et se trompait de coupable.** La
mesure a trouve DEUX strategies dominantes, et la pire n'etait pas l'esquive.

### ⚠️ DEFAUT N°1, LE PLUS GROS, ET PERSONNE NE L'AVAIT VU : un joueur qui
### MARTELE ATTAQUE gagnait 300 combats sur 300, en 3,4 s

Trouve a la premiere passe de mesure du lot, sur le code LIVRE en production
la veille. Un joueur qui tape ATTAQUE et rien d'autre **stun-locke**
l'adversaire des le premier coup propre : stagger 0,55 + delai de reaction
0,36..0,66 + windup de garde 0,08 = **0,99 a 1,29 s** avant que la moindre
defense soit levee, contre un cycle d'attaque de **0,78 s**. L'arithmetique
ne se referme jamais.

⚠️ **Aucun reglage ne l'atteignait, et c'est mesure et non suppose** : le
martelage gagne encore **120 sur 120** a `attack_recovery_s` de 0,36 / 0,44 /
0,52 / 0,60 **ET** 0,70. Le defaut n'a jamais ete dans les regles de combat.

**Il etait dans `FighterBrain.gd`, qui trahissait la promesse de son propre
en-tete** (« tout ce qu'un joueur peut faire, cette classe peut le faire ») :
l'horloge de reaction etait remise a zero a chaque tick ou le combattant
n'etait pas IDLE, donc le brain payait son delai APRES chacune de ses
actions et APRES chaque stagger, jamais PENDANT. Sa cadence reelle etait
`duree_action + delai` au lieu de `max(les deux)`. Un humain, lui, reflechit
pendant sa recuperation et pendant qu'il est sonne, et tape dans le buffer
d'entree de 0,16 s pour que sa reponse soit deja engagee a l'instant ou il
est libre. **Les deux cotes jouaient a deux jeux differents sur l'axe exact
qui decidait le match** -- la divergence qu'on ne trouve qu'en mesurant, deja
payee une fois par ce depot (`SubstituteModel.tscn`).

Corrige : l'horloge tourne EN CONTINU. Le delai est toujours facture en
entier, la decision passe toujours par le meme `_choose()`, et rien ne peut
etre joue avant que le combattant soit reellement IDLE -- une decision echue
pendant un lockout est TENUE (la passer a `request_action` la mettrait dans
le buffer de 0,16 s, ou elle expirerait en silence si le stagger dure plus
longtemps : elle disparaitrait pour la raison exacte qui la rendait
necessaire). **Le martelage passe de 100 % a 50 %.**

⚠️ **Effet de bord assume et signale : `ai_reaction_delay_s` change de sens.**
Il mesurait « le delai apres chaque action » ; il mesure desormais
« l'espacement MINIMUM entre deux decisions ». En dessous de la duree d'une
action il ne contraint plus rien -- mesure inerte de 0,16 a 0,36 -- et il ne
redevient un cadran de difficulte qu'a partir de ~0,70, ou le stun-lock
reapparait (martelage 100 % a delai 0,70 et 0,90). Les cadrans utiles sont
desormais `ai_aggression`, `ai_defense_rate` et `ai_feint_rate`.

### DEFAUT N°2, celui du brief : un joueur qui repond a CHAQUE telegraphe est INVINCIBLE

Mesure avec une politique honnete (latence de reaction humaine, **un seul
tap par lecture**, attaque uniquement quand elle est reellement libre) :
**100,0 % de victoires sur 300 combats**, a 0,12 / 0,18 / 0,24 s de latence.
Diagnostic instrumente : sur 207 attaques de l'adversaire, **0 touche
proprement** et 57 sont esquivees -- les 150 autres sont interrompues. Le
retour de Mathieu est donc litteralement exact, et pire qu'il ne le disait.

⚠️ **Piege de mesure rencontre TROIS fois, a connaitre avant d'ecrire une
politique de joueur** : une politique qui appelle `request_action` a chaque
tick n'est pas un joueur, c'est un surhomme. Le buffer d'entree de 0,16 s
est rafraichi chaque tick, donc elle enchaine les esquives sans jamais etre
verrouillee et **aucun `dodge_recovery_s`, de 0,32 a 0,72, ne change quoi que
ce soit**. Trois tableaux entiers ont ete produits, lus et jetes avant que la
cause soit trouvee. Une politique de joueur doit taper UNE fois par lecture,
et n'attaquer que depuis IDLE.

### LA FEINTE LIVREE N'EST PAS CELLE DU BRIEF -- la version litterale a ete construite, mesuree, abandonnee

Le brief decrivait : « un WINDUP puis N'ATTAQUE PAS, enchaine sur une
recuperation », suivi d'une vraie attaque. **Construit, mesure, jete.** Il ne
peut pas fonctionner dans cette FSM, pour une raison d'arithmetique et non de
reglage : **toutes les attaques du jeu portent le meme telegraphe
`attack_windup_s`**, donc le deuxieme temps est exactement aussi lisible que
le premier. Un joueur qui a esquive le mensonge est sorti de sa recuperation
et esquive de nouveau bien avant que le contre arrive. Mesure : un joueur a
esquive-reflexe passait de **85,7 % a 96,3 %** de victoires quand la feinte
etait activee -- **chaque feinte etait une attaque que l'IA ne portait pas**.
Monter `dodge_recovery_s` de 0,32 a 0,72 n'a rien change, aux trois latences.

**Livre a la place : la feinte est une attaque qui RETIENT son coup.** UNE
seule action, jamais deux. Le windup tourne sa duree normale, le coup ne
vient pas, le combattant reste arme pendant `feint_hold_s`, et le coup tombe
apres. Le defenseur a donc toujours exactement une fenetre de lecture, au
moment habituel ; ce qu'il ne peut pas savoir, c'est QUAND le coup arrive.

**L'asymetrie garde/esquive tombe toute seule des nombres, sans aucune regle
speciale** : la fenetre active de l'esquive est etroite et expire pendant le
hold, celle de la garde est plus de deux fois plus large et ne l'est pas.
Bande mesuree, `hold` x latence joueur, part des feintes qui touchent :

| hold | 0,12 s | 0,18 s | 0,24 s |
|---|---|---|---|
| 0,10-0,18 | esq 98-100 % / gar 0 % | **esq 0 %** | **esq 0 %** |
| **0,22 - 0,34** | **esq 100 % / gar 0 %** | **esq 100 % / gar 0 %** | **esq 100 % / gar 0 %** |
| 0,40 | esq 100 % / **gar 100 %** | esq 100 % / **gar 100 %** | esq 100 % / gar 0 % |

**Livre : `feint_hold_s = 0.28`, le centre de la bande.** En dessous de 0,22
un reflex d'esquive couvre encore le coup ; a 0,40 la garde est tombee aussi
et la feinte devient un coup inconditionnel.

### ⚠️ LE CONDITIONNEMENT DE LA FEINTE EST A L'ENVERS DE L'INTUITION -- c'est LE resultat du lot

`FighterBrain` ne feinte **QUE** contre un adversaire qui n'est **PAS** libre.
Ca se lit a l'envers jusqu'a ce qu'on regarde l'horloge : un coup retenu
reste vulnerable pendant `attack_windup_s` + le hold, donc un adversaire
LIBRE frappe simplement le premier -- ce n'est pas un jeu d'esprit, c'est un
tour offert. Un adversaire ENGAGE ne peut pas, et se libere en cours de
telegraphe : juste a temps pour le lire, y repondre, et se faire prendre par
un coup qui arrive apres l'expiration de sa reponse.

| condition | joueur esquive-reflexe |
|---|---|
| feinte desactivee | **100,0 %** |
| bluffer un adversaire LIBRE (l'intuition) | **100,0 %** -- la feinte ne part JAMAIS |
| **bluffer un adversaire ENGAGE (livre)** | **52,0 %** a taux 0,85 / **93,3 %** a 0,35 |

Sans aucun conditionnement, la feinte est desastreuse contre un marteleur :
**32 feintes sur 43 interrompues en plein windup, 1 seule touche**, et le
marteleur passe de 51,7 % a 90,7 %. Le conditionnement rend la mecanique
auto-regulee, **sans aucune memoire des habitudes du joueur** (hors perimetre
et non fait).

### ⚠️ CE QUE LE LOT N'ATTEINT PAS, dit sans maquillage

L'objectif « une strategie mono-touche doit PERDRE » **n'est PAS atteint**.
Ce qui est atteint, c'est « aucune ne domine » : les trois options passent
d'un ecart de **50 points** a **9,3 points**.

| strategie pure (n=150) | lot 3 | ce lot |
|---|---|---|
| marteler ATTAQUE | **100 % en 3,4 s** | **90,0 %** |
| repondre par ESQUIVE | *(non mesure)* | **93,3 %** |
| repondre par GARDE | *(non mesure)* | **99,3 %** |
| spam garde seule / esquive seule | 0 % | 0 % *(elles n'infligent aucun degat -- 0 % par arithmetique, pas par equilibrage)* |

**Les trois gagnent encore trop souvent, et la cause est mesuree** : l'IA est
interrompue avant de finir ses engagements (150 attaques interrompues sur
207). Ce n'est PAS un echec de la feinte -- PHASE C de la sonde prouve que
chaque feinte prise isolement touche exactement comme prevu, aux trois
latences. C'est que l'IA n'arrive pas assez souvent a en placer une.

⚠️ **Resultat de theorie des jeux a connaitre avant de relancer un tuning** :
contre un adversaire dont le melange est FIXE, il existe toujours une reponse
pure au moins aussi bonne que n'importe quel melange. « Aucune mono-touche ne
gagne » est donc **inatteignable** avec un `ai_feint_rate` constant ; le seul
objectif atteignable est d'EGALISER les trois, ce que fait le triplet livre
(`feint 0.35`, `def 0.80`, `hold 0.28`). Aller plus loin demande un adversaire
qui adapte son melange -- explicitement hors perimetre de ce lot.

**Trois sorties possibles pour le lot suivant, aucune prise ici** : de
l'armure ou des i-frames pendant le hold (regle de combat nouvelle, donc son
propre lot et sa propre passe device) ; un second coup RAPIDE apres la feinte
(nouveau timing, donc nouveau telegraphe a valider) ; ou un adversaire qui lit
la frequence de reponse du joueur.

### `BattleFeintProbe` : 27 checks, et PHASE A est celle qui compte

Une feinte echoue d'une facon qu'aucune assertion de combat ne voit : donnez-
lui une milliseconde de windup en moins, un degre de lean en moins, une chaine
de HUD differente, et **toutes les autres sondes restent vertes pendant que la
mecanique ne vaut plus rien**. PHASE A compare donc une attaque et une feinte
**tick par tick** sur les quatre canaux qu'un joueur possede : le libelle
imprime par le HUD, `is_threatening()`, `telegraph_duration()`, et **les
transforms que `FighterView` ecrit reellement sur le `ModelSlot`**. 19 ticks,
identiques sur les quatre.

⚠️ **`BattleTypes.action_label(FEINT)` rend `"Attaque"`, et ce n'est PAS un
bug a corriger.** Le HUD imprime cette chaine EN DIRECT, a cote de l'etat de
l'adversaire, pendant que le windup tourne. Un libelle « Feinte » donnerait la
reponse avant meme que le joueur ait regarde le combattant. Gate par PHASE A.

⚠️ **`Fighter.is_threatening()` rend VRAI pour une feinte, et c'est
obligatoire.** C'est toute la vue d'un observateur sur une attaque entrante :
l'en exclure ferait voir a travers le mensonge par n'importe quel brain -- or
un brain est exactement ce qui tient le role du joueur quand on mesure. Une
mesure prise contre un adversaire qu'on ne peut pas tromper n'est pas une
mesure de la mecanique, c'est une mesure de son absence.

PHASE B (le coup est en retard d'exactement le hold, 16 ticks, et
`strike_activated` part une fois), PHASE C (**le controle d'abord** : une
attaque simple repondue par une esquive est bien ESQUIVEE, sinon les lignes
suivantes mesureraient une mauvaise esquive et non une bonne feinte -- puis
esquive TOUCHEE et garde BLOQUEE aux trois latences), PHASE D (le
conditionnement dans son sens contre-intuitif), PHASE E (**exige que le combat
trace contienne reellement des feintes** avant d'asserter quoi que ce soit sur
son determinisme), PHASE F (`keepy.tres` porte `ai_feint_rate = 0.00` --
`BattleHUD` n'emet que trois actions, un humain n'a pas de bouton feinte, et
une IA qui tient son role ne doit pas disposer d'une option qu'il n'a pas).

### Validation

`BattleFeintProbe` **27/27**, `BattleContractProbe` **36/36**,
`BattleReadabilityProbe` **29/29**, `ProbeTimeoutAudit` **36 sondes scenes**
(35 + la nouvelle), toutes armees -- **toutes exit 0**. Import headless
**exit 0**, export Web release **exit 0**. `index.wasm` **35 376 909 octets**,
md5 **`af4a8fc2925d992348eb30deeeb54360`** -- identique au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur. `index.pck`
5 750 224 (export unique et propre, `build/` supprime avant -- a lire avec la
mise en garde permanente sur son instabilite). Piege payload tenu : **0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs` ou `web`, et
`BattleFeintProbe` **absent du pack**.

⚠️ **`BattleContractProbe` n'est PAS byte-identique au lot 3, et ce serait
anormal qu'elle le soit** : ce lot change le gameplay de l'IA. Sa PHASE F
rapporte desormais **20/40 (50,0 %), moyenne 9,27 s** contre 22/40 (55 %) et
13,85 s au lot 3 -- l'adversaire agit pendant ses propres lockouts, donc les
combats sont plus courts. Les 36 assertions passent, aucun seuil n'a ete
touche. `BattleReadabilityProbe` reste verte : ce lot ne touche ni la vue ni
le HUD, et l'unique changement de `FighterView` est de lire
`telegraph_duration()` au lieu de `phase_duration()` sur le seul WINDUP.

**Point de bascule Meshy intact** : rien n'est ajoute, deplace ou renomme dans
l'arbre de scene, tout passe toujours par `$Body` / `ModelSlot`. **Aucune
reference depuis `scripts/battle/` vers `scripts/dev/`** (piege deja consigne :
`scripts/dev/*` est exclu du pack, donc une reference `class_name` casse
UNIQUEMENT dans le build web).

### Reste ouvert -- jugement device, seul juge

1. **La feinte se lit-elle comme une feinte ?** Aucune sonde ne dit qu'un
   combattant qui reste arme un quart de seconde de plus se lit comme « il
   retient son coup » plutot que comme un bug d'animation. C'est tout l'objet
   du lot : le telegraphe est desormais une information AMBIGUE, et personne
   ne sait encore si l'ambiguite se percoit au pouce.
2. **La difficulte globale reste trop faible contre un joueur qui repond a
   chaque telegraphe** (chiffres ci-dessus). Mesure, argumentee, non corrigee.
3. `ai_reaction_delay_s` a change de sens et n'est plus le cadran de
   difficulte qu'il etait.

### Deploiement staging du lot 4 (palier 1, automatique)

`staging` `0fadccf` (merge `--no-ff`, arbre **byte-identique** a la branche
feature, verifie avant le push : meme hash d'arbre des deux cotes). CI run
**#172** (id `32466399904`) **verte en 3 min 57 s** (09:07:43 -> 09:11:40 UTC)
-- `Deploy to Vercel [STAGING -- staging]` succes, `[PRODUCTION -- main]`
correctement skippe. **`main` NON touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** : l'egress direct vers
`keepy-staging.vercel.app` est refuse par le proxy du sandbox (`http=000`,
re-teste et pas suppose), donc via `mcp__Vercel__web_fetch_vercel_url`.
`index.service.worker.js` sert **`CACHE_VERSION = '1787303471|4112654'`** =
**09:11:11 UTC**, c'est-a-dire A L'INTERIEUR de la fenetre du run #172 --
l'alias sert donc bien ce build et pas le precedent (lot 3 : `1787255094`,
19:44:54 la veille). `x-vercel-cache: MISS`, `age: 0`, `last-modified` colle
a l'instant de la requete : trois signaux independants qui disent que ce
n'est pas une reponse de cache.

⚠️ **Note de format, sans consequence** : le `CACHE_VERSION` porte desormais
un suffixe `|4112654` que les lots precedents n'avaient pas. Seule la partie
avant le `|` est l'epoch d'export ; c'est elle le discriminateur, et elle a
bien avance.


## KEEPY BATTLE, LOT 5 : LA DEFENSE ETAIT INJOUABLE -- la fenetre entiere
## tombait AVANT la portee d'un humain (21 aout 2026)

Branche `claude/lot5-defense-viability-exfk3w`, partie de `staging`
(`a61df49`, le lot 4 feinte). Retour device de Mathieu : « j'ai
l'impression que ma garde n'a pas tenu assez longtemps pour encaisser le
coup », et « garder ou esquiver n'a pas de sens, les degats sont enormes
et on n'a pas confiance que ca marche -- si on veut gagner on attaque,
point. »

Les sondes du lot 4 disaient l'INVERSE (garde 99,3 %, esquive 93,3 %).
**Les deux etaient vraies, elles mesuraient deux joueurs differents, et
un seul des deux existe.** Aucun chiffre du lot 4 n'a ete defendu.

### ⚠️ LE DEFAUT : `BattleFeintProbe` repondait au telegraphe en 0,12-0,24 s

Aucun humain ne produit ca a travers un ecran tactile et un navigateur.
Le temps de reaction visuel simple plafonne vers 0,25 s en laboratoire ;
un telephone ajoute l'echantillonnage du digitiseur et le dispatch
d'evenement du navigateur par-dessus. **La bande honnete est 0,30-0,45 s**
(`BattleDefenseProbe.HUMAN_FAST/TYPICAL/LATE`).

Et le nombre qui decide reellement si defendre est une option --
**DE COMBIEN LE TAP PEUT-IL ETRE EN RETARD** -- n'etait rapporte nulle
part. C'est tout l'objet de la nouvelle sonde.

### Chronogramme AVANT, mesure sur les FSM livrees (pas calcule a la main)

Attaquant Sparring, defenseur Keepy, ticks depuis la premiere frame du
telegraphe :

| | couverture reelle du tap |
|---|---|
| garde vs attaque simple | **0..217 ms** |
| garde vs attaque ET feinte | **67..217 ms** |
| esquive vs attaque simple | **33..233 ms** |
| esquive vs feinte | 317..517 ms |

**La bande humaine entiere (300-450 ms) tombe HORS de chacune de ces
fenetres.** La defense n'etait pas faible, elle etait **hors de portee** :
a 300 ms -- le tap le plus rapide qu'un humain produise -- la garde ne
couvre PAS l'attaque simple, et l'esquive ne couvre NI l'une NI l'autre.

⚠️ **Le ressenti device etait juste, le mecanisme non.** « La garde n'a pas
tenu assez longtemps » decrit un symptome reel dont la cause est
**« la garde arrive trop tard »**, pas « elle expire trop tot » -- la
contrainte qui mordait etait la borne HAUTE du tap, pas la largeur de la
fenetre. Pire, le tap arrivant pendant le stagger etait mange par le
buffer de 0,16 s (stagger 0,55 s) : le bouton ne faisait litteralement
rien. D'ou « on n'a pas confiance que ca marche ».

### PHASE D : le joueur imparfait -- ce que le banc du lot 4 ne pouvait pas voir

Trois strategies caricaturales, tap = latence + gaussienne(0, 90 ms),
n=300 par cellule (jamais n=40 : la lecon du lot 3, ecart-type ~8 points).
Les DEUX cotes sont pilotes (le brain reel sur l'adversaire, la politique
sur le joueur) -- le piege « 1 brain = sac de frappe » a deja ete
rencontre deux fois.

| politique | AVANT (300/380/450 ms) | APRES |
|---|---|---|
| **martelage** | **261 / 261 / 261** sur 300 | **239 / 239 / 239** |
| garde | 203 / 183 / 136 | **300 / 300 / 299** |
| esquive | 199 / 204 / 176 | **262 / 296 / 298** |
| mixte | 218 / 178 / 160 | **295 / 300 / 299** |

**AVANT : le marteleur gagne 87 % A TOUTES LES LATENCES** (il ne lit
rien, donc la latence ne le concerne pas) et **toute defense fait pire,
et de pire en pire a mesure que le tap tarde**. C'est exactement le
rapport device, en chiffres.

**APRES : defendre bat marteler a chaque latence.** C'est le critere de
viabilite du lot, et il est atteint.

### Les TROIS leviers, dans l'ordre ou il a fallu les tirer

**A. Le telegraphe : 0,31 -> 0,58 s.** Il n'y a pas d'alternative, et
c'est une inegalite, pas un gout :

```
attack_windup_s  >=  latence humaine + guard_windup_s du defenseur
```

Une garde devient active a `latence + guard_windup_s`. Un telegraphe plus
court qu'un temps de reaction humain ne peut pas etre repondu, seulement
DEVINE. Ni une garde plus large ni des degats moindres n'y changent quoi
que ce soit. Startup de garde descendu a 0,03-0,04 pour rendre ce budget.

⚠️ **B. ELARGIR LA GARDE NE SUFFIT PAS -- et seul le fait de le mesurer
l'a montre.** Avec les fenetres corrigees mais le reste intact, le
marteleur est passe a **300/300** : *meilleur* qu'avant le fix. La garde
marchait parfaitement et perdait quand meme.

```
lockout restant du defenseur + son attack_windup_s
    >=  attack_active_s + attack_recovery_s + attack_windup_s de l'attaquant
```

Quand cette inegalite tient, le contre n'arrive JAMAIS : l'attaquant est
deja derriere son telegraphe suivant. Bloquer devient une facon plus
lente de perdre, et ne jamais s'arreter d'attaquer est le jeu correct.
Le lot 2 avait allonge le telegraphe, le lot 5 bien davantage -- les deux
ont grossi le membre gauche, personne n'a grossi le droit.
**`attack_recovery_s` 0,34-0,42 -> 0,52-0,54**, stagger 0,45 -> **0,60**
pour rester pire qu'un coup dans le vide. Gate : `PHASE C2`.

**C. La punition : 12-13 -> 8 degats.** 24-26 % de la barre de vie par
erreur (4-5 coups pour un K.O.) rend une defense incertaine irrationnelle
quels que soient les fenetres. Desormais **16 %, 7 coups**, et 25 coups
bloques.

### Chronogramme APRES

| | couverture du tap |
|---|---|
| garde vs attaque simple | **33..533 ms** |
| **garde vs attaque ET feinte** | **233..533 ms** |
| esquive vs attaque simple | **283..517 ms** |
| esquive vs feinte | 483..717 ms |

⚠️ **La feinte est CONSERVEE comme lecture difficile, pas supprimee** (choix
explicite du brief). La garde la couvre depuis n'importe quel tap de la
bande humaine -- c'est ce qui en fait l'option sure, celle qu'un joueur
peut prendre AVANT de savoir lire une feinte. L'esquive ne la couvre qu'a
partir de 483 ms, donc **une esquive reflexe reste punie**.
`feint_hold_s` 0,28 -> 0,20 pour tenir dans la garde elargie.
`BattleDefenseProbe` PHASE B asserte cet echec : **la seule assertion du
depot qui veut que quelque chose NE marche PAS**.

### Feedback : quatre issues, quatre verdicts (tache C)

Avant, une garde tapee 80 ms trop tard produisait **le meme flash blanc et
le meme mot « TOUCHE »** que ne rien presser du tout. Un joueur sans signal
d'erreur ne peut pas apprendre un timing, et une option qu'on n'apprend
pas est une option morte (lecon Chased, deja consignee).

`Fighter.hit_taken` porte desormais l'action defensive engagee. **Argument
de signal et pas relecture de `current_action`** : ca marcherait
aujourd'hui uniquement parce que l'emit precede `_enter_stagger()` -- une
dependance silencieuse, dans le canal meme que ce lot ajoute pour que les
echecs cessent d'etre silencieux.

| issue | couleur | forme |
|---|---|---|
| garde tenue | bleu froid | la garde se comprime davantage (absorbe) |
| esquive reussie | aqua vif | un glissement supplementaire |
| **defense BRISEE** | **violet** | la pose s'evase et roule |
| pris a froid | blanc | rien |

Forme **en plus** de la couleur : la couleur est le canal le plus
facilement perdu sur un petit ecran ou en plein soleil, et ce sont
justement les deux evenements dont il faut apprendre un timing. Absorber
et briser sont des mouvements **opposes**, volontairement.

⚠️ **La regle du lot 2 est INTACTE** : la rampe soutenue vers `ALERT_COLOR`
pendant un windup veut toujours dire une seule chose, une attaque
entrante. Ce sont des flashs d'IMPACT, momentanes, un canal qui portait
deja deux sens ; ce lot ajoute les deux qui manquaient, dans une teinte
qui n'est ni le rouge du telegraphe ni le blanc neutre.

HUD : **« GARDE BRISEE » / « ESQUIVE RATEE »** au lieu d'un « TOUCHE » nu.

### `ai_reaction_delay_s` de l'adversaire etait PERIME

0,36 +- 0,30 -> **0,26 +- 0,18**. Ses chiffres etaient cales sur un
telegraphe de 0,30 s : face a 0,56 s il ne pouvait plus lire a temps
(delai + guard_windup devait tenir sous le windup adverse, et la moitie de
ses tirages depassaient). Trouve par sweep, pas suppose.

### Validation

`BattleDefenseProbe` (**34 checks, 0 failure**, nouvelle, armee --
`ProbeTimeoutAudit` passe a **37 scenes**), `BattleContractProbe`
(**36/36**), `BattleFeintProbe` (**27/27**), `BattleReadabilityProbe`
(**29/29**), `AssetContractAudit`, `DeathModelAudit`, `ChargerShapeProbe`
-- **toutes exit 0**. Boot headless de `Battle.tscn` / `BattleHUD.tscn` /
`BattleFighter.tscn` / `Hub.tscn` : exit 0, **0 erreur GDScript**. Import
+ export Web release **exit 0**, `index.wasm` **35 376 909** octets / md5
`af4a8fc2925d992348eb30deeeb54360` -- le fingerprint deja consigne pour
tout lot qui ne touche pas le code moteur. Piege payload tenu (**0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web`,
`build`).

⚠️ **`BattleFeintProbe.LATENCIES` est passe de `[0.12, 0.18, 0.24]` a
`[0.30, 0.38, 0.45]`.** Ce n'est pas un assouplissement : ce sont les
valeurs qui ont produit le faux vert. Elle reste **27/27** a la bande
reelle, donc la feinte survit aux fenetres elargies. **Si un futur lot
trouve cette bande genante, le geste honnete est de changer le `.tres`,
pas la bande -- la bande est un fait sur les gens, pas un parametre.**

⚠️ **Non-applicabilite VERIFIEE par grep, pas supposee** : aucune des
sondes non-Battle ne reference `Battle`, `Fighter` ni `resources/battle`,
et le diff de ce lot ne sort pas de `scripts/battle/`, `scripts/ui/
BattleHUD.gd`, `scripts/dev/Battle*` et `resources/battle/*.tres`.

### Reste ouvert

1. **Jugement device, et c'est tout l'objet du lot** : est-ce qu'un
   telegraphe de 0,58 s se lit comme lent/lourd plutot que lisible, et
   est-ce que les quatre verdicts se distinguent A L'OEIL sur un
   telephone. Le plus important est **GARDE BRISEE** : le joueur doit
   comprendre qu'il a mal time, pas que le bouton n'a rien fait.
   Aucune sonde ne repond a ca.
2. ⚠️ **La difficulte globale a BAISSE, et le levier qui la recupererait
   est hors perimetre.** Un joueur qui repond a chaque telegraphe gagne
   desormais 100 %. Ce qui manque a l'adversaire est de **punir une
   recovery d'attaque** : apres avoir bloque, il est lui-meme verrouille
   trop longtemps pour contre-attaquer. C'est un changement de BRAIN
   (explicitement hors perimetre de ce lot), pas un reglage `.tres` --
   **mesure** : raccourcir sa garde pour le liberer plus souvent le rend
   PIRE (marteleur 79 % -> 100 %), et les quatre reglages `ai_*` balayes
   ne descendent pas le marteleur sous 79 %.
3. **Les rounds s'allongent** : 6,1 s (marteleur, avant) -> 14,8 s ;
   defense ~20-21 s. Inherent -- un combat ou les deux cotes defendent
   EST plus long -- mais au-dessus de la cible 12-20 s du lot 3.
4. Toujours aucun asset 3D, aucun son, aucune persistance : la bascule
   Meshy passe toujours par `$Body` / `ModelSlot`, intouchee.

### Deploiement staging du lot 5 (palier 1, automatique)

`staging` `92a0f8f`, CI run **#174** (id `32471971573`) **verte en
3 min 18 s** (10:17:41 -> 10:20:59 UTC) -- `Deploy to Vercel
[STAGING -- staging]` succes, `[PRODUCTION -- main]` correctement
**skipped**. `main` **non touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste
refuse en 403 CONNECT sur ce domaine) : `CACHE_VERSION` du
`index.service.worker.js` servi = **`1787307631` = 10:20:31 UTC**, donc
**dans la fenetre du run #174**, contre `1787304120` = 09:22:00 (run #173,
lot 4) juste avant. `x-vercel-cache: MISS`, `age: 0`. L'alias sert bien ce
build.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES**
pendant ce deploiement -- deux appels `list_workflow_jobs` byte-identiques,
figes sur `Import project resources / in_progress`, `filter: "latest"`
compris. **Le `CACHE_VERSION` servi est ce qui a tranche**, et il a tranche
DANS LES DEUX SENS : lu trop tot il valait encore `1787304120` (lot 4), ce
qui a confirme que le job tournait REELLEMENT au lieu d'etre un cache
perime, puis il est passe a `1787307631`. Un second signal independant
distingue les deux cas ; un poll de plus ne l'aurait pas fait.

## KEEPY BATTLE : PREMIERE ECRITURE FIRESTORE — un compteur cumule anonyme, un write par combat fini (21 aout 2026)

Branche `claude/keepy-battle-stats-d8b7p2`, partie de `main` = `staging`
(`13cda8d`, meme arbre des deux cotes). **Battle n'ecrivait rien nulle part
depuis le lot 1** ; ce lot ouvre `battleStats/global`, un document UNIQUE,
CUMULE et ANONYME (aucun `uid`, aucun historique par combat), incremente a
la fin de chaque combat. Schema valide par Mathieu : `gamesPlayed`, `wins`,
`losses`, plus `attacks`/`dodges`/`blocks` en `{attempted, hit, missed}`, plus
`updatedAt` serveur.

### Recon : la troisieme reponse est celle qui a change le travail

1. **Auth** — `request.auth != null` partout dans le ruleset deploye
   (`82c07ff`), et c'est **Google Sign-In et RIEN D'AUTRE** : `grep` ne trouve
   aucun `signInAnonymously` dans le depot, `web/html_shell.html` n'utilise que
   `signInWithRedirect(auth, new GoogleAuthProvider())`.
2. **Fin de combat** — `BattleArena._end_round(player_won)`, point unique.
3. ⚠️ **AUCUN compteur n'existait.** Rien dans `scripts/battle/` ne
   trackait quoi que ce soit — `grep -i "stat|counter|tally|attempts"` ne rend
   que des faux positifs (`state_changed`). Tous les compteurs sont neufs.
4. **`battleStats`** — aucun bloc dans `firestore.rules`.

### L'invariant est VERIFIE, pas deduit du FSM

`hit + missed <= attempted`, par groupe. C'est une **inegalite** et jamais une
egalite : `attempted` compte des ENGAGEMENTS, `hit`/`missed` des RESOLUTIONS —
une attaque interrompue avant sa fenetre active, une garde ou une esquive qui
n'affronte aucun coup, sont engagees et jamais resolues. L'ecart est donc une
donnee (des engagements jamais testes), pas du mou.

Le FSM livre ne peut pas le casser aujourd'hui, **et c'est un argument sur du
code que `BattleTally` ne possede pas**. `repair()` verifie donc sur les vrais
chiffres, avant encodage, et **REMONTE `attempted`** au lieu de baisser les
resolutions : une resolution est un fait observe, un engagement manquant ne
peut etre qu'un trou de comptabilite. Chaque reparation est un `push_warning`.

### ⚠️ LA FORME DU WRITE EST LE VRAI RISQUE — `updateMask` present ET vide

Un `:commit`, un write : `update` avec le NOM du document seul (aucun
`fields`), `updateMask: {fieldPaths: []}`, et 12 `increment` + `updatedAt` en
`REQUEST_TIME`. C'est la forme que les SDK officiels emettent pour
`set(increment(), {merge:true})`.

**Si le masque disparait, Firestore ECRASE le document entier avant que les
transforms ne tournent** — c'est-a-dire une remise a zero des totaux partages,
la seule panne de ce lot qui detruit de la donnee au lieu d'en perdre une.
`BattleStatsProbe` PHASE D lit donc ces octets litteralement.

**Les zeros voyagent aussi, et c'est porteur** : un `increment` sur un champ
absent le cree a partir de 0, donc envoyer `losses: 0` apres une victoire est
ce qui fait que le TOUT PREMIER write produit la forme complete que le
`hasAll()` des rules exige. Aucune branche create-vs-update cote client : un
read-then-write courrait contre tous les autres joueurs.

### Rules : purement additives, et la monotonie sert DEUX fois

`git diff --numstat` : **152 lignes ajoutees, 0 retiree** ; les 358 premieres
lignes (`/scores` + `/quizzes` + `/categories`) sont **byte-identiques** a
`origin/main` (`cmp` silencieux). Lecture signed-in comme `/scores` ; pas de
triplet owner-only puisqu'il n'y a **pas de proprietaire** ; jeu de cles exact,
entiers non negatifs, `updatedAt == request.time`, `allow delete: if false`, et
une **monotonie** qui refuse toute ecriture faisant baisser un compteur.

⚠️ **La monotonie est aussi le filet sous la forme du write** : masque
perdu -> les valeurs resultantes seraient les seuls deltas du combat courant,
donc INFERIEURES au stocke -> ecriture refusee au lieu de totaux remis a zero.

⚠️ **LIMITE ACCEPTEE PAR MATHIEU** : un document unique partage incremente
cote client ne peut pas etre rendu etanche par des rules — la cle d'API est
publique (elle est dans le build). Les rules reduisent la surface, elles ne la
ferment pas. Chiffres d'affichage, rien de sensible.

### ⚠️ DEUX PREMISSES DU BRIEF SONT FAUSSES, mesurees

- **`firestore-rules.yml` n'a PAS de `workflow_dispatch`** — c'est explicite
  dans son propre commentaire (« Deliberately no workflow_dispatch »). Le SEUL
  chemin vers le projet live est un push sur `main` touchant `firestore.rules`.
  **Il n'existe donc aucun moyen de tester une ecriture battleStats sur staging
  avant la prod.**
- **Consequence directe : sur `staging`, AUCUNE ecriture battleStats ne peut
  reussir.** Pas de regle deployee -> deny par defaut -> 403 -> `push_warning`,
  et rien d'autre. C'est le mode de panne prevu, pas une regression.

### Validation

`BattleStatsProbe` (nouvelle, **85/85, exit 0**) : regles de comptage une par
une, invariant force puis repare, jeu de cles complet, octets du write, gate
headless (**reseau teste AVANT auth** — un probe ne touche jamais `Auth`), et
**PHASE F un vrai combat a travers `Battle.tscn` livre** (986 ticks, tally
coherent, **exactement UNE tentative d'ecriture**, aucune reparation
necessaire). Import et export Web **exit 0**, `index.wasm` **35 376 909** /
md5 `af4a8fc2925d992348eb30deeeb54360`. `ProbeTimeoutAudit` **38 scenes** (37
avant). Piege payload tenu.

**SEPT sondes BYTE-IDENTIQUES sur les DEUX flux contre `origin/main`** en
worktree separe (imports verifies complets des deux cotes, 24 `.scn`) :
`BattleContractProbe`, `BattleFeintProbe`, `BattleReadabilityProbe`,
`BattleDefenseProbe`, `AssetContractAudit`, `DeathModelAudit`,
`ChargerShapeProbe`.

⚠️ **`BattleFeintProbe` ECHOUE 5/27 — et elle echoue DEJA sur
`origin/main`, a l'octet pres.** Rouge PRE-EXISTANT, non attribuable a ce lot
et non touche par lui. Cause : `LATENCIES` y vaut toujours
`[0.12, 0.18, 0.24]` alors que la section « lot 5 » de ce fichier annonce
`[0.30, 0.38, 0.45]` — **ce changement n'a jamais atteint `main`**. A traiter
dans son propre lot.

### Reste ouvert

1. **Rien n'a jamais atteint Firestore.** Aucun idToken Google dans ce sandbox,
   donc la forme du write est prouvee contre les rules ECRITES, **pas contre le
   service**. En particulier, ni le comportement d'un `updateMask` vide ni le
   fait que `request.resource.data` porte les valeurs POST-increment ne sont
   verifies en ligne — le second est le meme mecanisme qui fait deja marcher
   `createdAt == request.time` sur `/scores`, le premier ne l'est pas.
2. **Le deploiement des rules est gate `main`** (point ci-dessus), donc la
   premiere ecriture reelle sera une ecriture de PRODUCTION.
3. **Keepy-Analytics n'est pas touche** — session distincte, apres celle-ci.

## KEEPY BATTLE, LOT 6 : LES CAPSULES DEVIENNENT DES MODELES — zero asset genere, zero credit Meshy (21 aout 2026)

Branche `claude/keepy-lot6-3d-models-t6sctv`, partie de `main` = `staging`
(`924d81f`, meme arbre). **Decision de cadrage de Mathieu : on n'attend pas
Meshy.** Les deux combattants portent desormais un `.glb` que le depot
possede deja, et **toute l'animation reste procedurale** (les tweens du lot
2 sur `$Body`/`ModelSlot`). Les modeles sont statiques, animes par code,
exactement comme les capsules. Chiffres complets : `docs/MESHY_SPEC.md`
**§12** (nouvelle).

| combattant | asset | tri | echelle | rotation | offset |
|---|---|---|---|---|---|
| `PlayerFighter/Body` (Keepy) | `keepy_squirrel_hero.glb` | 3 129 | 1,07368 | `(0,0,0)` | `(0, -0,2246, 0)` |
| `OpponentFighter/Body` (Sparring) | `keepy_hibou_pursuer.glb` | 7 070 | 0,895095 | `(0,0,0)` | `(0, -0,0489, 0)` |

### Inventaire : il EXISTE un modele de Keepy, et l'adversaire s'imposait

`assets/models/` contient **10 `.glb`, tous unlit, tous deja packes** : les
6 hazards + 2 props decor (148-560 tri, plats, sans texture), plus
**l'ecureuil hero** (3 129 tri, 1 texture baked) et **le hibou poursuivant**
(7 070 tri, 4 textures). Les huit petits sont des sujets **couches ou
accroupis** ; **le hibou est le SEUL modele debout du depot** (bbox
dominante en Y, 1,228 x **1,899** x 1,172) et l'ecureuil est le seul hero.
Le choix ne se discutait donc pas beaucoup — et il est narrativement juste :
dans Chased le hibou POURSUIT Keepy, dans Battle Keepy lui fait face.

### ⚠️ REUTILISER UN `.glb` DEJA LIVRE COUTE ZERO PAYLOAD — donc NE PAS le decimer

`export_filter="all_resources"` packe une ressource **une fois**. Verifie
sur le log `savepack`, pas argumente : chacune des 7 ressources derivees
(les 2 `.scn` + leurs 5 `.ctex`) apparait dans **exactement UNE** ligne
`Storing File`. Mesure sur deux exports propres dans la meme session :
`.pck` **5 759 040 -> 5 761 376 (+2 336, +0,04 %)**, soit les deux `.tres`,
les deux scenes et le `FighterView.gdc` grossi — **pas un octet d'art**.
`index.wasm` **identique des deux cotes** (35 376 909, md5
`af4a8fc2925d992348eb30deeeb54360`).

⚠️ **Corollaire qui INVERSE l'instinct habituel : passer un de ces modeles
par `decimate_hazard.py` aurait GROSSI le build.** Une copie decimee est un
fichier de plus, donc le pack porterait l'original (pour Chased) ET la
reduction (pour Battle). Le decimateur sert a ramener un asset NEUF sous
budget ; c'est le mauvais outil pour un asset deja livre et deja dans son
budget (§7.1 : 6 000 et 8 000). Battle dessine **~10 200 tri** au total
contre une cible de 50 000, sans piste, sans hazard, sans collectible : il
n'y avait rien a acheter.

### Orientation : `(0,0,0)`, et le zero est MESURE

Chased monte ces deux memes modeles a `(0, 180, 0)`. Battle les monte a
zero, et ce n'est ni une contradiction ni une copie : rendu de chaque `.glb`
depuis `+Z`, `-Z`, `+X` et le dessus. **Ecureuil vu de +Z : le visage, les
yeux, le badge « K ». Hibou vu de +Z : la face et les anneaux d'yeux
lumineux.** Les deux ont donc leur face en **model +Z**. Chased a besoin de
180 parce que §3 fait regarder ses slots vers **-Z** (on les voit de dos) ;
un combattant Battle regarde **son adversaire**, le long de son propre `+Z`.

⚠️ **C'est la PROFONDEUR de l'ecureuil, pas sa hauteur, qui dimensionne
l'arene.** Pose assise, queue enroulee le long de Z : 1,229 x 1,257 x
**1,897**. De profil, ce 1,897 est presente **sur l'axe qui separe les deux
combattants**. Portee avant mesuree sur la scene construite : **1,018**
(ecureuil) contre **0,524** (hibou). Separation **2,00 -> 2,70**, camera
reculee (z 5 -> 7,1 ; pitch -10,2 -> -13,5 ; **`fov` intouche a 40**). Les
deux combattants sont assertes **entiers dans le cadre en 1080x1920 ET
1170x2532**, et leurs pieds touchent le sol au dixieme de millimetre.

### ⚠️ LE VRAI RISQUE DU LOT S'EST REALISE : le telegraphe de l'adversaire perd sa TEINTE

Mesure sur la scene livree, repos contre alarme pleine, moyenne **en
lumiere lineaire sur les pixels PROPRES de chaque combattant** (masque
obtenu en re-rendant la meme frame slot masque) :

| combattant | luminance | ecart de teinte | ecart de saturation |
|---|---|---|---|
| capsule Keepy (lots 2-5, validee device) | 1,63:1 | 26,9° | +0,18 |
| capsule Sparring (lots 2-5, validee device) | 1,61:1 | **159,6°** | +0,47 |
| **ecureuil `.glb`** | **2,21:1** | 11,4° | +0,53 |
| **hibou `.glb`** | **1,57:1** | **10,2°** | +0,52 |

**L'ecureuil du joueur y GAGNE** (un corps creme multiplie par du rouge
chute plus qu'une capsule orange). **L'adversaire non** : luminance et
saturation tiennent, mais la **teinte s'effondre de 159,6° a 10,2°** — une
capsule bleue qui vire au rouge est un basculement quasi complementaire, un
hibou brun qui vire au rouge n'est presque pas un changement de teinte. Et
c'est l'adversaire que le joueur lit.

⚠️ **Une PREMIERE mesure du meme phenomene a lu 1,18:1 et etait FAUSSE — la
methode, pas l'arbre.** Elle prenait un dominant d'histogramme sur une
fenetre 11x11, la methode des recolorisations hazards du §11, qui marche
la-bas parce qu'un hazard plat unlit remplit sa fenetre d'une seule
couleur. Sur un modele texture cette fenetre contenait **95 couleurs
distinctes sur 121 pixels**, donc aucun dominant. **Toute mesure de
contraste future contre un asset importe texture doit MASQUER l'objet, pas
echantillonner une boite.**

### La reponse : un cue engine-side, exactement le patron deja etabli

§2.1 et §8 disent deja qu'un cue d'**EMISSION** ne peut pas vivre sur un
slot (d'ou les yeux du poursuivant, noeuds engine-side et pas partie du
`.glb`). Ce lot trouve l'autre moitie de la meme regle, plus vicieuse parce
qu'elle echoue **par degres** au lieu d'echouer en silence : **un cue
d'ALBEDO survit mecaniquement au swap, mais ce qu'un joueur en voit devient
une propriete de l'asset.**

`BattleFighter.tscn` gagne donc **`Body/Alert`** : deux prismes, un coeur
vif dans un contour quasi noir, au-dessus de la tete, cache sauf pendant un
telegraphe d'attaque. Ses couleurs appartiennent au projet, donc sa
lisibilite est un fait sur le MOTEUR et non sur le `.glb` qu'un futur profil
portera. **La rampe de teinte est CONSERVEE a cote** : elle lit encore sur
un modele clair, et plus rien ne depend d'elle seule.

⚠️ **Le marqueur est enfant du slot, donc il HERITE du lacet du
combattant.** La premiere version s'est rendue **de profil** et se lisait
comme une echarde de 6 cm. Il est place depuis `visual_aabb().end.y` et
de-lace depuis `global_basis`, les deux mesures prises a la resolution —
**aucun champ par profil**, donc le contrat « un `.tres` + un `.glb`, zero
ligne de code » survit aussi a ce fichier.

### `BattleReadabilityProbe` : PHASE G nouvelle, PHASE A remesuree

**42 checks, 0 echec, exit 0.** PHASE G gate que le marqueur franchit
**3,0:1 contre les DEUX fonds** possibles (coeur **5,14:1** sur le ciel,
contour **3,67:1** sur le sol — aucune des deux couleurs ne bat les deux,
mais ensemble aucun fond ne l'avale), qu'il **grandit** au lieu d'apparaitre
(0,282 -> 0,713), qu'il est au-dessus du corps, et que **garde et esquive ne
le levent jamais** — la couleur veut toujours dire exactement une chose.

PHASE A cesse de soustraire un **rayon de capsule 0,45 code en dur** : ce
nombre a cesse d'etre la reponse des que de vrais modeles sont arrives. Elle
lit desormais la portee reelle de chaque profil sur son propre
`visual_aabb()`.

⚠️ **Piege trouve en ecrivant PHASE G** : `Battle.tscn` demarre un vrai
round des qu'elle entre dans l'arbre, et son brain pilote l'adversaire
chaque frame. La premiere version laissait l'arene tourner et lisait un
marqueur leve par l'attaque de l'IA comme un marqueur leve par la garde que
la boucle venait de demander. `set_process(false)` **et**
`set_physics_process(false)` avant toute mesure.

### Validation

**HUIT sondes diffees contre `origin/main` en worktree separe (imports
verifies complets des deux cotes) : les HUIT sont BYTE-IDENTIQUES sur les
DEUX flux, stdout ET stderr** — `BattleContractProbe` (le determinisme :
**ce lot est purement visuel et l'identite au bit pres le dit plus fort
qu'un verdict identique**), `BattleFeintProbe`, `BattleDefenseProbe`,
`BattleStatsProbe`, `ProbeTimeoutAudit`, `DeathModelAudit`,
`ChargerShapeProbe`, `AssetContractAudit` (12/12 visuels, **0/10 colliders
deplaces**). Import + export Web **exit 0**.

⚠️ **`BattleFeintProbe` est ROUGE (5/27) — et elle l'est A L'IDENTIQUE sur
`origin/main`**, meme sortie au bit pres. Rouge **pre-existant**, deja
consigne au lot battleStats, **hors perimetre et non aggrave par ce lot** ;
constate avant et apres, comme demande. Cause deja connue : `LATENCIES` y
vaut toujours `[0.12, 0.18, 0.24]` alors que la section lot 5 annonce
`[0.30, 0.38, 0.45]` — **ce changement n'a jamais atteint `main`**.

### Reste ouvert — jugement device, seul juge

1. **Est-ce qu'un ecureuil assis « kawaii » se lit comme un COMBATTANT ?**
   Aucune sonde ne repond. C'est une pose assise, sans jambes visibles et
   sans garde : elle a ete choisie parce que c'est le seul Keepy du depot,
   pas parce qu'elle se bat bien. C'est le risque principal du lot.
2. **Est-ce que le marqueur d'attaque se lit** a vitesse reelle sur un
   telephone, et est-ce qu'il ne parasite pas la lecture de la silhouette ?
   Sa taille (0,36 x 0,32 unite) et sa hauteur (`ALERT_GAP = 0,22`) sont des
   choix mesures pour tenir dans le cadre, pas valides a l'oeil.
3. **Les combattants occupent ~20 % de la hauteur d'ecran** contre ~28 %
   pour les capsules — consequence directe de la queue de l'ecureuil, qui
   force un cadre plus large. Mesure, assume, mais reel.
4. **Aucun son, aucune particule, aucune animation squelettale, aucun second
   adversaire, aucune progression** : hors perimetre, inchange depuis le
   lot 1. Le point de bascule reste `$Body`/`ModelSlot`.

### Deploiement staging du lot 6 (palier 1, automatique)

`staging` `ca22981` (merge `--no-ff`, arbre **byte-identique** a la branche
feature — meme hash d'arbre des deux cotes, verifie avant le push). CI run
**#180** (id `32490331721`) **verte** (14:06:20 -> 14:09:43 UTC) — `Deploy to
Vercel [STAGING -- staging]` **succes** a 14:09:41, `[PRODUCTION -- main]`
correctement **skipped**. `main` **non touche** (palier 2, gate Mathieu apres
validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` — l'egress direct du sandbox reste
refuse sur ce domaine) : `CACHE_VERSION` du `index.service.worker.js` servi =
**`1787321354` = 14:09:14 UTC**, donc **a l'interieur de l'etape `Export Web
build` du run #180** (14:09:10 -> 14:09:15), contre `1787314110` = 12:08:30
(run #178) juste avant. `x-vercel-cache: MISS`, `age: 0`.

⚠️ **CORRECTION UTILE a la note « l'API GitHub Actions sert des etats
perimes » : `workflow_jobs_filter: {"filter": "latest"}` N'EST PAS le
remede.** Cette section-la consigne une observation UNIQUE ou passer
`"latest"` avait debloque la lecture. Ici c'est l'inverse, mesure : **trois
appels successifs avec `"latest"` ont rendu une reponse byte-identique figee
sur `Import project resources / in_progress`**, et c'est l'appel avec
`{"filter": "all"}` qui a rendu l'etat reel et complet. Les deux observations
ensemble disent la meme chose : **le parametre n'est pas la cause et n'est pas
la cure — seul un SECOND SIGNAL INDEPENDANT tranche.** Ici, comme au lot 3,
c'est le `CACHE_VERSION` reellement servi qui a repondu, et il a repondu dans
les deux sens (d'abord « toujours l'ancien build », donc le job tournait
vraiment ; puis le nouveau).

## KEEPY BATTLE, LOT 7 : REFONTE -- la GARDE et la FEINTE sont SUPPRIMEES, une BARRE DE CHARGEMENT dit quand le coup tombe (21 aout 2026)

Branche `claude/keepy-lot7-gameplay-98dj9f`, redemarree sur `origin/staging`
(`8c8a6c3`) -- elle pointait encore sur `main`, ou le lot 6 n'existe pas.
**Ce n'est ni un reglage ni une couche de plus : c'est une SIMPLIFICATION
assumee**, decidee par Mathieu apres quatre lots qui n'ont jamais deplace le
meme retour device.

### ⚠️ POURQUOI ON A ARRETE DE CORRIGER

Retours device identiques sur les lots **3, 4, 5 ET 6** : « la garde et
l'esquive ne marchent pas, la seule strategie c'est d'attaquer ». Chaque lot a
trouve une cause DIFFERENTE, REELLE et MESUREE, l'a fermee, et a recu la meme
phrase en retour. Les sondes disaient que defendre gagnait (garde 99,3 % au
lot 4, 300/300 pour une politique defensive au lot 5) ; le joueur ressentait
l'inverse.

**Cause finalement retenue** : le joueur savait qu'une attaque ARRIVAIT (le
telegraphe, valide au lot 2) et n'a jamais su QUAND elle frappe. Le lot 4 a en
plus rendu l'instant d'impact volontairement ambigu (feinte : coup retenu
0,28 s). Aucune largeur de fenetre ne fournit cette information -- c'est une
information manquante, pas une fenetre trop etroite.

### LE MODELE SUPPRIME, ET CE QUI LE REMPLACE

**SUPPRIME, pas desactive** -- aucun etat mort, aucun champ orphelin :
`Action.GUARD`, `Action.FEINT`, `Outcome.BLOCKED`, `is_attack_like()`,
`Fighter.telegraph_duration()`, la branche garde de `receive_strike()`,
`FighterView._brace()`/`_absorb_accent()`/`BLOCK_FLASH_COLOR`, le bouton
GARDE du HUD, et **sept champs de profil** (`guard_windup_s`,
`guard_active_s`, `guard_recovery_s`, `guard_damage_ratio`, `feint_hold_s`,
`ai_feint_rate`, `ai_guard_bias`). `FighterBrain` perd deux helpers qui
n'avaient plus qu'une seule valeur de retour atteignable.

**LA BARRE DE CHARGEMENT.** `Body/Charge` remplace le marqueur `Body/Alert`
du lot 6 : une piste sombre, un remplissage clair, et une **bande d'esquive**
qui deborde de la piste. Le remplissage est
`Fighter.charge_progress() = 1 - phase_left/phase_total`, lu **chaque frame**
dans `FighterView._process()`.

⚠️ **La barre pleine EST l'instant d'impact, par CONSTRUCTION et pas par
reglage** : le coup se resout au PREMIER tick d'`ACTIVE`, qui est le tick ou
le windup expire, qui est le tick ou la progression atteint 1,0. Mesure :
**barre pleine a UN TICK pres quand le coup part**, et l'ecart
`|progression - ecoule/total|` reste sous **1e-4** sur tout le remplissage.

⚠️ **PAS un tween, et la raison est le seul endroit ou ca compte.** Toutes les
autres animations de `FighterView` sont des tweens en temps MOTEUR -- aucune
ne promet un instant precis. La barre le promet. Un tween lance sur la
transition WINDUP deriverait contre l'accumulateur a pas fixe de l'arene, et
deriverait le PLUS a la fin, la ou vit toute la mecanique. La vue reste
strictement en LECTURE SEULE (un float entre, un transform sort) -- PHASE B
de `BattleReadabilityProbe` reste byte-identique avec les tweens vivants.

### ⚠️ LE MARQUEUR DU LOT 6 EST SUPPRIME, PAS GARDE A COTE -- c'est une decision

Le marqueur disait « une attaque arrive, a peu pres a ce stade ». La barre dit
ca ET l'instant. **Deux cues qui grandissent dans le meme coin d'ecran se
disputent une seule lecture, et le joueur apprend celui qui mene** -- c'est
exactement l'avertissement que `FighterView` porte deja pour teinte-vs-marqueur
(« les deux canaux doivent etre la MEME horloge »). L'argument de contraste du
lot 6 est transfere intact : remplissage clair dans une piste quasi-noire, donc
l'un des deux franchit toujours 3,0:1. **La rampe de teinte est CONSERVEE** --
autre surface, aucune geometrie en plus, et le lot 6 a mesure qu'elle survit
sur le modele du joueur. La couleur ne veut toujours dire qu'UNE chose : une
esquive ne leve aucune barre et ne rougit rien.

| paire | contraste mesure |
|---|---|
| remplissage vs ciel | **12,91:1** |
| remplissage vs sol | **4,10:1** |
| piste vs sol | 3,67:1 |
| remplissage vs sa propre piste | **15,05:1** |
| bande d'esquive vs ciel / vs sol | **14,9:1 / 4,73:1** (seule, sans etre portee par un voisin) |

### ⚠️ « APPUYER QUAND LA BARRE EST PLEINE » EST FAUX -- d'ou la bande dessinee

Savoir quand le coup tombe n'est que la moitie de ce qu'il faut ; l'autre
moitie est QUAND APPUYER, et ce n'est pas le meme instant. Une esquive a un
startup et une fenetre finie, donc le tap correct est un intervalle qui se
TERMINE avant la barre pleine. **Mesure** : les taps qui esquivent reellement
sont les ticks **26..49 sur 54**, soit **48 %..91 % de la barre, 400 ms de
large**. Un joueur a qui on dit « appuie quand c'est plein » appuie **83 ms
trop tard, a chaque fois**, et apprend que le bouton ne marche pas -- la phrase
exacte de quatre retours device.

La bande est donc DESSINEE, calculee par `BattleArena` (le seul objet qui
connait a la fois le windup de l'attaquant et les timings d'esquive du
defenseur -- une vue qui la deriverait de son propre profil dessinerait une
supposition sur le combattant d'en face).

⚠️ **La bande est DELIBEREMENT un SOUS-ENSEMBLE de ce qui marche.**
L'arithmetique continue donne 0,500..0,944 ; la mecanique quantifiee donne
0,481..0,907. Le bord bas est deja conservateur ; **le bord haut sur-promettait
de deux ticks**, il porte donc une allocation de deux ticks
(`EVADE_EDGE_ALLOWANCE_TICKS`). Une bande qui promet un tap et le fait echouer
est pire que pas de bande : elle enseigne le mauvais timing avec l'autorite du
jeu derriere elle. **Trouve par la sonde, pas par relecture** : l'assertion
« taper au bord haut esquive » est partie ROUGE au premier run.

### ⚠️ PHASE 2 -- les deux pistes existent DEJA, et la question etait le calibrage

Les deux pistes du brief (A : cout en tempo ; B : fenetre stricte) sont toutes
deux **inherentes au FSM** : `dodge_recovery_s` EST le cout, `dodge_active_s`
EST la fenetre. **Les deux sont retenues**, et c'est leur calibrage qui a ete
mesure, pas leur existence.

- **B, la fenetre** : `dodge_active_s = 0,40` -> **400 ms**, soit exactement
  la marge d'erreur du joueur, une pour une (il n'y a aucun autre terme).
  Gate a trois endroits parce qu'elle echoue dans trois directions : trop
  etroite pour la gigue humaine (plancher **4 sigma = 360 ms**), trop large
  (elle couvre **44 %** de la barre ; plafond 75 %, au-dela « taper n'importe
  quand » est correct et la decision disparait), ou fermee avant qu'un humain
  ait pu remarquer la barre (elle ferme a **817 ms** contre 450 ms au pire).
- **A, le cout** : `dodge_recovery_s = 0,36`. Gate par l'inegalite
  `tap + cycle d'esquive < windup + active + recovery` -- **avance au pire tap
  de la fenetre : +13 ms**, mince et positive, et le contre est **mesure** (les
  deux combattants joues, celui qui a esquive frappe le premier) et non calcule.

⚠️ **La bande humaine 300-450 ms du lot 5 n'est PLUS le critere de largeur, et
c'est le vrai changement conceptuel.** Regarder un remplissage se completer est
une ANTICIPATION, pas une REACTION ; la precision humaine sur un instant
anticipe est bien meilleure qu'une latence de reaction. La bande survit pour
UNE chose : le joueur doit d'abord REMARQUER le telegraphe, donc la fenetre ne
doit pas fermer avant qu'il ait pu le voir.

### ⚠️ LE CERVEAU LIT LA BARRE -- correction d'une position que ce lot avait prise deux heures plus tot

Un premier jet de `FighterBrain` refusait `charge_progress()` a l'IA, au motif
que la barre est « une information pour l'oeil humain ». **Mesure, c'etait
faux** : un joueur qui martele ATTAQUE gagnait **294/300** contre cette IA
aveugle, qui tape son esquive des qu'elle repere un telegraphe -- donc bien
trop tot -- et dont la fenetre a expire quand le coup arrive.

**La barre est a l'ecran. Le joueur L'A.** Une IA privee de cette information
n'est pas plus dure ni plus facile, elle joue a un autre jeu -- ce qui (a)
rompt la promesse de l'en-tete de ce fichier et (b) rend toute mesure
d'equilibrage de ce projet une mesure contre un mannequin incapable de faire ce
qu'une personne fait. **C'est le piege `SubstituteModel`, un lot apres le
precedent.** L'IA tire donc une fraction cible une fois par telegraphe
(`ai_dodge_aim`, dispersee par `ai_dodge_slop`) et tape quand le remplissage la
franchit. Ce qu'elle ne peut toujours pas faire : connaitre les timings de
l'adversaire, voir la milliseconde exacte, ou agir avant d'avoir paye son delai
de reaction.

### ⚠️ PHASE 3 -- `attack_recovery_s` est le levier, et la courbe N'EST PAS LISSE

Banc jetable (jamais commite, supprime avant commit), **n=300 par cellule**
(jamais n=40 : ecart-type binomial ~8 points, lecon du lot 3), gigue gaussienne
sigma 90 ms, **les DEUX cotes pilotes** (piege du sac de frappe deja rencontre
trois fois).

**Aucun reglage `.tres` ne corrigeait le martelage contre l'IA aveugle** --
mesure sur cinq champs avant le fix du cerveau, jamais sous 190/300. Apres le
fix, le levier apparait :

| `attack_recovery_s` | martelage (n=150) |
|---|---|
| 0,44 | 47/150 |
| 0,50 | 34/150 |
| **0,56 (valeur de depart)** | **128/150** |
| **0,62 (livre)** | **7/150** |
| 0,70 | 7/150 |

⚠️ **0,56 etait un PIC de resonance**, pas un point representatif : la valeur
que ce lot avait choisie au depart etait le pire point de la courbe. Regler sur
une resonance serait exactement le faux-vert que `ProbeCoverage.gd` documente
cinq fois -- 0,62 et 0,70 forment un plateau, pas un pic.

**Configuration livree** : `attack_windup_s 0,90` / `attack_active_s 0,12` /
`attack_recovery_s 0,62` / `attack_damage 14` / `max_hp 42` /
`dodge 0,05 / 0,40 / 0,36` / `stagger 0,70` / `ai_defense_rate 0,70` (adversaire)
/ `ai_dodge_aim 0,70` / `ai_dodge_slop 0,14`.

| politique caricaturale (n=300) | avant lot 7 | **apres** |
|---|---|---|
| **martelage d'ATTAQUE** | 98,0 % | **11,7 %** (moyenne 10,5 s) |
| esquive seule, jamais d'attaque | 0 % | **0 %** *(par arithmetique : elle n'inflige aucun degat)* |
| **lecture de la barre + contre** | -- | **98,7 %** (moyenne 24,2 s) |

**L'objectif du brief est atteint : le martelage n'est plus dominant, et de
loin.** Reste ouvert et dit franchement : la moyenne de 24,2 s depasse la cible
12-20 s du lot 3, et le max touche le plafond de 60 s -- quand les deux cotes
lisent bien, peu de coups passent. C'est inherent a un telegraphe de 0,90 s ;
non corrige, non maquille.

### Ce qui reste, et ce qui a ete signale plutot que garde « au cas ou »

⚠️ **`BattleTally.GROUP_BLOCKS` est CONSERVE, fige a zero, et documente comme
tel.** Rien ne peut plus l'incrementer. Il n'est PAS retire parce que les rules
Firestore **deployees** sur `keepy-8df91` exigent la cle : `statKeys()` liste
`blocks` et les chemins create/update assertent `hasOnly(statKeys())` **ET**
`hasAll(statKeys())`. Un write sans le groupe serait **REFUSE**, et toutes les
stats de Battle cesseraient d'etre enregistrees **en silence** (BattleStats ne
leve jamais). Le retirer demande un changement de rules, les rules ne se
deploient que sur un push `main` (`firestore-rules.yml` est scope a cette
branche par conception), et **ce lot ne va pas sur `main`**. La monotonie est
respectee entre-temps (increment de 0). **Ordre obligatoire le jour ou on le
retire : les RULES d'abord, le client ensuite** -- l'inverse casse
l'enregistrement pour tout le monde entre les deux.
`BattleStatsProbe` asserte desormais que le groupe est present ET a zero sur un
vrai combat, donc un futur lot qui le reincremente echoue la en premier.

**`BattleFeintProbe` est SUPPRIMEE** avec la mecanique qu'elle gatait. Elle
etait **DEJA ROUGE avant ce lot** (5/27 sur `origin/main`, ses `LATENCIES`
jamais mises a jour depuis le lot 4) -- sa suppression retire un rouge qui n'a
jamais ete celui de ce lot, et c'est dit plutot qu'absorbe dans un run vert.

**Conserves et vivants** : `dodge_windup_s` (vrai startup, il entre directement
dans l'arithmetique de la fenetre), les quatre `ai_*` d'origine, `Outcome.MISSED`.

### Validation

`BattleDefenseProbe` **21/21**, `BattleReadabilityProbe` **62/62**,
`BattleContractProbe` **33/33**, `BattleStatsProbe` **83/83**,
`ProbeTimeoutAudit` **37 sondes** (38 avant, une de moins avec la sonde feinte),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**.

**Determinisme prouve APRES la refonte** : `BattleContractProbe` jouee deux fois
a la graine 20260806 est **byte-identique sur les DEUX flux** (stdout ET
stderr). Les traces ont massivement bouge par rapport au lot 6, comme une
refonte doit le faire -- ce qui est prouve ici est la reproductibilite, pas
l'immobilite.

Import headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909 octets** / md5 `af4a8fc2925d992348eb30deeeb54360` et `index.js` md5
`4e08904b1b7107858246af44b602067b` -- identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur. `index.pck` 5 761 088 (export
unique et propre, `build/` et `.godot/` supprimes avant -- a lire avec la mise
en garde permanente sur son instabilite). Piege payload tenu : **0** ligne
`Storing File` pour `scripts/dev`, `assets_source`, `docs`, `web` ou `build`, et
le banc jetable absent du pack.

**Point de bascule Meshy intact** : rien d'ajoute, deplace ou renomme dans
l'arbre de scene cote combattant hors du sous-arbre `Body/Charge` ; tout passe
toujours par `$Body`/`ModelSlot`, les modeles 3D du lot 6 sont intouches.
**Aucune reference de `scripts/battle/` vers `scripts/dev/`.**

### Reste ouvert -- jugement device, seul juge

1. **La barre se lit-elle comme une horloge** a vitesse reelle sur un
   telephone, et la bande d'esquive se lit-elle comme « appuie ICI » ? Aucune
   sonde ne le dit, et c'est tout l'objet du lot.
2. **La duree des combats** : 24,2 s de moyenne pour un joueur qui lit bien,
   contre 12-20 s vises au lot 3, avec des combats qui touchent le plafond de
   60 s. Mesure, signale, non corrige.
3. **L'avance apres une esquive est de 13 ms au pire tap de la fenetre** --
   positive et gatee, mais mince. Si le contre parait ne jamais passer sur
   device, c'est le premier chiffre a regarder.
4. Le brief precisait « si ca s'avere trop facile, on complexifiera plus tard »
   -- rien n'a donc ete ajoute par precaution.

### Deploiement staging du lot 7 (palier 1, automatique)

`staging` **`f572270`** (merge `--no-ff`, arbre **byte-identique** a la branche
feature : meme hash d'arbre `35c2c90b` des deux cotes, verifie AVANT le push).
CI run **#182** (id `32497515657`) **verte en 3 min 23 s** (15:25:31 ->
15:28:54 UTC) -- `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. **`main` NON touche** (palier 2,
gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`, via
`mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste refuse
sur ce domaine) : `index.service.worker.js` sert
**`CACHE_VERSION = '1787326102|4201998'` = 15:28:22 UTC**, donc **a l'interieur
de la fenetre du run #182**, contre `1787321354` = 14:09:14 (run #181, lot 6).
`x-vercel-cache: MISS`, `age: 0`, `last-modified` colle a l'instant de la
requete -- trois signaux independants qui disent que ce n'est pas une reponse de
cache. L'alias sert bien ce build.

⚠️ **Ce qui est verifie et ce qui ne l'est pas, dit precisement** : le
`CACHE_VERSION` prouve **quel build est aliase**. Le fingerprint `index.wasm`
(**35 376 909** octets, md5 `af4a8fc2925d992348eb30deeeb54360`) est celui de
l'export LOCAL de cette session, pas relu sur le service -- l'`index.html`
servi n'a pas ete refetche pour l'extraire. Les deux ensemble etablissent la
chaine commit -> build -> deploiement ; la barre elle-meme est dessinee par
Godot dans le canvas et **aucune de ces mesures ne la voit**. Jugement device.

### ⚠️ TROISIEME INCIDENT DE SESSIONS CONCURRENTES -- le lot 7 a ete brieffe DEUX fois (21 aout 2026)

**La regle n°1 de ce fichier a ete enfreinte une troisieme fois** (precedents
du 6 et du 11 aout 2026). Deux sessions ont recu le meme brief lot 7. La
premiere (`claude/keepy-lot7-gameplay-98dj9f`) a livre, merge sur `staging`
(`f572270`) et deploye a 15:28 UTC. La seconde
(`claude/keepy-lot7-gameplay-dle7il`) a demarre a 17:32 UTC.

**Resolu comme les deux precedents le prescrivent, et moins cher** : le
`git fetch --all --prune` a ete fait AVANT d'ecrire une ligne -- la lecon
explicite de l'incident du 11 aout (« faire ce fetch AU DEBUT, pas a la
fin »). La seconde session n'a donc produit AUCUN doublon a abandonner : elle
a constate que `origin/staging` portait deja le lot, et s'est convertie en
AUDIT INDEPENDANT au lieu de le refaire. Cout du doublon : zero ligne de code,
contre ~3 h de travail duplique au 11 aout.

⚠️ **Rien dans l'outillage n'a signale la collision, une troisieme fois.** Le
seul indice etait la presence de `origin/claude/keepy-lot7-gameplay-98dj9f`
dans `git branch -r`, avec un arbre identique a `origin/staging`. **Comparer
les arbres (`git rev-parse <ref>^{tree}`) plutot que les noms de branche est ce
qui a tranche en une commande.**

#### Ce que l'audit independant a verifie -- rejoue, pas relu

Editeur Godot 4.3-stable installe dans ce second sandbox, import headless
complet (**24 `.scn`**, le piege du faux-rouge par import tronque controle et
non suppose). Sondes rejouees sur l'arbre `origin/staging` lui-meme :

| sonde | resultat | revendique par le lot |
|---|---|---|
| `BattleContractProbe` | **33/33, exit 0** | 33/33 |
| `BattleReadabilityProbe` | **62/62, exit 0** | 62/62 |
| `BattleDefenseProbe` | **21/21, exit 0** | 21/21 |
| `BattleStatsProbe` | **83/83, exit 0** | 83/83 |
| `ProbeTimeoutAudit` | **37 sondes**, toutes armees | 37 |
| `AssetContractAudit` | 12/12 visuels, **0/10 colliders deplaces** | idem |
| `DeathModelAudit` / `ChargerShapeProbe` | exit 0 | idem |

**Les chiffres d'equilibrage se reproduisent a l'unite pres** sur une autre
machine : martelage **35/300 = 11,7 %** (moyenne 10,5 s), esquive seule
**0/300**, lecture-de-la-barre + contre **296/300 = 98,7 %** (moyenne 24,2 s).
**L'objectif du brief -- le martelage n'est plus dominant -- est donc confirme
par une mesure independante**, pas seulement par celle qui l'a produit.

**Determinisme re-prouve APRES refonte** : `BattleContractProbe` jouee deux
fois a la graine 20260806 dans ce sandbox est **byte-identique sur les DEUX
flux** (stdout md5 `bd015b777aa42ce310dd35cba95512f3`, stderr identique).
**Contrat central de la barre re-mesure** : ecart
`|progression - ecoule/total|` **0,000000** sur tout le remplissage, barre
pleine a **0,9815** au dernier tick de charge, coup parti au tick 54 sur 54.

**Suppressions verifiees par grep plutot que par lecture** : `Action` ne
contient plus que `NONE / ATTACK / DODGE`, **zero code actif** contenant
`GUARD`/`FEINT`/`feint_*`/`guard_*`/`ai_feint_rate` hors commentaires
historiques, `BattleFeintProbe.{gd,tscn}` absente, et **aucune reference de
`scripts/battle/` vers `scripts/dev/`**. `BattleTally.GROUP_BLOCKS` est bien
conserve fige a zero, et c'est **correct** : `firestore.rules` deploye exige
`blocks` via `hasAll(statKeys())` (ligne 414), donc un write sans le groupe
serait refuse en silence. L'ordre « rules d'abord, client ensuite » consigne
par le lot tient.

**Aucun defaut trouve. Rien n'a ete corrige parce qu'il n'y avait rien a
corriger.**

#### ⚠️ Une seule nuance : le `CACHE_VERSION` consigne n'est PAS celui servi

Le lot cite `1787326102` = 15:28:22 UTC (run **#182**, le merge). Le service
sert **`1787326751` = 15:39:11 UTC**, soit le run **#183** -- le commit de doc
`20962d5`, qui a redeploye staging derriere lui. **Ni une erreur ni une
regression** : les deux builds ont un contenu de jeu identique (`CLAUDE.md`
n'est pas une ressource Godot), et l'epoch servi est POSTERIEUR au lot, donc
l'alias sert bien la refonte. C'est le meme schema deja consigne aux lots 3 et
5 (« l'alias pointe sur le run du commit de doc »). Dit ici pour qu'un futur
lecteur ne cherche pas l'epoch du #182 sur le service et n'en conclue pas qu'un
mauvais build est en ligne. Verifie a la re-lecture : `x-vercel-cache: HIT`,
`age: 1515` -- une reponse de cache CDN, donc **pas** les trois signaux de
fraicheur habituels ; c'est le `CACHE_VERSION` lui-meme, posterieur au lot, qui
porte la preuve ici, pas les en-tetes.

**Reste ouvert : inchange par cet audit.** Les quatre points du lot 7 restent
exactement ce qu'ils sont -- et le premier (la barre se lit-elle comme une
horloge a vitesse reelle sur un telephone) reste **hors de portee de toute
sonde de ce depot**. Aucune mesure de cette session ne le touche.

## KEEPY BATTLE, LOT 8 : L'ESQUIVE RAPPORTE ENFIN -- attaque INSTANTANEE cote joueur, et une RIPOSTE (21 aout 2026)

Branche `claude/lot-8-esquive-rapporte-prq4b5`, partie de `staging`
(`e00d0a5`). **Premier retour device positif en sept lots** : « Oui
j'esquive effectivement » -- le mecanisme de la barre du lot 7 FONCTIONNE.
Suivi de « mais je fais que perdre » : le joueur esquive bien et ne place
jamais de coup.

### PHASE 0 -- le chronogramme, et la cause n'etait PAS celle qu'on croyait

Le lot 7 avait deja signale deux fois son propre point faible : **+13 ms
d'avance apres une esquive reussie**, au pire tap de la bande dessinee.
Reproduit ici au tick pres (modele du FSM livre, avec le report d'overshoot) :

| tap (tick de la barre, sur 54) | defenseur libre | attaquant libre | avance |
|---|---|---|---|
| 28 (bord bas reel) | 76 | 99 | **+383 ms** |
| 49 (bord haut DESSINE) | 97 | 99 | **+33 ms** |
| 51 (bord haut reel) | 99 | 99 | **0 ms** |

⚠️ **Mais l'avance n'a jamais ete le vrai defaut, et c'est le resultat
central de la recon.** Meme a +383 ms, le contre du joueur etait
lui-meme **une attaque telegraphiee de 0,90 s avec sa bande d'esquive
dessinee**, que l'adversaire lit exactement comme le joueur lit la
sienne. Mesure sur les profils livres :

> `ai_dodge_aim 0,70 +- ai_dodge_slop 0,14` donne une plage de tirage
> **0,56..0,84**, entierement **a l'interieur** de la bande d'esquive
> reelle **0,519..0,944**. Quand l'adversaire decide d'esquiver, il
> reussit **~100 %** du temps.

Avec `ai_defense_rate = 0,70`, **~70 % des attaques du joueur etaient
esquivees d'office**, chacune coutant 1,64 s d'exposition. Le joueur
survivait et ne marquait pas : la phrase exacte du retour device.

⚠️ **Le banc du lot 7 ne pouvait pas voir ca, et c'est mesure et non
suppose.** Sa politique « lecture de la barre + contre » tapait son
contre **le tick meme ou elle redevenait libre** -- une machine, pas une
personne. Le meme banc, avec une latence humaine de 380 ms sur le contre,
donne **65,7 %** au lieu de 98,7 %, et des combats de **43 s** au lieu de
24,2 s. Ce seul terme manquant est tout l'ecart entre le rapport de sonde
et le retour device.

*(Banc Python jetable, jamais commite. Il n'a ete cru qu'apres avoir
**reproduit les trois chiffres publies du lot 7** : martelage 10,7 % /
10,3 s contre 11,7 % / 10,5 s, esquive seule 0 %, lecture+contre a
latence nulle 99,0 % / 23,6 s contre 98,7 % / 24,2 s.)*

### PHASE 1 -- l'attaque instantanee, et la barre RETIREE cote joueur

`keepy.tres` : **`attack_windup_s = 0.0`**. Le tap EST le coup : la frappe
se resout **au tick suivant (17 ms)**, gate par `BattleContractProbe`
PHASE A2.

**La barre disparait cote joueur par CONSEQUENCE, pas par un drapeau.**
`Fighter.is_charging()` exige desormais `_phase_total > 0.0`, et
`FighterView` s'y branche : un wind-up de longueur nulle traverse bien
l'etat WINDUP pendant un tick, et sans cette condition il aurait leve une
barre pleine pendant une frame -- et offert a l'IA une fraction a viser
sur une attaque par construction irreactable. Gate sur la scene livree :
**« an instant attack never raises a bar, not even for one frame »**, plus
l'absence de bande d'esquive (`is_visible_in_tree()`, pas le drapeau
local : la question est « est-ce dessine », pas « ce noeud est-il coche »).

⚠️ **Erreur de conception du lot 7 actee** : la barre avait ete posee des
DEUX cotes en croyant aider. Elle imposait en realite un timing au joueur
sur ses PROPRES coups -- or un coup qu'on decide n'est pas un coup qu'on lit.

⚠️ **CE QUI REMPLACE LA LECTURE DE LA BARRE PAR L'IA : RIEN, et c'est
mesure, pas compense.** Le chemin `_dodge_aim` de `FighterBrain` devient
**inatteignable** contre le joueur livre. L'IA retombe sur une esquive
aveugle -- une supposition -- ce qui est exactement ce dont dispose une
personne face a une attaque irreactable, et precisement pourquoi
`keepy.tres` price cette attaque en **chip (5)** et non en coup plein. Le
chemin est **CONSERVE et non supprime** : c'est le comportement du cerveau
face a tout adversaire telegraphie, ce qu'il rencontre des que le cablage
est mirroite (`BattleContractProbe` PHASE E le fait).
**Aucun reglage `ai_*` n'a ete durci** -- la consigne etait de mesurer
d'abord, et la mesure dit que ce n'etait pas necessaire.

### ⚠️ LA REGLE QUI REND TOUT LE RESTE POSSIBLE : un coup ORDINAIRE ne stagger plus

Sans elle, une attaque instantanee et annulante repetee plus vite que le
wind-up adverse est un **stun-lock**. **Mesure, pas deduit : martelage
300/300 (100 %) avec le stagger sur les coups ordinaires, 8 % sans.**

| | degats | stagger | annule le wind-up en cours |
|---|---|---|---|
| attaque **ordinaire** | `attack_damage` | **non** | **non** |
| **RIPOSTE** | `riposte_damage` | oui | oui |

Un telegraphe se termine donc **meme sous le feu** : marteler echange des
degats contre chaque coup que l'adversaire porte, au lieu de l'empecher
de jouer. Gate en trois assertions distinctes dans `BattleContractProbe`
PHASE B, dont **« a BLIND hit does NOT cancel the action it lands on »**.

### PHASE 2 -- LA RIPOSTE, coeur du lot

Une esquive qui couvre reellement un coup arme une riposte pour
`riposte_window_s`. **La fenetre ne se consomme QUE pendant les ticks
IDLE.** C'est le point qui decide si le mecanisme existe : l'esquive qui
gagne la riposte verrouille aussi son proprietaire pour la fin de son
propre cycle, et une fenetre comptee depuis l'instant de l'esquive serait
deja largement depensee avant que le joueur puisse bouger. Mesure sur le
FSM livre : **1200 ms encore ouverts au moment ou l'esquiveur redevient
libre**.

Latchee **au tap** (`_begin_action`), pas a la resolution : la recompense
appartient au moment ou le joueur decide. Une esquive = **une** riposte
(gate). Un stagger ou un KO la perdent.

**La fenetre de punition passe de 13 ms a 343 ms**, et le gate change de
nature -- il ne compare plus a zero mais **a un humain** :

| | lot 7 | lot 8 |
|---|---|---|
| avance deterministe au pire tap | **13 ms** | **343 ms** *(gate >= 300 ms, tap rapide)* |
| + temps de reflexion minimal adverse | -- | **643 ms** *(gate >= 450 ms, tap lent)* |

Le second est un **plancher dur** : `ai_reaction_jitter_s` n'est jamais
que additionne. C'est `attack_recovery_s` de l'adversaire (0,62 -> 0,95)
qui paie cette fenetre, et rien d'autre ne le peut -- l'inegalite est
ecrite au champ dans `FighterProfile.gd`.

⚠️ **`dodge_recovery_s` reste a 0,36, et ce n'est pas de l'immobilisme :
en dessous, le SPAM D'ESQUIVE devient dominant.** Mesure (n=300) :
dodge_rec 0,36 -> spam **0 %** ; 0,30 -> **100 %** ; 0,28 -> 97,7 % ;
0,24 -> 75,3 %. La couverture d'un spammeur est `da/(dw+da+dr)`, donc
raccourcir le cout de l'esquive le fait esquiver par accident. **La
fenetre de punition a donc ete achetee entierement du cote de
l'attaquant.**

**Attaquer SANS avoir esquive reste libre, et coute.** Le chip est
`attack_damage = 5` contre `riposte_damage = 14` (2,8x), sans stagger, et
il expose pendant `attack_active_s + attack_recovery_s` = **833 ms**
mesures. `PHASE C2` gate que la riposte coute **strictement plus** sur les
deux axes.

⚠️ **PHASE C2 A ETE RESCOPEE, et l'ancienne inegalite est PUBLIEE EN
ECHEC plutot que contournee.** Jusqu'au lot 7 elle assertait
`stagger_duration_s > toute recovery` -- juste tant que TOUT coup propre
staggerait, puisque le tempo etait alors le cout entier d'etre touche. Ce
n'est plus le cas. La satisfaire imposerait de monter les staggers
au-dessus des 950 ms de recovery de l'adversaire, et **c'est mesure : le
spam d'esquive passe alors de 0 % a 100 %** (une riposte chanceuse
verrouille assez longtemps pour placer la suivante). Chiffre publie, gate
remplace par l'invariant qui compte reellement.

### La riposte est VISIBLE, et ca n'etait pas optionnel

`FighterView` **tient** l'aqua `RIPOSTE_HOLD_COLOR` tant que la riposte
est depensable -- meme famille que le flash d'esquive reussie et que la
bande d'esquive de la barre : la marque qui dit « tape ici », le flash qui
dit « ca a marche » et le maintien qui dit « encaisse maintenant » sont
une seule couleur racontant une seule histoire. Le rouge continue de ne
vouloir dire qu'une chose, et il vit sur l'ADVERSAIRE.

⚠️ **Piege rencontre et ferme** : le flash d'esquive se rejoue vers
`_base_color`, donc il effacait le maintien **la frame meme ou il se
levait** (`riposte_changed` est emis AVANT `hit_taken`). Toutes les
detentes « retour au neutre » passent desormais par `_rest_color()`, qui
rend le maintien quand une riposte est due. Le cue existait et n'aurait
jamais ete vu.

### PHASE 3 -- equilibrage, n=300, les DEUX cotes pilotes

Politiques caricaturales, **chaque tap payant une reaction humaine de
300-450 ms tiree par tap** (le terme que le lot 7 n'avait pas) :

| politique | lot 7 | **lot 8** | duree moyenne |
|---|---|---|---|
| martelage d'ATTAQUE | 11,7 % | **8,0 %** | 8,7 s |
| esquive seule | 0 % | **0 %** *(par arithmetique : zero degat)* | 60,0 s |
| esquive-panique (tap des que la barre apparait) | -- | **0,0 %** | 8,6 s |
| **lecture de la bande + riposte** | 98,7 % | **100,0 %** | **12,9 s** |
| **la meme, JOUEUR IMPARFAIT** (3 lectures sur 4, gigue 140 ms) | -- | **80,0 %** | **14,7 s** |

**Les trois objectifs du brief sont atteints** : le martelage n'est pas
dominant, esquive+contre est de loin la meilleure strategie, et la marge
d'erreur existe -- **la ligne 100 % est une machine** (elle lit chaque
barre et ne se trompe jamais), la ligne a 80 % est ce que la meme
strategie vaut quand les lectures cessent d'etre gratuites.

**Les durees rentrent dans la cible 12-20 s** (12,9 / 14,7 s de moyenne,
max 18-20 s) contre **24,2 s de moyenne et des combats au plafond de 60 s**
au lot 7 -- l'attaque instantanee raccourcit bien, comme le brief le
prevoyait.

⚠️ **`attack_recovery_s` du JOUEUR = 0,72, choisi au CENTRE D'UN PLATEAU
et surtout pas au bord.** Le lot 7 avait deja documente des pics de
resonance sur ce champ ; il y en a un ici aussi, et **plus net** :

| `attack_recovery_s` joueur | 0,56 | 0,58 | 0,60 | **0,62** | 0,66 | 0,70 | 0,74 | 0,78 |
|---|---|---|---|---|---|---|---|---|
| spam d'esquive (base A / base B) | 100/100 | 100/100 | 100/100 | **0/0** | 0/0 | 0/0 | 0/0 | 0/0 |

Falaise **deterministe** (identique sur les deux bases de graines) entre
0,60 et 0,62. Se poser sur 0,62 serait se poser sur le bord ; **0,72** est
au milieu du plateau 0,62-0,90, avec le martelage a 0-4 % sur toute sa
longueur.

**Damage adverse 14/18 -> 12/16** : a 10/14 le spam d'esquive revient
(23 % base A, 31 % base B -- instable), a 14/18 le martelage tombe a 0 %.
12/16 est stable sur les deux bases. `max_hp` adverse 42 -> **64** pour la
duree.

### Determinisme

Prouve **APRES** le changement de gameplay, comme l'exige la consigne :
`BattleContractProbe` PHASE D joue le meme combat deux fois a la graine
20260820 et compare une trace par tick -- **byte-identique (7929 car.)**,
et **differente** a une autre graine (une trace toujours identique
passerait aussi si le combat etait gele). `BattleReadabilityProbe` PHASE B
rejoue le meme combat avec de vraies frames entre les ticks : **trace
byte-identique, 582 ticks des deux cotes** -- le temps moteur ne fuit
toujours pas dans le FSM. Aucun `randi()` global dans `scripts/battle/`.

### Une source de verite pour le prix d'un coup

`FighterProfile.damage_for(riposte)` est **le seul endroit** qui choisit
entre les deux nombres. `BattleArena` price avec, et **toutes** les sondes
resolvent avec -- donc un fixture ne peut pas pricer une riposte comme un
chip et rester vert. C'est la divergence, sur l'axe exact que ce lot
change, que ce depot a deja payee une fois (`SubstituteModel.tscn`).
Double-verrouille par **`BattleDefenseProbe` PHASE R2**, qui resout un
chip ET une riposte a travers **`Battle.tscn` lui-meme** -- vraie scene,
vrai `BattleArena`, vrai cablage : **5 dmg sans stagger, 14 dmg avec**.

### Deux defauts de SONDE trouves en chemin, corriges dans la sonde

1. **`BattleContractProbe` PHASE A et `BattleReadabilityProbe` PHASE C
   mesuraient le telegraphe sur le profil du JOUEUR** -- devenu le cas
   DEGENERE. Elles auraient asserte qu'un wind-up de 0 s dure 0 s et que
   rien n'a bouge pendant, ce qui est vrai et vide de sens. Bascculees sur
   le profil ADVERSE, qui est aussi le bon choix semantique : un
   telegraphe est une chose que le DEFENSEUR lit, donc il n'existe que sur
   le combattant d'en face. PHASE A2 couvre le cas zero explicitement.
2. **`BattleStatsProbe` PHASE F : un caricature `ticks % 3` silencieusement
   fragile.** Le joueur n'y est sollicite que quand il est libre, donc le
   choix dependait de la longueur du verrouillage **modulo 3** -- et
   l'attaque instantanee l'a mis a exactement 51 ticks. Le caricature
   attaquait et n'esquivait plus jamais : la sonde qui existe pour voir
   tous les compteurs en perdait la moitie. Remplace par une **bascule sur
   chaque action acceptee**, qui ne peut pas entrer en resonance avec un
   timing.

### Validation

`BattleContractProbe` **46/46**, `BattleDefenseProbe` **36/36**,
`BattleReadabilityProbe` **65/65**, `BattleStatsProbe` **83/83**,
`ProbeTimeoutAudit` **37 sondes scenes, toutes armees**,
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe` -- **toutes exit 0**.
Import headless **exit 0**, export Web release **exit 0**, `index.wasm`
**35 376 909** octets / md5 `af4a8fc2925d992348eb30deeeb54360` et
`index.js` md5 `4e08904b1b7107858246af44b602067b` -- identiques au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur.
Piege payload tenu : **0** ligne `Storing File` pour `scripts/dev`,
`assets_source`, `docs`, `web`, `build` ou `firebase.json`.

**Lot 6 intact** : rien d'ajoute, deplace ou renomme dans l'arbre de
scene, tout passe toujours par `$Body`/`ModelSlot`, les modeles 3D sont
intouches, et la barre de l'adversaire garde son contrat et ses ratios de
contraste (remplissage 12,91:1 vs ciel, 4,10:1 vs sol, bande d'esquive
14,9:1 / 4,73:1). **Vue toujours strictement en lecture seule sur le
FSM. Aucune reference de `scripts/battle/` vers `scripts/dev/`.**

⚠️ **`BattleTally.GROUP_BLOCKS` reste FIGE A ZERO**, verifie sur un vrai
combat par `BattleStatsProbe`. Les rules Firestore deployees exigent la
cle via `hasAll(statKeys())` : un write sans elle serait refuse **en
silence**. L'ordre reste obligatoire le jour ou on le retire -- **rules
d'abord, client ensuite** -- et les rules ne se deploient que sur `main`.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que l'esquive se SENT enfin payante ?** C'est tout l'objet du
   lot, et aucune sonde ne le dit. Ce qui est mesure, c'est que la fenetre
   existe (343 ms deterministes, 643 ms garantis) et que la riposte fait
   2,8x le chip en staggerant ; ce qui ne l'est pas, c'est qu'un joueur la
   voie et la prenne.
2. **Le maintien aqua se lit-il comme « tu as un coup en reserve »** ou
   comme une simple lueur ? C'est le seul canal qui annonce la recompense.
3. **L'attaque instantanee se sent-elle reactive ou brutale ?** Elle est
   irreactable pour l'adversaire par construction ; a 833 ms de
   verrouillage apres chaque tap, elle peut aussi se sentir lourde.
4. **L'esquive-panique perd 100 % des combats.** Argumente (la bande est
   DESSINEE, et « ESQUIVE RATEE » plus le flash violet disent au joueur
   qu'il a tape trop tot), mais c'est une lecon severe pour un premier
   contact -- a surveiller si Mathieu retrouve « trop dur ».
5. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif : hors perimetre, inchange.

### Deploiement staging du lot 8 (palier 1, automatique)

`staging` **`22f3b42`** (merge `--no-ff`, arbre **byte-identique** a la
branche feature : meme hash d'arbre `3a0ff0e7` des deux cotes, verifie
AVANT le push). CI run **#185** (id `32515598018`) **verte en 3 min 31 s**
(18:52:59 -> 18:56:30 UTC) -- `Deploy to Vercel [STAGING -- staging]`
succes, `[PRODUCTION -- main]` correctement **skipped**. **`main` NON
touche** (palier 2, gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas dans le log CI** (`keepy-staging.vercel.app`,
via `mcp__Vercel__web_fetch_vercel_url` -- l'egress direct du sandbox reste
refuse sur ce domaine) : `index.service.worker.js` sert
**`CACHE_VERSION = '1787338553|4187371'` = 18:55:53 UTC**, donc **a
l'interieur de la fenetre du run #185**, contre `1787334325` = 17:45:25
(run #184) juste avant. `x-vercel-cache: MISS`, `age: 0`, `last-modified`
colle a l'instant de la requete -- trois signaux independants de fraicheur.
L'alias sert bien ce build.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES** (deux
appels `list_workflow_jobs` **byte-identiques**, figes sur « Import project
resources / in_progress », `filter: "latest"` compris). **C'est le
`CACHE_VERSION` servi qui a tranche, dans les DEUX sens** : lu trop tot il
valait encore celui du run #184, ce qui confirmait que le job tournait
REELLEMENT au lieu d'etre un cache perime, puis il est passe a
`1787338553`. Un poll de plus ne l'aurait pas fait -- la regle « second
signal independant » deja consignee tient une fois de plus.

⚠️ **Piege de mesure rencontre pendant la validation, et il aurait produit
un FAUX ROUGE.** Les deux sondes gameplay seedees `ComboAudit`/
`ShrinkAudit` sont sorties **DIFFERENTES** au premier essai. Ce n'etait pas
une regression : **le run de la branche avait ete TUE en cours** (1009
octets contre 2670, coupe en plein « phase RISKY »), parce qu'il partageait
la machine avec l'export et les autres sondes. Rejouees proprement l'une
apres l'autre, elles sont **byte-identiques sur les DEUX flux** (2670 et
2149 octets des deux cotes). **Comparer les TAILLES avant de comparer les
contenus** : meme famille que le faux-rouge par import tronque deja
consigne, et une sortie tronquee ne se signale pas elle-meme.

## KEEPY BATTLE, LOT 9 : REEQUILIBRAGE DES DEGATS -- le ratio baisse, martelage NE bouge PAS (21 aout 2026)

Branche `claude/lot-9-damage-rebalance-pxw02t`, partie de `staging` (`054c8dc`,
lot 8). Retour device : « les attaques du hibou infligent des degats enormes,
disproportionne », et les deux symptomes a la fois -- le joueur meurt vite ET
n'arrive pas a faire baisser la vie de l'adversaire.

### PHASE 0 -- les chiffres re-verifies, et un etaient faux dans le brief

Le brief tablait sur « 64 PV joueur -> mort en 6 coups ». **Faux, mesure dans
les `.tres` et pas cru sur parole** : `keepy.tres.max_hp = 42`, pas 64 (64 est
le `max_hp` de **Sparring**, l'adversaire). Avec `attack_damage` adverse a 12,
un joueur passif meurt en `ceil(42/12) = 4` coups, pas 6. Le ratio
`adv_dmg/chip = 12/5 = 2,4x` cite dans le brief, lui, etait exact.

### PHASE 1 -- le conflit trouve par le sweep : le ratio cible casse le martelage

**Le vrai risque du lot n'etait pas dans le brief.** Un sweep en grille
(banc Python jetable reproduisant la FSM au tick pres, puis confirme sur
`BattleDefenseProbe` PHASE D -- le vrai banc, permanent, deja dans le depot)
montre que le taux de victoire du **martelage** est gouverne par une course de
DPS pure : `chip / cycle_joueur` contre `adv_dmg / cycle_adverse`. Monter le
chip sans toucher `attack_recovery_s` du joueur fait **exploser** le
martelage :

| adv_dmg | chip | ratio | martelage (rec=0.72 inchangee) |
|---|---|---|---|
| 12 (livre lot 8) | 5 (livre lot 8) | 2,40x | **11,7 %** (baseline) |
| 10 | 6 | 1,67x | **59,0 %** |
| 10 | 7 | 1,43x (cible du brief) | **63,3 %** |
| 11 | 8 | 1,38x | **94,3 %** |

**Directement au-dela de 8 dmg de chip, le martelage devient QUASI CERTAIN
(94-100 %).** Un ratio de 1,43x tel que suggere par le brief, applique
litteralement (chip 5->7, adv 12->10, rien d'autre), aurait rouvert
exactement l'exploit que les lots 7 et 8 ont ferme a la sueur -- « il suffit
d'attaquer » serait redevenu vrai.

### Le levier trouve, et il n'etait PAS dans le perimetre suggere : `attack_recovery_s` du JOUEUR

`attack_recovery_s` ralentit le cycle de chip SANS ralentir la riposte
(meme champ de timing, mais la riposte n'est quasi jamais throttlee par lui
puisqu'elle n'est tiree qu'apres une esquive reussie -- **mesure, pas
suppose** : `read+riposte`/`read+riposte-sloppy` restent a 100,0/14,0s et
94-96%/17,4-17,8s sur TOUTE la plage de recovery testee, 0,72 a 1,24). Sweep
fin a `adv=10 chip=7` (ratio 1,43x, la valeur suggeree par le brief) :

| `attack_recovery_s` joueur | martelage (3 graines) | chip DPS |
|---|---|---|
| 0,72 (livre lot 8) | 63,3 / 66,3 % | -- |
| 0,96 | 44,7 / 46,3 / 40,3 % | -- |
| 1,04 | 28,3 / 24,3 / 24,3 % | -- |
| 1,12 | 17,3 / 14,3 / 11,7 % | -- |
| **1,16 (retenu)** | **7,7 / 10,0 / 6,3 %** | 5,47 (baseline 5,95) |
| 1,20 | 6,3 / 4,0 / 3,7 % | -- |
| 1,24 | 1,7 / 3,0 / 2,7 % | -- |

⚠️ **La courbe n'est PAS monotone -- resonance, meme famille que celle deja
documentee au lot 7/8 sur ce meme champ.** Un point isole (ex. rec=0,88 : le
sweep montrait 95-97% de martelage, PIRE qu'a 0,72) aurait pu faire choisir
une fausse zone sure. `1,16` a ete verifie stable sur 3 graines independantes
et n'est pas sur un pic.

### Configuration retenue : EXACTEMENT le point suggere par le brief, PLUS le levier necessaire

`dummy.tres` (Sparring) : `attack_damage 12 -> 10`.
`keepy.tres` (Keepy) : `attack_damage 5 -> 7`, **`attack_recovery_s 0,72 ->
1,16`** (le champ non prevu par le brief, requis pour tenir « martelage reste
non dominant »).

`riposte_damage` **INCHANGE** des deux cotes (14 / 16) : ratio riposte/chip
Keepy `14/7 = 2,0x` (contre 2,8x avant) -- juge suffisant, la riposte reste
strictement plus forte ET la seule a staggerer (`BattleDefenseProbe` PHASE C2
gate `riposte_damage > attack_damage`, verifie).

Hits pour tuer (unguarded, worst case) :
- joueur (42 PV) vs adversaire : `ceil(42/12)=4` avant -> `ceil(42/10)=5`
  apres (**+25% de survie**).
- adversaire (64 PV) vs chip seul : `ceil(64/5)=13` avant -> `ceil(64/7)=10`
  apres (**chip plus fort, moins de coups pour vider la barre**).
- adversaire vs riposte seule : `ceil(64/14)=5`, inchange (la riposte reste le
  chemin de kill rapide).

### Validation, sur le VRAI banc du depot (`BattleDefenseProbe` PHASE D), pas une approximation

`BattleDefenseProbe` embarque deja un banc **permanent** (reported, jamais
gate) qui pilote les DEUX combattants (le vrai `FighterBrain` cote
adversaire, une politique caricaturale cote joueur, chaque tap payant une
latence humaine 300-450ms) -- exactement la methode que ce lot demandait,
deja ecrite. **3 graines independantes** (`20260821`, `31415926`, `7654321`
-- edit temporaire de la constante interne, jamais commite, revert avant tout
commit), 300 combats chacune, 900 combats par config :

| politique | AVANT (lot 8, moyenne 3 graines) | APRES (lot 9, moyenne 3 graines) |
|---|---|---|
| **martelage** | **8,2 %** (8,0/7,7/9,0) | **8,2 %** (7,3/8,0/9,3) -- **inchange** |
| dodge-only | 0,0 % (par arithmetique) | 0,0 % -- inchange |
| panic-dodge | 0,0 % | 0,0-0,3 % -- inchange |
| read+riposte (parfait) | 99,8-100,0 % | 99,3-100,0 % -- inchange |
| **read+riposte-sloppy (imparfait)** | **77,3 %** (80,0/72,7/79,3) | **80,1 %** (82,0/78,3/80,0) |
| duree (sloppy) | 14,5-14,9s | 14,9-15,0s |

**Le martelage ne bouge PAS d'un point sur la moyenne des 3 graines** --
c'etait l'invariant a proteger, et le sweep de la section precedente est ce
qui l'a garanti plutot que de le decouvrir apres coup. **Le lecteur imparfait
gagne PLUS souvent dans les 3 graines sur 3** (82,0>80,0 ; 78,3>72,7 ;
80,0>79,3) -- amelioration modeste (+2,8 points en moyenne) mais
**consistante**, pas un artefact d'une seule graine chanceuse. La cible du
brief (« le joueur imparfait doit gagner PLUS souvent qu'au lot 8 ») est donc
atteinte, avec l'honnetete que ce n'est pas un saut spectaculaire.

⚠️ **Reference unique-graine a connaitre** : la valeur `80,0 %` citee dans le
brief comme « base lot 8 » est la sortie de la graine par defaut de la sonde
(`20260821`), et un seul run supplementaire a une autre graine (`31415926`)
donne **72,7 %** pour ce MEME code -- un ecart de 7+ points venant de la seule
graine, sur 300 combats. **Ne jamais lire un seul run de PHASE D comme une
verite absolue** ; les 3 graines ci-dessus existent pour ca.

### PHASE 2 -- l'esquive-panique : `dodge_recovery_s` est MECANIQUEMENT DECOUPLE, verifie sur le vrai banc

Le brief demandait de regarder `dodge_recovery_s` pour adoucir la lecon
severe de l'esquive-panique (100 % de defaites). **Reponse franche : ce
champ n'a AUCUN effet sur ce policy, ni en Python ni sur le vrai banc du
depot -- verifie par edit temporaire + revert, pas suppose.**

```
dodge_recovery_s=0.20  panic-dodge wins   1/300 (  0.3%)  mean  11.3s
dodge_recovery_s=0.28  panic-dodge wins   0/300 (  0.0%)  mean  11.3s
dodge_recovery_s=0.36  panic-dodge wins   0/300 (  0.0%)  mean  11.3s
```

**Duree ET taux de victoire identiques au bruit pres sur toute la plage.**
Lu dans le code de la sonde (`BattleDefenseProbe.gd::_policy_fight`) : le
panic-dodge tape sa DODGE **au tick meme ou la barre apparait** (`t=0` du
windup adverse, zero latence de reaction meme), une seule fois par
telegraphe, sans retenter. Le succes d'un tel tap depend uniquement de
`dodge_windup_s` et `dodge_active_s` (est-ce que la fenetre active, calee sur
CE tap, couvre l'instant du coup) -- `dodge_recovery_s` ne gouverne QUE le
cout d'un enchainement de plusieurs esquives (spam), jamais la reussite d'un
tap unique deja tire. Un tap a `t=0` a besoin de `dodge_active_s >= W - dw`
(soit `>= 0,85s`, plus du DOUBLE de la valeur actuelle 0,40s) pour esperer
couvrir le coup -- une largeur qui, mecaniquement, ferait aussi decoller le
spam d'esquive continu par le meme argument de duty-cycle qui a motive le
`dodge_recovery_s=0,36` actuel (piste testee en Python : `dodge_active_s`
0,40->0,50->0,55 fait passer panic-dodge de 0% a 68% a 100%, un saut abrupt
dans la meme zone que celle documentee comme dangereuse pour le spam).

**Aucune valeur de `dodge_recovery_s` ne satisfait donc l'objectif du
brief, parce que ce n'est pas la variable en jeu -- dit franchement plutot
que choisir un compromis silencieux.** Le levier reel serait
`dodge_active_s`/`dodge_windup_s`, hors du champ que le brief a nomme, et son
elargissement porte un risque de spam documente sur cet axe meme. **NON
touche dans ce lot** -- `dodge_recovery_s` reste a `0,36` des deux cotes,
inchange. Une future session qui voudrait vraiment adoucir l'esquive-panique
devrait ouvrir son propre lot sur `dodge_active_s`, avec sa propre passe de
validation device (le risque de spam n'a pas ete mesure sur le vrai banc,
seulement argumente par le duty-cycle).

### Sondes rejouees, toutes exit 0

`BattleContractProbe` (46/46), `BattleDefenseProbe` (36/36, PHASE D
rapportee ci-dessus), `BattleReadabilityProbe` (65/65), `BattleStatsProbe`
(83/83), `ProbeTimeoutAudit` (37 sondes scenes armees), `AssetContractAudit`
(12/12 visuels, 0/10 colliders deplaces), `DeathModelAudit`,
`ChargerShapeProbe`. Aucune assertion codee en dur sur les anciennes valeurs
de degats/recovery n'a ete trouvee -- **verifie par grep, pas suppose** :
toutes les sondes lisent `KeepyProfile.attack_damage`/`riposte_damage`/
`attack_recovery_s` etc. directement sur les `.tres`, jamais un litteral --
c'est la discipline que `damage_for()` (le point unique de prix) impose
depuis le lot 8.

`GROUP_BLOCKS` de `BattleTally` reste fige a zero (rules Firestore
deployees, `hasAll(statKeys())`), inchange par ce lot -- aucun champ de
`BattleStats` ou des rules n'est touche.

### Build et export

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length` avant
extraction -- le piege de troncature silencieuse deja consigne). Import
headless **exit 0** (24 `.scn`, import complet verifie et pas suppose),
export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360`, `index.js` md5
`4e08904b1b7107858246af44b602067b` -- **identiques au fingerprint deja
consigne pour tout lot qui ne touche pas le code moteur**, coherent : ce lot
ne change que 3 valeurs dans 2 fichiers `.tres`. Piege payload verifie :
**0** ligne `Storing File` pour `assets_source`, `scripts/dev`, `docs`, ou
`web`. `index.pck` 5 762 912 octets (export unique et propre, `build/` et
`.godot/` supprimes avant -- a lire avec la mise en garde permanente sur son
instabilite).

### Reste ouvert

1. **Jugement device, seul juge** : est-ce que le ratio 1,43x et la
   recuperation allongee du joueur (0,72->1,16s, +61%) se SENTENT justes --
   chaque coup ordinaire est plus fort (+40%) mais moins frequent, et
   l'amelioration mesuree du lecteur imparfait est reelle mais modeste
   (+2,8 points en moyenne, pas un bond).
2. **L'esquive-panique reste une lecon a 100% de defaite**, non adoucie --
   argumente comme mecaniquement hors de portee de `dodge_recovery_s`, avec
   la piste reelle (`dodge_active_s`) nommee et deliberement pas prise dans
   ce lot.
3. Le riposte/chip a 2,0x (contre 2,8x avant) n'a pas ete mesure comme
   insuffisant, mais n'a pas non plus ete confirme comme le point d'equilibre
   ideal -- si un futur retour device dit que la riposte "ne se sent plus
   speciale", c'est le premier chiffre a revisiter.
4. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif : hors perimetre, inchange.

`main` **non touche**. Merge sur `staging` : palier 1, automatique (build,
export et sondes verts).

## KEEPY BATTLE, LOT 10 : SYMETRISATION -- 50 PV et le meme chip des deux cotes, et la cadence du joueur qui DOUBLE pour le payer (21 aout 2026)

Branche `claude/keepy-battle-symmetry-dnjqvx`, partie de `staging` (`bce85ed`,
lot 9). Retour device, capture a l'appui : **Sparring 43/64 PV, Keepy 12/42 PV**
-- l'adversaire a 22 PV de plus que le joueur. Les PV avaient servi de levier de
difficulte pendant neuf lots sans que la symetrie soit jamais remise a plat.
Decision de conception de Mathieu : **50 PV des deux cotes, `attack_damage`
ordinaire identique, et la riposte conservee comme avantage EXCLUSIF du
joueur** -- base symetrique, une seule asymetrie, assumee et lisible.

**Sept valeurs, deux fichiers `.tres`, ZERO ligne de code.** `git diff --stat`
contre `origin/staging` ne rapporte que `resources/battle/keepy.tres`,
`resources/battle/dummy.tres` et ce document. Aucune scene, aucun `.glb`, aucun
collider, aucun script de `scripts/battle/` ni de `scripts/ui/`.

### PHASE 0 -- l'etat reel, mesure dans les `.tres` et pas cru sur parole

| | Keepy (joueur) | Sparring (adversaire) |
|---|---|---|
| `max_hp` | **42** | **64** |
| `attack_damage` | 7 | 10 |
| `riposte_damage` | 14 | 16 |
| `attack_windup_s` | **0,00** (instantane) | **0,90** (barre de charge) |
| `attack_recovery_s` | 1,16 | 0,95 |

Coups pour tuer, avant ce lot : le joueur a besoin de **10 chips** ou **5
ripostes** pour vider 64 PV ; l'adversaire de **5 chips** ou **3 ripostes**
pour vider 42. L'ecart que Mathieu a photographie n'est donc pas une
impression : c'est un facteur **2** sur le nombre de coups a encaisser.
**Et oui, l'adversaire AVAIT une riposte** (`dummy.riposte_damage = 16`,
depensee par `FighterBrain._choose()` des que `is_riposte_ready()`).

### ⚠️ LA SYMETRISATION SEULE REND LE JEU TRIVIAL -- 87 a 100 % de martelage

Premiere mesure, avant toute compensation : `max_hp` a 50/50 et
`attack_damage` identique des deux cotes, tout le reste inchange. Banc reel
(les DEUX combattants pilotes, chaque tap du joueur paie une latence humaine
300-450 ms), n=300, graine 20260821.

| `attack_damage` (les deux) | martelage | esquive-panique | lecteur parfait | lecteur imparfait |
|---|---|---|---|---|
| 6 | **86,7 %** | 87,3 % | 100,0 % | 99,7 % |
| 7 | **96,0 %** | 87,7 % | 100,0 % | 99,0 % |
| 8 | **100,0 %** | 91,3 % | 100,0 % | 99,3 % |
| 9 | **100,0 %** | 88,7 % | 100,0 % | 99,7 % |
| 10 | **100,0 %** | 91,3 % | 100,0 % | 99,7 % |
| 12 | **100,0 %** | 87,0 % | 100,0 % | 99,7 % |

⚠️ **La valeur du chip ne change quasiment QUE la duree, pas le vainqueur** --
et la raison est arithmetique, pas accidentelle : **l'attaque du joueur a un
wind-up de ZERO** (lot 8), donc son cycle est `0 + 0,12 + 1,16 = 1,28 s`
contre `0,90 + 0,12 + 0,95 = 1,97 s` pour l'adversaire. A PV egaux et degats
egaux, le joueur inflige **1,54x** le DPS de l'adversaire par pure cadence, et
le combat est decide avant que la moindre lecture n'intervienne.

⚠️ **C'est le lot 8 qui parle : « an attack's damage is priced by how
avoidable it is ».** Une attaque instantanee et INESQUIVABLE payee au meme
prix qu'une attaque telegraphee de 0,9 s et esquivable n'est pas un prix egal,
c'est un avantage joueur. **La decision de Mathieu ne casse pas cette regle,
elle la deplace : le prix doit desormais etre paye en CADENCE au lieu de
l'etre en degats.**

### ⚠️ AUCUN CADRAN D'IA NE TOUCHE LE MARTELAGE -- ni un point sur huit essais

Avant de toucher a la cadence, les deux dials de personnalite de l'adversaire
ont ete balayes (D=8, PV 50/50, n=300). **Ils sont INERTES contre un
marteleur** :

| `dummy.ai_defense_rate` | 0,0 | 0,2 | 0,4 | 0,6 | 0,7 |
|---|---|---|---|---|---|
| martelage | 100,0 % | 100,0 % | 100,0 % | 100,0 % | 100,0 % |

| `dummy.ai_aggression` | 0,8 | 0,9 | 1,0 |
|---|---|---|---|
| martelage | 100,0 % | 100,0 % | 100,0 % |

Le lecteur imparfait ne bouge pas davantage (98,7 a 99,7 % partout). **Ne pas
rejouer ce balayage : il a une reponse, et elle est « non ».**

### ⚠️ `dummy.attack_recovery_s` EST VERROUILLE PAR PHASE C -- 43 ms de marge

Le levier symetrique evident -- accelerer l'adversaire -- **n'existe pas**.
`BattleDefenseProbe` PHASE C gate le fait que l'esquive PUNISSE :

```
worst_lead = (W + active + recovery)_adversaire - (tap_pire + cycle_esquive)_joueur
           = 1,97 - 1,6267 = 0,343 s     doit rester >= HUMAN_FAST (0,30)
```

`dummy.attack_recovery_s` ne peut donc pas descendre sous **~0,907** sans que
la fenetre de punition cesse d'etre prenable par un humain -- c'est-a-dire
sans rouvrir le defaut que le lot 8 existe pour fermer. **Non touche, valeur
inchangee a 0,95.** Les pics de resonance du lot 7 sur ce champ (0,44 -> 47/150,
0,56 -> 128/150) sont donc hors d'atteinte de toute facon.

### `keepy.attack_recovery_s` : le SEUL levier -- et il a CHANGE DE NATURE depuis le lot 9

Balayage a D=8, PV 50/50, n=300, graine 20260821 :

| `attack_recovery_s` joueur | martelage | lecteur parfait | lecteur imparfait |
|---|---|---|---|
| 1,16 (livre lot 9) | **100,0 %** | 100,0 % | 99,3 % |
| 1,40 | 93,7 % | 100,0 % | 99,3 % |
| 1,60 | 86,3 % | 97,3 % | 89,7 % |
| **1,80** | **89,7 %** ⚠️ | **87,3 %** | 75,7 % |
| 2,00 | 84,0 % | 87,3 % | 71,7 % |
| 2,20 | 57,7 % | 94,3 % | 73,0 % |
| 2,30 | 43,3 % | 93,7-98,0 % | 78,7-86,7 % |
| 2,40 | 25,0 % | 91,7-97,3 % | 71,0-81,7 % |
| 2,50 | 15,7 % | 92,0-96,0 % | 71,0-80,7 % |
| **2,60 (retenu)** | **11,7 %** | 94,0-96,0 % | 70,7-81,3 % |
| **2,70** | **13,0 %** ⚠️ | 93,0-96,0 % | 70,7-80,0 % |
| 2,80 | 4,7 % | 93,3-96,3 % | 70,7-80,0 % |

⚠️ **DEUX non-monotonies mesurees, la famille de resonance deja consignee aux
lots 7, 8 et 9 sur ce meme champ** : **1,80 REMONTE a 89,7 %** apres 86,3 % a
1,60, et **2,70 REMONTE a 13,0 %** apres 11,7 % a 2,60. Un balayage grossier
qui aurait saute de 1,60 a 1,80 aurait conclu que le levier ne marchait pas.

⚠️ **ET SURTOUT : ce champ ne SEPARE PLUS le marteleur du lecteur, contrairement
a ce que le lot 9 avait mesure.** Le lot 9 avait explicitement verifie que
`read+riposte` restait a 100 % sur TOUTE la plage 0,72-1,24, ce qui faisait de
`attack_recovery_s` un levier anti-martelage pur. **Ce n'est plus vrai apres
symetrisation** : entre 1,60 et 2,00 le lecteur parfait s'effondre de 97,3 a
87,3 % pendant que le marteleur ne perd que 2 points -- **a 1,80 le lecteur
est MOINS BON que le marteleur**. La raison est que la riposte est tiree par
le meme champ de timing, et qu'a PV/degats egaux le lecteur n'a plus de marge
de PV pour absorber le ralentissement. **Le levier ne redevient utilisable
qu'au-dela de 2,20**, ou le marteleur decroche enfin plus vite que le lecteur.

### La riposte est un levier QUANTIFIE : ce qui compte est le NOMBRE de ripostes pour tuer

`riposte_damage` du joueur est un levier **strictement lecteur** -- le
marteleur et l'esquive-panique n'en tirent jamais une, donc leurs lignes sont
**identiques au fight pres** sur toute la colonne. Mais son effet n'est pas
continu :

| `keepy.riposte_damage` (PV 50, rec 2,60) | ripostes pour tuer | lecteur parfait | lecteur imparfait |
|---|---|---|---|
| 18 | **3** | 94,0 % | **70,7 %** |
| 22 | **3** | 95,0 % | **71,3 %** |
| 26 | **2** | 96,0 % | **81,3 %** |

⚠️ **18 et 22 donnent le MEME resultat a un point pres, et 26 fait un saut de
10 points** : `ceil(50/18) = ceil(50/22) = 3` et `ceil(50/26) = 2`. **Le
reglage utile n'est pas « combien de degats » mais « combien de ripostes pour
tuer » -- une variable ENTIERE.** Toute future retouche de ce champ doit se
lire dans cette colonne-la, pas en pourcentage de degats.

### La riposte de l'adversaire : TRANCHEE, et son cout est chiffre

Le brief demandait de trancher explicitement. **Tranche : la riposte cesse
d'etre un avantage cote adversaire.** `dummy.riposte_damage` passe de **16 a
9**, soit `attack_damage + 1` -- la plus petite valeur que
`BattleDefenseProbe` PHASE C2 autorise (`riposte_damage > attack_damage`, gate
applique aux DEUX profils). Le mecanisme reste structurellement vivant (il
stagger, la sonde reste verte) mais le PAYOFF appartient au joueur :
**3,25x cote joueur contre 1,125x cote adversaire.**

⚠️ **Ce n'est PAS gratuit, et le chiffre est publie plutot qu'enjolive.** La
riposte adverse etait un frein anti-martelage reel : un marteleur attaque deux
fois plus souvent qu'un lecteur, donne donc deux fois plus d'occasions a
l'adversaire d'esquiver a l'aveugle et de riposter. Mesure a config finale
identique par ailleurs (D=8, PV 50/50, rec 2,60, `keepy.riposte_damage` 26) :

| `dummy.riposte_damage` | martelage | lecteur imparfait |
|---|---|---|
| 16 (avant) | **11,7 %** | 81,3 % |
| **9 (livre)** | **13,3 %** | 84,0 % |

**+1,6 point de martelage** : c'est le prix exact de l'asymetrie voulue.
Il est paye, pas cache.

### Configuration retenue

`resources/battle/keepy.tres` : `max_hp` **42 -> 50**, `attack_damage`
**7 -> 8**, `riposte_damage` **14 -> 26**, `attack_recovery_s` **1,16 -> 2,60**.
`resources/battle/dummy.tres` : `max_hp` **64 -> 50**, `attack_damage`
**10 -> 8**, `riposte_damage` **16 -> 9**.

Coups pour tuer, apres : **7 chips dans les DEUX sens** (`ceil(50/8)`) ;
**2 ripostes** cote joueur (`ceil(50/26)`) contre **6** cote adversaire
(`ceil(50/9)`). Ratio riposte/chip : **3,25x** cote joueur -- le lot 9 laissait
ouverte la question de son 2,0x « pas mesure comme insuffisant mais pas
confirme non plus » ; **ce lot le remonte franchement**, et c'est ce qui garde
une raison d'esquiver quand le chip est devenu symetrique.

⚠️ **`ai_dodge_aim` (0,70) reste calibre sur le wind-up de l'ADVERSAIRE et non
sur celui du joueur : rien de ce lot ne le touche.** De meme
`dodge_windup_s`/`dodge_active_s`/`dodge_recovery_s`, `stagger_duration_s`,
`riposte_window_s`, les cadrans `ai_*` et tout l'art (modeles `.glb`,
`model_scale`/`rotation`/`offset`) sont **intouches**.

### ⚠️ LE PRIX A ANNONCER : la commitment d'attaque du joueur passe de 1,28 s a 2,72 s

C'est le vrai cout de ce lot, et il n'est pas dissimule dans un tableau :
`attack_active_s + attack_recovery_s` passe de **1,28 s a 2,72 s (+113 %)**.
Le joueur est desormais **plus lent par attaque que l'adversaire** (2,72 contre
1,97) -- ce qui est coherent (son coup est instantane et inesquivable, il le
paie en engagement) mais represente un changement de FEEL majeur, sur le champ
que les lots 8 et 9 avaient deja allonge deux fois (0,62 -> 0,72 -> 1,16 -> 2,60).
**La riposte subit la meme recuperation** ; comme elle stagger l'adversaire
0,70 s seulement, celui-ci redevient libre AVANT le joueur apres un echange
gagne. **Aucune sonde ne dit si c'est jouable au pouce. C'est LE point de
jugement device de ce lot.**

### VALIDATION -- banc REEL du depot, 3 graines, n=300, AVANT et APRES tous deux remesures

`BattleDefenseProbe` PHASE D. La baseline n'est **pas citee de memoire** : les
`.tres` ont ete temporairement revertes et les 3 graines rejouees dans ce
sandbox (edit temporaire de la graine interne, jamais commite, revert verifie
par `git diff` vide). **Elle reproduit exactement la table publiee au lot 9**,
ce qui valide la comparaison avant d'en tirer quoi que ce soit.

| politique | AVANT (20260821 / 31415926 / 7654321) | moyenne | APRES (memes graines) | moyenne |
|---|---|---|---|---|
| **martelage** | 7,3 / 8,0 / 9,3 % | **8,2 %** | 13,3 / 13,7 / 13,3 % | **13,4 %** |
| esquive seule (`dodge-only`) | 0 / 0 / 0 % | **0,0 %** | 0 / 0 / 0 % | **0,0 %** |
| esquive-panique | 0,0 / 0,3 / 0,3 % | **0,2 %** | 0,7 / 0,3 / 0,0 % | **0,3 %** |
| lecture+riposte PARFAITE | 99,3 / 99,7 / 99,3 % | **99,4 %** | 99,0 / 97,3 / 98,7 % | **98,3 %** |
| **lecture+riposte IMPARFAITE** | 82,0 / 78,3 / 80,0 % | **80,1 %** | 84,0 / 85,0 / 90,0 % | **86,3 %** |
| duree, lecteur imparfait | 14,9 / 14,9 / 15,0 s | **14,9 s** | 13,2 / 13,0 / 12,6 s | **12,9 s** |

Objectifs du brief :
* **le martelage reste non dominant** -- OUI : 13,4 % contre 98,3 % pour le
  lecteur, soit un ecart de **85 points**. Mais il **monte de 5,2 points** par
  rapport au lot 9, et c'est dit tel quel.
* **lecture+riposte reste la meilleure strategie** -- OUI, de tres loin, sur
  les 3 graines.
* **duree 12-20 s** -- OUI sur les moyennes (10,9 a 15,9 s selon la politique).
  ⚠️ Les MAXIMA depassent : jusqu'a **22,2 s** (esquive-panique). C'etait deja
  le cas au lot 9 (23,7 s en baseline sur la graine 7654321).

### ⚠️ LE JEU EST PLUS FACILE POUR LE LECTEUR IMPARFAIT -- +6,2 points, dit franchement

**80,1 % -> 86,3 %**, et l'amelioration est presente sur les 3 graines
(84,0>82,0 ; 85,0>78,3 ; 90,0>80,0). C'est exactement le basculement que le
brief annoncait et acceptait d'avance. **Aucune compensation silencieuse n'a
ete faite** : la seule compensation appliquee est
`keepy.attack_recovery_s`, elle est le mandat explicite de la PHASE 2 du
brief, et elle a sa propre section chiffree ci-dessus. Le lecteur imparfait
n'est PAS proche de 100 % (86,3 %), donc la clause « si ca devient trivial, ne
compense pas de ta propre initiative » n'a pas eu a jouer.

**Les leviers chiffres si Mathieu veut re-durcir**, tous des editions d'UN seul
champ, deja mesures dans les tableaux ci-dessus :
* `keepy.attack_recovery_s` **2,60 -> 2,80** : martelage **11,7 -> 4,7 %**
  (mesure a `dummy.riposte_damage = 16` ; attendu ~6 % a 9), lecteur imparfait
  quasi inchange. **Cout : la commitment passe a 2,92 s.**
* `keepy.riposte_damage` **26 -> 22** : lecteur imparfait **~84 -> ~71 %**
  (passage de 2 a 3 ripostes pour tuer). Le levier le plus brutal.
* `dummy.riposte_damage` **9 -> 16** : martelage **13,3 -> 11,7 %**, mais rend
  a l'adversaire la riposte que ce lot lui retire.

### Determinisme

`BattleDefenseProbe` rejouee deux fois a la meme graine (20260806) :
**stdout ET stderr byte-identiques** (`cmp` silencieux sur les deux flux). Les
traces ONT bouge par rapport au lot 9 -- c'est le resultat attendu d'un lot
qui change sept nombres de gameplay -- mais la reproductibilite a graine egale
est intacte, ce qui est la propriete dont depend tout ce qui precede.

### Sondes

**Toutes exit 0** : `BattleDefenseProbe` (**36/36**, PHASE D rapportee
ci-dessus, gates PHASE A/B/C/C2/R/R2/E verts avec les nouveaux nombres),
`BattleContractProbe` (**46/46**), `BattleReadabilityProbe` (**65/65**),
`BattleStatsProbe` (**83/83**), `ProbeTimeoutAudit` (**37 sondes scenes**,
retour exact a la baseline apres suppression de la sonde de balayage jetable),
`AssetContractAudit` (12/12 visuels, **0/10 colliders deplaces**),
`DeathModelAudit`, `ChargerShapeProbe`.

**Aucune assertion codee en dur sur les anciennes valeurs -- verifie par grep,
pas suppose** : la seule occurrence litterale de `42` du perimetre est le
DEFAUT `@export var max_hp: int = 42` de `FighterProfile.gd`, que les deux
`.tres` ecrasent et qu'aucune sonde ne lit. Il est **laisse tel quel** (les
autres defauts de ce fichier ont deja derive de la meme facon depuis le lot 8)
plutot que touche, pour que ce lot reste strictement `.tres`-only.

⚠️ **La sonde de balayage etait une COPIE de `_policy_fight`, donc un fixture
qui pouvait diverger sur l'axe meme que ce lot change.** Parade appliquee avant
de lui faire confiance, selon la discipline maison : un run de CONTROLE sans
aucun override, qui devait reproduire la sortie de la sonde livree. Il l'a
reproduite **au fight pres sur les cinq politiques** (7,3 / 0,0 / 0,0 / 99,3 /
82,0 %). La sonde est supprimee avant commit.

`GROUP_BLOCKS` de `BattleTally` reste **fige a zero** (rules Firestore
deployees, `hasAll(statKeys())`) -- aucun champ de `BattleStats`, de
`BattleTally` ou des rules n'est touche par ce lot.

### Build et export

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases GitHub
officielles ; **tailles verifiees contre le `Content-Length` avant extraction**
-- 50 276 070 et 1 073 228 327 octets, le piege de troncature silencieuse deja
consigne). Import headless **exit 0** (24 `.scn`, import complet verifie et pas
suppose), export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` ; `index.js` md5
`4e08904b1b7107858246af44b602067b` -- **identiques au fingerprint deja consigne
pour tout lot qui ne touche pas le code moteur**, coherent : ce lot ne change
que sept nombres dans deux `.tres`. Piege payload verifie sur le log
`savepack` : **0** ligne `Storing File` pour `assets_source`, `scripts/dev`,
`docs`, `web` ou `build`. `index.pck` 5 762 880 octets (export unique et
propre, `build/` supprime avant -- a lire avec la mise en garde permanente sur
son instabilite, jamais offert comme preuve).

### Reste ouvert

1. **Jugement device, et il porte sur UN chiffre precis** : la commitment
   d'attaque a **2,72 s**. Est-ce que taper et rester bloque presque trois
   secondes se sent comme un engagement lourd et lisible, ou comme un jeu qui
   ne repond pas ? C'est le seul point que ce lot ne peut pas mesurer, et
   c'est le plus gros risque qu'il prend.
2. **Le jeu est plus facile** (+6,2 points pour le lecteur imparfait, +5,2 pour
   le marteleur). Assume et annonce ; les trois leviers de re-durcissement
   ci-dessus sont chiffres et attendent la decision de Mathieu.
3. **2 ripostes pour tuer** est tres court -- deux lectures reussies suffisent.
   C'est ce qui rend la riposte « nettement plus payante » comme le brief le
   demandait, mais c'est aussi ce qui rend le combat swingy. Le voisin a 3
   ripostes (`riposte_damage` 22) coute 13 points au lecteur imparfait.
4. **`attack_recovery_s` a cesse d'etre un levier anti-martelage PUR** sous
   symetrie (section dediee) -- toute future session qui reprendrait la recette
   du lot 9 sur ce champ mesurerait autre chose que ce que le lot 9 mesurait.
5. Toujours aucun son, aucune particule, aucun second adversaire, aucune
   progression, aucun brain adaptatif, et `dodge_active_s` toujours pas touche
   (lot dedie) : hors perimetre, inchange.

### Deploiement staging (palier 1, automatique)

`staging` `9b41b5d` (merge `--no-ff`, arbre **byte-identique** a la branche
feature -- verifie avant le push, `git diff` vide). CI run **#188**
(id `32525098032`).

**Verifie SUR LE SERVICE, pas dans le log CI**, et **dans les DEUX sens** --
la valeur AVANT a ete lue avant que le deploiement ne tombe, ce que les lots
precedents n'avaient pas toujours pu faire :

| | `CACHE_VERSION` servi | = UTC |
|---|---|---|
| avant (lot 9, run #187) | `1787342427` | **20:00:27** |
| **apres (ce lot, run #188)** | **`1787345288`** | **20:48:08** |

L'epoch d'apres tombe **a l'interieur de la fenetre du run #188** (demarre
20:44:31, import a 20:45:50), et la reponse est fraiche : `x-vercel-cache:
MISS`, `age: 0`, `last-modified` colle a l'instant de la requete. L'alias
sert donc bien le build symetrise.

⚠️ **L'API GitHub Actions a de nouveau servi des reponses PERIMEES, et cette
fois SUR LES DEUX filtres.** `filter: "latest"` etait fige des le depart ;
`filter: "all"` a d'abord rendu l'etat REEL (job a l'etape « Import project
resources », 20:45:50) puis s'est fige a son tour, rendant une reponse
byte-identique plusieurs appels de suite. **Le parametre n'est ni la cause ni
le remede** -- constat deja pose au lot 6, reconfirme ici dans une troisieme
configuration. Seul le `CACHE_VERSION` servi a tranche.

⚠️ **`curl` direct vers `*.vercel.app` est refuse par le proxy d'egress de ce
sandbox** (`http_code 000`, exit 56 -- **re-teste, pas suppose** ; meme
`example.com` est refuse). Le canal MCP Vercel est le seul disponible ici,
comme deja consigne au lot 3.

`main` **non touche** (`origin/main` toujours `924d81f`, verifie apres le
push). Merge sur `staging` : palier 1, automatique.

## KEEPY BATTLE LOT 11 : EGALITE STRICTE DES CHAMPS DE COMBAT, WINDUP=0 DES DEUX COTES, LE MARTELAGE RETROUVE (22 aout 2026)

Branche `claude/lot-11-battle-balance-70gtqq`, partie de `staging`
(`924079a`, lot 10). Retour device sur lot 10 : « c'est impossible de
prendre du plaisir, c'est trop long entre deux attaques » --
`attack_recovery_s` du joueur avait grimpe a 2,6 s pour tarifer un coup
INSTANTANE et INEVITABLE, portant l'engagement a 2,72 s. Decision de
Mathieu, non negociable : `keepy.tres` et `dummy.tres` doivent porter des
valeurs **IDENTIQUES** sur tout champ de COMBAT (`max_hp`,
`attack_damage`, `riposte_damage`, `attack_windup_s`,
`attack_recovery_s`, `dodge_*`, `stagger_duration_s`,
`riposte_window_s`). Seuls les champs de DECISION (`ai_*`), `display_name`
et le groupe Art peuvent differer.

### ⚠️ `attack_windup_s` DOIT etre egal aussi -- et la MESURE, pas la
### preference, a choisi ZERO plutot qu'une valeur partagee non nulle

Premiere tentative testee et REJETEE, mesuree avant d'etre ecartee :
`attack_windup_s = 0,9` des deux cotes (redonner au joueur le meme
telegraphe que Sparring). Resultat mesure sur `BattleDefenseProbe` PHASE D
(300 combats, joueur pilote par une politique-caricature, adversaire par
le vrai brain) : **martelage (« mash ») gagne 0/300**, contre 94,3% une
fois revenu a zero. Cause : un cerveau qui suit les regles LIT et esquive
un telegraphe parfaitement regulier -- exactement l'inverse de l'issue
acceptee d'avance (« dans un duel strictement symetrique, celui qui frappe
le plus souvent gagne »). L'arithmetique de cadence ferme aussi sur zero :
`active (0,12s) + recovery (~1,10s)` font deja ~1,22s, correspondant a
l'engagement 1,28s « jouable » du lot 8 -- il ne reste aucune marge pour un
wind-up sur aucun des deux cotes.

**`attack_windup_s = 0.0` des DEUX cotes**, restaurant la cadence « jouable »
du lot 8 mais desormais partagee. `attack_recovery_s = 1.1` (le milieu de
la fourchette demandee, sous la borne dure de 1,20). `attack_damage = 6`,
`riposte_damage = 12` (choisis par sweep, voir plus bas). `dodge_*`,
`stagger_duration_s`, `riposte_window_s` etaient deja identiques et
restent inchanges.

### ⚠️ BORNE DURE `attack_recovery_s <= 1,20s`, DES DEUX COTES -- pourquoi
### elle existe et ne doit plus jamais etre franchie

Le lot 10 a rendu le jeu injouable en portant cette valeur a 2,6s pour
compenser un coup qu'on ne pouvait pas eviter. Avec la symetrie stricte de
ce lot, plus aucun cote n'a besoin d'etre compense de cette facon : le
telegraphe est desormais nul des deux cotes, donc il n'y a plus de raison
structurelle de faire grimper `attack_recovery_s`. La borne est
NON FRANCHISSABLE precisement pour empecher qu'une future session ne
recree le meme piege (« il faut juste compenser un peu plus »). Sweep de
0,90 a 1,20 fait par pas de 0,05 (voir tableau plus bas) : aucune falaise,
progression lisse -- contrairement a l'ancienne falaise documentee a
0,60/0,62 sous l'ancienne configuration asymetrique, qui ne s'applique
plus a ce design.

### Sweep mesure, pas suppose -- `BattleDefenseProbe` PHASE D, n=300, graine fixe

| recovery | mash (win / duree) | panic / read+riposte |
|---|---|---|
| 0,90 | 100,0% / 8,9s | 19,7% / 10,8s |
| 0,95 | 100,0% / 9,5s | 25,3% / 11,4s |
| 1,00 | 100,0% / 10,0s | 23,3% / 12,0s |
| 1,05 | 100,0% / 10,4s | 25,0% / 12,2s |
| **1,10 (retenu)** | **94,3% / 10,8s** | **27,7% / 12,6s** |
| 1,15 | 86,0% / 11,0s | 28,0% / 12,8s |
| 1,20 (plafond) | 73,7% / 11,4s | 28,3% / 13,1s |

`BattleContractProbe` PHASE F (mirrore, les deux cotes pilotes par le vrai
brain, rapporte, jamais gate) confirme a `recovery=1,10` :
**duree moyenne 12,84s** (min 9,03 / max 16,92), dans la fourchette 10-15s
demandee.

### ⚠️ CONSEQUENCE MESUREE, PAS CACHEE : l'esquive REACTIVE contre un coup
### instantane est structurellement IMPOSSIBLE, des deux cotes desormais

Avec `attack_windup_s = 0`, le coup se resout au tick JUSTE APRES la
demande (`request_action`), avant que le defenseur -- meme s'il vient de
demander une esquive au meme instant -- ait pu atteindre sa propre phase
ACTIVE (`dodge_windup_s` a lui seul coute 3 ticks a 60 Hz). Ce n'est pas
une fenetre etroite, c'est une impossibilite structurelle, deja documentee
comme la consequence acceptee du lot 8 pour UN seul cote ; ce lot
l'etend a l'autre. Ce qui reste : l'esquive par CHANCE DE PHASE (un
combattant deja en train d'esquiver, d'un tap anterieur, se trouve par
hasard en phase ACTIVE au tick ou un coup adverse se resout). C'est
exactement ce que mesurent les politiques `panic-dodge` / `read+riposte`
du banc -- et elles rendent desormais des chiffres **IDENTIQUES** entre
elles (27,7%), parce qu'il n'existe plus de barre a lire : « lecture
parfaite » et « panique » sont devenues la MEME politique une fois le
telegraphe supprime des deux cotes. C'est une consequence honnete du
design, pas un defaut de sonde : signalee ici plutot que masquee.

### PHASE 3 -- validation sur le banc REEL du depot, n=300, plusieurs graines

| politique | victoires | duree moyenne | duree max |
|---|---|---|---|
| **martelage (mash)** | **283/300 (94,3%)** | 10,8s | 13,5s |
| esquive seule (dodge-only) | 0/300 (0,0%) | 13,6s | 20,9s |
| panique (panic-dodge) | 83/300 (27,7%) | 12,6s | 17,2s |
| lecture+riposte parfaite | 83/300 (27,7%) | 12,6s | 17,2s |
| lecture+riposte imparfaite (3/4, jitter 140ms) | 83/300 (27,7%) | 12,6s | 17,2s |

`BattleContractProbe` PHASE E (le brain pilote le fighter du JOUEUR, pas
seulement l'adversaire) confirme l'interchangeabilite sans cas special.
Les DEUX cotes sont pilotes dans chaque mesure (piege du sac de frappe,
deja rencontre 3 fois dans ce projet).

**Engagement du joueur (windup + resolution + recuperation)** :
`0 + 0,12 + 1,10 = 1,22s` -- tres proche de la cible ~1,20s, et dans la
famille du lot 8 (1,28s, « jouable »), tres loin du 2,72s injouable du
lot 10.

**Ce que ce lot NE resout PAS, et c'est assume plutot que maquille** :
l'esquive n'est plus une COMPETENCE (il n'y a plus rien a lire), elle
est desormais un pari de timing/rythme. `ai_dodge_aim`/`ai_dodge_slop`
deviennent vestigiaux pour la defense de l'IA contre un attaquant
instantane (deja documente comme consequence acceptee du lot 8, etendue
ici) -- le chemin `_dodge_aim` de `FighterBrain._choose()` reste
inatteignable des deux cotes. `ai_reaction_delay_s`/`jitter`,
`ai_aggression`, `ai_defense_rate` restent les seuls leviers reellement
actifs (cadence et frequence de decision), et n'ont pas ete retouches
(deja raisonnables, mesures ci-dessus).

### PHASE 2 -- calibrage IA : AUCUN changement de valeur, signal plutot que reglage force

Le brief demandait de regler les `ai_*` pour qu'« un joueur qui lit
correctement gagne clairement, et qu'un joueur distrait perde ». Mesure
avant d'agir : sous `attack_windup_s = 0`, il n'existe plus de telegraphe
a lire, donc aucune combinaison d'`ai_*` ne peut recreer une distinction
entre « lecture correcte » et « panique » -- les deux politiques rendent
deja des chiffres identiques (voir plus haut), et c'est une propriete de
la mecanique, pas de reglage IA. Forcer artificiellement une difference
(ex. donner au joueur un avantage cache) aurait ete exactement la
"compensation cachee" interdite par le brief. **Signale, non corrige** :
Mathieu tranche s'il souhaite reintroduire un signal de lecture ailleurs
(hors perimetre .tres, ou dans un lot futur). Les valeurs `ai_*`
existantes (`ai_aggression`, `ai_defense_rate`, `ai_reaction_delay_s`,
`ai_reaction_jitter_s`) sont **inchangees** et deja mesurees comme
raisonnables : mash gagne clairement (94,3%), les strategies passives ou
tardives perdent la majorite du temps (27,7% ou 0%).

### Sondes adaptees -- assertions rendues fausses par le design, jamais gate en douce

Trois fichiers de sonde touches, tous des adaptations d'assertions
devenues fausses par ce changement de design, jamais des reglages
d'anciens defauts :

- **`BattleDefenseProbe.gd`** : les PHASES A/B/C/R/E testent une
  esquive REACTIVE a un telegraphe -- structurellement impossible des
  deux cotes desormais (voir plus haut). Gardees derriere
  `_windup_retired()` : rapportees une fois, jamais gate sur une
  geometrie de bande devenue vide par construction (division par
  `DummyProfile.attack_windup_s` = 0 aurait produit des NaN en cascade
  si laissee telle quelle). PHASE C2, R2 et D **inchangees** -- elles ne
  dependent pas d'un telegraphe et restent pleinement valides.
- **`BattleReadabilityProbe.gd`** : PHASE C (le telegraphe grandit sur le
  corps du combattant) et la moitie « barre dessinee » de PHASE G sont
  gardees derriere le meme `_windup_retired()` -- il n'y a plus de barre
  a dessiner ni a colorer sur AUCUN des deux fighters. Ce que PHASE G
  verifie desormais dans ce cas : la geometrie `Body/Charge` existe
  encore dans la scene (un futur lot pourrait reintroduire un telegraphe
  sans toucher `BattleFighter.tscn`) et qu'un coup instantane ne leve
  jamais la barre, sur les DEUX fighters -- exactement l'assertion que
  le lot 8 faisait deja pour le seul joueur.
- **`BattleContractProbe.gd`** : PHASE A2 (« le coup du joueur est
  instantane ») passe SANS modification -- `KeepyProfile.attack_windup_s`
  reste zero. Aucune assertion cassee ici.

**Documentation de code mise a jour** (commentaires seulement, aucune
valeur ni logique touchee) : `FighterProfile.gd` (nouveau bloc d'en-tete
« LOT 11 » expliquant le renversement de l'asymetrie du lot 8, paragraphe
« instant, unavoidable chip... » corrige pour ne plus decrire une
asymetrie qui n'existe plus) et `FighterBrain.gd` (note que le
commentaire lot 8 sur l'attaquant instantane s'applique desormais aux
DEUX fighters).

### Determinisme verifie

`BattleContractProbe` rejouee deux fois a la meme graine (20260806) :
**sortie byte-identique**, stdout compris. Aucun `randi()`/`randf()`
global touche par ce lot (seul le `RandomNumberGenerator` seede de
l'arene est utilise, comme documente par `BattleArena.gd`).

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, tailles verifiees contre `Content-Length`, aucune
troncature). Import headless **exit 0**, export Web release **exit 0**,
aucune erreur GDScript. `index.wasm` **35 376 909 octets** -- identique au
fingerprint deja consigne pour tout lot qui ne touche pas le code moteur
(coherent : ce lot ne touche que 2 `.tres` + 2 fichiers de commentaires
`.gd` + 2 sondes). `index.pck` 5 762 880 octets (export unique et propre,
`build/`+`.godot/` supprimes avant -- a lire avec la mise en garde
permanente sur l'instabilite du `.pck`).

**Sondes, toutes exit 0** : `BattleContractProbe` (46/46),
`BattleDefenseProbe` (8/8 gate + PHASE D rapportee), `BattleReadabilityProbe`
(24/24), `BattleStatsProbe` (83/83, inchangee -- ne depend pas des timings
d'attaque), `AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit` (CHARGER seul fatal, capture au 2e contact pour les 5
autres types -- inchange, ce lot ne touche aucun hazard), `ChargerShapeProbe`,
`ProbeTimeoutAudit` (37 scenes, toutes armees). Piege payload sans objet
(ce lot ne touche ni `assets_source/`, ni `scripts/dev/*` au-dela des deux
fichiers de sonde deja lies au build via `exclude_filter`).

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que ~1,22s d'engagement se ressent comme jouable au pouce**,
   comme le lot 8 l'avait ete -- aucune sonde ne rend ce jugement, c'est
   l'objet meme de ce lot.
2. **L'esquive est-elle encore une option qui merite d'etre pressee** ?
   Mesuree comme statistiquement PERDANTE face au martelage (27,7% contre
   94,3%) -- c'est assume par le brief, mais reste une question de
   ressenti : un joueur qui esquive par chance de phase doit-il avoir
   l'impression de "jouer avec le systeme" ou de "presser un bouton
   inutile" ? Aucune sonde ne peut trancher.
3. **La disparition de la "lecture" comme competence** (panic-dodge ==
   read+riposte desormais) est signalee, pas corrigee -- decision future
   de Mathieu si un signal de lecture doit revenir sous une autre forme.

`main` **non touche**. Merge sur `staging` : palier 1, automatique des que
la CI est verte.

### Deploiement staging du lot 11 (palier 1, automatique)

`staging` (`3a2f6f6`), merge `--no-ff` sans conflit. CI **web-build run
#190** (id `32555358620`) **verte en 3 min 19 s** (05:49:51 -> 05:53:10
UTC) -- `Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**. `main` **non touche**
(palier 2, gate Mathieu apres validation device).

**Verifie SUR LE SERVICE, pas seulement dans le log CI** (canal MCP
Vercel) : `index.service.worker.js` servi par `keepy-staging.vercel.app`
porte **`CACHE_VERSION = 1787377960|4144358`** = **05:52:40 UTC**,
tombant **a l'interieur** de la fenetre du run #190 (05:49:51-05:53:10) --
l'alias sert bien ce build. `x-vercel-cache: MISS`, `age: 0`,
`last-modified` colle a l'instant de la requete : trois signaux
independants qui disent que ce n'est pas une reponse de cache.

**Reste ouvert, inchange depuis la section principale ci-dessus** :
jugement device sur le ressenti de l'engagement ~1,22s et sur si
l'esquive-par-chance-de-phase merite encore d'etre pressee.

## KEEPY BATTLE LOT 12 : LE TELEGRAPHE ADVERSE EST RESTAURE -- `attack_windup_s` N'EST PAS UN CHAMP DE COMBAT SYMETRISABLE (22 aout 2026)

Branche `claude/restore-opponent-telegraph-nkv24z`, partie de `staging`
(`75ea28f`). Corrige une CONSIGNE, pas une execution : le brief du lot 11
classait `attack_windup_s` comme un champ de COMBAT devant etre identique
des deux cotes, au meme titre que `max_hp`/`attack_damage`/etc. Cette
classification etait FAUSSE -- ce champ ne tarife rien, il GENERE la barre
de charge que le defenseur lit. Le lot 11 a suivi la consigne correctement
et a mesure sa propre consequence : esquive-panique et lecture+riposte
rendaient le MEME chiffre (27,7 %), parce qu'une fois le telegraphe
supprime des deux cotes il n'y avait plus rien a LIRE, seulement une
esquive de chance de phase. Ce lot ne corrige pas ce resultat comme un
bug -- il corrige la premisse qui l'a produit.

**Decision de Mathieu, une exception et une seule** : `dummy.tres`
retrouve `attack_windup_s = 0.9` (Sparring redevient LISIBLE).
`keepy.tres` garde `attack_windup_s = 0.0` (le tap EST le coup, inchange
depuis le lot 8). **Tous les autres champs de combat restent strictement
identiques** entre les deux profils, exactement comme le lot 11 l'exigeait :
`max_hp` 50/50, `attack_damage` 6/6, `riposte_damage` 12/12,
`attack_recovery_s` 1,10/1,10, `dodge_windup_s` 0,05/0,05,
`dodge_active_s` 0,4/0,4, `dodge_recovery_s` 0,36/0,36,
`stagger_duration_s` 0,7/0,7, `riposte_window_s` 1,2/1,2 -- verifie par
diff des deux `.tres` sur tous les champs de combat, **une seule ligne
differe**.

⚠️ **Ce n'est PAS une asymetrie de puissance.** Le hibou n'encaisse pas
plus, n'inflige pas plus, ne recupere pas plus vite, n'a pas plus de vie.
C'est la difference entre un adversaire LISIBLE et un joueur REACTIF --
sans elle il n'y a rien a lire ni a decider, seulement une course de
cadence. **Borne dure `attack_recovery_s <= 1,20 s` des deux cotes
maintenue** (1,10 des deux cotes, sous le plafond) -- rien dans ce lot
n'a eu besoin de s'en approcher.

### Perimetre du code : deux `.tres`, trois fichiers de commentaires/sondes, ZERO ligne de logique de jeu

`git diff --stat` contre `origin/staging` : `resources/battle/dummy.tres`
(un champ), `scripts/battle/FighterProfile.gd` et
`scripts/battle/FighterBrain.gd` (commentaires d'en-tete seulement, aucune
valeur ni logique touchee), `scripts/dev/BattleDefenseProbe.gd` et
`scripts/dev/BattleReadabilityProbe.gd` (adaptation d'une seule fonction
d'assertion chacun, plus leurs messages `print`). **Aucune scene, aucun
`.glb`, aucun collider, aucun script de `BattleArena.gd`/`Fighter.gd`/
`FighterView.gd`/`BattleHUD.gd` touche** -- tous generiques (`is_charging()`
keye sur la longueur de phase, `_evade_lo`/`_evade_hi` de `BattleArena.gd`
retournent deja `-1.0` si `attack_windup_s <= 0`), donc restaurer le
telegraphe cote Dummy les fait fonctionner sans une ligne a changer.

### `_windup_retired()` corrigee dans les DEUX sondes -- elle testait la mauvaise question

Le lot 11 l'avait ecrite comme `is_zero_approx(Dummy) AND
is_zero_approx(Keepy)` et gardait les phases A/B/C/R/E de
`BattleDefenseProbe` et PHASE C / la moitie "barre dessinee" de PHASE G de
`BattleReadabilityProbe` derriere elle. **Chaque phase gardee y est deja
ecrite attaquant=Dummy, defenseur=Keepy** (verifie ligne par ligne avant
tout edit) -- c'est exactement lot 8-10 restaure, pas un nouveau mecanisme.
La fonction ne testait donc jamais "y a-t-il un telegraphe dans le
combat", elle testait "y a-t-il un telegraphe du cote que CES phases
mesurent" -- et ce cote est **Dummy seul**. Corrigee en
`is_zero_approx(DummyProfile.attack_windup_s)` dans les deux fichiers,
avec les en-tetes et messages `print` mis a jour en consequence. Aucune
geometrie, aucun seuil, aucune tolerance modifiee -- seule la condition de
garde change, et elle passe desormais a `false`, ce qui **reactive** les
phases telles qu'ecrites plutot que d'en reecrire une seule.

### Validation -- editeur + templates Godot 4.3-stable installes dans ce sandbox

Releases GitHub officielles, tailles verifiees contre `Content-Length`
avant extraction (50 276 070 et 1 073 228 327 octets -- aucune troncature).
Import headless **exit 0** (24 `.scn`, complet). Export Web release
**exit 0**.

**`BattleDefenseProbe` : 36/36, PHASES A/B/C/R/E REACTIVEES et vertes** --
fenetre d'esquive 0,500..0,907 de la barre (817 ms, ferme apres le pire
humain a 450 ms), attaquant libre a 2 120 ms / cycle d'esquive 810 ms (marge
493 ms au pire tap, largement > `HUMAN_FAST` 300 ms), fenetre de riposte
1 200 ms encore ouverte au retour libre, les trois verdicts HUD distincts.
**`BattleReadabilityProbe` : 65/65**, PHASE C et la moitie barre de PHASE G
REACTIVEES -- telegraphe visible et croissant sur le corps de Sparring,
barre dessinee contraste 12,91:1 (ciel) / 4,10:1 (sol), bande d'esquive
14,89:1 / 4,73:1, et **la barre du joueur reste bien NON levee sur une
attaque instantanee** (assertion lot 8 inchangee). `BattleContractProbe` :
**46/46** (PHASE A2 -- l'attaque du joueur reste instantanee -- inchangee ;
PHASE F, rapportee jamais gatee, montre desormais Keepy-profil gagnant
40/40 en IA-vs-IA mirroite, consequence attendue et non maquillee d'un
adversaire lisible face a un attaquant instantane). `BattleStatsProbe` :
**83/83**, inchangee (ne depend d'aucun timing d'attaque). `AssetContractAudit`
(12/12 visuels, **0/10 colliders deplaces**), `DeathModelAudit`,
`ChargerShapeProbe`, `ProbeTimeoutAudit` (**37 sondes scenes**, retour exact
a la baseline apres suppression de la sonde de sweep jetable) -- **toutes
exit 0**.

**Determinisme verifie** : `BattleDefenseProbe` et `BattleContractProbe`
rejouees deux fois a la graine `20260806`, sortie **byte-identique** sur les
deux (stdout compris, `cmp` silencieux).

### PHASE 2 -- mesure, banc REEL du depot, n=900 par politique (3 graines x 300), pas suppose

Sonde jetable (jamais commitee, supprimee avant ce commit -- verifie
qu'elle disparaissait bien de `ProbeTimeoutAudit`, 38 -> 37 scenes) qui
reprend **verbatim** `_policy_fight()` de `BattleDefenseProbe.gd` (les deux
combattants pilotes -- le joueur par une politique caricature, l'adversaire
par le vrai `FighterBrain`, piege du sac de frappe deja rencontre 3 fois) et
la rejoue sur TROIS bases de graine (`20260821`, `31415926`, `7654321`), pas
une seule -- la lecon du lot 3 sur n=40. Chaque tap du joueur paie une
latence humaine 300-450 ms tiree par tap.

| politique | pooled (n=900) | duree moyenne |
|---|---|---|
| martelage (mash) | **900/900 (100,0 %)** | 10,4 s |
| esquive seule (dodge-only) | 0/900 (0,0 %) | 60,0 s *(plafond -- n'attaque jamais)* |
| **panique (panic-dodge)** | **591/900 (65,7 %)** | 17,2 s |
| **lecture+riposte parfaite** | **900/900 (100,0 %)** | 12,7 s |
| lecture+riposte imparfaite (3/4, gigue 140 ms) | 894/900 (99,3 %) | 14,2 s |

**Critere central du lot, atteint** : panique et lecture+riposte etaient
IDENTIQUES au lot 11 (27,7 % chacune) -- elles sont desormais **65,7 %
contre 100,0 %**, un ecart de **34,3 points**, stable sur les trois graines
(64,3-67,3 % pour panique). La dimension de LECTURE est reellement revenue :
lire la barre et riposter bat significativement le fait de taper au hasard
des l'apparition du telegraphe.

**Martelage reste eleve (100,0 %), et ce n'est PAS ecrase par une
asymetrie supplementaire** -- assume depuis le lot 11, aucun reglage n'a
ete ajoute pour le faire baisser. Il gagne par CADENCE : le cycle du joueur
(0 + 0,12 + 1,10 = 1,22 s) reste plus rapide que celui de Sparring
(0,9 + 0,12 + 1,10 = 2,12 s), meme si le joueur encaisse chaque coup
telegraphie sans jamais esquiver.

⚠️ **Panique depasse legerement la fourchette 10-15 s (17,2 s)** -- rapporte,
pas gate (meme discipline que `BattleDefenseProbe` PHASE D), et deja dans
la marge que d'autres lots ont acceptee pour cette meme politique
(lot 10 : maxima jusqu'a 22,2 s sur esquive-panique). Aucun reglage
supplementaire n'a ete fait pour le faire rentrer dans la fourchette --
ce n'etait pas demande et l'aurait ete au prix d'une modification hors
`.tres`.

**Engagement du joueur inchange** : `0 + 0,12 + 1,10 = 1,22 s` -- identique
au lot 11, dans la famille du lot 8 (1,28 s, "jouable"), loin du 2,72 s
injouable du lot 10.

### Ce qui n'a PAS ete touche

`ai_reaction_delay_s`/`ai_reaction_jitter_s`/`ai_aggression`/
`ai_defense_rate`/`ai_dodge_aim`/`ai_dodge_slop` sur les deux profils :
**intouches**, comme demande. Le chemin `_dodge_aim` de
`FighterBrain._choose()` redevient **atteignable** contre Sparring des
qu'un cerveau (probe mirroite ou un futur brain joueur) defend contre son
telegraphe -- il reste **inatteignable** contre le joueur, exactement
comme documente depuis le lot 8. `GROUP_BLOCKS` de `BattleTally` reste
**fige a zero** (rules Firestore deployees, `hasAll(statKeys())`) --
aucun champ de `BattleStats` ni des rules touche. Modeles `.glb`/
`ModelSlot`, attaque instantanee du joueur, fenetre de riposte, barre +
bande cote adversaire (lots 6-9) : tous **intouches**.

### Reste ouvert -- jugement device, seul juge

1. **Est-ce que le telegraphe de Sparring se lit a nouveau comme un
   signal exploitable au pouce**, sur un vrai telephone -- aucune sonde
   ne peut repondre a ca, c'est l'objet meme du lot.
2. Le martelage a 100,0 % reste la strategie dominante en absolu, meme si
   elle n'est plus indiscernable de la panique en face -- si Mathieu juge
   ca encore trop fort, le levier reste `keepy.attack_recovery_s` (deja
   documente aux lots 9/10), a re-mesurer avant tout changement.
3. Panique a 17,2 s de moyenne, legerement au-dessus de la fourchette
   10-15 s -- signale, non corrige.

`main` **non touche**. Merge sur `staging` : palier 1, automatique des que
la CI est verte.

### Deploiement staging du lot 12 (palier 1, automatique)

`staging` (`7dd5924`, merge `--no-ff`, arbre **byte-identique** a la
branche feature -- `git diff` vide). CI **web-build run #193**
(id `32598120648`) **verte en 3 min 34 s** (20:56:12 -> 20:59:46 UTC) --
`Deploy to Vercel [STAGING -- staging]` succes,
`[PRODUCTION -- main]` correctement **skipped**.

**Verifie SUR LE SERVICE, pas seulement dans le log CI** (canal MCP
Vercel) : `index.service.worker.js` servi par `keepy-staging.vercel.app`
porte **`CACHE_VERSION = 1787432354|3293683`** = **20:59:14 UTC**, tombant
**a l'interieur** de la fenetre du run #193 -- l'alias sert bien ce build.
`x-vercel-cache: MISS`, `age: 0`, `last-modified` colle a l'instant de la
requete : trois signaux independants qui disent que ce n'est pas une
reponse de cache.

`main` **non touche** (palier 2, gate Mathieu apres validation device sur
`keepy-staging.vercel.app` -- lisibilite du telegraphe adverse restaure).

