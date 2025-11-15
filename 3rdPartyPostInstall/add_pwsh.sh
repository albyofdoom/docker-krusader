#!/bin/sh
set -e

POWERSHELL_VERSION=7.4.6
ARCHIVE_MUSL="powershell-${POWERSHELL_VERSION}-linux-musl-x64.tar.gz"
ARCHIVE_GLIBC="powershell-${POWERSHELL_VERSION}-linux-x64.tar.gz"

# Detect distro
. /etc/os-release

case "$ID" in
  alpine)
    echo "🧊 Detected Alpine Linux ($VERSION_ID)"
    if [ "$(printf '%s\n' "3.19" "$VERSION_ID" | sort -V | head -n1)" = "3.19" ]; then
      SSL_PACKAGE="libssl3"
    else
      SSL_PACKAGE="libssl1.1"
    fi

    apk add --no-cache \
      ca-certificates \
      less \
      ncurses-terminfo-base \
      krb5-libs \
      libgcc \
      libintl \
      $SSL_PACKAGE \
      libstdc++ \
      tzdata \
      userspace-rcu \
      zlib \
      icu-libs \
      curl

    DOWNLOAD_URL="https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/${ARCHIVE_MUSL}"
    ;;

  debian|ubuntu)
    echo "🧱 Detected Debian/Ubuntu ($VERSION_ID)"
    
    # Detect ICU library version available
    if apt-cache show libicu74 >/dev/null 2>&1; then
      ICU_PKG="libicu74"
    elif apt-cache show libicu72 >/dev/null 2>&1; then
      ICU_PKG="libicu72"
    elif apt-cache show libicu67 >/dev/null 2>&1; then
      ICU_PKG="libicu67"
    elif apt-cache show libicu66 >/dev/null 2>&1; then
      ICU_PKG="libicu66"
    else
      echo "❌ No compatible libicu package found"
      exit 1
    fi
    
    echo "   Using ICU package: $ICU_PKG"
    
    apt-get update && apt-get install -y --no-install-recommends \
      curl \
      $ICU_PKG \
      libssl3 \
      libgssapi-krb5-2 \
      zlib1g \
      libstdc++6 \
      libgcc-s1 \
      ca-certificates \
      less && \
    rm -rf /var/lib/apt/lists/*

    DOWNLOAD_URL="https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/${ARCHIVE_GLIBC}"
    ;;

  *)
    echo "❌ Unsupported distro: $ID"
    exit 1
    ;;
esac

# Install PowerShell
echo "⬇️  Downloading PowerShell $POWERSHELL_VERSION..."
INSTALL_DIR="/opt/microsoft/powershell/$POWERSHELL_VERSION"
mkdir -p "$INSTALL_DIR"

if ! curl -fsSL "$DOWNLOAD_URL" -o /tmp/powershell.tar.gz; then
  echo "❌ Failed to download PowerShell from $DOWNLOAD_URL"
  exit 1
fi

echo "📦 Extracting PowerShell..."
tar zxf /tmp/powershell.tar.gz -C "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/pwsh"
ln -sf "$INSTALL_DIR/pwsh" /usr/bin/pwsh
rm /tmp/powershell.tar.gz

# Verify installation
if pwsh -version >/dev/null 2>&1; then
  echo "✅ PowerShell $POWERSHELL_VERSION installed successfully!"
  pwsh -version
else
  echo "❌ PowerShell installation failed verification"
  exit 1
fi