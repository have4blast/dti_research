#!/usr/bin/env bash

# Run s_create5TT_8.sh for every subject under RAW_DIR.
# Usage: TTGEN_METHOD=fsl|freesurfer ./s_create5TT_8_auto.sh

set -euo pipefail

PROJECT_DIR="/home/brain/dti_research"
RAW_DIR=${RAW_DIR:-/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw}
SCRIPT="${PROJECT_DIR}/derivatives/dticsd/s_create5TT_8.sh"
TTGEN_METHOD=${TTGEN_METHOD:-fsl}

if [[ ! -f "${SCRIPT}" ]]; then
    echo "[ERROR] Script not found: ${SCRIPT}" >&2
    exit 1
fi
if [[ "${TTGEN_METHOD}" != "fsl" && "${TTGEN_METHOD}" != "freesurfer" ]]; then
    echo "[ERROR] TTGEN_METHOD must be fsl or freesurfer: ${TTGEN_METHOD}" >&2
    exit 2
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
    echo "===== Step 8: ${subject_id} (${TTGEN_METHOD}) ====="

    fs_aseg=""
    if [[ "${TTGEN_METHOD}" == "freesurfer" ]]; then
        fs_subjects_dir=${FREESURFER_SUBJECTS_DIR:-${PROJECT_DIR}/freesurfer_subjects}
        fs_aseg=${FS_ASEG:-${fs_subjects_dir}/${subject_id}/mri/aseg.auto.mgz}
    fi

    if ! TTGEN_METHOD="${TTGEN_METHOD}" FS_ASEG="${fs_aseg}" \
        bash "${SCRIPT}" "${subject_id}"; then
        echo "[ERROR] Step 8 failed for ${subject_id}" >&2
        failed+=("${subject_id}")
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects completed Step 8."