#!/bin/bash

# Accept subject id as first arg, default to sub-032301
subj_id=${1:-sub-032301}

PREPROC_DIR=/home/brain/dti_research/preproc
DERIV_DIR=/home/brain/dti_research/derivatives/dticsd

# Input files (from preproc/<subj_id>/)
input_dwi=${PREPROC_DIR}/${subj_id}/${subj_id}_ses-01_dir-PA_dwi_aftereddy.mif
mask=${PREPROC_DIR}/${subj_id}/b0_1_PA_aftereddy_brain_mask.nii.gz

# Output directory for this subject
out_dir=${DERIV_DIR}/${subj_id}
mkdir -p "${out_dir}"

# Check inputs
if [[ ! -f "${input_dwi}" ]]; then
	echo "ERROR: input DWI not found: ${input_dwi}" >&2
	exit 1
fi
if [[ ! -f "${mask}" ]]; then
	echo "ERROR: brain mask not found: ${mask}" >&2
	exit 1
fi

echo "Step #1: Perform tensor fitting for ${subj_id}"
dwi2tensor "${input_dwi}" "${out_dir}/dt_PA.mif" -mask "${mask}"

echo "Step #2: Compute tensor metrics for ${subj_id}"
tensor2metric -fa "${out_dir}/FA_PA.mif" -ad "${out_dir}/AD_PA.mif" -rd "${out_dir}/RD_PA.mif" -adc "${out_dir}/MD_PA.mif" -vector "${out_dir}/PDD_PA.mif" "${out_dir}/dt_PA.mif"
