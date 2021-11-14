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
readonly VERSION="0.5.4"
readonly VERSION_NAME="Flow"
readonly LICENSE="MIT"

#################
# Configuration #
#################

HOMEBREW_PACKAGES=()

XCODES=()

ACTIVE_XCODE=

PURGE_XCODES=false

EXPERIMENTAL=false

RUBY_VERSION=

RUBY_NAME="ruby"

RUBY_GEMS=()

INSTALL_OH_MY_ZSH=false

INSTALL_OH_MY_ZSH_P10K=false

SIMULATORS=()

PURGE_SIMULATORS=false

##############
# Formatting #
##############

# Palette

if [[ -z ${NO_COLOR+x} ]]; then 
    WHITE="\033[1;37m"
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    NC='\033[0m'
    BOLD=$(tput bold)
    NORM=$(tput sgr0)
else
    WHITE=''
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
    BOLD=''
    NORM=''
fi


# Left-padded echo.
# Prints a message, left-padded with spaces.
# $1: title color.
# $2: padding level.
# $3: message.
lecho() {
    local left_padding=""
    for (( i=0; i<$2; i++ )); do
        left_padding="$left_padding "
    done
    echo -e "$left_padding$1$3$NC$NORM"
}

# Left-padded entry.
# Prints a message in the format "left: right", left-padded with spaces.
# $1: color for "left".
# $2: padding level for "left".
# $3: "left" message.
# $4: "right" message.
entry() {
    local left_padding=""
    for (( i=0; i<$2; i++ )); do
        left_padding="$left_padding "
    done
    printf "%s$1%s$NC: %s\n" "$left_padding" "$3" "$4"
}

#############
# Functions #
#############

_did_update_homebrew=0

# Installs a package using Homebrew if it is not already installed.
# $1: package name.
install_homebrew_package_if_needed() {
    if ! command -v brew >/dev/null 2>&1; then
        lecho "$RED" "1" "Homebrew not found. Installing it..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
            lecho "$RED" "1" "Failed to install Homebrew. Exiting..."
            exit 1
        }
    else
        if [ $_did_update_homebrew -eq 0 ]; then
            lecho "$GREEN" "1" "Homebrew found. Updating... ⌛️"
            brew update >/dev/null 2>&1 || {
                lecho "$RED" "1" "Homebrew update failed. Exiting..."
                exit 1
            }
            _did_update_homebrew=1
        fi
    fi
    local package_name=${1##*/}
    if ! brew list -1 | grep "$package_name" >/dev/null 2>&1; then
        lecho "$RED" "1" "Package $package_name not found. Installing it..."
        brew install "$1" || {
            lecho "$RED" "1" "Failed to install $package_name. Exiting..."
            exit 1
        }
    else
        lecho "$GREEN" "1" "Package $package_name is already installed."
    fi
}

# Checks if a specific version of Xcode is installed
# $1: Xcode version to check.
is_xcode_installed() {
    xcodes installed | grep -q "$1"
}

# Installs an Xcode if it is not already installed.
# $1: Xcode version to install.
install_xcode_if_needed() {
    if is_xcode_installed "$1"; then
        lecho "$GREEN" 1 "Xcode $1 is already installed."
    else
        lecho "$RED" 1 "Xcode $1 is not installed. Installing it... ⌛️"
        NSUnbufferedIO=YES xcodes install "$1" || {
            lecho "$RED" 1 "Failed to install Xcode $1. Exiting..."
            exit 1
        }
    fi
}

# Purges all Xcodes that are not in the --xcodes list.
purge_xcodes() {
    local installed_xcodes
    installed_xcodes=$(xcodes installed | awk '{print $1}')
    for xcode in $installed_xcodes; do
        # https://stackoverflow.com/a/15394738/2890168
        # shellcheck disable=SC2076
        if ! [[ " ${XCODES[*]} " =~ " $xcode " ]]; then
            lecho "$RED" 1 "Uninstalling Xcode $xcode..."
            NSUnbufferedIO=YES xcodes uninstall "$xcode" || {
                lecho "$RED" 1 "Failed to uninstall Xcode $xcode. Exiting..."
                exit 1
            }
        fi
    done
}

# Sets the active Xcode.
# $1: Xcode version to activate.
select_xcode() {
    xcodes select "$1" || {
        lecho "$RED" 1 "Failed to select Xcode $1. Exiting..."
        exit 1
    }
}

# Prints "true" is this is a virtual machine, "false" otherwise.
is_virtual_machine() {
    # Processor unknown check
    if system_profiler SPHardwareDataType | grep -q "Unknown"; then
        printf "true"
        return
    fi
    # QEMU RAM check
    if system_profiler SPMemoryDataType | grep -q "QEMU"; then
        printf "true"
        return
    fi
    # Vmx network adapter check
    if system_profiler SPEthernetDataType | grep -q "Vmx"; then
        printf "true"
        return
    fi
    printf "false"
}

# Installs a Ruby if it is not already installed.
# $1: Ruby version to install.
# $2: Ruby name (affects local folder + script names).
install_ruby_if_needed() {
    lecho "$GREEN" 1 "Building portable Ruby $1 in folder ./$2... ⏳"
    ruby-install ruby "$1"      \
        -i "$(realpath "./$2")" \
        --no-reinstall          \
        -c                      \
        -j "$(sysctl -n hw.physicalcpu)" > "$2.build.log" 2>&1 || {
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

# Create a Ruby activation script.
# $1: Ruby name.
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

simulator_runtime() {
    xcrun simctl list runtimes | grep "$1" | awk '{print $NF}' || { 
        echo "none" 
    }
}

clean_up_simulator_and_run() {
    local simulator=()
    IFS=',' read -ra simulator <<< "$1"
    local name
    name=$(echo "${simulator[0]}" | xargs)
    local device
    device=$(echo "${simulator[1]}" | xargs)
    local runtime
    runtime=$(echo "${simulator[2]}" | xargs)
    "$2" "$name" "$device" "$runtime"
}

print_simulator() {
    lecho "$WHITE" 3 "name: \"$1\", device: \"$2\", runtime: \"$3\""
}

create_simulator() {
    lecho "$RED" 1 "Creating simulator $1:$2:$3..."
    local runtime
    runtime=$(simulator_runtime "$(echo "$3" | xargs)")
    if [[ $runtime == "none" ]]; then
        lecho "$RED" 1 "Runtime $3 not found. Exiting..."
        exit 1
    fi
    xcrun simctl create "$1" "$2" "$runtime" > /dev/null 2>&1 || {
        lecho "$RED" 1 "Failed to create simulator $1:$2:$3. Exiting..."
        exit 1
    }
}

install_xcode_command_line_tools_if_needed() {
    if ! xcode-select -p >/dev/null 2>&1; then
        lecho "$RED" 0 "Installing Xcode command line tools... ⏳"
        xcode-select --install > /dev/null 2>&1 || {
            lecho "$RED" 0 "Failed to install Xcode command line tools. Exiting..."
            exit 1
        } && {
            lecho "${WHITE}${BOLD}" 0 "Xcode command line tools dialog should be visible now."
            lecho "${WHITE}${BOLD}" 0 "Please follow the instructions and reload this script when the installation is finished."
            exit 0
        }
    fi
}

###########
# Actions #
###########

# Prints out a warning if the user is running an older version of the script
update_action() {
    local remote_version
    remote_version=$(
        curl -LsS "https://raw.githubusercontent.com/Zi0P4tch0/iosdev.sh/master/iosdev.sh" 2>&1 |  
        grep -Eo 'VERSION="([0-9\.]+)"' | 
        cut -d"=" -f 2 | 
        sed s/\"//g || {
            echo "N/A"
        }
    )
    if [ "$remote_version" != "$VERSION" ] && [ "$remote_version" != "N/A" ]; then
        lecho "$YELLOW" 0 "Latest version available on Github: $remote_version."
        lecho "$YELLOW" 0 "Version you are currently using: $VERSION."
        lecho "$YELLOW" 0 "To update to the latest version, please run:"
        lecho "${WHITE}${BOLD}" 0 "curl -L https://raw.githubusercontent.com/Zi0P4tch0/iosdev.sh/master/iosdev.sh > /usr/local/bin/iosdev.sh"
        lecho "${WHITE}${BOLD}" 0 "chmod +x /usr/local/bin/iosdev.sh"
        echo ""
    fi
}

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
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--xcodes accepts a comma separated list of values."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            # Split comma separated values in $1 and store them in XCODES
            IFS=',' read -ra XCODES <<< "$1"
            ;;
        --active-xcode)
            shift          
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--active-xcode requires an argument."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            ACTIVE_XCODE="$1"
            ;;
        --experimental)
            EXPERIMENTAL=true
            ;;
        --ruby-version)
            shift
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--ruby-version requires an argument."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            RUBY_VERSION="$1"
            ;;
        --ruby-name)
            shift
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--ruby-name requires an argument."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            RUBY_NAME="$1"
            ;;
        --ruby-gems)
            shift
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--ruby-gems accepts a comma separated list of values."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            # Split comma separated values in $1 and store them in RUBY_GEMS
            IFS=',' read -ra RUBY_GEMS <<< "$1"
            ;;
        --homebrew-packages)
            shift
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--homebrew-packages accepts a comma separated list of values."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            # Split comma separated values in $1 and store them in RUBY_GEMS
            IFS=',' read -ra HOMEBREW_PACKAGES <<< "$1"
            ;;
        --install-oh-my-zsh)
            INSTALL_OH_MY_ZSH=true
            ;;
        --install-oh-my-zsh-p10k)
            INSTALL_OH_MY_ZSH_P10K=true
            ;;
        --simulators)
            shift
            if [[ -z "${1-}" ]] || [[ "${1-}" == --* ]]; then
                lecho "$RED" 0 "--simulators accepts a pipe ('|') separated list of values."
                lecho "$RED" 0 "Please see --help for more information."
                exit 1
            fi
            # Split comma separated values in $1 and store them in RUBY_GEMS
            IFS='|' read -ra SIMULATORS <<< "$1"
            ;;
         --purge-simulators)
            PURGE_SIMULATORS=true
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
    --homebrew-packages <comma separated list>
        Specify the Homebrew packages to install.
        e.g. iosdev.sh --homebrew-packages swiftlint,sourcery
    --install-oh-my-zsh
        Install Oh My Zsh.
         e.g. iosdev.sh --install-oh-my-zsh
    --install-oh-my-zsh-p10k
        Install Oh My Zsh "powerlevel10k" theme.
        This flag does nothing if "--install-oh-my-zsh" is not specified.
        e.g. iosdev.sh --install-oh-my-zsh --install-oh-my-zsh-p10k
    --simulators <pipe separated list>
        Create simulators.
        Each entry must be in the format: <name>,<device>,<runtime>.
        e.g. iosdev.sh --simulators "Simulator,iPhone 13,iOS 15.0|Simulator2,iPhone 12,iOS 14.4"
     --purge-simulators
        Delete all iOS simulators.
        This flag does nothing if "--simulators" is not specified.
        e.g. iosdev.sh --simulators "Simulator,iPhone 13,iOS 15.0" --purge-simulators
    --help
        Show this message
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
    entry "$GREEN" 1 "Experimental features" "$EXPERIMENTAL"
    lecho "$YELLOW" 1 "Xcodes"
    entry "$GREEN" 2 "Xcodes to install" "${XCODES[*]:-<none>}"
    entry "$GREEN" 2 "Purge flag" "${PURGE_XCODES}"
    entry "$GREEN" 2 "Active Xcode" "${ACTIVE_XCODE:-<none>}"
    lecho "$YELLOW" 1 "Ruby"
    entry "$GREEN" 2 "Ruby version" "${RUBY_VERSION:-<none>}"
    entry "$GREEN" 2 "Ruby name" "$RUBY_NAME"
    entry "$GREEN" 2 "Gems to install" "${RUBY_GEMS[*]:-<none>}"
    lecho "$YELLOW" 1 "Homebrew"
    entry "$GREEN" 2 "Packages to install" "${HOMEBREW_PACKAGES[*]:-<none>}"
    lecho "$YELLOW" 1 "Oh My Zsh"
    entry "$GREEN" 2 "Install" "${INSTALL_OH_MY_ZSH}"
    entry "$GREEN" 2 "Install P10K theme" "${INSTALL_OH_MY_ZSH_P10K}"
    lecho "$YELLOW" 1 "Simulators"
    if [ -z "${SIMULATORS[*]:-}" ]; then
        entry "$GREEN" 2 "Simulators to create" "<none>"
    else
        lecho "$GREEN" 2 "Simulators to create: "
        for simulator in "${SIMULATORS[@]}"; do
            clean_up_simulator_and_run "$simulator" print_simulator
        done
    fi
    entry "$GREEN" 2 "Purge flag" "${PURGE_SIMULATORS}"
    echo ""
}

xcodes_action() {

    lecho "$YELLOW" 0 "Xcodes"

    if ! [[ ${#XCODES[@]} -eq 0 ]]; then
        install_homebrew_package_if_needed "robotsandpencils/made/xcodes"
        install_homebrew_package_if_needed "aria2"
        # Check / install Xcodes
        for xcode_version in "${XCODES[@]}"; do
            install_xcode_if_needed "$xcode_version"
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
        lecho "${WHITE}${BOLD}" 1 "Done - source the script to activate the portable ruby!"
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
    echo ""
}

homebrew_packages_action() {
    lecho "$YELLOW" 0 "Homebrew"
    if [[ ${#HOMEBREW_PACKAGES[@]} -gt 0 ]]; then
        for package in "${HOMEBREW_PACKAGES[@]}"; do
            install_homebrew_package_if_needed "$package"
        done
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
    echo ""
}

install_oh_my_zsh_action() {
    lecho "$YELLOW" 0 "Oh My Zsh"
    if [[ "$INSTALL_OH_MY_ZSH" = true ]]; then
        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            lecho "$RED" 1 "Installing Oh My Zsh... ⌛️"
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh && exit 0)"
            lecho "${WHITE}${BOLD}" 1 "Done - please restart your terminal to see the changes."
        else
            lecho "$GREEN" 1 "Oh My Zsh is already installed."
        fi
        if [[ "$INSTALL_OH_MY_ZSH_P10K" = true ]]; then
            if ! [[ -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]] || ! grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"; then
                lecho "$RED" 1 "Installing P10K theme for Oh My Zsh... ⌛️"
                git clone --depth=1 "https://github.com/romkatv/powerlevel10k.git" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
                lecho "$RED" 1 "Setting P10K theme in .zshrc..."
                sed -i '' 's|\(ZSH_THEME="\).*\("\)|\1powerlevel10k/powerlevel10k\2|g' "$HOME/.zshrc"
                lecho "${WHITE}${BOLD}" 1 "Done - please restart your terminal to see the changes."
            else
                lecho "$GREEN" 1 "P10K theme is already installed."
            fi
        fi
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
    echo ""
}

simulators_action() {
    lecho "$YELLOW" 0 "Simulators"
    if [[ ${#SIMULATORS[@]} -gt 0 ]]; then
        if [[ "$PURGE_SIMULATORS" = true ]]; then
            lecho "$RED" 1 "Purging Simulators... ⌛️"
            xcrun simctl delete all || {
                lecho "$RED" 1 "Failed to purge simulators."
                exit 1
            }
        fi
        lecho "$RED" 1 "Creating simulators... ⌛️"
        for simulator in "${SIMULATORS[@]}"; do
            clean_up_simulator_and_run "$simulator" create_simulator
        done
        lecho "${WHITE}${BOLD}" 1 "Done!"
    else
        lecho "$GREEN" 1 "Nothing to do here."
    fi
    echo ""
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


system_info_action

if [[ "$(uname -m)" == "arm64" ]] && [[ "$EXPERIMENTAL" = false ]]; then
    lecho "$RED" 0 "This script is for Intel macOS only. Apple Silicon will be supported in a future release."
    exit 1
fi

update_action

if [[ -d "/Applications/Xcodes.app" ]]; then
    lecho "$RED" 0 "This script is incompatible with the Xcodes.app (found in /Applications)."
    lecho "$RED" 0 "If you installed it via Homebrew, please run 'brew uninstall homebrew/cask/xcodes' and try again."
    exit 1
fi

install_xcode_command_line_tools_if_needed

configuration_action

prompt_action

xcodes_action

make_portable_ruby_action

homebrew_packages_action

install_oh_my_zsh_action

simulators_action
