# build args for image
ARG GO_VER

# image for building ipfsfb
FROM golang:${GO_VER}
ENV IPFS_PATH /var/ipfsfb
VOLUME /var/ipfsfb
RUN go get github.com/ericchiang/pup && \
    apt-get update && apt-get install -y jq && \
    curl --silent "https://api.github.com/repos/ipfs/go-ipfs/releases/latest" | \
    jq -r '.assets[21].browser_download_url'| \
    wget -qi - && \
    tar xvfz *.tar.gz && \
    rm *.tar.gz && \
    cd go-ipfs && \
    ./install.sh

# expose ports for ipfs
EXPOSE 4001 5001 8080 8081
# assign build args to env for runtime arguments
ARG PROFILE
ARG ROUTING
ARG MIGRATE
ENV PROFILE ${PROFILE}
ENV ROUTING ${ROUTING}
ENV MIGRATE ${MIGRATE}
# runtime env
CMD ipfs daemon --init --init-profile=${PROFILE} --routing=${ROUTING} --migrate=${MIGRATE}
