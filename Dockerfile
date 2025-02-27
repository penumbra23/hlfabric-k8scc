FROM golang:1-alpine as builder
RUN apk --no-cache add git
ENV CGO_ENABLED=0

WORKDIR /go/src/app
COPY . .
RUN go env
RUN go build -o /bin/externalcc .


FROM hyperledger/fabric-peer:3.0.0-preview
RUN apt-get update && apt-get install patch && apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/{apt,dpkg,cache,log}/

# Install external cc
COPY k8scc.yaml /opt/k8scc/k8scc.yaml
COPY --from=builder /bin/externalcc /opt/k8scc/bin/externalcc
RUN ln -s /opt/k8scc/bin/externalcc /opt/k8scc/bin/detect
RUN ln -s /opt/k8scc/bin/externalcc /opt/k8scc/bin/build
RUN ln -s /opt/k8scc/bin/externalcc /opt/k8scc/bin/release
RUN ln -s /opt/k8scc/bin/externalcc /opt/k8scc/bin/run

# Patch core.xml with a hack:
#  As we cannot change data in volume /etc/hyperledger/fabric/ because of
#  https://docs.docker.com/engine/reference/builder/#notes-about-specifying-volumes,
#  we have to implement a workaround
COPY core.yaml.patch /opt/k8scc/core.yaml.patch
COPY core.yaml.md5sum /opt/k8scc/core.yaml.md5sum
COPY entrypoint.sh /opt/k8scc/entrypoint.sh
COPY core.yaml /etc/hyperledger/fabric/core.yaml

# Define entrypoint and CMD as JSON array, it's required to correcty pass arguments

# Since we're using a custom core.yaml, we don't need to patch the default one
# ENTRYPOINT ["/opt/k8scc/entrypoint.sh"]
CMD ["peer","node","start"]
