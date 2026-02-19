#!/usr/bin/env bash
set -euo pipefail

echo "### RUN.SH SMART VOLTRONIC START ###"

# Logs (bashio si dispo)
if [ -f /usr/lib/bashio/bashio.sh ]; then
  # shellcheck disable=SC1091
  source /usr/lib/bashio/bashio.sh
  logi(){ bashio::log.info "$1"; }
  logw(){ bashio::log.warning "$1"; }
  loge(){ bashio::log.error "$1"; }
else
  logi(){ echo "[INFO] $1"; }
  logw(){ echo "[WARN] $1"; }
  loge(){ echo "[ERROR] $1"; }
fi

logi "Smart Voltronic: init..."

OPTS="/data/options.json"
if [ ! -f "$OPTS" ]; then
  loge "options.json introuvable dans /data. Stop."
  exit 1
fi

# Helpers jq
jq_str_or() {
  local jq_expr="$1"
  local fallback="$2"
  jq -r "($jq_expr // \"\") | if (type==\"string\" and length>0) then . else \"$fallback\" end" "$OPTS"
}
jq_int_or() {
  local jq_expr="$1"
  local fallback="$2"
  jq -r "($jq_expr // $fallback) | tonumber" "$OPTS" 2>/dev/null || echo "$fallback"
}

# ---------- MQTT (options.json) ----------
MQTT_HOST="$(jq_str_or '.mqtt_host' '')"
MQTT_PORT="$(jq_int_or '.mqtt_port' 1883)"
MQTT_USER="$(jq -r '.mqtt_user // .mqtt_username // ""' "$OPTS")"
MQTT_PASS="$(jq -r '.mqtt_pass // .mqtt_password // ""' "$OPTS")"

logi "MQTT (options.json): ${MQTT_HOST:-<empty>}:${MQTT_PORT} (user: ${MQTT_USER:-<none>})"

if [ -z "${MQTT_HOST}" ]; then
  loge "mqtt_host vide. Renseigne-le dans la config add-on."
  exit 1
fi
if [ -z "${MQTT_USER}" ] || [ -z "${MQTT_PASS}" ]; then
  loge "mqtt_user ou mqtt_pass vide. Renseigne-les dans la config add-on."
  exit 1
fi

# ---------- Serial ports ----------
SERIAL_1="$(jq -r '.serial_ports[0] // ""' "$OPTS")"
SERIAL_2="$(jq -r '.serial_ports[1] // ""' "$OPTS")"
SERIAL_3="$(jq -r '.serial_ports[2] // ""' "$OPTS")"

logi "Serial1: ${SERIAL_1:-<empty>}"
logi "Serial2: ${SERIAL_2:-<empty>}"
logi "Serial3: ${SERIAL_3:-<empty>}"

# ---------- Génération du hash bcrypt pour l'auth Node-RED ----------
logi "Génération du hash bcrypt pour l'auth Node-RED..."

NR_ADMIN_AUTH_FILE="/data/nr_adminauth.json"
NR_ADMIN_USER="pi"
NR_ADMIN_PASS="monstro6364"

BCRYPTJS_PATH=""
for p in \
  /usr/lib/node_modules/node-red/node_modules/bcryptjs \
  /usr/local/lib/node_modules/node-red/node_modules/bcryptjs \
  /opt/node_modules/bcryptjs \
  /usr/lib/node_modules/bcryptjs \
  /usr/local/lib/node_modules/bcryptjs; do
  if [ -f "${p}/index.js" ]; then
    BCRYPTJS_PATH="$p"
    break
  fi
done

if [ -z "$BCRYPTJS_PATH" ]; then
  loge "bcryptjs introuvable. Impossible de générer le hash pour l'auth Node-RED."
  exit 1
fi

logi "bcryptjs trouvé : $BCRYPTJS_PATH"

HASH="$(node -e "
const bcrypt = require('$BCRYPTJS_PATH');
console.log(bcrypt.hashSync('$NR_ADMIN_PASS', 8));
")"

if [ -z "$HASH" ]; then
  loge "Échec de la génération du hash bcrypt."
  exit 1
fi

logi "Hash bcrypt généré avec succès"

cat > "$NR_ADMIN_AUTH_FILE" << JSONEOF
{
  "type": "credentials",
  "users": [
    {
      "username": "${NR_ADMIN_USER}",
      "password": "${HASH}",
      "permissions": "*"
    }
  ]
}
JSONEOF

logi "nr_adminauth.json créé : accès avec user=${NR_ADMIN_USER}"

# ---------- Gestion du flows.json ----------
# Logique :
#   - Première installation (pas de flows.json dans /data) -> copie depuis l'addon
#   - Déjà installé -> on NE TOUCHE PAS au flows existant (préserve les modifs utilisateur)
#   Dans les deux cas on met à jour MQTT et les ports serial configurés

if [ ! -f /data/flows.json ]; then
  logi "Première installation : copie de flows.json depuis l'addon"
  cp /addon/flows.json /data/flows.json
else
  logi "flows.json existant détecté : conservation des flows utilisateur"
fi

tmp="/data/flows.tmp.json"

# ---------- Injection des ports serial configurés ----------
# On met à jour UNIQUEMENT les noeuds serial-port par leur ID fixe.
# On ne supprime JAMAIS les noeuds serial-port ou serial in/out.
#
# IDs fixes des noeuds serial-port dans flows.json :
#   SERIAL_1 -> c546b54ae425b9d2
#   SERIAL_2 -> b2e3f4a5c6d7e8f9
#   SERIAL_3 -> 55a40ce3e960db15

logi "Mise à jour des ports serial dans flows.json..."

update_serial_port() {
  local node_id="$1"
  local serial_value="$2"
  local label="$3"

  if [ -z "$serial_value" ]; then
    logi "Serial ${label} non configuré, noeud conservé tel quel"
    return 0
  fi

  local exists
  exists="$(jq -r --arg id "$node_id" '.[] | select(.id==$id) | .id' /data/flows.json 2>/dev/null || echo "")"

  if [ -z "$exists" ]; then
    logw "Noeud serial-port ID $node_id introuvable dans flows.json (${label})"
    return 0
  fi

  jq --arg id "$node_id" --arg port "$serial_value" '
    map(
      if .id == $id
      then .serialport = $port
      else .
      end
    )
  ' /data/flows.json > "$tmp" && mv "$tmp" /data/flows.json

  logi "Port serial mis à jour : ${label} -> ${serial_value}"
}

update_serial_port "c546b54ae425b9d2" "$SERIAL_1" "SERIAL_1"
update_serial_port "55a40ce3e960db15" "$SERIAL_2" "SERIAL_2"
update_serial_port "39e06a015d18096d" "$SERIAL_3" "SERIAL_3"

# ---------- Injection MQTT dans le node mqtt-broker ----------
if ! jq -e '.[] | select(.type=="mqtt-broker" and .name=="HA MQTT Broker")' /data/flows.json >/dev/null 2>&1; then
  loge 'Aucun mqtt-broker nommé "HA MQTT Broker" trouvé dans flows.json'
  exit 1
fi

logi "Injection MQTT (broker/port/user) dans flows.json"

jq \
  --arg host "$MQTT_HOST" \
  --arg port "$MQTT_PORT" \
  --arg user "$MQTT_USER" \
  '
  map(
    if .type=="mqtt-broker" and .name=="HA MQTT Broker"
    then
      .broker=$host
      | .port=$port
      | .user=$user
    else .
    end
  )
  ' /data/flows.json > "$tmp" && mv "$tmp" /data/flows.json

# ---------- Injection credentials dans flows_cred.json ----------
if [ -f /data/flows_cred.json ]; then
  rm -f /data/flows_cred.json
  logw "Ancien flows_cred.json supprimé"
fi

BROKER_ID="$(jq -r '.[] | select(.type=="mqtt-broker" and .name=="HA MQTT Broker") | .id' /data/flows.json)"

if [ -z "$BROKER_ID" ]; then
  loge "Impossible de récupérer l'ID du node mqtt-broker dans flows.json"
  exit 1
fi

logi "Broker node ID: $BROKER_ID — Création flows_cred.json"

jq -n \
  --arg id "$BROKER_ID" \
  --arg user "$MQTT_USER" \
  --arg pass "$MQTT_PASS" \
  '{($id): {"user": $user, "password": $pass}}' \
  > /data/flows_cred.json

logi "flows_cred.json créé avec succès"

logi "Starting Node-RED sur le port 1892..."
exec node-red --userDir /data --settings /addon/settings.js
