#!/usr/bin/env bash

#####################################################################################
# Copyright (c) 2021 Matteo Pacini                                                  #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#####################################################################################

set -euo pipefail

readonly AUTHOR="Matteo Pacini <m+github@matteopacini.me>"
readonly VERSION="0.2.2"
readonly VERSION_NAME="Semi"
readonly LICENSE="MIT"

#################
# Configuration #
#################

XCODES=()

ACTIVE_XCODE=

PURGE_XCODES=false

COLOR_OUTPUT=true

EXPERIMENTAL=false

RUBY_VERSION=

RUBY_NAME="ruby"

RUBY_GEMS=()

##############
# Formatting #
##############

# Palette
BOLD_WHITE="\033[1m"
WHITE="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
NC='\033[0m'

# $1 sets the title color.
# $2 adds "n" padding characters to the left of the entry.
# $3 is the title.
lecho() {
    local LEFT_PADDING=""
    for (( i=0; i<$2; i++ )); do
        LEFT_PADDING="$LEFT_PADDING "
    done
    echo -e "$LEFT_PADDING$1$3$NC"
}

# $1 sets the color of left-hand side.
# $2 adds "n" padding characters to the left of the entry.
# $3 is the left-hand side text.
# $4 is the right-hand side text.
entry() {
    local LEFT_PADDING=""
    for (( i=0; i<$2; i++ )); do
        LEFT_PADDING="$LEFT_PADDING "
    done
    printf "%s$1%s$NC: %s\n" "$LEFT_PADDING" "$3" "$4"
}

#############
# Functions #
#############

_DID_UPDATE_HOMEBREW=0

install_homebrew_package_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        lecho "$RED" "1" "Homebrew not found. Installing it..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" || {
            lecho "$RED" "1" "Failed to install Homebrew. Exiting..."
            exit 1
        }
    else
        if [ $_DID_UPDATE_HOMEBREW -eq 0 ]; then
            lecho "$GREEN" "1" "Homebrew found. Updating... ⌛️"
            brew update >/dev/null 2>&1 || {
                lecho "$RED" "1" "Homebrew update failed. Exiting..."
                exit 1
            }
            _DID_UPDATE_HOMEBREW=1
        fi
    fi
    local PACKAGE_NAME=${1##*/}
    if ! brew list -1 | grep "$PACKAGE_NAME" >/dev/null 2>&1; then
        lecho "$RED" "1" "Package $PACKAGE_NAME not found. Installing it..."
        brew install "$1" || {
            lecho "$RED" "1" "Failed to install $PACKAGE_NAME. Exiting..."
            exit 1
        }
    else
        lecho "$GREEN" "1" "Package $PACKAGE_NAME already installed."
    fi
}

is_xcode_installed() {
    xcodes installed | grep -q "$1"
}

install_xcode_if_needed() {
    if is_xcode_installed "$1"; then
        lecho "$GREEN" 1 "Xcode $1 is already installed."
    else
        lecho "$RED" 1 "Xcode $1 is not installed. Installing it..."
        NSUnbufferedIO=YES xcodes install "$1" || {
            lecho "$RED" 1 "Failed to install Xcode $1. Exiting..."
            exit 1
        }
    fi
}

purge_xcodes() {
    INSTALLED_XCODES=$(xcodes installed | awk '{print $1}')
    for INSTALLED_XCODE in $INSTALLED_XCODES; do
        # https://stackoverflow.com/a/15394738/2890168
        # shellcheck disable=SC2076
        if ! [[ " ${XCODES[*]} " =~ " $INSTALLED_XCODE " ]]; then
            lecho "$RED" 1 "Uninstalling Xcode $INSTALLED_XCODE..."
            NSUnbufferedIO=YES xcodes uninstall "$INSTALLED_XCODE" || {
                lecho "$RED" 1 "Failed to uninstall Xcode $INSTALLED_XCODE. Exiting..."
                exit 1
            }
        fi
    done
}

select_xcode() {
    xcodes select "$1" || {
        lecho "$RED" 1 "Failed to select Xcode $1. Exiting..."
        exit 1
    }
}

is_virtual_machine() {
    # Processor unknown
    if system_profiler SPHardwareDataType | grep -q "Unknown"; then
        printf "true"
        return
    fi
    # QEMU RAM
    if system_profiler SPMemoryDataType | grep -q "QEMU"; then
        printf "true"
        return
    fi
    # Vmx network adapter
    if system_profiler SPEthernetDataType | grep -q "Vmx"; then
        printf "true"
        return
    fi
    printf "false"
}

show_update_warning_if_needed() {
    local SCRIPT_URL="https://raw.githubusercontent.com/Zi0P4tch0/iosdev.sh/master/iosdev.sh"
    local TMP_FILE
    TMP_FILE=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f $TMP_FILE" EXIT
    curl -fsSL "$SCRIPT_URL" -o "$TMP_FILE" 2> /dev/null && {
        local TMP_VERSION
        TMP_VERSION=$(grep -Eo '^VERSION="[^"]+"' "$TMP_FILE" | cut -d"=" -f2 | sed s/\"//g)   
        if [[ "$TMP_VERSION" != "$VERSION" ]]; then
            lecho "$YELLOW" 0 "Latest version available on Github: $TMP_VERSION."
            lecho "$YELLOW" 0 "Version you are currently using: $VERSION."
            lecho "$YELLOW" 0 "To update to the latest version, please run:"
            lecho "$BOLD_WHITE" 0 "curl -L https://raw.githubusercontent.com/Zi0P4tch0/iosdev.sh/master/iosdev.sh > /usr/local/bin/iosdev.sh"
            lecho "$BOLD_WHITE" 0 "chmod +x /usr/local/bin/iosdev.sh"
            echo ""
        fi
    }
}

# $1 is the Ruby version to install.
# $2 is the Ruby name.
install_ruby_if_needed() {
    lecho "$GREEN" 1 "Building portable Ruby $1 in folder ./$2... ⏳"
    ruby-install ruby "$1" -i "$(realpath "./$2")" --no-reinstall -c -j "$(sysctl -n hw.physicalcpu)" > "$2.build.log" 2>&1 || {
        lecho "$RED" 1 "Failed to build Ruby $1. See $2.build.log for more information."
        exit 1
    }
    rm -rf "$2.build.log" >/dev/null 2>&1
    create_ruby_activation_script "$2"
    if ! [[ ${#RUBY_GEMS[@]} -eq 0 ]]; then
        # shellcheck source=/dev/null
        source "./$2_activate.sh"
        lecho "$GREEN" 1 "Installing Ruby gems: ${RUBY_GEMS[*]}... ⏳"
        for RUBY_GEM in "${RUBY_GEMS[@]}"; do
            gem install "$RUBY_GEM" > "$2.gems.log" 2>&1 || {
                lecho "$RED" 1 "Failed to install gem $RUBY_GEM. See $2.gems.log for more information."
                exit 1
            }
        done
        rm -rf "$2.gems.log" >/dev/null 2>&1
    fi
}

create_ruby_activation_script() {
    lecho "$GREEN" 1 "Building done, creating activation script: ./$1_activate.sh."
cat <<EOF > "$1_activate.sh"
# shellcheck disable=SC2148
fn_exists() {
    if [ -n "\${ZSH_VERSION-}" ]; then
        type "\$1"| grep -q "function"
    else
        type -t "\$1"| grep -q "function"
    fi
}
if fn_exists "$1_deactivate"; then
    echo "Environment already activated."
    echo "Please run '$1_deactivate' to deactivate it."
else
    PREVIOUS_GEM_HOME="\${GEM_HOME-}"
    PREVIOUS_GEM_PATH="\${GEM_PATH-}"
    PREVIOUS_PATH="\$PATH"
    GEM_HOME="\$(realpath "./$1")/gems"
    export GEM_HOME
    GEM_PATH="\$(realpath "./$1")/gems"
    export GEM_PATH
    PATH="\$(realpath "./$1")/bin:\$(realpath "./$1")/gems/bin:\$PATH"
    export PATH
    function $1_deactivate() {
        export GEM_HOME="\$PREVIOUS_GEM_HOME"
        export GEM_PATH="\$PREVIOUS_GEM_PATH"
        export PATH="\$PREVIOUS_PATH"
        unset PREVIOUS_GEM_HOME
        unset PREVIOUS_GEM_PATH
        unset PREVIOUS_PATH
        unset -f $1_deactivate
    }
fi
EOF
}

###########
# Actions #
###########

parse_command_line_arguments_action() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --help)
            usage_action
            exit 0
            ;;
        --purge-xcodes)
            PURGE_XCODES=true
            ;;
        --xcodes)
            shift
            # Split comma separated values in $1 and store them in XCODES
            IFS=',' read -ra XCODES <<< "$1"
            ;;
        --active-xcode)
            shift
            ACTIVE_XCODE="$1"
            ;;
        --no-color)
            COLOR_OUTPUT=false
            ;;
        --experimental)
            EXPERIMENTAL=true
            ;;
        --ruby-version)
            shift
            RUBY_VERSION="$1"
            ;;
        --ruby-name)
            shift
            RUBY_NAME="$1"
            ;;
        --ruby-gems)
            shift
            # Split comma separated values in $1 and store them in RUBY_GEMS
            IFS=',' read -ra RUBY_GEMS <<< "$1"
            ;;
        *)
            usage_action
            exit 1
            ;;
        esac
        shift
    done
    
}

usage_action() {
cat <<USAGE
Usage:
    iosdev.sh [options]

Arguments:
    --xcodes <comma separated list>
        List of Xcode versions to install
        e.g. iosdev.sh --xcodes 13.1,13.2 
    --purge-xcodes
        Purge installed Xcode versions that are not in the "--xcodes" list.
        This flag does nothing if "--xcodes" is not specified.
        e.g. assuming Xcode 12.5.1 is installed:
        ./iosdev.sh --xcodes 13.1,13.2 --purge-xcodes
        This will install Xcode 13.1 and 13.2 and purge Xcode 12.5.1.
    --active-xcode <version>
        Select the active Xcode version.
        This flag does nothing if "--xcodes" is not specified.
        e.g. iosdev.sh --xcodes 13.1,13.2 --active-xcode 13.1
    --no-color
        Disable color output.
    --experimental
        Enable experimental features. 
        This option is not recommended, as it may break the script or have an unexpected behavior.
        Current experimental features are:
            - M1 macs support
    --ruby-version <version>
        Specify the portable Ruby version to install.
        e.g. iosdev.sh --ruby-version 2.7.2
    --ruby-name <name>
        Specify the portable Ruby's folder name. Defaults to "ruby".
        This flag does nothing if "--ruby-version" is not specified.
        e.g. iosdev.sh --ruby-version 2.7.2 --ruby-name prettyruby
    --ruby-gems <comma separated list>
        Specify the Ruby gems to install into the portable ruby.
        This flag does nothing if "--ruby-version" is not specified.
        e.g. iosdev.sh --ruby-version 2.7.2 --ruby-gems fastlane,cocoapods:1.11.2
    --help
        Show this help
USAGE
}

system_info_action() {
    lecho "$YELLOW" 0 "System Info"
    entry "$GREEN" 1 "macOS Version" "$(sw_vers -productVersion) build $(sw_vers -buildVersion)"
    entry "$GREEN" 1 "Architecture" "$(uname -m)"
    entry "$GREEN" 1 "Model" "$(system_profiler SPHardwareDataType | grep "Model Identifier" | awk '{print $3}')"
    entry "$GREEN" 1 "Virtual machine" "$(is_virtual_machine)"
    entry "$GREEN" 1 "CPU" "$(sysctl -n machdep.cpu.brand_string)"
    entry "$GREEN" 1 "Cores" "$(sysctl -n hw.physicalcpu)"
    entry "$GREEN" 1 "RAM (GB)" "$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024}')"
    entry "$GREEN" 1 "User" "$(whoami)"
    entry "$GREEN" 1 "Shell" "$($SHELL --version)"
    entry "$GREEN" 1 "Free space on disk (GB)" "$(df -h / | tail -1 | awk '{print $4}')"
    echo ""
}

configuration_action() {
    lecho "$YELLOW" 0 "Configuration"
    if [ "$EXPERIMENTAL" = true ]; then
        entry "$GREEN" 1 "Experimental features" "true"
    else
        entry "$GREEN" 1 "Experimental features" "false"
    fi
    lecho "$YELLOW" 1 "Xcodes"
    if [[ ${#XCODES[@]} -eq 0 ]]; then
        entry "$GREEN" 2 "Xcodes to install" "<none>"
    else
        entry "$GREEN" 2 "Xcodes to install" "${XCODES[*]}"
    fi
    entry "$GREEN" 2 "Purge Xcodes flag" "${PURGE_XCODES}"
    if [[ $ACTIVE_XCODE != "" ]]; then
        entry "$GREEN" 2 "Active Xcode" "${ACTIVE_XCODE}"
    else
        entry "$GREEN" 2 "Active Xcode" "<none>"
    fi
    lecho "$YELLOW" 1 "Ruby"
    if [ -z "$RUBY_VERSION" ]; then
        entry "$GREEN" 2 "Ruby version" "<none>"
    else
        entry "$GREEN" 2 "Ruby version" "$RUBY_VERSION"
    fi
    entry "$GREEN" 2 "Ruby name" "$RUBY_NAME"
    if [[ ${#RUBY_GEMS[@]} -eq 0 ]]; then
        entry "$GREEN" 2 "Gems to install" "<none>"
    else
        entry "$GREEN" 2 "Gems to install" "${RUBY_GEMS[*]}"
    fi
    echo ""
}

xcodes_action() {

    lecho "$YELLOW" 0 "Xcodes"

    if ! [[ ${#XCODES[@]} -eq 0 ]]; then
        install_homebrew_package_if_needed "robotsandpencils/made/xcodes"
        install_homebrew_package_if_needed "aria2"
        # Check / install Xcodes
        for XCODE_VERSION in "${XCODES[@]}"; do
            install_xcode_if_needed "$XCODE_VERSION"
        done
        if [[ "$PURGE_XCODES" = true ]]; then
            lecho "$YELLOW" 1 "Purging Xcodes..."
            purge_xcodes
        fi
        if [[ "$ACTIVE_XCODE" != "" ]]; then
            lecho "$YELLOW" 1 "Setting active Xcode to $ACTIVE_XCODE..."
            select_xcode "$ACTIVE_XCODE"
        fi
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
    echo ""
}

prompt_action() {
    local RESPONSE
    read -r -p "$(echo -e "${RED}Do you want to continue? [y/n] $NC")"  RESPONSE
    if [[ "$RESPONSE" != "y" ]]; then
        exit 0
    else
        echo ""
    fi
}

make_portable_ruby_action() {
    lecho "$YELLOW" 0 "Ruby"
    if [[ -n "$RUBY_VERSION" ]]; then
        install_homebrew_package_if_needed "ruby-install"
        install_homebrew_package_if_needed "coreutils"
        install_ruby_if_needed "$RUBY_VERSION" "$RUBY_NAME"
        lecho "$BOLD_WHITE" 1 "Done - source the script to activate the portable ruby!"
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
}

clear_palette_action() {
    if [[ "$COLOR_OUTPUT" = false ]]; then
        BOLD_WHITE=""
        WHITE=""
        RED=""
        GREEN=""
        YELLOW=""   
        NC="" 
    fi
}

##############
# Entrypoint #
##############

# Logo
cat <<EOF
██╗ ██████╗ ███████╗██████╗ ███████╗██╗   ██╗  ███████╗██╗  ██╗
██║██╔═══██╗██╔════╝██╔══██╗██╔════╝██║   ██║  ██╔════╝██║  ██║
██║██║   ██║███████╗██║  ██║█████╗  ██║   ██║  ███████╗███████║
██║██║   ██║╚════██║██║  ██║██╔══╝  ╚██╗ ██╔╝  ╚════██║██╔══██║
██║╚██████╔╝███████║██████╔╝███████╗ ╚████╔╝██╗███████║██║  ██║
╚═╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝  ╚═══╝ ╚═╝╚══════╝╚═╝  ╚═╝

The iOS Developer Toolbox v$VERSION - "$VERSION_NAME"
Author: $AUTHOR
License: $LICENSE

EOF

if [[ "$(uname -s)" != "Darwin" ]]; then
    lecho "$RED" 0 "This script is for macOS only."
    exit 1
fi

parse_command_line_arguments_action "$@"

clear_palette_action

system_info_action

if [[ "$(uname -m)" == "arm64" ]] && [[ "$EXPERIMENTAL" = false ]]; then
    lecho "$RED" 0 "This script is for Intel macOS only. Apple Silicon will be supported in a future release."
    exit 1
fi

show_update_warning_if_needed

if [[ -d "/Applications/Xcodes.app" ]]; then
    lecho "$RED" 0 "This script is incompatible with the Xcodes.app (found in /Applications)."
    lecho "$RED" 0 "If you installed it via Homebrew, please run 'brew uninstall homebrew/cask/xcodes' and try again."
    exit 1
fi

configuration_action

prompt_action

xcodes_action

make_portable_ruby_action
