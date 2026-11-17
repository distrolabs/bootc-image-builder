FROM registry.fedoraproject.org/fedora:45 AS builder

RUN dnf install -y \
    git-core \
    golang \
    gpgme-devel \
    libassuan-devel \
    && mkdir -p /build/bib

COPY bib/go.mod bib/go.sum /build/bib/

ARG GOPROXY=https://proxy.golang.org,direct
RUN go env -w GOPROXY=$GOPROXY

RUN cd /build/bib && go mod download

# Copy the entire dir to avoid having to conditionally include ".git" as that
# will not be available when tests are run under tmt
COPY . /build

WORKDIR /build

RUN ./build.sh


FROM registry.fedoraproject.org/fedora:45

# Fast-track osbuild so we don't depend on the "slow" Fedora release process
# to implement new features in bib
COPY ./group_osbuild-osbuild-fedora.repo /etc/yum.repos.d/

RUN dnf --version && \
    rpm -E %fedora

# Add Terra for Fedora 45
RUN dnf install -y \
    --nogpgcheck \
    --repofrompath=terra,https://repos.fyralabs.com/terra45 \
    terra-release \
    terra-gpg-keys

COPY ./package-requires.txt .

RUN dnf install -y \
    $(grep -vE '^#|^$' package-requires.txt) \
    && rm -f package-requires.txt \
    && dnf clean all

COPY --from=builder /build/bin/* /usr/bin/

COPY bib/data /usr/share/bootc-image-builder

ENTRYPOINT ["/usr/bin/bootc-image-builder"]

VOLUME /output
WORKDIR /output

VOLUME /store
VOLUME /rpmmd
VOLUME /var/lib/containers/storage

LABEL description="This tools allows to build and deploy disk-images from bootc container inputs."
LABEL io.k8s.description="This tools allows to build and deploy disk-images from bootc container inputs."
LABEL io.k8s.display-name="Bootc Image Builder"
LABEL io.openshift.tags="base fedora45"
LABEL summary="A container to create disk-images from bootc container inputs"
