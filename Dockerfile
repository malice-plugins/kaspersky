FROM ubuntu

# ADD https://products.s.kaspersky-labs.com/multilanguage/i_gateways/proxyserver/linux/kav4proxy_5.5-86_i386.deb /tmp

COPY kav4fs_8.0.4-312_i386.deb /tmp
COPY install.conf /tmp
COPY kaspersky.key /tmp

RUN dpkg --add-architecture i386 \
  && apt-get update \
  && apt-get install -y libc6-i386


RUN DEBIAN_FRONTEND=noninteractive dpkg --force-architecture -i /tmp/kav4fs_8.0.4-312_i386.deb

RUN /etc/init.d/kav4fs-supervisor start && /opt/kaspersky/kav4fs/bin/kav4fs-setup.pl --auto-install=/tmp/install.conf

# https://products.s.kaspersky-labs.com/multilanguage/endpoints/kesl/kesl_10.0.0-3458_amd64.deb

# https://products.s.kaspersky-labs.com/multilanguage/endpoints/kesl/klnagent_10.1.1-26_i386.deb

# https://products.s.kaspersky-labs.com/multilanguage/file_servers/kavlinuxserver8.0/kav4fs_8.0.4-312_i386.deb

# CMD /etc/init.d/kav4fs-supervisor && kav4fs-control --action skip --scan-file /malware/EICAR

# Add EICAR Test Virus File to malware folder
ADD http://www.eicar.org/download/eicar.com.txt /malware/EICAR

# CMD /etc/init.d/kav4fs-supervisor start && /opt/kaspersky/kav4fs/bin/kav4fs-control --scan-file /malware/EICAR
