#!/usr/bin/with-contenv bash
set -e
MQTT_HOST="$(bashio::config 'mqtt_host')"
MQTT_PORT="$(bashio::config 'mqtt_port')"
MQTT_USER="$(bashio::config 'mqtt_user')"
MQTT_PASS="$(bashio::config 'mqtt_pass')"
SERIAL_PORTS="$(bashio::config 'serial_ports' | jq -r '. | join(",")')"

cp /addon/flows.json /data/flows.json
sed -i "s/__MQTT_HOST__/${MQTT_HOST}/g" /data/flows.json
sed -i "s/__MQTT_PORT__/${MQTT_PORT}/g" /data/flows.json
sed -i "s/__MQTT_USER__/${MQTT_USER}/g" /data/flows.json
sed -i "s/__MQTT_PASS__/${MQTT_PASS}/g" /data/flows.json

IFS=',' read -ra PORTS <<< "${SERIAL_PORTS}"
sed -i "s/__SERIAL_1__/${PORTS[0]}/g" /data/flows.json
sed -i "s/__SERIAL_2__/${PORTS[1]}/g" /data/flows.json
sed -i "s/__SERIAL_3__/${PORTS[2]}/g" /data/flows.json

exec node-red --userDir /data --settings /addon/settings.js
