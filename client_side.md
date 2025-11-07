# Quick build & run guide for libssh examples (ssh_client)

This guide contains the steps and commands used to configure, build, and run the `ssh-client` example from this libssh repository. It explains what each command does and gives troubleshooting tips.

All commands assume you're using a POSIX shell (zsh/bash) and that your current working directory is the repository root (the directory that contains `CMakeLists.txt`).

## Prerequisites

- A C compiler (gcc/clang)
- CMake >= 3.12
- zlib (runtime and -dev headers)
- OpenSSL (runtime and -dev headers) or an alternative crypto provider supported by libssh
- make (or an equivalent build tool)

On Debian/Ubuntu a typical package install is:

```bash
sudo apt update
sudo apt install build-essential cmake pkg-config libssl-dev zlib1g-dev
```

If you prefer to use OpenSSL from a custom location, set `OPENSSL_ROOT_DIR` when invoking cmake (example later).

## Commands used (with descriptions)

1) Check CMake is available and view its version

```bash
cmake --version
```

What it does: prints the installed CMake version. libssh's `INSTALL` suggests CMake >= 3.12; the project may work with a newer version.

Troubleshooting: if this fails, install CMake via your package manager or from cmake.org.

2) Check your C compiler

```bash
gcc --version
```

What it does: confirms you have GCC (or replace with `clang --version`). If you don't have a compiler installed, `make` will fail.

3) Check `make` exists

```bash
which make || echo 'make not found'
```

What it does: verifies that a build tool is present. On many systems `make` is provided by `build-essential`.

4) Create a `build/` directory and run CMake to configure the project

```bash
mkdir -p build && cd build && cmake -DWITH_EXAMPLES=ON -DCMAKE_BUILD_TYPE=Debug ..
```

What it does: creates an out-of-tree build directory and runs CMake to generate build files. `-DWITH_EXAMPLES=ON` enables building example binaries (like `ssh-client`). `-DCMAKE_BUILD_TYPE=Debug` makes a debug build.

Notes / Troubleshooting:
- If CMake complains about missing dependencies, read the missing component name (for example: `OpenSSL`, `ZLIB`) and install the corresponding `-dev` package (e.g., `libssl-dev`, `zlib1g-dev`).
- If OpenSSL is installed in a non-standard location use:

```bash
cmake -DWITH_EXAMPLES=ON -DCMAKE_BUILD_TYPE=Debug -DOPENSSL_ROOT_DIR=/path/to/openssl ..
```

- If you see warnings about ABIMap/abimap, those are optional tools for ABI/versioning and usually do not block the build.

5) Build the project (parallel build uses all CPU cores)

```bash
cd build && make -j$(nproc)
```

What it does: compiles libssh and the example programs. Replace `$(nproc)` with a fixed number if you prefer (for example `-j4`).

Troubleshooting:
- If the build fails, read the failing target and the first compiler error — often indicates a missing header or library. Install the corresponding `-dev` package.
- Deprecation warnings are common (they won't necessarily fail the build). Focus on actual errors.

6) List the built example binaries

```bash
ls -l build/examples
```

What it does: shows example executables (e.g. `ssh-client`, `sshnetcat`, `scp_download`). Note their paths and make sure they are executable.

7) Print `ssh-client` help/usage

```bash
./build/examples/ssh-client --help
```

What it does: runs the example with the `--help` (or `-h`) argument to show how to use it. The example accepts configuration parsing and a few flags: `-F` to parse a config file, `-P` to write a pcap file (if built with PCAP support), and `-T` to set a proxy command. The example also supports specifying `[user@]host` and commands to execute.

8) Check dynamic dependencies of the ssh-client binary

```bash
ldd build/examples/ssh-client
```

What it does: lists shared libraries required by the binary and their resolution paths. Check that `libssh.so` and `libcrypto`/`libz` are resolved. If `libssh` or another library is listed as `not found`, you'll need to either install it system-wide (via `make install`) or point the runtime linker to the build `lib/` directory.

If `libssh.so` shows a path inside the build directory (e.g. `/.../build/lib/libssh.so.4`) then running the binary from the repository will find the library. If it points to `not found`, fix it using one of the options below.

### Runtime library options

- Use the build `lib/` for this session:

```bash
export LD_LIBRARY_PATH="$(pwd)/build/lib:$LD_LIBRARY_PATH"
```

What it does: tells the dynamic loader to search the build `lib/` directory for shared libraries at runtime. This is useful if you don't want to `make install`.

- Or install the library system-wide:

```bash
cd build
sudo make install
# (optionally) sudo ldconfig
```

What it does: installs `libssh` and headers to the system `CMAKE_INSTALL_PREFIX` (defaults to `/usr/local` unless changed). After installation, binaries will pick up the library from standard system paths.

8) Make the example executable if needed

```bash
chmod +x build/examples/ssh-client
```

What it does: ensures the example binary is runnable.

9) Run the client (example)

From the repository root:

```bash
./build/examples/ssh-client user@example.com
```

Or provide the user and port explicitly (the example parses some options via ssh options parsing):

```bash
./build/examples/ssh-client -l username -p 22 example.com
```

What it does: connects to `example.com` as `username` on port 22 and gives you an interactive shell or executes commands passed on the command line.

Notes:
- The example will prompt for passwords or use keys according to your SSH configuration (it parses `~/.ssh/config` and system config unless overridden).
- To run a command non-interactively, pass commands after the hostname: e.g.

```bash
./build/examples/ssh-client user@host ls -la /tmp
```

## Common problems & fixes

- Missing OpenSSL headers when configuring or building:
  - Install `libssl-dev` (Debian/Ubuntu) or the equivalent for your distribution.

- zlib not found:
  - Install `zlib1g-dev` (Debian/Ubuntu) or the equivalent.

- `libssh` not found at runtime:
  - Either `export LD_LIBRARY_PATH="$(pwd)/build/lib:$LD_LIBRARY_PATH"` before running the example, or run `cd build && sudo make install` and then `sudo ldconfig`.

- CMake errors about `GSSAPI` or optional features:
  - These warnings are often optional. If you need GSSAPI/Kerberos support install `libkrb5-dev` or similar.

- ABIMap/abimap warnings during configure:
  - These are related to ABI checking tools used by the build system and are optional; you can usually ignore them for a normal build.

- Permission denied when running examples:
  - Ensure the binaries are executable (`chmod +x`) and that you're in the correct directory.

## Quick