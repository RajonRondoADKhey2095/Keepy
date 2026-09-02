# ARCHIVE — incidents d'infrastructure résolus

> Extrait de `CLAUDE.md` par le LOT H (2 septembre 2026), **verbatim** : aucune ligne réécrite, résumée ni supprimée.
> 2 section(s), 168 lignes d'origine.
> Doctrine permanente : voir `CLAUDE.md`. Index des chantiers : `docs/lots/INDEX.md`.

## Incident résolu : `vercel alias set` "Not able to load user (404)" (8 août 2026)

**Symptôme** : le step `Deploy to Vercel [STAGING]` échouait de façon
identique 5 fois d'affilée sur `vercel alias set ... -T "$VERCEL_ORG_ID"`
(et ses variantes `--scope <slug>` / `--scope <team_id>` testées avant),
toujours avec `Not able to load user (404)`, alors que `vercel deploy`
juste avant réussissait sans problème avec le même token.

**Cause réelle** : le `VERCEL_TOKEN` utilisé était scope **équipe**
(`keepy`). `vercel deploy` s'appuie sur `VERCEL_ORG_ID`/`VERCEL_PROJECT_ID`
pour résoudre le contexte projet sans jamais appeler `/user`, donc il
passait. `vercel alias set`, lui, résout systématiquement l'identité via
un appel `/user` avant d'agir — quel que soit le flag de scope fourni
(`--scope` slug, `--scope` team ID, `-T` team ID) — et ce token équipe
n'avait pas de compte utilisateur associé exploitable par cet appel,
d'où le 404 constant. Aucune combinaison de flags CLI ne pouvait
contourner ça : le problème était le *type* de token, pas sa syntaxe
d'invocation.

**Solution qui a fonctionné** : régénérer un `VERCEL_TOKEN` scope
**compte personnel** (`rajonrondoadkhey2095's projects`, pas team
`keepy`) et le mettre à jour dans le secret GitHub — code CI inchangé
(`-T "$VERCEL_ORG_ID"`). Confirmé sur le run #44 (workflow_dispatch,
commit `759a371`) : `vercel deploy` → preview OK, puis `vercel alias set`
→ `Success! https://keepy-staging.vercel.app now points to
https://keepy-lpisx5c3p-rajonrondoadkhey2095s-projects.vercel.app`.
Fetch direct de `keepy-staging.vercel.app` confirmé HTTP 200, contenu =
export web Godot réel (`<title>Keepy</title>`, canvas, `index.js`,
`GODOT_CONFIG` avec `index.pck`/`index.wasm`), pas une 404 Vercel.

**À retenir pour une session future** : si `vercel alias set` échoue à
nouveau avec `Not able to load user`, vérifier en priorité le **scope du
token** (personnel vs équipe) avant de retoucher les flags CLI — c'est
la variable qui a réellement résolu l'incident, pas `-T` vs `--scope`.

## ⚠️ BLOCAGE GITHUB ACTIONS DU 26 AOUT 2026 : TRANSITOIRE, ET LA PREMISSE « QUOTA DE MINUTES » ETAIT FAUSSE — le repo est PUBLIC

Ce lot ne modifie **aucun fichier de jeu et aucun fichier de CI** : son seul
diff est cette section. Il est parti de `staging` (`25e54d9`, LAKE-MOVE-1),
`origin/main` (`ae13b99`) est **intouche**, et `.github/workflows/web-build.yml`
n'a pas ete effleure — le contournement manuel envisage n'a finalement pas eu
lieu, pour la raison qui suit.

### Le repo est PUBLIC : un quota de minutes ne peut structurellement pas etre la cause

**Mesure via l'API GitHub, pas supposee** : `RajonRondoADKhey2095/Keepy` porte
`"private": false` et `"visibility": "public"`. Sur un repo public, GitHub
Actions est **gratuit et illimite sur runners standard** (`ubuntu-latest`,
ce que ce workflow utilise) — le compteur de minutes gratuites ne s'applique
qu'aux repos prives. **Toute explication du type « quota epuise, reset au
prochain cycle de facturation » est donc exclue par construction ici, et ne
doit pas etre reprise dans un futur brief.**

### Ce que les runs echoues montraient reellement : le job n'obtenait PAS de runner

Trois runs sur `staging` `25e54d9` ont echoue avant cette session — #249
(`push`, 15:13 -> 15:29, `failure`), #250 (`workflow_dispatch`, 15:33,
`startup_failure`) et #251 (`workflow_dispatch`, 15:42, `failure`). Leur
signature commune, lue sur l'API et pas deduite :

- le job `build-and-deploy` reste **`queued`**, sans jamais recevoir de
  `runner_id` ;
- `get_job_logs` avec `failed_only` rend **`"No failed jobs found"`** alors
  que le run est `failure` — parce qu'aucun job n'a jamais tourne, donc il
  n'existe aucun log d'etape a lire.

C'est-a-dire : ce n'etait ni une erreur de build, ni un secret manquant, ni
le workflow. C'etait l'attribution du runner elle-meme.

### ⚠️ LE BLOCAGE S'EST LEVE TOUT SEUL — run #252 vert, ~2 h apres le dernier echec

Un `workflow_dispatch` relance sur `staging` a **17:46:09** a obtenu un
runner en **2 secondes** (`runner_id 1000001231`) et est alle au bout :
**`conclusion: success`**, 17:46:09 -> 17:53:35.

```
Checkout                                17:46:15 -> 17:50:04   (3 min 49 s)
Import project resources                17:50:34 -> 17:52:59
Export Web build                        17:52:59 -> 17:53:04
Verify export output                    17:53:04   success
Deploy to Vercel [PRODUCTION -- main]   17:53:21   skipped     <- main intouche
Deploy to Vercel [STAGING -- staging]   17:53:21 -> 17:53:32   success
```

**LAKE-MOVE-1 est donc deploye sur staging par la voie NORMALE.** Aucun
`vercel deploy` manuel n'a ete emis, aucun alias n'a ete repointe a la main,
et le pipeline permanent est byte-intouche.

⚠️ **Consequence pour une future session : ne pas construire un contournement
avant d'avoir retente un `workflow_dispatch`.** Ce blocage n'a laisse aucune
trace exploitable (pas de log, pas de message d'erreur, pas d'etape rouge) et
s'est resorbe sans intervention. Un simple re-declenchement l'a leve ; le
contournement, lui, aurait coute un token Vercel que le sandbox n'a pas (voir
plus bas) et un deploiement hors-CI a documenter pour toujours.

⚠️ **Piege de lecture evite, et c'est la nuance deja consignee au lot RIDE-1
qui a servi** : pendant le run #252, deux appels `list_workflow_jobs`
successifs (`filter: "all"` puis `"latest"`) ont rendu une reponse
**byte-identique**, figee sur « Checkout / in_progress » — exactement la forme
du piege « API Actions perimee ». **Ce n'en etait pas un** : ce checkout a
reellement dure **3 min 49 s** sur ce repo de 230 Mo. « L'etape est simplement
lente » doit etre ecarte avant d'accuser l'API, dans les deux sens.

### Verification SUR LE SERVICE, deux marqueurs, MISS/age 0 aux deux bouts

| marqueur | AVANT (run #248) | APRES (run #252) |
|---|---|---|
| `CACHE_VERSION` | `1787751298` = **13:34:58** | **`1787766783` = 17:53:03** |
| `index.pck` servi | **5 862 896** | **5 863 008** |
| `index.wasm` servi | 35 376 909 | 35 376 909 *(inchange, attendu)* |

L'epoch d'apres tombe **a l'interieur de l'etape `Export Web build`**
(17:52:59 -> 17:53:04), et les lectures d'apres portent `x-vercel-cache: MISS`
avec `age: 0` et un `last-modified` colle a l'instant de la requete.

⚠️ **Limite dite plutot que sous-entendue** : les deux lectures AVANT sont
arrivees en `x-vercel-cache: HIT` avec un `age` de 9 110 et 9 278 s — donc
**ce ne sont pas des mesures de fraicheur** au sens de la doctrine maison.
Elles valent comme lecture d'etat parce qu'elles reproduisent exactement les
deux valeurs que le brief donnait deja comme connues, et parce que le
`CACHE_VERSION` qu'elles portent tombe dans la fenetre du run #248 — pas parce
que la requete etait fraiche.

### Build local reproduit a l'identique de la CI, en secours et comme controle independant

Fait en parallele du run CI, avec les **memes versions que le workflow**
(`GODOT_VERSION 4.3-stable`, templates `4.3.stable`), **tailles verifiees
contre le `Content-Length`** avant extraction — **50 276 070** et
**1 073 228 327** octets, aucune troncature silencieuse. Import headless
**exit 0**, **24 `.scn`** (import complet verifie, pas suppose). Export Web
release **exit 0**.

`index.wasm` **35 376 909** / md5 **`af4a8fc2925d992348eb30deeeb54360`** et
`index.js` md5 **`4e08904b1b7107858246af44b602067b`** — **identiques au
fingerprint permanent** de ce depot, et identiques au `.wasm` servi. C'est LUI
la preuve d'identite. `index.pck` local **5 863 040** contre **5 863 008**
servi : **32 octets d'ecart**, l'instabilite de compression VRAM deja
documentee entre deux exports distincts du meme commit, jamais offerte comme
preuve.

### ⚠️ AUCUN `VERCEL_TOKEN` N'EXISTE DANS LE SANDBOX — a savoir avant de planifier un deploiement manuel

Verifie plutot que suppose : aucune variable `VERCEL_*` dans l'environnement,
pas de `~/.vercel` ni de `.vercel/` dans le depot, et le CLI `vercel` n'est
pas installe. Le token vit **uniquement** dans les secrets GitHub
(`VERCEL_TOKEN` / `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID`), que le workflow lit
et qu'une session ne peut pas lire.

Le serveur MCP Vercel, lui, est authentifie et permet de LIRE le projet et le
site servi (`get_project`, `web_fetch_vercel_url`) — c'est par la que les
marqueurs ci-dessus sont mesures, l'egress direct vers `*.vercel.app` restant
refuse par le proxy de ce sandbox. Mais son `deploy_to_vercel` prend un
**arbre de fichiers inline**, ce qui est inutilisable pour un build web Godot
(`index.wasm` seul fait 35 Mo). **Un deploiement manuel exigerait donc que
Mathieu fournisse un token**, et c'est le vrai cout du contournement qui a ete
evite ici.

### Reste ouvert

Rien sur le deploiement : LAKE-MOVE-1 est en ligne sur
`keepy-staging.vercel.app`, servi par le build du run #252, et le jugement
device sur le lac deplace reste celui que le lot LAKE-MOVE-1 a laisse ouvert.
**La cause racine du blocage Actions de 15:13-15:46 n'est PAS etablie** — elle
n'a laisse aucun log, et le diagnostic cote facturation (spending limit,
moyen de paiement) demande la Console GitHub, hors de portee d'une session.
Si le symptome revient, la premiere chose a faire est de **relancer un
`workflow_dispatch`** et de regarder si le job recoit un `runner_id`.

