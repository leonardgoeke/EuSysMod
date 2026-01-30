#!/bin/bash --login
#SBATCH --array=15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,42,41
#SBATCH --time=120:00:00
#SBATCH --job-name=results/mono_%j
#SBATCH --output=results/mono_%j.out
#SBATCH --error=results/mono_%j.err

module add julia/1.10.3
module add gurobi/10.0.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=32G --time=16000 --cpus-per-task=14 --ntasks-per-node=1 --wrap "julia runBenders.jl  $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK"




