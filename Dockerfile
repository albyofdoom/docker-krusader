FROM ich777/novnc-baseimage

LABEL org.opencontainers.image.authors="admin@minenet.at"
LABEL org.opencontainers.image.source="https://github.com/ich777/docker-krusader"

RUN export TZ=Europe/Rome && \
	rm -f /etc/apt/sources.list.d/*.list && \
	echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
	echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
	echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
	wget https://www.scootersoftware.com/DEB-GPG-KEY-scootersoftware.asc && \
	wget https://www.scootersoftware.com/scootersoftware.list && \
	cp DEB-GPG-KEY-scootersoftware.asc /etc/apt/trusted.gpg.d/ && \
	cp scootersoftware.list /etc/apt/sources.list.d/ && \
	apt-get update && \
	apt-get -y install --no-install-recommends wget ca-certificates gnupg && \
	wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg && \
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/microsoft.list && \
	apt-get update && \
	apt-get -y install --no-install-recommends krusader breeze-icon-theme kompare krename bzip2 lzma xz-utils lhasa zip unzip arj unace rar unrar p7zip-full rpm konsole gedit gwenview dbus-x11 keditbookmarks feh fonts-takao fonts-arphic-uming fonts-noto-cjk apt-utils nano mariadb-client-compat bc libicu72 powershell && \
	apt-get -y install --no-install-recommends bcompare && \
	apt-get upgrade -y && \
	ln -s /usr/bin/arj /usr/bin/unarj && \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
	echo $TZ > /etc/timezone && \
	apt-get -y install --no-install-recommends fonts-takao && \
	echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen && \ 
	echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen && \
	locale-gen && \
	rm -rf /var/lib/apt/lists/* && \
	sed -i '/    document.title =/c\    document.title = "Krusader - noVNC";' /usr/share/novnc/app/ui.js && \
	rm /usr/share/novnc/app/images/icons/* && \
	apt-get update && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY locales_krusader.tar /tmp/locales_krusader.tar
RUN tar -C / -xvf /tmp/locales_krusader.tar && \
	rm -rf /tmp/locales_krusader.tar

ENV DATA_DIR=/krusader
ENV CUSTOM_RES_W=1920
ENV CUSTOM_RES_H=920
ENV CUSTOM_DEPTH=16
ENV NOVNC_PORT=8080
ENV RFB_PORT=5900
ENV TURBOVNC_PARAMS="-securitytypes none"
ENV UMASK=000
ENV UID=99
ENV GID=100
ENV DATA_PERM=770
ENV USER="krusader"
ENV USER_LOCALES="en_US.UTF-8 UTF-8"

RUN mkdir $DATA_DIR && \
	useradd -d $DATA_DIR -s /bin/bash $USER && \
	chown -R $USER $DATA_DIR && \
	ulimit -n 2048

ADD /scripts/ /opt/scripts/
COPY /icons/* /usr/share/novnc/app/images/icons/
COPY /conf/ /etc/.fluxbox/
RUN chmod -R 770 /opt/scripts/ && \
	chown -R ${UID}:${GID} /mnt && \
	chmod -R 770 /mnt

EXPOSE 8080

#Server Start
ENTRYPOINT ["/opt/scripts/start.sh"]