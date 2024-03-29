#!/bin/bash

#SBATCH --array=1,2,3
#SBATCH --time=120:00:00
#SBATCH --mem-per-cpu=64G
#SBATCH --cpus-per-task=6
#SBATCH --job-name=durCH_%j
#SBATCH --output=results/durCH_%j.out
#SBATCH --error=results/durCH_%j.err

module load gcc/6.3.0
module add julia/1.8.5
module add gurobi/10.0.1

julia run.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK


