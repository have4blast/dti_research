#!/usr/bin/env bash

# Run MSMT-CSD response estimation and FOD calculation for every subject.

set -euo pipefail

PROJECT_DIR="/home/brain/dti_research"
PREPROC_ROOT=${PREPROC_ROOT:-${PROJECT_DIR}/preproc}
DERIV_ROOT=${DERIV_ROOT:-${PROJECT_DIR}/derivatives/dticsd}
OVERWRITE=${OVERWRITE:-0}

shopt -s nullglob
subjects=("${PREPROC_ROOT}"/sub-*)
if [[ ${#subjects[@]} -eq 0 ]]; then
    echo "[ERROR] No subject directories found under ${PREPROC_ROOT}" >&2
    exit 1
fi

FORCE_ARGS=()
if [[ "${OVERWRITE}" == "1" ]]; then
    FORCE_ARGS=(-force)
fi

failed=()
for subject_path in "${subjects[@]}"; do
    [[ -d "${subject_path}" ]] || continue
    subject_id=$(basename "${subject_path}")
    output_dir="${DERIV_ROOT}/${subject_id}"
    dwi_file="${PREPROC_ROOT}/${subject_id}/${subject_id}_ses-01_dir-PA_dwi_aftereddy.mif"
    mask_file="${PREPROC_ROOT}/${subject_id}/b0_1_PA_aftereddy_brain_mask.nii.gz"
    rf_wm="${output_dir}/RF_WM_PA_${subject_id}.txt"
    rf_gm="${output_dir}/RF_GM_PA_${subject_id}.txt"
    rf_csf="${output_dir}/RF_CSF_PA_${subject_id}.txt"
    rf_voxels="${output_dir}/RF_voxels_PA_${subject_id}.mif"
    wm_fod="${output_dir}/WM_FOD_PA_${subject_id}.mif"
    gm_fod="${output_dir}/GM_FOD_PA_${subject_id}.mif"
    csf_fod="${output_dir}/CSF_FOD_PA_${subject_id}.mif"

    echo "===== Step 7: ${subject_id} ====="
    if [[ ! -f "${dwi_file}" || ! -f "${mask_file}" ]]; then
        echo "[ERROR] Missing DWI or brain mask for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi

    mkdir -p "${output_dir}"
    if ! dwi2response dhollander \
        "${dwi_file}" "${rf_wm}" "${rf_gm}" "${rf_csf}" \
        -mask "${mask_file}" -voxels "${rf_voxels}" "${FORCE_ARGS[@]}" || \
        ! dwi2fod msmt_csd \
            "${dwi_file}" \
            "${rf_wm}" "${wm_fod}" \
            "${rf_gm}" "${gm_fod}" \
            "${rf_csf}" "${csf_fod}" \
            -mask "${mask_file}" "${FORCE_ARGS[@]}"; then
        echo "[ERROR] Step 7 failed for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi
    echo "===== Finished Step 7: ${subject_id} ====="
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects completed Step 7."