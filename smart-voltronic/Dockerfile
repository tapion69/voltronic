ARG BUILD_FROM=ghcr.io/hassio-addons/base:15.0.7
FROM ${BUILD_FROM}

RUN apk add --no-cache nodejs npm jq bash
RUN npm install -g --unsafe-perm node-red@3.1.9 \
  && npm cache clean --force

COPY smart-voltronic /addon
WORKDIR /addon

CMD ["/addon/run.sh"]
