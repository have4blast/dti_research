#!/bin/bash
# ================================
# Step #0: Set variables
# ================================
#!/usr/bin/env bash

# Usage: s_create5TT_8.sh [sub-XXXXXX]
# If subject id is provided, it will be used; otherwise defaults to sub-032301

set -euo pipefail

SUBJECT_ID=${1:-sub-032301}
SESSION_ID="ses-01"
PREPROC_DIR="/home/brain/dti_research/preproc"
DERIV_DIR="/home/brain/dti_research/derivatives/dticsd"

mkdir -p "${DERIV_DIR}/${SUBJECT_ID}"
cd "${DERIV_DIR}/${SUBJECT_ID}"

echo "======================================="
echo "Running 5TT generation for ${SUBJECT_ID}"
echo "======================================="

# ================================
# Step #1: Copy T1w in diffusion space
# ================================
echo "[Step 1/3] Copying T1-weighted image (in DWI space)..."
cp "${PREPROC_DIR}/${SUBJECT_ID}/T1w_in_dwi_space_highres.nii.gz" .
# If the subject-specific file does not exist, you can uncomment the fallback line below
# cp "${PREPROC_DIR}/test/T1w_in_dwi_space_highres.nii.gz" .

# ================================
# Step #2: Generate 5TT image using FreeSurfer-based segmentation (preferred)
# If FreeSurfer is not configured, set USE_FSL_FALLBACK=1 to use FSL-based 5ttgen instead.
# You can also point to a FreeSurferColorLUT.txt via FREESURFER_LUT env var.
# ================================
echo "[Step 2/3] Generating 5TT.mif..."

# Determine which backend to use for 5ttgen
USE_FSL_FALLBACK=${USE_FSL_FALLBACK:-0}
FREESURFER_LUT=${FREESURFER_LUT:-}

# if [[ -n "${FREESURFER_HOME:-}" ]]; then
#     echo "FreeSurfer detected via FREESURFER_HOME=${FREESURFER_HOME}. Using freesurfer backend."
#     TTGEN_CMD=(5ttgen freesurfer T1w_in_dwi_space_highres.nii.gz 5TT.mif -nocleanup -force)
# elif [[ -n "${FREESURFER_LUT}" && -f "${FREESURFER_LUT}" ]]; then
#     echo "FREESURFER_HOME not set, but FREESURFER_LUT provided (${FREESURFER_LUT}). Using freesurfer backend with -lut."
#     TTGEN_CMD=(5ttgen freesurfer T1w_in_dwi_space_highres.nii.gz 5TT.mif -lut "${FREESURFER_LUT}" -nocleanup -force)
# elif [[ "${USE_FSL_FALLBACK}" == "1" ]]; then
echo "FREESURFER_HOME not set. USE_FSL_FALLBACK=1 -> using FSL backend for 5ttgen."
TTGEN_CMD=(5ttgen fsl T1w_in_dwi_space_highres.nii.gz 5TT.mif -nocleanup -force)
# else
# 	echo "[ERROR] FreeSurfer not configured (FREESURFER_HOME unset) and USE_FSL_FALLBACK!=1." >&2
# 	echo "Set FREESURFER_HOME by sourcing FreeSurfer setup (e.g. source $HOME/freesurfer/SetUpFreeSurfer.sh)," >&2
# 	echo "or set USE_FSL_FALLBACK=1 to use the FSL-based 5ttgen backend, or set FREESURFER_LUT to a FreeSurferColorLUT.txt." >&2
# 	exit 2
# fi

echo "Running: ${TTGEN_CMD[*]}"
"${TTGEN_CMD[@]}"

# ================================
# Step #3: Convert for visualization
# ================================
echo "[Step 3/3] Converting 5TT.mif for visualization..."
5tt2vis 5TT.mif vis.mif -force

echo "======================================="
echo "5TT generation and visualization complete!"
echo "Output directory: ${DERIV_DIR}/${SUBJECT_ID}"
echo "======================================="
