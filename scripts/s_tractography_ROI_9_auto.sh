#!/usr/bin/env bash

# Run s_tractography_ROI_9.sh for every subject under RAW_DIR.

set -euo pipefail

PROJECT_DIR="/home/brain/dti_research"
RAW_DIR=${RAW_DIR:-/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw}
SCRIPT="${PROJECT_DIR}/derivatives/dticsd/s_tractography_ROI_9.sh"
DTICSD_ROOT="${PROJECT_DIR}/derivatives/dticsd"

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

    if [[ ! -f "${wm_fod}" || ! -f "${act_5tt}" ]]; then
        echo "[ERROR] Missing WM FOD or 5TT for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi

    echo "===== Step 9: ${subject_id} ====="
    if ! TRACT_INPUT="${wm_fod}" WM_FOD="${wm_fod}" ACT_5TT="${act_5tt}" \
        bash "${SCRIPT}" "${subject_id}"; then
        echo "[ERROR] Step 9 failed for ${subject_id}" >&2
        failed+=("${subject_id}")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects completed Step 9."