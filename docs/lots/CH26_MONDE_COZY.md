# CH26 — Le monde cozy : direction VOIE A, météo, transport, trois zones, persistance, grimper, récolte

> Chantier ouvert par le **LOT DE CADRAGE** du 5 septembre 2026, qui a
> nettoyé et promu vers `staging` le travail de **cinq sessions carte
> blanche** (v1 → v5, 4-5 septembre 2026, branches
> `claude/carte-blanche-cozy-02o8dm` puis
> `claude/carte-blanche-v5-grimper-9qlhci`).
>
> ⚠️ **Ce fichier n'est PAS le journal.** Le récit heure par heure des cinq
> nuits, avec ses mesures, ses impasses et ses captures, vit *verbatim* dans
> [`docs/CARTE_BLANCHE_JOURNAL.md`](../CARTE_BLANCHE_JOURNAL.md) et y reste.
> Ce fichier-ci est sa version **cadrée** : ce que la branche apporte, ce que
> le lot de cadrage a retiré, et ce qui reste à valider.

## Ce que le chantier apporte

Sept blocs, dans l'ordre où ils ont été construits. Chacun s'appuie sur le
précédent — c'est ce qui a rendu le rejeu de plus en plus cher, et c'est
l'argument qui a fait de la promotion vers `staging` la session suivante
plutôt qu'une sixième nuit de carte blanche.

| # | bloc | ce qui est livré |
|---|---|---|
| 1 | **Direction VOIE A** | `CozyPalette` (372 l.) et `CozyScatter` (1 116 l.) : sol, couvre-sol seedé, mur de forêt hors région en bande proche + LOD derrière, batches par cellule de 28 u pour que le frustum culling coupe des cellules entières. ~120 GLB neufs sous `assets/models/decor/`, tous générés par les scripts Blender de `docs/carte_blanche/blender/`. |
| 2 | **Météo vivante** | `CozyWeather` (120 l.) : quatre états (soleil / pluie / orage / neige), cycle automatique, `force()` / `force_auto()`. La palette est écrite en UN endroit (`CozyPalette.apply_weather()`) ; le nœud ne touche que le ciel et l'overlay 2D. L'ours va s'abriter (`BEAR_SHELTER`) quand le ciel tourne. |
| 3 | **Trois zones** | Le plateau d'origine, **le Vallon d'automne**, **la Lande aux Moulins**. Toutes à la **même altitude**, région étendue par rectangles et couloirs dans `HubRegion` — aucune falaise, aucun escalier, aucune migration multi-altitude (voir la doctrine ci-dessous). |
| 4 | **Transport** | `HubTransport` (379 l.) : deux lignes de montgolfière (« Or », « Ciel ») avec docks appairés, et le **Sautillon**, une balle sur laquelle Keepy monte. Un tap sur un dock achète toute la chaîne (marcher, appeler, attendre, embarquer). |
| 5 | **Persistance locale** | `WorldSave` (339 l.), autoload : un document JSON sous `user://`, schéma v1 stampé, un seul écrivain, sanitiseur qui accepte un fichier corrompu / futur / partiel sans jamais planter. Ressources, stock des arbres avec recharge à l'horloge murale paresseuse, fruits au sol, stats. Champs `next_id` / `placed` **réservés** sans lecteur, pour que l'identité d'un objet posé existe avant la première session de plantation. |
| 6 | **Grimper universel** | `HubTrees` (877 l.) + l'état `ON_TREE` de `KeepyHopper` : **53 arbres grimpables** (5 perchoirs + 48 arbres décoratifs adoptés depuis leurs `MultiMesh`), sans un seul nœud dessiné de plus. Tap par **rayon caméra** contre la couronne et le tronc, montée sur le **flanc de couronne**, secousse par `set_instance_transform` sur l'instance seule. |
| 7 | **Récolte** | `HubNuts` (405 l.) : ce qui tombe d'une secousse — deux fruits, des **feuilles** (feedback, jamais un compteur), une **coccinelle** qui marche et fuit le joueur, un **gland doré** dont la rareté est *cadencée* (12ᵉ secousse puis toutes les 19) et non tirée. `WorldHud` (171 l.) affiche un compteur rare **seulement quand le joueur en tient un**. |

## Ce que le lot de cadrage a RETIRÉ

La branche a été écrite pour être jetable et portait de l'échafaudage. Rien
de fonctionnel n'a été retiré ; tout ce qui suit est de l'emballage.

### Le bypass d'authentification — le point qui ne pouvait pas passer

`LoginScreen.gd` sautait l'écran de connexion Google sur tout hôte
`*.vercel.app` qui n'était ni `keepy-staging` ni `keepy-ten`, et
`Auth.gd` portait le mode invité (`_guest_mode`, `enter_guest_mode()`,
`is_guest_mode()`, `is_untrusted_preview_domain()`, `PROTECTED_HOSTS`).
`HubWorld.tscn` affichait un badge « INVITE - PREVIEW ».

**Retiré entièrement.** Le contrôle qui compte n'est pas la relecture du
retrait mais la comparaison : après nettoyage,
`git diff origin/main -- scripts/autoload/Auth.gd scripts/ui/LoginScreen.gd`
est **vide**. Le flux Google Sign-In livré est littéralement celui de `main`,
pas une reconstruction qui lui ressemble.

⚠️ **Le mode invité n'a jamais touché Firestore.** `Leaderboard.gd`,
`Quizz.gd` et `BattleStats.gd` gatent tous leurs écritures sur
`is_signed_in()` / `get_current_uid()` / `get_id_token()`, dont un invité
n'avait aucun — le bypass était un contournement d'écran, pas un
contournement d'autorisation. C'est ce qui a permis de le retirer sans
toucher à rien en aval.

### Les poignées de test dans du code livré

* **`force_ladybug_roll`** (`HubWorld.gd`) : un `float` public qu'une sonde
  écrivait pour **forcer l'issue** du tirage de la coccinelle. Remplacé par
  `_extras_rng` (un `RandomNumberGenerator` qui se sème lui-même à l'OS) et
  `set_extras_seed()`. La différence n'est pas cosmétique : **une graine ne
  peut pas faire dire au tirage livré quelque chose qu'il ne dirait pas** ;
  elle fixe seulement lequel des tirages possibles sort. La sonde ne
  *choisit* d'ailleurs plus la graine, elle la **cherche** — elle balaie
  jusqu'à en trouver une dont le premier tirage passe sous `LADYBUG_CHANCE`.
* **`WorldSave._data["stats"]["shakes"] = N`** écrit en direct par la sonde :
  remplacé par des appels réels à `tree_take()` sur des identifiants d'arbre
  jetables — le seul chemin qui incrémente ce compteur pour un joueur aussi.
  Au passage, `V4ClimbProbe` pointe désormais `SAVE_PATH_OVERRIDE` sur un
  fichier jetable : elle ne peut plus écraser la sauvegarde de personne.
* **`--showcase`** de `V4ClimbProbe` : un mode de capture de nuit qui
  n'assertait rien. Supprimé.

### Le workflow CI

`.github/workflows/web-build.yml` avait été étendu pour déployer les deux
branches carte blanche sur un alias `keepy-cozy`. **Restauré à l'identique
d'`origin/main`** (`git diff origin/main` vide sur ce chemin) : les étapes
PRODUCTION (`main` → `keepy-ten`) et STAGING (`staging` → `keepy-staging`)
sont celles d'avant, et l'alias `keepy-cozy` cesse d'exister.

### Les sondes de nuit

| sonde | verdict | pourquoi |
|---|---|---|
| `V4SaveProbe` | **gardée** | 45 assertions sur `WorldSave`, une mécanique livrée. Écrit sur un chemin jetable. |
| `V4ClimbProbe` | **gardée** | le contrat du ride vertical et de la récolte, une mécanique livrée. |
| `V4SiteProbe` | **gardée** | elle n'asserte rien — mais `HubTrees.gd` et `HubTapInput.gd` la **citent comme la source** de leurs chiffres de dégagement. La supprimer aurait fabriqué trois « chiffres fantômes » au sens de `CLAUDE.md`, et les re-dériver coûterait bien plus que le fichier. |
| `CozyCapture` | **gardée** | le seul instrument de rendu offscreen du hub cozy, et `CLAUDE.md` documente le rendu comparatif comme la méthode qui a fermé deux cas de métrique fausse. |
| `CozyGlbInspect` | **supprimée** | inspection ponctuelle du pipeline d'import, n'asserte rien, **aucun chiffre livré ne la cite**. Sonde jetable au sens de la doctrine. |

**Les quatre sondes conservées sont désormais bornées par
`ProbeWatchdog.arm()` en première instruction de `_ready()`**, à la place de
leurs `create_timer(...).quit(9)` maison — donc un seul verdict INCONCLUSIVE
et un seul code de sortie (`ProbeWatchdog.EXIT_TIMEOUT`) pour tout le
dossier. `CozyCapture` garde en plus son plafond de FRAMES, qui n'est pas la
même panne que le plafond d'horloge : le premier attrape une capture qui
n'arrive jamais parce que sa condition n'est jamais remplie, le second
attrape un run qui ne produit plus de frames du tout.

### Les outils de développement : gardés, mais re-gatés

Les trois affordances de la preview (overlay de performance, forçage de la
météo, remise à zéro de la sauvegarde) étaient gatées sur
`Auth.is_untrusted_preview_domain()` — c'est-à-dire sur une **liste noire de
noms d'hôtes**, qui est fausse dans les deux sens dès que l'alias jetable
disparaît : tout hôte non nommé devient un hôte de développeur, et l'overlay
ne peut **jamais** s'allumer sur staging ni en prod, là où ses chiffres sont
précisément les seuls qui comptent.

Elles passent sur **`DevTools.enabled()`** (`scripts/DevTools.gd`), une
**liste blanche** à trois entrées : hors web (éditeur, sondes, captures
xvfb), export web de DÉBOGAGE, ou le jeton `keepydev` présent dans la query
string ou le fragment de l'URL. Rien ne s'affiche sans que quelqu'un l'ait
demandé, et ce qui le demande n'est plus un nom d'hôte.

⚠️ **`DevTools` n'est PAS une frontière d'autorisation** et rien derrière ne
doit jamais être traité comme telle : n'importe qui peut taper le jeton. Elle
gate la **visibilité** d'affordances de développement pour qu'un joueur ne
tombe pas dessus. Tout ce qui touche Firestore reste gaté sur
`Auth.is_signed_in()`, que ce fichier ne lit ni n'influence.

## Ce qui reste à valider sur device — et pourquoi ça n'a pas pu l'être ici

Cinq nuits de travail n'ont été vues que sur une preview, et
`CLAUDE.md` documente au moins deux fois qu'une passe verte dans ce sandbox
peut être cassée sur device (llvmpipe/`opengl3` de bureau contre WebGL2 sous
Safari : deux compilateurs GLSL et deux tris des transparents). Les réglages
que les sessions carte blanche ont eux-mêmes listés comme « à régler sur
device » :

* `SEAT_MAX_Y` 4,85 — la tête à 0,4 u du bord haut du cadre ;
* `DECOR_TAP_MARGIN` 0,55 — un tap sur le chemin à côté d'un tronc doit
  rester une marche, pas une escalade ;
* `TREE_SURFACE_TILT_MAX_DEG` 20 et `CROWN_STOP` 0,85 — la pose sur le flanc
  a été fausse **trois fois sur capture** avant d'être juste, et aucune
  relecture ne l'aurait vu ;
* `LADYBUG_FLEE` 2,6 et `LADYBUG_LIFE_S` 9 — trop lent, pas de chasse ; trop
  vite, frustration ;
* le **FPS réel** de l'iPhone, que l'overlay de perf existe pour donner : le
  chiffre du sandbox (12 FPS sous llvmpipe en 1080×1920) n'est pas un chiffre
  device et ne l'a jamais été.

## Dette connue, non traitée par le lot de cadrage

* **Deux chemins pour une même chose** : les cinq perchoirs gardent leurs
  noisettes en nœuds enfants (15 `MeshInstance3D`) pendant que les 48 arbres
  adoptés les ont en batch. Un lot devrait basculer les perchoirs dans les
  batches, ou l'inverse — pas garder les deux.
* **Le pas caché sous le surplomb** : au pied d'un arbre rond, Keepy est
  invisible ~0,3 s derrière la couronne. Si c'est lu comme un trou, la
  réponse est de faire partir la montée du flanc dès le pied, **pas** de
  bouger la caméra (voir la doctrine `HubCamera.OFFSET` de `CLAUDE.md`).
* **La famille `climbtree.py`** à 794 tri par arbre est la plus lourde de la
  branche ; un LOD à ~300 tri reste à sortir.
* **Aucun son** sur la récolte, la coccinelle ou la météo.
* **Le gland doré n'a pas d'usage** — pièce de collection jusqu'au craft.

## Doctrines remontées dans `CLAUDE.md`

Le lot de cadrage a écrit dans `CLAUDE.md` les quatre doctrines de la branche
qui valent pour tout lot futur, plus trois corollaires. Elles ne sont pas
recopiées ici : ce fichier les nomme, `CLAUDE.md` les porte.

1. **Godot tient les faces HORAIRES pour faces avant** — un ruban CCW
   disparaît entièrement sous `cull_back`, sans une seule erreur.
2. **`viewport_get_render_info` ne compte que la liste OPAQUE, et au LOD que
   le moteur a choisi** — distinguer « gpu » de « scene », et gater le
   plafond sur le premier.
3. **`visibility_range_end` fonctionne en Compatibility** comme culling CPU
   pur, à condition de mettre `visibility_range_fade_mode = DISABLED`.
4. **Le ride vertical est l'alternative à la migration multi-altitude** —
   monter un personnage le long d'une géométrie coûte un état, pas une
   refonte de navigation.
5. Corollaire : **un `Node3D` porteur ne porte JAMAIS l'échelle** de
   l'instance qu'il représente.
6. Corollaire : **le tronc d'un arbre à houppier plein est invisible** depuis
   la caméra du hub.
7. Corollaire : **un `tint` de shader qui MULTIPLIE la couleur de sommet ne
   peut pas recolorer vers une autre teinte.**
