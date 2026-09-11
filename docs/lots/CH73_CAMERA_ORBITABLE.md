# CH73 — La caméra orbitable au doigt, à pied

> Lot du 11 septembre 2026. Branche `claude/ch73-orbitable-camera-6gw4vv`,
> base `d71f803` (merge CH72, `main` et `staging` alignées, arbre
> `dec9845b` des trois côtés).
>
> **Périmètre : la caméra du hub, à pied uniquement.** Aucun changement à
> la conduite (kart, char à voile, voilier, luge, planche), au parc
> d'attractions, au POV du CH72, ni au tap-to-move au-delà de ce qu'il
> fallait pour coexister avec l'orbite. Pas de zoom — la distance est
> invariante par construction, pas par convention.

## 1. Recon — deux prémisses du brief tombent

### 1.1 ⚠️ IL N'Y AVAIT AUCUN SEUIL TAP/DRAG DANS `HubTapInput`

Le brief demandait d'identifier « EXACTEMENT comment un tap court est
aujourd'hui distingué d'un drag (seuil de temps ? seuil de distance ? les
deux ?) » et de publier le seuil trouvé « avant d'ajouter quoi que ce soit
dessus ».

**Il n'y en avait aucun, d'aucune sorte.** `_unhandled_input` agissait sur
la seule *release*, et toute release appelait `_handle_point`
inconditionnellement, quelle que soit la distance parcourue par le doigt.

Le header du fichier le dit lui-même, et à l'envers :

> Only the RELEASE half of a touch is acted on. Acting on the press would
> fire while a finger is still down and still moving -- a player who
> touches the screen and drags to look would be sent to wherever their
> finger first met the glass.

C'est vrai de la *press*. Ce qui était livré envoyait Keepy là où le doigt
se **LEVAIT**. Rien n'était faux tant qu'il n'y avait aucune raison de
glisser ; CH73 donne un sens au glissement, donc il faut désormais
distinguer les deux gestes.

**Il n'y a donc rien « dessus » sur quoi ajouter — le seuil est à créer.**
Mais le dépôt en publie déjà un, dans `SkateTouchInput.gd` :

| constante | valeur | ce que son propre commentaire dit |
|---|---|---|
| `SLOP_PX` | **16,0 px** | « 16 px is a little over a millimetre on Mathieu's phone — large enough that a thumb pressing and lifting registers as a tap » |
| `TAP_MAX_S` | **0,45 s** | « a finger held motionless for a second is not asking to get off — it is asking to go straight on » |

`SLOP_PX` se justifie en termes de **pouce et de téléphone**, pas de
planche : c'est le même fait, et « un fait est publié une fois, jamais
recopié » interdit une seconde orthographe. **Il est lu depuis là.**

`TAP_MAX_S` est **refusé**, et c'est une décision argumentée — voir § 4.

### 1.2 La caméra, et ce qu'elle publie déjà

* pose hub : `global_position.lerp(_wanted() + offsets, weight)`,
  `_hub_basis` **jamais écrit** (discipline explicite, cassée une fois par
  un lot et payée sur `CabinProbe`) ;
* `OFFSET = (0 ; 7,6 ; 8,9)`, module **11,7034 u**, élévation
  **40,4951°** ;
* le basis authored pitche **34,0°** — la caméra **ne regarde donc pas**
  Keepy, désaccord de 6,5° mesuré au CH36 et dont `FRAME_TOP_AT_APLOMB`
  dérive.

### 1.3 Aucun prédicat « à pied » n'existait

`KeepyHopper` a **douze** états et ne publiait que `is_hopping()` et
`is_on_carrier()`. L'ensemble intéressant en fait deux. Publié en
`is_afoot()` plutôt que réécrit chez chaque lecteur : un appelant qui
aurait écrit le test lui-même serait à un `State` près de ne plus être
d'accord avec le suivant.

⚠️ **La balle sautillante est DEDANS, et c'est le seul arbitrage du lot.**
`_vehicle` est un *modificateur de saut* : l'état reste IDLE/HOPPING, le
tap nomme toujours une destination, la caméra est toujours la pose de
repos. Elle satisfait donc la lecture « schéma de contrôle » sur laquelle
le prédicat est bâti, et répondre faux pour elle creuserait une zone morte
que le joueur n'a aucun moyen de s'expliquer. Si un lot ultérieur veut
l'exclure, le changement est `and _vehicle == null`, une fois, à cet
endroit.

### 1.4 ⚠️ LA DETTE DU DOUBLE RELÂCHEMENT INTERFÈRE, ET DANS DEUX SENS

`HubTapInput` **ne filtre pas** `DEVICE_ID_EMULATION`, contrairement à
`KartTouchInput` et `SkateTouchInput` qui le filtrent tous les deux — et
c'est délibéré : `project.godot` ne pose pas `emulate_touch_from_mouse`,
donc sur un navigateur desktop un clic produit un événement souris **et
rien d'autre**. Filtrer la classe émulée ici rendrait le plateau
inutilisable hors téléphone.

Le prix est la dette que `CLAUDE.md` et `SkateInputProbe` enregistrent
tous deux : un doigt réel arrive **deux fois**, en
`InputEventMouseButton device=-1` **d'abord** puis en
`InputEventScreenTouch device=0`. Inoffensif pour un tap (`hop_to()` est
de profondeur un). **Pas inoffensif pour un drag**, de deux façons
indépendantes :

1. un mouvement appliqué sur les deux classes **tourne la caméra deux
   fois plus loin** sur téléphone que sur desktop, sans rien pour le
   signaler ;
2. un latch effacé sur la release est de nouveau vide à la seconde, donc
   le jumeau relirait le drag comme un tap et **marcherait Keepy là où le
   doigt s'est levé** — exactement le défaut que le seuil existe pour
   fermer, rentrant par la porte de derrière.

Conformément au brief, **la dette n'est pas corrigée** (hors scope). Elle
est neutralisée par la **forme**, et les deux moitiés sont gatées (§ 5,
PHASE D) au lieu d'être affirmées.

## 2. La mécanique — une rotation rigide, et trois propriétés gratuites

L'orbite est **une rotation rigide de tout le rig autour du point sol de
Keepy**. Les deux moitiés de la pose tournent de la **MÊME** rotation :

```
position = ground + R * OFFSET
basis    = R * _hub_basis          R = Ry(yaw) * Rx(-pitch)
```

Trois propriétés en tombent, aucune réglée :

1. **à (0, 0) la rotation est l'IDENTITÉ**, donc tout le code ajouté est
   arithmétiquement inerte sur un arbre où personne n'a glissé. Gaté
   (PHASE I), pas supposé ;
2. **la distance ne peut pas changer** — `|R·OFFSET| = |OFFSET| = 11,7034 u`
   pour toute rotation. Le brief interdisait d'ajouter un zoom ; cette
   forme rend un zoom impossible à ajouter par accident ;
3. **la caméra ne regarde toujours pas Keepy.** Le désaccord de 6,5° du
   CH36 est transporté inchangé, donc le cadrage que décrit le commentaire
   d'`OFFSET` (Keepy à 124 px, les pads de portail à 7,8 % et 92,2 %) est
   préservé **à tous les lacets**.

⚠️ **Et le roulis est exactement nul par ARITHMÉTIQUE, pas par clamp.**
`_hub_basis` est une rotation pure autour de X (la scène n'authore que du
tangage), le pivot de pitch aussi, le lacet est une rotation pure autour
de Y : le produit vaut `Ry(yaw) · Rx(-(pitch + 34°))`, un basis
lacet-puis-tangage dont le vecteur haut reste dans le plan vertical.
Mesuré sur toute la bande : **pire `|basis.x.y|` = 0,000000000**.

⚠️ **Le pitch pivote autour de l'axe droit TOURNÉ, pas autour du X du
monde** : `spin * pivot = Rot(spin·X, −pitch) * spin`, donc après un
demi-tour un glissement vers le bas incline toujours vers le bas.

⚠️ **Les deux moitiés retardent ENSEMBLE ou le rig n'est pas rigide.** La
position est lissée à `FOLLOW_LAMBDA` (constante de temps 0,2 s) ; un
basis qui snapperait viserait où la caméra *va être* plutôt qu'où elle
est, et Keepy sortirait du cadre pendant un glissement rapide pour y
revenir après. `_apply_orbit` slerpe le basis **au même poids**, et c'est
un no-op au repos (rien ne s'exécute sous la première ligne, donc pas de
dérive par aller-retour quaternion sur une longue session).

## 3. Les bornes de pitch — mesurées, et le balayage n'a trouvé aucun genou

`Ch73Recon` (sonde jetable, supprimée avant commit) a balayé la bande au
degré, sous xvfb + opengl3, en lisant trois grandeurs **sur la caméra
vivante** à chaque pas. Extraits :

| pitch | élévation | dégagement | couronne cadrée | % écran adressable | primitives |
|---|---|---|---|---|---|
| −40 | 0,50 | **0,1011** | oui | 40,0 | 74 538 |
| −35 | 5,50 | 1,1207 | oui | 46,7 | 74 484 |
| −30 | 10,50 | 2,1318 | oui | 53,3 | 74 464 |
| **−23** | **17,50** | **3,5183** | oui | **60,0** | 74 254 |
| −15 | 25,50 | 5,0375 | oui | 73,3 | 73 531 |
| −5 | 35,50 | 6,7954 | oui | 86,7 | 72 530 |
| **0 (repos)** | **40,50** | **7,6000** | oui | **93,3** | **71 764** |
| +10 | 50,50 | 9,0300 | oui | 100,0 | 52 694 |
| +25 | 65,50 | 10,6492 | oui | 100,0 | 39 838 |
| **+43** | **83,50** | **11,6281** | oui | 100,0 | 38 772 |
| +49 | 89,50 | 11,7030 | oui | 100,0 | 38 696 |

### 3.1 ⚠️ LA COURONNE EST DANS LE CADRE AUX QUATRE-VINGT-DIX PAS

« Keepy sort du cadre » ne borne **rien**. C'est la propriété 3 du § 2 qui
paie : une rotation rigide préserve le cadrage, donc le critère naturel
qu'on aurait cherché en premier n'existe pas. Le dire fait partie du
résultat.

### 3.2 Aucun genou — donc chaque borne est ancrée sur une PROPRIÉTÉ

La fraction adressable décroît **régulièrement** (93,3 % au repos, 80,0 à
−12, 66,7 à −22, 40,0 à −40), sans falaise sur laquelle poser une borne.
Chaque borne est donc ancrée sur une propriété **re-mesurable et gatée** :

**BASSE, −23,0° (élévation 17,4951).** Deux choses y tiennent et cessent
de tenir en dessous :
* la caméra garde **3,5183 u** de dégagement au-dessus de la surface —
  plus du **double** de la couronne de Keepy (1,7 u), donc l'objectif ne
  descend jamais dans la couche d'herbe que plante le scatter. Le
  dégagement atteint la couronne vers −32 et le sol lui-même à −40,5 ;
* le tangage **propre** de la caméra est encore de **11,0° vers le BAS**.
  Il atteint l'horizontale à −34,0°, angle au-delà duquel l'image est
  majoritairement du ciel et un tap ne veut rien dire sur l'essentiel de
  l'écran. 60,0 % de l'écran y résout encore vers un point du sol, contre
  93,3 % au repos.

**HAUTE, +43,0° (élévation 83,4951).** La limite dure est le **ZÉNITH** à
+49,4951, où la composante **horizontale** de l'offset est nulle — et un
lacet est une rotation autour de l'axe vertical, donc au zénith un
glissement latéral ne déplace la caméra **nulle part** et le joueur tient
une commande morte sans rien pour le lui dire. La borne conserve
**1,3249 u** de rayon horizontal (`11,7034 · cos 83,4951`), donc un lacet
tourne encore visiblement la vue tout en haut de la bande.

### 3.3 ⚠️ CE QUE LE BALAYAGE A RÉFUTÉ — le soupçon du lot lui-même

On s'attendait à ce qu'une caméra inclinée vers l'horizon ouvre le frustum
comme le fait la pose de CONDUITE : `DRIVE_FAR` existe parce que celle-ci
a mesuré **123 515 primitives contre 69 551** au spawn.

Mesuré ici : **74 538 tout en bas de la bande contre 71 764 au repos,
+3,9 %.** Le haze et le `visibility_range_end` du scatter font déjà le
travail. **`far` n'est PAS touché, et c'est une mesure, pas un oubli.**

### 3.4 Une limite énoncée et non corrigée

Cette caméra n'a jamais eu de collision avec le terrain et n'en a toujours
pas. Au repos elle flotte à 7,6 u et la question ne se posait pas ; à la
borne basse elle a 3,5183 u au-dessus d'un sol **plat**, donc au-dessus
d'un relief assez raide elle pourrait pénétrer. C'est la propriété
pré-existante de la pose fixe avec une marge plus petite, pas une classe
de défaut neuve, et la fermer est une forme de collision que ce lot n'a
pas eu à écrire.

## 4. ⚠️ LE HUB PREND `SLOP_PX` ET DÉCLINE `TAP_MAX_S`

Divergence assumée avec la planche, avec sa raison — le garde-fou du brief
demandait exactement ça (« signaler et proposer un ajustement plutôt que
de forcer une valeur arbitraire sans mesure »).

**Sur la planche un doigt TENU a un second sens** : c'est l'accélérateur,
donc un doigt pressé et tenu sans glisser est le geste « tout droit », et
le lire comme le tap de sortie éjecterait un rider qui demandait à
accélérer. `TAP_MAX_S` est ce qui sépare ces deux gestes **réels**.

**Dans le hub un doigt tenu n'a aucun autre sens.** Il y a deux gestes et
l'un d'eux est défini par le fait de **BOUGER** ; une press qui ne bouge
jamais ne peut avoir voulu dire que l'endroit qu'elle désigne. Une limite
de temps y inventerait un troisième résultat — presser, attendre, lever,
**RIEN** — sans aucun retour pour l'expliquer, et le joueur qu'elle
attraperait est le joueur délibéré qui repose son pouce avant de lever.

⚠️ **Et la limite a été MESURÉE avant d'être déclinée, sur un banc qu'elle
avait déjà mordu.** `TAP_MAX_S` est en temps **réel** ; `--fixed-fps` ne
fixe que le pas de simulation. Sous llvmpipe :

| frames | temps réel | verdict à 0,45 s |
|---|---|---|
| 1 | 0,152 s | encore un tap |
| 2 | 0,292 s | encore un tap |
| 4 | **0,551 s** | **PLUS un tap** |
| 6 | **0,824 s** | **PLUS un tap** |

Le tap de six frames de la sonde durait **0,824 s**. Une assertion passait
donc ou échouait **selon la charge machine**, et a envoyé une passe rouge
chercher un défaut qui n'existait pas. C'est « une sonde à séquence
temporelle se rejoue à charge comparable » arrivant par le **code** au
lieu du banc. C'est la **preuve**, pas la raison : la raison est le
paragraphe au-dessus, et elle tiendrait sur un téléphone à 120 Hz.

Gaté : PHASE T3b/T3c presse **1,380 s** immobile et exige que ce soit
toujours une destination. Passe rouge 7 (remettre `TAP_MAX_S`) : **1 rouge
sur 1 prédit**.

## 5. La sonde — `OrbitCameraProbe`, 56 assertions, sept phases

**Tout geste passe par `Input.parse_input_event`** dans les vrais nœuds ;
`HubCamera.orbit_by` n'est appelé **nulle part** dans le fichier sauf par
le moteur. CH57 a expédié 43 assertions vertes sur une planche qu'aucun
tap n'atteignait parce que son banc pilotait l'API : l'axe est le même —
le **ROUTAGE** — et il est pire que d'habitude ici, puisque ce qui est
gaté est une **DISTINCTION entre deux gestes qui arrivent sur le même
fil**.

⚠️ **Elle tourne sous xvfb + opengl3, jamais `--headless`.** Le brief
demandait une sonde headless ; elle ne peut pas l'être, et le modèle qu'il
citait (`FunfairProbe`) ne l'est pas non plus. Sous le driver dummy le
rect du conteneur est dégénéré, `_handle_point` sort à son test de rect et
**toutes** les assertions passeraient **en ne s'exécutant jamais**. PHASE I
asserte le rect en premier.

| phase | ce qu'elle gate |
|---|---|
| **I** | le banc voit un vrai écran ; au repos la rotation EST l'identité, l'offset EST `OFFSET`, le basis EST celui authored |
| **B** | les deux bornes, re-mesurées contre la propriété qui les a choisies ; distance invariante (pire 0,0000010 u) et roulis nul (0,000000000) sur toute la bande |
| **G** | un déplacement pixel connu produit un angle connu ; les deux signes ; **blind check** que la caméra a réellement bougé (8,5070 u) |
| **D** | le jumeau du téléphone tourne la caméra **une** fois, n'avale aucun tap sur **aucun** canal, un survol ne tourne rien, le même pixel deux fois vaut un pas |
| **S** | collant : 600 frames plus tard l'orbite est **bit-pour-bit** où elle a été laissée ; la pose est **arrivée** à 0,00000° de l'orbite laissée et à **114,51°** de la pose authored ; une marche entière n'y touche pas |
| **T** | un tap court marche toujours — avant l'orbite, sous un jitter de 12 px, après 1,380 s d'appui immobile, et **sous une caméra tournée** |
| **L** | aucune orbite tant que quelqu'un d'autre possède le cadre (POV, poursuite), et la licence revient après |

## 6. Rouge-avant-vert — sept passes, et deux ont trouvé des défauts DANS LA SONDE

| passe | neutralisé | prédit | obtenu |
|---|---|---|---|
| 1 | le latch de drag | 1 (D3) | **1** (D3, 3 taps de sol) |
| 2 | la réclamation un-geste-un-canal | 1 (D4) | **1** (D4) |
| 3 | l'intégration par delta (offset depuis l'ancre) | 3 | **5** |
| 4 | le clamp de pitch | 4 | **4** |
| 5 | la licence d'orbite | 4 | **4** |
| 6 | la pose qui suit l'orbite | 3 | **3** |
| 7 | `TAP_MAX_S` remis | 1 (T3c) | **1** (T3c) |

Fichiers restaurés et vérifiés **byte-identiques** (`cmp`) après chacune.

### 6.1 ⚠️ LA PASSE 1 A RENDU 4 ROUGES POUR 1 PRÉDIT, ET LES 3 EXTRAS ÉTAIENT DANS LA SONDE

Le latch retiré, la release au bout d'un geste d'orbite devenait un vrai
tap, Keepy partait marcher là où il tombait, et **trois instruments plus
loin** — « un tap a démarré une marche », « un jitter est encore un tap »,
« la caméra est maintenant tournée » — posaient leur question à un monde
qui avait bougé sous eux. L'un d'eux l'avait manifestement marché sur un
canal de prop, ce qui le laissait dans un état où l'orbite est
**correctement** refusée : un INSTRUMENT rouge sur du code juste.

Corrigé à la racine : `_reset()` regare Keepy sur `OPEN_GROUND` (le même
sol ouvert que `SkateInputProbe` et `SkateDismountProbe`) et re-snappe la
caméra, et tout pixel d'instrument passe par `_walk_pixel()` — qui vérifie
que le rayon **résout** vers le sol et que la destination est à plus de
3 u, donc ni un tap dans le ciel ni la marche de longueur nulle que
`CLAUDE.md` documente.

### 6.2 ⚠️ LA PASSE 2 EST REVENUE **ALL GREEN**, ET C'EST SA MOITIÉ LA PLUS UTILE

Retirer la réclamation de canal devait rendre D1 et D2 rouges. **Elle n'a
rien rendu rouge du tout.**

Cause : l'orbite intègre la différence entre échantillons **CONSÉCUTIFS**
(`at - _last`), donc un jumeau livré au **MÊME** pixel contribue le delta
une fois et **exactement zéro** la seconde. **Le doublement que ce lot
voulait empêcher est neutralisé par l'INTÉGRATION, pas par la
réclamation.**

C'est exactement le précédent que `SkateTouchInput` écrit sur son propre
garde `DEVICE_ID_EMULATION` (« ce que le garde achète n'est pas mesurable
ici »). Deux assertions en sont nées :

* **D5** gate l'intégration elle-même (passe 3 : le même pixel deux fois
  sort à **−1,20000 rad** au lieu de −0,60000, le doublement rendu
  visible) ;
* **D4** gate ce que la réclamation achète **réellement**, et c'est un
  défaut **desktop** et non téléphone : `_dragged` survit à un geste par
  conception (les deux releases d'un jumeau doivent lire le même latch),
  donc une souris **déplacée sans bouton enfoncé** après un drag serait un
  mouvement avec un `_last` périmé, un `_dragged` latché, et rien pour
  l'empêcher de tourner la caméra. **Un survol n'est pas un geste.**

### 6.3 Les extras des autres passes

* **Passe 3 : 5 pour 3.** Les deux extras (G2 le signe, S3 la convergence)
  tracent à la **même** cause que G1 : la sur-intégration fait franchir
  ±π au lacet, donc `wrapf` inverse le signe et la pose n'a pas convergé.
  Une seule cause, trois assertions.
* **Passe 4 : 4 pour 4**, et B2 publie un dégagement de **−1,1227 u** —
  la caméra sous le sol, exactement ce que la borne empêche. ⚠️ **B5 reste
  VERTE sous cette neutralisation**, et pour la mauvaise raison : au-delà
  du zénith le rayon horizontal repasse à 6,97 u, donc `> 1,0` est
  satisfait. B5 **n'est pas autoportante** — elle est gardée par B6 (le
  clamp tient). Dit plutôt que sous-entendu.

### 6.4 ⚠️ S3 A ÉCHOUÉ SUR DU CODE JUSTE, ET N'A PAS ÉTÉ FAITE TAIRE

Première rédaction : « la pose 600 frames plus tard est la pose 60 frames
après le lever ». **Rouge sur du code correct** — la pose était encore en
train d'**ARRIVER** : `_apply_orbit` retarde le basis à `FOLLOW_LAMBDA`
exactement comme la position l'a toujours été, donc un échantillon pris
une seconde après le lever porte encore `exp(−5) = 0,67 %` de l'erreur.

**Converger vers ce que le joueur a demandé n'est pas un recentrage**, et
une assertion incapable de distinguer les deux n'est pas celle dont cette
phase a besoin. Ce que « collant » interdit réellement, c'est que la pose
converge vers la pose **AUTHORED**. Les deux distances sont donc mesurées
et publiées : **0,00000° de l'orbite laissée, 114,51° de la pose
authored**, plus un instrument (S3c) qui exige que les deux bases soient
bien différentes pour que S3b ne soit pas vide.

## 7. Table croisée — deux arbres

| sonde | référence `d71f803` | branche | verdict |
|---|---|---|---|
| `.scn` importés | **154** | **154** | import complet des deux côtés |
| `FrameCeilingProbe` | exit 0 | exit 0, plafond relu **7,968** | parité |
| `ProbeTimeoutAudit` | 99 scènes, PASSED | 100 scènes, PASSED | **+1**, `OrbitCameraProbe` ; la recon jetable est supprimée |
| `SurfaceProbe` | ALL GREEN, 0 red | ALL GREEN, 0 red | parité |
| `SkateDismountProbe` | ALL GREEN, 0 red | ALL GREEN, 0 red | parité |
| `FunfairProbe` | ALL GREEN, 0 red | ALL GREEN, 0 red | parité |
| `CabinProbe` | **9 échecs** | **8 échecs** | ⚠️ voir 7.1 |
| `OrbitCameraProbe` | *(n'existe pas)* | **56 ok / 0 RED** | la sonde du lot |

### 7.1 ⚠️ `CabinProbe` NE SE REPRODUIT PAS SUR UN SEUL ARBRE — mesuré, pas supposé

9 échecs sur la référence **intouchée** contre 8 sur la branche : la
branche en a **moins**, mais les listes diffèrent, donc la comparaison
n'est pas lisible telle quelle. `CLAUDE.md` dit quoi faire avant de lire
une divergence de ce genre — **retourner la métrique contre elle-même**.

Deux runs de la **MÊME** référence intouchée, seuls, l'un après l'autre :

| run | échecs |
|---|---|
| référence, run 1 | **8** |
| référence, run 2 | **13** |

**8 et 13 sur un seul arbre**, avec des jeux d'assertions différents. Un
gate qui ne se reproduit pas sur un arbre ne peut rien dire de deux —
c'est exactement le CH37, et CH71 l'avait déjà noté (« CabinProbe ne se
reproduit pas sur un seul arbre »). La sonde est donc **exclue du verdict
de la table croisée, la mesure publiée** plutôt que passée sous silence.

Ce qui se dit malgré tout, et c'est la déclaration la plus forte
disponible : le jeu d'échecs de la branche est **byte-identique** à celui
du run 1 de la référence (`diff` vide sur les huit lignes, mêmes
libellés, mêmes nombres).

## 7bis. Déploiement — vérifié SUR LE SERVICE, deux marqueurs

Merge palier 1 : `d71f803..1396cc0` sur `staging`, arbres du commit de
merge et de la branche **byte-identiques** (`edde33c6` des deux côtés,
`git diff` vide).

| marqueur | lecture |
|---|---|
| **CI** | run 522, `conclusion: success`, `completed_at` 16:39:52 ; « Deploy to Vercel [PRODUCTION -- main] » **skipped** |
| **`CACHE_VERSION`** | `1789144756` = **16:39:16 UTC**, à l'intérieur de la fenêtre de l'étape `Export Web build` (16:39:09 → 16:39:17) |
| **lecture de l'alias** | `x-vercel-cache: **MISS**`, `age: **0**` — une vraie lecture, pas une copie de bord figée |
| **`index.wasm`** | **35 376 909** octets — la constante d'identité que `CLAUDE.md` publie pour un lot qui ne touche pas le code moteur ✅ |
| `index.js` | 331 495 octets |
| `index.pck` | 34 801 376 octets — marqueur « un nouveau build est servi », **jamais une preuve d'identité** |

## 8. Ce que ce lot NE peut PAS signer — CH62, dit en premier

Un banc ne juge pas un game feel. `ORBIT_GAIN = 0,005 rad/px`
(0,2865°/px, soit **143°** pour un balayage de pouce de 500 px) est un
bouton de ressenti : ce fichier prouve qu'un déplacement pixel connu
produit un angle connu, que l'angle est borné et que la pose est une
rotation rigide. **Si 0,005 est la bonne quantité de tour pour un pouce,
si la borne basse est une vue que quelqu'un veut, et si une caméra
collante est agréable à vivre sont des appels device.**

## 9. Suites possibles — aucune engagée

* **Le zoom.** Hors scope par consigne, et la forme rigide le rend
  impossible à ajouter par accident. Ce serait un facteur sur `OFFSET`
  dans `_orbit_offset()`, avec ses propres bornes mesurées.
* **La collision caméra/terrain** (§ 3.4).
* **La dette du double relâchement** (§ 1.4) reste ouverte. Elle est
  neutralisée pour l'orbite, pas corrigée ; le filtre
  `DEVICE_ID_EMULATION` ne peut pas être posé ici sans casser le desktop,
  donc la vraie réparation est un chemin souris explicite plutôt qu'un
  filtre.
* **`FRAME_TOP_AT_APLOMB` et ses dérivés** (`HubTrees.SEAT_MAX_Y`, le
  plafond de siège du parc) décrivent le cadre **à l'orbite zéro**. Ils
  restent les bons chiffres pour **AUTHORER** — un prop doit être visible
  pour un joueur qui n'a pas touché la caméra — mais ce ne sont pas des
  promesses sur un cadre que le joueur a tourné. Dit, pas corrigé.
