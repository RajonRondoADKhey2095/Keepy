# Firestore — rules versionnées, durcissement auth, plan Firebase

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 6 section(s), 1147 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## CLASSEMENT CABLE SUR L'AUTH GOOGLE : token + uid ENVOYES, jamais EXIGES — le durcissement des rules est une action MANUELLE post-merge-main (18 aout 2026)

Branche `claude/leaderboard-google-auth-d0yxwu`, partie de `staging`
(`d01618d`, le lot qui a rendu le sign-in Google fonctionnel sur device).
**Un seul fichier de code touché** : `scripts/autoload/Leaderboard.gd`.
Aucune scene, aucun collider, aucune constante de gameplay, aucun `.glb`.

`submit_score()` et `fetch_top_scores()` attachent desormais
`Authorization: Bearer <idToken>` (via `Auth.get_id_token()`), et
`submit_score()` ecrit en plus un champ `uid` (`stringValue`,
`Auth.get_current_uid()`) dans le document Firestore.

### ⚠️ L'ORDRE EST LA CONTRAINTE, PAS LE CODE — les rules sont GLOBALES au projet

**Les Firestore rules de `keepy-8df91` sont uniques pour tout le projet :
`staging` et la prod evaluent le MEME ruleset, il n'existe aucune copie par
environnement.** C'est ce qui interdit de durcir les rules dans cette
session, et ce qui dicte la seule sequence sure :

1. ce lot part sur `staging` (fait) ;
2. validation device, puis merge sur `main` (gate Mathieu, palier 2) ;
3. **SEULEMENT ENSUITE**, durcissement manuel des rules en Console Firebase.

Durcir avant l'etape 2 casserait la PROD a l'instant du changement de
rules : la prod servirait encore un client qui n'envoie ni token ni uid, et
toute soumission de score deviendrait `PERMISSION_DENIED`. Aucune session
agentique ne peut editer les rules (pas d'acces Console) — c'est une action
**manuelle**, et elle appartient a Mathieu.

**Ce que le durcissement devra exiger, une fois `main` a jour** :
`request.auth != null` et `request.resource.data.uid == request.auth.uid`,
en gardant les deux contraintes deja deployees (`name.size() <= 12`,
`createdAt == request.time`).

### « Envoye quand disponible », jamais « requis » — mesure des 4 etats

Le code ne DEPEND jamais de l'auth : signe out, il part exactement comme
avant ce lot (meme URL, meme corps sans `uid`, memes signaux, aucun nouveau
chemin d'erreur). Deux helpers separes, et cette separation est
volontaire : **Auth publie l'uid AVANT le token** (cf. le doc de
`Auth.get_id_token()`), donc les deux questions ne peuvent pas partager une
seule reponse. Un `is_signed_in()` seul laisserait passer un bearer VIDE,
que Google rejette en 401 la ou ne rien envoyer du tout est encore accepte
par les rules d'aujourd'hui.

Mesure sur les VRAIS autoloads (sonde jetable, jamais commitee, supprimee
avant le commit — `ProbeTimeoutAudit` revient a **33 sondes**) :

| etat Auth | `_request_headers()` | `_current_uid()` |
|---|---|---|
| signe out (etat reel headless) | `Content-Type` seul | `''` → champ omis |
| signe in, token pas encore arrive | `Content-Type` seul | `UID_...` → champ ecrit |
| signe in, token present | `Content-Type` + `Authorization: Bearer ...` | `UID_...` |
| session reperdue (token laisse rassis expres) | `Content-Type` seul | `''` |

La ligne signe-out rend **exactement** la liste d'en-tetes d'avant ce lot —
c'est la non-regression du chemin non authentifie, mesuree et pas plaidee.

⚠️ **Etat transitoire a connaitre AVANT le durcissement** : ligne 2 du
tableau — uid ecrit, pas encore de bearer. Inoffensif sous les rules
actuelles ; sous les rules durcies ce serait un `PERMISSION_DENIED`. La
fenetre est etroite (Auth publie le token juste apres l'uid, et l'ecran de
game over arrive bien plus tard que le gate de login), mais elle existe :
si une soumission echoue rarement apres le durcissement, c'est le premier
suspect, pas le reseau.

### Le court-circuit headless reste PRIORITAIRE sur tout le reste — verifie

`if not network_enabled: emit(...); return` reste la **premiere**
instruction des deux points d'entree, donc une sonde ne touche jamais
`Auth`, ne construit jamais d'en-tete, ne lit jamais de token. Mesure
(meme sonde jetable) : `DisplayServer.get_name() = headless`,
`network_enabled = false`, `Auth.is_signed_in() = false`,
`submit_finished` et `top_scores_fetched` emis **exactement une fois
chacun** avec `success = false`. `Auth.gd` se garde par ailleurs
independamment sur `OS.has_feature("web")` — deux gardes distinctes, pour
deux questions distinctes (cf. son en-tete).

### ⚠️ NON VERIFIE, ET C'EST LE RISQUE PRINCIPAL DE CE LOT : les rules
### actuelles acceptent-elles un champ `uid` EN PLUS ?

Si la regle deployee contraint le jeu de champs (`hasOnly([...])`), ajouter
`uid` la ferait echouer **sous les rules ACTUELLES**, c'est-a-dire
exactement la casse que la contrainte d'ordre ci-dessus existe pour eviter.
**Ce point n'a pas pu etre mesure dans cette session** : la politique du
sandbox bloque tout appel vers l'endpoint d'ECRITURE `:commit` de Firestore
(la lecture `:runQuery` passe, elle, et a confirme la forme des documents
existants : `name`/`score`/`nuts`/`glands`/`createdAt`, **aucun `uid`** a ce
jour).

**Recette de verification ZERO-ECRITURE, a rejouer par une session qui en a
le droit** (ou par Mathieu) — elle n'ecrit jamais rien parce que la
precondition ne peut pas etre satisfaite :

envoyer un `:commit` avec `"currentDocument": {"exists": true}` sur un
doc id frais (donc inexistant), en trois variantes —
(A) corps actuel sans `uid`, (B) corps a nom de 13 caracteres (rejet
`PERMISSION_DENIED` deja documente plus haut dans ce fichier, donc temoin
qui prouve que les rules sont bien evaluees), (C) corps avec `uid`.
Lecture : **400 `FAILED_PRECONDITION` = les rules ont ACCEPTE** (et rien
n'a ete ecrit) ; **403 `PERMISSION_DENIED` = les rules ont REFUSE**. Le
temoin (B) doit sortir 403, sinon le test est non concluant et il faut une
autre approche.

**En attendant, le vrai filet est le palier `staging`** : une soumission de
score sur `keepy-staging.vercel.app` qui apparait bien dans le top 10
repond a la question en une manipulation, et c'est precisement pourquoi ce
lot ne va pas plus loin que `staging`.

### Validation

Editeur + templates Godot 4.3-stable installes dans ce sandbox (releases
GitHub officielles, memes que la CI). Import headless **exit 0**, export Web
release **exit 0**, `Leaderboard.gdc` et `Auth.gdc` tous deux compiles dans
le `.pck`. `index.wasm` **35 376 909 octets** — identique au fingerprint
deja consigne pour tout lot qui ne touche pas le code moteur ; `index.pck`
5 445 248 octets (export unique et propre, `build/` supprime avant — a lire
avec la mise en garde permanente sur l'instabilite du `.pck`). Piege payload
tenu (**0** ligne `Storing File: res://assets_source`).

**HUIT sondes rejouees, chacune diffee contre `origin/staging` en worktree
separe : les HUIT sont BYTE-IDENTIQUES sur les DEUX flux (stdout ET
stderr), exit 0 des deux cotes** — `ProbeTimeoutAudit` (33 sondes),
`AssetContractAudit` (12/12 visuels, 0/10 colliders deplaces),
`DeathModelAudit`, `ChargerShapeProbe`, `AlarmRampAudit` (12/12), plus les
trois sondes gameplay seedees `ComboAudit`, `ShrinkAudit`, `ChargerAudit`
(graine 20260806, `--fixed-fps 60`). C'est le bar attendu : le
court-circuit headless fait de ce lot un no-op complet sous sonde, et
l'identite au bit pres le dit plus fort qu'un simple verdict identique.

### Reste ouvert

1. **La question `hasOnly` ci-dessus** — le seul vrai risque, non mesure
   ici, mais tranche par une soumission de score sur staging.
2. **Le durcissement des rules lui-meme** : action MANUELLE, en Console
   Firebase, **apres** le merge sur `main`, jamais avant.
3. Jugement device sur `keepy-staging.vercel.app` : le classement se charge
   toujours, et une soumission aboutit toujours, avec un utilisateur
   Google reellement connecte.

## FIRESTORE RULES VERSIONNÉES + DÉPLOIEMENT AUTOMATIQUE — la Console n'est plus la source de vérité (18 août 2026)

Branche `claude/firestore-rules-automation-337tsq`, partie de `staging`
(`ec81387`). **Lot infra** : aucun fichier de JEU touché — ni scène, ni
`.gd`, ni `.glb`, ni `project.godot`. En particulier
`scripts/autoload/Leaderboard.gd` est **intouché**, comme demandé, et
`git diff` contre `origin/staging` ne rapporte **aucun** chemin sous
`scenes/`, `scripts/` ou `assets/`.

⚠️ **Une exception au « pur » : `export_presets.cfg` A été modifié** —
une ligne d'`exclude_filter`, pour fermer un piège payload que ce lot
introduisait lui-même (voir la section « Piège payload » plus bas). Ce
n'est pas du code moteur et ça ne change aucune scène, mais c'est un
fichier de plus que ce que le brief laissait attendre, donc dit ici
plutôt que passé sous silence.

### `firestore.rules` EST désormais la source de vérité, plus la Console

Trois fichiers nouveaux à la racine :

| fichier | contenu |
|---|---|
| `firestore.rules` | le ruleset, **reproduit à l'octet près** depuis ce qui est déployé en prod |
| `firebase.json` | `{ "firestore": { "rules": "firestore.rules" } }` |
| `.firebaserc` | `{ "projects": { "default": "keepy-8df91" } }` |

⚠️ **Avant ce lot, les rules n'existaient QUE dans la Console Firebase** —
collées à la main, sans historique, sans revue, sans diff possible. Un
`git ls-tree -r origin/main` ne trouvait aucun fichier `firebase`/
`firestore` dans le dépôt. À partir de maintenant : **le fichier gagne**.
Toute édition faite directement en Console sera **écrasée silencieusement**
au prochain push sur `main` touchant `firestore.rules`. Ne plus éditer en
Console.

**Le contenu versionné a été vérifié caractère pour caractère, pas
supposé** : le fichier a été comparé (`diff` + `cmp`) à une re-saisie
indépendante du bloc collé par Mathieu — **byte-identique**. Vérifié aussi :
pur ASCII (aucun caractère non-ASCII), **LF seul** (aucun CR/CRLF), aucun
espace ni tabulation en fin de ligne, aucune tabulation nulle part, 16
lignes, une seule newline finale. Le premier déploiement automatique
re-publie donc exactement le ruleset déjà en place — **un no-op
sémantique**.

⚠️ **Limite honnête de cette vérification, à ne pas surinterpréter** : elle
prouve que le fichier == le bloc collé, **pas** que le bloc collé == ce qui
tourne réellement sur `keepy-8df91`. La clé de compte de service vit dans le
secret GitHub, jamais dans le sandbox — aucune session agentique ne peut
lire les rules live pour les confronter. Si le bloc collé avait dérivé du
déployé, le premier run corrigerait cet écart au lieu d'être un no-op, et
c'est le log du job (qui `cat` le fichier avant de déployer) qui le dirait.

**Cohérence recoupée avec le code, pas seulement avec le brief** :
`Leaderboard.gd` déclare `PROJECT_ID := "keepy-8df91"` (donc `.firebaserc`
pointe bien le projet du jeu) et écrit exactement les champs `name`, `score`,
`nuts`, `glands`, plus `uid` quand un utilisateur est signé, plus `createdAt`
via `setToServerValue: "REQUEST_TIME"` — soit précisément les six clés du
`hasOnly([...])` du ruleset versionné. `hasOnly` autorisant un sous-ensemble,
un document sans `uid` (joueur non signé) reste accepté, comme aujourd'hui.

### Le trigger : `main` UNIQUEMENT + path filter — il PROLONGE le palier 2, il ne le contourne pas

`.github/workflows/firestore-rules.yml` (nouveau) :

```yaml
on:
  push:
    branches: [main]
    paths: ['firestore.rules']
```

**Pourquoi `main` seul, et pourquoi ce n'est pas un contournement du
gate.** Les Firestore rules sont **GLOBALES au projet `keepy-8df91`** :
`staging` et la prod évaluent le MÊME ruleset, il n'existe aucune copie par
environnement (c'est le fait autour duquel tout l'en-tête de
`Leaderboard.gd` est écrit). Un déploiement de rules n'a donc **aucun
palier 1 disponible** — déployer depuis `staging` SERAIT déployer en prod,
en ayant l'air d'une preview. Le palier 2 (autorisation explicite de
Mathieu, après validation device, avant tout merge sur `main`) est par
conséquent **le seul gate qui existe** pour les rules. Lier le trigger à
`main` met les rules DERRIÈRE ce gate au lieu de passer à côté.

**Pas de `workflow_dispatch`, délibérément** : il permettrait un run manuel
depuis n'importe quelle ref et n'importe quel état de fichier — exactement
les deux choses que le trigger existe pour empêcher. Un run échoué se
relance depuis l'UI Actions sans ça.

**Pas de `cancel-in-progress` sur la `concurrency`** (contrairement à
`web-build.yml`) : un build web annulé ne laisse qu'un artefact à jeter, un
déploiement de rules annulé a publié ou pas — un push suivant doit faire la
queue derrière, pas le tuer.

### ⚠️ C'est un FICHIER DE WORKFLOW SÉPARÉ, pas un job dans `web-build.yml` — contrainte structurelle, pas préférence

Le brief demandait un nouveau JOB dans le workflow existant, gaté par
`paths: ['firestore.rules']`. **Les deux sont incompatibles dans GitHub
Actions** : `on.push.paths` est un filtre de **WORKFLOW**, il n'a aucun
équivalent au niveau job. Poser ce filtre sur `web-build.yml` aurait gaté le
job build/export/deploy Web sur `firestore.rules` — donc plus aucun
déploiement web sauf si les rules changent — ce que le brief interdit
explicitement.

Les contournements possibles à l'intérieur de `web-build.yml` étaient tous
pires : un `if:` de job plus un `git diff` de la plage poussée (fragile sur
force-push, premier push et commits de merge, et le workflow tourne quand
même), ou une action tierce de paths-filter (une dépendance de chaîne
d'approvisionnement de plus pour ce qu'Actions fait nativement). Le job
aurait de plus hérité du `cancel-in-progress: true` de `web-build.yml`.

Le filtre est donc gardé **exactement tel que spécifié** — natif, sans
action, sans heuristique de diff — dans le seul endroit où cette syntaxe
peut vouloir dire ce qu'elle doit vouloir dire. **`web-build.yml` est
byte-intouché par ce lot** (`git diff` vide sur ce fichier).

### Authentification : le secret déjà en place, aucun nouveau secret

Secret GitHub utilisé — **nom exact : `FIREBASE_SERVICE_ACCOUNT_KEEPY`**
(JSON complet d'un compte de service capable de déployer les rules de
`keepy-8df91`). Il existait déjà, ce lot n'en crée aucun.

Chaîne : `google-github-actions/auth@v2` avec `credentials_json: ${{
secrets.FIREBASE_SERVICE_ACCOUNT_KEEPY }}` écrit la clé dans un fichier
temporaire et exporte `GOOGLE_APPLICATION_CREDENTIALS` ; `firebase-tools`
(installé par `npm install -g firebase-tools`) le lit tout seul — **ni
`firebase login`, ni `FIREBASE_TOKEN`**. Puis `firebase deploy --only
firestore:rules --project keepy-8df91 --non-interactive`.

Une étape de garde vérifie la présence du secret et échoue avec un message
actionnable, même forme que le `Check Vercel secrets` de `web-build.yml` —
plutôt qu'une erreur d'auth opaque au fond d'un CLI. Une étape `cat
firestore.rules` précède le déploiement : le log du job porte donc
littéralement le ruleset publié, à son SHA.

### Comment changer les rules à l'avenir

1. Éditer `firestore.rules` sur une branche feature.
2. Merger sur `staging` comme d'habitude (palier 1, automatique) — **le job
   ne se déclenche PAS**, le trigger est scopé `main`. C'est voulu : rien ne
   part sur le projet live tant que le gate humain n'est pas passé.
3. Autorisation explicite de Mathieu, puis merge sur `main` (palier 2).
4. Le job fait le reste. Rien à faire en Console.

⚠️ **La contrainte d'ORDRE du durcissement auth reste ENTIÈREMENT valable,
seul son MÉCANISME change.** La section « CLASSEMENT CABLE SUR L'AUTH
GOOGLE » (18 août 2026) décrit le durcissement (`request.auth != null` et
`request.resource.data.uid == request.auth.uid`) comme une action
**manuelle en Console, après le merge sur `main`** du client qui envoie
token et uid. Ce lot ne change pas d'un iota la séquence — durcir avant que
la PROD serve ce client la casserait à l'instant du changement de rules
(`PERMISSION_DENIED` sur toute soumission). Il change seulement l'outil :
le durcissement devient **une édition de `firestore.rules` + un merge sur
`main`**, et non plus un collage en Console. Le point 2 du « Reste ouvert »
de cette section-là se lit désormais ainsi.

### Piège payload : les trois fichiers racine et l'export Godot

`export_presets.cfg` utilise `export_filter="all_resources"` (piège déjà
documenté deux fois dans ce fichier), donc tout nouveau fichier racine
mérite une mesure et non une supposition. **Bien lui en a pris : le piège
s'est déclenché.**

⚠️ **`firebase.json` PARTAIT dans le build — mesuré sur un export réel,
pas prédit.** Le log `savepack` du premier export imprimait `savepack:
step 89: Storing File: res://firebase.json`, et un `grep` sur le `.pck`
retrouvait le contenu littéral du fichier. Cause : **Godot importe `.json`
comme une ressource**. L'argument rassurant qui aurait pu être tenu sans
mesurer — « `vercel.json` est à la racine depuis des mois sans
conséquence » — était en fait le contraire d'une preuve : `vercel.json`
**fuite exactement de la même façon**, ligne `Storing File` comprise, et
personne ne l'avait vu.

**Corrigé au niveau du preset** (`firebase.json` ajouté à
`exclude_filter`, à côté de `scripts/dev/*`, `assets_source/*`, `docs/*`
et `web/*`), puis **re-mesuré sur un export propre** (`build/` supprimé
d'abord — l'auto-contamination déjà documentée) : `Storing File` passe de
**130 à 129** entrées, `.pck` de **5 445 376 à 5 445 280** octets, et
`firestore.rules` / `firebase.json` / `firebaserc` retournent **0
occurrence** dans le pack. `index.wasm` reste à **35 376 909** — le
fingerprint déjà consigné pour tout lot qui ne touche pas le code moteur.

**Les deux autres fichiers sont mesurés comme NON packés**, et n'ont donc
rien reçu : `firestore.rules` (extension inconnue de Godot — l'unique
occurrence de cette chaîne dans le premier `.pck` était la *valeur JSON*
à l'intérieur de `firebase.json`, vérifiée par lecture des octets
alentour, pas le fichier) et `.firebaserc` (fichier caché). Rien n'a été
ajouté « au cas où » : seul le défaut mesuré est fermé.

⚠️ **`vercel.json` est laissé tel quel, délibérément** — il préexiste à ce
lot, il ne pèse que 368 octets, et la CI le copie depuis la racine du
dépôt (`cp vercel.json build/web/vercel.json`), jamais depuis le pack.
Le signaler ici plutôt que le corriger en douce : c'est le même défaut,
il appartient à un autre lot.

### Reste ouvert

1. **Le premier run réel**, qui n'aura lieu qu'au merge sur `main` — le
   trigger étant scopé `main`, **ce lot ne déclenche rien en partant sur
   `staging`**. C'est à ce run-là qu'on verra si le compte de service a
   bien la permission `firebaserules.releases.create` : le brief l'affirme,
   aucune session ne peut le vérifier sans la clé.
   ⚠️ **A EU LIEU le 18 août 2026 au merge `9029bfe`, et il a ÉCHOUÉ** —
   pas sur `firebaserules.releases.create` (jamais atteint) mais sur
   `serviceusage.services.get`, dans le contrôle préalable
   « l'API Firestore est-elle activée ? ». Voir la section « GATE GOOGLE
   SIGN-IN EN PRODUCTION » en fin de fichier : c'est elle qui porte l'état
   à jour, ce point-ci reste écrit tel qu'il l'était avant le run.
2. Le durcissement auth lui-même (point 2 de la section du 18 août), qui
   reste la décision et le calendrier de Mathieu — désormais faisable par
   fichier plutôt qu'en Console.

## GATE GOOGLE SIGN-IN EN PRODUCTION — et le 1er run réel de `firestore-rules.yml` ÉCHOUE sur une permission IAM (18 août 2026)

`staging` (`5065948`) → `main`, commit de merge **`9029bfe`**, `--no-ff`,
aucun conflit, après autorisation explicite de Mathieu (palier 2) et
validation device sur `keepy-staging.vercel.app`. **`main` était
strictement en retard** (`staging..main` VIDE), et l'arbre du commit de
merge est **byte-identique à `staging`** — vérifié AVANT le push, pas
supposé : `git diff HEAD origin/staging` vide et **même hash d'arbre des
deux côtés (`fbac9b1dac8e1ecb68597371a77a24445228ee78`)**. Ce qui part en
prod est donc littéralement l'arbre validé, pas une recomposition.

Règle n°1 vérifiée AU DÉBUT (et pas à la fin, cf. l'incident du 11 août) :
`git fetch --all --prune` puis tri des refs distantes par date — la ref la
plus récente du dépôt EST `origin/staging` (07:07:55 UTC), toutes les
branches auth du lot sont déjà dedans, **aucune session concurrente**.

Contenu du lot (rien de neuf écrit ici, c'est le cumul des sections
précédentes) : gate Google Sign-In devant le jeu (`LoginScreen.tscn` est
désormais `run/main_scene`, autoload `Auth`), classement câblé sur l'auth
(token + uid envoyés quand disponibles, jamais exigés), `firestore.rules`
versionné + `firestore-rules.yml`.

### ⚠️ LE 1er RUN RÉEL DE `firestore-rules.yml` A ÉCHOUÉ — les rules ne sont PAS déployées

Run **#1**, id `32114434279`, job `deploy-firestore-rules`
(`95640666817`), démarré 08:03:31, **échec 08:04:01**. Le trigger, lui,
**fonctionne exactement comme spécifié** : le push sur `main` contenant
`firestore.rules` a bien déclenché le workflow, du premier coup, sans
`workflow_dispatch`. Sept étapes sur huit passent — secret présent, auth
Google Cloud OK, `firebase-tools` installé, `cat firestore.rules` imprime
bien le ruleset à son SHA. **C'est la 8ᵉ, `Deploy Firestore rules`, qui
tombe**, en 2 secondes :

```
=== Deploying to 'keepy-8df91'...
i  deploying firestore
i  firestore: ensuring required API firestore.googleapis.com is enabled...

Error: Request to https://serviceusage.googleapis.com/v1/projects/keepy-8df91/services/firestore.googleapis.com
had HTTP Error: 403, Permission denied to get service [firestore.googleapis.com]
##[error]Process completed with exit code 1.
```

**Cause exacte, lue dans le log et pas devinée** : `firebase deploy` fait
un contrôle préalable « l'API Firestore est-elle activée ? » via
**`serviceusage.googleapis.com`**, et le compte de service du secret
`FIREBASE_SERVICE_ACCOUNT_KEEPY` n'a pas le droit
**`serviceusage.services.get`** sur `keepy-8df91`.

⚠️ **Deux conséquences à ne pas confondre, et la seconde est la plus
importante :**

1. **La permission qui manque n'est PAS celle que « Reste ouvert »
   anticipait.** Cette section attendait le verdict sur
   `firebaserules.releases.create` — **il n'a toujours pas été rendu** :
   l'échec survient AVANT le premier appel à l'API Rules. Corriger le
   droit Service Usage peut donc très bien révéler un SECOND droit
   manquant derrière. Ne pas annoncer le job « réparé » tant qu'un run
   n'est pas sorti vert.
2. **La PROD sert désormais un client qui écrit un champ `uid`, alors que
   le ruleset LIVE n'a pas bougé** — il reste celui de la Console.
   `firestore.rules` versionné ajoute `'uid'` à son `hasOnly([...])` ;
   **si les rules de la Console contraignent le jeu de clés sans `uid`,
   toute soumission de score signée part en `PERMISSION_DENIED`**. Et
   comme le gate impose désormais la connexion, **toutes** les
   soumissions portent un `uid`. C'est exactement le risque nommé au
   « ⚠️ NON VERIFIE » de la section du 18 août ; il n'est **toujours pas
   mesuré** : la recette zéro-écriture (`currentDocument: {exists:true}`)
   a été tentée dans ce sandbox et **bloquée**, cette fois par le
   classifieur d'actions, en plus de l'egress déjà documenté. Le seul
   témoin réel disponible reste une soumission de score depuis un client
   connecté — sur staging comme sur prod, les rules étant globales.

**Rien n'a été retenté à l'aveugle, rien n'a été édité pour contourner** :
ni re-run, ni modification du workflow, ni « firebase deploy --force ».
La sortie est une action IAM en Console, qui n'appartient à aucune session
agentique : accorder au compte de service le rôle
**`roles/serviceusage.serviceUsageConsumer`** (qui porte
`serviceusage.services.get`/`.use`) sur `keepy-8df91`, puis **relancer le
job échoué depuis l'UI Actions** — `workflow_dispatch` est absent par
conception, mais « Re-run failed jobs » fonctionne et rejoue le même SHA
avec le même fichier.

### Web build : vert, et la prod sert bien le build authentifié

CI run **#138** (id `32114434258`), **succès en 3 min 20 s** (08:03:33 →
08:06:53). `Deploy to Vercel [PRODUCTION -- main]` réussi,
`[STAGING -- staging]` correctement **skipped** (push sur `main`). Le log
porte lui-même `▲ Aliased https://keepy-ten.vercel.app`.

Chaîne de preuve du déploiement, lue sur l'API Vercel (indépendante du
CDN) : `dpl_AK8L574k9nUhiVqcdaprDGC4ougc`, **`source: "cli"`**,
`meta.gitRootDirectory = build/web`, `githubCommitSha =
9029bfe…`, `readyState READY`, `alias` contenant
**`keepy-ten.vercel.app`**, prêt à 08:06:49.

⚠️ **La fenêtre de 404 documentée le 12 août s'est reproduite à
l'identique, une fois de plus** : le déploiement NATIF
(`dpl_77YddKeXZbtjd2HUrhx88erjCjvT`, reconnaissable à son
`meta.branchAlias`) a pris la prod à **08:03:29**, la CI l'a remplacée à
**08:06:44** — **~3 min 15 s de 404**, refermés d'eux-mêmes. Toujours pas
corrigé (Settings → Git du projet Vercel, action Console de Mathieu).

**Fingerprint LIVE sur `keepy-ten.vercel.app`, requête fraîche** (l'accès
direct reste bloqué en 403 par l'egress du sandbox — passé par le fetch
Vercel, comme aux lots précédents) : HTTP 200, **`x-vercel-cache: MISS`**,
**`age: 0`**, `last-modified` = l'instant de la requête (l'index est servi
en `no-cache, must-revalidate`) — **trois signaux indépendants qui disent
que ce n'est pas une réponse de cache**, la leçon déjà payée deux fois sur
ce projet. `GODOT_CONFIG.fileSizes` = **`index.pck 5 445 248` /
`index.wasm 35 376 909`** — le `wasm` est identique au fingerprint de tous
les lots qui ne touchent pas le code moteur, et c'est LUI la preuve
d'identité, jamais le `.pck`.

Ce que le HTML servi prouve réellement, dit précisément plutôt que
gonflé : **le pont d'auth est bien EN PRODUCTION** (`window.keepyAuth`,
`keepySignInWithGoogle`, `signInWithRedirect`, et `KNOWN_AUTH_HOSTS`
contenant `keepy-ten.vercel.app`, donc `authDomain` résolu sur l'origine
propre et **pas** de repli cross-origin) ; **aucun en-tête COOP/COEP dans
la réponse**, conformément au fix qui les a supprimés ; et
**`/__/auth/handler` répond 200 avec le vrai widget Firebase**, donc la
réécriture de `vercel.json` est active en prod. Le gate visuel lui-même
est dessiné par Godot dans le canvas : **aucune de ces mesures ne le
« voit »**, elles établissent la chaîne commit → build → déploiement →
origine servie. `run/main_scene = res://scenes/LoginScreen.tscn` à ce SHA
en est le dernier maillon. **Le rendu reste un jugement device.**

### Reste ouvert

1. **Le job rules** — droit `serviceusage.services.get` à accorder, puis
   re-run ; et le verdict sur `firebaserules.releases.create` toujours
   pas rendu (voir plus haut).
2. **Les rules LIVE acceptent-elles le champ `uid` ?** Question inchangée
   depuis le 18 août, mais son enjeu a monté d'un cran : la prod envoie
   désormais ce champ pour de vrai, à chaque soumission.
3. **Le durcissement auth** (`request.auth != null` + `uid ==
   request.auth.uid`) reste la décision et le calendrier de Mathieu — et
   il est de toute façon bloqué derrière le point 1, puisque le chemin de
   déploiement des rules ne fonctionne pas encore.
4. La fenêtre de 404 à chaque push sur `main`, inchangée.

## DURCISSEMENT DES RULES : l'auth devient OBLIGATOIRE en écriture, ET la lecture passe en signed-in — chantier « fermer Keepy » CLOS (18 août 2026)

Branche `claude/firestore-auth-hardening-78qq9o`, partie de `main`
(`12d7539`). **Deux fichiers seulement : `firestore.rules` et ce
document.** Aucun `.gd`, aucune scène, aucun `.glb`, aucune config
d'export — `git diff --stat` contre `origin/main` ne rapporte rien
d'autre. `scripts/autoload/Leaderboard.gd` est **intouché**, comme le
brief le demandait : ce lot est le pendant SERVEUR du lot client du
matin même, pas une seconde passe dessus.

### ⚠️ LE PIPELINE DE DÉPLOIEMENT DES RULES FONCTIONNE — le point 1 du « reste ouvert » de la section précédente est CLOS

La section « GATE GOOGLE SIGN-IN EN PRODUCTION » ci-dessus se termine sur
un run #1 en échec (`serviceusage.services.get` refusé) et sur un verdict
jamais rendu concernant `firebaserules.releases.create`. **Les deux sont
tranchés** : Mathieu a accordé le droit IAM manquant, et la **tentative 4
du même run #1** (id `32114434279`, job `95667590004`) est sortie
**verte**, 09:43:24 → 09:44:05 UTC, 8 étapes sur 8 :

```
i  firestore: ensuring required API firestore.googleapis.com is enabled...
✔  firestore: required API firestore.googleapis.com is enabled
✔  cloud.firestore: rules file firestore.rules compiled successfully
✔  firestore: released rules firestore.rules to cloud.firestore
✔  Deploy complete!
```

**Conséquence à ne pas rater : le ruleset LIVE de `keepy-8df91` EST
désormais le fichier versionné.** La Console a cessé d'être la source de
vérité à 09:44:01 UTC. Et cela **clôt au passage la question ouverte
depuis trois lots** — « les rules acceptent-elles un champ `uid` en
plus ? » : le fichier déployé porte `uid` dans son `hasOnly([...])`,
donc oui, par construction et non par déduction. Il n'y a plus rien à
sonder là-dessus.

### Ce qui change, exactement — le diff sémantique fait QUATRE lignes

Comments mis à part (le fichier en gagne beaucoup, il est désormais
auto-documenté puisque la CI le `cat` avant de le publier), le diff
contre `origin/main` est :

| | avant | après |
|---|---|---|
| lecture | `allow read: if true;` | **`allow read: if request.auth != null;`** |
| écriture, 1ère condition | *(aucune)* | **`request.auth != null`** |
| écriture, uid présent | *(non exigé)* | **`keys().hasAll(['uid'])`** |
| écriture, uid légitime | *(non vérifié)* | **`data.uid == request.auth.uid`** |

**Toutes les validations existantes sont conservées AU CARACTÈRE PRÈS** —
vérifié par un diff commentaires-strippés, pas affirmé : `hasOnly` sur
les six clés, `score is int` dans `[0, 100000]`, `name is string` de
`size() <= 12`, `nuts`/`glands` entiers ≥ 0, `createdAt == request.time`,
`allow update, delete: if false`. Le diff sémantique ne contient que les
quatre lignes du tableau.

⚠️ **`hasAll(['uid'])` n'est PAS redondant avec la comparaison qui suit,
et c'est le seul endroit où ce lot s'écarte de la lettre du brief.** Le
brief tablait sur « un uid absent échouera sur la comparaison » — c'est
vrai, mais par une **erreur d'évaluation** (accès à une clé absente),
pas par un `false` propre. `&&` court-circuite, donc `hasAll` transforme
ce cas en refus explicite et lisible avant que la comparaison ne soit
tentée. Même refus, chemin déterministe.

### La lecture : RESTREINTE, et la condition du brief est vérifiée par mesure

Le brief conditionnait le choix à « aucun écran ne lit le classement
avant authentification — vérifie dans le code plutôt que de supposer ».
**Vérifié, et la condition est remplie :**

- `grep` sur tout `scenes/` + `scripts/` : le **seul** appelant de
  `Leaderboard.fetch_top_scores()` est `scripts/ui/GameOverScreen.gd`
  (deux appels : le précheck de qualification, puis le rendu final).
  Aucun autre lecteur nulle part.
- `GameOverScreen` n'est atteignable qu'après une run, une run qu'après
  `TitleScreen`, et `TitleScreen` qu'après `LoginScreen` — qui est le
  `run/main_scene` depuis le gate du 17 août.
- **La seule porte dérobée est fermée dans la scène elle-même**, vérifié
  et pas supposé : `OfflineButton` (« Continuer (hors web) ») porte
  `visible = false` dans `LoginScreen.tscn`, et n'est démasqué que sur la
  branche `not OS.has_feature("web")` de `_ready()` — qu'un build web
  livré ne prend jamais.

**Ce que la restriction achète** : la collection `scores` cesse d'être
énumérable par quiconque possède la clé API cliente — laquelle est
**publique par conception** (elle est dans le build, `Leaderboard.gd`
ligne 49) et donc à la portée de n'importe qui ouvre les devtools. Avant
ce lot, un `POST :runQuery` anonyme rendait la liste complète des
pseudos ; c'est exactement ce qui a servi de mesure de référence
ci-dessous.

**Ce que ça n'achète PAS, et qui est dit plutôt que passé sous silence** : l'inscription
Google est ouverte à tout le monde, donc n'importe quel compte Google
peut toujours lire. La restriction élève le coût d'un scrape (il faut
désormais un compte et un token), elle ne rend pas les données privées.
C'est une porte fermée, pas un coffre.

⚠️ **RÉSIDU ACCEPTÉ, mesuré dans le code et non découvert plus tard** :
un joueur bien connecté dont le round-trip `getIdToken()` n'a jamais
abouti (la branche `.catch` de `html_shell.html`) n'envoie AUCUN header
`Authorization` — `Leaderboard._request_headers()` refuse délibérément
d'émettre un bearer vide. Pour lui, `request.auth` est null et la
lecture échoue là où elle passait avant. **Elle dégrade en « Classement
indisponible », jamais en crash**, et ce même joueur ne peut de toute
façon plus écrire : le classement lui est uniformément indisponible au
lieu d'être à moitié fonctionnel. C'est le seul chemin où la
restriction de lecture coûte quelque chose.

### Tâche 3 — `Leaderboard.gd` face à un `PERMISSION_DENIED` : MESURÉ, pas supposé

Sonde jetable `scripts/dev/LeaderboardDeniedProbe.tscn` (jamais commitée,
supprimée avant le commit — `ProbeTimeoutAudit` revient à **33 sondes**).
Elle pilote les **vrais** handlers de réponse de l'autoload livré
(`_on_submit_completed` / `_on_query_completed`) avec le corps exact que
Firestore renvoie sur un refus, plutôt qu'un stub : la question porte sur
ce que le code livré fait de cette réponse, et rien d'autre dans la
chaîne ne peut changer le verdict.

```
=== LEADERBOARD PERMISSION_DENIED PROBE ===
  network_enabled=false (headless short-circuit)
  Auth.is_signed_in=false uid='' token=''
  headers signed-out: ["Content-Type: application/json"]
    OK    signed-out sends no Authorization header
    OK    signed-out uid is empty (field omitted)
    OK    submit_finished emitted exactly once
    OK    submit_finished carried success=false
    OK    top_scores_fetched emitted exactly once
    OK    top_scores_fetched carried success=false
    OK    top_scores_fetched carried an empty array
    OK    submit_score short-circuits to one failure signal
    OK    fetch_top_scores short-circuits to one failure signal
  --- 0 failure(s) ---        exit 0
```

**9 assertions sur 9 OK, exit 0.** Ce que stderr porte est exactement ce
qu'il doit porter : deux `push_warning` (`result=0, code=403, ...
PERMISSION_DENIED`), **pas** un `push_error`, **pas** une exception — le
403 traverse la même branche que n'importe quel échec réseau, et les deux
signaux partent avec `success = false` une fois chacun. Aucun appelant
n'a de branche à ajouter.

Les trois chemins par lesquels un `uid` peut manquer sont donc couverts,
et **aucun ne crashe** :
1. **Session perdue en cours de partie** (`Auth.is_signed_in()` repasse à
   faux entre le gate et l'écran de game over) → uid omis, pas de bearer,
   403 côté serveur → `submit_finished(false)` → le label « Score non
   synchronisé (hors ligne ?) » s'affiche. Exactement le chemin déjà
   emprunté hors ligne.
2. **Éditeur / desktop** (`OfflineButton`) → jamais signé, donc 403 sur
   les deux appels au lieu de 200. Chemin de développement uniquement,
   dégradation identique.
3. **Sondes headless** → `network_enabled = false` en toute première
   instruction des deux points d'entrée : aucune requête n'est jamais
   construite, `Auth` n'est jamais interrogé. Re-mesuré ci-dessus.

### ⚠️ DÉFAUT TROUVÉ EN LISANT LE CODE, NON CORRIGÉ ICI — le token n'est JAMAIS rafraîchi

`web/html_shell.html` publie l'`idToken` depuis **`onAuthStateChanged`**,
qui ne tire que sur un changement d'état d'authentification — pas depuis
`onIdTokenChanged`, qui est le callback tirant sur les rafraîchissements.
`Auth.gd` coupe par ailleurs son `_process` dès `_ready_reported`
(`set_process(false)`), donc plus aucun poll ne va rechercher une valeur
plus fraîche. **Le token que Godot détient est celui capturé une fois, à
la connexion.** Un token d'ID Firebase expire au bout d'une heure.

Conséquence attendue pour une session PWA laissée ouverte plus d'une
heure : le bearer envoyé est expiré, et Firestore répond **401** avant
même d'évaluer la moindre règle. **Ce n'est PAS créé par ce lot** — un
bearer invalide était déjà rejeté sous les anciennes règles, et le lot
client de ce matin est celui qui a introduit l'envoi du bearer. Ce lot ne
déplace donc rien sur cet axe.

⚠️ **Non mesuré, et dit comme tel** : le 401-sur-token-expiré est le
comportement documenté de l'API, pas une observation faite ici (il
faudrait une session réelle vieille d'une heure). Le correctif naturel
est une ligne de shell (`onIdTokenChanged` au lieu de
`onAuthStateChanged`), mais c'est un changement de JS embarqué dans un
lot de rules + doc : **délibérément laissé à son propre lot** plutôt que
poussé sur `main` sans validation device dans le même commit qu'un
durcissement de sécurité.

### Vérification de bout en bout : la lecture anonyme, AVANT et APRÈS

L'egress vers `firestore.googleapis.com` fonctionne depuis ce sandbox
(contrairement à ce qu'une session précédente avait constaté), donc la
mesure est réelle et non déduite. Même requête exacte que
`Leaderboard.fetch_top_scores()` (`POST :runQuery`, `orderBy score DESC`),
sans aucun header `Authorization` :

| moment | HTTP | corps |
|---|---|---|
| **avant** (rules d'avant ce lot, live) | **200** | la liste réelle des scores, pseudos compris |
| **après** (rules de ce lot, live) | **403** | `{"error":{"code":403,"message":"Missing or insufficient permissions.","status":"PERMISSION_DENIED"}}` |

**La chronologie est serrée au point d'être une preuve de causalité, pas
une corrélation** : le job a imprimé `released rules` à **10:32:59,77
UTC**, et la même requête anonyme, rejouée en boucle toutes les 15 s
depuis avant le push, est passée de **200 à 10:32:45** à **403 à
10:33:01** — deux secondes après la publication. Rien d'autre n'a touché
ce projet dans cet intervalle.

⚠️ **Le pendant en ÉCRITURE n'a PAS été testé, et c'est un choix, pas un
oubli.** La recette « zéro-écriture » consignée plus haut dans ce fichier
(`currentDocument: {"exists": true}` sur un doc id neuf, en lisant 400
`FAILED_PRECONDITION` = accepté contre 403 = refusé) **NE FONCTIONNE
PAS** : mesurée ici, elle rend **403 sur toutes ses variantes, témoin
compris**, parce qu'`exists: true` fait classer l'opération en **UPDATE**
et non en CREATE — or `allow update: if false`. Elle ne peut donc rien
distinguer. La seule alternative aurait été un vrai `exists: false`,
c'est-à-dire écrire une ligne parasite indélébile (`allow delete: if
false`) dans la collection de production. **Le test de lecture ci-dessus
suffit** : il prouve que le ruleset publié est bien celui en vigueur et
que `request.auth != null` est réellement évalué — et la condition
d'écriture vient du **même fichier, publié par la même release**.

**Corollaire pour une future session : ne pas rejouer la recette
zéro-écriture, elle est fausse.** Le paragraphe qui la décrit reste
au-dessus pour l'historique ; ce paragraphe-ci est le correctif.

### Validation

Éditeur Godot 4.3-stable installé dans ce sandbox pour ce lot (release
GitHub officielle). Import headless **exit 0**. Trois sondes rejouées
après retrait de la sonde jetable, **toutes exit 0** :
`ProbeTimeoutAudit` (**33 sondes**, retour exact à la baseline),
`AssetContractAudit` (**12/12 visuels, 0/10 colliders déplacés**),
`DeathModelAudit` (CHARGER seul fatal, capture au 2ᵉ contact pour les
cinq autres). **Non-applicabilité assumée et pas déguisée en preuve** :
aucune sonde de ce dépôt ne parle à Firestore ni ne lit un fichier de
rules — elles ne peuvent pas valider ce lot, elles peuvent seulement
attester qu'il n'a rien cassé, ce qui est déjà garanti par un diff qui
ne touche aucune ressource Godot. Aucun export web n'est
rejoué : ce lot ne touche **aucune** ressource Godot, donc rien de ce que
l'export empaquette ne change — le `.pck` et l'`index.wasm` du build en
production restent ceux du merge `9029bfe`, et le job `web-build.yml` ne
se déclenchera de toute façon que pour reconstruire un arbre identique
côté jeu.

`firestore.rules` re-vérifié comme au lot précédent : **ASCII pur, LF
seul, aucune tabulation, aucun espace en fin de ligne**. La compilation
du ruleset, elle, est **serveur** (`firebaserules.googleapis.com`) — il
n'existe pas de compilateur hors ligne, donc le seul contrôle possible
est celui de la CI. **Mode de défaillance sûr, vérifié dans l'ordre des
étapes du log ci-dessus** : `compiled successfully` précède strictement
`released rules`, donc une erreur de syntaxe fait échouer le job **sans
publier**, laissant les rules live intactes.

### Le déploiement automatique déclenché PAR ce merge : run #2, VERT

`staging` (`e51278b`) → `main`, commit de merge **`8b70b24`**, `--no-ff`,
aucun conflit. `main` était **strictement en retard** (`staging..main`
vide dans l'autre sens) et l'arbre du commit de merge est
**byte-identique** à celui de `staging` et de la branche feature — même
hash d'arbre `3035ee1c...` sur les trois, vérifié avant le push.

Le push a déclenché `firestore-rules.yml` **tout seul**, comme prévu :
run **#2** (id `32127251623`, job `95680442384`), **tentative 1**,
10:32:26 → 10:33:02 UTC, **36 secondes**, `conclusion: success`, **8
étapes sur 8**.

```
i  firestore: ensuring required API firestore.googleapis.com is enabled...
✔  firestore: required API firestore.googleapis.com is enabled
✔  cloud.firestore: rules file firestore.rules compiled successfully
i  firestore: uploading rules firestore.rules...
✔  firestore: released rules firestore.rules to cloud.firestore   [10:32:59,77]
✔  Deploy complete!
```

**Le ruleset durci est en vigueur sur `keepy-8df91` depuis 10:32:59 UTC**,
et c'est vérifié sur le service lui-même (tableau ci-dessus), pas
seulement dans un log de CI.

⚠️ **Le même push déclenche AUSSI `web-build.yml`**, qui reconstruit et
redéploie la prod — donc **une fenêtre de 404 d'environ 3 minutes**, la
même que celle documentée plus haut. Le build est pourtant identique côté
jeu (aucune ressource Godot dans le diff) : c'est le prix fixe d'un push
sur `main`, pas une conséquence de ce lot.

### Reste ouvert

1. **Le rafraîchissement du token** (`onIdTokenChanged`), ci-dessus —
   le seul vrai défaut connu du chemin auth, à traiter dans son propre
   lot avec validation device.
2. **Jugement device** : une soumission de score réelle par un joueur
   Google connecté doit toujours aboutir sur `keepy-ten.vercel.app`, et
   le top 10 doit toujours s'afficher. C'est la seule chose qu'aucune
   mesure de cette session ne couvre — elles prouvent que la porte est
   fermée, pas que la clé du joueur l'ouvre encore.
3. La fenêtre de 404 à chaque push sur `main`, inchangée.


## RULES KEEPY QUIZZ PORTÉES DANS `firestore.rules` — écrites, PAS encore déployées (18 août 2026)

> ⚠️ **CLÔTURE — DÉPLOYÉES EN PRODUCTION le 18 août 2026 à 12:52:52 UTC**
> (run **#3** de `firestore-rules.yml`, id `32139090001`, merge `e73c796`).
> Le « PAS encore déployées » du titre et le §« CE LOT N'A RIEN DÉPLOYÉ »
> ci-dessous décrivent l'état de ce lot **au moment où il a été écrit** ;
> ils ne sont pas réécrits, pour ne pas perdre la trace de la séquence
> réelle (palier 1 puis palier 2). La section « Merge en production » en
> fin de section porte l'état à jour.

Branche `claude/keepy-quiz-firestore-rules-r1crb3`, partie de `main`
(`7fcada5`). **Deux fichiers : `firestore.rules` et ce document.** Aucun
`.gd`, aucune scène, aucun `.glb`, aucune config d'export — `git diff
--stat` contre `origin/main` ne rapporte rien d'autre. Le brouillon du §4
de `docs/QUIZZ_SPEC.md` est porté tel quel dans le fichier réel ; le
brouillon lui-même n'est pas modifié.

### ⚠️ CE LOT N'A RIEN DÉPLOYÉ — la version LIVE reste celle du 18 août 10:32:59 UTC

**Le ruleset en vigueur sur `keepy-8df91` est toujours celui publié par le
run #2 de `firestore-rules.yml` (id `32127251623`)** : durcissement auth de
`scores`, sans une ligne de Quizz. C'est mécanique et pas une prudence
particulière — le workflow est `on.push.branches: [main]` +
`paths: ['firestore.rules']`, or ce lot part sur `staging`.

⚠️ **Précision qui corrige une formulation courante : un push sur
`staging` ne déclenche RIEN.** Le déclenchement automatique est bien le
comportement voulu et déjà éprouvé (run #1 tentative 4 et run #2, tous deux
verts), mais il est attaché au **merge sur `main`**, pas au palier 1. Le
jour où Mathieu autorise ce merge, le job partira **tout seul**, sans
action manuelle, et publiera ce fichier sur le projet **global** — donc sur
la production de Keepy Chased en même temps que sur staging. C'est
exactement pourquoi ce lot s'arrête à `staging` : les rules n'ont pas de
palier 1 disponible, le gate humain est le seul qui existe.

Mode de défaillance sûr, déjà mesuré dans le log du lot précédent :
`compiled successfully` précède **strictement** `released rules`, donc une
erreur de syntaxe échoue le job **sans publier** et laisse les rules live
intactes.

### Ce qui est ajouté — purement ADDITIF, mesuré et pas plaidé

`git diff --numstat origin/main -- firestore.rules` rend **`192  0`** :
192 lignes ajoutées, **zéro retirée**. C'est la preuve la plus forte que
les rules `scores` ne sont pas touchées, et elle est doublée d'un `cmp` :
le bloc `match /scores/{scoreId}` (47 lignes) et l'en-tête du fichier
(40 lignes) sont **byte-identiques** à `origin/main`.

| bloc | read | create | update | delete |
|---|---|---|---|---|
| `scores/{scoreId}` | signed-in | validé | **interdit** | **interdit** |
| `quizzes/{quizId}` | owner-only | validé | validé | owner-only |
| `quizzes/{quizId}/questions/{questionId}` | owner-only | validé | validé | owner-only |

Le triplet d'auth est **littéralement** celui de `scores` (`hasOnly` /
`hasAll(['uid'])` / `uid == request.auth.uid`), pour qu'un relecteur voie
le même motif aux deux endroits et non deux variantes à comparer.

⚠️ **Un seul écart avec le brouillon du §4, et il est syntaxique, pas
sémantique : les `function` sont HISSÉES au-dessus de leur premier
appel.** Le brouillon déclarait `validCount()` après les `allow` qui
l'utilisent, et `typeShapeValid()` avant ses propres callees. Rien ne
garantit hors ligne que le compilateur de rules hisse les déclarations, et
un `Function is undefined` coûterait un aller-retour complet par le gate
`main` pour un défaut de mise en page. Vérifié par script sur le fichier
livré : **0 violation déclare-avant-usage**, et **les 10 fonctions sont
réellement utilisées** (aucune déclaration morte).

### Vérification `hasOnly` — auditée par script, pas relue à l'œil

Fermeture transitive des appels de fonctions calculée sur le fichier
livré, pour chaque `allow` :

| `allow` | `hasOnly` | `hasAll` | auth | `visibility == 'private'` |
|---|---|---|---|---|
| quizzes `create` | ✅ | ✅ | ✅ | ✅ |
| quizzes `update` | ✅ | ✅ | ✅ | ✅ |
| questions `create` | ✅ *(via `typeShapeValid`)* | ✅ | ✅ | s.o. |
| questions `update` | ✅ *(via `typeShapeValid`)* | ✅ | ✅ | s.o. |
| tous les `read` / `delete` | s.o. — aucune donnée entrante | — | ✅ | s.o. |

**Aucun chemin d'écriture ne peut faire entrer un champ hors schéma.** Sur
les questions, le porteur du `hasOnly` est `typeShapeValid()` et non
`commonValid()` : chaque branche de type ferme son **propre** jeu de clés,
donc un `mcq4` ne peut pas transporter `answerBool` ni un `truefalse` un
`answerIndex`. C'est ce qui rend `type` contraignant plutôt que décoratif —
et les deux `allow` exigent `typeShapeValid()`, donc il n'existe pas de
chemin qui n'aurait que `commonValid()`.

**`visibility` ne peut jamais valoir autre chose que `'private'` à la
création** : la valeur est comparée par égalité stricte, ET le champ est
dans le `hasAll`, donc il ne peut pas non plus être omis. Même paire sur
`update` — un quiz créé privé ne peut pas être élargi par une mise à jour.

### Comment un élargissement futur de `visibility` se ferait — DEUX edits distincts

C'est la propriété qui a fait retenir « le champ existe, la valeur
`'public'` n'existe pas » plutôt que « pas de champ du tout » ou
« accepter `'public'` tout de suite » (`docs/QUIZZ_SPEC.md` §2.3, décision
actée par Mathieu le 18 août 2026 — **une décision, pas un état
d'attente**). Ouvrir le partage demanderait :

1. **Édit n°1 — élargir l'ÉCRITURE** : remplacer
   `visibility == 'private'` par une appartenance à un ensemble, dans les
   deux `allow` (`create` **et** `update`) du bloc `quizzes`.
2. **Édit n°2 — élargir la LECTURE** : la règle de lecture actuelle est
   `allow read: if ownsExisting();`, owner-only **sans mentionner
   `visibility` du tout**. C'est délibéré : une règle qui consulterait déjà
   ce champ serait une porte à moitié ouverte, et l'édit n°1 seul
   l'ouvrirait rétroactivement sur tout document marqué entre-temps.

**Deux edits = deux passages par le gate `main`**, donc deux revues. Et
⚠️ **la question de la triche structurelle doit être tranchée AVANT le
premier des deux** : les bonnes réponses vivent dans le document que le
joueur doit lire, les rules ne savent pas masquer un champ à l'intérieur
d'un document (c'est tout ou rien), et ce projet n'a **aucun composant
serveur** pour arbitrer — Keepy parle à Firestore en REST direct. Ce n'est
pas un détail d'implémentation à régler plus tard.

### Limites ACCEPTÉES, reportées dans le fichier lui-même — pas des bugs à corriger

Recopiées en tête du bloc Quizz de `firestore.rules` pour qu'un relecteur
du seul fichier de rules les ait sous les yeux (`docs/QUIZZ_SPEC.md` §5) :
le **nombre de questions par quiz n'est pas gatable** (les rules ne savent
pas compter les documents d'une sous-collection — le plafond de 50 est
client-side, et `questionCount` est borné mais **jamais** confronté à la
réalité) ; **pas de suppression en cascade** (les questions orphelines
restent en base, lisibles par leur seul propriétaire — coût de stockage,
pas de fuite) ; **`order` n'est ni unique ni contigu** (trier sur
`(order, questionId)`, jamais sur `order` seul).

### Validation

⚠️ **Il n'existe pas de compilateur de rules hors ligne** — la compilation
est un service (`firebaserules.googleapis.com`) et la clé de compte de
service vit dans le secret GitHub, jamais dans un sandbox. La première
vraie vérification syntaxique aura donc lieu au déploiement, avec le mode
de défaillance sûr rappelé plus haut. Ce qui a pu être vérifié ici l'a été
**par script sur le fichier livré**, pas par relecture : accolades
équilibrées (21/21, profondeur finale 0, jamais négative), **ASCII pur**,
**LF seul**, aucune tabulation, aucun espace en fin de ligne, newline
finale unique — la même liste de contrôles que les deux lots rules
précédents.

**Aucune sonde rejouée, et c'est une non-applicabilité assumée, pas une
omission déguisée en preuve** : ce lot ne touche **aucune** ressource
Godot, donc rien de ce que l'export empaquette ne change, et aucune sonde
de `scripts/dev/` ne lit un fichier de rules ni ne parle à Firestore —
elles ne peuvent pas valider ce lot. **Aucun Godot n'est de toute façon
installé dans ce sandbox** (ni éditeur ni templates). Piège payload sans
objet et déjà mesuré au lot précédent : `firestore.rules` n'est pas une
ressource Godot (0 occurrence dans le `.pck`), et `CLAUDE.md` non plus.

### Reste ouvert

1. **Le déploiement lui-même** — merge `staging` → `main`, gaté par
   Mathieu, et c'est ce merge qui déclenchera le job. Rien de ce lot n'est
   en vigueur avant.
2. **La première compilation réelle** de ce bloc, qui n'a jamais eu lieu
   (voir ci-dessus).
3. **Aucun client n'existe encore** : `Quizz.gd`, les écrans du §7 et le
   branchement du bouton grisé du hub restent à écrire. Ces rules décrivent
   un contrat que rien n'exerce pour l'instant — et `docs/QUIZZ_SPEC.md` §8
   porte déjà les pièges REST à connaître avant de l'écrire (deux
   `updateTransforms` à la création, `updateMask` excluant `uid`/
   `createdAt` à la mise à jour, `fieldFilter uid EQUAL` **obligatoire**
   sur toute liste, index composite `uid ASC` + `updatedAt DESC`, un seul
   `HTTPRequest` en vol à la fois, et le bearer **exigé** — un appel sans
   token est un 403 garanti, à ne pas dépenser en aller-retour).
4. Le rafraîchissement du token (`onIdTokenChanged`, jamais rebranché) —
   inchangé, et **Quizz y sera plus exposé que Chased**, qui n'écrit
   qu'une fois en fin de run.

### Merge en production (18 août 2026, autorisation explicite de Mathieu)

`staging` (`54eb498`) → `main`, commit de merge **`e73c796`**, `--no-ff`,
aucun conflit. **Ce merge est le premier à publier des rules Quizz sur
`keepy-8df91`** — le projet est GLOBAL, donc ce ruleset est celui
qu'évaluent staging ET la prod de Keepy Chased.

Règle n°1 vérifiée **AU DÉBUT** (leçon de l'incident du 11 août) :
`git fetch --all --prune` puis tri de toutes les refs distantes par date de
commit — la plus récente du dépôt EST `origin/staging` (12:37:18 UTC),
immédiatement suivie de `claude/keepy-quiz-firestore-rules-r1crb3`
(12:36:59), les deux appartenant à ce lot. **Aucune session concurrente.**

`main` était **strictement en retard** (`staging..main` VIDE) et l'arbre du
commit de merge est **byte-identique à `staging`**, vérifié AVANT le push :
`git diff HEAD origin/staging` vide **et même hash d'arbre des deux côtés
(`65685e1d1b9d0c2cd2b65273b85b9d0411a3fbd9`)**, `firestore.rules` au même
md5 (`13baa15cb3ee7d7696431408f6ccaaaf`).

#### ⚠️ RÉSULTAT DU JOB RULES — run #3, VERT, et le mode de défaillance sûr a tenu

Run **#3** (id `32139090001`, job `95717216243`), **tentative 1**,
12:51:41 → 12:52:55 UTC, **71 s**, `conclusion: success`, **8 étapes sur 8**
— aucun des deux échecs IAM du run #1 ne s'est reproduit
(`serviceusage.services.get` passe, et **`firebaserules.releases.create` rend
enfin son verdict : il passe aussi**).

**L'ordre exigé par la tâche est vérifié à l'horodatage, pas supposé** — la
compilation précède STRICTEMENT la publication, donc une erreur de syntaxe
aurait fait échouer le job **sans rien publier**, laissant les rules live
intactes :

```
12:52:50.94  ✔  firestore: required API firestore.googleapis.com is enabled
12:52:51.83  i  cloud.firestore: checking firestore.rules for compilation errors...
12:52:52.25  ✔  cloud.firestore: rules file firestore.rules compiled successfully
12:52:52.44  i  firestore: uploading rules firestore.rules...
12:52:52.89  ✔  firestore: released rules firestore.rules to cloud.firestore
12:52:52.89  ✔  Deploy complete!
```

**C'était la PREMIÈRE compilation réelle du bloc Quizz** (point 2 du « Reste
ouvert » ci-dessus) : il n'existe pas de compilateur de rules hors ligne, la
compilation est un service. Elle passe du premier coup — les 21 accolades
équilibrées et l'hygiène ASCII/LF vérifiées par script sur la branche
n'avaient jamais prouvé que la SYNTAXE Firestore était bonne, seulement
qu'elle était plausible. Elle l'est.

**L'étape `Show resolved rules file` imprime le fichier ENTIER au SHA
`e73c7962…`**, donc le log porte littéralement ce qui a été publié — le bloc
`/scores` y figure verbatim, `allow read: if request.auth != null;` et les
huit lignes de validation de `create` comprises.

⚠️ **Piège de lecture de ce log, à connaître avant de crier à la corruption :
GitHub masque `{` et `}` en `***`** (le secret `FIREBASE_SERVICE_ACCOUNT_KEEPY`
est un JSON dont les accolades sont des lignes de secret à part entière, donc
Actions les censure partout dans le log). `function signedIn() ***` est
`function signedIn() {`. Le log est donc **inutilisable pour une comparaison
byte-à-byte**, et parfaitement lisible pour tout le reste.

#### Le bloc `/scores` n'a pas bougé — le vrai risque de ce merge

C'était le risque implicite, pas « est-ce que les nouvelles rules
marchent ». Trois preuves indépendantes, dans l'ordre de force :

1. **Byte-identité en amont, mesurée avant le merge** : les **68 premières
   lignes** de `firestore.rules` (en-tête + bloc `/scores` complet jusqu'à
   son accolade fermante) sont **byte-identiques** entre `origin/main` et
   `origin/staging` (`cmp` silencieux). Le diff est purement additif : il
   commence à la ligne 66, **après** `allow update, delete: if false;`.
2. **Release atomique d'un fichier unique** : `firebase deploy --only
   firestore:rules` publie LE fichier, il ne fusionne pas des blocs. Un
   `/scores` inchangé dans le fichier est donc un `/scores` inchangé en
   vigueur — c'est structurel, pas une inférence.
3. **Mesure côté service, avant ET après le déploiement** — la requête
   `:runQuery` **exactement** celle de `Leaderboard.fetch_top_scores()`
   (`orderBy score DESC, limit 10`), sans header `Authorization` :

   | | avant (12:50 UTC) | après (12:54 UTC) |
   |---|---|---|
   | `/scores` `:runQuery` anonyme | **403 PERMISSION_DENIED** | **403 PERMISSION_DENIED** |
   | `/quizzes` `:runQuery` anonyme | 403 | 403 |

   Les corps de réponse sont **byte-identiques** avant/après (`cmp`
   silencieux sur les deux collections). Un `GET /documents/scores` anonyme
   rend 403 lui aussi.

⚠️ **Ce que cette mesure ne prouve PAS, dit plutôt que gonflé** : un 403
anonyme est le comportement ATTENDU depuis le durcissement du 18 août
10:32:59 — il montre que le gate de lecture est toujours évalué de la même
façon, **pas** qu'un joueur Google réellement connecté peut encore lire et
écrire. **Aucune requête AUTHENTIFIÉE n'a pu être émise depuis ce sandbox** :
il n'y a pas d'idToken Google disponible, et la sonde qui aurait pu en
fabriquer un (création d'un compte anonyme via `identitytoolkit
accounts:signUp`) **a été refusée par le classifieur d'actions** — refus
respecté, aucun contournement tenté. Le seul témoin réel reste une
soumission de score par un vrai joueur connecté. **Jugement device.**

#### Web build : vert, et la prod sert bien cet arbre

CI **web-build run #148** (id `32139090008`, tentative 1), **succès en
3 min 18 s** (12:51:45 → 12:55:03). `Deploy to Vercel [PRODUCTION -- main]`
**succès**, `[STAGING -- staging]` correctement **skipped**. Le log porte
lui-même `▲ Aliased https://keepy-ten.vercel.app`. **Aucun changement Godot
n'était attendu** (le diff ne contient que `firestore.rules` et `CLAUDE.md`,
dont aucun n'est une ressource Godot) et c'est confirmé côté sortie.

**Fingerprint vérifié sur le site LIVE**, requête fraîche via le fetch Vercel
(l'egress direct de ce sandbox reste bloqué en 403 CONNECT sur ce domaine) :
HTTP **200**, **`x-vercel-cache: MISS`**, **`age: 0`**, `last-modified` collé
à l'instant de la requête — trois signaux indépendants qui disent que ce
n'est pas une réponse de cache. `GODOT_CONFIG.fileSizes` = **`index.pck
5 451 056` / `index.wasm 35 376 909`**. Le `wasm` est **identique au bit
près** au fingerprint consigné pour tous les lots qui ne touchent pas le code
moteur — et c'est LUI la preuve d'identité, jamais le `.pck`.

**Aucune sonde rejouée, non-applicabilité assumée et pas une omission** : ce
lot ne touche **aucune** ressource Godot, aucune sonde de `scripts/dev/` ne
lit un fichier de rules ni ne parle à Firestore, et aucun Godot n'est
installé dans ce sandbox. La seule validation structurelle pertinente —
import + export headless de l'intégralité des scènes sans erreur — **a eu
lieu et réussi** : c'est exactement ce que fait le job CI sur ce commit
précis.

#### Reste ouvert après ce merge

1. **Aucun client n'exerce encore ces rules** — point 3 ci-dessus,
   **inchangé** : `Quizz.gd`, les écrans du §7 et le branchement du bouton
   grisé du hub restent à écrire. Le contrat est en vigueur, rien ne
   l'appelle.
2. **La première écriture réelle** (create d'un quiz, create d'une question)
   n'a jamais été tentée contre le service — ni ici (egress d'écriture et
   classifieur), ni ailleurs. Les pièges REST du §8 de `docs/QUIZZ_SPEC.md`
   sont donc toujours de la théorie.
3. **Le classement de Chased**, pour un joueur Google réellement connecté :
   argumenté inchangé et mesuré inchangé sur le canal anonyme, mais non
   testé sur le canal authentifié — voir l'avertissement ci-dessus.
4. ~~Le rafraîchissement du token (`onIdTokenChanged`, jamais rebranché)~~
   — **CLOS le 18 août 2026**, voir la section suivante — et la
   fenêtre de ~3 min de 404 à chaque push sur `main` : **inchangée**, et
   toujours hors périmètre de ce lot.


## INFRA : plan Firebase — Spark, apres un aller-retour Blaze non explique (21-22 aout 2026)

**Plan actuel du projet `keepy-8df91` : SPARK, depuis le 22 aout 2026.**
Confirme en Console a 0 $/mois. C'est le seul plan que ce depot doit
utiliser tant que la regle ci-dessous n'a pas ete suivie.

### Historique

Le projet est passe en **Blaze le 21 aout 2026**, sans qu'aucune session
agentique ni aucun commit de ce depot n'en soit la cause identifiee —
`Cloud Storage` et `Cloud Functions` sont tous deux **absents** du projet
a ce jour (Storage affichait encore « Premiers pas » en Console au moment
de la recon, jamais initialise ; aucune Cloud Function n'existe dans ce
depot ni dans la console). Les deux seuls produits Firebase reellement
utilises par Keepy — **Firestore** et **Authentication** — sont l'un
comme l'autre couverts par le plan Spark. Rebascule en Spark effectuee
manuellement en Console le **22 aout 2026**, confirmee a 0 $/mois. Rien
dans le code, les rules ou la config de ce depot n'a jamais exige Blaze ;
le passage du 21 aout est traite comme un aller-retour sans effet
durable, pas comme un changement d'architecture.

### Regle permanente : Blaze est une DECISION, jamais un side-effect de clic

**Cloud Storage et Cloud Functions exigent tous les deux le plan Blaze.**
Aucun des deux n'existe dans ce projet a ce jour. Si l'un devient
necessaire — l'exemple deja identifie est un **masquage cote serveur des
bonnes reponses Quizz** (`docs/QUIZZ_SPEC.md`, deja note comme necessitant
une piece serveur que ce projet n'a pas, puisque Keepy parle a Firestore
en REST direct depuis le client et que les rules ne savent pas masquer un
champ a l'interieur d'un document) — alors le passage en Blaze doit etre :

1. **decide explicitement par Mathieu**,
2. **documente dans ce fichier AVANT execution** (quel produit Blaze est
   necessaire, pour quel besoin, quel cout attendu),
3. et seulement ensuite execute en Console.

Un changement de plan Firebase n'est **jamais** un effet de bord acceptable
d'un autre clic en Console (activer un produit, explorer un onglet) — c'est
exactement le mode de defaillance du 21 aout que cette regle existe pour
fermer.

### Recommandation permanente

**Des que ce projet repasse en Blaze un jour, poser un budget GCP avec des
alertes a 50 %, 90 % et 100 %, avant tout usage reel du produit qui a
motive le passage.** Aucune session agentique ne peut poser ce budget elle-
meme (action Console/GCP) — c'est une action manuelle a faire par Mathieu
au moment de la bascule, pas apres coup.

