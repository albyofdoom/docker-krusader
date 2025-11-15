FROM debian:bookworm-slim

LABEL org.opencontainers.image.authors="admin@minenet.at"
LABEL org.opencontainers.image.source="https://github.com/albyofdoom/docker-krusader"

# Set timezone argument
ARG TZ=Europe/Rome
ENV TZ=${TZ}

# Install base system, VNC, noVNC, window manager, and application packages
RUN export DEBIAN_FRONTEND=noninteractive && \
	# Add contrib and non-free repos for rar/unrar
	echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
	echo "deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
	echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list && \
	apt-get update && \
	apt-get -y install --no-install-recommends \
		# Base utilities
		wget curl ca-certificates gnupg procps xz-utils supervisor \
		# VNC and display
		tigervnc-standalone-server tigervnc-common \
		x11vnc xvfb x11-utils \
		# Window manager and desktop components
		fluxbox \
		xterm \
		# noVNC dependencies
		python3 python3-numpy \
		novnc \
		# Krusader and file management
		krusader breeze-icon-theme kompare krename \
		# Archive support
		bzip2 lzma lhasa zip unzip arj unace rar unrar p7zip-full rpm \
		# Terminal and editors
		konsole gedit nano \
		# Image viewer
		gwenview feh \
		# Desktop integration
		dbus-x11 keditbookmarks \
		# Fonts (including CJK support)
		fonts-takao fonts-arphic-uming fonts-noto-cjk \
		# Utilities
		apt-utils bc locales \
		# Database client
		mariadb-client \
		&& \
	# Set up locales
	echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
	echo "ko_KR.UTF-8 UTF-8" >> /etc/locale.gen && \
	echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen && \
	locale-gen && \
	# Set timezone
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
	echo $TZ > /etc/timezone && \
	# Create symlink for unarj
	ln -s /usr/bin/arj /usr/bin/unarj && \
	# Clean up
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install Beyond Compare
RUN wget https://www.scootersoftware.com/DEB-GPG-KEY-scootersoftware.asc && \
	wget https://www.scootersoftware.com/scootersoftware.list && \
	install -m0644 DEB-GPG-KEY-scootersoftware.asc /etc/apt/trusted.gpg.d/ && \
	install -m0644 scootersoftware.list /etc/apt/sources.list.d/ && \
	rm -f DEB-GPG-KEY-scootersoftware.asc scootersoftware.list && \
	apt-get update && \
	apt-get -y install --no-install-recommends bcompare && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install PowerShell
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/microsoft.gpg && \
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/microsoft.list && \
	apt-get update && \
	apt-get -y install --no-install-recommends libicu72 powershell && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Copy locale translations
COPY locales_krusader.tar /tmp/locales_krusader.tar
RUN tar -C / -xvf /tmp/locales_krusader.tar && \
	rm -rf /tmp/locales_krusader.tar

# Set up noVNC
RUN ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# Environment variables
ENV DATA_DIR=/krusader \
	CUSTOM_RES_W=1920 \
	CUSTOM_RES_H=920 \
	CUSTOM_DEPTH=16 \
	NOVNC_PORT=8080 \
	RFB_PORT=5900 \
	UMASK=000 \
	UID=99 \
	GID=100 \
	DATA_PERM=770 \
	USER=krusader \
	USER_LOCALES="en_US.UTF-8 UTF-8" \
	DISPLAY=:1

# Create user and directories
RUN mkdir -p ${DATA_DIR} /var/run/dbus && \
	useradd -u ${UID} -d ${DATA_DIR} -s /bin/bash ${USER} && \
	chown -R ${UID}:${GID} ${DATA_DIR} && \
	ulimit -n 2048

# Copy scripts and configs
COPY scripts/ /opt/scripts/
COPY icons/ /usr/share/novnc/app/images/icons/
COPY conf/ /etc/.fluxbox/
RUN chmod -R 770 /opt/scripts/ && \
	mkdir -p /mnt && \
	chown -R ${UID}:${GID} /mnt && \
	chmod -R 770 /mnt

# Create supervisor config for VNC and noVNC
RUN mkdir -p /etc/supervisor/conf.d && \
	echo '[supervisord]' > /etc/supervisor/supervisord.conf && \
	echo 'nodaemon=true' >> /etc/supervisor/supervisord.conf && \
	echo 'user=root' >> /etc/supervisor/supervisord.conf && \
	echo '' >> /etc/supervisor/supervisord.conf && \
	echo '[include]' >> /etc/supervisor/supervisord.conf && \
	echo 'files = /etc/supervisor/conf.d/*.conf' >> /etc/supervisor/supervisord.conf

EXPOSE ${NOVNC_PORT} ${RFB_PORT}

WORKDIR ${DATA_DIR}

# Server Start
ENTRYPOINT ["/opt/scripts/start.sh"]