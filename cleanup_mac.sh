#!/bin/bash

# Mac System Cleanup Script
# Created by Antigravity

echo "==================================================="
echo "   STARTING MAC SYSTEM CLEANUP"
echo "==================================================="
echo "This script will delete caches, logs, and temporary files."
echo "Some steps require sudo (administrator) password."
echo ""

# Ask for sudo permission upfront to keep the session alive
sudo -v
# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Function to print status
print_status() {
    echo ""
    echo ">>> $1"
}

# 1. User Caches
print_status "Cleaning User Caches (~/Library/Caches)..."
# We exclude some sensitive folders if necessary, but generally nuke is requested
rm -rf ~/Library/Caches/* 2>/dev/null
echo "User Caches cleaned."

# 2. System Caches
print_status "Cleaning System Caches (/Library/Caches)... [SUDO]"
sudo rm -rf /Library/Caches/* 2>/dev/null
echo "System Caches cleaned."

# 3. User Logs
print_status "Cleaning User Logs (~/Library/Logs)..."
rm -rf ~/Library/Logs/* 2>/dev/null
echo "User Logs cleaned."

# 4. System Logs
print_status "Cleaning System Logs (/var/log, /Library/Logs)... [SUDO]"
sudo rm -rf /var/log/* 2>/dev/null
sudo rm -rf /Library/Logs/* 2>/dev/null
echo "System Logs cleaned."

# 5. Xcode DerivedData (often massive)
if [ -d "~/Library/Developer/Xcode/DerivedData" ]; then
    print_status "Cleaning Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null
    echo "Xcode DerivedData cleaned."
fi

# 6. Trash
print_status "Emptying Trash..."
rm -rf ~/.Trash/* 2>/dev/null
echo "Trash emptied."

# 7. Homebrew
if command -v brew &> /dev/null; then
    print_status "Cleaning Homebrew Cache..."
    brew cleanup
fi

# 8. Docker
if command -v docker &> /dev/null; then
    if docker info > /dev/null 2>&1; then
        print_status "Pruning Docker System (unused containers, networks, images)..."
        docker system prune -f
    fi
fi

# 9. QuickLook Cache
print_status "Cleaning QuickLook Cache..."
rm -rf /var/folders/*/*/*/com.apple.QuickLook.thumbnailcache/* 2>/dev/null

echo ""
echo "==================================================="
echo "   CLEANUP COMPLETE"
echo "==================================================="
echo "Current Disk Usage:"
df -h /System/Volumes/Data
