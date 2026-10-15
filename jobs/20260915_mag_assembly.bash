#!/bin/bash

#SBATCH --job-name=nfmag_RUN_NAME
#SBATCH --account=def-jstinchc
#IGNORE --nodes=1
#IGNORE --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mail-user=damian.hernandez@utoronto.ca
#SBATCH --mail-type=ALL
#SBATCH --mem=4G
#SBATCH --time=48:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

### LOAD COMPUTATIONAL ENVIRONMENT ###
module load StdEnv/2023
module load apptainer/1.4.5
module load java/25.36
module load nextflow/26.04.4

### INITIALIZE VARIABLES ###
PROJECTDIR=/home/herna499/scratch/mag_assembly/ #your working directory
SAMPLESHEET=${PROJECTDIR}/metadata/samplesheet.csv
DATABASEPATH=/home/herna499/scratch/mag_dbs
DB_APPTAINER=/home/herna499/scratch/mag_dbs/busco.sif
OUTDIR=${PROJECTDIR}/out #where to store output of run
MAX_CPU=12 #maximum number of CPUs you want to give to nextflow
MAX_MEM='600GB' #maximum RAM you want to give to nextflow
SLURM_PROFILE=def-jstinchc #the SLURM account for "billing"
PARAM_FILE=config.params #parameter file for specifying parameters that are not nextflow defaults

### TROUBLESHOOTING AND NOTES ###
#include the file paths to your files in the initialize environment section
#modify --job-name with run name
#bump --mem if jobs OOM - mag's assembly steps (SPAdes/MEGAHIT, MetaBAT2) can need way more depending on data size
#bump up --time if you run out of time
#if you have pre-built assemblies, you can add `--assembly_input` to the run command. More information available in `pre-computed-assembly-option.txt`
#fastq files must be compressed as `.fastq.gz` or `.fq.gz`
#the samplesheet must be a csv file with a .csv suffix
#if you do not have a database path to include, you should download the database. nf-core/mag can download these databases in the run, but it's best to have a static image in your HPC for reproducibility.
#uncomment out `-resume` in run command if picking up from a failed run

### SAMPLESHEET DESCRIPTION ####
##header descriptions
#sample (text): sample name
#group (integer): the group within which to compute co-abundances for the binning step. Basically, assembly is still being done per sample, but the co-abundances used for the binning when mapping reads to pooled contigs
#short_reads_1 (path): path to forward reads
#short_reads_2 (path): path to reverse reads
#long_reads (path): path to long reads
#short_reads_platform (text): one of ILLUMINA, BGISEQ, LS454, ION_TORRENT, DNBSEQ, ELEMENT, ULTIMA, VELA_DIAGNOSTICS, GENAPSYS, GENEMIND, TAPESTRI
#long_reads_platform (text): one of OXFORD_NANOPORE, OXFORD_NANOPORE_HQ, PACBIO_CLR, PACBIO_HIFI

##short-reads only
#required headers are: sample,group,short_reads_1,short_reads_2,long_reads,short_reads_platform
#short_reads_2 and long_reads are optional and can be left as empty columns.

##long-reads only
#required headers are: sample,run,group,long_reads,long_reads_platform

##mixed read types
#required headers are: sample,group,short_reads_1,short_reads_2,long_reads,short_reads_platform,long_reads_platform

##if samples are split across runs
#add a `run` column after the `sample` column. Run IDs must be unique within a multi-run sample.
#A sample with multiple runs will be automatically concatenated.

### PREPARING DATABASES ###

#uncomment and run if you have not downloaded the databases or if you want to download updated versions
#note, I was having issues using busco to download the dataset. I would recommend trying the below for you, but if you are also having download issues, then use the busco download script.
#apptainer exec $DB_APPTAINER busco --download prokaryota --download_path ${DATABASEPATH}/busco_db
#wget --no-check-certificate -P ${DATABASEPATH} https://tbb.bio.uu.nl/tina/CAT_pack_prepare/20241212_CAT_nr.tar.gz
#wget -P ${DATABASEPATH} https://data.gtdb.aau.ecogenomic.org/releases/release232/232.0/auxillary_files/gtdbtk_package/full_package/gtdbtk_r232_data.tar.gz

### CREATE LOCAL CACHE AND PIPELINE LOGS ###
#uncomment if you have not made your project directory
# cd $PROJECTDIR

export APPTAINER_CACHEDIR="$PWD/.apptainer_cache"
export NXF_HOME="$PWD/.nextflow"

# Strictly required so the alliance profile knows which account to bill sub-jobs to
export SLURM_ACCOUNT=$SLURM_PROFILE

# Heavily recommended: Cache Apptainer containers in project storage, NOT your home directory
export NXF_SINGULARITY_CACHEDIR=${PROJECTDIR}/nxf_cache

mkdir -p logs "$APPTAINER_CACHEDIR" "$NXF_HOME"

### RUN ASSEMBLY ###
# Only allocates resources for the Nextflow orchestrator with just 
# "-profile apptainer". All pipeline steps run locally inside this one 
# job's N cores/N GB in that configuration. If you want each step to get
# its own SLURM job instead, use "-profile slurm,apptainer" + a 
# nextflow.config with SLURM executor settings.
# You can alternatively use a params file to specify all of this.
# For reproducibility, I am specifying the nf-core/mag version.
# You can resume a stalled run by appending `-resume` to the command.
# Alliance Canada has a Nextflow setup which coordinates jobs to run in parallel
# which is why my `-profile` argument is alliance_canada.

# Soil samples are pretty bad for using up a lot of RAM. We can try doing assembly
# within samples and binning within group later. A disadvantage of doing this is
# that you can lose rare microbes since the assembly algorithms use the high depth
# coverage from pooling groups for assembly to statistically believe the rare microbe
# contigs are real. But, if you have really diverse samples and a lot of samples, you
# might just not be able to realistically run the analysis.

nextflow run nf-core/mag \
	-r 5.5.0 \
	-profile alliance_canada \
	--input $SAMPLESHEET \
	--bbnorm \
	--bnorm_target 100 \
	--bbnorm_min 5 \
	--save_bbnorm_reads \
    --busco_db ${DATABASEPATH}/busco_db \
    --busco_db_lineage auto_prok \
    --cat_db ${DATABASEPATH}/20241212_CAT_nr.tar.gz \
    --gtdb_db ${DATABASEPATH}/release232 \
	--max_cpus $MAX_CPU \
	--max_memory $MAX_MEM \
	--outdir $OUTDIR \
	-c $PARAM_FILE \
	-resume

# Docs:
#   nf-core/mag pipeline: https://nf-co.re/mag
#   nf-core/mag GitHub:   https://github.com/nf-core/mag
#   Nextflow docs:        https://www.nextflow.io/docs/latest/index.html
#   Nextflow GitHub:      https://github.com/nextflow-io/nextflow

