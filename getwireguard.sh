#!/bin/sh
# shellcheck disable=SC3043

# WireGuard installation script for Ubiquiti
# Inspired by: https://github.com/whiskerz007/ubnt_get_wireguard/blob/master/get_wireguard.sh

## Config section
# desired version (like 1.0.20201221-1)
# -> provided by first argument
VERSION=
# firmware version (v1 or v2)
# -> overwritten by second argument
FWVERSION=v1

## Script config section
FIRSTBOOT_DIR='/config/data/firstboot/install-packages'

## Code section

# Functions

echoJob() {
	local message="$1"

	echo "## $message"
	echo
}

exitError() {
	local message="$1"

	echo "ERROR: $message"
	echo "Exiting ..."
	exit 1
}

# Must run as root
if [ "$(/usr/bin/id -u)" -ne 0 ]; then
	exitError "Please run as root"
fi

# Check arguments
if [ $# -lt "1" ]; then
	echo "Usage:"
	echo "  getwireguard.sh <version> [<tools version>] [<firmware revision: v1/v2>]"
	echo
	echo "  getwireguard.sh 1.0.20201221-1 1.0.20210101 v2"
	echo "  getwireguard.sh 1.0.20201221-1 1.0.20210101"
	echo "  getwireguard.sh 1.0.20201221-1"
	echo
	echo "Default tools version is the same as the specified primary version (without suffix)."
	echo "Default firmware revision is v1."
	echo
	exit 1
fi

# Parse arguments
[ -n "$1" ] && VERSION=$1
[ -n "$2" ] && TOOLS=$2
[ -n "$3" ] && FWVERSION=$3

# Remove leading "v" from version (optional)
VERSION=$(echo "$VERSION" | sed 's/^v//' )
TOOLS=$(echo "$TOOLS" | sed 's/^v//' )

# Set TOOLS if not set
SHORTVER=$(echo "$VERSION" | sed 's/-.*//')
[ -n "$TOOLS" ] || TOOLS="$SHORTVER"

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
	echo
	echo "Installed WireGuard version: $INSTALLED_VERSION"
	echo "Requested WireGuard version: $VERSION"
	echo "( Requested Tools version:   $TOOLS )"
	echo

	while true; do
		read -p "Download and install $VERSION? [y/n] " answer
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
	echo
	echo "WireGuard not installed."
	echo "Requested WireGuard version: $VERSION"
	echo "( Requested Tools version:   $TOOLS )"
	echo
fi

# Assemble URL
URL="https://github.com/WireGuard/wireguard-vyatta-ubnt/releases/download/${VERSION}/${BOARD}-${FWVERSION}-v${SHORTVER}-v${TOOLS}.deb"
DEBFILE=$(basename "$URL")
DEBPATH="/tmp/$DEBFILE"

# Download
echo
echoJob "Downloading package ..."
echo "URL: $URL"
echo

curl --silent --fail --location "$URL" -o "$DEBPATH" || \
	exitError "Error $? during download."

# Check downloaded file
[ -s "$DEBPATH" ] || \
	exitError "Downloaded file is empty or does not exist."

# Check package integrity
echoJob "Checking integrity ..."

dpkg-deb --info "$DEBPATH" >/dev/null || \
	exitError "Debian package integrity check failed for package."

# Install package
echoJob "Installing package ..."

dpkg -i "$DEBPATH" || \
	exitError "A problem occured while installing the package."

# Enable firmware upgrade persistence
echo
echoJob "Enable firmware upgrade persistence ..."

# Delete older packages
OLDER_PKG_PATTERN="${FIRSTBOOT_DIR}/wireguard*.deb"
# shellcheck disable=SC2086
OLDER_PKGS=$(ls $OLDER_PKG_PATTERN 2>/dev/null)

if [ -n "$OLDER_PKGS" ]; then
	echo "Older packages found:"
	for f in $OLDER_PKGS; do
		echo "$f" | sed 's#.*/#  #'
	done
	echo

	while true; do
		read -p "Delete older packages? [y/n] " answer
		case $answer in
			[Yy]* )
				echo "Deleting old files ..."
				echo
				# shellcheck disable=SC2086
				rm $OLDER_PKG_PATTERN
				break
				;;
			[Nn]* )
				echo "Keeping old packages."
				echo "This will probably result in a broken state after the new package has been installed."
				echo "Files are found in: $FIRSTBOOT_DIR"
				echo
				break
				;;
		esac
	done
fi

echo "Moving current package ..."
echo

FIRSTBOOT_PATH="${FIRSTBOOT_DIR}/wireguard_${VERSION}.deb"
mkdir -p "$FIRSTBOOT_DIR" && mv "$DEBPATH" "$FIRSTBOOT_PATH"

[ -s "$FIRSTBOOT_PATH" ] || \
	exitError "Error during firstboot setup. Please investigate ..."

echoJob "Finished."
exit 0
