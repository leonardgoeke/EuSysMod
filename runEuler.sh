#!/bin/bash

#SBATCH --array=3
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=report/benders_%j.out
#SBATCH --error=report/benders_%j.err

module load gcc/6.3.0
module add julia/1.8.5
module add gurobi/10.0.1

sbatch --nodes=21 --ntasks=21 --mem-per-cpu=32G --time=600 --ntasks-per-node=1 --wrap "julia runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"