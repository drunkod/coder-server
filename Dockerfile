# This is a hack to setuo alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/drunkod/coder-core:master AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/drunkod/coder-core:master AS linux-arm64
ARG ALT_ARCH=arm64

FROM ${TARGETOS}-${TARGETARCH} AS builder
ARG TARGETARCH
ARG OPENVSCODE_VERSION=4.9.0

# Install npm, nodejs and some tools required to build native node modules 
RUN sudo apk --no-cache add build-base libsecret-dev python3 wget nano

# Setup a dummy project
RUN sudo npm install --global code-server --unsafe-perm
RUN sudo npm install -g pnpm

# Put everything into a 'staging' folder
RUN sudo mkdir -p /tmp/staging/opt/ && \
    sudo mv /usr/local/lib/node_modules/code-server /tmp/staging/usr/local/lib/node_modules/code-server && \
    sudo chown -R root:root /tmp/staging/usr/local/lib/node_modules/code-server
    
# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

ARG USERNAME=coder

# Copy stuff from the staging folder of the 'builder' stage
COPY --from=builder /tmp/staging /

RUN sudo pnpm install --global code-server --unsafe-perm

WORKDIR /home/$USERNAME

EXPOSE 8080

CMD code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check 
#      --config /config/.config/code-server/config.yaml \
#     --user-data-dir /config/data --extensions-dir /config/extensions
