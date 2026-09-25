# Step: Change angle parameters (for test subject)
# Defaults preserve the original test-file behavior. Override these variables
# to use subject-specific or FreeSurfer-derived ROI inputs.
WM_FOD=${WM_FOD:-WM_FOD_test.mif}
WM_MASK=${WM_MASK:-WM_mask_test.mif}
SEED_IMAGE=${SEED_IMAGE:-LV1_test.mif}
OVERWRITE=${OVERWRITE:-0}
FORCE_ARGS=()
if [[ "${OVERWRITE}" == "1" ]]; then
	FORCE_ARGS=(-force)
fi

tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 10 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle10.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 20 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle20.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 30 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle30.tck "${FORCE_ARGS[@]}"
tckgen "${WM_FOD}" -algorithm iFOD2 -mask "${WM_MASK}" -seed_image "${SEED_IMAGE}" -angle 40 -maxlength 250 -select 500 -nthreads 4 CSD_Prob_500_leftV1_test_angle40.tck "${FORCE_ARGS[@]}"



