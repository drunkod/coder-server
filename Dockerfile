# This is a hack to setuo alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/drunkod/coder-core:master AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/drunkod/coder-core:master AS linux-arm64
ARG ALT_ARCH=arm64


# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

ARG OPENVSCODE_VERSION=4.9.0

ARG USERNAME=coder

# Install npm, nodejs and some tools required to build native node modules 
RUN sudo apk --no-cache add build-base libsecret-dev python3 wget nano

# Setup a dummy project
RUN sudo npm install --global code-server --unsafe-perm

WORKDIR /home/$USERNAME

EXPOSE 8080

CMD code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check 
#      --config /config/.config/code-server/config.yaml \
#     --user-data-dir /config/data --extensions-dir /config/extensions
