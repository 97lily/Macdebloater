#!/bin/bash

# Deep Cleanup Script (Interactive & Comprehensive)
# Created by Antigravity

# --- Configuration ---
ARCHIVE_DIR="$HOME/Cleanup_Archives/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$ARCHIVE_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Utilities ---

# Totals for Progress (Adjust manually if adding more items)
TOTAL_STEPS=30
CURRENT_STEP=0

draw_progress_bar() {
    local w=50
    local p=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    local l=$((p * w / 100))
    local r=$((w - l))
    
    # Move cursor up 1 line to overwrite previous bar if we wanted a static footer, 
    # but for scrolling log, we just print it at the top of the item block.
    # actually, let's keep it simple: [====...] P%
    
    printf "\r${BLUE}Progress: [${GREEN}%-${w}s${BLUE}] %d%%${NC}" "$(printf '%.0s=' $(seq 1 $l))" "$p"
}

increment_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
}

print_header() {
    # Clear line for clean loop output
    echo "" 
    echo -e "${BLUE}:: $1 ::${NC}"
}

print_info() {
    echo -e "${NC}   $1"
}

print_warning() {
    echo -e "${YELLOW}   (!) $1${NC}"
}

print_success() {
    echo -e "${GREEN}   OK.${NC}"
}

# format_size path
get_size() {
    sudo du -sh "$1" 2>/dev/null | cut -f1
}

# compress_and_delete path name
compress_and_delete() {
    local target="$1"
    local name="$2"
    local filename="${name// /_}.tar.gz"
    local dest="$ARCHIVE_DIR/$filename"

    print_info "Compressing $target to $dest..."
    if sudo tar -czf "$dest" -C "$(dirname "$target")" "$(basename "$target")" 2>/dev/null; then
        print_success "Compressed."
        print_info "Deleting original..."
        sudo rm -rf "$target"
        print_success "Deleted $target"
    else
        echo -e "${RED}Failed to compress. Skipping deletion.${NC}"
    fi
}

# process_item "Name" "Path" "DefaultAction(y/n)" "WarningMessage"
process_item() {
    increment_step
    draw_progress_bar
    echo "" # Newline after progress bar

    local name="$1"
    local path="$2"
    local default_action="$3" # y or n
    local warning="$4"

    echo -e "${BLUE}>> $name${NC}"
    
    # Check existence
    if [ ! -e "$path" ] && [ ! -d "$path" ]; then
        # Check if glob pattern exists (rough check)
        if ! ls $path 1> /dev/null 2>&1; then
             # Silent skip or minimal logging to keep UI clean
             # printf "   (Skipped/Empty)\n" 
             return
        fi
    fi

    local size
    size=$(get_size "$path")
    echo "   Size: $size | Path: $path"

    if [ -n "$warning" ]; then
        print_warning "$warning"
    fi

    local prompt_char
    if [ "$default_action" == "n" ]; then
        prompt_char="N"
    else
        prompt_char="Y"
    fi
    
    # Simplified prompt
    local prompt_str="   Delete? [y/n/c/i] (Default: $prompt_char) > "

    while true; do
        read -p "$prompt_str" choice
        choice=${choice:-$default_action}

        case "$choice" in
            y|Y)
                sudo rm -rf $path
                print_success 
                break
                ;;
            n|N)
                echo "   Skipped."
                break
                ;;
            c|C)
                compress_and_delete "$path" "$name"
                break
                ;;
            i|I)
                echo "   Top 5 large items:"
                sudo du -ah "$path" 2>/dev/null | sort -rh | head -n 5 | sed 's/^/      /'
                ;;
            *)
                echo "   Invalid option."
                ;;
        esac
    done
}

# --- Main Script ---

# Request Sudo
sudo -v
# Keep-alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

print_header "STARTING DEEP CLEANUP"
echo "Archives will be saved to: $ARCHIVE_DIR"

# 1. Standard Caches
process_item "User Caches" "$HOME/Library/Caches/*" "y" "Safe to delete. Apps will rebuild them."
process_item "System Caches" "/Library/Caches/*" "y" "Safe to delete."

# 2. Logs
process_item "User Logs" "$HOME/Library/Logs/*" "y" "Old logs."
process_item "System Logs" "/var/log/*" "y" "System logs."

# 3. Xcode
if [ -d "$HOME/Library/Developer/Xcode" ]; then
    process_item "Xcode DerivedData" "$HOME/Library/Developer/Xcode/DerivedData" "y" "Speeds up build if corrupt, but will trigger rebuilds."
    process_item "Xcode iOS DeviceSupport" "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "n" "HUGE. Contains symbols for old iOS versions. Delete if you don't debug old devices."
    process_item "Xcode Archives" "$HOME/Library/Developer/Xcode/Archives" "n" "Your built app archives. Only delete if you have them backed up."
fi

# 4. Shared Folder
process_item "Shared User Data" "/Users/Shared/*" "n" "Files shared between users. Sometimes contains game data or installed app info."

# 5. Mobile Development
process_item "Android Studio / Gradle Caches" "$HOME/.gradle/caches" "n" "Will need to re-download dependencies."
process_item "CocoaPods Cache" "$HOME/Library/Caches/CocoaPods" "y" "Pod cache."

# 6. Package Managers
increment_step
draw_progress_bar
echo ""
echo -e "${BLUE}>> Homebrew Cleanup${NC}"
if command -v brew &> /dev/null; then
    read -p "   Run 'brew cleanup'? [y/N] > " brew_choice
    if [[ "$brew_choice" =~ ^[Yy]$ ]]; then
        brew cleanup
    else
        echo "   Skipped."
    fi
fi

increment_step
draw_progress_bar
echo ""
echo -e "${BLUE}>> Docker Prune${NC}"
if command -v docker &> /dev/null && docker info > /dev/null 2>&1; then
    read -p "   Run 'docker system prune'? [y/N] > " docker_choice
    if [[ "$docker_choice" =~ ^[Yy]$ ]]; then
        docker system prune
    else
        echo "   Skipped."
    fi
fi

# 7. System Maniac (Special Handling)
process_recursive() {
    increment_step
    draw_progress_bar
    echo ""

    local name="$1"
    local find_cmd="$2"
    local warning="$3"
    
    echo -e "${BLUE}>> $name${NC}"
    if [ -n "$warning" ]; then
        print_warning "$warning"
    fi
    
    echo "   (Calculating size...)"
    # Silence permission errors
    local count
    count=$(eval "$find_cmd | wc -l 2>/dev/null")
    echo "   Found $count files."
    
    if [ "$count" -eq 0 ]; then
        # echo "   (None found, skipping)"
        return
    fi
    
    read -p "   Delete all found files? [y/N] > " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        eval "$find_cmd -delete 2>/dev/null"
        print_success 
    else
        echo "   Skipped."
    fi
}

process_recursive "DS_Store Files" "find $HOME -name '.DS_Store' -type f" "Deletes folder view settings (icon positions, sort order)."
# Exclude heavily protected directories to avoid 'Operation not permitted' spam
process_recursive "Broken Symlinks" "find -L $HOME -path '$HOME/Library/Containers' -prune -o -path '$HOME/Library/Group Containers' -prune -o -path '$HOME/Library/Mobile Documents' -prune -o -type l -print" "Deletes links pointing to non-existent files."

# Specialized Paths
process_item "Mail Downloads" "$HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/*" "n" "Attachments you opened in Mail."
process_item "Message Attachments" "$HOME/Library/Messages/Attachments/*" "n" "WARNING: Deletes all photos/files from iMessage history."

# 8. Browsers (Caches Only)
process_item "Google Chrome Cache" "$HOME/Library/Caches/Google/Chrome/*" "y" "Browser cache."
process_item "Firefox Cache" "$HOME/Library/Caches/Firefox/Profiles/*/cache2/*" "y" "Browser cache."
process_item "Safari Cache" "$HOME/Library/Caches/com.apple.Safari/*" "y" "Browser cache."

# 9. Communication Apps
process_item "Slack Cache" "$HOME/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Cache/*" "y" "Slack cache."
process_item "Discord Cache" "$HOME/Library/Application Support/discord/Cache/*" "y" "Discord cache."
process_item "Zoom Cache" "$HOME/Library/Caches/us.zoom.xos/*" "y" "Zoom cache."

# 10. Creative / Adobe
process_item "Adobe Common Cache" "$HOME/Library/Application Support/Adobe/Common/Media Cache Files/*" "y" "Media cache files (often huge)."

# 11. Development Tools (Extended)
process_item "NPM Cache" "$HOME/.npm/*" "n" "Node package cache."
process_item "Yarn Cache" "$HOME/Library/Caches/Yarn/*" "y" "Yarn cache."
process_item "Composer Cache" "$HOME/.composer/cache/*" "n" "PHP Composer cache."

# 12. System Maintenance
increment_step
draw_progress_bar
echo ""
echo -e "${BLUE}>> System Maintenance${NC}"
read -p "   Run DNS Flush, RAM Purge, and Font DB Reset? [y/N] > " sys_choice
if [[ "$sys_choice" =~ ^[Yy]$ ]]; then
    print_info "Flushing DNS..."
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    print_info "Purging RAM..."
    sudo purge
    print_info "Resetting Font Databases..."
    sudo atsutil server -shutdown
    sudo atsutil server -ping
    print_success "Maintenance complete."
else
    echo "   Skipped."
fi

# 13. Trash
process_item "Trash" "$HOME/.Trash/*" "y" ""

# Cleanup empty archive dir if unused
if [ -z "$(ls -A $ARCHIVE_DIR)" ]; then
   rmdir "$ARCHIVE_DIR"
   echo "No archives created, removed empty archive folder."
else
    echo "Archives saved in $ARCHIVE_DIR"
fi

print_header "CLEANUP COMPLETE"
df -h /System/Volumes/Data
