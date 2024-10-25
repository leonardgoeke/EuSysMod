#!/bin/bash

#SBATCH --array=1
#SBATCH --time=120:00:00
#SBATCH --job-name=benders_%j
#SBATCH --output=output/tsr_%j.out
#SBATCH --error=output/tsr_%j.err

module add julia/1.10.3

sbatch --nodes=1 --ntasks=1 --mem-per-cpu=8G --time=4320 --cpus-per-task=4 --ntasks-per-node=1 --wrap "julia --heap-size-hint=30G convertTimeSeries.jl"