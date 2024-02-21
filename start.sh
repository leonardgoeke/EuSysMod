#!/bin/bash --login
#SBATCH --array=1,2
#SBATCH --job-name=AnyMOD
#SBATCH --output=/net/work/goeke/julia/log.%j.%a.out
#SBATCH --time=120:00:00
#SBATCH --mem-per-cpu=96G
#SBATCH --partition=smp
#SBATCH --cpus-per-task=5
#SBATCH --mail-type=FAIL,TIME_LIMIT,END
#SBATCH --mail-user=lgo@wip.tu-berlin.de

GUROBI_HOME=/afs/math/software/gurobi/9.0.2/
export GUROBI_HOME

module add gurobi/10.0.1
module add julia/1.7.3

julia run.jl $SLURM_ARRAY_TASK_ID $SLURM_CPUS_PER_TASK



