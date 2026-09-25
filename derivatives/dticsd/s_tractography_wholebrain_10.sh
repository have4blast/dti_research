# Whole-brain CSD-based probabilistic anatomically constrained tractography
# Defaults preserve the original test-file behavior. Override these variables
# to use subject-specific WM FOD and FreeSurfer-derived 5TT files.
WM_FOD=${WM_FOD:-WM_FOD_test.mif}
ACT_5TT=${ACT_5TT:-}
SEED_DYNAMIC=${SEED_DYNAMIC:-${WM_FOD}}
TCK_OUTPUT=${TCK_OUTPUT:-CSD_Prob_ACT_500_test.tck}
OVERWRITE=${OVERWRITE:-0}
FORCE_ARGS=()
if [[ "${OVERWRITE}" == "1" ]]; then
    FORCE_ARGS=(-force)
fi
ACT_ARGS=()
if [[ -n "${ACT_5TT}" ]]; then
    ACT_ARGS=(-act "${ACT_5TT}")
fi

tckgen "${WM_FOD}" \
    -algorithm iFOD2 \
    "${ACT_ARGS[@]}" \
    -seed_dynamic "${SEED_DYNAMIC}" \
    -backtrack \
    -crop_at_gmwmi \
    -maxlength 250 \
    -step 0.8 \
    -select 500 \
    -nthreads 4 \
    "${TCK_OUTPUT}" "${FORCE_ARGS[@]}"

# Set ACT_5TT to a FreeSurfer- or FSL-derived 5TT.mif to enable ACT.


# tckgen WM_FOD_test.mif \
#     -algorithm iFOD2 \
#     -act 5TT_test.mif \
#     -backtrack \
#     -crop_at_gmwmi \
#     -seed_dynamic WM_FOD_test.mif \
#     -maxlength 250 \
#     -step 0.8 \
#     -select 300000 \
#     -nthreads 4 \
#     CSD_Prob_ACT_300000_test.tck



