# makerust.bash: The Ultimate (WSL) Rust Compilation and Deployment Script 

Depending on command line options and user interaction, makerust.bash can do the following, in this order:
-	Update Rust toolchains, components, and rustup.
-	Update dependencies in Cargo.lock to the latest versions
-	Remove files from the target directory to clean build artifacts and dependencies.
-	Build a Linux binary.
-	Install the Linux binary.
-	Delete the Linux build directory.
-	Build a Windows binary.
-	Install the Windows binary.
-	Delete the Windows build directory.
-	Generate documentation.

The script describes its command line parameters. You should pass at least one of these:

- `-l <path>`: build the Linux binary under this path, and then move it to this path.
- `-w <path>`: build the Windows binary under this path, and then move it to this path.

Without the -f option, the script will prompt before invoking each command.

Example usage:

```
time ~/git/makerust/makerust.bash -w $HOME/bin -l $HOME/bin -p . -fvdt
```

Example output:

```
[2024-11-18 09:09:34]:jw@LAPTOP-JT7KRJMI:2063:~/git/uimport
$ time ~/git/makerust/makerust.bash -w $HOME/bin -l $HOME/bin -p . -fvdt
makerust.bash: RUST_BACKTRACE set to full
makerust.bash: Project directory set to: .
makerust.bash: Windows build output directory set to: /home/jw/bin
makerust.bash: Linux build output directory set to: /home/jw/bin
makerust.bash: Documentation output directory set to:
makerust.bash: Build mode set to: release
makerust.bash: Verbose mode: 1
makerust.bash: Debug mode: 1
makerust.bash: Time mode: 1
makerust.bash: Force mode: 1
makerust.bash: Binary name detected: uimport
makerust.bash: Update Rust toolchains, components, and rustup.
makerust.bash: Force mode enabled: executing without prompt: rustup update
info: syncing channel updates for 'stable-x86_64-unknown-linux-gnu'
info: checking for self-update

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.82.0 (f6e511eec 2024-10-15)

info: cleaning up downloads & tmp directories
makerust.bash: Running again to capture output: rustup update
makerust.bash: Running command with timing: rustup update
info: syncing channel updates for 'stable-x86_64-unknown-linux-gnu'
info: checking for self-update

  stable-x86_64-unknown-linux-gnu unchanged - rustc 1.82.0 (f6e511eec 2024-10-15)

info: cleaning up downloads & tmp directories

real    0m0.181s
user    0m0.058s
sys     0m0.047s
makerust.bash: Update dependencies in Cargo.lock to the latest versions.
makerust.bash: Force mode enabled: executing without prompt: cargo update -v
    Updating crates.io index
     Locking 0 packages to latest compatible versions
   Unchanged windows-core v0.52.0 (latest: v0.58.0)
note: to see how you depend on a package, run `cargo tree --invert --package <dep>@<ver>`
makerust.bash: Running again to capture output: cargo update -v
makerust.bash: Running command with timing: cargo update -v
    Updating crates.io index
     Locking 0 packages to latest compatible versions
   Unchanged windows-core v0.52.0 (latest: v0.58.0)
note: to see how you depend on a package, run `cargo tree --invert --package <dep>@<ver>`

real    0m0.534s
user    0m0.133s
sys     0m0.011s
makerust.bash: Remove target directory files to clean build artifacts and dependencies.
makerust.bash: Force mode enabled: executing without prompt: cargo clean
     Removed 0 files
makerust.bash: Running again to capture output: cargo clean
makerust.bash: Running command with timing: cargo clean
     Removed 0 files

real    0m0.054s
user    0m0.051s
sys     0m0.000s
makerust.bash: Build Linux binary.
makerust.bash: Force mode enabled: executing without prompt: cargo build --target-dir "/home/jw/bin" --release
    Finished `release` profile [optimized] target(s) in 0.40s
makerust.bash: Running again to capture output: cargo build --target-dir "/home/jw/bin" --release
makerust.bash: Running command with timing: cargo build --target-dir "/home/jw/bin" --release
    Finished `release` profile [optimized] target(s) in 0.36s

real    0m0.410s
user    0m0.049s
sys     0m0.042s
makerust.bash: Install Linux binary: /home/jw/bin/release/uimport
makerust.bash: Force mode enabled: executing without prompt: cp "/home/jw/bin/release/uimport" "/home/jw/bin/"
makerust.bash: Running again to capture output: cp "/home/jw/bin/release/uimport" "/home/jw/bin/"
makerust.bash: Running command with timing: cp "/home/jw/bin/release/uimport" "/home/jw/bin/"

real    0m0.033s
user    0m0.003s
sys     0m0.000s
makerust.bash: Delete Linux build directory used by cargo: /home/jw/bin/release.
/home/jw/git/makerust/makerust.bash: line 106: run_command: command not found
makerust.bash: Force mode: deleted directory: /home/jw/bin/release
makerust.bash: Build Windows binary.
makerust.bash: Force mode enabled: executing without prompt: cargo.exe build --target-dir "C:/users/ms/OneDrive/wslbin" --release
    Finished release [optimized] target(s) in 0.20s
makerust.bash: Running again to capture output: cargo.exe build --target-dir "C:/users/ms/OneDrive/wslbin" --release
makerust.bash: Running command with timing: cargo.exe build --target-dir "C:/users/ms/OneDrive/wslbin" --release
    Finished release [optimized] target(s) in 0.14s

real    0m0.279s
user    0m0.002s
sys     0m0.000s
makerust.bash: Install Windows binary: /mnt/c/users/ms/OneDrive/wslbin/release/uimport.exe
makerust.bash: Force mode enabled: executing without prompt: cp "/mnt/c/users/ms/OneDrive/wslbin/release/uimport.exe" "/mnt/c/users/ms/OneDrive/wslbin/"
makerust.bash: Running again to capture output: cp "/mnt/c/users/ms/OneDrive/wslbin/release/uimport.exe" "/mnt/c/users/ms/OneDrive/wslbin/"
makerust.bash: Running command with timing: cp "/mnt/c/users/ms/OneDrive/wslbin/release/uimport.exe" "/mnt/c/users/ms/OneDrive/wslbin/"

real    0m0.067s
user    0m0.000s
sys     0m0.003s
makerust.bash: Delete Windows build directory used by cargo: /mnt/c/users/ms/OneDrive/wslbin/release.
/home/jw/git/makerust/makerust.bash: line 106: run_command: command not found
makerust.bash: Force mode: deleted directory: /mnt/c/users/ms/OneDrive/wslbin/release
makerust.bash: Script completed successfully.

real    0m7.301s
user    0m0.816s
sys     0m0.457s
```