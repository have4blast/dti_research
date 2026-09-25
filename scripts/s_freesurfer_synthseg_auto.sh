#!/usr/bin/env bash

# Generate FreeSurfer-compatible aseg.auto.mgz files for all raw subjects.
# Usage: ./scripts/s_freesurfer_synthseg_auto.sh

set -euo pipefail

PROJECT_DIR="/home/brain/dti_research"
RAW_DIR=${RAW_DIR:-/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw}
FS_SUBJECTS_DIR=${FREESURFER_SUBJECTS_DIR:-${PROJECT_DIR}/freesurfer_subjects}
SYNTHSEG=${SYNTHSEG:-${FREESURFER_HOME}/bin/mri_synthseg}
THREADS=${THREADS:-1}

if [[ -z "${FREESURFER_HOME:-}" || ! -x "${SYNTHSEG}" ]]; then
    echo "[ERROR] FreeSurfer SynthSeg is unavailable: ${SYNTHSEG}" >&2
    exit 2
fi

shopt -s nullglob

if [[ $# -ge 1 ]]; then
    subjects=("${RAW_DIR}/$1")
elif [[ -n "${SINGLE_SUBJECT:-}" ]]; then
    subjects=("${RAW_DIR}/${SINGLE_SUBJECT}")
else
    subjects=("${RAW_DIR}"/sub-*)
fi
if [[ ${#subjects[@]} -eq 0 ]]; then
    echo "[ERROR] No subject directories found under ${RAW_DIR}" >&2
    exit 1
fi

failed=()
for subject_path in "${subjects[@]}"; do
    [[ -d "${subject_path}" ]] || continue
    subject_id=$(basename "${subject_path}")
    t1_file=$(find "${subject_path}/ses-01/anat" -maxdepth 1 -type f \
        -name '*T1w.nii.gz' -print -quit 2>/dev/null)
    subject_mri="${FS_SUBJECTS_DIR}/${subject_id}/mri"
    aseg_file="${subject_mri}/aseg.auto.mgz"

    echo "===== FreeSurfer segmentation: ${subject_id} ====="
    if [[ -z "${t1_file}" ]]; then
        echo "[ERROR] T1w image not found for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi
    if [[ -f "${aseg_file}" ]]; then
        echo "[SKIP] Existing segmentation: ${aseg_file}"
        continue
    fi

    mkdir -p "${subject_mri}"
    if ! "${SYNTHSEG}" --i "${t1_file}" --o "${aseg_file}" \
        --cpu --fast --autocrop --threads "${THREADS}" \
        --keepgeom --noaddctab; then
        echo "[ERROR] SynthSeg failed for ${subject_id}" >&2
        failed+=("${subject_id}")
        continue
    fi
    if [[ ! -f "${aseg_file}" ]]; then
        echo "[ERROR] SynthSeg did not create ${aseg_file}" >&2
        failed+=("${subject_id}")
    else
        echo "[OK] Created ${aseg_file}"
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[ERROR] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "All subjects have FreeSurfer aseg.auto.mgz files."