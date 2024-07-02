#!/bin/bash

#SBATCH --array=3,4,6,7,9,10
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=report/benders_%j.out
#SBATCH --error=report/benders_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=9 --ntasks=9 --mem-per-cpu=8G --time=4380 --cpus-per-task=4 --ntasks-per-node=1 --wrap "julia --heap-size-hint=30G runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"