#!/bin/bash

#SBATCH --array=12,13
#SBATCH --time=96:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=results/benders_%j.out
#SBATCH --error=results/benders_%j.err

module add julia/1.10.3
module add gurobi/12.0.1

sbatch --nodes=31 --ntasks=31 --mem-per-cpu=4G --time=6000 --cpus-per-task=14 --ntasks-per-node=1 --wrap "julia --heap-size-hint=54G runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"