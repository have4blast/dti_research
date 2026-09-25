#!/bin/bash
# Step: Change angle parameters
# Defaults preserve the original test-file behavior. Override these variables
# to use subject-specific or FreeSurfer-derived ROI inputs.
SUBJECT_ID=${1:-sub-032301}
DERIV_DIR="/home/brain/dti_research/derivatives/dticsd/${SUBJECT_ID}"
mkdir -p "${DERIV_DIR}"
cd "${DERIV_DIR}"

WM_FOD=${WM_FOD:-${DERIV_DIR}/WM_FOD_PA_${SUBJECT_ID}.mif}
WM_MASK=${WM_MASK:-${DERIV_DIR}/WM_mask.mif}
SEED_IMAGE=${SEED_IMAGE:-${DERIV_DIR}/seed_image.mif}
OVERWRITE=${OVERWRITE:-0}
FORCE_ARGS=()
if [[ "${OVERWRITE}" == "1" ]]; then
	FORCE_ARGS=(-force)
fi

tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 10 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle10.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 20 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle20.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 30 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle30.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 40 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle40.tck "${FORCE_ARGS[@]}"



