# This is a hack to set up alternate architecture names
# For this to work, it needs to be built using docker 'buildx'
# Define a new stage for building the image for amd64 architecture
FROM jrottenberg/ffmpeg:alpine AS linux-amd64
# Define a build argument for alternate architecture name, set to x64 by default   
ARG ALT_ARCH=x64    

# Define a new stage for building the image for arm64 architecture
FROM jrottenberg/ffmpeg:alpine AS linux-arm64 
# Define a build argument for alternate architecture name, set to arm64 for arm64 stage
ARG ALT_ARCH=arm64   

# This is the builder stage, where we install dependencies and set up the staging folder
# Define a new stage for building the image, based on the target OS and architecture
FROM ${TARGETOS}-${TARGETARCH} AS builder  
# Define a build argument for the target architecture
ARG TARGETARCH   
# Define a build argument for the VS Code version
ARG OPENVSCODE_VERSION=4.9.0
# Define a build argument for the default username
# ARG USERNAME=coder   

# Install npm, nodejs and some tools required to build native node modules 
RUN apk --no-cache add build-base libsecret-dev python3 wget nano

# Setup a dummy project and put everything into a 'staging' folder
# RUN sudo npm install --global code-server --unsafe-perm
# RUN sudo mkdir -p /tmp/staging/usr/local/lib/node_modules/ && \
#     sudo mv /usr/local/lib/node_modules/code-server/ /tmp/staging/usr/local/lib/node_modules/code-server && \
#     sudo chown -R root:root /tmp/staging/usr/local/lib/node_modules/code-server
  

# This inherits from the hack above
# This is the final stage, where we copy files from the builder stage and start the server
# Define a new stage for building the final image, based on the target OS and architecture
FROM ${TARGETOS}-${TARGETARCH} AS final
# Define a build argument for the target architecture
ARG TARGETARCH
# Define a build argument for the default username   
# ARG USERNAME=coder   



# Copy the staging folder from the builder stage to the final stage root directory
 COPY --from=builder /usr/local /usr/local

# Expose port 8080 for the server
EXPOSE 8080

# Start the code-server with some flags to disable telemetry, update checks, and authentication
CMD code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry --disable-update-check 

#      --config /config/.config/code-server/config.yaml \
#     --user-data-dir /config/data --extensions-dir /config/extensions
