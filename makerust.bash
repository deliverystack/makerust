#!/usr/bin/bash

# Script Summary:
# This script automates building, testing, and deploying Rust projects.
# It supports building binaries for both Linux and Windows, as well as generating documentation.
# Features include:
#   - User prompts with a default "yes" behavior.
#   - Running commands multiple times for timing output when the `-t` flag is provided.
#   - Support for debug and release build modes.
#   - Force mode to skip all prompts.
#   - Verbose and debug modes for increased output clarity.
#   - Automatic detection of binary names from Cargo.toml.
#   - Output colorization for informational, warning, and error messages.

# Default values
project_dir="$(pwd)" # The Rust project directory (default: current directory)
winbld=""            # Output directory for Windows builds
linbld=""            # Output directory for Linux builds
doc_dir=""           # Output directory for documentation
build_mode="release" # Build mode, either "release" or "debug" (default: release)
verbose=0            # Verbose mode toggle
debug=0              # Debug mode toggle
use_time=0           # Time mode toggle
rust_backtrace="full" # Default Rust backtrace level
force=0              # Force mode toggle
script_name=$(basename "$0") # The script name for use in messages

# Colors using tput for better output readability
green=$(tput setaf 2)
yellow=$(tput setaf 3)
red=$(tput setaf 1)
cyan=$(tput setaf 6)
orange=$(tput setaf 3)
reset=$(tput sgr0)

# Informational message
info() {
    [[ "$verbose" -eq 1 || "$debug" -eq 1 ]] && printf "${cyan}${script_name}${reset}: %s\n" "$1"
}

progress() {
    printf "${orange}${script_name}${reset}: %s\n" "$1"
}

# Warning message
warn() {
    printf "${yellow}${script_name}${reset}: %s\n" "$1"
}

# Error message
error() {
    printf "${red}${script_name}${reset}: %s\n" "$1" >&2
}

# Debug message
debug() {
    [ "$debug" -eq 1 ] && printf "${blue}${script_name}${reset}: %s\n" "$1"
}

# Display usage information
usage() {
    echo "Usage: ${script_name} [options]"
    echo "Options:"
    echo "  -v          Enable verbose mode."
    echo "  -d          Enable debug mode (increased verbosity)."
    echo "  -t          Use time to measure command execution."
    echo "  -b <value>  Set RUST_BACKTRACE (default: full). Supported values: full, short, 0, 1."
    echo "  -p <path>   Specify project directory (default: current directory)."
    echo "  -w <path>   Specify output directory for Windows executable."
    echo "  -l <path>   Specify output directory for Linux executable."
    echo "  -o <path>   Specify output directory for documentation."
    echo "  -m <mode>   Specify build mode (debug or release, default: release)."
    echo "  -f          Force mode: skip prompts and proceed unless an error occurs."
    echo "  -h          Show this help message."
    exit 0
}

# Function to prompt for deleting the build directory
prompt_delete_build_dir() {
    local build_dir="$1"
    if [ -d "$build_dir" ]; then
        if [ "$force" -eq 1 ]; then
            run "rm -rf \"$build_dir\""
        else
            echo -n "Do you want to delete the build directory $build_dir? [Y/n] "
            read -r delete_dir
            if [[ -z "$delete_dir" || "$delete_dir" =~ ^[Yy]$ ]]; then
                run "rm -rf \"$build_dir\""
            else
                debug "Skipping deletion of $build_dir"
            fi
        fi
    fi
}

# Function to get the binary name from Cargo.toml
get_binary_name() {
    local cargo_toml="$project_dir/Cargo.toml"
    if [ -f "$cargo_toml" ]; then
        grep -m1 '^name =' "$cargo_toml" | sed -E 's/^name = "(.*)"/\1/'
    else
        error "Cargo.toml not found in $project_dir"
        exit 1
    fi
}

# Function to run commands
run() {
    local cmd="$1"

    # Print and execute command
    if [ "$force" -eq 1 ]; then
        info "Force mode enabled: executing without prompt: ${cyan}${cmd}${reset}"
    else
        echo -e "${prefix} About to execute: ${green}${cmd}${reset}"
        echo -n "Do you want to proceed? [Y/n/a] "
        read -r proceed
        if [[ "$proceed" =~ ^[Aa]$ ]]; then
            info "Aborting script as per user request."
            exit 1
        elif [[ -z "$proceed" || "$proceed" =~ ^[Yy]$ ]]; then
            info "Proceeding with command: $cmd"
        else
            info "Skipping command: $cmd"
            return
        fi
    fi

    if [ "$debug" -eq 1 ] || [ "$verbose" -eq 1 ]; then
        eval "$cmd"
        info "Running again to capture output: ${cyan}${cmd}${reset}"
    fi

    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    # Check for errors or warnings in the command output
    grep_output=$(echo "$output" | grep -Eiq '(^|\s)(error|warning)(\s|$)' && ! echo "$output" | grep -Eq '(^|\s)--')

    # Handle errors
    if [ $exit_code -ne 0 ] || [ "$grep_output" ]; then
        error "Command failed: $cmd (exit code: $exit_code)"

        if [ "$force" -eq 1 ]; then
            info "Force mode enabled: exiting script due to command error."
            exit 1
        fi            

        if [ "$force" -ne 1 ]; then
            echo -n "Do you want to continue to the next command? [Y/n] "
            read -r continue_next
            if [[ -z "$continue_next" || "$continue_next" =~ ^[Yy]$ ]]; then
                warn "Continuing to the next command despite error."
            else
                exit 1
            fi
        else
            warn "Force mode enabled: continuing despite error."
        fi
    fi

    # Run with `time` if `-t` is specified
    if [ "$use_time" -eq 1 ]; then
        info "Running command with timing: $cmd"
        eval "time $cmd"
    fi
}

# Parse command-line arguments
while getopts ":vdtb:p:w:l:o:m:fh" opt; do
    case $opt in
        v) verbose=1 ;;             # Enable verbose mode
        d) debug=1 ;;               # Enable debug mode
        t) use_time=1 ;;            # Enable time mode
        b) rust_backtrace=$OPTARG ;; # Set Rust backtrace level
        p) project_dir=$OPTARG ;;   # Set project directory
        w) winbld=$OPTARG ;;        # Set Windows build output directory
        l) linbld=$OPTARG ;;        # Set Linux build output directory
        o) doc_dir=$OPTARG ;;       # Set documentation output directory
        m) build_mode=$OPTARG ;;    # Set build mode
        f) force=1 ;;               # Enable force mode
        h) usage ;;                 # Show usage information
        *) usage ;;                 # Show usage on invalid arguments
    esac
done

# Validate build mode
if [[ "$build_mode" != "release" && "$build_mode" != "debug" ]]; then
    error "Invalid build mode: $build_mode. Must be 'release' or 'debug'."
    exit 1
fi

export RUST_BACKTRACE=$rust_backtrace
debug "RUST_BACKTRACE set to ${green}$RUST_BACKTRACE${reset}"
debug "Project directory set to: ${green}$project_dir${reset}"
debug "Windows build output directory set to: ${green}$winbld${reset}"
debug "Linux build output directory set to: ${green}$linbld${reset}"
debug "Documentation output directory set to: ${green}$doc_dir${reset}"
debug "Build mode set to: ${green}$build_mode${reset}"
debug "Verbose mode: ${green}$verbose${reset}"
debug "Debug mode: ${green}$debug${reset}"
debug "Time mode: ${green}$use_time${reset}"
debug "Force mode: ${green}$force${reset}"

binary_name=$(get_binary_name)
debug "Detected binary name: $binary_name"

# Build and deploy binaries
progress "Update Rust toolchains, components, and rustup."
run "rustup update"
progress "Update dependencies in Cargo.lock to the latest versions."
run "cargo update -v"
progress "Remove target directory files to clean build artifacts and dependencies."
run "cargo clean"

# Linux build
if [ -n "$linbld" ]; then
    progress "Build Linux binary."
    run "cargo build --target-dir \"$linbld\" --$build_mode"
    linux_bin="$linbld/$build_mode/$binary_name"
    if [ -f "$linux_bin" ]; then
        progress "Install Linux binary: ${cyan}${linux_bin}${reset}"
        if [ "$force" -eq 1 ]; then
            run "cp \"$linux_bin\" \"$linbld/\""
        else
            echo -n "Binary already exists. Do you want to overwrite it? [Y/n/a] "
            read -r overwrite
            if [[ "$overwrite" =~ ^[Aa]$ ]]; then
                info "Aborting script as per user request."
                exit 1
            elif [[ -z "$overwrite" || "$overwrite" =~ ^[Yy]$ ]]; then
                run "cp $linux_bin $linbld"
            else
                debug "Skipping overwrite of $linux_bin"
            fi
        fi
    else
        warn "Linux binary not found: $linux_bin"
    fi

    progress "Delete Linux build directory used by cargo: ${cyan}${linbld}/${build_mode}${reset}."
    prompt_delete_build_dir "$linbld/$build_mode"
fi

if [ -n "$winbld" ]; then
    progress "Build Windows binary."
    winbld=$(wslpath -ma "$winbld")
    run "cargo.exe build --target-dir \"$winbld\" --$build_mode"
    windows_bin="$winbld/$build_mode/$binary_name.exe"
    windows_bin=$(wslpath -u "$windows_bin")
    if [ -f "$windows_bin" ]; then
        progress "Install Windows binary: ${cyan}${windows_bin}${reset}"
        winbld=$(wslpath -u "$winbld")
        if [ "$force" -eq 1 ]; then
            run "cp \"$windows_bin\" \"$winbld/\""
        else
            echo -n "Binary already exists. Do you want to overwrite it? [Y/n/a] "
            read -r overwrite
            if [[ "$overwrite" =~ ^[Aa]$ ]]; then
                info "Aborting script as per user request."
                exit 1
            elif [[ -z "$overwrite" || "$overwrite" =~ ^[Yy]$ ]]; then
                run "cp \"$windows_bin\" \"$winbld/\""
            else
                debug "Skipping overwrite of $windows_bin"
            fi
        fi
    else
        warn "Windows binary not found: $windows_bin"
    fi

    progress "Delete Windows build directory used by cargo: ${cyan}${winbld}/${build_mode}${reset}."
    prompt_delete_build_dir "$winbld/$build_mode"
fi

# Documentation generation
if [ -n "$doc_dir" ]; then
    progress "Generate documentation."
    run "cargo doc -v --target-dir \"$doc_dir\""
fi

progress "Script completed successfully."