# This is a hack to setuo alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
FROM ghcr.io/drunkod/coder-core:latest AS linux-amd64
ARG ALT_ARCH=x64

FROM ghcr.io/drunkod/coder-core:latest AS linux-arm64
ARG ALT_ARCH=arm64

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS builder
ARG TARGETARCH
ARG CLOUDFLARE_VERSION=2022.10.3

ARG VERSION=4.9.0

ENV EUID=1000 EGID=1000 HOME=/home/vscode

# Install npm, nodejs and some tools required to build native node modules 
RUN sudo apk --no-cache add npm build-base libsecret-dev python3 wget



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

# Download 'openvscode-server'
RUN \
   cd /tmp && \
   wget https://github.com/cdr/code-server/releases/download/v$VERSION/code-server-$VERSION-linux-$TARGETARCH.tar.gz && \
   tar xzf code-server-$VERSION-linux-$TARGETARCH.tar.gz && \
   rm code-server-$VERSION-linux-$TARGETARCH/lib/node && \
   rm code-server-$VERSION-linux-$TARGETARCH.tar.gz && \
   mv code-server-$VERSION-linux-$TARGETARCH /tmp/staging/usr/lib/code-server

# This inherits from the hack above
FROM ${TARGETOS}-${TARGETARCH} AS final
ARG TARGETARCH

# Copy stuff from the staging folder of the 'builder' stage
COPY --from=builder /tmp/staging /

RUN sed -i 's/"$ROOT\/lib\/node"/node/g'  /usr/lib/code-server/bin/code-server

COPY code-server /usr/bin/
RUN chmod +x /usr/bin/code-server

EXPOSE 8080
CMD code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check \
    --proxy-domain ${PROXY_DOMAIN} --config /config/.config/code-server/config.yaml \
    --user-data-dir /config/data --extensions-dir /config/extensions
