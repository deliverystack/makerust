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
blue=$(tput setaf 4)
reset=$(tput sgr0)

# Prefixes for colored output messages
prefix="${green}${script_name}:${reset}"
warn_prefix="${yellow}${script_name}:${reset}"
err_prefix="${red}${script_name}:${reset}"
debug_prefix="${blue}${script_name}:${reset}"

# Functions for colored output

# Informational message
info() {
    printf "%s %s\n" "$prefix" "$1"
}

# Warning message
warn() {
    printf "%s %s\n" "$warn_prefix" "$1"
}

# Error message
error() {
    printf "%s %s\n" "$err_prefix" "$1" >&2
}

# Debug message
debug() {
    [ "$debug" -eq 1 ] && printf "%s %s\n" "$debug_prefix" "$1"
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

# Set RUST_BACKTRACE environment variable
export RUST_BACKTRACE=$rust_backtrace
info "RUST_BACKTRACE set to $RUST_BACKTRACE"

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
run_command() {
    local cmd="$1"

    # Print and execute command
    if [ "$force" -eq 1 ]; then
        info "Force mode enabled: executing without prompt: $cmd"
    else
        echo -e "${prefix} About to execute: ${green}${cmd}${reset}"
        echo -n "Do you want to proceed? [Y/n] "
        read -r proceed
        if [[ -z "$proceed" || "$proceed" =~ ^[Yy]$ ]]; then
            info "Proceeding with command: $cmd"
        else
            info "Skipping command: $cmd"
            return
        fi
    fi

    # Execute command and capture output
    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    # Display command output
    echo "$output" | tee /dev/stderr

    # Handle errors
    if [ $exit_code -ne 0 ]; then
        error "Command failed: $cmd (exit code: $exit_code)"
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

# Main script logic
binary_name=$(get_binary_name)
info "Detected binary name: $binary_name"

# Build and deploy binaries
run_command "rustup update"
run_command "cargo update -v"
run_command "cargo clean"

# Linux build
if [ -n "$linbld" ]; then
    run_command "cargo build --target-dir \"$linbld\" --$build_mode"
    linux_bin="$linbld/$build_mode/$binary_name"
    if [ -f "$linux_bin" ]; then
        info "Linux binary found: $linux_bin"
        run_command "cp \"$linux_bin\" \"$linbld/\""
    else
        warn "Linux binary not found: $linux_bin"
    fi
fi

# Windows build
if [ -n "$winbld" ]; then
    winbld=$(wslpath -ma "$winbld")
    run_command "cargo.exe build --target-dir \"$winbld\" --$build_mode"
    windows_bin="$winbld/$build_mode/$binary_name.exe"
    windows_bin=$(wslpath -u "$windows_bin")
    if [ -f "$windows_bin" ]; then
        info "Windows binary found: $windows_bin"
        winbld=$(wslpath -u "$winbld")
        run_command "cp \"$windows_bin\" \"$winbld/\""
    else
        warn "Windows binary not found: $windows_bin"
    fi
fi

# Documentation generation
if [ -n "$doc_dir" ]; then
    run_command "cargo doc -v --target-dir \"$doc_dir\""
fi

info "Script completed successfully."
