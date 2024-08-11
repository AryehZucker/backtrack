#! /bin/bash



CONFDIR="$HOME/.config/backtrack"


# Process command line arguments
if [[ "$1" == "-v" ]]; then
	VERB="--verbose"
fi


# Input password and verify
read -s -p "Enter passphrase: " passphrase
echo
passhash=$(shasum --algorithm 256 <<<"$passphrase")
passhash_old=$(cat "$CONFDIR/passhash.conf")
until [[ "$passhash" == "$passhash_old" ]]; do
	echo "Incorrect passphrase"
	read -s -p "Enter passphrase: " passphrase
	echo
	passhash=$(shasum --algorithm 256 <<<"$passphrase")
done


# Read paths from paths.conf
#bug: cannot process pathnames with spaces
#add: process wildcards
#add: exclude paths
paths=
while read -r path; do
	#skip past comments and blank lines
	if [[ "$path" == "#"* || "$path" =~ ^[[:space:]]*$ ]]; then
		continue
	fi

	#check that path is absolute
	if [[ "$path" != /* ]]; then
		echo "Error: $path: paths must be absolute" >&2
		exit 1
	fi

	paths="$paths $path"
done <"$CONFDIR/paths.conf"


# Archive, compress, and encrypt files
#bug: resulting tar file is root owned
archfile="/tmp/files.$$.tmp"
sudo tar --create $paths >$archfile
gpg $VERB --batch --compress-algo zlib --passphrase "$passphrase" --output $archfile.gpg --symmetric $archfile


# Update packages
echo "New packages to add:"
package=" "
until [[ -z "$package" ]]; do
	read -r package
	if [[ "$package" ]]; then
		echo "$package" >>"$CONFDIR/packages.conf"
	fi
done


# Encrypt package list
packagefile="/tmp/packages.$$.tmp"
gpg $VERB --batch --passphrase "$passphrase" --output $packagefile --symmetric "$CONFDIR/packages.conf"


# Upload archive & package list
remote=$(cat "$CONFDIR/remote-backup-path.conf")
rclone -P --config="$CONFDIR/rclone.conf" copyto $archfile.gpg $remote/files
rclone -P --config="$CONFDIR/rclone.conf" copyto $packagefile $remote/packages


# Remove temp files
rm $archfile $archfile.gpg $packagefile

# Done
echo Done
