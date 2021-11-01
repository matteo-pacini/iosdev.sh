#!/bin/bash

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

AUTHOR="Matteo Pacini <m+github@matteopacini.me>"
VERSION="0.1.0"
VERSION_NAME="A New Saga Begins"
LICENSE="MIT"

#################
# Configuration #
#################

XCODES=()

PURGE_XCODES=false

COLOR_OUTPUT=true

EXPERIMENTAL=false

RUBY_VERSION=

RUBY_NAME="ruby"

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

install_homebrew_package_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        lecho "$RED" "1" "Homebrew not found. Installing it..."
        /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    else
        brew update >/dev/null 2>&1
    fi
    local PACKAGE_NAME=${1##*/}
    if ! brew list -1 | grep "$PACKAGE_NAME" >/dev/null 2>&1; then
        lecho "$RED" "1" "Package $PACKAGE_NAME not found. Installing it..."
        brew install "$1"
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
        NSUnbufferedIO=YES xcodes install "$1"
    fi
}

purge_xcodes() {
    INSTALLED_XCODES=$(xcodes installed | awk '{print $1}')
    for INSTALLED_XCODE in $INSTALLED_XCODES; do
        if ! [[ " ${XCODES[*]} " =~ " $INSTALLED_XCODE " ]]; then
            lecho "$RED" 1 "Uninstalling Xcode $INSTALLED_XCODE..."
            NSUnbufferedIO=YES xcodes uninstall "$INSTALLED_XCODE"
        fi
    done
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

###########
# Actions #
###########

parse_command_line_arguments_action() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -h|--help)
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
    -h, --help
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
    entry "$GREEN" 1 "Hostname" "$(hostname)"
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
    lecho "$YELLOW" 1 "Ruby"
    if [ -z "$RUBY_VERSION" ]; then
        entry "$GREEN" 2 "Ruby version" "<none>"
    else
        entry "$GREEN" 2 "Ruby version" "$RUBY_VERSION"
    fi
    entry "$GREEN" 2 "Ruby name" "$RUBY_NAME"
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
        lecho "$GREEN" 1 "Building portable Ruby $RUBY_VERSION in folder ./$RUBY_NAME... ⏳"
        ruby-install ruby "$RUBY_VERSION" -i "$(realpath ./$RUBY_NAME)" --no-reinstall -c -j "$(sysctl -n hw.physicalcpu)" > "$RUBY_NAME.build.log" 2>&1 || {
            lecho "$RED" 1 "Failed to build Ruby $RUBY_VERSION. See $RUBY_NAME.build.log for more information."
            exit 1
        }
        lecho "$GREEN" 1 "Building done, creating activation script: ./${RUBY_NAME}_activate.sh."
cat <<EOF > ${RUBY_NAME}_activate.sh
function fn_exists() {
    if [ -n "\$ZSH_VERSION" ]; then
        type "\$1"| grep -q "function"
    else
        type -t "\$1"| grep -q "function"
    fi
}
if fn_exists "deactivate"; then
    echo "Environment already activated."
    echo "Please run 'deactivate' to deactivate it."
else
    PREVIOUS_GEM_HOME="\$GEM_HOME"
    PREVIOUS_GEM_PATH="\$GEM_PATH"
    PREVIOUS_PATH="\$PATH"
    export GEM_HOME="$(realpath "./$RUBY_NAME")/gems"
    export GEM_PATH="$(realpath "./$RUBY_NAME")/gems"
    export PATH="$(realpath "./$RUBY_NAME")/bin:$(realpath "./$RUBY_NAME")/gems/bin:$PATH"
    function deactivate() {
        export GEM_HOME="\$PREVIOUS_GEM_HOME"
        export GEM_PATH="\$PREVIOUS_GEM_PATH"
        export PATH="\$PREVIOUS_PATH"
        unset PREVIOUS_GEM_HOME
        unset PREVIOUS_GEM_PATH
        unset PREVIOUS_PATH
        unset -f deactivate
    }
fi
EOF
        lecho "$BOLD_WHITE" 1 "Done - source the script to activate the portable ruby!"
    else
        lecho "$GREEN" 1 "Nothing to do here."
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

if [[ "$COLOR_OUTPUT" = false ]]; then
    BOLD_WHITE=""
    WHITE=""
    RED=""
    GREEN=""
    YELLOW=""   
    NC="" 
fi

system_info_action

if [[ "$(uname -m)" == "arm64" ]] && [[ "$EXPERIMENTAL" = false ]]; then
    lecho "$RED" 0 "This script is for Intel macOS only. Apple Silicon will be supported in a future release."
    exit 1
fi

configuration_action

prompt_action

xcodes_action

make_portable_ruby_action