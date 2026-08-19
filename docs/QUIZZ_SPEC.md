# Keepy Quizz — conception du schéma Firestore, des rules et des écrans

**Étape : CONCEPTION UNIQUEMENT.** Aucun gameplay, aucune scène, aucun
autoload n'est créé par ce lot. Le seul fichier ajouté est celui-ci.
`firestore.rules`, `.github/workflows/firestore-rules.yml`, `firebase.json`
et `.firebaserc` sont **intouchés** — le brouillon de rules du §4 vit ici,
dans un bloc de code, et nulle part ailleurs.

Keepy Quizz est un second sous-jeu sous l'ombrelle « Keepy's Memorial
Quest », à côté de Keepy Chased. Il partage le projet Firebase
`keepy-8df91`, l'autoload `Auth` et le gate Google Sign-In déjà en
production depuis le 18 août 2026.

> **MISE À JOUR DU 18 AOÛT 2026 — trois décisions de Mathieu sont ACTÉES,
> et l'ombrelle EXISTE.** Ce document a été écrit avec trois points
> ouverts (§10.1, §10.2 et le volet visibilité de §10.5) ; les trois sont
> tranchés, et ce ne sont plus des propositions :
>
> 1. **Point d'accroche : un écran hub séparé**, `scenes/Hub.tscn`, pas un
>    second bouton sur `TitleScreen`. **Il est livré** (lot
>    « Keepy's Memorial Quest hub », 18 août 2026) — voir §7.1 pour le
>    chemin de nœud exact auquel brancher le vrai gameplay.
> 2. **Écran de jeu Quizz : hôte unique + panneaux par format**, pas un
>    écran par format. L'écart argumenté au §7 devient la forme retenue.
> 3. **`visibility` reste `'private'` et rien d'autre**, sans échéance de
>    révision. Ce n'est plus « en attendant », c'est la décision — §2.3
>    n'a donc rien à changer, seulement à cesser de se lire comme
>    provisoire.
>
> Les paragraphes concernés sont amendés sur place ci-dessous plutôt que
> réécrits : l'argumentaire qui a mené à ces choix garde sa valeur, c'est
> son statut (« proposé » → « acté ») qui change.

---

## 0. Ce qui a été LU avant de proposer quoi que ce soit

Recon faite sur l'arbre réel, pas de mémoire. Base : `origin/main` =
`origin/staging` = `6d57fd4`.

| vérification | résultat |
|---|---|
| `git fetch --all --prune` + tri des refs par date | ref la plus récente = `origin/main`/`origin/staging` (18 août 10:34 UTC), soit le lot de durcissement des rules déjà clos et documenté. **Aucune session concurrente.** |
| `CLAUDE.md` | lu intégralement sur l'arbre (pas de mémoire) |
| `firestore.rules` | lu — bloc `scores` reproduit ci-dessous |
| `scripts/autoload/Leaderboard.gd` | lu — chaîne token/uid reproduite ci-dessous |
| `scripts/autoload/Auth.gd` | lu — API publique relevée |
| `docs/MESHY_SPEC.md` | parcouru (§1, §2, §8, §9, §10) — verdict au §6 |

### Le pattern d'auth réellement déployé sur `scores`

```
allow read: if request.auth != null;

allow create: if request.auth != null
  && request.resource.data.keys().hasOnly(['name','score','nuts','glands','createdAt','uid'])
  && request.resource.data.keys().hasAll(['uid'])
  && request.resource.data.uid == request.auth.uid
  && ...bornes de type et de valeur...
  && request.resource.data.createdAt == request.time;

allow update, delete: if false;
```

Trois propriétés à réutiliser telles quelles, et une à ne PAS réutiliser :

- **`hasOnly([...])` ferme le jeu de clés.** C'est structurel : un champ
  non listé fait échouer l'écriture. Ce point porte à lui seul
  l'exclusion Keepr du §3.
- **`hasAll(['uid'])` rend le champ obligatoire**, là où `hasOnly` ne fait
  que le plafonner ; et il transforme un uid absent en `false` propre
  plutôt qu'en erreur d'évaluation (le commentaire du fichier réel le dit
  explicitement).
- **`uid == request.auth.uid`** empêche un client authentifié d'écrire
  sous l'identité d'un autre.
- ⚠️ **`allow update, delete: if false` ne peut PAS être repris.** Un
  score est immuable par nature ; un questionnaire s'édite et se
  supprime. C'est le seul endroit où Quizz doit sortir du patron de
  `scores`, et c'est ce qui amène les vérifications d'immuabilité du §4
  (`uid` et `createdAt` ne bougent pas d'une mise à jour).

### Comment `Leaderboard.gd` obtient et transmet token + uid

À reprendre **verbatim**, y compris la séparation en deux helpers :

```gdscript
func _request_headers() -> PackedStringArray:
    var headers := PackedStringArray(["Content-Type: application/json"])
    if not Auth.is_signed_in():
        return headers
    var token := Auth.get_id_token()
    if token.is_empty():
        return headers
    headers.append("Authorization: Bearer %s" % token)
    return headers

func _current_uid() -> String:
    if not Auth.is_signed_in():
        return ""
    return Auth.get_current_uid()
```

⚠️ **La séparation en deux fonctions n'est pas cosmétique** : `Auth`
publie l'uid **avant** le token (doc de `Auth.get_id_token()` :
« Empty string when signed out, off-web, or while the token is still
being fetched (the uid is published before the token) »). Un seul
`is_signed_in()` laisserait donc passer un bearer **vide**, que Google
rejette en 401. Les deux questions ne peuvent pas partager une réponse.

Trois autres acquis de ce fichier, chacun payé par un incident réel :

1. **`accept_gzip = false` sur chaque `HTTPRequest`.** Sans ça, l'export
   Web rend `result=8` (`RESULT_BODY_DECOMPRESS_FAILED`) avec `code=200`
   — une réponse HTTP réussie que Godot jette en la décodant. Validé
   device (PWA + onglet Chrome). **Non négociable pour Quizz.**
2. **Court-circuit headless en PREMIÈRE instruction** de chaque point
   d'entrée réseau (`if not network_enabled: emit(...); return`), avec
   `network_enabled = false` quand `DisplayServer.get_name() ==
   "headless"`. C'est ce qui rend les sondes de `scripts/dev/`
   byte-identiques sans qu'aucune n'ait à s'en occuper.
3. **`createdAt == request.time` impose `:commit` avec
   `updateTransforms` / `setToServerValue: "REQUEST_TIME"`.** Un
   timestamp littéral côté client, même parfaitement à l'heure, ne
   satisfait jamais cette égalité — vérifié live contre ce projet, il
   échoue en `PERMISSION_DENIED` à chaque fois. Un simple
   `POST .../documents/quizzes` ne peut donc PAS créer un document dont
   une règle contraint l'horodatage.

---

## 1. Décision de structure : sous-collection, pas questions embarquées

Deux formes possibles pour « une liste de questions appartenant à un
questionnaire ». Les deux ont été pesées ; le départage est fait par ce
que les **rules savent valider**, pas par le goût.

| | questions EMBARQUÉES (array dans le doc quiz) | questions en SOUS-COLLECTION |
|---|---|---|
| lecture d'un quiz jouable | 1 read | 1 + N reads |
| taille max | 1 MiB par doc, plafond réel ~1 000 questions | aucune limite pratique |
| **validation par les rules** | ⚠️ **impossible par élément** | ✅ une règle par document |
| nombre de questions borné par les rules | ✅ `size() <= 50` | ❌ non (voir §5) |
| réordonner / éditer une question | réécrit tout le doc | écrit un seul doc |

⚠️ **Le point décisif : les Firestore rules n'ont pas de boucle.** Sur un
array, elles savent asserter `x is list` et `x.size() <= 50`, et rien de
plus — **aucune** vérification du contenu des éléments. Un client
authentifié pourrait donc écrire `questions: [42, null, {}, []]` et les
rules l'accepteraient. Tout le travail de validation retomberait alors
côté client, c'est-à-dire côté attaquant, sur les trois formats que le
`type` est censé discriminer.

**Retenu : sous-collection `quizzes/{quizId}/questions/{questionId}`**,
avec `uid` **dénormalisé sur chaque question**. La dénormalisation évite
un `get()` du parent dans les rules — un `get()` est une lecture facturée
à chaque évaluation, plafonnée à 10 par requête simple, et il ferait
dépendre l'écriture d'une question de la lisibilité du quiz.

Le coût accepté est nommé au §5 : le nombre de questions par quiz devient
non gatable côté serveur.

### Nom du champ propriétaire : `uid`, pas `ownerUid`

`ownerUid` est plus explicite, et il a été considéré. **`uid` est retenu**
pour que les trois lignes d'auth soient **littéralement les mêmes** que
celles déjà déployées sur `scores` — un relecteur de `firestore.rules`
voit le même triplet `hasOnly` / `hasAll(['uid'])` / `uid ==
request.auth.uid` à deux endroits, et pas deux variantes à comparer.
Ambiguïté résiduelle assumée : sur une question, `uid` désigne le
propriétaire du questionnaire parent, pas un « auteur de la question » —
c'est la même personne dans tous les cas prévus ici.

---

## 2. Schéma proposé

### 2.1 `quizzes/{quizId}` — le questionnaire

`quizId` : id auto généré côté client, même alphabet et même longueur que
`Leaderboard._generate_auto_id()` (20 caractères).

| champ | type | contraintes | rôle |
|---|---|---|---|
| `uid` | string | `== request.auth.uid`, immuable | propriétaire |
| `title` | string | 1..60 caractères | titre affiché |
| `visibility` | string | **`'private'` uniquement** | voir §2.3 |
| `questionCount` | int (optionnel) | 0..50 | compteur d'affichage, **non fiable** (§5) |
| `createdAt` | timestamp | `== request.time` à la création, immuable ensuite | tri |
| `updatedAt` | timestamp | `== request.time` à chaque écriture | tri de la liste |

Aucun autre champ. `hasOnly` refuse tout le reste.

### 2.2 `quizzes/{quizId}/questions/{questionId}` — les trois formats

**Champs communs aux trois types :**

| champ | type | contraintes |
|---|---|---|
| `uid` | string | `== request.auth.uid`, immuable |
| `type` | string | `'mcq4'` \| `'truefalse'` \| `'free'`, immuable |
| `prompt` | string | 1..200 caractères — l'énoncé |
| `order` | int | 0..199 — position dans le questionnaire |
| `createdAt` | timestamp | `== request.time`, immuable |
| `updatedAt` | timestamp | `== request.time` |

**Champs propres à chaque type**, et rien d'autre :

| `type` | champs additionnels | contraintes |
|---|---|---|
| `mcq4` | `choice0`, `choice1`, `choice2`, `choice3` (string) + `answerIndex` (int) | chaque choix 1..120 caractères ; `answerIndex` dans 0..3 |
| `truefalse` | `answerBool` (bool) | — |
| `free` | `answerText` (string) | 1..120 caractères |

⚠️ **Pourquoi quatre champs scalaires `choice0..3` plutôt qu'un array
`choices` de 4 entrées** — c'est le même argument qu'au §1, une couche
plus bas. Avec un array, les rules savent imposer `size() == 4` et rien
d'autre : `choices: [null, 42, {}, []]` passerait. Avec quatre champs
scalaires, **chaque** choix est vérifié `is string` et borné côté
serveur. Le brief fixe le format à « QCM 4 réponses » — le nombre est
donc une constante du design, pas un paramètre, et la forme la moins
idiomatique est ici la seule qui soit réellement gatée. Coût assumé : un
QCM à 3 ou 5 réponses demanderait une migration de schéma, pas un simple
`append`.

⚠️ **Le discriminant `type` est ENFORCÉ, pas décoratif.** Chaque branche
du §4 porte son propre `hasOnly` : un document `type: 'mcq4'` qui
transporterait `answerBool` est refusé, et un `type: 'truefalse'` qui
transporterait `answerIndex` aussi. Sans cette forme, `type` serait une
simple étiquette qu'un client pourrait contredire.

### 2.3 `visibility` : le champ existe, la valeur `'public'` n'existe pas

Le brief demande « privé par défaut, pas de lecture publique large tant
que ce n'est pas demandé explicitement ». Trois lectures possibles, et
c'est la plus stricte qui est retenue :

- ❌ ne pas mettre le champ du tout → une évolution demanderait une
  migration de tous les documents existants ;
- ❌ mettre le champ et accepter `'private'|'public'` dès maintenant → un
  client pourrait écrire `'public'` aujourd'hui, sur des documents que la
  règle de lecture ignore encore ; le jour où la règle honore ce champ,
  une lecture publique s'ouvrirait **rétroactivement** sur des documents
  marqués par erreur, sans qu'aucun changement de ce jour-là ne le dise ;
- ✅ **mettre le champ et n'accepter QUE `'private'`** — c'est ce qui est
  proposé.

⚠️ **ACTÉ par Mathieu le 18 août 2026 : ce troisième choix EST la
décision, et pas un état d'attente.** Keepy Quizz reste privé / non
partagé, sans échéance de révision — donc rien à changer ici, seulement à
ne plus lire ce paragraphe comme provisoire. Un lot futur qui voudrait
ouvrir le partage ne « lèverait » pas une restriction temporaire : il
rouvrirait une décision, avec les deux modifications de `firestore.rules`
ci-dessous ET la question de triche structurelle ci-dessous, toutes deux
intactes.

**Conséquence voulue : ouvrir la lecture publique demandera DEUX
modifications de `firestore.rules`** (élargir les valeurs acceptées en
écriture, puis élargir la règle de lecture), donc deux passages par la
revue et par le gate `main`. La règle de lecture proposée au §4 ne
mentionne d'ailleurs pas `visibility` du tout : elle est owner-only, sans
condition. C'est délibéré — une règle qui lirait déjà `visibility` serait
une porte à moitié ouverte.

⚠️ **Point de conception à trancher AVANT toute mise en commun d'un
questionnaire, signalé maintenant parce qu'il est structurel :** les
bonnes réponses vivent dans le même document que les questions, et **les
Firestore rules ne savent pas masquer un champ à l'intérieur d'un
document** — c'est tout ou rien. Aujourd'hui c'est sans conséquence, le
seul lecteur autorisé étant le propriétaire, qui connaît déjà ses
réponses. Le jour où un autre joueur doit jouer un questionnaire, il
devra lire les questions, donc les réponses, donc pourra tricher. Sortir
de là demande une correction **côté serveur** (Cloud Function ou
équivalent), et **ce projet n'a aucun composant serveur** : Keepy parle à
Firestore en REST direct, sans SDK et sans backend. Ce n'est donc pas un
détail d'implémentation à régler plus tard, c'est une décision
d'architecture qui appartient à Mathieu, le jour où le partage est
demandé.

---

## 3. EXCLUSION KEEPR — respectée, et vérifiée plutôt qu'affirmée

**Aucun champ, aucune référence, aucun mécanisme du schéma ci-dessus ne
permet d'importer ou de lier des données issues de Keepr** (l'application
de messagerie, projet Firebase `keepr-529cc`, entièrement distinct). Le
contenu des questionnaires est saisi à la main par l'utilisateur Keepy
dans les écrans du §7, point.

Cette exclusion est vérifiée sur trois axes, pas seulement déclarée :

1. **L'état du dépôt a été mesuré.** `grep -rniI "keepr\|keepr-529cc"` sur
   tout l'arbre (hors `.git`, `build/`, `.godot/`) rend **quatre
   occurrences, toutes en prose et aucune en code** : `README.md` ligne
   379, qui dit précisément que le classement est « independent from
   `keepr-529cc` », et trois mentions de `CLAUDE.md` qui citent des
   conventions de rédaction. **Zéro** identifiant de projet, zéro clé
   d'API, zéro URL, zéro import, dans aucun `.gd`, `.tscn`, `.json`,
   `.cfg` ou `.html`. Le point de départ est propre.
2. **Le schéma ne contient aucun véhicule d'import.** Pas de champ
   `sourceUrl`, `importedFrom`, `externalRef`, `messageId`, `threadId`,
   `attachment`, pas de chemin de document étranger, pas de blob. Les
   seuls champs de contenu sont `title`, `prompt`, `choice0..3`,
   `answerText` — du texte court, borné, tapé par l'utilisateur.
3. **`hasOnly([...])` rend l'exclusion SERVEUR, pas seulement
   documentaire.** C'est le point qui compte : le jeu de clés est fermé
   côté Firestore. Un futur client — ou un client modifié, la clé d'API
   étant publique par conception — qui tenterait d'écrire un champ
   d'import se ferait refuser l'écriture. Ajouter un tel mécanisme
   demanderait de modifier `firestore.rules`, fichier versionné, déployé
   uniquement par un push sur `main`, donc passé par le gate humain
   (palier 2). L'exclusion n'est pas une promesse tenue par la bonne
   volonté du code client : elle est portée par le même mécanisme que
   l'authentification.

---

## 4. Brouillon de rules — À NE PAS COPIER DANS `firestore.rules` À CE STADE

Ce bloc est une **proposition**. `firestore.rules` et
`.github/workflows/firestore-rules.yml` ne sont pas touchés par ce lot :
un push sur `main` touchant `firestore.rules` déploie immédiatement sur
le projet **global** `keepy-8df91`, donc sur la production de Keepy
Chased, et rien ici n'a été validé device.

```
// ---------------------------------------------------------------
// KEEPY QUIZZ -- BROUILLON. A inserer dans le meme
// `match /databases/{database}/documents` que /scores, sans y toucher.
// ---------------------------------------------------------------

function signedIn() {
  return request.auth != null;
}
// Proprietaire du document DEJA EN BASE (read / update / delete).
function ownsExisting() {
  return signedIn() && resource.data.uid == request.auth.uid;
}
// Proprietaire du document ENTRANT (create / update).
function ownsIncoming() {
  return signedIn() && request.resource.data.uid == request.auth.uid;
}

match /quizzes/{quizId} {

  // Owner-only, sans condition sur `visibility` -- voir la note du
  // paragraphe 2.3 : une regle qui lirait deja ce champ serait une
  // porte a moitie ouverte.
  //
  // Vaut pour `get` ET pour `list`. Consequence pratique cote client :
  // Firestore refuse une requete de liste qu'il ne peut pas prouver
  // conforme a cette regle, donc le :runQuery DOIT porter un
  // fieldFilter `uid EQUAL <mon uid>`. Une liste non filtree est
  // rejetee, ce n'est pas optionnel.
  allow read: if ownsExisting();

  allow create: if ownsIncoming()
    && request.resource.data.keys().hasOnly(
         ['uid','title','visibility','questionCount','createdAt','updatedAt'])
    && request.resource.data.keys().hasAll(
         ['uid','title','visibility','createdAt','updatedAt'])
    && request.resource.data.title is string
    && request.resource.data.title.size() >= 1
    && request.resource.data.title.size() <= 60
    && request.resource.data.visibility == 'private'
    && validCount()
    && request.resource.data.createdAt == request.time
    && request.resource.data.updatedAt == request.time;

  // La difference de fond avec /scores : ici update existe, donc il faut
  // dire explicitement ce qui NE PEUT PAS bouger. Sans les deux lignes
  // d'immuabilite, un proprietaire pourrait reassigner son quiz a un
  // autre uid, ou antidater sa creation.
  allow update: if ownsExisting()
    && request.resource.data.uid == resource.data.uid
    && request.resource.data.createdAt == resource.data.createdAt
    && request.resource.data.keys().hasOnly(
         ['uid','title','visibility','questionCount','createdAt','updatedAt'])
    && request.resource.data.keys().hasAll(
         ['uid','title','visibility','createdAt','updatedAt'])
    && request.resource.data.title is string
    && request.resource.data.title.size() >= 1
    && request.resource.data.title.size() <= 60
    && request.resource.data.visibility == 'private'
    && validCount()
    && request.resource.data.updatedAt == request.time;

  allow delete: if ownsExisting();

  function validCount() {
    return !request.resource.data.keys().hasAny(['questionCount'])
      || (request.resource.data.questionCount is int
          && request.resource.data.questionCount >= 0
          && request.resource.data.questionCount <= 50);
  }

  match /questions/{questionId} {

    allow read: if ownsExisting();

    allow create: if ownsIncoming()
      && commonValid()
      && request.resource.data.createdAt == request.time
      && typeShapeValid();

    allow update: if ownsExisting()
      && request.resource.data.uid == resource.data.uid
      && request.resource.data.type == resource.data.type
      && request.resource.data.createdAt == resource.data.createdAt
      && commonValid()
      && typeShapeValid();

    allow delete: if ownsExisting();

    function commonValid() {
      return request.resource.data.keys().hasAll(
               ['uid','type','prompt','order','createdAt','updatedAt'])
        && request.resource.data.type in ['mcq4','truefalse','free']
        && request.resource.data.prompt is string
        && request.resource.data.prompt.size() >= 1
        && request.resource.data.prompt.size() <= 200
        && request.resource.data.order is int
        && request.resource.data.order >= 0
        && request.resource.data.order <= 199
        && request.resource.data.updatedAt == request.time;
    }

    // C'est CE bloc qui rend `type` contraignant plutot que decoratif :
    // chaque branche ferme son propre jeu de cles, donc un 'mcq4' ne peut
    // pas transporter answerBool, ni un 'truefalse' un answerIndex.
    function typeShapeValid() {
      return (request.resource.data.type == 'mcq4' && mcq4Valid())
        || (request.resource.data.type == 'truefalse' && trueFalseValid())
        || (request.resource.data.type == 'free' && freeValid());
    }

    function choiceValid(c) {
      return c is string && c.size() >= 1 && c.size() <= 120;
    }

    function mcq4Valid() {
      return request.resource.data.keys().hasOnly(
               ['uid','type','prompt','order','createdAt','updatedAt',
                'choice0','choice1','choice2','choice3','answerIndex'])
        && request.resource.data.keys().hasAll(
             ['choice0','choice1','choice2','choice3','answerIndex'])
        && choiceValid(request.resource.data.choice0)
        && choiceValid(request.resource.data.choice1)
        && choiceValid(request.resource.data.choice2)
        && choiceValid(request.resource.data.choice3)
        && request.resource.data.answerIndex is int
        && request.resource.data.answerIndex >= 0
        && request.resource.data.answerIndex <= 3;
    }

    function trueFalseValid() {
      return request.resource.data.keys().hasOnly(
               ['uid','type','prompt','order','createdAt','updatedAt',
                'answerBool'])
        && request.resource.data.keys().hasAll(['answerBool'])
        && request.resource.data.answerBool is bool;
    }

    function freeValid() {
      return request.resource.data.keys().hasOnly(
               ['uid','type','prompt','order','createdAt','updatedAt',
                'answerText'])
        && request.resource.data.keys().hasAll(['answerText'])
        && request.resource.data.answerText is string
        && request.resource.data.answerText.size() >= 1
        && request.resource.data.answerText.size() <= 120;
    }
  }
}
```

**Propriété utile de la forme QCM ci-dessus** : `answerIndex` ne peut pas
désigner un choix vide, puisque les quatre choix sont requis et bornés à
au moins un caractère. La cohérence est obtenue par construction, sans
règle croisée.

⚠️ **Ce brouillon n'a été ni compilé ni déployé.** Il n'existe pas de
compilateur de rules hors ligne : la compilation est un service
(`firebaserules.googleapis.com`), et le seul chemin qui la déclenche dans
ce dépôt est le job CI, lui-même scopé sur `main`. Le mode de défaillance
reste sûr (`compiled successfully` précède strictement `released rules`
dans le log : une erreur de syntaxe échoue le job **sans publier**), mais
il faut le savoir : la première vraie vérification syntaxique de ce bloc
aura lieu au moment de son déploiement.

---

## 5. Ce que les rules NE peuvent PAS garantir — rapporté, pas gaté

Quatre limites réelles, nommées ici plutôt que découvertes plus tard.

1. **Le nombre de questions par quiz n'est pas gatable.** Les rules ne
   savent pas compter les documents d'une sous-collection. Le plafond de
   50 est donc **client-side**. `questionCount` sur le doc parent est
   borné par les rules mais **rien ne vérifie qu'il correspond à la
   réalité** — un client peut écrire `questionCount: 0` sur un quiz de 30
   questions. À traiter comme une valeur d'affichage, jamais comme une
   source de vérité ; l'écran de jeu compte les documents réellement lus.
2. **Pas de suppression en cascade.** Supprimer `quizzes/{id}` ne
   supprime **pas** `quizzes/{id}/questions/*` — Firestore n'a pas de
   cascade. Les questions orphelines restent en base, toujours lisibles
   par leur propriétaire mais inatteignables par la liste des quiz. La
   parade est côté client (supprimer les questions puis le quiz), et elle
   est **best-effort** : une coupure au milieu laisse des orphelines.
   Sans composant serveur, il n'y a pas de tâche de nettoyage possible.
   Impact : consommation de stockage, pas de fuite (l'auth reste requise).
3. **`order` n'est ni unique ni contigu.** Deux questions peuvent porter
   `order: 3`. Une règle ne peut pas voir les autres documents. Le tri
   d'affichage doit donc être déterministe malgré les ex æquo — tri sur
   `(order, questionId)`, jamais sur `order` seul, sinon deux
   rafraîchissements peuvent donner deux ordres différents.
4. **Le texte n'est pas validé au-delà du type et de la longueur.** Un
   `prompt` peut être « aaaa ». C'est hors de portée des rules et ce
   n'est pas un problème de sécurité.
5. **`quizzes.categoryId` n'est PAS vérifié comme référence** (ajouté le
   19 août 2026, voir §11). Les rules valident son TYPE et sa LONGUEUR,
   jamais le fait que la catégorie existe ni qu'elle appartienne au même
   `uid`. Elles le pourraient — `get(/databases/$(database)/documents/
   categories/$(...)).data.uid` — et c'est **délibérément écarté** au §11.
   Conséquence concrète : un `categoryId` peut « pendre » (la catégorie a
   été supprimée), et c'est **l'état normal après toute suppression de
   catégorie**, pas une anomalie. La résolution se fait à l'affichage —
   un id qui ne correspond à aucune catégorie lue retombe dans « Sans
   catégorie » — donc rien n'est jamais perdu ni affiché en erreur.

---

## 6. Contraintes d'assets : `MESHY_SPEC.md` ne s'applique pas (vérifié)

Vérification demandée au titre de « pas de contrainte cachée ». Verdict :
**aucune contrainte de `MESHY_SPEC.md` ne pèse sur un Quizz 2D.** Tout le
document est écrit pour l'installation d'un `.glb` sur un `ModelSlot` de
la scène 3D de Keepy Chased — sa règle n°1 (« un asset peut changer
n'importe quel visuel, il ne peut changer aucune hitbox »), son §2
(pipeline `ModelSlot`), son §8 (contraste hazard/sol contre le plancher
3,0:1) et sa checklist §10 (`AssetContractAudit`, `AlarmRampAudit`,
`PursuerFramingAudit`, `ChargerShapeProbe`) portent tous sur des
colliders et des hazards que Quizz n'a pas.

Quatre points du dépôt restent applicables **si** Quizz reçoit un jour un
habillage graphique — ils ne viennent pas tous de `MESHY_SPEC.md` :

- ⚠️ **Piège payload** (`CLAUDE.md`, mesuré trois fois) :
  `export_presets.cfg` utilise `export_filter="all_resources"`, donc
  **toute** ressource du projet part dans le build, référencée ou non.
  `exclude_filter` couvre aujourd'hui `scripts/dev/*`, `assets_source/*`,
  `docs/*`, `web/*` et `firebase.json`. Toute nouvelle arborescence
  d'assets sources Quizz doit y être ajoutée, et **la vérification se
  fait sur le log `savepack` d'un export réel** (lignes `Storing File`),
  jamais sur la lecture du filtre.
- **Import de textures** : le défaut du projet est **lossless**. La seule
  exception documentée est `title_cover.png` (WebP q=0.7), motivée par une
  source de 2,1 Mo en plein écran. Une texture d'UI Quizz suit le défaut.
- **`gl_compatibility`** (§9) : pas de SDFGI, pas de fog volumétrique, pas
  de SSAO. Sans objet pour de l'UI 2D, mais le rappel vaut si Quizz
  affiche un décor 3D.
- **Identité marécage** : `SwampIdentityAudit` gate « aucun état du jeu ne
  rend une frame bleue ou pastel » sur **quatre états du monde 3D**.
  `TitleScreen.tscn` en a été **délibérément retiré** le 14 août 2026
  (couverture graphique dédiée). Une scène Quizz est dans le même cas :
  elle n'a pas à être dominée par le vert, et cette sonde ne doit pas être
  étendue pour l'y contraindre. Palette de référence si cohérence
  souhaitée : `GameState.SWAMP_SKY = Color(0.062, 0.115, 0.044)`.

---

## 7. Écrans et scènes Godot nécessaires — liste, rien de créé

Convention du dépôt : une scène par écran dans `scenes/`, son script dans
`scripts/ui/`, navigation par `get_tree().change_scene_to_file()`
(`LoginScreen` → `TitleScreen` → `Game`).

| scène | rôle |
|---|---|
| `QuizzMenuScreen.tscn` | Point d'entrée du sous-jeu : deux chemins, « mes questionnaires » et « jouer », plus le retour vers l'ombrelle. |
| `QuizzListScreen.tscn` | Liste des questionnaires de l'utilisateur connecté (titre, nombre de questions, date de mise à jour), avec créer / ouvrir / supprimer. |
| `QuizzEditorScreen.tscn` | Édition d'un questionnaire : son titre, et la liste ordonnée de ses questions (ajouter, éditer, supprimer, réordonner). |
| `QuestionEditorScreen.tscn` | Édition d'UNE question : les champs communs, plus un panneau d'édition différent selon `type` (QCM 4 / vrai-faux / réponse libre). |
| `QuizzPlayScreen.tscn` | Déroulé d'une partie : progression, énoncé courant, validation, passage à la question suivante. Hôte des trois panneaux de réponse ci-dessous. |
| `QuizzAnswerMcq4.tscn` | Panneau de réponse QCM : quatre boutons de choix exclusifs. |
| `QuizzAnswerTrueFalse.tscn` | Panneau de réponse vrai/faux : deux boutons. |
| `QuizzAnswerFree.tscn` | Panneau de réponse libre : un champ de saisie et sa validation. |
| `QuizzResultsScreen.tscn` | Résultat de fin de partie : score, et relecture question par question (réponse donnée contre réponse attendue). |

**Plus un autoload, qui n'est pas un écran mais conditionne tous les
autres :** `scripts/autoload/Quizz.gd`, à écrire sur le contrat exact de
`Leaderboard.gd` — `accept_gzip = false`, court-circuit headless en
première instruction, chaque point d'entrée finit toujours en signal
(succès ou échec), jamais d'exception, jamais de blocage.

Deux remarques de conception sur cette liste :

⚠️ **Le brief demande « un écran de jeu par format de question ». La
proposition ci-dessus le rend comme UN écran hôte + TROIS panneaux, et
c'est un écart délibéré.** Trois écrans complets triplerait la
chrome commune — barre de progression, compteur, énoncé, bouton
« suivant », gestion de fin de questionnaire — sur les trois, alors qu'un
questionnaire mélange les trois formats à l'intérieur d'une **même
partie** : trois `change_scene_to_file()` par question, avec l'état de la
partie à faire survivre à chaque transition. Le découpage par format
reste réel (`QuizzAnswerMcq4/TrueFalse/Free`), il vit juste un cran plus
bas.

✅ **ARBITRÉ par Mathieu le 18 août 2026 : hôte unique + panneaux par
format, c'est-à-dire la proposition ci-dessus.** L'écart avec le brief
d'origine est donc fermé, et la ligne `QuizzPlayScreen.tscn` du tableau
est la forme retenue, pas une suggestion. Un lot Quizz futur n'a plus à
re-poser la question.

✅ **Où Quizz s'accroche EST tranché, et le point d'accroche est LIVRÉ**
— voir §7.1 juste en dessous. Le paragraphe d'origine posait deux options
(second bouton sur `TitleScreen`, ou écran d'ombrelle entre `LoginScreen`
et les sous-jeux) ; Mathieu a retenu la seconde, pour la raison qui y
était déjà donnée — elle vieillit mieux si un troisième sous-jeu arrive.

### 7.1 Le point d'accroche RÉEL — `scenes/Hub.tscn` (livré le 18 août 2026)

Chemins exacts, à lire sur l'arbre plutôt qu'à deviner. Le flux de
démarrage est désormais :

```
run/main_scene = res://scenes/LoginScreen.tscn
        │  (session Google valide)
        ▼
res://scenes/Hub.tscn        <-- l'ombrelle "Keepy's Memorial Quest"
        ├── "Keepy Chased" -> res://scenes/TitleScreen.tscn  (inchangé)
        └── "Keepy Quizz"  -> DESACTIVE, "Bientot disponible"
```

| ce qu'il faut | où |
|---|---|
| la scène hub | `scenes/Hub.tscn` |
| son script | `scripts/ui/Hub.gd` |
| **le bouton à activer** | nœud `CenterContainer/HubPanel/VBoxContainer/QuizzCard/QuizzButton`, exposé par `Hub.gd` sous `quizz_button` |
| le libellé d'attente à retirer | nœud frère `.../QuizzCard/QuizzCaption`, texte `"Bientot disponible"` |
| le modèle à copier | `Hub._on_chased_pressed()` — une ligne, `change_scene_to_file()` |

**Ce qu'une session Quizz future a exactement à faire pour brancher le
gameplay**, et rien de plus :

1. retirer `disabled = true` de `QuizzButton` dans `scenes/Hub.tscn` ;
2. remplacer le texte de `QuizzCaption` (ou masquer le nœud) ;
3. connecter `quizz_button.pressed` dans `Hub._ready()` vers un
   `change_scene_to_file("res://scenes/QuizzMenuScreen.tscn")`, sur le
   modèle exact de `chased_button` juste au-dessus.

⚠️ **`Hub.gd` `push_error` si `QuizzButton` n'est plus `disabled`.** C'est
volontaire et ce n'est pas un obstacle : l'assertion existe pour qu'un
bouton ré-activé sans être connecté ne parte pas en production comme un
contrôle mort. La supprimer fait partie de l'étape 3 ci-dessus — pas
avant, pas séparément.

⚠️ **`scenes/TitleScreen.tscn` n'est PAS le point d'accroche et ne doit
pas le devenir.** Il est l'écran de démarrage propre à Keepy Chased (son
logo, son sous-titre, son « Jouer ») et il est resté **byte-intouché** par
le lot hub. Ajouter Quizz là ferait lire le second sous-jeu comme un mode
du premier.

---

## 8. Notes REST à connaître avant d'écrire `Quizz.gd`

Toutes tirées du fonctionnement réel de `Leaderboard.gd` et du contrat
des rules ci-dessus.

- **Créer un quiz ou une question** : `POST .../documents:commit`, avec
  `currentDocument: {"exists": false}` et **deux** entrées
  `updateTransforms` (`createdAt` et `updatedAt`, chacune
  `setToServerValue: "REQUEST_TIME"`). Un `POST .../documents/quizzes`
  ordinaire ne peut pas satisfaire `createdAt == request.time`.
- **Mettre à jour** : `:commit` avec `currentDocument: {"exists": true}`,
  un `updateMask` qui **exclut** `uid` et `createdAt` (les règles
  d'immuabilité comparent le document résultant à l'existant, donc ne pas
  les envoyer suffit), et une transform sur `updatedAt`.
- **Lister mes questionnaires** : `:runQuery` avec un
  `structuredQuery.where` → `fieldFilter` `uid` `EQUAL`
  `{stringValue: <mon uid>}`. ⚠️ **Sans ce filtre la requête est
  refusée**, pas vide : la règle de lecture étant owner-only, Firestore
  n'exécute que les requêtes qu'il peut prouver conformes.
- **Lister les questions d'un quiz** : `:runQuery` sur le parent
  (`.../documents/quizzes/{quizId}`) avec
  `from: [{"collectionId": "questions"}]`.
- ⚠️ **Index composite requis** pour « mes quiz triés par date » :
  `uid ASC` + `updatedAt DESC`. Une égalité combinée à un `orderBy` sur un
  autre champ n'est pas couverte par les index à champ unique. À créer en
  Console, **ou mieux** : ajouter `"indexes": "firestore.indexes.json"` à
  `firebase.json` — le job `firestore-rules.yml` existant deviendrait
  alors le chemin de déploiement des index aussi. Hors périmètre ici,
  mais c'est la bonne place le jour venu.
- ⚠️ **Un `HTTPRequest` ne fait qu'une requête à la fois** (`ERR_BUSY`
  sinon). `Leaderboard.gd` s'en sort avec un nœud par endpoint parce
  qu'il n'en a que deux. Quizz en a nettement plus (list, get, create,
  update, delete, sur deux collections) : il lui faut soit une file, soit
  un petit pool. À décider à l'implémentation, mais à ne pas découvrir en
  route.
- ⚠️ **Contrairement à `scores`, l'auth est ici REQUISE par les rules.**
  `Leaderboard.gd` envoie le bearer « quand il est disponible, jamais
  exigé » — c'était correct pour des rules qui acceptaient l'anonyme.
  Pour Quizz, une requête sans bearer est un **403 garanti** : `Quizz.gd`
  doit refuser de la lancer et émettre son signal d'échec directement,
  plutôt que dépenser un aller-retour pour un refus certain.
- ⚠️ **Le rafraîchissement du token d'ID est un défaut CONNU et NON
  CORRIGÉ** (`CLAUDE.md`, 18 août 2026) : `web/html_shell.html` publie le
  token depuis `onAuthStateChanged` et non `onIdTokenChanged`, et
  `Auth.gd` coupe son `_process` une fois prêt. Le token détenu est celui
  capturé à la connexion, et un token Firebase expire au bout d'une
  heure. Une session Quizz longue verra donc ses écritures échouer en
  401. Ce défaut préexiste à Quizz et appartient à son propre lot — mais
  Quizz sera **plus exposé que Keepy Chased**, qui n'écrit qu'une fois en
  fin de run là où un éditeur de questionnaire écrit en continu.

---

## 9. Ce que ce lot ne fait PAS

- Ne touche pas `firestore.rules` (le §4 est un brouillon dans un bloc de
  code, rien d'autre).
- Ne touche pas `.github/workflows/firestore-rules.yml`, `firebase.json`,
  `.firebaserc`.
- Ne crée aucune scène, aucun script, aucun autoload, aucun asset.
- Ne modifie aucun fichier existant du dépôt — un seul fichier ajouté.
- N'est mergé ni sur `staging`, ni sur `main`, et n'est pas déployé.

## 10. Questions ouvertes pour Mathieu

⚠️ **Les points 1, 2 et le volet « partage » du point 5 sont CLOS depuis
le 18 août 2026 — ne pas les rouvrir, ne pas les re-proposer.** Ils sont
conservés ici avec leur réponse plutôt que supprimés, pour qu'une session
future voie la décision et pas un blanc.

1. ~~**Point d'accroche de Quizz**~~ → **TRANCHÉ : écran d'ombrelle
   séparé.** `scenes/Hub.tscn` est livré, `LoginScreen` y redirige, et
   `TitleScreen` est resté intouché. Chemins et procédure de branchement
   au **§7.1**.
2. ~~**Un écran de jeu par format, ou un hôte + trois panneaux ?**~~ →
   **TRANCHÉ : hôte unique + panneaux par format**, soit la proposition
   du §7. Le brief d'origine demandait l'inverse ; l'écart est fermé en
   faveur de l'hôte unique.
3. **Correction de la réponse libre** : comparaison exacte après
   normalisation (minuscules, espaces réduits, accents retirés) ? Une
   seule bonne réponse, ou faut-il prévoir des variantes acceptées ? La
   seconde option demanderait un champ de plus, et les rules **ne
   sauraient pas** en valider le contenu s'il est en liste (même limite
   qu'au §1) — la forme validable serait à nouveau des champs scalaires
   numérotés.
4. **Plafonds** : 60 caractères de titre, 200 d'énoncé, 120 de réponse,
   50 questions par questionnaire — valeurs proposées, pas mesurées.
   Elles se durcissent facilement plus tard, elles s'assouplissent
   difficilement (un plafond relâché ne rend pas lisible ce qui a été
   saisi entre-temps).
5. **Partage / lecture publique** → **le volet « pour l'instant » est
   TRANCHÉ : Quizz reste privé / non partagé**, `visibility` n'accepte
   que `'private'`, et c'est une décision actée et non un état d'attente
   (§2.3). Ce qui reste ouvert est uniquement ce qu'il faudrait résoudre
   **si** Mathieu décidait un jour d'ouvrir : la note du §2.3 sur la
   triche structurelle (les réponses vivent dans le document que le
   joueur doit lire, et ce projet n'a aucun composant serveur pour
   arbitrer) devrait être tranchée **avant** ce jour-là, pas pendant.


---

## 11. Catégories (19 août 2026) — `categories/{categoryId}`

Lot `claude/keepy-categories-filtering-0mnv5s`, parti de `staging`.
**Ajout, pas réécriture** : les §1 à §10 ci-dessus restent valables mot
pour mot, y compris la décision `visibility = 'private'` du §2.3, que ce
lot ne touche ni ne mentionne dans ses rules.

### 11.1 Schéma

Collection **top-level**, au même niveau que `quizzes`, **pas** une
sous-collection de celle-ci.

| champ | type | contraintes | rôle |
|---|---|---|---|
| `uid` | string | `== request.auth.uid`, immuable | propriétaire |
| `name` | string | 1..30 caractères | libellé du chip |
| `createdAt` | timestamp | `== request.time` à la création | — |

Aucun autre champ. `hasOnly` refuse tout le reste.

**Pourquoi top-level et pas `quizzes/{quizId}/categories/…`** : une
catégorie appartient à l'UTILISATEUR et sert PLUSIEURS quiz. La nicher
sous un quiz dirait l'inverse (une catégorie par quiz), et « lister
toutes mes catégories » deviendrait un `collectionGroup` — c'est-à-dire
une requête que la règle owner-only ne saurait plus prouver conforme sans
un index de plus. Le raisonnement est le symétrique exact de celui du §1
pour les questions : là-bas la sous-collection gagne parce qu'une question
appartient à UN quiz ; ici elle perd pour la raison inverse.

**Pas de champ `visibility`, et ce n'est pas un oubli.** Une catégorie est
toujours privée : il n'y a aucune décision de partage à trancher à son
sujet. Un champ dont une seule valeur est acceptable existe sur `quizzes`
parce que la question y est ouverte (§2.3) ; ici elle ne l'est pas, donc
le champ n'existe pas — `hasOnly` le refuserait.

**Pas de champ `updatedAt` non plus** : rien ne peut modifier une
catégorie (voir §11.3), donc un champ « dernière modification » ne
pourrait jamais valoir autre chose que `createdAt`.

### 11.2 `quizzes.categoryId` — optionnel, et NON vérifié comme référence

| champ | type | contraintes |
|---|---|---|
| `categoryId` | string (**optionnel**) | absent, OU 1..64 caractères |

Ajouté aux deux `hasOnly` du bloc `quizzes` — **create ET update**.
⚠️ **L'oublier sur `update` aurait cassé `update_quiz()` pour tout quiz
catégorisé** : la règle d'immuabilité compare le document RÉSULTANT, et
un champ conservé hors `updateMask` fait partie de ce résultat ; un
`hasOnly` qui ne le nomme pas l'aurait donc refusé alors même que le
client ne l'envoie pas.

64 et non 20 : le plafond ne doit pas épouser la longueur de l'auto-id du
générateur courant, sinon changer le générateur demanderait un passage par
le gate `main`.

#### La décision `get()`-en-rule : ÉCARTÉE, et pour trois raisons

Les rules PEUVENT valider une référence croisée —
`get(/databases/$(database)/documents/categories/$(request.resource.data.categoryId)).data.uid == request.auth.uid`.
C'est écarté :

1. **Coût.** Un `get()` est une **lecture facturée à chaque évaluation**,
   plafonnée à 10 par requête simple, sur le chemin le plus chaud de
   l'écriture d'un quiz. C'est exactement l'argument qui a fait
   **dénormaliser `uid` sur les questions au §1** — l'appliquer ici est
   une cohérence, pas une nouveauté.
2. **Couplage.** Elle ferait dépendre l'écriture d'un quiz de la
   LISIBILITÉ d'un autre document : supprimer une catégorie rendrait
   soudain **non modifiable** chaque quiz qui la citait. Le mode de
   défaillance serait un `PERMISSION_DENIED` sur une opération sans
   rapport apparent avec la suppression.
3. **Fragilité.** `get()` d'un document absent rend `null`, et lire
   `.data` dessus est une **erreur d'évaluation**, pas un `false` propre —
   il faudrait donc systématiquement le doubler d'un `exists()`.

**Ce qu'un `categoryId` invalide peut faire au pire** : ranger un quiz du
propriétaire dans un tiroir à lui qui n'existe pas. Aucune donnée d'autrui
n'est atteignable par ce champ — **il ne sert jamais de clé de lecture**,
la liste des quiz est filtrée sur `uid` et rien d'autre. C'est donc une
contrainte d'**intégrité**, pas de **sécurité**.

**Validation retenue : client-side, sur deux niveaux.**
`Quizz.create_quiz()` valide la FORME (longueur), et l'écran ne peut
proposer qu'un id qu'il vient lui-même de lister — c'est lui le vrai gate
d'intégrité. Un id pendant est **résolu à l'affichage** :
`QuizzHomeScreen._resolved_category_id()` retombe sur « Sans catégorie »
pour tout id qui ne correspond à aucune catégorie lue. Rien n'est jamais
perdu, rien n'est jamais affiché en erreur.

### 11.3 Rules — `allow update: if false`, et ce que ça coûte

`read` / `create` / `delete` sont owner-only, avec le triplet d'auth
littéral de `scores` et de `quizzes`. **`update` est refusé.**

Motif : le client de ce lot (`create_category` / `list_own_categories` /
`delete_category`) n'écrit jamais de mise à jour, et ouvrir `update`
déploierait une surface que rien n'exerce.

⚠️ **Coût réel, assumé et pas caché** : **renommer une catégorie est
impossible**. Corriger une faute de frappe demande de supprimer puis
recréer, ce qui mint un id **NEUF** — tous les quiz qui pointaient sur
l'ancien se retrouvent avec un `categoryId` pendant (§11.2 : ils
retombent dans « Sans catégorie », jamais en erreur). C'est la même
famille de limite que l'absence de cascade au §5.2.

**Rouvrir demande DEUX choses à la fois** : la règle devient le même bloc
que `update` sur `quizzes` (ownsExisting + `uid`/`createdAt` immuables +
`name` valide + `hasOnly`/`hasAll`), **et** une méthode
`update_category()` côté `Quizz.gd`. Une seule des deux ne sert à rien.
C'est le premier candidat d'un lot de suite.

**Pas de cascade non plus, et il n'y a rien où cascader** : les quiz ne
sont pas les enfants d'une catégorie, ils se contentent d'en nommer une.
Supprimer une catégorie ne réécrit aucun quiz — l'alternative (lister
tous les quiz, en réécrire N) est une boucle best-effort qui peut échouer
à mi-chemin et laisser la collection dans un état pire qu'un id périmé.

### 11.4 Index composites : AUCUN nouvel index n'est requis

⚠️ **C'est une contrainte de conception, pas une constatation** : les deux
requêtes de ce lot ont été écrites POUR ne pas en demander.

| requête | forme | index |
|---|---|---|
| `list_own_quizzes()` | `uid EQUAL` + `orderBy updatedAt DESC` | **inchangée** — l'index `uid ASC` + `updatedAt DESC` déjà créé en Console |
| `list_own_categories()` | `uid EQUAL`, **aucun `orderBy`** | **aucun** — servie par l'index single-field automatique sur `uid` |

Un filtre d'égalité combiné à un `orderBy` sur un **autre** champ n'est
pas couvert par les index à champ unique (c'est ce qui a imposé l'index
de `list_own_quizzes`, §8). Un filtre d'égalité **seul** l'est. C'est
pourquoi `list_own_categories()` **ne trie pas côté serveur** : le tri
alphabétique se fait dans `_dispatch`, sur `(name minuscule, id)`.
Corollaire pour une session future : **ajouter un `orderBy` à cette
requête n'est pas un changement gratuit** — c'est une création d'index
manuelle en Console.

**Le filtrage par catégorie ne passe PAS par le serveur non plus.**
Ajouter un `fieldFilter categoryId` à la requête de liste combinerait une
**seconde** égalité avec l'`orderBy` existant et demanderait un
**troisième** index composite (`uid ASC` + `categoryId ASC` +
`updatedAt DESC`), toujours à créer à la main. L'écran filtre donc le
tableau qu'il a déjà en main. Ce qu'on y gagne en plus : le changement de
chip est **instantané**, sans aller-retour réseau.

⚠️ **Ce choix a une borne, et elle est nommée plutôt que découverte plus
tard** : `list_own_quizzes()` ne pagine pas, donc le filtrage client
suppose que tous les quiz d'un utilisateur tiennent dans une réponse. Le
jour où une pagination devient nécessaire, le filtrage devra redescendre
côté serveur — et c'est **ce jour-là** qu'il faudra créer le troisième
index, pas avant.

### 11.5 API `Quizz.gd`

```
create_category(name)            -> category_created(success, category_id, error)
list_own_categories()            -> categories_fetched(success, categories, error)
delete_category(category_id)     -> category_deleted(success, category_id, error)
create_quiz(title, category_id = "")   # retrocompatible, parametre optionnel
```

Mêmes conventions que le reste du fichier, sans exception : `success` en
premier et `error` en dernier, un signal émis **exactement une fois** par
appel quoi qu'il arrive, court-circuit headless en toute première
instruction, auth exigée même en lecture, une seule `HTTPRequest` en vol
et une file FIFO. `create_quiz` **omet** `categoryId` plutôt que
d'envoyer `""` — les rules bornent le champ à 1..64 **quand il est
présent**, donc une chaîne vide serait un refus.

Il n'y a **pas** d'`update_category()` (§11.3), et **rien n'appelle
encore `delete_category()`** : l'écran ne l'expose pas, parce que
supprimer un tiroir fait silencieusement pendre chaque quiz qui le
nommait et mérite une confirmation que ce lot ne construit pas.
