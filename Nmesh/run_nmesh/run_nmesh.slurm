#!/bin/bash

#SBATCH --partition=longq7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8

# Default resources — can be overridden when submitting
#SBATCH --mem=128G
#SBATCH --time=1-00:00:00

# Separate output/error for every job
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

# Email notifications
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=YOUREMAIL@ADDRESS

# -------------------------------
# Parameter file
# -------------------------------

PARFILE="$1"

if [ -z "$PARFILE" ]; then
    echo "ERROR: No parameter file supplied."
    echo "Usage: sbatch --job-name=NAME run_nmesh.slurm file.par"
    exit 1
fi

if [ ! -f "$PARFILE" ]; then
    echo "ERROR: Parameter file does not exist: $PARFILE"
    exit 1
fi


# -------------------------------
# Job information
# -------------------------------

echo "=========================================="
echo "Nmesh run"
echo "=========================================="
echo "Job ID       : $SLURM_JOB_ID"
echo "Job name     : $SLURM_JOB_NAME"
echo "Parameter    : $PARFILE"
echo "Node         : $(hostname)"
echo "Start time   : $(date)"
echo "Directory    : $(pwd)"
echo "=========================================="


# -------------------------------
# Run Nmesh
# -------------------------------

~/nmesh/exe/nmesh "$PARFILE"

STATUS=$?


# -------------------------------
# Finished
# -------------------------------

echo
echo "=========================================="
echo "Nmesh finished"
echo "Parameter    : $PARFILE"
echo "Exit status  : $STATUS"
echo "End time     : $(date)"
echo "=========================================="

exit $STATUS
