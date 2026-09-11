# CH74 — Grimper aux arbres uniquement au tap sur l'apex

## Le lot

`tree_hit()` ne teste plus le disque au sol ni la capsule de tronc : seule
une sphère centrée sur le sommet (`top`) du kind, rayon `CLIMB_APEX_R`
(0,6, valeur de goût), répond désormais. `accepts_tap()` et
`is_on_occupied()` restent intacts — la mécanique de secousse d'un arbre
déjà occupé est une dette séparée, hors scope ici.

`HubTrees.apex_of()` est ajouté comme fait **publié** (patron
`position_of` / `seat_height`) pour que `V4ClimbProbe` puisse viser le vrai
point de gate sans redupliquer le calcul interne de `tree_hit`.

`V4ClimbProbe` : un tir sur le tronc et sur le centre de couronne doivent
désormais rendre un MISS (c'est le constat que ce lot vérifie), un tir sur
l'apex précis un HIT. `_ray_segment()` (l'ancienne capsule de tronc) est
retirée, plus aucun appelant après suppression de son test.

`footprints()` vérifiée neutre : elle relit `TREES`/`FOOTPRINT`, jamais
`crown`/`top` — donc ce lot ne touche à aucune empreinte au sol déjà
publiée ailleurs.

Fichiers touchés : `scripts/hub/HubTrees.gd`, `scripts/hub/HubTapInput.gd`,
`scripts/dev/V4ClimbProbe.gd`.

## ⚠️ Dette préexistante, non imputable à ce lot — tracée, pas corrigée

`V4ClimbProbe._print_list()` fait tourner sa batterie de tirs sur l'arbre
d'index **5** (`var i: int = 5`), caméra synthétique posée à
`at + (0 ; 7,6 ; 8,9)` — le même offset que `HubCamera.OFFSET`. Deux
assertions de cette batterie, `ray_apex_hits_tree` et
`occupied_answers_when_included`, sont rouges **des deux côtés de ce
lot** : sur `main`/`staging` tel qu'il était avant ce merge, et sur la
branche `claude/kippy-tree-apex-climb-m1nea2` après. La parité a été
établie en amont de ce merge (chiffres du rapport transmis pour ce lot) :
le tir censé toucher l'apex de l'arbre 5 rend un `hit` sur l'arbre **11**
au lieu de 5, aux deux extrémités de la comparaison.

**Root cause identifiée : occlusion caméra synthétique entre les arbres 5
et 11.** La caméra synthétique de la batterie de test est positionnée à
l'offset `HubCamera.OFFSET` au-dessus de l'arbre 5 lui-même — donc à une
hauteur et un recul fixes, indépendants du layout réel du hub. `tree_hit`
parcourt l'ensemble des arbres candidats pour un rayon donné et rend
l'index du premier arbre touché ; si l'arbre 11 se trouve sur la ligne de
mire construite par ce montage synthétique (entre la caméra posée et
l'apex visé de l'arbre 5), `tree_hit` répond 11 au lieu de 5 — un
comportement cohérent avec ce que `tree_hit` a toujours fait (répondre au
premier arbre sur le rayon), et pas un défaut introduit par ce lot, qui ne
touche ni au positionnement des arbres ni à l'algorithme de parcours de
`tree_hit`, seulement à la forme du volume de test par arbre (sphère
d'apex au lieu de disque + capsule).

Cette doctrine ne réutilise aucune règle déjà écrite dans `CLAUDE.md`
telle quelle : c'est un montage de sonde (caméra synthétique dérivée d'une
position d'arbre, jamais de la vraie caméra du hub) qui ne modélise pas
l'occlusion réelle entre arbres voisins du layout. C'est un problème de
**sonde**, pas de **jeu** — rien n'indique qu'un vrai joueur, sous la vraie
`HubCamera`, tape sur l'apex de l'arbre 5 et grimpe à l'arbre 11 à la
place.

**Ce lot ne tente PAS de corriger cette occlusion** — c'est explicitement
hors scope de la tâche qui a produit ce fichier. Elle reste ouverte comme
dette de sonde, à reprendre par un futur lot qui devra soit reposer la
caméra synthétique de `_print_list()` sur la vraie `HubCamera` (position et
orientation réellement utilisées en jeu, pas un offset recalculé depuis la
position de l'arbre testé), soit choisir un arbre de test dont la ligne de
mire ne croise aucun voisin.

## Déploiement

Palier 1 (feature → `staging`) : merge fast-forward de
`claude/kippy-tree-apex-climb-m1nea2` sur `staging`, gate technique
uniquement (build + export), aucune autorisation humaine requise par
doctrine. `staging` restait, avant ce merge, à l'identique de `main`
(même arbre) — le merge fast-forward n'a rejoué aucune divergence.

`web-build.yml` déclenché par le push sur `staging` ; résultat du run
consigné dans le rapport de ce lot.
