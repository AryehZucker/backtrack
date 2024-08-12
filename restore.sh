#! /bin/bash

CONFDIR="$HOME/.config/backtrack"
mkdir -p "$CONFDIR"


# Process command line arguments
if [[ "$1" == "-v" ]]; then
	VERB="--verbose"
fi


# Install dependencies
if [[ -z $(which rclone) ]]; then
	echo "Installing rclone..."
	apt-get update && apt-get install rclone -y
fi


# Set up rclone remote
echo "Setting up connection for remote storage"
rclone config --config="$CONFDIR/rclone.conf"


# Select remote dir for backups
if [[ -s "$CONFDIR/remote-backup-path.conf" ]]; then
	read -p "Enter remote backup directory (remote:path/to/dir/) [default: $(cat $CONFDIR/remote-backup-path.conf)]: " remote
	if [[ -z "$remote" ]]; then
		remote=$(cat "$CONFDIR/remote-backup-path.conf")
	fi
else
	until [[ -n "$remote" ]]; do
	        read -p "Enter remote backup directory (remote:path/to/dir/): " remote
	done
fi


# Input passphrase
until [[ -n "$passphrase" ]]; do
	read -s -p "Enter secret pasphrase to decrypt backup: " passphrase
	echo
done


# Restore files
archfile="/tmp/files.$$.tmp"
rclone -P --config="$CONFDIR/rclone.conf" copyto $remote/files $archfile.gpg
gpg $VERB --batch --compress-algo zlib --passphrase "$passphrase" --output $archfile --decrypt $archfile.gpg
dir=`pwd`
read -p "Extract to root (/) [y/n]? "
if [[ "$REPLY" == y* ]]; then
	dir="/"
fi
cd "$dir"
sudo tar --extract --same-permissions --same-owner --file="$archfile"
cd -


# Install packages
packagefile="/tmp/packages.$$.tmp"
rclone -P --config="$CONFDIR/rclone.conf" copyto $remote/packages $packagefile
while read -r package; do
	#skip past comments and blank lines
	if [[ "$package" == "#"* || "$package" =~ ^[[:space:]]*$ ]]; then
		continue
	fi

	packages="$packages $package"
done < <(gpg $VERB --batch --passphrase "$passphrase" --decrypt "$packagefile")
echo $packages
sudo apt-get update && sudo apt-get install $packages -y


# Remove temp files
rm $archfile $archfile.gpg $packagefile


echo -e "\nDone"
