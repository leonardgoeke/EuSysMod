#!/bin/bash

#SBATCH --output=results/meta_%j.out
#SBATCH --error=results/meta_%j.err

sbatch startBenders_2scr_4threads_16ram.sh
sbatch startBenders_2scr_8threads_8ram.sh
sbatch startBenders_2scr_8threads_16ram.sh
sbatch startBenders_4scr_4threads_16ram.sh