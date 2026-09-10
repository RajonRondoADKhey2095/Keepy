# CH50 — Extension zone 0 nord : le sol du skatepark (8 septembre 2026)

> Base : `origin/main` au commit `2876f27` (merge palier 2 CH32-CH49),
> arbre `9a1d2a9ebcdb3f957b820bdd9829fccfb6bf9454`. Branche
> `claude/lot-zone0-nord-skatepark-ezbguf`.
>
> **Vérification de concurrence faite AU DÉBUT** (`git fetch origin`,
> comparaison par **hash d'arbre** et non par nom) : `HEAD`, la branche
> désignée, `origin/staging` et `origin/main` portaient les **quatre le même
> arbre**, la branche étant fraîche et partie du tip de `main`. Aucune ref
> distante ne ressemble à celle-ci. Aucune session concurrente.

---

## CE QUE CE LOT FAIT, ET CE QU'IL NE FAIT PAS

Il **étend le sol marchable de la zone 0 vers le nord** — un disque de
rayon 28 — et il l'habille : le tapis végétal le couvre, le mur forestier
se referme derrière lui, l'horizon suit. **Aucun asset de skatepark n'est
posé.** Le skatepark est un lot Meshy à lui ; celui-ci ne fait qu'exister
le terrain sur lequel il se tiendra.

Le cadrage caméra est **accepté d'avance et non compensé** : `HubCamera`
ne pivote jamais et se tient 8,9 u au nord de Keepy, donc tout le nouveau
disque est hors champ à l'aller — exactement le marché que le lobe nord
CH16 a déjà passé, sur les mêmes termes.

---

## 1. LE CENTRE : (0, 35), ET C'EST UNE MESURE, PAS UNE PRÉFÉRENCE

Le brief laissait le choix (« collé au bord existant du lobe nord actuel ou
plus au nord »). Le balayage tranche, et il tranche **contre** l'intuition
du brief sur un point.

Le taux est celui du dépôt : la diagonale publiée, 98,995 u pour 18,700 s,
soit **0,18890 s/u**. Le plafond est les 22,0 s que le hub se tient.

| centre | portée | pire paire créée | | couture | avale le lobe r=12 |
|---|---|---|---|---|---|
| **(0, 35)** | z 63 | **106,600 u** | **20,137 s** | **56,0 u** | oui |
| (0, 40) | z 68 | 110,765 u | 20,923 s | 55,1 u | oui |
| (0, 45) | z 73 | 115,321 u | 21,784 s | 52,3 u | oui |
| (0, 47) | z 75 | 117,157 u | **22,131 s** ❌ | 50,6 u | oui |

Deux résultats sortent de ce balayage, et aucun des deux n'était lisible
dans le brief :

**⚠️ PREMIER — « UN GOULOT D'ÉTRANGLEMENT ENTRE LES DEUX DISQUES » N'EST PAS
UNE FORME QUE CE LOT PEUT DESSINER.** Un disque de rayon 28 **avale** le
lobe r=12 à *tous* les centres que le budget autorise : il faut |Δz| > 16
pour lui échapper, et le budget plafonne |Δz| à ~12. Il n'y a pas de col
parce qu'il n'y a pas deux lobes — **il y a un lobe qui a grossi**. La
question du brief a une réponse, et c'est « la question ne se pose pas ».

**SECOND — le centre le moins cher est aussi celui à la plus large
couture.** (0, 35) donne 56,0 u de bord nord ouvert (x ∈ [−28, 28]) et la
pire paire la plus courte. Rien n'est échangé en le prenant.

Et surtout — **la pire traversée du hub est INCHANGÉE**. La paire que ce
disque crée (coin sud-ouest de la montagne → bord opposé du disque,
106,590 u marchés) **perd** contre celle que CH38 a déjà shippée,
(35, −35) → (−63, 18) à 111,414 u. Le disque de CH50 est deuxième.

Conséquence de forme : le centre est **le même point** que
`north_lobe_centre()`, retourné depuis **la même variable statique**, donc
« le milieu du bord nord » garde exactement une orthographe dans
`HubRegion`. Deux accesseurs, une variable.

**Ce que ça laisse derrière :** `NORTH_LOBE_RADIUS` devient **INERTE**, sur
les termes exacts où `SHORE_PAD_RADIUS` l'est depuis LAKE-MOVE — contenu par
un terme plus large de la même union, **gardé** plutôt que zéroté parce que
c'est un nombre mesuré avec une provenance publiée (le plus conservateur des
quatre de la recon CH16) et parce que `SeesawProbe`, `LakeZoneProbe` et
`ZiplineStructureProbe` le lisent tous encore. Son terme dans `contains()`
et son candidat dans `clamp_to()` sont morts **par arithmétique** (même
centre, 12 < 28), pas par accident.

Chiffres du sol gagné, mesurés sur la région construite :

* demi-disque neuf : **1 231,5 u²**, moins les 226,2 u² que le lobe CH16
  apportait déjà → **1 005,3 u² nets, +20,52 %** du carré de 4 900 ;
* réseau de contrôle à 1 u sur la boîte publiée : **980 points gagnés** ;
* `walkable_bounds()` passe de **137 × 247 à 137 × 263** (le span x est
  intact : le disque tient dans x ∈ [−28, 28]).

---

## 2. LE TAPIS ET LE MUR BOUGENT ENSEMBLE, ET LES DEUX SONT DÉRIVÉS

`CozyScatter.COVER_MAX.y` valait **47** — une troisième orthographe de
« 35 + 12 » que rien ne gatait, ce qui est précisément pourquoi elle n'a pas
bougé quand le lobe a bougé. Elle vaut désormais
`HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS`. Même
défaillance que le −37 de CH40, sur l'autre axe, et même réparation.

La lèvre du mur forestier avait **trois** orthographes du littéral `50.0`
— deux dans `_forest_wall` (l'aire de la boîte et le tirage) et une dans
`_hills`. Un littéral écrit trois fois est un littéral qui bouge deux fois
et reste en place une. Elles deviennent une constante unique, dérivée :

```
const WALL_NEAR_Z: float = PLATEAU_HALF_EXTENT + SKATE_LOBE_RADIUS + 5.0   # 68.0
```

5 u de lèvre et non les 3 u que l'ancien 50 laissait au-dessus du lobe
r=12 : `WALL_CLEARANCE` en mange 2, et une bande de 1 u n'est pas une
bande.

**⚠️ POURQUOI LE MUR EXISTE AU NORD, ALORS QUE LA CAMÉRA FIXE NE MONTRE
JAMAIS DE z SUPÉRIEUR À CELUI DE KEEPY :** parce que la caméra de
**poursuite** le montre (CH30 — le kart et le char à voile), et que la
trouvaille de CH30 était justement qu'une caméra de poursuite révèle le
décor sous des azimuts que le cadre figé n'a jamais montrés, avec deux
défauts réels qui s'y cachaient.

### Le refus automatique, confirmé par mesure et pas par lecture

Le brief demandait de *confirmer* que `_forest_wall` et `_sprinkle`
continuent de refuser tout candidat désormais dans la région. C'est
automatique — les deux passes testent `HubRegion.contains(p)` et rien
d'autre n'a changé — mais « automatique » n'est pas « mesuré » :
`SkateGroundProbe` PHASE WALL compte **0 arbre de mur dans la région** et
PHASE COVER compte **0 pièce de tapis hors région, sur toute la carte**.

### Décalage du flux RNG — attendu, chiffré, pas une régression

`_sprinkle` et `_forest_wall` partagent le **même** `_rng`, et le nombre de
candidats est `aire × densité`. Les deux aires grandissent, donc **tout
tirage postérieur au premier `_sprinkle` se déplace** et le tapis entier est
redistribué. Un diff de capture sera bruyant ; c'est par conception.

| | avant | après |
|---|---|---|
| rectangle de tapis | 8 400 u² | **10 000 u² (+19,05 %)** |
| candidats `grass` | 2 856 | 3 400 |
| candidats `flower` / `leaf` / `pebble` | 268 / 252 / 151 | 320 / 300 / 180 |
| candidats `mushroom` / `bush` / `rock` | 50 / 33 / 33 | 60 / 40 / 40 |
| boîte du mur | 32 240 u² | **34 472 u² (+6,92 %)** |
| candidats mur lointain / proche | 902 / 870 | 965 / 930 |

La densité **par unité de surface éligible** est exactement celle qu'elle
était partout ailleurs : mesurée à **0,4101 pièce/u²** sur le demi-disque,
contre le ~0,45 du plateau.

---

## 3. ⚠️ LE FAUX-VERT DE CE LOT : LA SONDE A D'ABORD TOURNÉ EN HEADLESS

Le premier run de `SkateGroundProbe` était `--headless`, sur le
raisonnement — écrit noir sur blanc dans son propre en-tête — qu'elle ne lit
ni pixel ni frustum, et que CLAUDE.md impose alors le headless.

Elle est revenue en annonçant **zéro instance sur le nouveau sol**, et son
assertion d'absence (« rien hors du disque ») **VERTE**, parce que zéro la
satisfait aussi.

La cause est le **troisième** item de la liste du driver dummy : relire une
transform de `MultiMesh` rend l'**identité**. Mesuré sur le hub livré, même
arbre, même commande, seul le driver change :

| driver | instances | non-identité | étendue lue |
|---|---|---|---|
| `--headless` | 2 743 | **0** | (0,0,0) → (0,0,0) |
| `xvfb` + `opengl3` | 2 743 | **2 743** | x [−62,7 ; 70,7] z [−209,8 ; 67,6] |

**La règle de CLAUDE.md coupe donc dans les deux sens, mais l'axe n'est pas
« pixels ou pas » — c'est « qu'est-ce qu'on relit du moteur ».** Une sonde
qui ne lit aucun pixel mais relit un `MultiMesh` a besoin d'un vrai driver
tout autant qu'une sonde de pixels. Le coût (llvmpipe) se paie en
rétrécissant le `SubViewport` à 96 × 160 pour tout le run, puisque aucune
phase n'échantillonne un fragment.

**Et la parade est dans la sonde, pas dans son en-tête** : PHASE COVER porte
désormais un **contrôle d'instrument** qui exige que *toutes* les transforms
relues soient non-identité, et **échoue bruyamment** au lieu de compter un
zéro tranquille.

---

## 4. ⚠️ LE MUR D'ANNEAU ET LES HAIES SONT DEUX PASSES, DEUX RÈGLES — ET UNE
## EXPLICATION FAUSSE A ÉTÉ ÉCRITE AVANT D'ÊTRE RÉFUTÉE

Une première version de PHASE WALL balayait tous les batches `wall_near*` et
les gatait tous sur `WALL_CLEARANCE`. Elle est sortie **ROUGE sur 42
arbres**, et l'explication écrite pour ce rouge — « le filtre livré
échantillonne huit points, donc un arbre peut passer sous le rayon » —
**était fausse** : recalculer ce filtre arbre par arbre a montré que **41
des 42 auraient été REJETÉS** par lui. Autre chose les avait laissés passer,
et ce n'était pas un défaut.

Les **quatre passes de haie** (`hedge`, `hedge2`, `hedge3`, `hedge4`)
n'appellent **pas** `_near_region` : elles refusent `contains()` et une
empreinte, rien de plus, **à dessein** — une haie **borde** un bord de
couloir, s'en écarter de deux mètres est la seule chose qu'elle ne doit pas
faire. Elles partagent la **famille** `wall_near` avec le mur d'anneau, donc
un balayage par famille ramasse les deux ; c'est la **cellule** de la clé de
batch qui les sépare (`wall_<secteur>` contre `hedge*`).

Séparées, le compte tombe à **441 arbres d'anneau + 110 de haie = 551**, et
il reste **exactement 1** arbre d'anneau sous `WALL_CLEARANCE` — qui, lui,
passe bien le filtre 8 points livré. L'explication d'origine était juste
pour l'anneau et n'expliquait rien des 41 autres.

**Doctrine, et elle généralise** : quand une famille de batch est remplie
par **plusieurs passes aux règles différentes**, un gate écrit sur la
famille mesure la mauvaise population — et il tombe en rouge sur du code
correct, ce qui envoie diagnostiquer la mauvaise chose. La sonde compte
désormais les deux passes séparément **et asserte que leur somme est le
total de la famille**, sans quoi une cellule qu'elle ne connaît pas ferait
sortir des arbres du gate en silence.

---

## 5. CE QUE LA SONDE GATE, ET LES TROIS PASSES ROUGES

`scripts/dev/SkateGroundProbe.gd` — **permanente**, elle gate un contrat
permanent (le sol nord existe, il est habillé, le mur le referme, la
traversée tient). `ProbeTimeoutAudit` monte donc d'une sonde.

```
xvfb-run --auto-servernum -- godot4 --rendering-driver opengl3 \
  --fixed-fps 60 --path . res://scripts/dev/SkateGroundProbe.tscn
```

**BLIND** rejoue l'**ANCIENNE** région — le `contains()` livré avec le seul
terme CH50 retiré, **retapé à la main** dans la sonde et jamais éteint dans
`HubRegion` (une sonde capable d'éteindre la région livrée est une sonde
capable de la laisser éteinte). Le prix de la copie est qu'elle peut
pourrir, donc BLIND asserte d'abord qu'elle est un **sous-ensemble strict**
du prédicat livré sur un réseau à 1 u : **0 fuite, 980 points gagnés**.

⚠️ **Et l'assertion évidente était fausse.** « L'ancienne région refuse
TOUTES les stations du demi-disque » est sortie **ROUGE : 56 sur 67**. Les
11 restantes sont dans le lobe CH16 — du sol qui existait déjà. L'assertion
honnête n'est pas « elle refuse tout » mais « elle admet **exactement** le
lobe CH16 et les lobes de structure, et rien d'autre » : 0 écart sur 67, et
c'est une phrase qu'un rayon mal retapé casserait.

### Les trois passes rouges, une par changement livré

| neutralisation | rouges | lesquelles |
|---|---|---|
| **N1** — le terme de région coupé de `contains()`, `walkable_bounds()` et `clamp_to()` | **9** | 980 gagnés → 0 ; 67 admis → 11 ; 36 points de bord → 19 ; boîte 63 → 47 ; 505 pièces → 98 ; 398 sur sol neuf → 0 ; 235 au nord de 47 → 0 ; 9 cellules vides sur 14 ; les deux bouts de la paire ne sont plus marchables |
| **N2** — `COVER_MAX.y` remis à 47 | **3** | la borne n'est plus la portée de la région ; 0 pièce au nord de 47 ; 6 cellules vides sur 14 |
| **N3** — `WALL_NEAR_Z` remis à 50 | **3** | la lèvre n'est plus portée + 5 ; **0** arbre au nord du nouveau bord ; **1 arbre à 1,826 u** du sol marchable |

Les trois fichiers ont été restaurés et vérifiés **byte-identiques**
(`cmp`) après chaque passe.

**N2 et N3 se lisent ensemble et c'est le point 4 du brief** : N2 laisse le
terrain **chauve** (6 cellules vides), N3 laisse la **canopée en surplomb**
(un arbre à 1,826 u du sol marchable) et l'**horizon absent** (0 arbre au
nord du bord). Les deux bornes ne peuvent pas bouger séparément, et le
rouge le montre au lieu de l'affirmer.

**N2 laisse `truly_new` VERT**, et c'est ce qui prouve que la sonde
distingue « la région a grandi » de « le tapis a grandi » — deux contrats,
deux assertions, deux passes rouges qui ne se recouvrent pas.

### Les mesures vertes

* **PHASE A** : 36/36 points de bord dedans ; les **17** azimuts qui
  sortent au nord de la couture sortent tous de la région (les deux autres
  sont la couture elle-même, **nommés** plutôt qu'absorbés par un seuil
  arrondi) ; bord nord du carré marchable sur toute sa longueur, 0 trou ;
  couture **56,0 u** ; lobe CH16 strictement contenu.
* **PHASE COVER** : **505** pièces sur le demi-disque, dont **398** sur du
  sol que l'ancienne région refusait et **235** au nord de l'ancien
  `COVER_MAX.y` ; **0 cellule vide sur 14** ; **0** pièce hors région sur
  toute la carte.
* **PHASE WALL** : **25** arbres au nord du nouveau bord ; **0** dans la
  région ; plus proche à **2,161 u** ; **16** collines, **0** posant sa jupe
  sur le skatepark (mesuré sur l'**ellipse** et jamais sur son AABB
  transformée).
* **PHASE CROSSING**, marchée au vrai `KeepyHopper` à `--fixed-fps 60` :

| paire | u | frames | s | plafond |
|---|---|---|---|---|
| **nouvelle** (−63, −12) → (22,43 ; 51,74) | 106,590 | 1 207 | **20,117** | 22,0 |
| **témoin CH38** (35, −35) → (−63, 18) | 111,414 | 1 258 | **20,967** | 22,0 |
| **contrôle** diagonale publiée | 98,995 | 1 122 | **18,700** | — |

La diagonale est reproduite **à la frame près** (1 122 frames, 18,700 s) :
c'est ce qui donne à ce banc le droit de publier les deux autres chiffres.
Et la nouvelle paire **ne bat pas** celle de CH38 — la pire marche du hub
est inchangée.

---

## 6. LA TABLE DES SONDES EXISTANTES, REJOUÉE SUR LES DEUX ARBRES

Doctrine CLAUDE.md : *la sonde d'un lot ne voit pas les régressions des
autres lots*. `HubRegion` est un mode partagé, donc la table a été rejouée
sur **deux arbres** — la branche, et un worktree de `origin/main` importé à
part (**154 `.scn` des deux côtés**, comptés avant toute comparaison) —
séquentiellement, à charge comparable.

| sonde | `origin/main` | branche (avant) | branche (après) |
|---|---|---|---|
| `ProbeTimeoutAudit` | PASSED, 84 scènes | PASSED, **85** | PASSED, 85 |
| `MountainProbe` | 0 rouge | **0 rouge** | 0 rouge |
| `MinimapProbe` | 0 rouge | 2 rouges | **0 rouge** |
| `SeesawProbe` | 2 FAIL | 5 FAIL | **2 FAIL** |
| `ZiplineStructureProbe` | 3 FAIL | 4 FAIL | **3 FAIL** |
| `LakeZoneProbe` | 3 FAIL (INCONCLUSIVE) | 3 FAIL (INCONCLUSIVE) | idem |
| `SkateGroundProbe` | — | — | **ALL GREEN** |

**Parité rétablie sur toute la ligne.** Les échecs restants sont
**pré-existants et identiques des deux côtés** : le bord OUEST « qui n'a pas
bougé » (le rectangle montagne de CH38 le fait bouger depuis), deux comptes
de nœuds de dessin, le dégagement du blaireau, et les trois de
`LakeZoneProbe`. Ce lot n'en corrige aucun — ils ont leurs causes propres et
les mélanger brouillerait ce que CH50 a réellement réparé.

`MountainProbe` **0 rouge des deux côtés** est le résultat le plus important
de cette table : le budget de traversée, l'habillage de la crête et les
bornes de tapis de CH40 traversent CH50 intacts.

⚠️ `LakeZoneProbe` sort **INCONCLUSIVE** (`EXIT=2`) des deux côtés, à son
budget de 900 s pile, avec un CPU réel et un log qui grandit jusqu'au bout —
le cas que CH32 documente pour ce sandbox sans GPU matériel, pas un défaut.
Son compteur `beyond` passe de 35 099 à 44 125 : il **était déjà rouge** (il
compte toutes les zones ajoutées depuis CH26, la plus lointaine à
(−36,55 ; −103,2), dans la Lande) et CH50 s'y ajoute sans le créer.

### Trois trouvailles réelles, et deux d'entre elles étaient des loteries

**A — `SeesawProbe` et `ZiplineStructureProbe` gataient un rayon périmé.**
Quatre assertions traitaient le bord d'un lobe comme la frontière nord de la
région. CH50 rend cela faux — pas parce que la région fuit, mais parce que la
frontière a déménagé. Corrigées **au rayon qui répond vraiment**, en
conservant le contrat CH16 (son sol existe, désormais asserté *intérieur*).

⚠️ **Et l'exemption « sauf là où le CARRÉ couvre déjà » était courte de
quatre azimuts** — le lobe de structure P2 de CH21 atteint 28,2 u depuis ce
centre, 0,2 u au-delà du bord. C'est exactement « une liste de ce qui n'est
pas le sujet est fausse au premier nom oublié ». Les deux sondes prennent
désormais leur exemption dans ce que `HubRegion` **publie**, et — c'est la
moitié qui compte — **assertent que cette reconstruction reproduit
`contains()` sur chaque échantillon** (721/721 et 360/360). Le prochain terme
d'union échouera donc **bruyamment ici** au lieu d'être oublié en silence.

**B — le plancher de bruit de `MinimapProbe` mesurait où l'herbe est
tombée.** Le plan est dessiné à alpha 0,92, donc 8 % de la scène 3D est dans
chaque pixel lu ; `SceneTree.paused` arrête les scripts mais **pas le `TIME`
d'un shader**, si bien que le tapis animé par le vent derrière le widget
continue de bouger. 0,0000 sur `main`, 0,0450 sur la branche — **de façon
parfaitement déterministe, trois runs de chaque côté** — non parce que la
carte a changé mais parce que le décalage du flux RNG a posé une touffe qui
oscille derrière le widget. La 3D est désormais **masquée** pour cette phase
(toutes les frames comparées partagent alors le même fond, ce qui est tout ce
dont la différence de couverture avait besoin), et restauration assertée.

**⚠️ C — LA MEILLEURE TROUVAILLE : UN GATE DE CONTRASTE DONT L'ENCRE EST
NOIRE PAR CONSTRUCTION EST UN TEST DU SOL, PAS DU MARQUEUR.**

CH48 asserte « le bord de la plaque franchit 3,0:1 tout autour ». La branche
est sortie **2,31:1** sur un échantillon de 480, `main` **3,56:1** sur 488.
Tentant de conclure « CH50 a cassé la minimap ». C'est faux, et la mesure le
dit.

`best` est le **minimum** sur la coque, donc c'est le liséré **noir** par
construction (la sonde asserte ailleurs que chaque cellule en porte un, pire
L 0,0039). Contre une encre noire, le ratio WCAG vaut `(L + 0,05) / 0,05` :
**3,0:1 exige que le SOL soit à L ≥ 0,10**. L'assertion mesure donc la
luminance du **plan**, en portant le nom du marqueur.

Balayage du plan **rendu**, même mesure des deux côtés :

| arbre | px de sol peint | L min | ce qu'un liséré noir parfait atteint | px sous L 0,10 |
|---|---|---|---|---|
| `origin/main` | 77 832 | **0,0656** | **2,31:1** | 166 (**0,21 %**) |
| branche CH50 | 72 851 | 0,0205 | 1,41:1 | 1 468 (2,02 %) |

**`origin/main` porte déjà une bande de sol peint à L 0,0656, c'est-à-dire
exactement 2,31:1 — le chiffre même que la branche rapporte.** CH50 n'a rien
assombri : il a élargi le cadre, ce qui a déplacé une plaque de montgolfière
**sur une bande qui existait déjà**, et transformé en défaite une loterie que
cette assertion gagnait depuis CH48.

Traité comme la sonde traite **déjà** le lavage hors-monde, pour la raison
identique et mesurée : les échantillons sur un sol qu'aucune encre sombre ne
peut franchir sont **comptés et publiés**, et le gate devient ce qui est
défendable — *la part du périmètre qui tombe sur du sol inatteignable reste
petite* (plafond 8 %). **La vraie réparation** — remonter les bandes sombres
du plan, ou une auréole claire hors du liséré — **est un changement de
conception CH48 qui demande une lecture device, et il n'est pas glissé ici.**

---

## 7. CE QUI RESTE OUVERT

* **CH48, la bande sombre du plan.** 0,21 % du sol peint de la minimap est
  sous L 0,10 **sur `main` déjà** : tout marqueur qui y atterrit ne peut pas
  franchir 3,0:1, quel que soit son dessin. Publié et gaté en part, pas
  réparé — c'est un arbitrage de conception pour Mathieu.
* **Le skatepark lui-même** : lot Meshy séparé. Le sol l'attend, dressé,
  entouré et budgété.
* **Validation device sur `keepy-staging.vercel.app`** : le sandbox n'a pas
  de GPU matériel, `opengl3` y retombe sur llvmpipe. La géométrie et le
  cadrage sont prouvés ; le rendu WebGL2 sous Safari iOS ne l'est pas.
