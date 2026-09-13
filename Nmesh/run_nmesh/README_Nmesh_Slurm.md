# Nmesh Slurm Run Guide

This README documents the reusable Slurm batch file used to run Nmesh parameter files (`.par`) on the cluster.

## 1. Main idea

Use one reusable Slurm file:

```bash
run_nmesh.slurm
```

and pass the parameter file when submitting:

```bash
sbatch --job-name=Lmax5 run_nmesh.slurm Lmax5.par
```

You do **not** need a new `.slurm` file for every `.par` file.

---

## 2. Important lines in `run_nmesh.slurm`

```bash
#SBATCH --partition=longq7
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --time=1-00:00:00

#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=YOUR_EMAIL@fau.edu
```

`%x` is the job name and `%j` is the Slurm job ID.

Example:

```bash
sbatch --job-name=Lmax5 run_nmesh.slurm Lmax5.par
```

might create:

```text
Lmax5_584321.out
Lmax5_584321.err
```

The `.out` file contains normal program output.  
The `.err` file contains stderr/error messages.

The scientific Nmesh result files are separate and are written according to the `.par` file.

---

## 3. Simplest submit commands

Normal run:

```bash
sbatch --job-name=Lmax5 run_nmesh.slurm Lmax5.par
```

Override memory:

```bash
sbatch --job-name=Lmax5 --mem=128G run_nmesh.slurm Lmax5.par
```

Override memory and time:

```bash
sbatch --job-name=Lmax5 --mem=128G --time=1-00:00:00 run_nmesh.slurm Lmax5.par
```

Large-memory example:

```bash
sbatch --job-name=Lmax6 --mem=281G --time=2-00:00:00 run_nmesh.slurm Lmax6.par
```

Command-line `sbatch` options override the defaults in the Slurm file.

---

## 4. Check jobs

```bash
squeue -u $USER
```

A more detailed view:

```bash
squeue -u $USER -o "%.18i %.20j %.10T %.10M %.10l %.6D %R"
```

Live monitoring:

```bash
watch -n 5 "squeue -u $USER"
```

---

## 5. Cancel jobs

Cancel one job:

```bash
scancel JOBID
```

Cancel all of your jobs:

```bash
scancel -u $USER
```

---

## 6. Check memory and runtime after a run

```bash
sacct -j JOBID --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS
```

Important fields:

- `Elapsed` — actual runtime
- `ReqMem` — memory requested
- `MaxRSS` — maximum memory actually used
- `State` — COMPLETED, FAILED, OUT_OF_MEMORY, CANCELLED, etc.

Use this before deciding how much RAM to request for the next run.

---

## 7. Check high-memory nodes in `longq7`

```bash
sinfo -N -p longq7 -o "%15N %10T %6c %12m %10l %30b"
```

Sort long-queue nodes by memory:

```bash
sinfo -N -p longq7 -h -o "%N %m %c %t %f" | sort -k2 -nr
```

This is useful before submitting 128 GB, 281 GB, or larger jobs.

---

## 8. Run several `.par` files

Reuse the same Slurm file:

```bash
sbatch --job-name=Lmax4 run_nmesh.slurm Lmax4.par
sbatch --job-name=Lmax5 run_nmesh.slurm Lmax5.par
sbatch --job-name=spin01 run_nmesh.slurm spin01.par
```

Each submission gets its own:

- Slurm job ID
- `.out` file
- `.err` file
- email notifications
- Nmesh result files

---

## 9. Submit every `.par` file in a directory

```bash
for p in *.par; do
    name="${p%.par}"

    sbatch         --job-name="$name"         --output="${name}_%j.out"         --error="${name}_%j.err"         run_nmesh.slurm "$p"
done
```

Use this carefully because it submits all matching `.par` files.

---

## 10. Check output while a job is running

```bash
tail -f Lmax5_JOBID.out
```

Check errors live:

```bash
tail -f Lmax5_JOBID.err
```

Press `Ctrl+C` to stop following the file.

---

## 11. Before every submission

Check the parameter file:

```bash
ls -lh filename.par
```

Check the Nmesh executable:

```bash
ls -lh ~/nmesh/exe/nmesh
```

Also remember to check:

- requested RAM
- requested walltime
- correct partition (`longq7` for long jobs)
- output paths inside the `.par` file
- available disk space
- whether another run could overwrite the same scientific output

---

## 12. Quick reference

Submit:

```bash
sbatch --job-name=NAME run_nmesh.slurm FILE.par
```

Submit with memory/time:

```bash
sbatch --job-name=NAME --mem=128G --time=1-00:00:00 run_nmesh.slurm FILE.par
```

Check:

```bash
squeue -u $USER
```

Cancel:

```bash
scancel JOBID
```

Cancel all:

```bash
scancel -u $USER
```

Check memory/runtime:

```bash
sacct -j JOBID --format=JobID,JobName,State,Elapsed,ReqMem,MaxRSS
```

Check high-memory long-queue nodes:

```bash
sinfo -N -p longq7 -h -o "%N %m %c %t %f" | sort -k2 -nr
```

## Main rule

Keep **one reusable Slurm file**. Change the `.par` file, job name, memory, and walltime at submission time instead of creating a new Slurm script for every run.
