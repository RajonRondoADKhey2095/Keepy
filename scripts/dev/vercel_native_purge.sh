#!/bin/bash
# ============================================================================
#  PURGE DES DEPLOIEMENTS NATIFS VERCEL -- projet "keepy"
# ============================================================================
#
#  ATTENTION -- CE FICHIER A DEUX PHASES, ET LA SECONDE EST IRREVERSIBLE.
#
#    PHASE A (active) : READ-ONLY. Inventorie tous les deploiements, les
#      classe par `source`, resout les alias proteges, ecrit la liste des
#      candidats dans un fichier. NE SUPPRIME RIEN. Peut etre relancee
#      autant de fois que voulu, sans aucun effet de bord.
#
#    PHASE B (commentee) : DESTRUCTIVE ET IRREVERSIBLE. Un deploiement
#      supprime chez Vercel ne se restaure pas -- il disparait aussi de
#      l'historique de rollback. NE DECOMMENTER QU'APRES avoir relu les
#      chiffres imprimes par la phase A et verifie le fichier de candidats.
#
#  Pourquoi cette purge : le projet a eu, en parallele du deploiement CI
#  (web-build.yml -> `vercel deploy build/web --token=...`, source="cli"),
#  l'integration Git native GitHub<->Vercel active (source="git"). Le natif
#  poussait le depot BRUT a chaque push -- sans index.html a la racine, donc
#  ne servant jamais rien d'utile -- et chacun de ces deploiements est retenu
#  par Vercel comme candidat de rollback. Voir CLAUDE.md, section
#  "DEUX deploiements se disputent la PROD a chaque push sur main".
#
#  CRITERE DE TRI (mesure, pas suppose -- verifie sur deux deploiements du
#  MEME commit 89366a5) : le champ `source` de l'API.
#      source == "git"  -> natif  -> candidat a la suppression
#      source == "cli"  -> CI     -> A GARDER, c'est ce qui sert le site
#
#  Le token n'est JAMAIS en dur ici : il est lu dans l'environnement.
#      export VERCEL_TOKEN=...   puis   scripts/dev/vercel_native_purge.sh
# ============================================================================

set -euo pipefail

if [ -z "${VERCEL_TOKEN:-}" ]; then
  echo "ERREUR: la variable d'environnement VERCEL_TOKEN est absente." >&2
  echo "        export VERCEL_TOKEN=... avant de lancer ce script." >&2
  exit 1
fi

PROJECT_ID=prj_OikxKVaLr5nmu1P2944CdQVE4tkh
TEAM_ID=team_ev0yJWnUwGjtuJpAIVpCP3hZ
ALL=/tmp/keepy_deployments.jsonl
CANDIDATES=/tmp/keepy_purge_candidates.txt

api() { curl -sf -H "Authorization: Bearer $VERCEL_TOKEN" "$1"; }

# --- Alias proteges : resolus vers leur deploymentId AVANT tout tri. --------
# On protege par ID, pas par presence d'un champ `alias` dans la liste : ce
# champ n'est pas garanti par /v6/deployments, et un filtre qui teste un
# champ absent laisse passer TOUT le monde. Si une resolution rend du vide,
# on s'arrete -- purger sans savoir qui sert le site n'est pas une option.
PROTECTED=""
for A in keepy-ten.vercel.app keepy-staging.vercel.app; do
  D=$(api "https://api.vercel.com/v4/aliases/$A?teamId=$TEAM_ID" | jq -r '.deploymentId // empty')
  if [ -z "$D" ]; then
    echo "ERREUR: impossible de resoudre l'alias $A vers un deploiement." >&2
    echo "        Purger sans cette information risquerait de casser le site." >&2
    exit 1
  fi
  echo "PROTEGE  $A -> $D"
  PROTECTED="$PROTECTED $D"
done
CURRENT_PROD=$(api "https://api.vercel.com/v9/projects/$PROJECT_ID?teamId=$TEAM_ID" \
               | jq -r '.targets.production.id // empty')
[ -n "$CURRENT_PROD" ] && { echo "PROTEGE  prod courante -> $CURRENT_PROD"; PROTECTED="$PROTECTED $CURRENT_PROD"; }

# --- PHASE A : inventaire complet (read-only) ------------------------------
: > "$ALL"
UNTIL=$(($(date +%s) * 1000))
while :; do
  R=$(api "https://api.vercel.com/v6/deployments?projectId=$PROJECT_ID&teamId=$TEAM_ID&limit=100&until=$UNTIL")
  N=$(jq '.deployments | length' <<<"$R")
  [ "$N" -eq 0 ] && break
  jq -c '.deployments[]' <<<"$R" >> "$ALL"
  UNTIL=$(jq -r '.pagination.next // "null"' <<<"$R")
  [ "$UNTIL" = "null" ] && break
done

echo
echo "TOTAL DEPLOIEMENTS : $(wc -l < "$ALL")"
echo "REPARTITION PAR SOURCE :"
jq -s 'group_by(.source) | map({source: (.[0].source // "(absent)"), n: length})' "$ALL"

# jq -r sur la liste protegee : un ID protege n'entre jamais dans le fichier.
printf '%s\n' $PROTECTED | jq -R . | jq -s . > /tmp/keepy_protected.json
jq -r --slurpfile prot /tmp/keepy_protected.json '
  select(.source == "git")
  | (.uid // .id) as $i
  | select(($prot[0] | index($i)) == null)
  | (((.alias // []) | map(ascii_downcase))) as $al
  | select(($al | index("keepy-ten.vercel.app")) == null)
  | select(($al | index("keepy-staging.vercel.app")) == null)
  | $i' "$ALL" | sort -u > "$CANDIDATES"

echo
echo "CANDIDATS A LA SUPPRESSION : $(wc -l < "$CANDIDATES")  -> $CANDIDATES"
echo "10 premiers :"
head -10 "$CANDIDATES"
echo
echo "PHASE A TERMINEE. AUCUNE SUPPRESSION N'A EU LIEU."
echo "Relire les chiffres ci-dessus, puis decommenter la PHASE B pour purger."

# ============================================================================
#  PHASE B -- DESTRUCTIVE ET IRREVERSIBLE. NE PAS DECOMMENTER A LA LEGERE.
# ============================================================================
# echo "Suppression de $(wc -l < "$CANDIDATES") deploiements dans 10 s (Ctrl-C pour annuler)"
# sleep 10
# while read -r D; do
#   curl -s -X DELETE -H "Authorization: Bearer $VERCEL_TOKEN" \
#     "https://api.vercel.com/v13/deployments/$D?teamId=$TEAM_ID" \
#     -o /dev/null -w "$D %{http_code}\n"
#   sleep 0.25
# done < "$CANDIDATES"
