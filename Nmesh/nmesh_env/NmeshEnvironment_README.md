# Nmesh Environment on Athene

This directory contains a reusable environment setup script for **building and working with Nmesh on the FAU Athene HPC cluster**.

The script was created after configuring the dependencies required for Nmesh together with **FUKA/Kadath**, MPI, FFTW, GSL, SuiteSparse, and OpenBLAS. It also performs a series of checks before rebuilding Nmesh so that common environment and linking problems can be identified early.

Personal usernames and machine-specific absolute paths are intentionally not included in this repository. Users should configure the relevant paths for their own installation.

---

## What the Script Does

The environment script performs the main setup and verification required for an Nmesh build, including:

* loading the required compiler and HPC modules;
* checking GCC and MPI compilers;
* configuring FFTW for compilation and linking;
* checking the FUKA/Kadath installation;
* verifying the FUKA symbolic link used by `FUKAdataReader`;
* checking `libkadath.a`;
* checking for the required `KadathExportBNS` symbol;
* checking the Nmesh project directories and dependencies;
* performing basic FUKA rebuild-safety checks;
* displaying and recording the active build environment;
* providing helper commands for normal and clean Nmesh builds; and
* checking the resulting Nmesh executable and its runtime libraries.

---

## Required Software / Modules

The working Athene environment uses:

```bash id="8l5jdn"
module purge

module load gcc/14
module load suite-sparse
module load gsl
module load openmpi4
module load fftw/3.3.10-gcc-12.4.0-cfng67f
```

Module versions may change on the cluster, so check the currently available versions when reproducing the environment:

```bash id="cz6l94"
module avail
```

or, for a particular dependency:

```bash id="zkg22m"
module avail fftw
```

The Nmesh C sources use the MPI C compiler:

```bash id="2vp2in"
mpicc
```

while the final executable is linked using:

```bash id="8sj4hb"
mpic++
```

The C++ linker is required because the FUKA/Kadath components contain C++ code.

---

## FUKA / Kadath Setup

Nmesh accesses FUKA through the `FUKAdataReader` project.

Rather than maintaining another copy of FUKA inside the Nmesh source tree, the setup uses a **symbolic link** from the location expected by `FUKAdataReader` to an existing FUKA installation.

Conceptually:

```text id="8g3l4f"
Nmesh/
└── src/
    └── projects/
        └── FUKAdataReader/
            └── fuka  --->  /path/to/existing/fuka
```

A symbolic link can be created with:

```bash id="rh2d0d"
cd /path/to/nmesh/src/projects/FUKAdataReader

ln -s /path/to/existing/fuka fuka
```

Verify it with:

```bash id="2s0b9p"
readlink -f fuka
```

The required Kadath library should then be accessible through:

```text id="8iy49m"
fuka/lib/libkadath.a
```

It can be checked with:

```bash id="60omtb"
ls -lh fuka/lib/libkadath.a
```

For the FUKA/Nmesh interface, the required `KadathExportBNS` symbol can be checked with:

```bash id="21n2dv"
nm -C fuka/lib/libkadath.a | grep "KadathExportBNS"
```

---

## FFTW Linking

One important issue encountered during the setup was that loading the FFTW module made FFTW available at runtime, but the final Nmesh linker initially could not locate:

```text id="s8s1fn"
-lfftw3
```

which produced:

```text id="4v23xk"
/usr/bin/ld: cannot find -lfftw3
```

The FFTW library directory therefore also needs to be available in the compiler/linker search path.

For example:

```bash id="5at7zt"
export FFTW_LIB="/path/to/fftw/lib"
export LIBRARY_PATH="$FFTW_LIB${LIBRARY_PATH:+:$LIBRARY_PATH}"
```

The actual FFTW installation path should be determined from the cluster environment rather than hardcoded into a public script.

Useful commands are:

```bash id="3m45gf"
module show fftw
```

and:

```bash id="s1a9uo"
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -i fftw
```

The configured compile-time path can be checked with:

```bash id="ccryhu"
echo "$LIBRARY_PATH" | tr ':' '\n' | grep -i fftw
```

---

## Using the Environment Script

Load the environment into the current shell with:

```bash id="z3gv7g"
source nmesh_environment.sh
```

The script should be **sourced**, rather than simply executed, because the loaded modules and exported environment variables need to remain available in the current shell.

After loading, verify the environment if necessary with:

```bash id="l2ixu8"
module list
which gcc
which mpicc
which mpic++
```

---

## Building Nmesh

For a normal incremental build:

```bash id="fzk06n"
cd /path/to/nmesh

make V=1 2>&1 | tee build.log
```

A normal build is preferable during everyday development because only files that need recompilation are rebuilt.

For a complete rebuild:

```bash id="6sruue"
cd /path/to/nmesh

make clean
make V=1 2>&1 | tee build_full.log
```

Before performing a clean rebuild, verify that the FUKA installation, symbolic link, and FUKA build configuration are intact.

---

## Everyday Workflow

A typical session is:

```bash id="5pf4vy"
# Load the Nmesh environment
source nmesh_environment.sh

# Go to the Nmesh repository
cd /path/to/nmesh

# Build after making source changes
make V=1 2>&1 | tee build.log

# Check the executable
ls -lh exe/nmesh
```

If helper functions are included in the environment script, the workflow can instead be:

```bash id="hyx5pm"
source nmesh_environment.sh

nmesh_build
nmesh_check
```

For an intentional clean rebuild:

```bash id="9zt8ex"
nmesh_clean_build
```

---

## Checking the Build

The final executable should normally be located at:

```text id="opfdqu"
nmesh/exe/nmesh
```

Check that it exists:

```bash id="pk3l8h"
ls -lh exe/nmesh
```

Check for missing runtime libraries:

```bash id="s5w6x8"
ldd exe/nmesh | grep "not found"
```

If this produces no output, no missing dynamic libraries were detected by this check.

---

## Debugging a Failed Build

Save the complete build output:

```bash id="z0nysd"
make V=1 2>&1 | tee build.log
```

Then extract the most useful errors:

```bash id="7njdf5"
grep -niE \
"cannot find|undefined reference|fatal error|No such file|collect2: error|not found" \
build.log | tail -100
```

The final part of the build log is also useful:

```bash id="y2i5im"
tail -100 build.log
```

For FUKA/Kadath/FFTW-specific problems:

```bash id="kwl2qm"
grep -niE "FUKA|kadath|fftw" build.log | tail -100
```

Compiler warnings should be distinguished from errors. Warnings do not necessarily indicate that the build failed.

---

## Running Nmesh

For small tests, Nmesh can be invoked with a parameter file as:

```bash id="2x9o7v"
/path/to/nmesh/exe/nmesh example.par
```

Computationally intensive simulations should be submitted through the cluster scheduler rather than run on a login node.

---

## Notes for Reproducing the Setup

When recreating this environment on another account or system:

1. Set the Nmesh and FUKA paths for the local installation.
2. Load the appropriate compiler, MPI, GSL, SuiteSparse, FFTW, and BLAS modules.
3. Create or verify the FUKA symbolic link.
4. Verify that `libkadath.a` exists.
5. Verify the required FUKA/Kadath symbols.
6. Make sure FFTW is visible to the linker.
7. Build Nmesh and inspect the build log for actual errors.
8. Verify the final executable and its runtime dependencies.

Paths and module versions are intentionally kept configurable because they may differ between users and may change as the Athene software environment is updated.

---

## Repository Scope

This directory contains personal setup scripts and documentation developed to make the Nmesh workflow easier to reproduce.

It does **not** distribute Nmesh, FUKA, Kadath, or other external dependencies. Those projects should be obtained from their respective official sources and used according to their licenses.

The scripts here are intended primarily as workflow/reference material and may require modification for other accounts, clusters, compiler versions, or software installations.
