#!/bin/bash
export DISPLAY=:1
export XDG_RUNTIME_DIR=/tmp/xdg
export LANGUAGE="$LOCALE_USR"
export LANG="$LOCALE_USR"
export XAUTHORITY=${DATA_DIR}/.Xauthority

echo "---Checking for old logfiles---"
find $DATA_DIR -name "XvfbLog.*" -exec rm -f {} \;
find $DATA_DIR -name "x11vncLog.*" -exec rm -f {} \;
echo "---Checking for old display lock files---"
rm -rf /tmp/.X1*
rm -rf /tmp/.X11*
rm -rf ${DATA_DIR}/.vnc/*.log ${DATA_DIR}/.vnc/*.pid
chmod -R ${DATA_PERM} ${DATA_DIR}
if [ -f ${DATA_DIR}/.vnc/passwd ]; then
	if [ "${RUNASROOT}" == "true" ]; then
		chmod 600 /root/.vnc/passwd
	else
		chmod 600 ${DATA_DIR}/.vnc/passwd
	fi
fi

echo "---Resolution check---"
if [ -z "${CUSTOM_RES_W}" ]; then
	CUSTOM_RES_W=1900
fi
if [ -z "${CUSTOM_RES_H}" ]; then
	CUSTOM_RES_H=1000
fi

if [ "${CUSTOM_RES_W}" -le 1023 ]; then
	echo "---Width too low, must be a minimum of 1024 pixels, correcting to 1024...---"
    CUSTOM_RES_W=1024
fi
if [ "${CUSTOM_RES_H}" -le 767 ]; then
	echo "---Height too low, must be a minimum of 768 pixels, correcting to 768...---"
    CUSTOM_RES_H=768
fi

echo "---Starting D-Bus---"
mkdir -p /var/run/dbus
# Start system D-Bus
dbus-daemon --system --fork 2>/dev/null || true
# Start session D-Bus for the krusader user
su ${USER} -c "dbus-daemon --session --fork --address=unix:path=/tmp/dbus-session" 2>/dev/null || true
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session

echo "---Starting VNC server---"
mkdir -p ${DATA_DIR}/.vnc
# Create xstartup script if it doesn't exist
if [ ! -f ${DATA_DIR}/.vnc/xstartup ]; then
	cat > ${DATA_DIR}/.vnc/xstartup << 'EOF'
#!/bin/bash
export HOME=/etc
# Start Fluxbox and keep it running in foreground
exec /usr/bin/fluxbox
EOF
	chmod +x ${DATA_DIR}/.vnc/xstartup
fi

# Start VNC with TigerVNC
vncserver :1 \
	-geometry ${CUSTOM_RES_W}x${CUSTOM_RES_H} \
	-depth ${CUSTOM_DEPTH} \
	-rfbport ${RFB_PORT} \
	-SecurityTypes None \
	-AlwaysShared \
	-AcceptPointerEvents \
	-AcceptKeyEvents \
	-AcceptSetDesktopSize \
	-SendCutText \
	-AcceptCutText \
	2>&1 | tee ${DATA_DIR}/.vnc/vncserver.log

sleep 3

# Verify VNC server is running
if ! ps aux | grep -v grep | grep -q "Xtigervnc :1"; then
	echo "---ERROR: VNC server failed to start---"
	cat ${DATA_DIR}/.vnc/*.log
	exit 1
fi

echo "---VNC server started successfully---"

echo "---Starting noVNC server---"
/usr/share/novnc/utils/novnc_proxy --vnc localhost:${RFB_PORT} --listen ${NOVNC_PORT} 2>&1 | tee ${DATA_DIR}/.vnc/novnc.log &
sleep 2

echo "---Waiting for X display to be ready---"
for i in {1..10}; do
	if xdpyinfo -display :1 >/dev/null 2>&1; then
		echo "---X display :1 is ready---"
		break
	fi
	echo "Waiting for display... ($i/10)"
	sleep 1
done

echo "---Starting Krusader---"
cd ${DATA_DIR}

# Start session D-Bus daemon for KDE applications
echo "---Starting session D-Bus---"
export DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-session
dbus-daemon --session --fork --address=${DBUS_SESSION_BUS_ADDRESS}
sleep 1

# Set up Qt/KDE environment variables
export QT_X11_NO_MITSHM=1
export QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb
export XDG_RUNTIME_DIR=/tmp/xdg

if [ "${RUNASROOT}" == "true" ]; then
	echo
	echo "+--------------------------------------------------------------------------------"
	echo "|"
	echo "| You are running Krusader as root, please be very careful what you are doing!!!"
	echo "|"
	echo "+--------------------------------------------------------------------------------"
	echo
	if [ "${DEV}" == "true" ]; then
		if [ ! -d /root/.config ]; then
			/usr/bin/krusader --left /mnt --right /mnt ${START_PARAMS}
		else
			/usr/bin/krusader ${START_PARAMS}
		fi
	else
		if [ ! -d /root/.config ]; then
			/usr/bin/krusader --left /mnt --right /mnt ${START_PARAMS} 2> /dev/null
		else
			/usr/bin/krusader ${START_PARAMS} 2> /dev/null
		fi
	fi
else
	if [ "${DEV}" == "true" ]; then
		if [ ! -d ${DATA_DIR}/.config ]; then
			/usr/bin/krusader --left /mnt --right /mnt ${START_PARAMS}
		else
			/usr/bin/krusader ${START_PARAMS}
		fi
	else
		if [ ! -d ${DATA_DIR}/.config ]; then
			/usr/bin/krusader --left /mnt --right /mnt ${START_PARAMS} 2> /dev/null
		else
			/usr/bin/krusader ${START_PARAMS} 2> /dev/null
		fi
	fi
fi

# Keep container alive even if Krusader exits
echo "---Krusader process ended, keeping container alive---"
tail -f ${DATA_DIR}/.vnc/*.log