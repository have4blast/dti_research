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
# Step #2: Generate 5TT image
# The copied T1w image is an intensity image, so the FSL backend is the
# appropriate default. The FreeSurfer backend requires a FreeSurfer aseg
# parcellation image, not the subject directory or the T1w image.
# ================================
echo "[Step 2/3] Generating 5TT.mif..."

# Set TTGEN_METHOD=freesurfer to use an existing FreeSurfer subject.
TTGEN_METHOD=${TTGEN_METHOD:-fsl}

case "${TTGEN_METHOD}" in
    fsl)
        echo "Using FSL backend with T1w_in_dwi_space_highres.nii.gz."
        TTGEN_CMD=(5ttgen fsl T1w_in_dwi_space_highres.nii.gz 5TT.mif -nocleanup -force)
        ;;
    freesurfer)
        FS_ASEG=${FS_ASEG:-/home/brain/dti_research/freesurfer_subjects/${SUBJECT_ID}/mri/aseg.auto.mgz}
        DWI_TEMPLATE=${DWI_TEMPLATE:-${PREPROC_DIR}/${SUBJECT_ID}/${SUBJECT_ID}_ses-01_dir-PA_dwi_aftereddy.mif}
        T1_TO_DWI_MRTRIX=${T1_TO_DWI_MRTRIX:-${PREPROC_DIR}/${SUBJECT_ID}/anat2dwialign_mrtrix.txt}
        if [[ ! -f "${FS_ASEG}" ]]; then
            echo "[ERROR] FreeSurfer aseg image not found: ${FS_ASEG}" >&2
            exit 2
        fi
        if [[ -z "${FREESURFER_HOME:-}" ]]; then
            echo "[ERROR] FREESURFER_HOME is not set; source SetUpFreeSurfer.sh first." >&2
            exit 2
        fi
        if [[ ! -f "${DWI_TEMPLATE}" ]]; then
            echo "[ERROR] DWI template not found: ${DWI_TEMPLATE}" >&2
            exit 2
        fi
        if [[ ! -f "${T1_TO_DWI_MRTRIX}" ]]; then
            echo "[ERROR] T1-to-DWI MRtrix transform not found: ${T1_TO_DWI_MRTRIX}" >&2
            echo "Run preproc/s_T1wflirt_5.sh ${SUBJECT_ID} first, or set T1_TO_DWI_MRTRIX." >&2
            exit 2
        fi
        echo "Using FreeSurfer parcellation image: ${FS_ASEG}"
        echo "Generating native-space FreeSurfer 5TT: 5TT_native.mif"
        TTGEN_CMD=(5ttgen freesurfer "${FS_ASEG}" 5TT_native.mif -nocleanup -force)
        ;;
    *)
        echo "[ERROR] TTGEN_METHOD must be 'fsl' or 'freesurfer': ${TTGEN_METHOD}" >&2
        exit 2
        ;;
esac

echo "Running: ${TTGEN_CMD[*]}"
"${TTGEN_CMD[@]}"

if [[ "${TTGEN_METHOD}" == "freesurfer" ]]; then
    echo "Transforming FreeSurfer 5TT to DWI space with nearest-neighbour interpolation..."
    mrtransform 5TT_native.mif \
        -linear "${T1_TO_DWI_MRTRIX}" \
        -template "${DWI_TEMPLATE}" \
        -interp nearest \
        5TT.mif \
        -force
fi

# ================================
# Step #3: Convert for visualization
# ================================
echo "[Step 3/3] Converting 5TT.mif for visualization..."
5tt2vis 5TT.mif vis.mif -force

echo "======================================="
echo "5TT generation and visualization complete!"
echo "Output directory: ${DERIV_DIR}/${SUBJECT_ID}"
echo "======================================="
