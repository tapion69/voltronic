#!/usr/bin/with-contenv bash
set -euo pipefail

MQTT_HOST="$(bashio::config 'mqtt_host')"
MQTT_PORT="$(bashio::config 'mqtt_port')"
MQTT_USER="$(bashio::config 'mqtt_user')"
MQTT_PASS="$(bashio::config 'mqtt_pass')"
SERIAL_PORTS="$(bashio::config 'serial_ports' | jq -r '. | join(",")')"

# Always apply repo flow (auto-update)
cp /addon/flows.json /data/flows.json

# Escape for sed
esc() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }

sed -i "s/__MQTT_HOST__/$(esc "$MQTT_HOST")/g" /data/flows.json
sed -i "s/__MQTT_PORT__/$(esc "$MQTT_PORT")/g" /data/flows.json
sed -i "s/__MQTT_USER__/$(esc "$MQTT_USER")/g" /data/flows.json
sed -i "s/__MQTT_PASS__/$(esc "$MQTT_PASS")/g" /data/flows.json

IFS=',' read -ra PORTS <<< "${SERIAL_PORTS}"
SERIAL_1="${PORTS[0]:-}"
SERIAL_2="${PORTS[1]:-}"
SERIAL_3="${PORTS[2]:-}"

sed -i "s/__SERIAL_1__/$(esc "$SERIAL_1")/g" /data/flows.json
sed -i "s/__SERIAL_2__/$(esc "$SERIAL_2")/g" /data/flows.json
sed -i "s/__SERIAL_3__/$(esc "$SERIAL_3")/g" /data/flows.json

exec node-red --userDir /data --settings /addon/settings.js
