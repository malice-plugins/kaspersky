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
# FROM debian
FROM ubuntu:bionic

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

RUN apt-get update \
  && apt-get install -yq locales \
  && locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TERM=screen-256color

# Install Kaspersky AV
# ADD https://products.s.kaspersky-labs.com/multilanguage/i_gateways/proxyserver/linux/kav4proxy_5.5-86_i386.deb /tmp
# COPY kav4fs_8.0.4-312_i386.deb /tmp
COPY license.key /etc/kaspersky/license.key
COPY config/docker.conf /etc/kaspersky/docker.conf

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
  && apt-get install -yq $buildDeps libc6-i386 lib32z1 tree libcurl4-openssl-dev curlftpfs \
  && echo "===> Install Kaspersky..." \
  && wget --progress=bar:force https://products.s.kaspersky-labs.com/multilanguage/file_servers/kavlinuxserver8.0/kav4fs_8.0.4-312_i386.deb -P /tmp \
  && DEBIAN_FRONTEND=noninteractive dpkg --force-architecture -i /tmp/kav4fs_8.0.4-312_i386.deb \
  && chmod a+s /opt/kaspersky/kav4fs/bin/kav4fs-setup.pl \
  && chmod a+s /opt/kaspersky/kav4fs/bin/kav4fs-control \
  && chmod 0777 /etc/kaspersky/license.key \
  && /opt/kaspersky/kav4fs/bin/kav4fs-control -L --validate-on-install /etc/kaspersky/license.key; sleep 3  \
  && /opt/kaspersky/kav4fs/bin/kav4fs-control -L --install-on-install /etc/kaspersky/license.key; sleep 3  \
  && echo "===> Setup Kaspersky..." \
  && /opt/kaspersky/kav4fs/bin/kav4fs-setup.pl --auto-install=/etc/kaspersky/docker.conf; sleep 10 \
  # && echo "===> Fix CVEs..." \
  # && wget --progress=bar:force http://media.kaspersky.com/utilities/CorporateUtilities/klnagent_10.1.0-61_i386_deb.zip -P /tmp \
  # && cd /tmp \
  # && unzip klnagent_10.1.0-61_i386_deb.zip \
  # && DEBIAN_FRONTEND=noninteractive dpkg --force-architecture -i klnagent_10.1.0-61_i386.deb \
  && echo "===> Clean up unnecessary files..." \
  # && apt-get purge -y --auto-remove $buildDeps \
  # && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives /tmp/* /var/tmp/*

# COPY config/odscan.ini /etc/kaspersky/odscan.ini
# RUN \
#   echo "===> Fix settings..." \
#   && /etc/init.d/kav4fs-supervisor start; sleep 10 \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -T --file /etc/kaspersky/odscan.ini --set-settings 9

# RUN \
#   echo "===> Updating AV..." \
#   && /etc/init.d/kav4fs-supervisor restart; sleep 10 \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -T --start-task 6 --progress \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -T --get-stat Update
# && mv /var/opt/kaspersky/kav4fs/update/avbases /var/opt/kaspersky/kav4fs/update/avbases-backup \
# && mv /var/opt/kaspersky/kav4fs/update/update_temp_deleted_suddenly /var/opt/kaspersky/kav4fs/update/avbases

# RUN \
#   echo "===> Validate..." \
#   && /etc/init.d/kav4fs-supervisor restart; sleep 10 \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -S --app-info \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -L --validate-key /etc/kaspersky/license.key \
#   && /opt/kaspersky/kav4fs/bin/kav4fs-control -L --query-status

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
