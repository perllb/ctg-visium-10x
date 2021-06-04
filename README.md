# ctg-visium-10x 
## Nextflow pipeline for preprocessing and QC of 10x chromium sc-visium data with spaceranger. 

## USAGE

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
    * `aggregate`:
        * Output from cellranger aggregation. 
    * `ctg-md5.PROJ_ID.txt`: text file with md5sum recursively from output dir root    


## Samplesheet requirements:

The pipeline will use the input samplesheet for demultiplexing, so it should be correct!
To extract sample ID, reference and project ID for the processes, the pipeline extracts columns after [Data] in any samplesheet. 
For trimming of adapers, the entire IEM samplesheet can be used as input - but it is sufficient with only a [Data] row followed by the following columns:

 [Data]
 | Sample_ID | Sample_Name | index | Sample_Project | Sample_ref |
 | --- | --- | --- | --- | --- | 
 | Si1 | Sn1 | SI-GA-D9 | proj_2021_012 | human | 
 | Si2 | Sn2 | SI-GA-H9 | proj_2021_012 | human | 
 | Sample1 | S1 | SI-GA-C9 | proj_2021_013 | mouse |
 | Sample2 | S23 | SI-GA-C9 | proj_2021_013 | mouse |

```

The nf-pipeline takes the following Columns from samplesheet to use in channels:

- Sample_ID ('Sample_Name' will be ignored)
- Index (Must use index ID!)
- Sample_Project (Project ID)
- Sample_Species (human/mouse/custom - if custom, see below how to edit the config file)
```

## Slide Area specification
Spaceranger needs to know which slide and area each tissue sample is on. 
For this, the pipeline needs a .csv file (e.g. slide_area.txt) specifying sample ID, sample_name, slide and area, where Lib_ID has to match the Sample_ID in the samplesheet. 

| Lib_ID | Sample_Name | Slide | Area |
| --- | --- | --- | --- |
| Visium_09 | Mm926 | V10T06-109 | A1 |
| Visium_10 | Mm113 | V10T06-109 | B1 |
| Visium_14 | PO20 | V10T06-110 | B1 |
| Visium_18 | Mm935 | V10T06-030 | B1 |

## Slide File
The Slide will be downloaded by spaceranger in runtime. However, if running the pipeline on a server with no connection, the `slide` needs to match a file in the visium slidefile reference. E.g. for V10T06-109 there has to exist a corresponding V10T06-109.gpr file in the slideref dir. 

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


