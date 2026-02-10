FROM ghcr.io/hassio-addons/base:15.0.7
RUN apk add --no-cache nodejs npm jq
RUN npm install -g node-red
COPY smart-voltronic /addon
WORKDIR /addon
CMD ["/addon/run.sh"]