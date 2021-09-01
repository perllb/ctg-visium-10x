# ctg-visium-10x 
## Nextflow pipeline for automated spaceranger processing and QC of 10x chromium sc-visium-10x data. 

## USAGE (manual run with nextflow)
Alternative is to run with driver (see below).


1. Clone and build the Singularity container for this pipeline: (https://github.com/perllb/ctg-visium-10x/tree/main/container). 
2. Edit the nextflow.config file to fit your project and system. Set current directory as `basedir`. (from where you execute the pipeline).
3. Set up `slide_area.txt` file and prepare slide .gpr file. See below for info.
4. Edit your samplesheet to match the example samplesheet (same columns, with Sample_Species each sample edited)
5. Run pipeline 
```
nohup nextflow run pipe-visium-10x.nf > log.pipe-visium-10x.txt &
```


## Pipeline steps:

Spaceranger version: spaceranger v1.2.2

* `Demultiplexing` (spaceranger mkfastq): Converts raw basecalls to fastq, and demultiplex samples based on index (https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/using/mkfastq), and tag barcodes.
* `FastQC`: FastQC calculates quality metrics on raw sequencing reads (https://www.bioinformatics.babraham.ac.uk/projects/fastqc/). MultiQC summarizes FastQC reports into one document (https://multiqc.info/).
* `Align` + `Counts` (spaceranger count): Aligns fastq files to reference genome, generate spatial feature counts, perform secondary analysis such as clustering and generates the cloupe files (https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/using/count). Using 
* `Aggregation` (spaceranger aggr): **Not yet supported.** Automatically creates the input csv pointing to molecule_info.h5 files for each sample to be aggregated and executes aggregation (https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/using/aggregate). 
* `multiQC`: Compile fastQC and spaceranger count metrics in multiqc report
* `md5sum`: md5sum of all generated files


## Output:
* ctg-PROJ_ID-output
    * `qc`: Quality control output. 
        * cellranger metrics: Main metrics summarising the count / cell output 
        * fastqc output (https://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
        * multiqc output: Summarizing FastQC output and demultiplexing (https://multiqc.info/)
    * `fastq`: Contains raw fastq files from cellranger mkfastq.
    * `count`: Cellranger count output. Here you find gene/cell count matrices, secondary analysis output, and more. Please go to https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/using/count for more information on the output files.
    * `summaries`: 
        * web-summary files which provide an overview of essential metrics from the 10x run. 
        * cloupe files which can be used to explore the data interactively in the Loupe browser (https://support.10xgenomics.com/spatial-gene-expression/software/visualization/latest/what-is-loupe-browser)  
    * `ctg-md5.PROJ_ID.txt`: text file with md5sum recursively from output dir root    



## Input files

The following files have to be added to the runfolder for pipeline success

1. Samplesheet: `CTG_SampleSheet.visium-10x.csv` (In runfolder)
2. `slide_area.csv` (In runfolder)
3. `images` directory with tif images: (In runfolder)
4. tif images in `images` directory, with name corresponding to Sample_ID in samplesheet: images/`<sample_id>.tif`
5. slidefiles .gpr (If running offline.) (See below for file location)

### 1. Samplesheet requirements:

- The pipeline will use the input samplesheet for demultiplexing, so it must be correct!
- To extract sample ID, reference and project ID for the processes, the pipeline extracts columns after [Data] in any samplesheet. 
- For trimming of adapers, the entire IEM samplesheet can be used as input - but it is sufficient with only a [Data] row followed by the following columns:
- Add a [Header] field with ProjectID,[project-id],

| [Header] | --- | --- | --- | 
| --- | --- | --- | --- |
| ProjectID | 2021_021 | --- | --- | 
| [Data] | --- | --- | --- | 
| **Sample_ID** | **index** | **Sample_Project** | **Sample_ref** |
| Si1 | SI-GA-D9 | 2021_012 | human | 
| Si2 | SI-GA-H9 | 2021_012 | human | 
| Sample1 | SI-GA-C9 | 2021_013 | mouse |
| Sample2 | SI-GA-C9 | 2021_013 | mouse |

The nf-pipeline takes the following Columns from samplesheet to use in channels:

- Sample_ID ('Sample_Name' will be ignored)
- Index (Must use index ID, not sequence!)
- Sample_Project (Project ID)
- Sample_Species (human/mouse/custom - if custom, see below how to edit the config file)

#### Samplesheet template
```
[Header]
ProjectID,2021_021,

[Data],,,
Sample_ID,index,Sample_Project,Sample_ref
Visium_25,SI-TT-A4,2021_099,human
Visium_26,SI-TT-B4,2021_099,human
Visium_27,SI-TT-C4,2021_099,human
Visium_28,SI-TT-D4,2021_099,human
Visium_29,SI-TT-E4,2021_099,human
Visium_30,SI-TT-F4,2021_099,human
Visium_40,SI-TT-H5,2021_099,human 
```

### 2. slide_area.txt specifications

#### Slide Area specification
Spaceranger needs to know which slide and area each tissue sample is on. 

For this, the pipeline needs a .csv file (`slide_area.csv`) specifying sample ID, sample_name, slide and area, where `Lib_ID` has to match the `Sample_ID` in the samplesheet. 

| Lib_ID | Sample_Name | Slide | Area |
| --- | --- | --- | --- |
| Visium_09 | Mm926 | V10T06-109 | A1 |
| Visium_10 | Mm113 | V10T06-109 | B1 |
| Visium_14 | PO20 | V10T06-110 | B1 |
| Visium_18 | Mm935 | V10T06-030 | B1 |

#### Slide Area template
```
Lib_ID,Sample_Name,Slide,Area
Visium_25,PO7PO9,V10S21-048,A1
Visium_26,PO9PO7,V10S21-048,B1
Visium_27,PO7_2,V10S21-048,C1
Visium_28,PO13,V10S21-048,D1
Visium_29,Mm1319,V10S21-049,A1
Visium_30,Mm1369,V10S21-049,B1
Visium_31,Mm743,V10S21-049,C1
Visium_32,Mm807,V10S21-049,D1
```

### 3 + 4. Image dir with slide .tif images 

Must be in runfolder, under `images` directory
- tif-image for each sample. 
- File name must be <Sample_ID>.tif, where Sample_ID correspond to `Sample_ID` in samplesheet AND `Lib_ID` slide_area.csv.

### 5. .GPR files

- The `Slide` column values in slide_area.csv (specified above) needs a .gpr file in the visium slidefile reference. E.g. for V10T06-109 there has to exist a
corresponding V10T06-109.gpr file in the slideref dir (<slidedir>/V10T06-109.gpr)
 
Download from 10x webpage (See `Downloading a Slide File for Local Operation` @https://support.10xgenomics.com/spatial-gene-expression/software/pipelines/latest/using/count) and add to slide-ref directory. 

Slide-ref directory is specified in driver (which will be automatically defined in nextflow.config (default: /projects/fs1/shared/references/visium/slidefiles/). 

(The Slide .gpr will normally be downloaded by spaceranger in runtime if run in environment with network connection - but this pipeline is designed to run offline.)
 

##  USAGE with driver 
For automated execution of pipeline.

- Must be started from within runfolder root directory.
- Needs:
 1. Runfolder (from where it is started)
 2. Samplesheet (with format as specified in ***Samplesheet requirements*** below). If not specified, will take `runfolder/CTG_SampleSheet.csv` from runfolder if it exists.
 3. Imagedir. If not specified, will take `runfolder/images` from runfolder if it exists. See `Image dir specifications` below.
 4. Slide files in reference directory. See `Slide file specifications` below. 

```
Usage: visium-10x [ -m META_ID ] [ -s SAMPLESHEET ] [ -f IMAGE-DIR ] [ -a SLIDE-REF ] [ -i INDEX-TYPE] [ -b BCL2FASTQ-ARG ] [ -r RESUME ] [ -c CUSTOM-GENOME ]  [ -d DEMUX-OFF ] [ -n DRY-RUN ] [ -h HELP ] 

Optional arguments: 
META-ID           -m : Set 'meta-id' for run-analysis (e.g. 210330-10x). Default: Takes date of runfolder + run ID in runfolder name and adds visium-10x as suffix. E.g. '210330_A00681_0334_AHWFKTDMXX' becomes 210330_0334-visium-10x 
SAMPLESHEET       -s : Set samplesheet used for run (Default: runfolder/CTG_SampleSheet.csv) 
IMAGE-DIR         -f : Image-dir with TIFS (names as SampleID) and Slide-Area csv (slide_area.csv) (default: <runfolder>/images)
SLIDE-REF         -a : Specify path to directory containing the .gpr slide files (default: /projects/fs1/shared/references/visium/slidefiles/)
INDEX-TYPE        -i : Set -a if change to single index. (Default: dual) 
BCL2FASTQ-ARG     -b : String with bcl2fastq argument for demux. e.g. '--use-bases-mask=Y28n*,I6n*,N10,Y90n*
CUSTOM-GENOME     -c : Path to custom reference genome if needed. Skip if human/mouse defined in samplesheet 
RESUME            -r : Set if to resume nf-pipeline
DEMUX-OFF         -d : Set flag to skip mkfastq (then fastq must be in FQDIR) 
DRY-RUN           -n : Set -n if you only want to create pipeline directory structure, copy all files to ctg-projects, but not start pipeline. Good if you want to modify config etc manually for this project before starting nextflow.
HELP              -h : print help message
 
```

***Run driver with default settings***
This requires the current files and directories to be in correct name and location:
- `CTG_SampleSheet.csv` in runfolder
- `images` directory in runfolder. Contain .tif images and slide_area.csv file.
- `slide .gpr` in slide-reference directory (default slide-reference dir:/projects/fs1/shared/references/visium/slidefiles/ - the defaults can be edited in driver script)

```
cd runfolder 
visium-10x-driver
```

***Run driver with non-default imagedir location***
```
cd runfolder 
visium-10x-driver -f /path/to/imagedir
```

## Functions of visium-10x-driver
1. Creates project folder, containing:
   - nextflow.config (copied from visium-10x pipe dir, and edited based on default driver params and user-specified parameters)
   - pipe-visium-10x.nf (copied from visium-10x pipe dir)
   - samplesheet (copied from the one specified in driver)
   - images (imagedir copied from the one specified in driver)
2. Creates pipeline output directory
   - default is specified in driver script (/projets/fs1/nas-sync/ctg-delivery/visium-10x/<metaid>)
3. Creates QC log output directory
   - in which qc output of pipeline is copied 
4. Checks if .gpr files exists for all slides specified in slide_area.csv.
5. Starts pipe-visium-10x



## Container
- `ctg-visium-10x`: For 10x visium-seq. Based on spaceranger v.1.2.2
https://github.com/perllb/ctg-visium-10x/tree/main/container

### Build containers from recipes

NOTE: Environment.yml file has to be in current working directory
```
sudo -E singularity build singularity-spaceranger-1.2.2.sif singularity-spaceranger-1.2.2-buildewr
```
Add path to .sif in nextflow.config


### Run command with container
```
singularity exec --bind /fs1 singularity-spaceranger-1.2.2.sif spaceranger count (..arguments..)
```

## Custom genome 

If custom genome (not hg38 or mm10) is used

1. Set "Sample_Species" column to 'custom' in samplesheet:

Example:
 | Sample_ID | Sample_Name | index | Sample_Project | Sample_Species | 
 | --- | --- | --- | --- | --- | 
 | Si1 | Sn1 | SI-GA-D9 | proj_2021_012 | **custom** | 
 | Si2 | Sn2 | SI-GA-H9 | proj_2021_012 | **custom** | 
 
 2. In nextflow.config, set 
 `custom_genome=/PATH/TO/CUSTOMGENOME`
 
### Add custom genes (e.g. reporters) to cellranger annotation

Use the `ctg-cellranger-add2ref` script. 

https://github.com/perllb/ctg-cellranger-add2ref


