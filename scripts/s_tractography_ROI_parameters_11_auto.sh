#!/usr/bin/env bash

# Run s_tractography_ROI_parameters_11.sh for every subject under RAW_DIR.

set -euo pipefail

PROJECT_DIR="/home/brain/dti_research"
RAW_DIR=${RAW_DIR:-/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw}
SCRIPT="${PROJECT_DIR}/derivatives/dticsd/s_tractography_ROI_parameters_11.sh"
DTICSD_ROOT="${PROJECT_DIR}/derivatives/dticsd"
TRACT_ROOT="${PROJECT_DIR}/derivatives/tractography"

if [[ ! -f "${SCRIPT}" ]]; then
    echo "[ERROR] Script not found: ${SCRIPT}" >&2
    exit 1
fi

shopt -s nullglob
subjects=("${RAW_DIR}"/sub-*)
if [[ ${#subjects[@]} -eq 0 ]]; then
    echo "[ERROR] No subject directories found under ${RAW_DIR}" >&2
    exit 1
fi

failed=()
for subject_path in "${subjects[@]}"; do
    [[ -d "${subject_path}" ]] || continue
    subject_id=$(basename "${subject_path}")
    wm_fod="${DTICSD_ROOT}/${subject_id}/WM_FOD_PA_${subject_id}.mif"
    act_5tt="${DTICSD_ROOT}/${subject_id}/5TT.mif"
    tract_dir="${TRACT_ROOT}/${subject_id}"
    wm_mask="${tract_dir}/WM_mask_${subject_id}.mif"
    seed_image="${tract_dir}/WM_seed_${subject_id}.mif"

    if [[ ! -f "${wm_fod}" || ! -f "${act_5tt}" ]]; then
        echo "[ERROR] Missing WM FOD or 5TT for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi

    mkdir -p "${tract_dir}"
    echo "===== Step 11: ${subject_id} ====="
    if ! mrconvert "${act_5tt}" -coord 3 2 "${wm_mask}" -force || \
        ! mrconvert "${wm_mask}" "${seed_image}" -force || \
        ! (cd "${tract_dir}" && \
            WM_FOD="${wm_fod}" WM_MASK="${wm_mask}" SEED_IMAGE="${seed_image}" \
            OVERWRITE="${OVERWRITE:-0}" bash "${SCRIPT}"); then
        echo "[ERROR] Step 11 failed for ${subject_id}" >&2
        failed+=("${subject_id}")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects completed Step 11."