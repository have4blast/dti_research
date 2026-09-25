#!/usr/bin/env bash

# Resume FreeSurfer 5TT, tractography, and pyAFQ from one subject onward.
# Usage:
#   ./scripts/resume_freesurfer_afq.sh --from-subject sub-032303 --skip-existing

set -u

PROJECT_DIR="/home/brain/dti_research"
RAW_DIR=${RAW_DIR:-/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw}
LOGFILE=${LOGFILE:-${PROJECT_DIR}/resume_freesurfer_afq.log}
FROM_SUBJECT=""
SKIP_EXISTING=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from-subject)
            FROM_SUBJECT=${2:-}
            shift 2
            ;;
        --skip-existing)
            SKIP_EXISTING=1
            shift
            ;;
        *)
            echo "Usage: $0 --from-subject sub-XXXXXX [--skip-existing]" >&2
            exit 2
            ;;
    esac
done

if [[ -z "${FROM_SUBJECT}" ]]; then
    echo "[ERROR] --from-subject is required." >&2
    exit 2
fi
if [[ -z "${FREESURFER_HOME:-}" ]]; then
    echo "[ERROR] FREESURFER_HOME is required." >&2
    exit 2
fi

if [[ -f "${FREESURFER_HOME}/SetUpFreeSurfer.sh" ]]; then
    set +u
    # shellcheck disable=SC1091
    source "${FREESURFER_HOME}/SetUpFreeSurfer.sh" >/dev/null
    set -u
fi

mkdir -p "$(dirname "${LOGFILE}")"
exec > >(tee -a "${LOGFILE}") 2>&1

shopt -s nullglob
subjects=("${RAW_DIR}"/sub-*)
started=0
failed=()

run_step() {
    local label=$1
    shift
    echo "[START] ${label}"
    if "$@"; then
        echo "[OK] ${label}"
        return 0
    fi
    local status=$?
    echo "[ERROR] ${label} (exit=${status})" >&2
    return "${status}"
}

exists_or_run() {
    local label=$1
    local output=$2
    shift 2
    if [[ "${SKIP_EXISTING}" == "1" && -e "${output}" ]]; then
        echo "[SKIP] ${label}: ${output}"
        return 0
    fi
    run_step "${label}" "$@"
}

for subject_path in "${subjects[@]}"; do
    [[ -d "${subject_path}" ]] || continue
    subject_id=$(basename "${subject_path}")
    if [[ "${started}" == "0" ]]; then
        [[ "${subject_id}" == "${FROM_SUBJECT}" ]] || continue
        started=1
    fi

    echo "========== Resuming ${subject_id} =========="
    dti_dir="${PROJECT_DIR}/derivatives/dticsd/${subject_id}"
    tract_dir="${PROJECT_DIR}/derivatives/tractography/${subject_id}"
    aseg="${PROJECT_DIR}/freesurfer_subjects/${subject_id}/mri/aseg.auto.mgz"
    five_tt="${dti_dir}/5TT.mif"
    wm_fod="${dti_dir}/WM_FOD_PA_${subject_id}.mif"
    roi_tck="${tract_dir}/Tensor_Det_300000.tck"
    whole_tck="${tract_dir}/CSD_Prob_ACT_500_${subject_id}.tck"
    wm_mask="${tract_dir}/WM_mask_${subject_id}.mif"
    seed_image="${tract_dir}/WM_seed_${subject_id}.mif"
    afq_dir="${PROJECT_DIR}/derivatives/pyafq/${subject_id}"
    afq_bundle="${afq_dir}/${subject_id}_ses-01_dir-PA_desc-bundles_tractography.trk"
    subject_failed=0

    if ! exists_or_run "${subject_id} FreeSurfer segmentation" "${aseg}" \
        env SINGLE_SUBJECT="${subject_id}" FREESURFER_SUBJECTS_DIR="${PROJECT_DIR}/freesurfer_subjects" \
        bash "${PROJECT_DIR}/scripts/s_freesurfer_synthseg_auto.sh"; then
        subject_failed=1
    fi
    if [[ "${subject_failed}" == "0" ]] && ! exists_or_run "${subject_id} Step 8 5TT" "${five_tt}" \
        env TTGEN_METHOD=freesurfer FS_ASEG="${aseg}" \
        bash "${PROJECT_DIR}/derivatives/dticsd/s_create5TT_8.sh" "${subject_id}"; then
        subject_failed=1
    fi

    mkdir -p "${tract_dir}"
    if [[ "${subject_failed}" == "0" ]] && ! exists_or_run "${subject_id} Step 9 ROI tractography" "${roi_tck}" \
        env TRACT_INPUT="${wm_fod}" WM_FOD="${wm_fod}" ACT_5TT="${five_tt}" \
        bash "${PROJECT_DIR}/derivatives/dticsd/s_tractography_ROI_9.sh" "${subject_id}"; then
        subject_failed=1
    fi
    if [[ "${subject_failed}" == "0" ]] && ! exists_or_run "${subject_id} Step 10 whole-brain tractography" "${whole_tck}" \
        env WM_FOD="${wm_fod}" ACT_5TT="${five_tt}" TCK_OUTPUT="${whole_tck}" \
        OVERWRITE=1 bash "${PROJECT_DIR}/derivatives/dticsd/s_tractography_wholebrain_10.sh"; then
        subject_failed=1
    fi
    if [[ "${subject_failed}" == "0" ]] && ! exists_or_run "${subject_id} Step 11 WM mask" "${wm_mask}" \
        mrconvert "${five_tt}" -coord 3 2 "${wm_mask}" -force; then
        subject_failed=1
    fi
    if [[ "${subject_failed}" == "0" ]] && ! exists_or_run "${subject_id} Step 11 seed image" "${seed_image}" \
        mrconvert "${wm_mask}" "${seed_image}" -force; then
        subject_failed=1
    fi

    if [[ "${subject_failed}" == "0" ]]; then
        angle10="${tract_dir}/CSD_Prob_500_leftV1_test_angle10.tck"
        angle20="${tract_dir}/CSD_Prob_500_leftV1_test_angle20.tck"
        angle30="${tract_dir}/CSD_Prob_500_leftV1_test_angle30.tck"
        angle40="${tract_dir}/CSD_Prob_500_leftV1_test_angle40.tck"
        if [[ "${SKIP_EXISTING}" == "1" && -f "${angle10}" && -f "${angle20}" && -f "${angle30}" && -f "${angle40}" ]]; then
            echo "[SKIP] ${subject_id} Step 11 angle comparison"
        elif ! (cd "${tract_dir}" && run_step "${subject_id} Step 11 angle comparison" \
            env WM_FOD="${wm_fod}" WM_MASK="${wm_mask}" SEED_IMAGE="${seed_image}" OVERWRITE=1 \
            bash "${PROJECT_DIR}/derivatives/dticsd/s_tractography_ROI_parameters_11.sh"); then
            subject_failed=1
        fi
    fi

    if [[ "${subject_failed}" == "0" ]]; then
        if [[ "${SKIP_EXISTING}" == "1" && -f "${afq_bundle}" ]]; then
            echo "[SKIP] ${subject_id} pyAFQ: ${afq_bundle}"
        elif ! exists_or_run "${subject_id} pyAFQ" "${afq_bundle}" \
            python3 "${PROJECT_DIR}/derivatives/pyafq/runAFQ.py" "${subject_id}"; then
            subject_failed=1
        fi
    fi

    if [[ "${subject_failed}" == "1" ]]; then
        failed+=("${subject_id}")
        echo "[SUBJECT FAILED] ${subject_id}"
    else
        echo "[SUBJECT OK] ${subject_id}"
    fi
done

if [[ "${started}" == "0" ]]; then
    echo "[ERROR] Start subject not found: ${FROM_SUBJECT}" >&2
    exit 2
fi
if [[ ${#failed[@]} -gt 0 ]]; then
    printf '[SUMMARY] Failed subjects: %s\n' "${failed[*]}" >&2
    exit 1
fi
echo "[SUMMARY] Resume completed successfully."