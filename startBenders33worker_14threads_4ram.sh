#!/bin/bash

#SBATCH --array=50,51
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=results/benders_%j.out
#SBATCH --error=results/benders_%j.err

module add julia/1.10.3
module add gurobi/12.0.1

sbatch --nodes=33 --ntasks=33 --mem-per-cpu=4G --time=7500 --cpus-per-task=14 --ntasks-per-node=1 --wrap "julia runBenders.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"