#!/usr/bin/with-contenv bash
set -euo pipefail

# ✅ charge bashio (sinon bashio::log.* / bashio::config = "command not found")
source /usr/lib/bashio/bashio.sh

bashio::log.info "Smart Voltronic: init..."


MQTT_HOST="$(bashio::config 'mqtt_host')"
MQTT_PORT="$(bashio::config 'mqtt_port')"
MQTT_USER="$(bashio::config 'mqtt_user')"
MQTT_PASS="$(bashio::config 'mqtt_pass')"
SERIAL_PORTS="$(bashio::config 'serial_ports' | jq -r '. | join(",")')"

bashio::log.info "MQTT: ${MQTT_HOST}:${MQTT_PORT} (user: ${MQTT_USER:-<none>})"
bashio::log.info "Serial ports (raw): ${SERIAL_PORTS}"

# Always apply repo flow (auto-update)
cp /addon/flows.json /data/flows.json

# Escape for sed replacement safely
esc() {
  printf '%s' "$1" | sed -e 's/[\/&|\\]/\\&/g'
}

# Replace MQTT placeholders
sed -i "s/__MQTT_HOST__/$(esc "$MQTT_HOST")/g" /data/flows.json
sed -i "s/__MQTT_PORT__/$(esc "$MQTT_PORT")/g" /data/flows.json
sed -i "s/__MQTT_USER__/$(esc "$MQTT_USER")/g" /data/flows.json
sed -i "s/__MQTT_PASS__/$(esc "$MQTT_PASS")/g" /data/flows.json

# Parse up to 3 serial ports
IFS=',' read -ra PORTS <<< "${SERIAL_PORTS}"
SERIAL_1="${PORTS[0]:-}"
SERIAL_2="${PORTS[1]:-}"
SERIAL_3="${PORTS[2]:-}"

# Log + sanity checks
for i in 1 2 3; do
  p_var="SERIAL_${i}"
  p_val="${!p_var}"
  if [ -n "${p_val}" ]; then
    if [ -e "${p_val}" ]; then
      bashio::log.info "Serial ${i}: ${p_val} (OK)"
    else
      bashio::log.warning "Serial ${i}: ${p_val} (NOT FOUND)"
    fi
  else
    bashio::log.info "Serial ${i}: <empty>"
  fi
done

# Replace Serial placeholders
sed -i "s/__SERIAL_1__/$(esc "$SERIAL_1")/g" /data/flows.json
sed -i "s/__SERIAL_2__/$(esc "$SERIAL_2")/g" /data/flows.json
sed -i "s/__SERIAL_3__/$(esc "$SERIAL_3")/g" /data/flows.json

bashio::log.info "Starting Node-RED..."
exec node-red --userDir /data --settings /addon/settings.js
