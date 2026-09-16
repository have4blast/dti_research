#!/usr/bin/env bash

set -euo pipefail

# ======================================
# Subject settings
# ======================================

SUBJECT_ID=${1:-sub-032301}
SESSION_ID="ses-01"

PREPROC_DIR="/home/brain/dti_research/preproc"
DERIV_DIR="/home/brain/dti_research/derivatives/dticsd"

# FreeSurfer
export FREESURFER_HOME=/usr/local/freesurfer/8.2.0

set +u
source $FREESURFER_HOME/FreeSurferEnv.sh
set -u

export SUBJECTS_DIR=/home/brain/dti_research/freesurfer_subjects

mkdir -p "${DERIV_DIR}/${SUBJECT_ID}"
cd "${DERIV_DIR}/${SUBJECT_ID}"

echo "======================================="
echo "Running FreeSurfer 5TT generation"
echo "Subject: ${SUBJECT_ID}"
echo "======================================="

# ======================================
# Input files
# ======================================

FS_SUBJECT="${SUBJECTS_DIR}/${SUBJECT_ID}"

TRANSFORM_FILE="${PREPROC_DIR}/${SUBJECT_ID}/anat2dwialign_mrtrix.txt"

DWI_TEMPLATE="${PREPROC_DIR}/${SUBJECT_ID}/b0_1_PA_aftereddy_brain.nii.gz"

# ======================================
# Check inputs
# ======================================

if [ ! -d "${FS_SUBJECT}" ]; then
    echo "[ERROR] FreeSurfer subject not found:"
    echo "${FS_SUBJECT}"
    exit 1
fi

if [ ! -f "${FS_SUBJECT}/mri/aparc+aseg.mgz" ]; then
    echo "[ERROR] FreeSurfer reconstruction incomplete:"
    echo "${FS_SUBJECT}/mri/aparc+aseg.mgz"
    exit 1
fi

if [ ! -f "${TRANSFORM_FILE}" ]; then
    echo "[ERROR] Missing transform:"
    echo "${TRANSFORM_FILE}"
    exit 1
fi

if [ ! -f "${DWI_TEMPLATE}" ]; then
    echo "[ERROR] Missing DWI template:"
    echo "${DWI_TEMPLATE}"
    exit 1
fi

# ======================================
# Step 1
# Create 5TT in native T1 space
# ======================================

echo ""
echo "[Step 1/3] Creating 5TT in native T1 space"

5ttgen freesurfer \
    "${FS_SUBJECT}" \
    5TT_native.mif \
    -force

# ======================================
# Step 2
# Transform 5TT to DWI space
# ======================================

echo ""
echo "[Step 2/3] Transforming 5TT into DWI space"

mrtransform \
    5TT_native.mif \
    -linear "${TRANSFORM_FILE}" \
    -template "${DWI_TEMPLATE}" \
    5TT.mif \
    -force

# ======================================
# Step 3
# Visualization
# ======================================

echo ""
echo "[Step 3/3] Creating visualization image"

5tt2vis \
    5TT.mif \
    vis.mif \
    -force

# ======================================
# Summary
# ======================================

echo ""
echo "======================================="
echo "5TT generation complete"
echo "======================================="

echo "Native-space 5TT:"
echo "$(pwd)/5TT_native.mif"

echo ""
echo "DWI-space 5TT:"
echo "$(pwd)/5TT.mif"

echo ""
echo "Visualization:"
echo "$(pwd)/vis.mif"

echo "======================================="