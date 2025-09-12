#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title babacoiffure check and restart services
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🛠️

# Documentation:
# @raycast.description Vérifie l'état des services BABACOIFFURE (API & WEBSITE) en PROD et PREPROD via des appels API, 
#                      et redémarre automatiquement les services qui ne répondent pas avec un code 200 (si "restart" est passé en argument).
# @raycast.author toi

# Usage :
#   ./script.sh           # → check only (par défaut)
#   ./script.sh check     # → check only
#   ./script.sh restart   # → check + restart

ACTION=${1:-check}  # Par défaut : check uniquement

ENVS=("PROD" "PREPROD")
SERVICES=("API" "WEBSITE" "ADMIN")

for ENV in "${ENVS[@]}"; do
  for SERVICE in "${SERVICES[@]}"; do

    CHECK_VAR="BABACOIFFURE_CHECKHEALTH_${ENV}_${SERVICE}"
    RESTART_VAR="BABACOIFFURE_DEPLOY_HOOK_${ENV}_${SERVICE}"

    CHECK_URL="${!CHECK_VAR}"
    RESTART_URL="${!RESTART_VAR}"

    if [[ -z "$CHECK_URL" ]]; then
      echo "[${ENV}_${SERVICE}] ⚠️ Variable CHECK_URL non définie, skipping..."
      continue
    fi

    echo "[${ENV}_${SERVICE}] 🔍 Vérification du service ($CHECK_URL)..."

    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$CHECK_URL")
    echo "[${ENV}_${SERVICE}] ↪ Code HTTP reçu : $http_code"

    if [[ "$http_code" != "200" ]]; then
      echo "[${ENV}_${SERVICE}] 🚨 Service DOWN ou timeout."

      if [[ "$ACTION" == "restart" ]]; then
        if [[ -z "$RESTART_URL" ]]; then
          echo "[${ENV}_${SERVICE}] ❌ RESTART_URL manquant, impossible de redémarrer."
        else
          echo "[${ENV}_${SERVICE}] 🔁 Tentative de redémarrage ($RESTART_URL)..."
          restart_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$RESTART_URL")
          if [[ "$restart_code" == "200" ]]; then
            echo "[${ENV}_${SERVICE}] ✅ Redémarrage réussi."
          else
            echo "[${ENV}_${SERVICE}] ❌ Échec du redémarrage (HTTP $restart_code)."
          fi
        fi
      else
        echo "[${ENV}_${SERVICE}] 🚫 Redémarrage ignoré (mode check uniquement)."
      fi
    else
      echo "[${ENV}_${SERVICE}] ✅ Service OK."
    fi

    echo "---------------------------------------"
  done
done
