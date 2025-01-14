workflow prodigal {

  File imgap_input_fasta
  String imgap_project_id
  String imgap_project_type
  String container

  if(imgap_project_type == "isolate") {
    call fasta_len {
      input:
        input_fasta = imgap_input_fasta
    }
  }
  Int word_count = select_first([fasta_len.wc, 0])
  if(imgap_project_type == "isolate" && word_count >= 20000) {
    call iso_big {
      input:
        input_fasta = imgap_input_fasta,
        project_id = imgap_project_id,
        container=container
    }
  }
  if(imgap_project_type == "isolate" && word_count < 20000) {
    call iso_small {
      input:
        input_fasta = imgap_input_fasta,
        project_id = imgap_project_id,
        container=container
    }
  }
  if(imgap_project_type == "metagenome") {
    call metag {
      input:
        input_fasta = imgap_input_fasta,
        project_id = imgap_project_id,
        container=container
    }
  }

  call clean_and_unify {
    input:
      iso_big_proteins_fasta = iso_big.proteins,
      iso_small_proteins_fasta = iso_small.proteins,
      meta_proteins_fasta = metag.proteins,
      iso_big_genes_fasta = iso_big.genes,
      iso_small_genes_fasta = iso_small.genes,
      meta_genes_fasta = metag.genes,
      iso_big_gff = iso_big.gff,
      iso_small_gff = iso_small.gff,
      meta_gff = metag.gff,
      project_id = imgap_project_id,
      container=container
  }

  output {
    File gff = clean_and_unify.gff
    File genes = clean_and_unify.genes
    File proteins = clean_and_unify.proteins
  }
}

task fasta_len {

  File input_fasta

  command {
    grep -v '^>' ${input_fasta} | wc -m
  }

  runtime {
    cpu: 1
    time: "1:00:00"
    memory: "86G"
  }

  output {
    Int wc = select_first([read_int(stdout()),0])
  }
}

task iso_big {

  String bin="/opt/omics/bin/prodigal"
  File   input_fasta
  Int    translation_table = 11
  String project_id
  File   train = "${project_id}_prodigal.trn"
  String container

  command {
    set -euo pipefail
    ${bin} -i ${input_fasta} -t ${train} -g ${translation_table} -q
    ${bin} -f gff -g ${translation_table} -p single -m -i ${input_fasta} \
    -t ${train} -o ${project_id}_prodigal.gff \
    -d ${project_id}_prodigal_genes.fna -a ${project_id}_prodigal_proteins.faa
  }

  runtime {
    cpu: 1
    time: "1:00:00"
    memory: "86G"
    docker: container
  }

  output {
    File gff = "${project_id}_prodigal.gff"
    File genes = "${project_id}_prodigal_genes.fna"
    File proteins = "${project_id}_prodigal_proteins.faa"
  }
}

task iso_small {

  String bin="/opt/omics/bin/prodigal"
  File   input_fasta
  String project_id
  String container

  command {
    ${bin} -f gff -p meta -m -i ${input_fasta} \
    -o ${project_id}_prodigal.gff -d ${project_id}_prodigal_genes.fna \
    -a ${project_id}_prodigal_proteins.faa
  }

  runtime {
    cpu: 1
    time: "1:00:00"
    memory: "86G"
    docker: container
  }

  output {
    File gff = "${project_id}_prodigal.gff"
    File genes = "${project_id}_prodigal_genes.fna"
    File proteins = "${project_id}_prodigal_proteins.faa"
  }
}

task metag {

  String bin="/opt/omics/bin/prodigal"
  File   input_fasta
  String project_id
  String container

  command {
    ${bin} -f gff -p meta -m -i ${input_fasta} \
    -o ${project_id}_prodigal.gff -d ${project_id}_prodigal_genes.fna \
    -a ${project_id}_prodigal_proteins.faa
  }

  runtime {
    cpu: 1
    time: "1:00:00"
    memory: "86G"
    docker: container
  }

  output {
    File gff = "${project_id}_prodigal.gff"
    File genes = "${project_id}_prodigal_genes.fna"
    File proteins = "${project_id}_prodigal_proteins.faa"
  }
}

task clean_and_unify {

  File?  iso_big_proteins_fasta
  File?  iso_small_proteins_fasta
  File?  meta_proteins_fasta
  File?  iso_big_genes_fasta
  File?  iso_small_genes_fasta
  File?  meta_genes_fasta
  File?  iso_big_gff
  File?  iso_small_gff
  File?  meta_gff
  String unify_bin="/opt/omics/bin/structural_annotation/unify_gene_ids.py"
  String project_id
  String container

  command {
    sed -i 's/\*$//g' ${iso_big_proteins_fasta} ${iso_small_proteins_fasta} ${meta_proteins_fasta}
    sed -i 's/\*/X/g' ${iso_big_proteins_fasta} ${iso_small_proteins_fasta} ${meta_proteins_fasta}
    ${unify_bin} ${iso_big_gff} ${iso_small_gff} ${meta_gff} \
                 ${iso_big_genes_fasta} ${iso_small_genes_fasta} ${meta_genes_fasta} \
                 ${iso_big_proteins_fasta} ${iso_small_proteins_fasta} ${meta_proteins_fasta}
    mv ${iso_big_proteins_fasta} . 2> /dev/null
    mv ${iso_small_proteins_fasta} . 2> /dev/null
    mv ${meta_proteins_fasta} . 2> /dev/null
    mv ${iso_big_genes_fasta} . 2> /dev/null
    mv ${iso_small_genes_fasta} . 2> /dev/null
    mv ${meta_genes_fasta} . 2> /dev/null
    mv ${iso_big_gff} . 2> /dev/null
    mv ${iso_small_gff} . 2> /dev/null
    mv ${meta_gff} . 2> /dev/null
  }

  runtime {
    cpu: 1
    time: "1:00:00"
    memory: "86G"
    docker: container
  }

  output {
    File gff = "${project_id}_prodigal.gff"
    File genes = "${project_id}_prodigal_genes.fna"
    File proteins = "${project_id}_prodigal_proteins.faa"
  }
}

