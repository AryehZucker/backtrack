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
	rclone config
	echo
fi

# Select remote dir for backups
if [[ -s "$CONFDIR/remote-backup-path" ]]; then
	read -p "Enter remote backup directory (remote:path/to/dir/) [default: $(cat $CONFDIR/remote-backup-path)]: " backup_dir
	if [[ -n "$backup_dir" ]]; then
		echo "$backup_dir" >"$CONFDIR/remote-backup-path.conf"
	fi
else
	until [[ -n "$backup_dir" ]]; do
	        read -p "Enter remote backup directory (remote:path/to/dir/): " backup_dir
	done
	echo "$backup_dir" >"$CONFDIR/remote-backup-path.conf"
fi

# Select paths to back up
if [[ ! -f "$CONFDIR/paths.conf" ]]; then
	echo -en "# List local files and directories to back up (supports wildcards)\n\n" >"$CONFDIR/paths.conf"
fi
nano "$CONFDIR/paths.conf"

# Select packages to install on restore
if [[ ! -f "$CONFDIR/packages.conf" ]]; then
        echo -en "# List packages to install on restore\n\n" >"$CONFDIR/packages.conf"
fi
nano "$CONFDIR/packages.conf"

echo "Setup complete"
