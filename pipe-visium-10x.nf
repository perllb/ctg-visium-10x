#!/usr/bin/env nextFlow

// set variables
runfolder = params.runfolder
basedir = params.basedir
metaID = params.metaid
OUTDIR = params.outdir
FQDIR = params.fqdir
IMDIR = params.imagedir
CNTDIR = params.countdir
QCDIR = params.qcdir
CTGQC = params.ctgqc
SUMDIR = params.sumdir
SLIDEREF = params.slideref

// Read and process sample sheet
sheet = file(params.sheet)

// create new file for reading into channels that provide sample info!
newsheet = file("$basedir/sample-sheet.nf.csv")
slidesheet = file("$IMDIR/slide_area.txt")

// Read and process sample sheet
all_lines = sheet.readLines()
write_b = false // if next lines has sample info
newsheet.text=""     

for ( line in all_lines ) {

    if ( write_b ) {
	newsheet.append(line + "\n")
    }
    if (line.contains("[Data]")) {
	write_b = true
    }
}

println "============================="
println ">>> visium-10x pipeline >>>"
println ""
println "> INPUT: "
println "> experiment		: $runfolder "
println "> sample-sheet		: $sheet "
println "> project-id		: $metaID "
println "> basedir		: $basedir "
println "> imagedir		: $IMDIR "
println "> slide reference      : $SLIDEREF " 
println ""
println "> OUTPUT: "
println "> output-dir		: $OUTDIR "
println "> fastq-dir		: $FQDIR "
println "> count-dir		: $CNTDIR "
println "> qc-dir		: $QCDIR "
println "> summary-dir		: $SUMDIR "
println "> ctg-qc-dir		: $CTGQC "
println "============================="

// all samplesheet info
Channel
    .fromPath(newsheet)
    .splitCsv(header:true)
    .map { row -> tuple( row.Sample_ID, row.Sample_Name, row.Sample_Project, row.Sample_ref ) }
    .tap{infoall}
    .into { srcount_csv ; fastqc_csv }

// slide area file
Channel
    .fromPath(slidesheet)
    .splitCsv(header:true)
    .map { row -> tuple( row.Lib_ID, row.Sample_Name, row.Slide, row.Area) }
    .unique()
    .tap{infoSlide}
    .set { count_slide }

println " > Samples to process: "
infoall.subscribe{ println "Info: $it" }

println " > Slide area per sample: "
infoSlide.subscribe{ println "Info Slides: $it" }

// Run mkFastq
process mkfastq {

	input:
        val sheet 

	output:
        val "x" into srcount_x
	val "x" into fqc_x
    

	"""
	
	spaceranger mkfastq \
    --id=$metaID \
    --run=$runfolder \
    --samplesheet=$sheet \
    --jobmode=local \
    --localmem=100 \
    --localcores=${task.cpus} \
    --output-dir $FQDIR 

	"""
}

process count {

	publishDir "${CNTDIR}", mode: "move", overwrite: true
	tag "$sid"

	input: 
	val x from  srcount_x
        set sid, sname, projid, ref, name, slide, area from srcount_csv.join(count_slide)

	output:
        file "${sname}/outs/" into samplename
	val projid into md5_count 

	"""
        if [ $ref == "Human" ] || [ $ref == "human" ]
        then
            genome="/projects/fs1/shared/references/hg38/cellranger/refdata-gex-GRCh38-2020-A"
        elif [ $ref == "mouse" ] || [ $ref == "Mouse" ]
        then
            genome="/projects/fs1/shared/references/mm10/cellranger/refdata-gex-mm10-2020-A"
        elif [ $ref == "custom"  ] || [ $ref == "Custom" ] 
        then
            genome=${params.custom_genome}
        else
            echo ">SPECIES NOT RECOGNIZED!"
            genome="ERR"
        fi

	 spaceranger count \
             --id=${sname} \
             --fastqs=${FQDIR}/$projid/$sid/ \
	     --project=$projid \
             --sample=$sname \
             --image=${IMDIR}/rotated/${sname}.tif \
             --slidefile=${SLIDEREF}/${slide}.gpr \
             --slide=$slide \
             --area=$area \
             --transcriptome=\$genome \
             --localcores=${task.cpus} --localmem=130


        mkdir -p ${SUMDIR}
        mkdir -p ${SUMDIR}/cloupe
        mkdir -p ${SUMDIR}/web-summaries

	mkdir -p ${CTGQC}/${projid}
	mkdir -p ${CTGQC}/${projid}/web-summaries

	## Copy to delivery folder 
        cp ${sname}/outs/web_summary.html ${SUMDIR}/web-summaries/${sname}.web_summary.html
        cp ${sname}/outs/cloupe.cloupe ${SUMDIR}/cloupe/${sname}_cloupe.cloupe

	## Copy to CTG QC dir 
        cp ${sname}/outs/web_summary.html ${CTGQC}/${projid}/web-summaries/${sname}.web_summary.html


	"""

}

process fastqc {

	tag "$sid" 

	input:
	val x from fqc_x
	set sid, sname, projid, ref from fastqc_csv	
        
        output:
        val projid into mqc_cha

	"""

        mkdir -p ${QCDIR}
        mkdir -p ${QCDIR}/fastqc

        for file in ${FQDIR}/$projid/$sid/*fastq.gz
            do fastqc \$file --outdir=${QCDIR}/fastqc
        done
	"""
    
}

process multiqc {

    input:
    val projid from mqc_cha.unique()

    output:
    val "x" into multiqc_outch
    val projid into md5_qc

    script:
    """
    cd $OUTDIR
    multiqc . --outdir ${QCDIR}/ -n ${projid}_multiqc_report.html

    mkdir -p ${CTGQC}/$projid/
    cp -r ${QCDIR}/ ${CTGQC}/$projid/

    """
}

process md5sum {

    tag "${projid}"

    input:
    set projid, projid2 from md5_qc.unique().phase(md5_count.unique()) 

    output:
    val "done" into donech

    """
    cd ${OUTDIR} 
    find -type f -exec md5sum '{}' \\; > ctg-md5.${projid}.txt
    """ 

}
