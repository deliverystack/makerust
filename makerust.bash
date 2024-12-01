#!/usr/bin/bash

# SCRIPT SUMMARY
# This script automates building, testing, and deploying Rust projects.
# Features include:
#   - Building binaries for Linux and Windows platforms.
#   - Generating documentation for the project.
#   - Support for debug and release build modes.
#   - A "force mode" to skip user prompts.
#   - Verbose and debug modes for detailed logging.
#   - Optional command execution timing.
#   - Detection of binary names from Cargo.toml.
#   - Informative, warning, and error messages with colorized output.

# DEFAULT CONFIGURATION VARIABLES
project_dir="$(pwd)" # Default project directory is the current directory
winbld=""            # Windows build output directory (user-defined)
linbld=""            # Linux build output directory (user-defined)
doc_dir=""           # Documentation output directory (user-defined)
build_mode="release" # Build mode: "release" (default) or "debug"
verbose=0            # Verbose mode toggle (0: off, 1: on)
debug=0              # Debug mode toggle (0: off, 1: on)
use_time=0           # Time command execution toggle (0: off, 1: on)
rust_backtrace="full" # Default Rust backtrace level for debugging
force=0              # Force mode toggle (0: off, 1: on)
script_name=$(basename "$0") # The name of this script for message context

# OUTPUT COLOR CONFIGURATION (for user-friendly messaging)
green=$(tput setaf 2)   # Green for success or informational variable values
yellow=$(tput setaf 3)  # Yellow for warnings
red=$(tput setaf 1)     # Red for errors
cyan=$(tput setaf 6)    # Cyan for informational messages
orange=$(tput setaf 3)  # Orange for progress updates
reset=$(tput sgr0)      # Reset to default terminal text style

display() {
    printf "${1}${script_name}${reset}: %s\n" "$2"
}

# FUNCTION: Display informational messages (e.g., status updates)
# Arguments: $1 - Message string
info() {
    [[ "$verbose" -eq 1 || "$debug" -eq 1 ]] && display ${green} "$1"
}

# FUNCTION: Display progress messages (e.g., ongoing tasks)
# Arguments: $1 - Message string
progress() {
    display ${orange} "$1"
}

# FUNCTION: Display warning messages (e.g., potential issues)
# Arguments: $1 - Warning message string
warn() {
    display ${yellow} "$1"
}

# FUNCTION: Display error messages (e.g., command failures)
# Arguments: $1 - Error message string
error() {
    display ${red} "$1" >&2
}

# FUNCTION: Display debug messages (if debug mode is enabled)
# Arguments: $1 - Debug message string
debug() {
    [ "$debug" -eq 1 ] && display ${cyan} "$1"
}

# FUNCTION: Display usage information for the script
# Purpose: Provide a summary of available options and usage examples.
usage() {
    echo "Usage: ${script_name} [options]"
    echo "Options:"
    echo "  -v          Enable verbose mode."
    echo "  -d          Enable debug mode (more detailed output)."
    echo "  -t          Enable command execution timing."
    echo "  -b <value>  Set RUST_BACKTRACE level (default: full)."
    echo "  -p <path>   Specify the Rust project directory."
    echo "  -w <path>   Specify the output directory for Windows builds."
    echo "  -l <path>   Specify the output directory for Linux builds."
    echo "  -o <path>   Specify the output directory for documentation."
    echo "  -m <mode>   Specify build mode ('debug' or 'release')."
    echo "  -f          Enable force mode (skip all prompts)."
    echo "  -h          Display this help message."
    exit 0
}

# FUNCTION: Prompt the user to delete a build directory
# Arguments: $1 - Path of the build directory to delete
# If the directory exists, prompt the user (unless force mode is enabled).
prompt_delete_directory() {
    local dir="$1"

    if [ -d "$dir" ]; then
        if [ "$force" -ne 1 ]; then
            echo -e "${warn_prefix} Do you want to delete the directory: ${yellow}${dir}${reset}? [y/N]"
            read -r delete_dir
            if [[ "$delete_dir" =~ ^[Yy]$ ]]; then
                run "rm -rf \"$dir\""
                info "Deleted directory: $dir"
            else
                info "Skipped deletion of directory: $dir"
            fi
        else
            run "rm -rf \"$dir\""
            info "Force mode: deleted directory: $dir"
        fi
    else
        debug "Directory not found, skipping deletion: $dir"
    fi
}

# FUNCTION: Extract the binary name from the project's Cargo.toml file
# Arguments: None
# Returns: Binary name as extracted from Cargo.toml
get_binary_name() {
    local cargo_toml="$project_dir/Cargo.toml"
    if [ -f "$cargo_toml" ]; then
        grep -m1 '^name =' "$cargo_toml" | sed -E 's/^name = "(.*)"/\1/'
    else
        error "Cargo.toml not found in $project_dir"
        exit 1
    fi
}

# FUNCTION: Execute a command with optional prompts and error handling
# Arguments: $1 - Command string to execute
# If force mode is enabled, the command runs without confirmation.
run() {
    local cmd="$1"

    # Show command execution preview
    if [ "$force" -eq 1 ]; then
        info "Force mode enabled: executing without prompt: ${cyan}${cmd}${reset}"
    else
        echo -e "${script_name}: About to execute: ${green}${cmd}${reset}"
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

    if [ "$use_time" -eq 1 ]; then
        cmd="time $cmd"
    fi

    output=""
    while IFS= read -r line; do
        output+="$line"$'\n'
        if [[ "$verbose" -eq 1 || "$debug" -eq 1 ]]; then
            echo "$line"
        fi
    done < <($cmd 2>&1)
    local exit_code=$?

    # Check for errors or warnings in the output
    if [ $exit_code -ne 0 ] || echo "$output" | grep -qEi "(error|warning)" | grep -vqE "(--error|--warning)"; then
        error "Command failed: $cmd (exit code: $exit_code)"
        if [ "$force" -eq 1 ]; then
            info "Force mode enabled: exiting script due to command error."
            exit 1
        fi
        echo -n "${script_name}: Do you want to continue to the next command? [Y/n] "
        read -r continue_next
        if [[ -z "$continue_next" || "$continue_next" =~ ^[Yy]$ ]]; then
            warn "Continuing to the next command despite error."
        else
            exit 1
        fi
    fi
}

# PARSE COMMAND-LINE ARGUMENTS
# Options:
# -v: Enable verbose mode
# -d: Enable debug mode
# -t: Enable timing
# -b: Set Rust backtrace level
# -p: Set project directory
# -w: Set Windows build output directory
# -l: Set Linux build output directory
# -o: Set documentation output directory
# -m: Set build mode (debug or release)
# -f: Enable force mode
# -h: Display help
while getopts ":vdtb:p:w:l:o:m:fh" opt; do
    case $opt in
        v) verbose=1 ;;
        d) debug=1 ;;
        t) use_time=1 ;;
        b) rust_backtrace=$OPTARG ;;
        p) project_dir=$OPTARG ;;
        w) winbld=$OPTARG ;;
        l) linbld=$OPTARG ;;
        o) doc_dir=$OPTARG ;;
        m) build_mode=$OPTARG ;;
        f) force=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

CARGO_TARGET_DIR=$project_dir
cd $project_dir

# Validate build mode (must be "release" or "debug")
if [[ "$build_mode" != "release" && "$build_mode" != "debug" ]]; then
    error "Invalid build mode: $build_mode. Must be 'release' or 'debug'."
    exit 1
fi

if [[ "$rust_backtrace" != "full" && "$rust_backtrace" != "short" && "$rust_backtrace" != "0" && "$rust_backtrace" != "1" ]]; then
    error "Invalid RUST_BACKTRACE value: $rust_backtrace. Must be 'full', 'short', '0', or '1'."
fi

# Export RUST_BACKTRACE level for the script's execution
export RUST_BACKTRACE=$rust_backtrace
debug "RUST_BACKTRACE set to ${cyan}$RUST_BACKTRACE${reset}"
debug "Project directory set to: ${cyan}$project_dir${reset}"
debug "Windows build output directory set to: ${cyan}$winbld${reset}"
debug "Linux build output directory set to: ${cyan}$linbld${reset}"
debug "Documentation output directory set to: ${cyan}$doc_dir${reset}"
debug "Build mode set to: ${cyan}$build_mode${reset}"
debug "Verbose mode: ${cyan}$verbose${reset}"
debug "Debug mode: ${cyan}$debug${reset}"
debug "Time mode: ${cyan}$use_time${reset}"
debug "Force mode: ${cyan}$force${reset}"

# DETECT THE PROJECT'S BINARY NAME
binary_name=$(get_binary_name)
debug "Binary name detected: ${cyan}${binary_name}${reset}" HW

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
            run "cp $linux_bin $linbld"
        else
            echo -n "${script_name}: Binary already exists. Do you want to overwrite it? [Y/n/a] "
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
        ls $linux_bin
    fi

    progress "Delete Linux build directory used by cargo: ${cyan}${linbld}/${build_mode}${reset}."
    prompt_delete_directory "$linbld/$build_mode"
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
    prompt_delete_directory "$winbld/$build_mode"
fi

# GENERATE DOCUMENTATION
if [ -n "$doc_dir" ]; then
    if [ ! -d "$doc_dir" ]; then
        error "Documentation directory does not exist: $doc_dir"
    fi
    info "Generating documentation."
    run "cargo doc -v --target-dir \"$doc_dir\""
fi

progress "Script completed successfully."