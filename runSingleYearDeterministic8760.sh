#!/bin/bash

#SBATCH --array=1982-2016
#SBATCH --time=120:00:00
#SBATCH --job-name=results/ESCU_SingleDeter_%j
#SBATCH --output=results/SingleDeter_%j.out
#SBATCH --error=results/SingleDeter_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=16G --time=4320 --cpus-per-task=8 --ntasks-per-node=1 --wrap "julia --heap-size-hint=120G runSingleYearDeterministic8760.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"