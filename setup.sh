#! /bin/bash

CONFDIR="$HOME/.config/backtrack"
mkdir -p "$CONFDIR"

# Install dependencies
if [[ -z $(which rclone) ]]; then
	echo "Installing rclone..."
	apt-get update && apt-get install rclone -y
fi

# Set up rclone remote
read -p "Would you like to set up a new connection for remote storage [y/n]? "
if [[ "$REPLY" == y* ]]; then
	rclone config --config="$CONFDIR/rclone.conf"
	echo
fi

# Select remote dir for backups
if [[ -s "$CONFDIR/remote-backup-path.conf" ]]; then
	read -p "Enter remote backup directory (remote:path/to/dir/) [default: $(cat $CONFDIR/remote-backup-path.conf)]: " backup_dir
	if [[ -n "$backup_dir" ]]; then
		echo "$backup_dir" >"$CONFDIR/remote-backup-path.conf"
	fi
else
	until [[ -n "$backup_dir" ]]; do
	        read -p "Enter remote backup directory (remote:path/to/dir/): " backup_dir
	done
	echo "$backup_dir" >"$CONFDIR/remote-backup-path.conf"
fi

# Set up a passphrase
if [[ -s "$CONFDIR/passhash.conf" ]]; then
	read -s -p "Enter secret pasphrase to encrypt backup [blank to use existing]: " passphrase
	echo
	read -s -p "Confirm secret pasphrase [blank to use existing]: " passphrase_confirm
	echo
	until [[ "$passphrase" == "$passphrase_confirm" ]]; do
		read -s -p "Enter secret pasphrase to encrypt backup [blank to use existing]: " passphrase
		echo
		read -s -p "Confirm secret pasphrase [blank to use existing]: " passphrase_confirm
		echo
	done
	if [[ -n "$passphrase" ]]; then
		shasum --algorithm 256 <<<"$passphrase" >"$CONFDIR/passhash.conf"
	fi
else
	until [[ -n "$passphrase" && "$passphrase" == "$passphrase_confirm" ]]; do
		read -s -p "Enter secret pasphrase to encrypt backup: " passphrase
		echo
		read -s -p "Confirm secret pasphrase: " passphrase_confirm
		echo
	done
	shasum --algorithm 256 <<<"$passphrase" >"$CONFDIR/passhash.conf"
fi
chmod 600 "$CONFDIR/passhash.conf"

# Select paths to back up
if [[ ! -f "$CONFDIR/paths.conf" ]]; then
	echo -en "# List local files and directories to back up\n\n" >"$CONFDIR/paths.conf"
fi
nano "$CONFDIR/paths.conf"

# Select packages to install on restore
if [[ ! -f "$CONFDIR/packages.conf" ]]; then
        echo -en "# List packages to install on restore\n\n" >"$CONFDIR/packages.conf"
fi
nano "$CONFDIR/packages.conf"

echo "Setup complete"
