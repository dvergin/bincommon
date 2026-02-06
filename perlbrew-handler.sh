#!/bin/bash

# --- 1. Root Safety Check ---
if [[ $EUID -eq 0 ]]; then
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo "ERROR: DO NOT RUN THIS SCRIPT WITH SUDO OR AS ROOT."
   echo "Perlbrew is designed to manage Perl as a regular user."
   echo "The script will ask for your password only when needed."
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
   exit 1
fi

# --- 2. User Acknowledgment ---
clear
echo "============================================================"
echo "          PERLBREW AUTOMATED UPDATE ENGINE                 "
echo "============================================================"
echo " This script will:"
echo " 1. Install the latest stable Perl via perlbrew."
echo " 2. Migrate your CPAN modules to the new version."
echo " 3. Update the global CGI symlink (/usr/local/bin/site-perl)."
echo ""
echo " IMPORTANT: You will be prompted for your [sudo] password "
echo " during the final steps to update system-level symlinks.   "
echo "============================================================"
read -p " Press [ENTER] to acknowledge and begin the process... "

# --- 3. Environment Setup ---
if [ -z "$PERLBREW_ROOT" ]; then
    [ -f ~/perl5/perlbrew/etc/bashrc ] && source ~/perl5/perlbrew/etc/bashrc
fi

SYMLINK_DIR="/usr/local/bin/site-perl"
SYMLINK_PATH="$SYMLINK_DIR/perl"

echo "--- Checking Environment ---"
# Ensure perlbrew-specific cpanm exists
which cpanm | grep -q "perlbrew" || perlbrew install-cpanm

# Ensure Symlink Directory exists
if [ ! -d "$SYMLINK_DIR" ]; then
    echo "Creating system directory $SYMLINK_DIR (requires sudo)..."
    sudo mkdir -p "$SYMLINK_DIR"
fi

# --- 4. Version Identification ---
CURRENT=$(perlbrew list | grep '*' | tr -d '* ' | sed 's/ (.*)//')
LATEST=$(perlbrew available | grep -v 'i' | head -n 1 | awk '{print $1}')

if [ -z "$CURRENT" ]; then
    echo "Error: No active perlbrew version detected. Please run 'perlbrew switch' first."
    exit 1
fi

if [ "$CURRENT" == "$LATEST" ]; then
    echo "Status: Already on latest version ($CURRENT)."
    # We still run the symlink/permission logic to ensure stability
else
    echo "Updating: $CURRENT -> $LATEST"

    # Install new version
    perlbrew install "$LATEST" --notest --noman

    # Migrate modules
    echo "Migrating modules..."
    perlbrew clone-modules "$CURRENT" "$LATEST"

    # Verification
    OLD_COUNT=$(perlbrew list-modules | wc -l)
    perlbrew use "$LATEST"
    NEW_COUNT=$(perlbrew list-modules | wc -l)

    if [ "$NEW_COUNT" -lt "$OLD_COUNT" ]; then
        echo "Warning: Only $NEW_COUNT/$OLD_COUNT modules migrated successfully."
        echo "Manual review required. Switching to new version but NOT uninstalling $CURRENT."
        perlbrew switch "$LATEST"
    else
        perlbrew switch "$LATEST"
        perlbrew uninstall "$CURRENT"
        echo "Migration successful. Old version removed."
    fi
fi

# --- 5. Global Symlink & Permissions ---
echo "--- Finalizing System Integration (requires sudo) ---"
sudo ln -sf "$(which perl)" "$SYMLINK_PATH"
sudo chmod +x "$HOME"
sudo chmod -R +x "$HOME/perl5"

echo "--- Process Complete ---"
echo "Active Perl: $(perl -v | grep -o 'v[0-9]\.[0-9]*\.[0-9]*')"
echo "CGI Symlink: $(ls -l $SYMLINK_PATH | awk '{print $9,$10,$11}')"
echo ""
echo "Please run 'source ~/perl5/perlbrew/etc/bashrc' to update this shell."

