####################################################
# GOLANG BUILDER
####################################################
# FROM golang:1.11 as go_builder

# COPY . /go/src/github.com/malice-plugins/kaspersky
# WORKDIR /go/src/github.com/malice-plugins/kaspersky
# RUN go get -u github.com/golang/dep/cmd/dep && dep ensure
# RUN go build -ldflags "-s -w -X main.Version=v$(cat VERSION) -X main.BuildTime=$(date -u +%Y%m%d)" -o /bin/avscan

####################################################
# PLUGIN BUILDER
####################################################
FROM ubuntu:xenial

LABEL maintainer "https://github.com/blacktop"

LABEL malice.plugin.repository = "https://github.com/malice-plugins/kaspersky.git"
LABEL malice.plugin.category="av"
LABEL malice.plugin.mime="*"
LABEL malice.plugin.docker.engine="*"

# Create a malice user and group first so the IDs get set the same way, even as
# the rest of this may change over time.
RUN groupadd -r malice \
  && useradd --no-log-init -r -g malice malice \
  && mkdir /malware \
  && chown -R malice:malice /malware

# Install Kaspersky AV
# ADD https://products.s.kaspersky-labs.com/multilanguage/i_gateways/proxyserver/linux/kav4proxy_5.5-86_i386.deb /tmp
# COPY kav4fs_8.0.4-312_i386.deb /tmp
COPY license.key /etc/kaspersky/license.key
RUN buildDeps='libreadline-dev:i386 \
  ca-certificates \
  libc6-dev:i386 \
  build-essential \
  gcc-multilib \
  cabextract \
  mercurial \
  git-core \
  unzip \
  wget' \
  && set -x \
  && dpkg --add-architecture i386 \
  && apt-get update \
  && apt-get install -yq $buildDeps libc6-i386 lib32z1 \
  && echo "===> Install Kaspersky..." \
  && wget https://products.s.kaspersky-labs.com/multilanguage/file_servers/kavlinuxserver8.0/kav4fs_8.0.4-312_i386.deb -P /tmp \
  && DEBIAN_FRONTEND=noninteractive dpkg --force-architecture -i /tmp/kav4fs_8.0.4-312_i386.deb \
  && chmod a+s /opt/kaspersky/kav4fs/bin/kav4fs-control \
  && chmod 0777 /etc/kaspersky/license.key \
  && /etc/init.d/kav4fs-supervisor start; sleep 10 && /opt/kaspersky/kav4fs/bin/kav4fs-control --install-active-key /etc/kaspersky/license.key \
  && echo "===> Clean up unnecessary files..." \
  && apt-get purge -y --auto-remove $buildDeps \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives /tmp/* /var/tmp/*

# Ensure ca-certificates is installed for elasticsearch to use https
RUN apt-get update -qq && apt-get install -yq --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY install.conf /tmp
RUN /etc/init.d/kav4fs-supervisor start; sleep 10 \
  && /opt/kaspersky/kav4fs/bin/kav4fs-setup.pl --auto-install=/tmp/install.conf

RUN \
  echo "===> Updating AV..." \
  && /etc/init.d/kav4fs-supervisor start; sleep 10 \
  && /opt/kaspersky/kav4fs/bin/kav4fs-control --start-task 6 \
  && /opt/kaspersky/kav4fs/bin/kav4fs-control --progress 6

# Add EICAR Test Virus File to malware folder
ADD http://www.eicar.org/download/eicar.com.txt /malware/EICAR

# COPY --from=go_builder /bin/avscan /bin/avscan

WORKDIR /malware

# ENTRYPOINT ["/bin/avscan"]
# CMD ["--help"]

####################################################
# CMD /etc/init.d/kav4fs-supervisor start && /opt/kaspersky/kav4fs/bin/kav4fs-control --scan-file /malware/EICAR

# https://products.s.kaspersky-labs.com/multilanguage/endpoints/kesl/kesl_10.0.0-3458_amd64.deb

# https://products.s.kaspersky-labs.com/multilanguage/endpoints/kesl/klnagent_10.1.1-26_i386.deb

# https://products.s.kaspersky-labs.com/multilanguage/file_servers/kavlinuxserver8.0/kav4fs_8.0.4-312_i386.deb
