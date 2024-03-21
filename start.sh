#!/bin/bash

#SBATCH --array=1,2,3,4,5,6
#SBATCH --time=120:00:00
#SBATCH --mem-per-cpu=32G
#SBATCH --cpus-per-task=8
#SBATCH --job-name=durCH1752_%j
#SBATCH --output=report/durCH1752_%j.out
#SBATCH --error=report/durCH1752_%j.err

module load gcc/6.3.0
module add julia/1.8.5
module add gurobi/10.0.1

julia run.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK


