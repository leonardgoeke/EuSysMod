#!/bin/bash

#SBATCH --array=1,2,3,4,5,6,7,8,9,10,11,12
#SBATCH --time=120:00:00
#SBATCH --mem-per-cpu=64G
#SBATCH --cpus-per-task=6
#SBATCH --job-name=durCH_%j
#SBATCH --output=results/durCH_%j.out
#SBATCH --error=results/durCH_%j.err

module add gurobi/10.0.1
module add julia/1.7.3

julia run.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK


