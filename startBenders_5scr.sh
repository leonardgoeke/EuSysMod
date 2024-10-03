#!/bin/bash

#SBATCH --array=5
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=results/benders_%j.out
#SBATCH --error=results/benders_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=21 --ntasks=20 --mem-per-cpu=16G --time=6000 --cpus-per-task=4 --ntasks-per-node=1 --wrap "julia --heap-size-hint=62G runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"