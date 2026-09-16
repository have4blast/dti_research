#!/bin/bash

RAW_DIR=/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw
PREPROC_DIR=/home/brain/dti_research/preproc
# Accept subject id as first arg, default to sub-032301
subj_id=${1:-sub-032301}

# set subj_path to RAW_DIR (adjust if your raw layout is different)
subj_path=${RAW_DIR}/${subj_id}

# quick check: ensure expected fmap files exist in raw data
pa_fmap=${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-PA_epi.nii.gz
ap_fmap=${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-AP_epi.nii.gz
if [[ ! -f "${pa_fmap}" || ! -f "${ap_fmap}" ]]; then
    echo "ERROR: expected fmap files not found for ${subj_id}:" >&2
    echo "  Missing: ${pa_fmap}" >&2
    echo "  Missing: ${ap_fmap}" >&2
    exit 1
fi

echo "===== Processing ${subj_id} ====="

mkdir -p ${PREPROC_DIR}/${subj_id}
cd ${PREPROC_DIR}/${subj_id}

# ================================
# Step 1: Extract b=0 images from b=0 data
# ================================
step_start=$(date +%s)
# PA
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-PA_epi.nii.gz b0_PA_1.nii.gz 0 1
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-PA_epi.nii.gz b0_PA_2.nii.gz 1 1
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-PA_epi.nii.gz b0_PA_3.nii.gz 2 1

# AP
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-AP_epi.nii.gz b0_AP_1.nii.gz 0 1
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-AP_epi.nii.gz b0_AP_2.nii.gz 1 1
fslroi ${subj_path}/ses-01/fmap/${subj_id}_ses-01_acq-SEfmapDWI_dir-AP_epi.nii.gz b0_AP_3.nii.gz 2 1
step_end=$(date +%s)
echo "Step #1 completed in $((step_end - step_start)) sec"
echo
# ================================
# Step 2: Merge b=0 files into a single NIfTI
# ================================
step_start=$(date +%s)
fslmerge -t APPAb0_all.nii.gz \
b0_AP_1.nii.gz b0_AP_2.nii.gz b0_AP_3.nii.gz \
b0_PA_1.nii.gz b0_PA_2.nii.gz b0_PA_3.nii.gz
step_end=$(date +%s)
echo "Step #2 completed in $((step_end - step_start)) sec"
echo

# ================================
# Step 3: Run TOPUP
# ================================
echo "Running TOPUP for ${subj_id} ..."
step_start=$(date +%s)
topup --imain=APPAb0_all.nii.gz \
    --datain=${PREPROC_DIR}/acquisition_parameters.txt \
    --config=${PREPROC_DIR}/b02b0download.cnf \
    --out=topup_PA_AP_b0 \
    --fout=field \
    --iout=unwarped_images
step_end=$(date +%s)
echo "Step #3 completed in $((step_end - step_start)) sec"
echo

echo "Finished TOPUP for ${subj_id}"

