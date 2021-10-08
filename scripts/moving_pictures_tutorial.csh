#!/bin/sh
#
##SBATCH --job-name=moving_pictures
#SBATCH --time=72:00:00
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=1
#SBATCH --partition=shared


#load qiime module
module load qiime2/2018.8

export TMPDIR='/scratch/users/t-sprehei1@jhu.edu/tmp'

OUTPUT="qiime2-moving-pictures-tutorial"

echo "Beginning QIIME"
date

mkdir $OUTPUT

echo "Getting data"
date 

wget \
  -O "${OUTPUT}/sample-metadata.tsv" \
  "https://data.qiime2.org/2018.8/tutorials/moving-pictures/sample_metadata.tsv"
mkdir ${OUTPUT}/emp-single-end-sequences
wget \
  -O "${OUTPUT}/emp-single-end-sequences/barcodes.fastq.gz" \
  "https://data.qiime2.org/2018.8/tutorials/moving-pictures/emp-single-end-sequences/barcodes.fastq.gz"
wget \
  -O "${OUTPUT}/emp-single-end-sequences/sequences.fastq.gz" \
  "https://data.qiime2.org/2018.8/tutorials/moving-pictures/emp-single-end-sequences/sequences.fastq.gz"

echo "Importing data"
date

qiime tools import \
  --type EMPSingleEndSequences \
  --input-path $OUTPUT/emp-single-end-sequences \
  --output-path $OUTPUT/emp-single-end-sequences.qza

echo "Demuxing"
date

qiime demux emp-single \
  --i-seqs ${OUTPUT}/emp-single-end-sequences.qza \
  --m-barcodes-file ${OUTPUT}/sample-metadata.tsv \
  --m-barcodes-column BarcodeSequence \
  --o-per-sample-sequences ${OUTPUT}/demux.qza

qiime demux summarize \
  --i-data ${OUTPUT}/demux.qza \
  --o-visualization ${OUTPUT}/demux.qzv

echo "Starting DADA2"
date

qiime dada2 denoise-single \
  --i-demultiplexed-seqs ${OUTPUT}/demux.qza \
  --p-trim-left 0 \
  --p-trunc-len 120 \
  --o-representative-sequences ${OUTPUT}/rep-seqs-dada2.qza \
  --o-table ${OUTPUT}/table-dada2.qza \
  --o-denoising-stats ${OUTPUT}/stats-dada2.qza
qiime metadata tabulate \
  --m-input-file ${OUTPUT}/stats-dada2.qza \
  --o-visualization ${OUTPUT}/stats-dada2.qzv
mv rep-seqs-dada2.qza ${OUTPUT}/rep-seqs.qza
mv table-dada2.qza ${OUTPUT}/table.qza
qiime feature-table summarize \
  --i-table ${OUTPUT}/table.qza \
  --o-visualization ${OUTPUT}/table.qzv \
  --m-sample-metadata-file ${OUTPUT}/sample-metadata.tsv
qiime feature-table tabulate-seqs \
  --i-data ${OUTPUT}/rep-seqs.qza \
  --o-visualization ${OUTPUT}/rep-seqs.qzv

echo "Starting phylogenetic and diversity analysis"
date

qiime phylogeny align-to-tree-mafft-fasttree \
  --i-sequences ${OUTPUT}/rep-seqs.qza \
  --o-alignment ${OUTPUT}/aligned-rep-seqs.qza \
  --o-masked-alignment ${OUTPUT}/masked-aligned-rep-seqs.qza \
  --o-tree ${OUTPUT}/unrooted-tree.qza \
  --o-rooted-tree ${OUTPUT}/rooted-tree.qza
qiime diversity core-metrics-phylogenetic \
  --i-phylogeny ${OUTPUT}/rooted-tree.qza \
  --i-table ${OUTPUT}/table.qza \
  --p-sampling-depth 1109 \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --output-dir ${OUTPUT}/core-metrics-results
qiime diversity alpha-group-significance \
  --i-alpha-diversity ${OUTPUT}/core-metrics-results/faith_pd_vector.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --o-visualization ${OUTPUT}/core-metrics-results/faith-pd-group-significance.qzv

qiime diversity alpha-group-significance \
  --i-alpha-diversity ${OUTPUT}/core-metrics-results/evenness_vector.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --o-visualization ${OUTPUT}/core-metrics-results/evenness-group-significance.qzv
qiime diversity beta-group-significance \
  --i-distance-matrix ${OUTPUT}/core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --m-metadata-column BodySite \
  --o-visualization ${OUTPUT}/core-metrics-results/unweighted-unifrac-body-site-significance.qzv \
  --p-pairwise

qiime diversity beta-group-significance \
  --i-distance-matrix ${OUTPUT}/core-metrics-results/unweighted_unifrac_distance_matrix.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --m-metadata-column Subject \
  --o-visualization ${OUTPUT}/core-metrics-results/unweighted-unifrac-subject-group-significance.qzv \
  --p-pairwise

echo "Making emperor plots"
date

qiime emperor plot \
  --i-pcoa ${OUTPUT}/core-metrics-results/unweighted_unifrac_pcoa_results.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --p-custom-axes DaysSinceExperimentStart \
  --o-visualization ${OUTPUT}/core-metrics-results/unweighted-unifrac-emperor-DaysSinceExperimentStart.qzv

qiime emperor plot \
  --i-pcoa ${OUTPUT}/core-metrics-results/bray_curtis_pcoa_results.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --p-custom-axes DaysSinceExperimentStart \
  --o-visualization ${OUTPUT}/core-metrics-results/bray-curtis-emperor-DaysSinceExperimentStart.qzv

echo "Rarefaction analysis"
date

qiime diversity alpha-rarefaction \
  --i-table ${OUTPUT}/table.qza \
  --i-phylogeny ${OUTPUT}/rooted-tree.qza \
  --p-max-depth 4000 \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --o-visualization ${OUTPUT}/alpha-rarefaction.qzv

echo "Starting taxonomic classification"
date

wget \
  -O "${OUTPUT}/gg-13-8-99-515-806-nb-classifier.qza" \
  "https://data.qiime2.org/2018.8/common/gg-13-8-99-515-806-nb-classifier.qza"
qiime feature-classifier classify-sklearn \
  --i-classifier ${OUTPUT}/gg-13-8-99-515-806-nb-classifier.qza \
  --i-reads ${OUTPUT}/rep-seqs.qza \
  --o-classification ${OUTPUT}/taxonomy.qza

qiime metadata tabulate \
  --m-input-file ${OUTPUT}/taxonomy.qza \
  --o-visualization ${OUTPUT}/taxonomy.qzv
qiime taxa barplot \
  --i-table ${OUTPUT}/table.qza \
  --i-taxonomy ${OUTPUT}/taxonomy.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --o-visualization ${OUTPUT}/taxa-bar-plots.qzv

echo "Begin ANCOM analysis"
date

qiime feature-table filter-samples \
  --i-table ${OUTPUT}/table.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --p-where "BodySite='gut'" \
  --o-filtered-table ${OUTPUT}/gut-table.qza
qiime composition add-pseudocount \
  --i-table ${OUTPUT}/gut-table.qza \
  --o-composition-table ${OUTPUT}/comp-gut-table.qza
qiime composition ancom \
  --i-table ${OUTPUT}/comp-gut-table.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --m-metadata-column Subject \
  --o-visualization ${OUTPUT}/ancom-Subject.qzv
qiime taxa collapse \
  --i-table ${OUTPUT}/gut-table.qza \
  --i-taxonomy ${OUTPUT}/taxonomy.qza \
  --p-level 6 \
  --o-collapsed-table ${OUTPUT}/gut-table-l6.qza

qiime composition add-pseudocount \
  --i-table ${OUTPUT}/gut-table-l6.qza \
  --o-composition-table ${OUTPUT}/comp-gut-table-l6.qza

qiime composition ancom \
  --i-table ${OUTPUT}/comp-gut-table-l6.qza \
  --m-metadata-file ${OUTPUT}/sample-metadata.tsv \
  --m-metadata-column Subject \
  --o-visualization ${OUTPUT}/l6-ancom-Subject.qzv

echo "Complete"
date

