#!/usr/bin/env bash

# s_diffusioncsd_7.sh
# Purpose: estimate response functions (dhollander) and run MSMT-CSD
# Outputs are written to: derivatives/dticsd/<subj>/

set -euo pipefail

subj_id=${1:-sub-032301}

BASE_PREPROC=/home/brain/dti_research/preproc
SUB_PREPROC=${BASE_PREPROC}/${subj_id}

# Use subject-specific preproc folder if it exists, otherwise use preproc/test
if [[ -d "${SUB_PREPROC}" ]]; then
  PREPROC_DIR="${SUB_PREPROC}"
else
  PREPROC_DIR="${BASE_PREPROC}/test"
fi

echo "Using PREPROC_DIR=${PREPROC_DIR}"

# Input DWI/.mif and mask (expected names created by preproc scripts)
DWI_MIF=${PREPROC_DIR}/${subj_id}_ses-01_dir-PA_dwi_aftereddy.mif
MASK_NII=${PREPROC_DIR}/b0_1_PA_aftereddy_brain_mask.nii.gz

if [[ ! -f "${DWI_MIF}" ]]; then
  echo "ERROR: DWI file not found: ${DWI_MIF}" >&2
  exit 1
fi
if [[ ! -f "${MASK_NII}" ]]; then
  echo "ERROR: mask file not found: ${MASK_NII}" >&2
  exit 1
fi

# Optional overwrite flag: set OVERWRITE=1 to pass -force to dwi2response
OVERWRITE_FLAG=""
if [[ "${OVERWRITE:-0}" == "1" ]]; then
  OVERWRITE_FLAG="-force"
fi

# Output directory under derivatives/dticsd/<subj>
OUT_BASE=/home/brain/dti_research/derivatives/dticsd
OUT_DIR=${OUT_BASE}/${subj_id}
mkdir -p "${OUT_DIR}"

# Output filenames (subject specific) saved under OUT_DIR
RF_WM=${OUT_DIR}/RF_WM_PA_${subj_id}.txt
RF_GM=${OUT_DIR}/RF_GM_PA_${subj_id}.txt
RF_CSF=${OUT_DIR}/RF_CSF_PA_${subj_id}.txt
RF_VOXELS=${OUT_DIR}/RF_voxels_PA_${subj_id}.mif

# ================================
# Step #1: Estimate response function (dhollander method)
# ================================

printf "[%s] Running dwi2response dhollander on %s\n" "$(date '+%F %T')" "${DWI_MIF}"
dwi2response dhollander \
  ${OVERWRITE_FLAG} \
  "${DWI_MIF}" \
  "${RF_WM}" "${RF_GM}" "${RF_CSF}" \
  -mask "${MASK_NII}" \
  -voxels "${RF_VOXELS}"


# ================================
# Step #2: Estimate fiber orientation distribution (MSMT-CSD)
# ================================

printf "[%s] Running dwi2fod msmt_csd on %s\n" "$(date '+%F %T')" "${DWI_MIF}"
dwi2fod msmt_csd \
  "${DWI_MIF}" \
  "${RF_WM}" "${OUT_DIR}/WM_FOD_PA_${subj_id}.mif" \
  "${RF_GM}" "${OUT_DIR}/GM_FOD_PA_${subj_id}.mif" \
  "${RF_CSF}" "${OUT_DIR}/CSF_FOD_PA_${subj_id}.mif" \
  -mask "${MASK_NII}"

printf "[%s] Done. Outputs in %s\n" "$(date '+%F %T')" "${OUT_DIR}"

