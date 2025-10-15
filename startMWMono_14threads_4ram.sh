#!/bin/bash --login
#SBATCH --array=43
#SBATCH --time=120:00:00
#SBATCH --job-name=results/mono_%j
#SBATCH --output=results/mono_%j.out
#SBATCH --error=results/mono_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=4G --time=4320 --cpus-per-task=14 --ntasks-per-node=1 --wrap "julia --heap-size-hint=54G runMW.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"



