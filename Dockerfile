FROM ich777/novnc-baseimage

LABEL org.opencontainers.image.authors="admin@minenet.at"
LABEL org.opencontainers.image.source="https://github.com/ich777/docker-krusader"

# Build-time argument for timezone (default kept same as original)
ARG TZ=America/Los_Angeles
ENV TZ=${TZ} \
	DATA_DIR=/krusader \
	CUSTOM_RES_W=1920 \
	CUSTOM_RES_H=920 \
	CUSTOM_DEPTH=16 \
	NOVNC_PORT=8080 \
	RFB_PORT=5900 \
	TURBOVNC_PARAMS="-securitytypes none" \
	UMASK=000 \
	UID=99 \
	GID=100 \
	DATA_PERM=770 \
	USER=krusader \
	USER_LOCALES="en_US.UTF-8 UTF-8"

# Consolidate package repository additions, installs, locale generation and cleanup in one layer
RUN set -eux; \
	echo "deb http://deb.debian.org/debian bookworm contrib non-free non-free-firmware" > /etc/apt/sources.list; \
	wget -qO /tmp/DEB-GPG-KEY-scootersoftware.asc https://www.scootersoftware.com/DEB-GPG-KEY-scootersoftware.asc; \
	wget -qO /tmp/scootersoftware.list https://www.scootersoftware.com/scootersoftware.list; \
	install -m0644 /tmp/DEB-GPG-KEY-scootersoftware.asc /etc/apt/trusted.gpg.d/; \
	install -m0644 /tmp/scootersoftware.list /etc/apt/sources.list.d/; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
	  krusader breeze-icon-theme kompare krename bzip2 lzma xz-utils lhasa zip unzip arj unace rar unrar p7zip-full rpm konsole gedit gwenview dbus-x11 keditbookmarks feh fonts-takao fonts-arphic-uming fonts-noto-cjk apt-utils nano bcompare; \
	# create locales
	echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen; \
	echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen; \
	locale-gen; \
	apt-get upgrade -y; \
	# symlinks and timezone
	ln -s /usr/bin/arj /usr/bin/unarj || true; \
	ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
	echo ${TZ} > /etc/timezone; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/* /tmp/*

# Extract provided locales archive and remove it in same layer
COPY locales_krusader.tar /tmp/locales_krusader.tar
RUN tar -C / -xvf /tmp/locales_krusader.tar && rm -f /tmp/locales_krusader.tar

# Create data dir and user, set ownership in single RUN
RUN mkdir -p ${DATA_DIR} && \
	useradd -d ${DATA_DIR} -s /bin/bash ${USER} && \
	chown -R ${UID}:${GID} ${DATA_DIR} && \
	ulimit -n 2048

# Use COPY instead of ADD and set permissions/ownership in the same layer
COPY scripts/ /opt/scripts/
COPY icons/ /usr/share/novnc/app/images/icons/
COPY conf/ /etc/.fluxbox/
RUN chmod -R 770 /opt/scripts/ && \
	chown -R ${UID}:${GID} /opt/scripts /usr/share/novnc/app/images/icons /etc/.fluxbox || true; \
	if [ -d /mnt ]; then chown -R ${UID}:${GID} /mnt || true; chmod -R 770 /mnt || true; fi

EXPOSE 8080

# Consider switching to non-root user if start-up does not require root; left commented for now
# USER ${USER}

# Server Start
ENTRYPOINT ["/opt/scripts/start.sh"]