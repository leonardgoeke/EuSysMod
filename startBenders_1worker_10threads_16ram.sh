#!/bin/bash

#SBATCH --array=13
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=results/benders_%j.out
#SBATCH --error=results/benders_%j.err

module add julia/1.10.3
module add gurobi/12.0.1

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=16G --time=4200 --cpus-per-task=10 --ntasks-per-node=1 --wrap "julia --heap-size-hint=150G runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"