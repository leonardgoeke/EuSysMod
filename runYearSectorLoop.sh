#!/bin/bash --login
#SBATCH --array=2
#SBATCH --time=120:00:00
#SBATCH --job-name=ESCU_monoEndoLoop_%j
#SBATCH --output=results/monoEndoLoop_%j.out
#SBATCH --error=results/monoEndoLoop_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=24G --time=4320 --cpus-per-task=8 --ntasks-per-node=1 --wrap "julia --heap-size-hint=120G runYearSectorLoop_1.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"
sbatch --nodes=1 --ntasks=1 --mem-per-cpu=24G --time=4320 --cpus-per-task=8 --ntasks-per-node=1 --wrap "julia --heap-size-hint=120G runYearSectorLoop_2.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"