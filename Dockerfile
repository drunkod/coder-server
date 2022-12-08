# This is a hack to setuo alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/drunkod/coder-core:master AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/drunkod/coder-core:master AS linux-arm64
ARG ALT_ARCH=arm64


# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS builder
ARG TARGETARCH
ARG CLOUDFLARE_VERSION=2022.10.3
ARG OPENVSCODE_VERSION=4.9.0

# Install npm, nodejs and some tools required to build native node modules 
RUN sudo apk --no-cache add npm build-base libsecret-dev python3 wget

# Setup a dummy project
RUN cd /tmp && \
    npm init -y && \
# Then add dependencies
    npm install keytar node-pty spdlog native-watchdog @parcel/watcher && \
# Remove any precompiled native modules
    find /tmp/node_modules -name "*.node" -exec rm -rf {} \;

# Build keytar native modue
RUN cd /tmp/node_modules/keytar && \
    npm run build && \
    strip /tmp/node_modules/keytar/build/Release/keytar.node

# Build node-pty native modue
RUN cd /tmp/node_modules/node-pty && \
    npm install && \
    strip /tmp/node_modules/node-pty/build/Release/pty.node

# Build spdlog native modue
RUN cd /tmp/node_modules/spdlog && \
    npm rebuild && \
    strip /tmp/node_modules/spdlog/build/Release/spdlog.node

# Build native-watchdog native modue
RUN cd /tmp/node_modules/native-watchdog && \
    npm rebuild && \
    strip /tmp/node_modules/native-watchdog/build/Release/watchdog.node

# Build @parcel/watcher native modue
RUN cd /tmp/node_modules/@parcel/watcher && \
    npm install && \
    strip /tmp/node_modules/@parcel/watcher/build/Release/watcher.node

# Download 'cloudflared' manually instead of using apk.
# This is currently required because it is only available on the edge/testing Alpine repo.
RUN wget https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARE_VERSION}/cloudflared-linux-${TARGETARCH} && \
    chmod +x cloudflared-linux-${TARGETARCH}  && \
# Remove debug symbols
    strip cloudflared-linux-${TARGETARCH} && \
# Put it into a 'staging' folder
    mkdir -p /tmp/staging/usr/bin && \ 
    mv cloudflared-linux-${TARGETARCH} /tmp/staging/usr/bin/cloudflared && \
    sudo chown root:root  /tmp/staging/usr/bin/cloudflared

# Download 'code-server'
RUN wget https://github.com/coder/code-server/releases/download/v${OPENVSCODE_VERSION}/code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH}.tar.gz && \
# Unpack it
    tar -xf code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH}.tar.gz && \
    rm code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH}.tar.gz && \
# Remove the 'node binary that comes with it
    rm code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH}/lib/node && \
# Replacing it with a symlink
    ln -s /usr/bin/node ./code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH}/lib/node && \
# Remove pre-compiled binary node modules
    find . -name "*.node" -exec rm -rf {} \; && \
# Put everything into a 'staging' folder
    sudo mkdir -p /tmp/staging/opt/ && \
    sudo mv code-server-${OPENVSCODE_VERSION}-linux-${TARGETARCH} /tmp/staging/opt/code-server && \
#     sudo cp /tmp/node_modules/keytar/build/Release/keytar.node /tmp/staging/opt/code-server/node_modules/keytar/build/Release/keytar.node && \
#     sudo cp /tmp/node_modules/node-pty/build/Release/pty.node /tmp/staging/opt/code-server/node_modules/node-pty/build/Release/pty.node && \
#     sudo cp /tmp/node_modules/spdlog/build/Release/spdlog.node /tmp/staging/opt/code-server/node_modules/spdlog/build/Release/spdlog.node && \
#     sudo cp /tmp/node_modules/native-watchdog/build/Release/watchdog.node /tmp/staging/opt/code-server/node_modules/native-watchdog/build/Release/watchdog.node && \
#     sudo cp /tmp/node_modules/@parcel/watcher/build/Release/watcher.node /tmp/staging/opt/code-server/node_modules/@parcel/watcher/build/Release/watcher.node && \
    sudo chown -R root:root /tmp/staging/opt/code-server

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

# Copy stuff from the staging folder of the 'builder' stage
COPY --from=builder /tmp/staging /

ARG USERNAME=coder
# Change user
USER $USERNAME

ENV PATH=$PATH:/opt/code-server/bin

WORKDIR /home/$USERNAME

EXPOSE 8080

CMD code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check \
    --proxy-domain ${PROXY_DOMAIN} --config /config/.config/code-server/config.yaml \
    --user-data-dir /config/data --extensions-dir /config/extensions
