#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title babacoiffure check and restart  services
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🛠️

# Documentation:
# @raycast.description Vérifie l'état des services BABACOIFFURE (API & WEBSITE) en PROD et PREPROD via des appels API, 
#                      et redémarre automatiquement les services qui ne répondent pas avec un code 200.
# @raycast.author toi

# Liste des environnements et services à checker
ENVS=("PROD" "PREPROD")
SERVICES=("API" "WEBSITE")

for ENV in "${ENVS[@]}"; do
  for SERVICE in "${SERVICES[@]}"; do

    CHECK_VAR="BABACOIFFURE_CHECKHEALTH_${ENV}_${SERVICE}"
    RESTART_VAR="BABACOIFFURE_DEPLOY_HOOK_${ENV}_${SERVICE}"

    CHECK_URL="${!CHECK_VAR}"
    RESTART_URL="${!RESTART_VAR}"

    if [[ -z "$CHECK_URL" || -z "$RESTART_URL" ]]; then
      echo "[${ENV}_${SERVICE}] ⚠️ Variables non définies, skipping..."
      continue
    fi

    echo "[${ENV}_${SERVICE}] Vérification du service via $CHECK_URL"

    # Ajout du timeout de 2 secondes (--max-time 2)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "$CHECK_URL")

    echo "[${ENV}_${SERVICE}] Code HTTP check: $http_code"

    if [[ "$http_code" != "200" ]]; then
      echo "[${ENV}_${SERVICE}] 🚨 Service DOWN ou timeout, tentative de redémarrage via $RESTART_URL"
      restart_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$RESTART_URL")
      if [[ "$restart_code" == "200" ]]; then
        echo "[${ENV}_${SERVICE}] 🔄 Redémarrage réussi."
      else
        echo "[${ENV}_${SERVICE}] ❌ Échec du redémarrage (HTTP $restart_code)."
      fi
    else
      echo "[${ENV}_${SERVICE}] ✅ Service OK."
    fi

    echo "---------------------------------------"

  done
done
