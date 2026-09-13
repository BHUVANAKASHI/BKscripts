#!/bin/bash

# ==============================================================================
# NMESH BUILD ENVIRONMENT — FAU ATHENE
# ==============================================================================
#
# Purpose:
#   Prepare and verify the complete environment needed to compile Nmesh,
#   including:
#
#     1.  Basic paths
#     2.  Required modules
#     3.  Compiler / MPI checks
#     4.  FFTW setup
#     5.  FUKA symlink and Kadath checks
#     6.  Nmesh project-directory checks
#     7.  Required static/shared library checks
#     8.  FUKA safety checks
#     9.  Environment summary
#     10. Build / post-build verification
#
# IMPORTANT:
#   This script is intended to be SOURCED:
#
#       source ~/nmesh_environment.sh
#
#   Do NOT normally run:
#
#       ./nmesh_environment.sh
#
#   because module changes and exported environment variables need to remain
#   active in the current shell.
#
# ==============================================================================


# ==============================================================================
# 1. BASIC PATHS
# ==============================================================================

echo
echo "======================================================================"
echo "1. NMESH BASIC PATHS"
echo "======================================================================"

# Main Nmesh checkout
export NMESH_HOME="$HOME/nmesh"

# External working FUKA installation
export FUKA_EXTERNAL="path"

# Location where Nmesh expects FUKA
export FUKA_NMESH="path"

# Kadath static library
export KADATH_LIB="path"

# FUKA CMake-generated Makefile
export FUKA_BUILD_MAKEFILE="path"

# FFTW installation discovered on Athene
export FFTW_ROOT="path"

export FFTW_LIB="$FFTW_ROOT/lib"
export FFTW_INCLUDE="$FFTW_ROOT/include"


echo "NMESH_HOME       = $NMESH_HOME"
echo "FUKA_EXTERNAL    = $FUKA_EXTERNAL"
echo "FUKA_NMESH       = $FUKA_NMESH"
echo "KADATH_LIB       = $KADATH_LIB"
echo "FFTW_ROOT        = $FFTW_ROOT"

echo


# Check that Nmesh directory exists
if [ ! -d "$NMESH_HOME" ]; then
    echo "ERROR: Nmesh directory does not exist:"
    echo "       $NMESH_HOME"
    return 1 2>/dev/null || exit 1
fi

echo "[OK] Nmesh directory exists."


# ==============================================================================
# 2. LOAD REQUIRED MODULES
# ==============================================================================

echo
echo "======================================================================"
echo "2. LOADING REQUIRED MODULES"
echo "======================================================================"

# Start from a clean module environment.
module purge


# ----------------------------------------------------------------------
# Compiler
# ----------------------------------------------------------------------

module load gcc/14

if [ $? -ne 0 ]; then
    echo "ERROR: Could not load gcc/14"
    return 1 2>/dev/null || exit 1
fi


# ----------------------------------------------------------------------
# SuiteSparse
# ----------------------------------------------------------------------

module load suite-sparse

if [ $? -ne 0 ]; then
    echo "ERROR: Could not load suite-sparse"
    return 1 2>/dev/null || exit 1
fi


# ----------------------------------------------------------------------
# GSL
# ----------------------------------------------------------------------

module load gsl

if [ $? -ne 0 ]; then
    echo "ERROR: Could not load gsl"
    return 1 2>/dev/null || exit 1
fi


# ----------------------------------------------------------------------
# OpenMPI
# ----------------------------------------------------------------------

module load openmpi4

if [ $? -ne 0 ]; then
    echo "ERROR: Could not load openmpi4"
    return 1 2>/dev/null || exit 1
fi


# ----------------------------------------------------------------------
# FFTW
# ----------------------------------------------------------------------

module load fftw/3.3.10-gcc-12.4.0-cfng67f

if [ $? -ne 0 ]; then
    echo "ERROR: Could not load FFTW module"
    return 1 2>/dev/null || exit 1
fi


echo
echo "[OK] Required modules loaded."

echo
echo "Loaded modules:"
module list 2>&1


# ==============================================================================
# 3. COMPILER AND MPI CHECKS
# ==============================================================================

echo
echo "======================================================================"
echo "3. COMPILER / MPI CHECKS"
echo "======================================================================"


# Nmesh C source is normally compiled using mpicc.
if command -v mpicc >/dev/null 2>&1; then
    echo "[OK] mpicc  = $(which mpicc)"
else
    echo "ERROR: mpicc is not available."
    return 1 2>/dev/null || exit 1
fi


# The FINAL Nmesh link must use mpic++ because FUKA/Kadath contains C++ code.
if command -v mpic++ >/dev/null 2>&1; then
    echo "[OK] mpic++ = $(which mpic++)"
else
    echo "ERROR: mpic++ is not available."
    return 1 2>/dev/null || exit 1
fi


if command -v gcc >/dev/null 2>&1; then
    echo "[OK] gcc    = $(which gcc)"
else
    echo "ERROR: gcc is not available."
    return 1 2>/dev/null || exit 1
fi


if command -v g++ >/dev/null 2>&1; then
    echo "[OK] g++    = $(which g++)"
else
    echo "ERROR: g++ is not available."
    return 1 2>/dev/null || exit 1
fi


echo
echo "Compiler versions:"
echo "----------------------------------------------------------------------"

gcc --version | head -1
g++ --version | head -1
mpicc --version | head -1
mpic++ --version | head -1


# ==============================================================================
# 4. FFTW SETUP AND LINKER CHECK
# ==============================================================================

echo
echo "======================================================================"
echo "4. FFTW SETUP"
echo "======================================================================"


# The FFTW module adds its lib directory to LD_LIBRARY_PATH.
#
# However, during the Nmesh build we discovered that:
#
#       mpic++ ... -lfftw3
#
# failed with:
#
#       /usr/bin/ld: cannot find -lfftw3
#
# Therefore the FFTW lib directory ALSO needs to be available to the
# compile-time linker through LIBRARY_PATH.


if [ ! -d "$FFTW_LIB" ]; then
    echo "ERROR: FFTW library directory does not exist:"
    echo "       $FFTW_LIB"
    return 1 2>/dev/null || exit 1
fi


# Add FFTW to compiler/linker search path.
case ":${LIBRARY_PATH:-}:" in
    *":$FFTW_LIB:"*)
        ;;
    *)
        export LIBRARY_PATH="$FFTW_LIB${LIBRARY_PATH:+:$LIBRARY_PATH}"
        ;;
esac


echo "[OK] FFTW linker path configured."

echo
echo "FFTW LIBRARY_PATH:"
echo "$LIBRARY_PATH" | tr ':' '\n' | grep fftw


# ----------------------------------------------------------------------
# Check that libfftw3 actually exists
# ----------------------------------------------------------------------

echo
echo "Checking FFTW libraries:"

ls -lh "$FFTW_LIB"/libfftw3* 2>/dev/null

if ! ls "$FFTW_LIB"/libfftw3.so* >/dev/null 2>&1 &&
   [ ! -f "$FFTW_LIB/libfftw3.a" ]; then

    echo
    echo "ERROR: libfftw3 was not found in:"
    echo "       $FFTW_LIB"

    return 1 2>/dev/null || exit 1
fi

echo "[OK] FFTW library found."


# ----------------------------------------------------------------------
# Compile a tiny FFTW test
# ----------------------------------------------------------------------

echo
echo "Testing FFTW compile/link..."

cat > /tmp/test_nmesh_fftw.c <<'EOF'
#include <fftw3.h>

int main(void)
{
    fftw_complex *x;

    x = fftw_malloc(sizeof(fftw_complex) * 8);

    if (x == NULL)
        return 1;

    fftw_free(x);

    return 0;
}
EOF


mpicc /tmp/test_nmesh_fftw.c -lfftw3 -o /tmp/test_nmesh_fftw

if [ $? -ne 0 ]; then
    echo
    echo "ERROR: FFTW compile/link test failed."
    echo
    echo "Do NOT attempt a full Nmesh rebuild yet."
    return 1 2>/dev/null || exit 1
fi


/tmp/test_nmesh_fftw

if [ $? -ne 0 ]; then
    echo "ERROR: FFTW runtime test failed."
    return 1 2>/dev/null || exit 1
fi


echo "[OK] FFTW compile and runtime test passed."


# ==============================================================================
# 5. FUKA / KADATH CHECKS
# ==============================================================================

echo
echo "======================================================================"
echo "5. FUKA / KADATH CHECKS"
echo "======================================================================"


# ----------------------------------------------------------------------
# Verify external FUKA
# ----------------------------------------------------------------------

if [ ! -d "$FUKA_EXTERNAL" ]; then
    echo "ERROR: External FUKA tree does not exist:"
    echo "       $FUKA_EXTERNAL"
    return 1 2>/dev/null || exit 1
fi

echo "[OK] External FUKA directory exists."


# ----------------------------------------------------------------------
# Verify Nmesh FUKA path
# ----------------------------------------------------------------------

if [ ! -e "$FUKA_NMESH" ]; then

    echo
    echo "ERROR: Nmesh FUKA path does not exist:"
    echo
    echo "       $FUKA_NMESH"
    echo
    echo "Expected this to be a symlink pointing to:"
    echo
    echo "       $FUKA_EXTERNAL"
    echo

    return 1 2>/dev/null || exit 1
fi


echo
echo "Nmesh FUKA path resolves to:"

readlink -f "$FUKA_NMESH"


# ----------------------------------------------------------------------
# Verify the symlink points to the expected FUKA
# ----------------------------------------------------------------------

FUKA_RESOLVED="$(readlink -f "$FUKA_NMESH")"
EXTERNAL_RESOLVED="$(readlink -f "$FUKA_EXTERNAL")"

if [ "$FUKA_RESOLVED" != "$EXTERNAL_RESOLVED" ]; then

    echo
    echo "WARNING:"
    echo "Nmesh FUKA does NOT resolve to the expected external FUKA."
    echo
    echo "Nmesh resolves to:"
    echo "    $FUKA_RESOLVED"
    echo
    echo "Expected:"
    echo "    $EXTERNAL_RESOLVED"

else

    echo "[OK] Nmesh FUKA path points to the expected FUKA tree."

fi


# ----------------------------------------------------------------------
# Check libkadath.a
# ----------------------------------------------------------------------

echo
echo "Checking Kadath library..."

if [ ! -f "$KADATH_LIB" ]; then

    echo "ERROR: libkadath.a is missing:"
    echo "       $KADATH_LIB"

    return 1 2>/dev/null || exit 1
fi


ls -lh "$KADATH_LIB"

echo "[OK] libkadath.a exists."


# ----------------------------------------------------------------------
# Verify KadathExportBNS symbol
# ----------------------------------------------------------------------

echo
echo "Checking KadathExportBNS symbol..."

if nm -C "$KADATH_LIB" 2>/dev/null | grep -q "KadathExportBNS"; then

    nm -C "$KADATH_LIB" |
        grep "KadathExportBNS" |
        head

    echo
    echo "[OK] KadathExportBNS exists in libkadath.a."

else

    echo
    echo "ERROR: KadathExportBNS not found in libkadath.a."

    return 1 2>/dev/null || exit 1
fi


# ==============================================================================
# 6. NMESH PROJECT DIRECTORY CHECKS
# ==============================================================================

echo
echo "======================================================================"
echo "6. NMESH PROJECT CHECKS"
echo "======================================================================"


# These project directories were required by the working Nmesh configuration.

PROJECTS=(
    "Project1"
    "Project2"
    ....
)


MISSING_PROJECTS=0


for P in "${PROJECTS[@]}"
do

    DIR="$NMESH_HOME/src/projects/$P"

    if [ -d "$DIR" ]; then

        printf "[OK] %-20s %s\n" "$P" "$DIR"

    else

        printf "[MISSING] %-15s %s\n" "$P" "$DIR"

        MISSING_PROJECTS=1

    fi

done


if [ "$MISSING_PROJECTS" -ne 0 ]; then

    echo
    echo "ERROR: One or more required Nmesh project directories are missing."

    return 1 2>/dev/null || exit 1
fi


echo
echo "[OK] Required Nmesh project directories are present."


# ==============================================================================
# 7. REQUIRED LIBRARY / DEPENDENCY CHECKS
# ==============================================================================

echo
echo "======================================================================"
echo "7. LIBRARY / DEPENDENCY CHECKS"
echo "======================================================================"


# ----------------------------------------------------------------------
# GSL
# ----------------------------------------------------------------------

echo
echo "Checking GSL..."

if pkg-config --exists gsl 2>/dev/null; then
    echo "[OK] GSL found through pkg-config."
else
    echo "INFO: GSL not visible through pkg-config."
    echo "      This is not necessarily fatal if the module provides linker paths."
fi


# ----------------------------------------------------------------------
# OpenBLAS
# ----------------------------------------------------------------------

echo
echo "Checking OpenBLAS..."

OPENBLAS_FOUND="$(find \
    /opt/ohpc/pub/spack/opt/spack \
    -name 'libopenblas.so*' \
    -print -quit 2>/dev/null)"

if [ -n "$OPENBLAS_FOUND" ]; then

    echo "[OK] OpenBLAS found:"
    echo "     $OPENBLAS_FOUND"

else

    echo "WARNING: Could not locate libopenblas automatically."

fi


# ----------------------------------------------------------------------
# Check Nmesh's existing lib directory
# ----------------------------------------------------------------------

echo
echo "Current Nmesh libraries:"

if [ -d "$NMESH_HOME/lib" ]; then

    ls "$NMESH_HOME/lib"/lib*.a 2>/dev/null | sed 's/^/  /'

else

    echo "INFO: $NMESH_HOME/lib does not exist yet."
    echo "      It will normally be created during the build."

fi


# ----------------------------------------------------------------------
# Check FUKAdataReader archive if already built
# ----------------------------------------------------------------------

if [ -f "$NMESH_HOME/lib/libFUKAdataReader.a" ]; then

    echo
    echo "[OK] Existing libFUKAdataReader.a found:"
    ls -lh "$NMESH_HOME/lib/libFUKAdataReader.a"

else

    echo
    echo "INFO: libFUKAdataReader.a is not currently present."
    echo "      A clean Nmesh build should generate it."

fi


# ==============================================================================
# 8. FUKA BUILD SAFETY CHECK
# ==============================================================================

echo
echo "======================================================================"
echo "8. FUKA BUILD SAFETY CHECK"
echo "======================================================================"


# This check is IMPORTANT.
#
# FUKAdataReader/Makefile expects:
#
#       fuka/build_release/build/Makefile
#
# If that file is missing, its dependency rules can invoke:
#
#       make Get_fuka
#
# which includes operations that remove/re-create:
#
#       $(FUKADIR)/build_release/build
#
# Since the Nmesh FUKA directory is currently linked to our external FUKA
# tree, we do not want this happening unexpectedly.


if [ -f "$FUKA_BUILD_MAKEFILE" ]; then

    echo "[OK] FUKA build Makefile exists:"
    echo
    echo "     $FUKA_BUILD_MAKEFILE"

else

    echo
    echo "**********************************************************************"
    echo "WARNING: FUKA build Makefile is missing!"
    echo "**********************************************************************"
    echo
    echo "Expected:"
    echo
    echo "    $FUKA_BUILD_MAKEFILE"
    echo
    echo "DO NOT perform a full clean Nmesh rebuild until this is investigated."
    echo
    echo "The FUKAdataReader Makefile may attempt to execute Get_fuka."
    echo

    export NMESH_FUKA_REBUILD_SAFE=0

fi


if [ -f "$FUKA_BUILD_MAKEFILE" ]; then
    export NMESH_FUKA_REBUILD_SAFE=1
fi


# ==============================================================================
# 9. COMPLETE ENVIRONMENT SUMMARY
# ==============================================================================

echo
echo "======================================================================"
echo "9. ENVIRONMENT SUMMARY"
echo "======================================================================"


echo
echo "Nmesh:"
echo "    $NMESH_HOME"


echo
echo "FUKA:"
echo "    expected : $FUKA_NMESH"
echo "    resolved : $(readlink -f "$FUKA_NMESH")"


echo
echo "Kadath:"
echo "    $(readlink -f "$KADATH_LIB")"


echo
echo "FFTW:"
echo "    $FFTW_LIB"


echo
echo "Compilers:"
echo "    gcc    = $(which gcc)"
echo "    g++    = $(which g++)"
echo "    mpicc  = $(which mpicc)"
echo "    mpic++ = $(which mpic++)"


echo
echo "Important linker paths:"
echo

echo "$LIBRARY_PATH" |
    tr ':' '\n' |
    sed 's/^/    /'


echo
echo "Important runtime library paths:"
echo

echo "$LD_LIBRARY_PATH" |
    tr ':' '\n' |
    sed 's/^/    /'


echo
echo "Loaded modules:"
module list 2>&1


# ----------------------------------------------------------------------
# Save the currently working environment for future reference.
# ----------------------------------------------------------------------

ENV_RECORD="$HOME/nmesh_working_environment.txt"


{
    echo "============================================================"
    echo "NMESH WORKING ENVIRONMENT"
    echo "============================================================"

    echo
    echo "Date:"
    date

    echo
    echo "Host:"
    hostname

    echo
    echo "Nmesh:"
    echo "$NMESH_HOME"

    echo
    echo "FUKA expected:"
    echo "$FUKA_NMESH"

    echo
    echo "FUKA resolved:"
    readlink -f "$FUKA_NMESH"

    echo
    echo "Kadath:"
    readlink -f "$KADATH_LIB"

    echo
    echo "FFTW:"
    echo "$FFTW_LIB"

    echo
    echo "Compilers:"
    which gcc
    which g++
    which mpicc
    which mpic++

    echo
    echo "Versions:"
    gcc --version | head -1
    g++ --version | head -1
    mpicc --version | head -1
    mpic++ --version | head -1

    echo
    echo "Loaded modules:"
    module list 2>&1

    echo
    echo "LIBRARY_PATH:"
    echo "$LIBRARY_PATH"

    echo
    echo "LD_LIBRARY_PATH:"
    echo "$LD_LIBRARY_PATH"

} > "$ENV_RECORD"


echo
echo "[OK] Environment information saved to:"
echo
echo "     $ENV_RECORD"


# ==============================================================================
# 10. BUILD / REBUILD INSTRUCTIONS AND POST-BUILD CHECKS
# ==============================================================================

echo
echo "======================================================================"
echo "10. NMESH BUILD / REBUILD"
echo "======================================================================"

echo
echo "Environment setup is complete."
echo


# ----------------------------------------------------------------------
# Helper function: normal incremental build
# ----------------------------------------------------------------------

nmesh_build()
{

    echo
    echo "=================================================================="
    echo "NMESH INCREMENTAL BUILD"
    echo "=================================================================="
    echo

    cd "$NMESH_HOME" || return 1


    make V=1 2>&1 | tee build.log

    BUILD_STATUS=${PIPESTATUS[0]}


    echo
    echo "Build exit status: $BUILD_STATUS"


    if [ "$BUILD_STATUS" -ne 0 ]; then

        echo
        echo "NMESH BUILD FAILED"
        echo
        echo "Important errors:"
        echo "------------------------------------------------------------------"

        grep -niE \
        "cannot find|undefined reference|fatal error|No such file|collect2: error|not found" \
        build.log |
        tail -100

        return "$BUILD_STATUS"

    fi


    echo
    echo "NMESH BUILD COMPLETED."

    nmesh_check

}


# ----------------------------------------------------------------------
# Helper function: COMPLETE clean rebuild
# ----------------------------------------------------------------------

nmesh_clean_build()
{

    echo
    echo "=================================================================="
    echo "NMESH CLEAN REBUILD"
    echo "=================================================================="
    echo


    # Protect the external FUKA tree.
    if [ "$NMESH_FUKA_REBUILD_SAFE" != "1" ]; then

        echo "ERROR:"
        echo
        echo "FUKA build configuration is not considered safe."
        echo
        echo "Not running make clean / full rebuild."
        echo
        echo "Check:"
        echo
        echo "    $FUKA_BUILD_MAKEFILE"

        return 1

    fi


    cd "$NMESH_HOME" || return 1


    echo "Running:"
    echo
    echo "    make clean"
    echo

    make clean

    if [ $? -ne 0 ]; then

        echo
        echo "ERROR: make clean failed."

        return 1

    fi


    echo
    echo "Starting complete Nmesh rebuild..."
    echo


    make V=1 2>&1 | tee build_full.log

    BUILD_STATUS=${PIPESTATUS[0]}


    if [ "$BUILD_STATUS" -ne 0 ]; then

        echo
        echo "NMESH CLEAN BUILD FAILED"
        echo
        echo "Important errors:"
        echo "------------------------------------------------------------------"

        grep -niE \
        "cannot find|undefined reference|fatal error|No such file|collect2: error|not found" \
        build_full.log |
        tail -100

        return "$BUILD_STATUS"

    fi


    echo
    echo "NMESH CLEAN BUILD COMPLETED."

    nmesh_check

}


# ----------------------------------------------------------------------
# Helper function: check final executable
# ----------------------------------------------------------------------

nmesh_check()
{

    echo
    echo "=================================================================="
    echo "NMESH EXECUTABLE CHECK"
    echo "=================================================================="
    echo


    NMESH_EXE="$NMESH_HOME/exe/nmesh"


    if [ ! -x "$NMESH_EXE" ]; then

        echo "ERROR:"
        echo
        echo "Nmesh executable is missing or is not executable:"
        echo
        echo "    $NMESH_EXE"

        return 1

    fi


    echo "[OK] Nmesh executable exists:"
    echo

    ls -lh "$NMESH_EXE"


    echo
    echo "Checking dynamic libraries..."
    echo


    ldd "$NMESH_EXE" |
        grep -E "fftw|gsl|openblas|stdc\+\+|not found" || true


    echo
    echo "Checking for missing runtime libraries..."


    if ldd "$NMESH_EXE" | grep -q "not found"; then

        echo
        echo "ERROR: One or more runtime libraries are missing:"
        echo

        ldd "$NMESH_EXE" |
            grep "not found"

        return 1

    fi


    echo
    echo "=================================================================="
    echo "NMESH BUILD ENVIRONMENT IS WORKING"
    echo "=================================================================="

    return 0

}


# ==============================================================================
# FINAL MESSAGE
# ==============================================================================

echo
echo "======================================================================"
echo "NMESH ENVIRONMENT READY"
echo "======================================================================"
echo
echo "Available commands:"
echo
echo "  Normal build:"
echo
echo "      nmesh_build"
echo
echo "  Complete clean rebuild:"
echo
echo "      nmesh_clean_build"
echo
echo "  Check existing executable:"
echo
echo "      nmesh_check"
echo
echo "Nmesh directory:"
echo
echo "      $NMESH_HOME"
echo
echo "======================================================================"
