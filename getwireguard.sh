#!/bin/sh

# WireGuard installation script for Ubiquiti
# Inspired by: https://github.com/whiskerz007/ubnt_get_wireguard/blob/master/get_wireguard.sh

## Config section
# desired version (like 1.0.20201221-1)
# -> provided by first argument
VERSION=
# firmware version (v1 or v2)
# -> overwritten by second argument
FWVERSION=v2

## Script config section
FIRSTBOOT_DIR='/config/data/firstboot/install-packages'

## Code section

# Must run as root
if [ "$(/usr/bin/id -u)" -ne 0 ]; then
	echo "Please run as root"
	exit 1
fi

# Check arguments
if [ $# -lt "1" ]; then
	echo "Usage: getwireguard.sh <version, e.g. 1.0.20201221-1> [<firmware revision: v1/v2>]"
	exit 1
fi

# Parse arguments
[ -n "$1" ] && VERSION=$1
[ -n "$2" ] && FWVERSION=$2

# Remove leading "v" from version
VERSION=$(echo "$VERSION" | sed 's/^v//' )

# Check board name of device
BOARD=$(cut -d'.' -f2 < /etc/version | sed 's/ER-//I')

# Set board mapping to match repo
case $BOARD in
	e120)  BOARD='ugw3';;
	e220)  BOARD='ugw4';;
	e1020) BOARD='ugwxg';;
esac

echo "Board: $BOARD"

# Check installed version (like 1.0.20201221-1)
INSTALLED_VERSION=$(dpkg-query --show --showformat='${Version}' wireguard 2> /dev/null)

if [ -n "$INSTALLED_VERSION" ]; then
	echo "Installed WireGuard version: $INSTALLED_VERSION"
	echo "Requested WireGuard version: $VERSION"
	echo

	while true; do
		read -p "Download and install $VERSION? [y/n]" answer
		case $answer in
			[Yy]* )
				break
				;;
			[Nn]* )
				exit 0
				;;
		esac
	done
else
	echo "WireGuard not installed."
	echo "Requested WireGuard version: $VERSION"
fi

# Assemble URL
SHORTVER=$(echo "$VERSION" | sed 's/-.*//')
URL="https://github.com/WireGuard/wireguard-vyatta-ubnt/releases/download/${VERSION}/${BOARD}-${FWVERSION}-v${SHORTVER}-v${SHORTVER}.deb"
DEBFILE=$(basename "$URL")
DEBPATH="/tmp/$DEBFILE"

# Download
echo "Downloading package ..."
echo "URL: $URL"

curl --silent --location "$URL" -o "$DEBPATH" || {
	echo "Error during download. Exiting ..."
	exit 1
}

# Check package integrity
echo "Checking integrity ..."

dpkg-deb --info "$DEBPATH" >/dev/null || {
	echo "Debian package integrity check failed for package. Exiting ..."
	exit 1
}

# Install package
echo "Installing package ..."

dpkg -i "$DEBPATH" || {
	echo "A problem occured while installing the package. Exiting ..."
	exit 1
}

# Enable firmware upgrade persistence
echo "Enable firmware upgrade persistence ..."

FIRSTBOOT_PATH="${FIRSTBOOT_DIR}/wireguard_${VERSION}.deb"
mkdir -p "$FIRSTBOOT_DIR" && mv "$DEBPATH" "$FIRSTBOOT_PATH"

[ -s "$FIRSTBOOT_PATH" ] || {
	echo "Error during firstboot setup. Please investigate ..."
	exit 1
}

echo "Finished."
exit 0
