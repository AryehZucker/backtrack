# Backtrack - Backup and Restore Automation Script

**Backtrack** is a Bash script designed to automate the backup and restoration of important files and applications on a Linux system. It leverages `rclone` to configure backups for storage on any major cloud service, ensuring your data is safe and easily recoverable.

## Prerequisites

Before using **Backtrack**, ensure the following software is installed on your system:

- `apt-get`
- `gpg`
- `shasum`
- `tar`
- `nano`

If `rclone` is not already installed, **Backtrack** will automatically install it for you.

## Installation

To install **Backtrack**, place the script in a directory that is included in your `PATH`, such as:

- `~/bin/`
- `/usr/local/bin/`

## Usage

**Backtrack** is a command-line tool that can be used with the following options:

```
backtrack [help|config|backup|restore]
```

### Options

- **help**: Displays usage information.
- **config**:
    - Sets up an `rclone` remote.
    - Prompts for the remote directory to back up to.
    - Asks for a passphrase for encryption.
    - Prompts for paths to back up and packages to install upon restore.
- **backup** (default option):
    - Prompts for your passphrase.
    - Archives, compresses, and encrypts your files.
    - Prompts for any packages to add to the list for installation upon restore.
    - Uploads the files via rclone to the previously configured storage location.
- **restore**:
    - Sets up an `rclone` remote.
    - Prompts for the remote directory to restore from.
    - Prompts for the passphrase for decryption.
    - Restores files by downloading, decrypting, and decompressing.
    - Installs packages.
