#! /bin/bash



NAME="backtrack"
CONFDIR="$HOME/.config/backtrack"
mkdir -p "$CONFDIR"


# Process command line arguments
if [[ "$1" == "-v" ]]; then
	VERB="--verbose"
	shift
fi


# Clean up temporary files before every exit
function cleanup {
	find "/tmp" -name "$NAME.$$.*.tmp" -delete
}
trap cleanup EXIT


function config {
	echo "Configuring backtrack..."
	
	# Install dependencies
	if [[ -z $(which rclone) ]]; then
		echo "Installing rclone..."
		apt-get update && apt-get install rclone -y
	fi
	
	# Set up rclone remote
	echo -e "Create an rclone remote for backups\n"
	rclone config --config="$CONFDIR/rclone.conf"
	echo
	
	# Select remote dir for backups
	#bug: must not end in /
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
		read -s -p "Enter secret pasphrase to encrypt backup [blank to use existing]: " passphrase && echo
		read -s -p "Confirm secret pasphrase [blank to use existing]: " passphrase_confirm && echo
		until [[ "$passphrase" == "$passphrase_confirm" ]]; do
			read -s -p "Enter secret pasphrase to encrypt backup [blank to use existing]: " passphrase && echo
			read -s -p "Confirm secret pasphrase [blank to use existing]: " passphrase_confirm && echo
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
	
	# Done config
	echo "Configuration complete"
}


function backup {
	echo "Backing up computer..."
	
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
	archive_file="/tmp/$NAME.$$.files.tmp"
	backup_file="/tmp/$NAME.$$.backup.tmp"
	sudo tar --create $paths >$archive_file
	gpg $VERB --batch --compress-algo zlib --passphrase "$passphrase" --output $backup_file --symmetric $archive_file
	
	
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
	package_file="/tmp/$NAME.$$.packages.tmp"
	gpg $VERB --batch --passphrase "$passphrase" --output $package_file --symmetric "$CONFDIR/packages.conf"
	
	
	# Upload archive & package list
	#add: upload to folder remote/hostname/date-time/
	remote=$(cat "$CONFDIR/remote-backup-path.conf")
	rclone -P --config="$CONFDIR/rclone.conf" copyto $backup_file $remote/files
	rclone -P --config="$CONFDIR/rclone.conf" copyto $package_file $remote/packages
}


function restore {
	echo "Restoring computer from backup..."
	
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
		read -s -p "Enter secret pasphrase to decrypt backup: " passphrase && echo
	done
	
	
	# Restore files
	archive_file="/tmp/$NAME.$$.files.tmp"
	backup_file="/tmp/$NAME.$$.backup.tmp"
	rclone -P --config="$CONFDIR/rclone.conf" copyto $remote/files $backup_file
	gpg $VERB --batch --compress-algo zlib --passphrase "$passphrase" --output $archive_file --decrypt $backup_file
	dir=`pwd`
	read -p "Extract to root (/) [y/n]? "
	if [[ "$REPLY" == y* ]]; then
		dir="/"
	fi
	cd "$dir"
	sudo tar --extract --same-permissions --same-owner --file="$archive_file"
	cd -
	
	
	# Install packages
	package_file="/tmp/$NAME.$$.packages.tmp"
	rclone -P --config="$CONFDIR/rclone.conf" copyto $remote/packages $package_file
	while read -r package; do
		#skip past comments and blank lines
		if [[ "$package" == "#"* || "$package" =~ ^[[:space:]]*$ ]]; then
			continue
		fi
	
		packages="$packages $package"
	done < <(gpg $VERB --batch --passphrase "$passphrase" --decrypt "$package_file")
	echo $packages
	sudo apt-get update && sudo apt-get install $packages -y
}


# Execute propper command
case $1 in
	config)
		config
	;;
	
	backup|"")
		# Check if configuration is needed
		if [[ -z $(which rclone) ||
				! -f "$CONFDIR/packages.conf" ||
				! -f "$CONFDIR/passhash.conf" ||
				! -f "$CONFDIR/paths.conf" ||
				! -f "$CONFDIR/rclone.conf" ||
				! -f "$CONFDIR/remote-backup-path.conf" ]]; then
			config
		fi
		backup
	;;
	
	restore)
		resore
	;;
	
	help|*)
		echo "Usage: backtrack [help|config|backup|restore]"
		exit
	;;
esac

# Done
echo -e "\nDone"
