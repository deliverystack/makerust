#!/usr/bin/bash

source $HOME/bin/lib.bash

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
cyan=$(tput setaf 6)    # Cyan for informational messages
reset_color=$(tput sgr0)      # Reset to default terminal text style

# FUNCTION: Display usage information for the script
# Purpose: Provide a summary of available options and usage examples.
usage() {
    echo "Usage: ${script_name} [options]"
    echo "Options:"
    echo "  -b <value>  Set RUST_BACKTRACE level (default: full)."
    echo "  -d          Enable debug mode (more detailed output)."
    echo "  -f          Enable force mode (skip all prompts)."
    echo "  -h          Display this help message."
    echo "  -l <path>   Specify the output directory for Linux builds."
    echo "  -m <mode>   Specify build mode ('debug' or 'release')."
    echo "  -o <path>   Specify the output directory for documentation."
    echo "  -p <path>   Specify the Rust project directory."
    echo "  -t          Enable command execution timing."
    echo "  -v          Enable verbose mode."
    echo "  -w <path>   Specify the output directory for Windows builds."
    exit 0
}

# FUNCTION: Prompt the user to delete a build directory
# Arguments: $1 - Path of the build directory to delete
# If the directory exists, prompt the user (unless force mode is enabled).
prompt_delete_directory() {
    local dir="$1"

    # Prevent accidental deletion of the project directory or root directory
    if [[ "$dir" == "$project_dir" || "$dir" == "/" ]]; then
        error "Refusing to delete the project directory or root directory: $dir"
        return 1
    fi

    if [ -d "$dir" ]; then
        if [ "$force" -ne 1 ]; then
            echo -e "Do you want to delete the directory: ${cyan}${dir}${reset_color}? [y/N]"
            read -r delete_dir
            if [[ "$delete_dir" =~ ^[Yy]$ ]]; then
#                run_command rm -rf "$dir"
                info "Deleted directory: $dir"
            else
                info "Skipped deletion of directory: $dir"
            fi
        else
#            run_command rm -rf "$dir"
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

run_flags=()
[[ "$debug" -eq 1 ]] && run_flags+=("-d")
[[ "$verbose" -eq 1 ]] && run_flags+=("-v")
[[ "$use_time" -eq 1 ]] && run_flags+=("-t")
run_flags+=("-x")
run_flags+=("--") # must be last

#export CARGO_TARGET_DIR=$project_dir
cd "$project_dir" || error "invalid project directory: ${cyan}$project_dir${reset_color}"

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
debug "RUST_BACKTRACE set to ${cyan}$RUST_BACKTRACE${reset_color}"
debug "Project directory set to: ${cyan}$project_dir${reset_color}"
debug "Windows build output directory set to: ${cyan}$winbld${reset_color}"
debug "Linux build output directory set to: ${cyan}$linbld${reset_color}"
debug "Documentation output directory set to: ${cyan}$doc_dir${reset_color}"
debug "Build mode set to: ${cyan}$build_mode${reset_color}"
debug "Verbose mode: ${cyan}$verbose${reset_color}"
debug "Debug mode: ${cyan}$debug${reset_color}"
debug "Time mode: ${cyan}$use_time${reset_color}"
debug "Force mode: ${cyan}$force${reset_color}"

# DETECT THE PROJECT'S BINARY NAME
binary_name=$(get_binary_name)
debug "Binary name detected: ${cyan}${binary_name}${reset_color}"

progress "Remove target directory files to clean build artifacts and dependencies."
run_command "${run_flags[@]}" cargo clean --target-dir "$project_dir/target" 

if [ -n "$linbld" ]; then
    progress "Update Linux Rust toolchains, components, and rustup."
    run_command "${run_flags[@]}" rustup update

    progress "Update Linux dependencies in Cargo.lock to the latest versions."
    run_command "${run_flags[@]}" cargo update -v


    progress "Build Linux binary."
    run_command "${run_flags[@]}" cargo build --target-dir "$project_dir/target/linux" "--$build_mode"
    
    linux_bin="$project_dir/target/linux/$build_mode/$binary_name"
    if [ -f "$linux_bin" ]; then
        progress "Install Linux binary: ${cyan}${linux_bin}${reset_color}"
        run_command "${run_flags[@]}" cp "$linux_bin" "$linbld"
    else
        warn "Linux binary not found: $linux_bin"
    fi

    progress "Delete Linux build directory used by cargo."
    run_command "${run_flags[@]}" cargo clean --target-dir "$project_dir/target/linux"
fi

# Windows build
if [ -n "$winbld" ]; then
    progress "Update Windows Rust toolchains, components, and rustup."
    run_command "${run_flags[@]}" rustup.exe update

    progress "Update Windows dependencies in Cargo.lock to the latest versions."
    run_command "${run_flags[@]}" cargo.exe update -v

    progress "Build Windows binary."
    run_command "${run_flags[@]}" cargo.exe build --target-dir "$winbld" "--$build_mode"

    windows_bin=$(wslpath -u "$project_dir/target/windows/$build_mode/$binary_name.exe")
    if [ -f "$windows_bin" ]; then
        progress "Install Windows binary: ${cyan}${windows_bin}${reset_color}"
        winbld=$(wslpath -u "$winbld")
        run_command "${run_flags[@]}" cp "$windows_bin" "$winbld/"
    else
        warn "Windows binary not found: $windows_bin"
    fi

    progress "Delete Windows build directory used by cargo."
    run_command "${run_flags[@]}" cargo clean --target-dir "$project_dir/target/windows"
fi

# GENERATE DOCUMENTATION
if [ -n "$doc_dir" ]; then
    if [ ! -d "$doc_dir" ]; then
        error "Documentation directory does not exist: $doc_dir"
    fi
    info "Generating documentation."
    run_command "${run_flags[@]}" cargo doc -v --target-dir "$project_dir/target/docs"
fi

progress "Script completed successfully."