#!/usr/bin/env bash
# Écrit la clé publique du projet Supabase « Ouinon » dans supabase.json
# (non commité), à passer à la fabrication de l'APK :
#   bash tool/cle_supabase.sh
#   flutter build apk ... --dart-define-from-file=supabase.json
# La clé est lue avec l'API de gestion de Supabase (jeton de la session).
set -euo pipefail
cd "$(dirname "$0")/.."
curl -sf https://api.supabase.com/v1/projects/mcusodanxgriodltqkhc/api-keys \
  | python3 -c "import json,sys; k=[k['api_key'] for k in json.load(sys.stdin) if k.get('type')=='publishable'][0]; json.dump({'SUPABASE_CLE': k}, open('supabase.json','w'))"
echo "supabase.json prêt."
