#!/bin/bash --login
#SBATCH --array=16-18
#SBATCH --time=120:00:00
#SBATCH --job-name=results/mono_%j
#SBATCH --output=results/mono_%j.out
#SBATCH --error=results/mono_%j.err

module add julia/1.10.3
module add gurobi/12.0.1

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=32G --time=7200 --cpus-per-task=10 --ntasks-per-node=1 --wrap "julia runMono.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"


