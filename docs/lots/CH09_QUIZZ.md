# Keepy Quizz — autoload CRUD et premier écran

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 434 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## `Quizz.gd` : PREMIER CLIENT RÉEL des collections `quizzes`/`questions` — CRUD d'authoring seul, aucun écran (18 août 2026)

Branche `claude/quizz-autoload-crud-pkqwl4`, partie de `staging` (`6d6a6a4`,
donc **posée sur le fix de rafraîchissement du token `onIdTokenChanged`** du
même jour — ce n'est pas un détail, voir plus bas). **Deux fichiers touchés :**
`scripts/autoload/Quizz.gd` (nouveau) et une ligne d'autoload dans
`project.godot`. **`scenes/Hub.tscn`, `scripts/ui/Hub.gd` et
`firestore.rules` sont INTOUCHÉS**, vérifié et pas affirmé : `git diff --stat`
contre `origin/staging` ne rapporte rien d'autre que ces deux fichiers (+ ce
document).

Les rules Quizz sont en production depuis le 12:52:52 UTC du même jour (run #3
de `firestore-rules.yml`) et **rien ne les exerçait** : le point 1 du « Reste
ouvert » de la section rules disait « aucun client n'existe encore ». Ce lot
écrit ce client. Il ne le **teste** toujours pas contre le service — voir
« Ce qui n'a PAS été mesuré » plus bas, c'est la limite honnête de ce lot.

### Périmètre : authoring, et rien d'autre

Créer / lire / modifier / supprimer **ses propres** quiz et questions. Huit
points d'entrée, huit signaux :

| appel | signal |
|---|---|
| `create_quiz(title)` | `quiz_created(success, quiz_id, error)` |
| `update_quiz(quiz_id, title, question_count = -1)` | `quiz_updated(success, quiz_id, error)` |
| `delete_quiz(quiz_id)` | `quiz_deleted(success, quiz_id, error)` |
| `list_own_quizzes()` | `quizzes_fetched(success, quizzes, error)` |
| `create_question(quiz_id, type, payload)` | `question_created(success, quiz_id, question_id, error)` |
| `update_question(quiz_id, question_id, type, payload)` | `question_updated(success, quiz_id, question_id, error)` |
| `delete_question(quiz_id, question_id)` | `question_deleted(success, quiz_id, question_id, error)` |
| `list_questions(quiz_id)` | `questions_fetched(success, quiz_id, questions, error)` |

**Aucune scène, aucun écran de jeu, aucune boucle de partie.** Le bouton
« Keepy Quizz » du hub reste `disabled = true` et **toujours connecté à rien**.

⚠️ **`success` est en PREMIER argument ici, alors que `Leaderboard.gd` le met
en DERNIER** (`top_scores_fetched(entries, success)`). Divergence assumée : la
cohérence à l'intérieur du fichier neuf a été préférée à la cohérence avec un
voisin à deux signaux, et `Leaderboard.gd` n'est pas touché par ce lot.

### Le contrat de robustesse est celui de `Leaderboard.gd`, copié dans l'ORDRE

1. **Court-circuit headless EN PREMIER**, dans `_ready()` :
   `DisplayServer.get_name() == "headless"` → `network_enabled = false`.
   Même détection, même raison — toute sonde de `scripts/dev/` est couverte
   automatiquement, y compris une sonde future qui n'aurait rien à
   désactiver.
2. **Jamais de crash, toujours un signal, exactement UN par appel.**
3. **Un argument refusé échoue LOCALEMENT**, avant toute socket.

⚠️ **Conséquence vérifiée et non supposée : aucun tirage RNG n'a lieu sous une
sonde.** `_generate_auto_id()` consomme `randi()` — mais il est appelé
**après** le gate sur TOUS les chemins, donc sous `--headless` il n'est jamais
atteint. C'est ce qui permet aux sondes seedées de rester byte-identiques
malgré un autoload de plus dans chaque arbre.

### ⚠️ L'AUTH EST OBLIGATOIRE ICI, contrairement à `Leaderboard.gd`

`Leaderboard.gd` envoie le bearer « quand il est disponible, jamais exigé »,
parce que les rules `/scores` acceptaient l'anonyme. Les rules Quizz gatent
`signedIn()` sur **read, create, update ET delete**, des deux côtés : une
requête sans bearer est un **403 garanti**.

Ce fichier refuse donc de dépenser un aller-retour pour un refus certain :
chaque point d'entrée exige **les DEUX moitiés** — un utilisateur signé ET un
token non vide — et émet `error = "auth-required"` immédiatement sinon, sans
jamais construire de requête. Les deux moitiés sont testées **séparément et
pas ensemble** parce qu'`Auth` publie l'uid **avant** le token : un simple
`is_signed_in()` laisserait passer un bearer VIDE, que Google répond en 401 au
lieu d'un refus de rule. **Mesuré** (phase B de la sonde jetable) : uid posé,
token vide → `auth-required`, **zéro requête construite**.

Le token est relu **à chaque départ de requête**, jamais mis en cache — ce lot
est posé sur le fix `onIdTokenChanged` du même jour, et c'est lui qui rend
cette lecture utile : avant lui le token détenu était figé à la connexion et
expirait au bout d'une heure. Un éditeur de questionnaire écrit en continu, là
où Keepy Chased écrit une fois par run — le point 4 du « Reste ouvert » de la
section durcissement, corrigé la veille au soir, était donc bien un
prérequis de celui-ci.

### Les pièges REST de `QUIZZ_SPEC.md` §8, un par un

- **CREATE** : `:commit`, `currentDocument: {exists: false}`, **DEUX**
  `updateTransforms` (`createdAt` ET `updatedAt`, `setToServerValue:
  REQUEST_TIME`). Les rules exigent l'égalité avec `request.time`, qu'un
  littéral client ne peut pas satisfaire.
- **UPDATE** : `updateMask.fieldPaths` **exactement égal aux clés envoyées** —
  ni plus (une clé masquée mais absente des `fields` serait **SUPPRIMÉE**), ni
  moins. `uid` et `createdAt` ne sont **ni envoyés ni masqués** : les rules
  comparent le document RÉSULTANT au stocké, et un champ hors masque est
  préservé tel quel, donc les omettre satisfait l'immuabilité.
- **LISTE** : `fieldFilter uid EQUAL <mon uid>` sur les deux listes, sans
  exception. Firestore n'exécute que les requêtes qu'il peut PROUVER conformes
  à une règle owner-only — une liste non filtrée est **REFUSÉE**, pas vide.
- **UNE SEULE requête en vol** : un `HTTPRequest`, une **file FIFO**, un slot
  in-flight. Huit opérations sur deux collections rendaient le motif
  « un nœud par endpoint » de `Leaderboard.gd` intenable (huit nœuds, et
  toujours pas deux `create` d'affilée). **Rien n'est jamais perdu en
  silence** : un appel fait pendant qu'un autre est en vol est mis en file et
  parti au moment où le slot se libère ; et un appel en file dont la session
  a expiré entre-temps **échoue avec son propre signal** au lieu d'être jeté.

⚠️ **`type` EST envoyé sur `update_question` alors qu'il est immuable, et
c'est délibéré.** Une valeur égale satisfait la règle d'immuabilité ; une
valeur qui NE correspond PAS au document stocké est alors refusée sur cette
règle précise, au lieu de produire un échec `hasOnly` déroutant causé par les
champs de l'ancien type survivant hors du masque à côté de ceux du nouveau.

### Deux décisions de tri qui ne se ressemblent pas — et c'est mesuré, pas incohérent

- **`list_own_quizzes()` trie CÔTÉ SERVEUR** (`updatedAt DESCENDING`), comme
  le §8 le prescrit. ⚠️ **Cela exige un INDEX COMPOSITE `uid ASC` +
  `updatedAt DESC` sur `quizzes`, et sa création est une ACTION MANUELLE en
  Console Firebase** — une égalité combinée à un `orderBy` sur un autre champ
  n'est servie par aucun index à champ unique. Tant qu'il n'existe pas,
  Firestore répond **400 FAILED_PRECONDITION** avec un message contenant une
  **URL de console prête à l'emploi**. Ce message est transmis **VERBATIM**
  sur l'argument `error` de `quizzes_fetched` — donc l'URL survit jusqu'à
  l'appelant au lieu d'être avalée. **Aucun repli, aucun retry** : retomber
  en silence sur une requête non triée masquerait un index manquant derrière
  un autre jeu de résultats.
- **`list_questions()` ne trie PAS côté serveur, et c'est le choix le plus
  correct des deux.** Les rules déployées disent elles-mêmes qu'`order` n'est
  **ni unique ni contigu** et que le tri d'affichage doit être **(order,
  questionId)** — une égalité de rang qu'un `orderBy` Firestore sur `order`
  seul ne sait pas exprimer. Le tri est donc fait ici, sur (order, id), ce qui
  a un second effet : la requête reste sur l'index à champ unique `uid` et
  **n'a besoin d'AUCUN index composite**, donc elle marche le jour où elle
  tourne pour la première fois. Le jeu est plafonné à quelques dizaines de
  documents, le tri local ne coûte rien.

### Conventions figées par ce fichier

- **Les clés du `payload` d'entrée et des dictionnaires décodés sont les noms
  de champs Firestore VERBATIM** (`prompt`, `order`, `choice0..3`,
  `answerIndex`, `answerBool`, `answerText`, `title`, `visibility`,
  `questionCount`, `createdAt`, `updatedAt`), plus `id` pour l'identifiant de
  document. Ce qu'on lit est ce qu'on écrit : **aucune table de traduction à
  se tromper**.
- **`visibility` n'est PAS un paramètre.** Un argument suggérerait qu'un
  appelant peut en choisir un autre ; seul `'private'` existe, et c'est une
  décision actée (§2.3), pas un défaut modifiable.
- **`questionCount` est écrit à 0 à la création**, bien que les rules le
  rendent optionnel : un compteur présent dès le départ fait d'`update_quiz`
  une écriture de champ ordinaire au lieu d'une branche créer-ou-modifier. Il
  reste une valeur **d'AFFICHAGE** — rien ne le réconcilie jamais avec la
  réalité, les rules ne savent pas compter une sous-collection.
- **`PROJECT_ID` et `API_KEY` sont LUS depuis `Leaderboard.gd`**, pas
  recopiés. Deux copies littérales d'une clé d'API sont un risque de rotation
  dont le mode de défaillance est un 403 silencieux dans le fichier qu'on a
  oublié. `_generate_auto_id()`, lui, **est** une copie locale de six lignes
  plutôt qu'un appel dans l'API privée du voisin — si l'un change, l'autre
  doit suivre.
- **La validation locale reflète les rules** (titre 1..60, énoncé 1..200,
  choix 1..120, `answerIndex` 0..3, `answerText` 1..120, `order` 0..199,
  `questionCount` 0..50, type dans les trois). Elle ne rend pas le serveur
  redondant — il reste l'autorité — elle transforme un 403 certain en échec
  local instantané portant un motif qu'une UI peut afficher.

⚠️ **Le plafond de 50 questions par quiz n'est PAS appliqué et ne PEUT pas
l'être ici** : ni ce fichier ni une rule ne sait compter la sous-collection
sans une liste, et un compte lu au moment de créer court après lui-même. Un
appelant qui y tient doit compter ce que `list_questions()` a rendu et refuser
localement. Même famille : **`delete_quiz()` n'est PAS une cascade** — les
questions survivent en orphelines, lisibles par leur seul propriétaire (coût
de stockage, pas de fuite). Pour les supprimer, il faut les lister et les
supprimer **avant** le parent.

### Mesure : sonde jetable, 108 assertions, ZÉRO octet sorti de la machine

`scripts/dev/QuizzContractProbe.tscn`, construite pour ce lot puis
**supprimée avant le commit** (`ProbeTimeoutAudit` revient donc à son chiffre
de baseline). **108 assertions, 0 échec, exit 0.** Elle pilote le VRAI
autoload — jamais un stub du fichier testé — sur six phases : court-circuit
headless, gate d'auth, **corps REST exacts** confrontés aux rules déployées,
file FIFO, validation locale, et réponses/décodage.

⚠️ **Piège d'outillage rencontré, à connaître avant de vouloir intercepter un
`HTTPRequest` dans ce dépôt : on NE PEUT PAS le stubber.** Une sous-classe
GDScript qui redéfinit `request()` est **refusée à la compilation** par Godot
4.3 (« overrides a method from native class », warning traité en erreur), et
même en la forçant, l'appel de `Quizz.gd` part en ptrcall natif parce que
`_http` est **typé statiquement** — le script n'est jamais atteint.
**Contournement retenu, qui s'est révélé meilleur que le stub** : une
opération est **entièrement construite dans `_queue` AVANT que `_pump()` ne
l'envoie**, donc occuper le slot in-flight avec une sentinelle suffit à lire
l'url, la méthode et le corps exacts de chaque appel, sans transport du tout.
La file, la complétion et le décodage sont ensuite exercés en appelant
directement `_pump()`, `_on_request_completed()` et `_dispatch()`. **Aucun
octet n'est jamais parti vers Firestore**, et c'est bien le code livré qui est
mesuré.

**Ce que la sonde a trouvé et qui a été corrigé** : sur un échec de transport
(hors ligne, DNS, connexion refusée) le corps de réponse est **vide**, et le
donner à `JSON.parse_string` faisait imprimer au moteur sa propre ligne
`ERROR: Parse JSON failed` — une entrée stderr alarmante pour l'échec le plus
ordinaire de ce fichier. `_error_text()` ne tente désormais le parse que si le
corps commence par `{`. Trouvé par la mesure, pas par relecture.

### Sondes : AUCUNE n'est affectée, vérifié plutôt que supposé

**Non-applicabilité vérifiée par `grep`, pas supposée** : aucune sonde de
`scripts/dev/` ne référence `Quizz`, et aucune ne charge `run/main_scene`
(chacune lance sa propre `.tscn`). Le seul effet possible d'un autoload de
plus est structurel : un nœud de plus dans chaque arbre de sonde, plus son
`HTTPRequest` enfant. Et il ne consomme **aucun tirage RNG** (voir plus haut),
donc les flux seedés ne peuvent pas se décaler.

**Mesuré quand même, contre `origin/staging` en worktree séparé, sur l'arbre
FINAL du lot** (graine 20260806, `--fixed-fps 60`) :

| sonde | verdict | diff contre `origin/staging` |
|---|---|---|
| `ProbeTimeoutAudit` | exit 0, **33 sondes** (retour exact à la baseline après retrait de la sonde jetable) | **byte-identique** |
| `AssetContractAudit` | exit 0, 12/12 visuels, **0/10 colliders déplacés** | **byte-identique** |
| `DeathModelAudit` | exit 0 | **byte-identique** |
| `ChargerShapeProbe` | exit 0 | **byte-identique** |
| `AlarmRampAudit` | exit 0 | **byte-identique** |
| `ComboAudit` (seedée) | exit 0 | **byte-identique** |
| `ShrinkAudit` (seedée) | exit 0 | **byte-identique** |

**Sept sondes, byte-identiques sur les DEUX flux (stdout ET stderr), exit 0
des deux côtés.** C'est le bar attendu pour un lot qui n'ajoute qu'un autoload
inerte sous sonde, et l'identité au bit près le dit plus fort qu'un simple
verdict identique.

### Build

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles, mêmes que la CI). Import headless **exit 0**,
export Web release **exit 0**. `index.wasm` **35 376 909 octets**, md5
`af4a8fc2925d992348eb30deeeb54360` — **identique au fingerprint déjà consigné**
pour tout lot qui ne touche pas le code moteur. `Quizz.gdc` est bien compilé
dans le `.pck` à côté de `Auth.gdc` / `Leaderboard.gdc` / `GameState.gdc`
(donc l'autoload est réellement enregistré, pas seulement écrit).
`index.pck` 5 467 616 octets — export unique et propre (`build/` supprimé
avant ET après), à lire avec la mise en garde permanente sur l'instabilité du
`.pck`. Piège payload re-vérifié sur le log `savepack` : **0** ligne
`Storing File: res://assets_source`.

### ⚠️ CE QUI N'A PAS ÉTÉ MESURÉ — la limite honnête de ce lot

**Aucune requête n'a jamais atteint Firestore.** Ni depuis ce sandbox (pas
d'idToken Google réel, et la fabrication d'un compte de test a déjà été
refusée dans une session précédente), ni ailleurs. Tout ce qui précède prouve
que le client construit **exactement** ce que les rules déployées décrivent,
**pas** que le serveur l'accepte. Les points suivants restent donc de la
théorie tant qu'un écran ne les exerce pas pour de vrai :

1. **L'INDEX COMPOSITE `uid ASC` + `updatedAt DESC` sur `quizzes` n'existe
   pas** (rien dans ce dépôt ne le crée, `firebase.json` ne déclare aucun
   `firestore.indexes.json`). **`list_own_quizzes()` échouera donc au premier
   appel réel**, en 400 FAILED_PRECONDITION — c'est **attendu**, pas un bug à
   chercher. L'`error` du signal portera l'URL de console à cliquer.
   **ACTION MANUELLE de Mathieu**, ou — meilleure place le jour venu, et
   délibérément HORS PÉRIMÈTRE ici parce que ça déploierait sur le projet
   global — ajouter `"indexes": "firestore.indexes.json"` à `firebase.json`
   pour que `firestore-rules.yml` devienne aussi le chemin de déploiement des
   index.
2. **La première écriture réelle** (create d'un quiz, create d'une question)
   n'a jamais été tentée contre le service.
3. **Le rafraîchissement du token en session longue** : le fix
   `onIdTokenChanged` est validé sur device pour Keepy Chased, pas pour une
   session d'authoring de plus d'une heure.

### Où une future session reprend

- **Rien n'appelle `Quizz.gd`.** Les écrans du §7 de `docs/QUIZZ_SPEC.md`
  restent à écrire (liste de mes quiz, éditeur de quiz, éditeur de question),
  ainsi que l'hôte unique + panneaux par format tranché au §10.2.
- **Le branchement du bouton du hub** est décrit au §7.1 de
  `docs/QUIZZ_SPEC.md` : retirer `disabled = true` de `QuizzButton` dans
  `scenes/Hub.tscn`, connecter son `pressed`, et **retirer l'assertion de
  `Hub._ready()`** qui `push_error` si ce `disabled` disparaît — elle existe
  pour qu'un bouton réactivé mais non connecté ne puisse pas passer inaperçu,
  donc son retrait fait partie du branchement, pas d'un lot de nettoyage.
- **Le §10.3 reste ouvert** (correction de la réponse libre : comparaison
  exacte après normalisation ? variantes acceptées ?) et il faudra le trancher
  avant d'écrire l'écran de jeu du format `free`, pas pendant.

## `QuizzHomeScreen.tscn` : PREMIER ÉCRAN RÉEL exercant `Quizz.gd` — créer + lister, rien d'autre (18 août 2026)

Branche `claude/quiz-home-screen-t8dt2w`, redémarrée sur `origin/staging`
(`6c72dbc`) — la branche pointait encore sur `main`, sans `Quizz.gd`. Trois
fichiers touchés : `scenes/QuizzHomeScreen.tscn` + `scripts/ui/
QuizzHomeScreen.gd` (nouveaux), `scenes/Hub.tscn` + `scripts/ui/Hub.gd`
(bouton Quizz activé). **Périmètre volontairement étroit, comme demandé** :
créer un quiz par titre, lister les siens. Pas d'édition de questions, pas de
jeu — juste de quoi prouver que la fondation `Quizz.gd` marche contre
Firestore, chose que la section précédente de ce fichier note explicitement
n'avoir **jamais** été exercée en conditions réelles.

### Un seul écran, pas les quatre du §7 de `docs/QUIZZ_SPEC.md`

Le tableau du §7 prévoit `QuizzMenuScreen` / `QuizzListScreen` / `QuizzEditorScreen`
/ `QuestionEditorScreen` séparés. Ce lot en livre UN, `QuizzHomeScreen.tscn`,
qui fait le travail de `QuizzMenuScreen` + `QuizzListScreen` réunis — création
et liste sur le même écran, un champ + un bouton au-dessus d'une liste. C'est
un écart assumé au tableau, pas une relecture de la décision d'hôte
unique/panneaux par format du §10.2 (qui concerne l'écran de JEU, pas
l'authoring) : le brief de ce lot demandait explicitement « juste de quoi
valider que la fondation Quizz.gd fonctionne », et un écran de moins à router
pour une validation de fondation est le bon niveau d'effort. `QuizzMenuScreen`/
`QuizzListScreen` restent des noms disponibles pour une session future qui
voudrait les séparer une fois l'édition de questions justifiant un vrai menu.

Chemin de navigation, remplace la ligne « DESACTIVE » du §7.1 :

```
res://scenes/Hub.tscn
        └── "Keepy Quizz" -> res://scenes/QuizzHomeScreen.tscn   <-- NOUVEAU
                └── "<" (BackButton) -> res://scenes/Hub.tscn
```

### Le bouton Quizz du hub est ACTIF — la garde `push_error` est retirée

Exactement les trois étapes que le §7.1 avait préparées : `disabled = true`
retiré de `QuizzButton` dans `Hub.tscn` (il reprend le style bouton actif de
`ChasedButton`, `StyleBoxFlat_button_disabled` devenu inutilisé est supprimé
du fichier — `load_steps` ajusté de 8 à 7) ; `QuizzCaption` passe de
« Bientot disponible » à « Cree et gere tes questionnaires » ; `Hub._ready()`
connecte `quizz_button.pressed` vers `change_scene_to_file(QUIZZ_SCENE)`, sur
le modèle exact de `_on_chased_pressed()`. **La garde `push_error` qui
existait pour qu'un bouton réactivé sans être connecté ne parte pas en
production comme un contrôle mort est retirée** — elle n'a plus lieu d'être
puisque le bouton est désormais réellement connecté, exactement comme sa
propre doc l'annonçait.

### Comportement attendu au tout premier lancement : index Firestore manquant

`Quizz.list_own_quizzes()` documente déjà, dans son propre commentaire, que la
requête `uid EQUAL` + `orderBy updatedAt DESC` a besoin d'un index composite
qui n'a jamais été créé (aucune écriture réelle n'a encore eu lieu contre
`quizzes`), et que Firestore répond alors `400 FAILED_PRECONDITION` avec un
message portant une URL Console toute prête, transmise **verbatim** sur
l'argument `error` du signal `quizzes_fetched`. **Ce lot est le premier code
qui affiche cette réponse au joueur plutôt que de la traiter comme une panne
générique.**

`_show_error()` détecte ce cas précis (`error.contains("FAILED_PRECONDITION")`
ET une sous-chaîne `https://` présente), extrait tout ce qui suit le premier
`https://` (l'URL Firestore ne contient pas d'espace, elle est déjà encodée —
rien à chercher comme délimiteur de fin), et affiche un panneau dédié (fond
ambre, distinct visuellement du message d'échec générique) avec l'URL posée
dans un `LineEdit` non-éditable (`editable = false`, pour ne jamais déclencher
le clavier virtuel mobile au tap — piège déjà documenté ailleurs dans ce
fichier pour le clavier iOS) plus un bouton « Copier le lien »
(`DisplayServer.clipboard_set()`). **Toute autre erreur** — hors ligne,
`auth-required`, un vrai refus serveur — reste un message d'échec standard,
même registre que `LoginScreen._message_for()` : le texte générique plus le
détail brut entre parenthèses, jamais masqué.

⚠️ **Ce chemin n'a PAS pu être exercé contre le vrai service Firestore depuis
ce sandbox** — aucun idToken Google n'y est disponible (même limite déjà
consignée pour les lots rules précédents), donc ni la création d'un quiz ni
le premier `list_own_quizzes()` réel n'ont pu être tentés ici. La détection
d'erreur et l'extraction d'URL sont vérifiées par une sonde jetable (ci-dessous)
qui rejoue le message Firestore EXACT documenté par `Quizz.gd`
(`"result=0 code=400 FAILED_PRECONDITION: ... You can create it here:
https://console.firebase.google.com/v1/r/project/keepy-8df91/firestore/
indexes?create_composite=..."`), pas contre une vraie réponse capturée en
direct. **Jugement device pour la première création réelle**, qui devra
suivre ce lien une fois, comme prévu depuis l'écriture de `Quizz.gd`.

### État de chargement, cohérent avec `LoginScreen`/`Hub`

`_set_busy()` désactive le bouton Créer et le champ de titre pendant un appel
en vol, et bascule le texte de statut entre « Chargement... » / « Creation... »
— même registre texte-only que `LoginScreen._refresh_from_auth()`, pas de
spinner ni d'overlay supplémentaire. Une création réussie vide le champ de
titre puis **relance une vraie liste** plutôt que d'insérer une ligne devinée
localement : l'ordre et la date affichés viennent toujours du serveur, jamais
d'une hypothèse faite ici — la même discipline que `Quizz.gd` applique déjà à
ses propres réponses.

### Formatage de date : `updatedAt` (RFC3339) → `JJ/MM/AAAA HH:MM`

`Time.get_datetime_dict_from_datetime_string()` ne comprend que les secondes
entières ; la fraction de seconde et le `Z` final du timestamp Firestore sont
retirés avant l'appel. **Mesuré, pas supposé** : une chaîne imparsable ne
renvoie pas un dictionnaire vide mais un dictionnaire à zéro partout — c'est
donc `year == 0` qui sert de détecteur d'échec plutôt qu'un test
`is_empty()`, avec la chaîne brute affichée en repli plutôt qu'un
« 00/00/0000 » absurde sur le seul champ qu'un joueur ne peut pas
interpréter lui-même.

### Sondes headless : aucune affectée, vérifié par grep et par exécution

`grep` sur `scripts/dev/` : **aucune sonde ne référence `QuizzHomeScreen.tscn`,
`Hub.tscn` ni `LoginScreen.tscn`** — chacune lance sa propre scène et
contourne `run/main_scene` par construction, même constat déjà fait aux deux
lots hub/token précédents. `ProbeTimeoutAudit` (**33 sondes, toutes armées**),
`AssetContractAudit` (12/12 visuels, 0/10 colliders déplacés), `DeathModelAudit`
(CHARGER seul fatal, capture au 2ᵉ contact), `ChargerShapeProbe` — **rejouées
dans ce sandbox, toutes exit 0**, aucune ligne stderr nouvelle hors celle déjà
documentée (`Parameter "m" is null` sur `DeathModelAudit`, pré-existante).

Une sonde jetable (`scripts/dev/QuizzHomeScreenProbe.tscn`, jamais commitée,
supprimée avant ce commit) a instancié l'écran réel et appelé ses handlers
avec des payloads synthétiques : détection FAILED_PRECONDITION + extraction
d'URL, non-déclenchement du panneau index sur une erreur non liée, peuplement
de la liste (2 lignes, dates formatées), état vide, et vidage du champ de
titre après une création réussie — **toutes les assertions passent**.

### Validation build

Éditeur + templates Godot 4.3-stable installés dans ce sandbox pour ce lot
(releases GitHub officielles). Import headless **exit 0**, export Web release
**exit 0**, aucune ligne d'erreur dans les deux logs. `index.wasm`
**35 376 909 octets** — identique au fingerprint déjà consigné pour tout lot
qui ne touche pas le code moteur, cohérent : ce lot n'ajoute que deux scènes
UI et modifie deux fichiers UI existants, aucun script `autoload` ni
`project.godot` (au-delà de l'autoload `Quizz` déjà enregistré par le lot
précédent).

### Reste ouvert — jugement device, seul juge

1. **La toute première création réelle** sur `keepy-staging.vercel.app` :
   doit produire soit un quiz qui apparaît dans la liste (si l'index existe
   déjà), soit le panneau d'index avec un lien qui, une fois ouvert et
   confirmé en Console, débloque la liste au rafraîchissement suivant. Aucune
   des deux branches n'a pu être vue tourner contre le vrai service depuis ce
   sandbox.
2. Lisibilité de l'écran à l'échelle réelle d'un téléphone (le panneau
   d'index, en particulier — jamais vu rendu ailleurs que dans une sonde
   headless).
3. Tout le reste du §7 (édition de questions, jeu) reste à écrire, inchangé
   par ce lot.

`main` n'est **pas** touché : palier 1 seulement (merge automatique sur
`staging`, build/export/sondes verts) ; palier 2 reste gaté par Mathieu après
validation device.

