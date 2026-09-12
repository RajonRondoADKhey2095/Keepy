# CH82 — Le skatepark s'étend, et la planche s'accroche toute seule

> Chantier : skatepark (suite de CH51, CH53, CH54, CH57, CH58, CH60,
> CH61, CH63, CH64, CH66, CH67, CH68, CH69, CH70).
> Branche : `claude/skatepark-grind-mechanics-hu0snz`. Cible : `staging`.
> 12 septembre 2026.

Deux volets dans un seul lot, et ils ne sont pas indépendants : le sens
de parcours que le premier impose est exactement ce qui rend le second
lisible.

---

## 1. RECON BLOQUANT — ce que le parc contenait vraiment

`park_span()` **23,2008 u** (CH69 publie 23,201), `push` **16,4253**,
`brake` **11,0800** (CH70 publie les deux au chiffre près), parc
**755 tri + 16 de dalle = 771** contre un plafond de 6 000. Le banc
reproduit trois chiffres au dossier avant d'en publier un seul de neuf.

Le script réel du parc est bien `HubSkatepark.gd` + `SkateparkMesh.gd`
(vérifié, pas supposé). Cinq modules : funbox (0 ; 45,5), **rail**
(4,2 ; 48,5) lacet 0,30, deux quarterpipes, bol. Tous solides depuis
CH69.

### 1.1 ⚠️ LE SENS DE « RAMPE » EST TRANCHÉ, ET LA MESURE LE TRANCHE

Le brief demandait de trancher entre « rail » et « rampe courbe ». Le
parc ne contient **qu'un seul élément accrochable au sens classique** —
le rail, poutre de 0,12 dont le dessus est à **y = 0,680**. Les
quarterpipes sont exclus, et pas par goût : la lèvre du 2,10 se tient
**1,62 u au-dessus** de ce que la capture atteint, donc un rider ne
pourrait y être pris qu'en sortant d'un air que CH66 a chiffré à
**0,762 s de fenêtre exigée contre 0,817 s de vol**. Une fonctionnalité
atteignable dans cinq centièmes de seconde est une fonctionnalité que
personne n'a. La funbox est exclue aussi : son deck est une surface
qu'on ROULE, et une ligne le long de son arête se battrait avec la
surface trois centimètres à côté pour la même planche.

### 1.2 ⚠️ ET LA PLANCHE NE PEUT PAS ATTEINDRE LE RAIL TOUTE SEULE

Mesuré, pas déduit : `POP_SPEED` (5,0) sous `GRAVITY` (26,0) culmine à
**0,4808 u** depuis le plat. Le rail est à **0,680**, soit **0,1992 u
au-dessus** de tout ce que ce corps sait faire. Et
`SkatePhysicsProbe` PHASE J mesure depuis CH60 qu'une planche qui roule
passe **SOUS** la poutre (sa capsule culmine à 0,26 contre un dessous à
0,56) et ne rencontre jamais qu'un **PIED**.

Donc « il touche et il reste dessus » **ne peut pas** être un résultat
de collision. Ce qui est livré est une **AIMANTATION**, dite comme
telle, et deux choses l'empêchent d'être une licence — voir § 3.

### 1.3 Le sol au sud du parc est VIDE

Balayage des empreintes publiées (Transport, Trees, Cove, Skatepark,
Funfair, Karting) dans x[−16, 16] × z[22, 46] : les **seules** sont
celles de la funbox et du bol eux-mêmes. `HubSurface.height_at` rend
0,0000 partout sur la bande. Aucun prop n'a été déplacé pour faire de
la place, contrairement à CH67.

### 1.4 Le cadre, re-mesuré pour ce lot

Depuis z = 46 la demi-largeur du cadre vaut **7,00 u à z = 38** et
**8,24 u à z = 35** ; depuis z = 42, **5,34 u à z = 38**. Le contenu
posé au SUD du parc est donc du contenu DEVANT le rider, puisque la
caméra ne montre que des z inférieurs au sien. C'est ce qui décide le
sens de l'extension.

---

## 2. L'EXTENSION — trois ledges, un sens, et une dalle qui pousse d'un côté

`FLOW = (0, −1)` est publié : l'axe que l'en-tête de `HubSkatepark`
décrit depuis CH53 (« meant to be ridden SOUTHWARD », et c'est pour ça
que la planche est garée au nord) devient une VALEUR, parce qu'un lot
de layout en avait besoin comme telle.

| # | module | position | taille | haut | ligne de grind |
|---|---|---|---|---|---|
| 5 | ledge | (3,40 ; 41,60) | 0,55 × 0,30 × 5,20 | 0,30 | 5,20 u |
| 6 | ledge | (1,00 ; 38,00) | 0,55 × 0,45 × 4,40 | 0,45 | 4,40 u |
| 7 | ledge | (−1,80 ; 34,40) | 0,55 × 0,62 × 3,40 | 0,62 | 3,40 u |

* **Appendues, jamais insérées.** Six fichiers indexent `MODULES` par
  NUMÉRO (`RIDES` de SkatePhysicsProbe, `MODULES[4]` de
  PhysicsCostProbe, les deux lèvres de SkateInertiaProbe, la funbox de
  SkateDismountProbe, les deux rampes de SkateAirProbe). Les cinq
  premiers indices ne bougent pas.
* **Toutes à lacet 0,0**, donc l'axe long sur Z, donc sur `FLOW` :
  mesuré **0,0000 deg d'écart** pour les trois. Le rail garde ses
  0,30 rad — **17,19 deg mesurés**, à l'intérieur des 40 deg que la
  capture tolère, donc il grinde depuis une descente droite comme les
  trois autres. Le tourner coûterait de déplacer un module contre
  lequel trois chantiers ont mesuré des stations, pour acheter un
  alignement dont la capture n'a pas besoin.
* **La première est posée SUR LA LIGNE DU RAIL, exprès.** Le rail finit
  à (3,313 ; 45,634) et sa ligne prolongée au sud passe x = 3,30 à
  z = 45 ; une ledge à x = 3,4 est donc là où un rider qui vient de
  grinder le rail vers le sud ARRIVE. Mesuré en jeu : sortie du rail à
  z 44,20, reprise par la ledge 4 ticks plus tard à z 44,69. **Le parc
  s'enchaîne.**
* **Hauteurs 0,30 / 0,45 / 0,62** : un curb, une ledge, un bloc. La
  plus haute est la hauteur *authored* du rail, donc les lignes du parc
  couvrent la bande accessible au lieu de s'y grouper.
* **`tap_radius` 1,8 et non 2,4** : deux disques de score qui se
  recouvrent font une bande de sol où QUEL module on a scoré est un
  accident d'un centimètre (septième contrainte de CH69, gatée par
  `SkateparkProbe` G5). La paire la plus serrée — cette première ledge
  contre la funbox — reste à **0,46 u**.
* **Géométrie** : une boîte solide (12 tri, **une** pièce convexe) plus
  deux cornières d'acier COPING en surface 1 (24 tri, solides à rien) —
  l'idiome de la funbox, argument pour argument. **36 triangles pièce**,
  **+108 pour le parc**, qui passe de 771 à **879** sur un plafond de
  6 000. Le dessus pâle n'est pas une décoration : le parc est unlit et
  rien ne post-traite la frame, donc une boîte grise sur du béton gris
  n'a **aucun** indice de « ça se grinde ».
* **La dalle pousse d'un seul côté** : `SLAB_MIN.y` 41,0 → **32,0**.
  C'est exactement ce pour quoi CH69 avait transformé la dalle d'une
  taille centrée en ses deux COINS. Le béton du module le plus au sud
  s'arrête à z 32,70, donc la bordure le dégage de **0,70 u**.

### 2.1 ⚠️ CE QUE L'EXTENSION COÛTE, MESURÉ AUX DEUX BOUTS

C'est la règle CH69 (« un lot de LAYOUT publie ce que ses déplacements
font aux constantes dérivées ») appliquée à elle-même :

| grandeur | avant | après |
|---|---|---|
| `park_span()` | 23,2008 u | **26,8461 u** (+15,7 %) |
| `skate_coast_u()` | 23,2008 | **26,8461** |
| `drag_k` | 0,029876 | **0,025819** |
| `roll_stop` | 0,9959 | **0,8606** |
| `push` | 16,4253 | **16,0519** |
| `brake` | 11,0800 | **11,4324** |
| parc (tri) | 755 + 16 | **863 + 16** |

Les DISTANCES *authored* (run-up 3,20, run-out 3,20) ne bougent pas —
c'est le solveur de `configure()` qui absorbe le changement, et c'est
précisément pourquoi `park_span` est dérivé. Ce qui bouge est la roue
libre : une planche lâchée à la croisière s'arrête maintenant dans
26,8 u au lieu de 23,2, c'est-à-dire **toujours à l'intérieur du parc
où on l'a poussée**, qui est le contrat de CH61. **C'est un changement
de TOUCHER et il se valide sur device.**

### 2.2 ⚠️ ET LE TAPIS EST REBATTU, DIT PLUTÔT QUE CACHÉ

`HubSkatepark.footprints()` est consommé dans `CozyScatter._blocked()`,
donc AVANT les tirages : un candidat rejeté saute ses deux `randf` et
décale le flux pour tous les suivants (CH53). Mesuré hub-wide :

| famille | avant | après |
|---|---|---|
| grass | 1 005 | 960 |
| bush | 17 | **5** |
| flower | 109 | 100 |
| rock | 10 | 16 |
| instances | 2 689 | **2 602** |
| batches | 337 | 338 |

CH71 a montré comment l'éviter (tester l'empreinte APRÈS les tirages).
**Refusé ici, et la raison est écrite** : l'échapper demanderait de
publier la dalle d'AVANT comme un littéral gelé à côté de la dalle
vivante, c'est-à-dire de fabriquer la seconde orthographe périmée que
tout ce dépôt paie le plus cher. Le tapis est donc rebattu une fois, et
mesuré. C'est aussi ce que CH78 a assumé pour la même raison.

---

## 3. LA MÉCANIQUE — ce qui s'accroche, et ce qui s'en détache

Le contrat de Mathieu, mot pour mot : « quand Keepy touche un élément de
grind, il s'accroche AUTOMATIQUEMENT dessus et glisse le long, sans
action du joueur pour déclencher l'accrochage ». Pas de geste, pas de
bouton, pas de fenêtre à viser — et c'est la raison pour laquelle rien
de ce qui suit n'est un trick : un mécanisme qui ne demande rien ne peut
pas perdre la course que CH66 a mesurée.

### 3.1 Où vit quoi

```
SkateparkMesh.rail_grind_line() / ledge_grind_line()   la ligne, en LOCAL
  -> HubSkatepark.grind_line_local(spec)               une branche PAR KIND
    -> HubSkatepark.grind_edges()                      en MONDE, lu sur les NOEUDS BÂTIS
      -> HubWorld._setup_skatepark()                   UNE ligne de câblage
        -> SkateBoardBody.set_grind_edges()            la planche ne connaît que des segments
```

La planche ne sait pas qu'un parc existe ; le parc ne sait pas qu'une
planche existe. Et `grind_line_local` a **une branche par kind, y
compris pour les trois qui répondent « nulle part »** — la forme CH76 :
un cinquième kind reçoit un `push_error`, pas la géométrie d'un rail.

### 3.2 Les constantes, et laquelle est un goût

| constante | valeur | d'où elle vient |
|---|---|---|
| `GRIND_MOUNT_S` | 0,1923 s | `POP_SPEED / GRAVITY` — le temps que l'ollie de la planche met à culminer |
| `GRIND_CATCH_DROP` | **0,9615 u** | `POP_SPEED × GRIND_MOUNT_S` — donc la montée ne peut **jamais** dépasser `POP_SPEED` |
| `GRIND_CATCH_RISE` | 0,26 | une largeur de deck |
| `GRIND_CATCH_R` | 0,46 | une demi-longueur de deck |
| `GRIND_CATCH_LEAD` | 0,92 | une longueur de deck — voir § 3.4 |
| `GRIND_MIN_SPEED` | 1,830 u/s | `sqrt(2 · DECEL · DECK_LENGTH)` — une longueur de deck de glisse |
| `GRIND_MIN_RUN` | 0,92 | une longueur de deck de ligne restante |
| `GRIND_COOLDOWN_S` | 0,2514 s | le temps de sortir du rayon de capture à la vitesse la plus lente qu'elle accepte |
| `GRIND_DECEL` | 1,8200 u/s² | `GRIND_MU (0,07) × GRAVITY` |
| `GRIND_ALIGN_COS` | 40 deg | **un goût**, borné des deux côtés par la sonde |
| `GRIND_BAIL_COS` | 75 deg | **un goût**, plus large que la capture par conception |

⚠️ **`GRIND_MU` et les deux angles sont des chiffres de RESSENTI et le
lot le dit.** Rien ne s'appuie encore dessus ; le jour où quelque chose
s'y appuiera, CH70 exige un balayage avant de les bouger.

Les deux inégalités qui bornent `GRIND_DECEL`, mesurées et gatées : une
planche entrant à la croisière glisse **27,47 u** contre une ligne la
plus longue de 6,00 u ; et le SOL prend **3,4426 u/s²** à la même
vitesse contre 1,8200 pour l'acier (ratio mesuré en course : **1,62**).

### 3.3 La vitesse d'entrée EST la vitesse d'approche

Rien n'est ajouté, rien n'est mis à l'échelle, rien n'est écrêté.
Mesuré à quatre approches, dont la quatrième est la troisième répétée
pour donner au banc son propre plancher :

| approche | entrée | nez au moment de la prise |
|---|---|---|
| pleine | **8,409930** | −0,446 u |
| capée 6,0 | **5,639482** | −0,404 u |
| capée 4,0 | **3,890409** | −0,458 u |
| capée 4,0 (répétée) | **3,890373** | −0,458 u |

**Écart 4,5195 u/s pour un plancher de banc de 0,000036** — un facteur
125 000. L'égalité entrée/approche tient à 1e-6, le premier tick de
glisse porte exactement cette vitesse moins **un** tick de la loi du
rail, et la composante verticale au moment de la prise vaut
**0,00000000**.

### 3.4 ⚠️ LA PORTÉE D'APPROCHE — mesurée, et le lot n'aurait pas marché sans

Une ledge est un BLOC : sa face d'extrémité est un mur de 0,30 à 0,62 u
contre une capsule qui culmine à 0,26. Un rider qui descend le parc la
rencontre **DE FACE**, et la première version de ce fichier ne le
prenait qu'une fois son centre à l'intérieur du segment — c'est-à-dire
après que son **NEZ**, une demi-planche devant, l'avait déjà percutée.
Le vidage tick par tick est sans ambiguïté :

```
t 44 pos (3.522, 0.0000, 37.830)  |vh| 7.978
t 48 pos (3.636, 0.0000, 38.386)  |vh| 8.832
t 52 pos (3.772, 0.0000, 38.564)  |vh| 2.032   <-- le mur
... une seconde et demie à contourner le bloc ...
t 73 pos (3.859, 0.0000, 39.767)  |vh| 5.867   <-- enfin pris
```

Automatique, et ça commençait par un crash. La capture porte donc
**une longueur de deck au-delà de chaque bout de la ligne**, et les
deux moitiés sont un terme : la demi-planche est le nez, l'autre moitié
couvre le tick de retard de la capture (une planche à la croisière
parcourt 0,167 u par tick). Après correction, même station :

```
t 46 pos (3.579, 0.0000, 38.100)  |vh| 8.410   <-- pris, nez encore à 0.446 du bloc
t 47..t57  y 0.026 -> 0.286, la vitesse décroît de 0.0303 par tick
t 58 pos (3.400, 0.3000, 39.743)  |vh| 8.046   <-- posé sur la ligne
```

**Le montage a DEUX gouverneurs et le plus petit gagne** : le temps
(`GRIND_MOUNT_S`) et la portée (la fraction du lead déjà couverte). Le
second est ce qui empêche une planche lente de se tenir à hauteur de
rail en plein vol avant que le rail ne commence ; et la borne
`POP_SPEED` survit gratuitement au second, parce que le terme de portée
ne devient le plus petit que pour une planche plus lente que
`LEAD / MOUNT_S`, et une planche plus lente monte plus lentement.
Mesuré sur le rail (le pire montage, 0,680 u depuis le plat) :
**12 ticks, pire montée 3,5360 u/s** contre un plafond de 5,00.

### 3.5 Les quatre sorties, et il n'y en a que quatre

| sortie | mesure |
|---|---|
| **le bout de la ligne** | quitte à **0,000 u** du bout, à **7,667 u/s**, 14 ticks de vol ensuite |
| **la glisse s'épuise** | entrée 2,176, **0,366 u** parcourus, lâche à 1,812 u/s |
| **le pouce se braque** | demandé au tick 20, lâché au tick **23** ; 1 seule prise dans la course (le cooldown tient) |
| **le rider descend** | `stop()` sort de la ligne et la vitesse tombe à 0 |

Le grind **n'est pas le patron ÉCHELLE** et PHASE X est ce qui le
montre : le pouce n'est jamais avalé ni réinterprété. Il dirige, et
diriger assez fort à l'écart EST la sortie.

⚠️ **ET LA SORTIE PAR LA VITESSE N'EST PAS GATÉE SUR LE MONTAGE**, ce
qui est la seule exception au montage atomique. Une première rédaction
la gardait derrière « une fois monté » ; une planche prise sur la
portée d'approche mais trop lente pour atteindre la ligne s'arrête
alors à un blend qui ne se complétera jamais, et **rien ne la lâche** —
exactement l'état bloquant que le brief demande d'éviter. Deux réponses
livrées : l'entrée exige désormais de quoi ARRIVER *et* glisser
(`v² ≥ GRIND_MIN_SPEED² + 2·DECEL·lead_restant`, dont `GRIND_MIN_SPEED`
est le cas `lead = 0`), **et** le plancher de vitesse lâche quoi qu'il
arrive, en reposant la planche sur le niveau d'où elle a été prise.

### 3.6 Ce que le lot NE fait pas, et le dit

* **Le grind ne rapporte AUCUN point.** `note_landing` n'est jamais
  appelé pendant une conduite physique (`ON_CARRIER` n'émet pas
  `hop_landed`) — c'est une dette **nommée** par CH57 et CH64, pas un
  oubli, et la payer est une question d'ÉQUILIBRE (CH51 a mesuré qu'un
  parc sans borne rapporte plus que l'exploration de tout le monde) qui
  demande son propre balayage.
* **Aucun retour sonore ni HUD.** Le retour est visuel : la planche est
  visiblement sur la ligne, alignée, en train de glisser.
* **Le comportement des rampes courbes n'est pas touché.** Aucune
  ligne de leur géométrie, de leur collider ou de leur physique n'a
  bougé, et `SkatePhysicsProbe` le confirme sur les deux arbres.

---

## 4. CE QUE LES PASSES ROUGES ONT DIT

**Quatre neutralisations à l'exécution** (PHASE R, en donnant à la
planche une AUTRE liste, jamais en éditant un fichier — vert/rouge/vert
sur un seul arbre) : hauteur `DROP+0,20` refusée / `DROP−0,10` prise ;
angle 17 deg pris / 60 deg refusé ; vitesse de pointe 1,107 refusée /
9,944 prise ; aucune ligne du tout → jamais prise, et elle roule quand
même 3,60 u. Chaque seuil est donc mesuré **des deux côtés** (CH65).

**Passe rouge source nº 1 — le test d'alignement retiré. 3 rouges pour
5 prédits, et les deux manquants sont la trouvaille.** J1 (traverser le
rail) rougit comme prévu : la planche est prise et monte à **0,6809**
au lieu de rester à 0,0000, ce qui est exactement le contrat CH60 que
ce lot devait ne pas casser. **J2 (traverser une ledge) est resté
VERT** — et pas parce que l'alignement le protégeait : le mur arrête la
planche à **0,736 u de la ligne**, donc **hors** de `GRIND_CATCH_R`
(0,460), et ce cas n'atteint jamais le test d'alignement. J1 est la
garde d'alignement de la phase ; J2 est la garde du MUR. Une assertion
d'instrument a été ajoutée pour que la seconde cesse de pouvoir se lire
comme la première (CH73 : un garde qu'une neutralisation ne fait pas
rougir n'est pas gaté — ici il l'est, mais par autre chose).

**Passe rouge source nº 2 — la portée d'approche ramenée à 0,001.
10 rouges pour 4 prédits, et les 6 extras ont UNE seule cause** : sans
elle, la planche percute la face de la ledge et **quatre courses sur
six ne sont plus accrochées du tout** (E[2], E[3], D, X1, X3, X4
perdent leur prise). Les 4 prédits sont les gardes de nez, qui passent
de −0,45 u à **+1,225 u** et **+0,446 u**. `GRIND_CATCH_LEAD` n'est donc
pas un confort : sans elle les ledges ne sont pas grindables.

Les deux fichiers ont été restaurés et vérifiés **byte-identiques**
(`cmp`) après chaque passe.

---

## 5. DEUX DÉFAUTS D'INSTRUMENT, CHACUN AVEC L'ALLURE D'UN RÉSULTAT

1. **`SkatePhysicsProbe` PHASE V ne pouvait pas juger une boîte.** Sa
   grille échantillonne l'AABB du module ; un BLOC remplit son propre
   AABB, donc les deux classificateurs ont voté « dedans » **1521 fois
   sur 1521** et la garde d'instrument a refusé de signer — correctement
   (CH40 : un accord mesuré par un test qui n'a jamais dit « dehors »
   est la liste de masquage vide). Réparé en agrandissant la boîte
   d'**exactement une CELLULE** et en montant le pas de deux, de sorte
   que la TAILLE de cellule est inchangée et que **chaque échantillon
   intérieur retombe sur le point monde qu'il a toujours occupé** :
   `(taille + 2·cellule) / (pas + 2) = cellule`. Les quatre modules déjà
   scannés gardent donc leurs verdicts à l'échantillon près (funbox
   1 079 dedans, rail 13, quarterpipes 351 et 390, bol 186) et gagnent
   une coquille d'air sur laquelle les deux classificateurs doivent
   s'accorder. Grille réelle : 15 × 11 × 15 = **2 475**.
2. **`SkatePhysicsProbe` PHASE N mesurait le grind.** Sa revendication
   est « sans rien de SOLIDE là, rien ne tient la planche ». La course
   du petit quarterpipe finit à (5 ; 50) et la ligne du rail passe
   x = 4,664 à z = 50 — **0,34 u**, dans `GRIND_CATCH_R`, alignée : la
   planche était prise par le rail et `supported` lisait **108 ticks**
   sur un module neutralisé. C'est le layout qui fonctionne, pas ce que
   la phase demande. Les lignes sont désormais retirées pour la durée
   de la phase et remises à la fin (gaté).

---

3. **`SkateInertiaProbe` PHASE E gatait un fantôme sur 27 millimètres de
   marge, et le lot l'a fait basculer.** Son test « il ne traverse pas
   un volume fantôme » comparait le PIC atteint à `lèvre + 0,60`. CH61
   avait déjà corrigé **la même revendication, dans l'autre sonde**
   (`SkatePhysicsProbe` PHASE R) en écrivant pourquoi : depuis
   l'inertie, une hauteur au-dessus d'une lèvre a une seconde cause
   parfaitement légitime — la planche est éjectée du sommet et devient
   un projectile — donc le test doit porter sur ce qu'il a toujours
   voulu dire, **que rien ne TIENT la planche au-dessus de la lèvre**.
   Cette copie-ci avait gardé le pic. Mesuré sur les deux arbres :
   `origin/staging` lit **2,023 contre un plafond de 2,050**, soit
   **27 mm** de marge sur une lecture de 2 u (1,3 %) ; le +0,10 u/s
   d'arrivée que CH82 apporte le porte à 2,192 et le gate rougit sur
   une planche qui fait exactement ce qu'un quarterpipe de 1,45 u pris
   à la vitesse fait faire. **RE-VISÉ et non élargi** (CH69 : un gate
   avec 1,3 % de marge n'est pas un gate) : la sonde enregistre
   désormais le sommet où le module TENAIT la planche, et il lit
   **1,279 contre une lèvre de 1,450** — donc le 2,192 est bien du vol
   et non un volume fantôme.
4. **Et la même phase mesurait le grind.** Elle boucle sur tous les
   modules solides, donc elle s'est mise à lancer des rampes contre des
   ledges. Les rungs 6, 8 et 10 u/s ont tous culminé à **0,681** — la
   ligne du RAIL, dans laquelle la sortie de la ledge débouche — donc
   l'écart s'est effondré à **0,622 contre 0,621** et la phase
   rapportait une réponse plate sur un mécanisme qui marchait
   exactement comme prévu. Les ledges sont **SAUTÉES avec leur raison**,
   sur le patron que le rail et le bol avaient déjà : une ledge n'a pas
   de transition à convertir, et `SkateGrindProbe` PHASE E possède la
   loi arrivée → entrée pour ces modules, qu'elle gate comme une
   ÉGALITÉ et non comme une conversion.

⚠️ **Et un cinquième piège, d'outillage pur, payé deux fois dans la
session** : `pgrep -f` et `pkill -f` **matchent leur propre shell
ancêtre** quand la ligne de commande de celui-ci porte le texte cherché.
Une boucle d'attente a survécu **1 900 s** à un travail déjà fini, et
deux commandes se sont tuées elles-mêmes (exit 144). `CLAUDE.md` le
documente déjà mot pour mot ; la parade est
`scripts/dev/wait_for_probe.sh --pid`, ou le mécanisme de tâches du
harnais, et **jamais un `while pgrep` en ligne**.

⚠️ **Et un sixième, qui a coûté 14 minutes** : la table croisée avait
d'abord été lancée en copiant les sondes MODIFIÉES dans l'arbre de
référence, pour comparer des instruments identiques. Une sonde qui
référence `HubSkatepark.KIND_LEDGE` **ne parse pas** sur un arbre qui
ne l'a pas — et `CLAUDE.md` le dit : une sonde dont le script ne parse
pas ne tombe pas vite, `ProbeWatchdog.arm()` n'est jamais atteint et le
process traîne jusqu'à son timeout **sans une seule ligne de sortie**.
La table compare donc des **VERDICTS**, chaque arbre jouant ses propres
sondes.

## 6. BUDGET

| | avant | après |
|---|---|---|
| parc, triangles (modules) | 755 | **863** (+108) |
| parc + dalle | 771 | **879** |
| plafond CH52 | 6 000 | 6 000 |

Les trois ledges coûtent **36 triangles pièce** (une boîte solide de 12,
deux cornières décor de 12 chacune). Le plafond n'est pas une cible :
chaque triangle dépensé ici se rachète sur le tapis d'herbe, et le
tapis a effectivement reculé (§ 2.2).

---

## 7. TABLE CROISÉE — deux arbres

⚠️ **Chaque arbre joue SES sondes.** La première tentative copiait les
sondes modifiées dans l'arbre de référence pour comparer des instruments
identiques ; une sonde qui référence `HubSkatepark.KIND_LEDGE` **ne
parse pas** là-bas, et `CLAUDE.md` le dit — une sonde dont le script ne
parse pas ne tombe pas vite, elle traîne **quatorze minutes** jusqu'à
son timeout sans une ligne de sortie. La table compare des **VERDICTS**.

| sonde | driver | branche | `origin/staging` |
|---|---|---|---|
| `SkateGrindProbe` (neuve) | headless | **103 / 0** | — |
| `SkatePhysicsProbe` | headless | **180 / 0** | 161 / 0 |
| `SkateInertiaProbe` | headless | **103 / 0** | 103 / 0 |
| `SkateAirProbe` | headless | **40 / 0** | 40 / 0 |
| `SkateTraverseProbe` | headless | **37 / 0** | 37 / 0 |
| `SkateTrickProbe` | headless | **54 / 0** | 54 / 0 |
| `SkateDismountProbe` | headless | **33 / 0** | 33 / 0 |
| `SkateparkProbe` | xvfb + opengl3 | **69 / 0** | 57 / 0 |
| `SkateFeelProbe` | xvfb + opengl3 | **123 / 0** | 123 / 0 |
| `SkateEdgeProbe` | xvfb + opengl3 | **11 / 0** | 11 / 0 |
| `SkateDriveProbe` | xvfb + opengl3 | **29 / 0** | 29 / 0 |
| `SkateGroundProbe` | xvfb + opengl3 | 41 / **2** | 41 / **2** |
| `SkateInputProbe` | xvfb + opengl3 | 85 / **1** | 85 / **1** |
| `PhysicsCostProbe` | headless | 7 / **1** | 9 / **1** |
| `ProbeTimeoutAudit` | headless | **PASSED, 104 sondes** | PASSED, 103 |

**Quatre rouges, tous en PARITÉ EXACTE et tous PRÉ-EXISTANTS :**

* `SkateGroundProbe` ×2 — « 1 distant hills put a skirt on the skatepark
  ground » et « the new pair (21.817 s) does NOT beat CH38's
  (20.967 s) », identiques au mot et au chiffre sur les deux arbres.
* `SkateInputProbe` ×1 — « and it did NOT stop the board », 1,736 → 0,815
  sur la branche contre 1,694 → 0,780 sur la référence (une mesure
  sensible à la charge, même verdict).
* `PhysicsCostProbe` ×1 — `I1 the bench's geometry IS the shipped park's
  geometry (468 tris)` : `PARK_TRIS_ON_FILE` vaut 468 pour un parc qui
  en porte 755 depuis CH64/CH69. Le banc s'arrête là **sur les deux
  arbres** et ne mesure donc rien nulle part. Signalé, non corrigé : le
  re-baseliner serait re-signer le chiffre d'un autre lot.

⚠️ **Et deux de ses trois rouges initiaux étaient bien de ce lot** :
`I2` et `I5` comptaient les kinds de module en littéral (`== 4`) — la
cinquième orthographe littérale du même défaut trouvée dans cette
session. Dérivées, la parité revient à 1 contre 1.

`ProbeTimeoutAudit` passe de **103 à 104** scènes de sonde : `+1`
exactement, les deux sondes jetables (`GrindRecon`, `GrindTrace`)
ayant été supprimées avant le commit.

### 7.1 Le budget, aux stations du parc

`SkateparkProbe` PHASE B, mêmes quatre stations, même banc :

| station | frame, référence | frame, branche | le parc seul |
|---|---|---|---|
| (0 ; 42) | 82 283 | **81 389** | +615 → **+723** |
| (−10 ; 51) | 89 392 | **88 674** | +605 → **+641** |
| (0 ; 51) | 85 437 | **84 402** | +755 → **+863** |
| (0 ; 63) | 85 564 | **84 439** | +755 → **+863** |

Le parc coûte **exactement +108 primitives** de plus (son delta de
triangles), et la frame entière est pourtant **plus LÉGÈRE de 700 à
1 100 primitives** à chaque station : le tapis d'herbe que la dalle
dégage paie le béton plus que son prix. Draw calls **433 → 439** (+6,
les trois ledges et leurs deux surfaces).

### 7.2 La fenêtre de trick, préservée

Le gate CH66/CH70, sur les deux arbres, pouce de référence à **0,762 s**
exigées :

| rampe | référence | branche |
|---|---|---|
| grand quarterpipe (2,10) | 0,817 s | **0,817 s** |
| petit quarterpipe (1,45) | 0,900 s | **0,917 s** |

La marge de 7 % que CH70 a refusé de dépenser est **intacte**, et
légèrement meilleure sur le petit — ce qui est le sens attendu, la
roue libre plus longue rendant une arrivée plus rapide.

---

## 8. BUILD

Export web local, `4.3-stable`, templates vérifiées contre leur
`Content-Length` (1 073 228 327) :

* `index.wasm` **35 376 909** octets, md5
  **`af4a8fc2925d992348eb30deeeb54360`** — le fingerprint d'identité que
  `CLAUDE.md` publie pour tout lot qui ne touche pas le code moteur ;
* `index.js` md5 **`4e08904b1b7107858246af44b602067b`** ;
* `index.pck` 34 846 224 octets (**non probant en taille**, CLAUDE.md :
  la passe de compression VRAM varie d'un export à l'autre) ;
* **629 fichiers packés, zéro fuite** : aucune ligne `Storing File` pour
  `res://build/`, `res://scripts/dev/`, `res://assets_source/`,
  `res://docs/`, `firebase.json` ni `vercel.json`.
