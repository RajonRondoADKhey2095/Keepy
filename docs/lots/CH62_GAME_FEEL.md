# CH62 — LOT GAME FEEL : rendre la physique PERCEPTIBLE

> Sept sections. Le lot part d'un verdict device de Mathieu sur le build
> CH61 — « je ne vois pas de différence, je n'arrive pas à m'amuser avec
> le skateboard » — sur une physique dont **toutes les sondes étaient
> vertes** et dont les mesures étaient justes. Il n'ajoute **aucune
> physique** : il ajoute ce qui la restitue.

## Section 0 — LA PRÉMISSE, ET ELLE TIENT

CH61 mesure une hauteur qui suit la vitesse d'arrivée : **0,098 u à
2,98 u/s contre 1,106 u à 8,97 u/s** sur le même quarterpipe, un ordre de
grandeur d'écart. `SkateFeelProbe` PHASE W a reproduit le banc de CH61
avant de publier quoi que ce soit de neuf — `push 17,2165`,
`brake 10,3433`, à la quatrième décimale — donc c'est bien la même
planche.

Le défaut n'était dans aucune de ces mesures. Il était dans le fait que
**rien à l'écran ne les restitue** : `HubCamera.OFFSET` est une constante
`(0 ; 7,6 ; 8,9)` qui ne tourne jamais et ne monte jamais, le hub n'a
**aucun son** (mesuré : trois fichiers `.wav` dans tout le dépôt, tous
possédés par `HUD.gd` de Keepy Chased), et un mètre de hauteur sur une
caméra à 11,7 u déplace la planche de quelques dizaines de pixels vers le
haut du cadre — indiscernable d'une planche simplement plus loin.

`CLAUDE.md` le dit depuis CH53 : **une mécanique invisible n'existe pas
pour le joueur.**

## Section 1 — CE QUI A ÉTÉ FAIT DE LA CAMÉRA, ET CE QUE ÇA IMPLIQUE POUR D6

### D6 reste FERMÉE, et voici exactement de combien elle s'est entrouverte

Le mode `RIDE` de `HubCamera` **n'est pas une caméra de poursuite**. Ce
qu'il ne fait pas est la moitié de sa définition :

* **il ne fait pas de lacet** — la BASE de la caméra n'est jamais touchée,
  donc l'horizon ne peut pas bouger, ce qui est la raison même pour
  laquelle la pose du hub est figée ;
* **il n'y a aucun `look_at`**, aucun cap retardé, aucun changement de
  `far` — le mode kart fait les quatre, celui-ci aucun ;
* **la pose reste `_wanted() + OFFSET`**, exactement comme toujours, avec
  un offset SUPPLÉMENTAIRE borné ajouté à la CIBLE du même lerp. Hors
  ride, `_ride_offset()` rend `Vector3.ZERO` **exactement**, et les deux
  lignes du suivi sont byte-identiques à ce qui a toujours été livré.

Trois termes, tous bornés, tous publiés par `SkateFeel` :

| terme | à `rush` plein | ce qu'il achète |
|---|---|---|
| recul | **1,20 u** ajoutés à `OFFSET.z` | le petit mouvement de recul qui dit que le cadre RÉAGIT |
| hauteur | **0,45 u** ajoutés à `OFFSET.y` | idem, et il compense le recul dans le cadre |
| **fov** | **+6,0°** sur 45 (13 % d'image en plus) | **le travail** : ce qui lit comme de la vitesse est du décor EN MOUVEMENT, et le fov est ce qui en met plus à l'écran sans éloigner la planche |
| suivi de hauteur | **0,72 × la hauteur de la planche** | qu'une montée LISE comme une montée |

Mesuré sur un vol tapé au-dessus du quarterpipe de 1,45 u : **la caméra
monte de 0,899 u** pour un pic de planche de 1,966 u au-dessus du sol.
Sans ce terme elle ne monte de rien du tout — c'est le comportement livré
avant ce lot.

### ⚠️ Le suivi de hauteur est un CÂBLE SÉPARÉ de la vitesse, et la passe rouge le prouve

La passe rouge A coupe le fil du `rush` dans `HubCamera._ride_advance`.
Six assertions rougissent, **toutes** dans la réponse à la vitesse — et
`H THE CAMERA CLIMBED with the board (0,862 u)` reste **VERTE**. Les deux
moitiés de l'effet caméra sont réellement couvertes séparément.

### Ce que ça implique pour D6

Ce lot **ne tranche pas** D6 et ne prétend pas l'avoir fait. Ce qu'il
établit :

1. **Une caméra qui répond sans tourner suffit à rendre une vitesse
   lisible.** Il n'a pas fallu de poursuite pour que la hauteur et
   l'allure existent à l'écran.
2. **Le coût d'une vraie poursuite serait d'un tout autre ordre.** Le
   simple élargissement de fov + recul de ce lot coûte déjà **+8 165
   primitives et +16 draw calls** au poste mesuré (§3), là où CH30 a
   chiffré la poursuite du kart à **123 515 contre 69 551** — parce
   qu'une poursuite regarde vers l'horizon et perd la protection du
   frustum. Sur le lobe nord, où CH52 a mesuré **ZÉRO** disponible,
   c'est la mesure qui décidera de D6, pas un goût.
3. **Le critère de `CLAUDE.md` reste intact** : ce qui décide d'une
   poursuite est le PILOTAGE CONTINU, et la planche reste tapée vers une
   destination. Ce lot n'y touche pas.

## Section 2 — LES QUATRE EFFETS, ET POURQUOI CEUX-LÀ

Chacun a **son propre commit**, pour que Mathieu puisse en faire retirer
un sans perdre les autres.

### 1. La caméra (§1) — 0 draw call, un coût de frustum

### 2. Les traînées de vitesse, au BORD du cadre — 1 draw call

Quatre candidats étaient au brief. Ce qui a tranché est le budget, puis
le style :

* **un flou directionnel** est une passe plein écran. `CLAUDE.md` price
  explicitement les effets par fragment, et le lobe nord n'a **rien**.
  2 073 600 pixels sur un téléphone qui saute déjà une frame sur trois est
  la seule chose que ce lot ne devait pas expédier ;
* **une traînée derrière la planche** est de la géométrie monde :
  primitives, draw call, et une question d'enroulement (CH39). C'est aussi
  le moins lisible des quatre sur cette caméra — la planche fait 124 px et
  une traînée vit derrière elle, c'est-à-dire sous Keepy ;
* **un gros pompage de fov** est le tic « runner arcade » que le brief
  interdit, et il coûte des primitives au poste exact où il n'y en a pas.
  Un PETIT est livré quand même, dans la caméra, où il est mesuré ;
* **des traînées dessinées en `draw_texture_rect_region` depuis UNE seule
  texture sont UN SEUL draw call** — CH46 a mesuré exactement ça (37
  marqueurs + un fond depuis un atlas : **+1 appel**, contre **+38** pour
  la même chose en `draw_circle`).

Et elles sont **au bord** parce que c'est là que la vitesse se lit : le
centre du cadre porte la planche et le rider, que le joueur REGARDE ; le
mouvement périphérique est ce que l'œil intègre comme vélocité sans qu'on
le lui pointe. C'est aussi la moitié de l'écran où ce jeu n'a rien.

Trois choses les gardent cozy : **alpha de pointe 0,28**, **aucune arête
franche nulle part** (la bande est feathered en largeur ET en longueur,
donc une traînée n'a ni bouts ni côtés), et un **blanc CHAUD**, jamais
cyan.

### 3. Le son — 0 primitive, 0 draw call

**Ce qui existait, mesuré avant de construire quoi que ce soit** : trois
`.wav`, tous possédés par `HUD.gd`, **rien du tout dans le hub**, aucun
autoload SFX, aucune disposition de bus. `HUD.gd` dit pourquoi, noir sur
blanc : deux cues one-shot ne justifient pas un service global.

Ce raisonnement n'a pas changé, donc ce lot **ne construit pas un système
audio**. Il construit le minimum viable demandé — deux
`AudioStreamPlayer` simples possédés par la porte qui monte et démonte la
planche, exactement la forme que `HUD.gd` livre déjà.

* `skate_roll.wav` — **16 384 frames à 22 050 Hz mono 16 bits** (0,743 s),
  crête à 0,55. **Exactement périodique par construction** : le spectre a
  été écrit directement (corps large autour de 170 Hz, pente rose
  au-dessus, petit plateau vers 2,3 kHz pour le grain du béton) et
  transformé en inverse, donc le dernier échantillon rejoint le premier
  sans couture et la boucle ne peut pas cliquer. Un tremblement
  d'amplitude à 3 cycles par boucle pour les roulements, à un multiple
  exact de la longueur de boucle pour qu'il survive au raccord.
* `skate_land.wav` — **5 292 frames** (0,240 s), crête 0,70. Une claque de
  bois : transitoire de bruit sur un corps qui tombe de 174 Hz à 46 Hz.

Le pitch et le niveau suivent la **pace brute**, pas `rush()` : une
planche qui roule lentement fait quand même du bruit, et la faire taire
sous le plancher mettrait un clic au début de chaque ride. Les deux
players sont **plus doux que n'importe quel cue de Chased** (−26 à −9 dB
contre −4 / −2), parce que c'est un hub où l'on s'assoit et pas une
poursuite qu'on perd.

### 4. L'ombre portée qui se détache — 1 draw call, 2 triangles

La plus vieille réponse du livre, et la bonne ici : c'est le **seul indice
qui transforme une altitude en une DISTANCE À L'ÉCRAN entre deux choses
que le joueur voit en même temps**. La planche monte ; la tache sombre
reste au sol ; l'écart EST l'altitude, et ça ne demande ni HUD, ni
chiffre, ni apprentissage.

**Pas une vraie ombre** : tout asset de ce hub est unlit, le mesh de la
planche est en `SHADOW_CASTING_SETTING_OFF`, et allumer une vraie
projection pour un prop allumerait une shadow map pour tout le lobe nord.

**Elle est posée par un RAYCAST** et pas par `HubSurface.ground()` : la
planche passe l'essentiel d'un ride intéressant AU-DESSUS d'un module, et
une ombre posée sur la pelouse sous le deck de la funbox est une ombre
dessinée DANS la funbox, que le depth buffer mange — le repère
disparaîtrait exactement au moment où il sert. D1 est intact : ceci LIT la
surface, ne l'écrit jamais, et n'autorise aucune seconde orthographe du
sol.

Mesuré : blob à **1,966 u** de séparation au pic, alpha **0,340 → 0,215**,
échelle **1,000 → 0,660** — et le blob est projeté à **(540 ; 1071)** quand la
planche l'est à **(540 ; 912)**, soit **159 px d'écart à l'écran**, ce qui EST
le message.

### ⚠️ LES DEUX RÉGLAGES QUI ONT ÉTÉ MESURÉS PLUTÔT QUE CHOISIS, ET LES DEUX ONT BOUGÉ

Une sonde ne peut pas dire si c'est agréable (§4), mais elle peut dire de
combien un effet change les pixels qu'il couvre — et un **RENDU** peut
dire si on le voit. `CLAUDE.md` le répète depuis CH23 : la vérification
est un rendu, jamais une relecture. Un outil de capture jetable a rendu
trois frames (garée, à la croisière, au sommet d'un vol réel), les a
comparées à la même frame avec l'effet caché, et a déplacé les deux seuls
réglages du lot qu'aucun raisonnement ne pouvait fixer.

**Les traînées, 0,20 → 0,28.** À 0,20 le champ éclaircissait les pixels
qu'il couvre d'une **MOYENNE de 0,046 de pleine échelle**, soit ~5 %, et
la capture le confirmait : sur une image fixe **il n'y avait rien**. Le
lot qui existe parce que CH61 était juste et invisible ne pouvait pas
expédier son propre repère invisible. Le doute est donc tranché **vers le
haut**, ici et nulle part ailleurs.

**L'ombre, un fondu de 0,30 → 0,09 ramené à 0,34 → 0,20.** La première
rampe était physiquement juste (une ombre de contact s'adoucit quand le
corps monte) et **exactement à l'envers comme repère** : localisée sur la
frame au sommet d'un vrai saut, le blob y était lu à **alpha 0,112 sur du
béton pâle** — invisible au moment précis où il porte tout le message.
Mesuré au sommet : la planche est projetée à **(540 ; 912)** et le blob à
**(540 ; 1071)**, **159 px d'écart à l'écran**. C'est cet écart qu'il faut
voir ; la valeur qui le rendait illisible a été corrigée.

⚠️ **Et l'outil de capture est SUPPRIMÉ avant le commit** (`CLAUDE.md` :
une sonde de mesure ponctuelle n'entre pas dans le dépôt).
`ProbeTimeoutAudit` revient à **94 sondes** — le 93 de CH61 plus la seule
sonde permanente de ce lot.

## Section 3 — LE COÛT, EFFET PAR EFFET

### PHASE B — le coût PERMANENT du lot, planche garée : **ZÉRO**

| | ON (interrupteur haut) | OFF | delta |
|---|---|---|---|
| nœuds dessinés | 715 | 715 | **0** |
| triangles de scène | 346 624 | 346 624 | **0** |
| primitives du SubViewport | 70 923 | 70 923 | **0** |
| draw calls du SubViewport | 301 | 301 | **0** |
| primitives totales | 72 205 | 72 205 | **0** |
| draw calls totaux | 318 | 318 | **0** |

⚠️ **Et ce zéro est prouvé POSITIF D'ABORD.** Un zéro passe gratuitement.
`HubPerfOverlay` saute ce qui n'est pas visible dans l'arbre, donc un
recensement incapable de VOIR le blob rendrait le même zéro qu'un lot qui
ne coûte rien. Le blob est donc **montré**, le recensement doit bouger de
**exactement un nœud et deux triangles**, on le recache, il revient — et
seulement là le zéro veut dire quelque chose.

Les 70 923 primitives au spawn reproduisent le **70 946** de CH52 : le
banc restitue un chiffre déjà au dossier avant d'en publier un neuf.

### PHASE F — le coût de chaque effet PENDANT un ride, monde GELÉ

Poste : la planche lancée à 10 u/s depuis le park, monde figé,
**plancher de bruit du banc 0 primitive / 0 draw call**.

| effet éteint | Δ primitives SubViewport | Δ draw calls SubViewport | Δ primitives totales | Δ draw calls totaux |
|---|---|---|---|---|
| **ombre portée** | **+2** | **+1** | +2 | +1 |
| **traînées** | **0** (elles sont dans le viewport racine) | 0 | **+28** | **+1** |
| **caméra** | **+8 165** | **+16** | +8 165 | +16 |

* **L'ombre coûte littéralement un quad** : 2 primitives, 1 draw call.
* **Les traînées coûtent 28 primitives et UN draw call pour les
  QUATORZE.** 28 = 14 × 2 triangles, exactement. Et leur encre est mesurée
  à **2,432 % du cadre** — le chiffre qui price un effet par fragment.
* **La caméra coûte ~10 % de la frame à ce poste**, et c'est la seule
  ligne chère du lot.

⚠️ **Et le banc REFUSE de décomposer la ligne caméra.** Lues chacune
isolément à travers le même protocole : le recul seul **+203**, le fov
seul **+1 460**, les deux ensemble **+8 165** — les parties ne somment pas
au tout (1 663 contre 8 165). Un frustum est un VOLUME, l'angle et
l'apex balaient une région commune, et rien n'oblige les deux termes à
être additifs. `CLAUDE.md`, sur le banc de shader qui ne séparait pas ses
trois candidats : **« ce banc ne les sépare pas » EST le résultat.**

### Ce que ça vaut en FPS, et pourquoi c'est un chiffre à signaler

À la borne inférieure de CH52 (**≥ 0,199 ms par 1 000 primitives** au bord
nord), **8 165 primitives valent ≥ 1,6 ms**. Sur une frame device qui
tourne entre 50 et 56 FPS (17,9 à 20,0 ms), c'est de l'ordre de **4 à 5
FPS**. **C'est au-dessus du seuil de 2 FPS que le brief demande de
signaler, et c'est signalé ici plutôt que livré en silence.**

⚠️ **Mais cette facture n'est payée QUE derrière l'interrupteur `Physique
(dev)` ET QUE pendant un ride.** Planche garée, interrupteur haut : zéro
(PHASE B). Interrupteur bas : le lot n'existe pas (PHASE O). Aucun joueur
de production ne paie une primitive de ce lot.

### Ce qui a été ÉCARTÉ faute de budget

* **le flou directionnel** — passe plein écran, refusée sur le prix au
  fragment sans même être écrite ;
* **une traînée de géométrie derrière la planche** — primitives + draw
  call + une question d'enroulement, pour le cue le moins lisible des
  quatre sur cette caméra ;
* **un pompage de fov généreux** — borné à 6° ;
* **fermer `far` pendant le ride** (ce que fait `DRIVE_FAR` à 120 u pour
  le kart) aurait pu FINANCER l'élargissement de fov. Écarté : la
  montagne du CH38/CH40 et le décor lointain apparaîtraient et
  disparaîtraient à l'entrée et à la sortie du ride, et ce lot n'a pas de
  mesure pour dire à quelle distance ça se voit.

## Section 4 — CE QU'AUCUNE SONDE NE PEUT VALIDER ICI

C'est la première ligne du fichier de la sonde, et c'est délibéré.

**`SkateFeelProbe` NE PEUT PAS DIRE SI C'EST AGRÉABLE.** Le game feel est
un jugement, il se fait avec un pouce sur un téléphone, et il appartient à
Mathieu. Dix-neuf faux-signaux de ce dépôt étaient des assertions qui
RESSEMBLAIENT à la mesure demandée ; le dix-huitième était une sonde qui
appelait l'API au lieu d'exercer le canal réel. Écrire ici un feu vert qui
sous-entend « le ride est amusant » serait le vingtième, et le pire —
parce que le verdict device qui a déclenché ce lot portait sur un build
dont **toutes** les sondes étaient vertes.

**Ce que la sonde signe :**

1. **la courbe est une COURBE** (PHASE C) — bornée, monotone, et elle
   BOUGE (le spread est gaté AVANT la monotonie : une constante est
   monotone) ;
2. **les effets y sont CÂBLÉS** (PHASE W, H, A) — chaque valeur est relue
   **sur l'objet vivant** (`camera.fov` tel que le moteur le tient,
   `camera.ride_offset()` tel que la pose l'utilise, `streaks.rush()`,
   `roll.pitch_scale`) pendant qu'une vraie planche roule avec un vrai
   rider dessus ;
3. **rien ne tourne interrupteur bas** (PHASE O) ;
4. **ce que ça coûte** (PHASE B, F) et **que les deux effets DESSINÉS
   dessinent vraiment des PIXELS** (PHASE P).

**Ce qu'elle ne signe pas :** que les traînées lisent comme de la vitesse,
que le roulement sonne comme de l'uréthane, que l'ombre rend l'air
lisible, que quoi que ce soit là-dedans est cozy.

## Section 5 — LES SEPT FAUX-SIGNAUX TROUVÉS **DANS LE BANC**

Aucun n'était un défaut du jeu. Tous auraient publié un chiffre faux.

### 5.1 ⚠️ UN PARCOURS DE BANC QUI NE TIENT PAS DANS LA RÉGION MESURE UN RUN QUI N'A JAMAIS EU LIEU

PHASE H lançait une approche tapée de 9 u vers le quarterpipe de 1,45 u,
qui est à (5 ; 54) et se prend par le nord — donc départ à **z = 63,7**,
**hors du lobe skate** (centre (0 ; 35), r 28, qui atteint z = 62,55 à
x = 5). `SkateBoardBody._fence` **REFUSE** un pas hors région **et efface
la cible avec**. Résultat : `air ticks 0 | peak blob lift 0,000 | camera
climb 0,000` — trois lectures parfaitement vraies d'un run qui ne s'est
jamais produit, et qui se lisent exactement comme « l'effet n'est pas
câblé ». Corrigé en RÉDUISANT la course jusqu'à ce qu'elle tienne
(mesurée : **6,75 u**) et en gatant qu'elle reste assez longue.

### 5.2 ⚠️ UNE CAMÉRA QUI BOUGE FAIT « COÛTER » 5 747 PRIMITIVES À UN QUAD DE DEUX TRIANGLES

Première version de PHASE F, monde vivant : éteindre le blob « coûtait »
**+5 747 primitives** et les traînées **+5 713** — sur deux triangles et
sur un overlay qui n'est même pas dans ce viewport. Les lectures étaient
vraies : la planche roule à 10 u/s entre deux captures espacées de trois
frames, le suivi emmène la caméra, et c'est une autre moitié du park qui
est dans le frustum. **Le plancher de bruit du banc ne l'a pas attrapé
parce qu'il était pris sur deux lectures dos à dos et que les bascules ne
l'étaient pas.** Corrigé en **GELANT le monde** (`get_tree().paused`), ce
qui fait tomber le plancher à **0 primitive / 0 draw call**.

### 5.3 ⚠️ UNE LECTURE RÉPÉTÉE NE DÉTECTE PAS UNE VALEUR PÉRIMÉE — plancher ZÉRO des deux côtés d'un pas de 315

Le gel a fabriqué le piège suivant, et c'est **le plus important du lot**.
Monde gelé, le compteur lit **85 812 deux fois de suite, tremblement
ZÉRO**. On déplace la caméra de 2,3 u et on la remet exactement où elle
était : il lit **86 127 deux fois de suite, tremblement zéro encore**.
**Deux états parfaitement stables pour UNE pose.**

Le premier était périmé. **Un moteur ne réévalue pas ce qu'une caméra
gelée voit tant qu'elle ne BOUGE pas**, et tout ce que ce dépôt oppose à
un mauvais delta — le plancher de bruit de CH40, le tremblement par
station de CH41 — est une **lecture répétée**, qui s'accorde avec une
valeur périmée aussi volontiers qu'avec une vraie.

Parade livrée (`_read_pose`) : une pose n'est **jamais lue là où on la
trouve**. La caméra est emmenée AILLEURS, on lui donne des frames, on la
pose sur la configuration à mesurer, on lui redonne des frames, et
seulement là on lit — **deux fois**, les deux publiées.

⚠️ **Et même avec ça, la même pose lit 86 432 quand c'est le RIDE qui a
mis la caméra là et 86 133 quand c'est le protocole de secousse.** Les
deux se répètent exactement. **Le compteur de frame du moteur porte un
état DÉPENDANT DU CHEMIN sur un monde gelé.** C'est publié tel quel, et
c'est pourquoi la ligne caméra est un ORDRE DE GRANDEUR (≈ 8 200) et pas
un chiffre à l'unité.

### 5.4 ⚠️ UN PLANCHER DE PIXELS À 85 % DE LA SURFACE

Première version de PHASE P : **110 550 pixels échantillonnés de
différence entre deux captures de la MÊME frame**, soit 85 % de la
surface. Deux causes réelles : le monde tournait encore, et **le `TIME`
d'un shader n'est pas arrêté par `paused`** (`CLAUDE.md`, CH48), donc
l'herbe, l'eau et le haze bougent d'un cheveu à chaque frame pour
toujours. Un cheveu n'est pas ce à quoi ressemble l'un ou l'autre des
effets de ce lot. Corrigé par un **seuil de 0,02 pleine échelle** sur un
canal : plancher **≈ 300-400 px**, signal **1 074 et 1 421 px**.

### 5.5 ⚠️ UNE GÉOMÉTRIE ÉCRITE EN PIXELS ABSOLUS N'A PAS LA MÊME FORCE SUR DEUX ÉCRANS

Le champ de traînées, écrit en pixels, encrait **0,694 %** d'une surface
headless de 1920 de haut et **1,233 %** de la fenêtre xvfb — le MÊME code,
deux fois plus fort sur un écran que sur l'autre, sans rien pour dire
lequel le téléphone aurait. Toutes les dimensions sont désormais des
FRACTIONS du contrôle, et l'encre est une constante (**2,432 %**) que le
banc publie.

### 5.6 ⚠️ `edit/loop_mode=0` DANS UN `.import` DE WAV NE VEUT PAS DIRE « PAS DE BOUCLE »

Il veut dire **« Detect From WAV »**, et un WAV généré sans chunk de
boucle retombe alors sur DISABLED. L'énumération de l'importeur Godot 4.3
est `0 Detect From WAV / 1 Disabled / 2 Forward / 3 Ping-Pong /
4 Backward` : il faut **2**. Le symptôme aurait été un roulement qui
s'arrête au bout de 0,743 s de chaque ride, sans erreur. `SkateAudio`
`push_error` si le sample revient sans boucle, et PHASE A le gate sur la
ressource chargée.

### 5.7 ⚠️ LA FUNBOX N'EST PAS DE L'AIR

Premier jet de PHASE H, lancé à la croisière depuis 2 u : **13 ticks en
l'air, 0,217 u de séparation du blob, impact sous le plancher, aucun
cue**. Lecture correcte, et ce n'est pas de l'air : une planche qui monte
une rampe de 0,85 u et arrive sur un deck est PORTÉE tout du long. CH61
avait déjà mesuré lequel des modules lâche la planche par le haut — celui
de 1,45 u — et c'est le seul air véritable que ce park produit.

## Section 6 — LES PASSES ROUGES : DEUX QUI NE SE RECOUVRENT PAS, ET UNE TROISIÈME QUI A ARRÊTÉ LE RUN

`CLAUDE.md`, CH46 : deux passes qui **ne se recouvrent pas** sont la
preuve que les deux moitiés sont réellement couvertes ; une seule passe
qui rougit tout ne distingue rien.

| passe | ce qui est neutralisé | rouges | ce qui reste VERT |
|---|---|---|---|
| **A** | le fil du `rush` dans `HubCamera._ride_advance` | **6**, toutes dans PHASE W, toutes sur la réponse à la vitesse | **toute** PHASE H (dont « THE CAMERA CLIMBED, 0,862 u ») et **toute** PHASE A |
| **B** | le fondu de l'ombre dans `SkateShadow` | **2**, toutes dans PHASE H | **toute** PHASE C, **toute** PHASE W, **toute** PHASE A |
| **C** | `SkateFeel.rush()` → `return 0.0` | **8**, toutes dans PHASE C, dont les cinq blind checks « MOVES » | *le run s'ARRÊTE* — le garde d'instrument refuse d'imprimer une seule mesure en dessous |

Les trois fichiers restaurés et vérifiés **byte-identiques** par `cmp`.

La passe A est celle qui compte : elle prouve que **le suivi de hauteur
de la caméra et sa réponse à la vitesse sont deux câbles distincts**, ce
qu'aucune relecture ne pouvait montrer.

## Section 7 — RÉGRESSIONS, TRAVERSÉES, ET LA TABLE CROISÉE

`HubCamera` est un **mode partagé**, donc `CLAUDE.md` exige de rejouer la
table des sondes existantes sur les DEUX arbres — la branche et une
référence `origin/staging` importée à part — et pas sur la branche seule.
Le tableau est dans le rapport du lot.

Ce qui n'a **pas** été touché : la loi de mouvement CH61 (constantes
comprises), les colliders (aucun de neuf, le bol reste sans), le score du
lot 2, `KeepyHopper` hors `ON_CARRIER`, `HubSurface` (D1), le semis
`CozyScatter`, et le chemin d'activation de CH59 — le bouton
`Physique (dev)` reste le seul, aucune URL, aucun query param.
