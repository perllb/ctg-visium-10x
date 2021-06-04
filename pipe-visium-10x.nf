#!/usr/bin/env nextFlow

// set variables
runfolder = params.runfolder
basedir = params.basedir
metaid = params.metaid
outdir = params.outdir
fqdir = params.fqdir
imdir = params.imagedir
cntdir = params.countdir
qcdir = params.qcdir
ctgqc = params.ctgqc
sumdir = params.sumdir
slideref = params.slideref

// Read and process sample sheet
sheet = file(params.sheet)

// create new file for reading into channels that provide sample info!
newsheet = file("$basedir/sample-sheet.nf.csv")
slidesheet = file("$imdir/slide_area.txt")

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
println "> project-id		: $metaid "
println "> basedir		: $basedir "
println "> imagedir		: $imdir "
println "> slide reference      : $slideref " 
println ""
println "> OUTPUT: "
println "> output-dir		: $outdir "
println "> fastq-dir		: $fqdir "
println "> count-dir		: $cntdir "
println "> qc-dir		: $qcdir "
println "> summary-dir		: $sumdir "
println "> ctg-qc-dir		: $ctgqc "
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
    --id=$metaid \
    --run=$runfolder \
    --samplesheet=$sheet \
    --jobmode=local \
    --localmem=100 \
    --localcores=${task.cpus} \
    --output-dir $fqdir 

	"""
}

process count {

	publishDir "${cntdir}", mode: "move", overwrite: true
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
             --fastqs=${fqdir}/$projid/$sid/ \
	     --project=$projid \
             --sample=$sname \
             --image=${imdir}/rotated/${sname}.tif \
             --slidefile=${slideref}/${slide}.gpr \
             --slide=$slide \
             --area=$area \
             --transcriptome=\$genome \
             --localcores=${task.cpus} --localmem=130


        mkdir -p ${sumdir}
        mkdir -p ${sumdir}/cloupe
        mkdir -p ${sumdir}/web-summaries

	mkdir -p ${ctgqc}/${projid}
	mkdir -p ${ctgqc}/${projid}/web-summaries

	## Copy to delivery folder 
        cp ${sname}/outs/web_summary.html ${sumdir}/web-summaries/${sname}.web_summary.html
        cp ${sname}/outs/cloupe.cloupe ${sumdir}/cloupe/${sname}_cloupe.cloupe

	## Copy to CTG QC dir 
        cp ${sname}/outs/web_summary.html ${ctgqc}/${projid}/web-summaries/${sname}.web_summary.html


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

        mkdir -p ${qcdir}
        mkdir -p ${qcdir}/fastqc

        for file in ${fqdir}/$projid/$sid/*fastq.gz
            do fastqc \$file --outdir=${qcdir}/fastqc
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
    cd $outdir
    multiqc . --outdir ${qcdir}/ -n ${projid}_multiqc_report.html

    mkdir -p ${ctgqc}/$projid/
    cp -r ${qcdir}/ ${ctgqc}/$projid/

    """
}

process md5sum {

    tag "${projid}"

    input:
    set projid, projid2 from md5_qc.unique().phase(md5_count.unique()) 

    output:
    val "done" into donech

    """
    cd ${outdir} 
    find -type f -exec md5sum '{}' \\; > ctg-md5.${projid}.txt
    """ 

}
