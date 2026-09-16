#!/bin/bash

PREPROC_DIR=/home/brain/dti_research/preproc
RAW_DIR=/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw

# Accept subject id as first arg, default to sub-032301
subj_id=${1:-sub-032301}

# work in the subject's preproc directory
mkdir -p ${PREPROC_DIR}/${subj_id}
cd ${PREPROC_DIR}/${subj_id}

# ================================
# Step #1: Extract b=0 from preprocessed DWI data
# ================================
echo "Extracting b=0 image for registration with T1w for ${subj_id}"
fslroi ${subj_id}_ses-01_dir-PA_dwi_aftereddy.nii.gz b0_1_PA_aftereddy.nii.gz 0 1


# ================================
# Step #2: Perform BET on T1w and b=0
# ================================
echo "Running brain extraction on T1w and b0 for ${subj_id}"
bet ${RAW_DIR}/${subj_id}/ses-01/anat/${subj_id}_ses-01_acq-mp2rage_T1w.nii.gz \
    T1w_brain -f 0.3 -m
bet b0_1_PA_aftereddy.nii.gz b0_1_PA_aftereddy_brain -f 0.3 -m


# ================================
# Step #3: Perform registration from b=0 to T1w
# ================================
echo "Aligning dwi data with T1-weighted image for ${subj_id}"
epi_reg --epi=b0_1_PA_aftereddy_brain \
        --t1=${RAW_DIR}/${subj_id}/ses-01/anat/${subj_id}_ses-01_acq-mp2rage_T1w.nii.gz \
        --t1brain=T1w_brain \
        --out=dwi2anatalign


# ================================
# Step #4: Convert transformation (T1w → DWI)
# ================================
echo "Convert transformation matrix for ${subj_id}"
convert_xfm -inverse -omat anat2dwialign.mat dwi2anatalign.mat


# ================================
# Step #5: Apply the transform (FSL → MRtrix)
# ================================
echo "Perform T1w to b=0 registration (convert to MRtrix format) for ${subj_id}"
transformconvert anat2dwialign.mat \
    ${RAW_DIR}/${subj_id}/ses-01/anat/${subj_id}_ses-01_acq-mp2rage_T1w.nii.gz \
    b0_1_PA_aftereddy_brain.nii.gz flirt_import anat2dwialign_mrtrix.txt -force

mrtransform ${RAW_DIR}/${subj_id}/ses-01/anat/${subj_id}_ses-01_acq-mp2rage_T1w.nii.gz \
    -linear anat2dwialign_mrtrix.txt \
    -template b0_1_PA_aftereddy_brain.nii.gz \
    T1w_in_dwi_space_highres.nii.gz -force


# ================================
# Step #6: Convert preprocessed DWI data to MRtrix format
# ================================
echo "Convert preprocessed dMRI data from FSL to MRtrix format for ${subj_id}"
mrconvert ${subj_id}_ses-01_dir-PA_dwi_aftereddy.nii.gz \
    ${subj_id}_ses-01_dir-PA_dwi_aftereddy.mif \
    -fslgrad ${subj_id}_ses-01_dir-PA_dwi_aftereddy.eddy_rotated_bvecs \
             ${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.bval

echo "Registration and conversion completed successfully for ${subj_id}!"
