module load apptainer

#assuming working directory is jobs folder
MAG_CONTAINERS=../../mag_containers/

cd $MAG_CONTAINERS
apptainer pull quast-5.0.2.sif https://depot.galaxyproject.org/singularity/quast:5.0.2--py37pl526hb5aa323_2
