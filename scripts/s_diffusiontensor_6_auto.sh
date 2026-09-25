#!/usr/bin/env bash

# Run DTI tensor fitting and metric calculation for every preprocessed subject.

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
    tensor_file="${output_dir}/${subject_id}_dt_PA.mif"

    echo "===== Step 6: ${subject_id} ====="
    if [[ ! -f "${dwi_file}" || ! -f "${mask_file}" ]]; then
        echo "[ERROR] Missing DWI or brain mask for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi

    mkdir -p "${output_dir}"
    if ! dwi2tensor "${dwi_file}" "${tensor_file}" \
        -mask "${mask_file}" "${FORCE_ARGS[@]}" || \
        ! tensor2metric \
            -fa "${output_dir}/${subject_id}_FA_PA.mif" \
            -ad "${output_dir}/${subject_id}_AD_PA.mif" \
            -rd "${output_dir}/${subject_id}_RD_PA.mif" \
            -adc "${output_dir}/${subject_id}_MD_PA.mif" \
            -vector "${output_dir}/${subject_id}_PDD_PA.mif" \
            "${tensor_file}" "${FORCE_ARGS[@]}"; then
        echo "[ERROR] Step 6 failed for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi
    echo "===== Finished Step 6: ${subject_id} ====="
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects completed Step 6."