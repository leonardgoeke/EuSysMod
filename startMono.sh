#!/bin/bash --login
#SBATCH --array=1,2,3
#SBATCH --time=120:00:00
#SBATCH --job-name=ESCU_mono_%j
#SBATCH --output=results/mono_%j.out
#SBATCH --error=results/mono_%j.err

GUROBI_HOME=/afs/math/software/gurobi/9.0.2/
export GUROBI_HOME

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=32G --time=4320 --cpus-per-task=8 --ntasks-per-node=1 --wrap "julia --heap-size-hint=60G run.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"



