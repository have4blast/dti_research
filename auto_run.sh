#!/bin/bash

# ============================================================
# auto_run.sh
#
# Usage:
#   ./auto_run.sh [fsl|freesurfer] [options]
#
# Examples:
#   ./auto_run.sh fsl
#   ./auto_run.sh freesurfer
#   ./auto_run.sh freesurfer --from-subject sub-032302
#   ./auto_run.sh freesurfer --skip-existing
#   ./auto_run.sh freesurfer --from-subject sub-032302 --skip-existing
#
# Options:
#   --from-subject SUB
#       指定した被験者から処理を開始
#
#   --skip-existing
#       既存の成果物があるStepをスキップ
#
#   -h, --help
#       ヘルプを表示
# ============================================================


# ============================================================
# 基本設定
# ============================================================

RAW_DIR="/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw"

# Step 3〜5
PREPROC_DIR="/home/brain/dti_research/preproc"

# Step 6〜11
DTICS_DIR="/home/brain/dti_research/derivatives/dticsd"

# pyAFQ
PYAFQ_DIR="/home/brain/dti_research/derivatives/pyafq"

# FreeSurfer
FREESURFER_SUBJECTS="/home/brain/dti_research/freesurfer_subjects"

# FreeSurfer SynthSeg
SYNTHSEG_SCRIPT="/home/brain/dti_research/scripts/s_freesurfer_synthseg_auto.sh"


# ============================================================
# スクリプトディレクトリ
# ============================================================

PREPROC_SCRIPT_DIR="$PREPROC_DIR"
DTICS_SCRIPT_DIR="$DTICS_DIR"


# ============================================================
# 引数
# ============================================================

TTGEN_METHOD="${1:-fsl}"

if [[ "$TTGEN_METHOD" != "fsl" && "$TTGEN_METHOD" != "freesurfer" ]]; then
    echo "ERROR: 第1引数は fsl または freesurfer を指定してください。"
    echo
    echo "Usage:"
    echo "  $0 [fsl|freesurfer] [--from-subject sub-XXXXXX] [--skip-existing]"
    exit 1
fi

shift

FROM_SUBJECT=""
SKIP_EXISTING=false

while [[ $# -gt 0 ]]; do

    case "$1" in

        --from-subject)
            if [[ -z "$2" ]]; then
                echo "ERROR: --from-subject には被験者IDが必要です。"
                exit 1
            fi

            FROM_SUBJECT="$2"
            shift 2
            ;;

        --skip-existing)
            SKIP_EXISTING=true
            shift
            ;;

        -h|--help)
            echo
            echo "Usage:"
            echo "  $0 [fsl|freesurfer] [options]"
            echo
            echo "Options:"
            echo "  --from-subject SUB    指定した被験者から処理を開始"
            echo "  --skip-existing       既存の成果物があるStepをスキップ"
            echo "  -h, --help            ヘルプを表示"
            echo
            exit 0
            ;;

        *)
            echo "ERROR: 不明なオプション: $1"
            exit 1
            ;;

    esac

done


# ============================================================
# 設定表示
# ============================================================

echo
echo "============================================================"
echo " auto_run.sh"
echo "============================================================"
echo "TTGEN_METHOD : $TTGEN_METHOD"
echo "RAW_DIR      : $RAW_DIR"
echo "PREPROC_DIR  : $PREPROC_DIR"
echo "DTICS_DIR    : $DTICS_DIR"
echo "PYAFQ_DIR    : $PYAFQ_DIR"
echo "FS_DIR       : $FREESURFER_SUBJECTS"
echo "FROM_SUBJECT : ${FROM_SUBJECT:-なし}"
echo "SKIP_EXISTING: $SKIP_EXISTING"
echo "============================================================"
echo


# ============================================================
# FreeSurfer設定
# ============================================================

if [[ "$TTGEN_METHOD" == "freesurfer" ]]; then

    if [[ -z "${FREESURFER_HOME:-}" ]]; then
        export FREESURFER_HOME="/usr/local/freesurfer/8.2.0"
    fi

    if [[ ! -f "${FREESURFER_HOME}/SetUpFreeSurfer.sh" ]]; then
        echo "ERROR: FreeSurferが見つかりません:"
        echo "  $FREESURFER_HOME"
        exit 1
    fi

    echo "Loading FreeSurfer..."
    source "${FREESURFER_HOME}/SetUpFreeSurfer.sh"

    echo "FreeSurfer:"
    echo "  $FREESURFER_HOME"
    echo

fi


# ============================================================
# 共通関数
# ============================================================

run_command()
{
    local STEP_NAME="$1"
    shift

    echo
    echo "------------------------------------------------------------"
    echo "$STEP_NAME"
    echo "------------------------------------------------------------"

    echo "Command:"
    printf '  %q' "$@"
    echo
    echo

    local STEP_START
    local STEP_END

    STEP_START=$(date +%s)

    "$@"

    local STATUS=$?

    STEP_END=$(date +%s)

    if [[ $STATUS -ne 0 ]]; then
        echo
        echo "ERROR: $STEP_NAME failed."
        echo "Exit code: $STATUS"
        echo "Time: $((STEP_END - STEP_START)) sec"
        return $STATUS
    fi

    echo
    echo "$STEP_NAME completed."
    echo "Time: $((STEP_END - STEP_START)) sec"

    return 0
}


# ============================================================
# 被験者一覧
# ============================================================

SUBJECTS=()

for subdir in "$RAW_DIR"/sub-*; do

    if [[ ! -d "$subdir" ]]; then
        continue
    fi

    sub=$(basename "$subdir")
    SUBJECTS+=("$sub")

done


if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
    echo "ERROR: 被験者ディレクトリが見つかりません:"
    echo "  $RAW_DIR/sub-*"
    exit 1
fi


# ============================================================
# --from-subject の確認
# ============================================================

if [[ -n "$FROM_SUBJECT" ]]; then

    FOUND=false

    for sub in "${SUBJECTS[@]}"; do

        if [[ "$sub" == "$FROM_SUBJECT" ]]; then
            FOUND=true
            break
        fi

    done

    if [[ "$FOUND" == false ]]; then
        echo "ERROR: 指定された被験者が見つかりません:"
        echo "  $FROM_SUBJECT"
        exit 1
    fi

fi


# ============================================================
# 失敗した被験者
# ============================================================

FAILED_SUBJECTS=()


# ============================================================
# 処理開始フラグ
# ============================================================

START_PROCESSING=false

if [[ -z "$FROM_SUBJECT" ]]; then
    START_PROCESSING=true
fi


# ============================================================
# 被験者ループ
# ============================================================

for subdir in "$RAW_DIR"/sub-*; do

    if [[ ! -d "$subdir" ]]; then
        continue
    fi

    sub=$(basename "$subdir")


    # --------------------------------------------------------
    # --from-subject より前の被験者をスキップ
    # --------------------------------------------------------

    if [[ "$START_PROCESSING" == false ]]; then

        if [[ "$sub" == "$FROM_SUBJECT" ]]; then
            START_PROCESSING=true
        else
            echo "Skipping $sub (before $FROM_SUBJECT)"
            continue
        fi

    fi


    # ========================================================
    # 被験者開始
    # ========================================================

    echo
    echo
    echo "============================================================"
    echo " Processing subject: $sub"
    echo "============================================================"


    # --------------------------------------------------------
    # 被験者ディレクトリ
    # --------------------------------------------------------

    SUBJECT_PREPROC_DIR="${PREPROC_DIR}/${sub}"
    SUBJECT_DTICS_DIR="${DTICS_DIR}/${sub}"
    SUBJECT_PYAFQ_DIR="${PYAFQ_DIR}/${sub}"
    SUBJECT_FS_DIR="${FREESURFER_SUBJECTS}/${sub}"


    # --------------------------------------------------------
    # 必要なディレクトリを作成
    # --------------------------------------------------------

    mkdir -p "$SUBJECT_PREPROC_DIR"
    mkdir -p "$SUBJECT_DTICS_DIR"
    mkdir -p "$SUBJECT_PYAFQ_DIR"
    mkdir -p "$SUBJECT_FS_DIR"


    if [[ ! -d "$SUBJECT_PREPROC_DIR" ]]; then
        echo "ERROR: preproc directory の作成に失敗しました:"
        echo "  $SUBJECT_PREPROC_DIR"

        FAILED_SUBJECTS+=("$sub")
        continue
    fi


    if [[ ! -d "$SUBJECT_DTICS_DIR" ]]; then
        echo "ERROR: dticsd directory の作成に失敗しました:"
        echo "  $SUBJECT_DTICS_DIR"

        FAILED_SUBJECTS+=("$sub")
        continue
    fi


    # ========================================================
    # FreeSurfer SynthSeg
    # ========================================================

    if [[ "$TTGEN_METHOD" == "freesurfer" ]]; then

        FS_ASEG="${SUBJECT_FS_DIR}/mri/aseg.auto.mgz"

        if [[ "$SKIP_EXISTING" == true && -e "$FS_ASEG" ]]; then

            echo
            echo "------------------------------------------------------------"
            echo "FreeSurfer SynthSeg"
            echo "------------------------------------------------------------"
            echo "SKIP: $FS_ASEG"

        else

            echo
            echo "------------------------------------------------------------"
            echo "FreeSurfer SynthSeg"
            echo "------------------------------------------------------------"

            if [[ ! -f "$SYNTHSEG_SCRIPT" ]]; then
                echo "ERROR: FreeSurfer SynthSeg scriptが見つかりません:"
                echo "  $SYNTHSEG_SCRIPT"

                FAILED_SUBJECTS+=("$sub")
                continue
            fi

            if ! run_command \
                "FreeSurfer SynthSeg: $sub" \
                bash \
                "$SYNTHSEG_SCRIPT" \
                "$sub"
            then
                FAILED_SUBJECTS+=("$sub")
                continue
            fi

        fi

    fi


    # ========================================================
    # Step 3: TOPUP
    #
    # 出力:
    #   field.nii.gz
    #   topup_PA_AP_b0_fieldcoef.nii.gz
    #   topup_PA_AP_b0_movpar.txt
    #   unwarped_images.nii.gz
    # ========================================================

    STEP3_OUTPUT="${SUBJECT_PREPROC_DIR}/field.nii.gz"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP3_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #3: TOPUP"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP3_OUTPUT"

    else

        if [[ ! -x "$PREPROC_SCRIPT_DIR/s_fsltopup_3.sh" ]]; then
            echo "ERROR: Step 3 script が見つかりません:"
            echo "  $PREPROC_SCRIPT_DIR/s_fsltopup_3.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$PREPROC_SCRIPT_DIR"; then
            echo "ERROR: preproc directoryへ移動できません:"
            echo "  $PREPROC_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #3: TOPUP" \
            "$PREPROC_SCRIPT_DIR/s_fsltopup_3.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 4: EDDY
    #
    # 出力:
    #   ${sub}_ses-01_dir-PA_dwi_aftereddy.nii.gz
    # ========================================================

    STEP4_OUTPUT="${SUBJECT_PREPROC_DIR}/${sub}_ses-01_dir-PA_dwi_aftereddy.nii.gz"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP4_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #4: EDDY"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP4_OUTPUT"

    else

        if [[ ! -x "$PREPROC_SCRIPT_DIR/s_fsleddy_4.sh" ]]; then
            echo "ERROR: Step 4 script が見つかりません:"
            echo "  $PREPROC_SCRIPT_DIR/s_fsleddy_4.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$PREPROC_SCRIPT_DIR"; then
            echo "ERROR: preproc directoryへ移動できません:"
            echo "  $PREPROC_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #4: EDDY" \
            "$PREPROC_SCRIPT_DIR/s_fsleddy_4.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 5: T1 registration
    #
    # 出力:
    #   T1w_in_dwi_space_highres.nii.gz
    # ========================================================

    STEP5_OUTPUT="${SUBJECT_PREPROC_DIR}/T1w_in_dwi_space_highres.nii.gz"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP5_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #5: T1 registration"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP5_OUTPUT"

    else

        if [[ ! -x "$PREPROC_SCRIPT_DIR/s_T1wflirt_5.sh" ]]; then
            echo "ERROR: Step 5 script が見つかりません:"
            echo "  $PREPROC_SCRIPT_DIR/s_T1wflirt_5.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$PREPROC_SCRIPT_DIR"; then
            echo "ERROR: preproc directoryへ移動できません:"
            echo "  $PREPROC_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #5: T1 registration" \
            "$PREPROC_SCRIPT_DIR/s_T1wflirt_5.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 6: DTI tensor
    #
    # 出力:
    #   dt_PA.mif
    #   FA_PA.mif
    #   AD_PA.mif
    #   RD_PA.mif
    #   MD_PA.mif
    #   PDD_PA.mif
    # ========================================================

    STEP6_OUTPUT="${SUBJECT_DTICS_DIR}/dt_PA.mif"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP6_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #6: DTI tensor"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP6_OUTPUT"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_diffusiontensor_6.sh" ]]; then
            echo "ERROR: Step 6 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_diffusiontensor_6.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #6: DTI tensor" \
            "$DTICS_SCRIPT_DIR/s_diffusiontensor_6.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 7: MSMT-CSD
    #
    # 出力:
    #   WM_FOD_PA.mif
    #   GM_FOD_PA.mif
    #   CSF_FOD_PA.mif
    # ========================================================

    STEP7_OUTPUT="${SUBJECT_DTICS_DIR}/WM_FOD_PA_${sub}.mif"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP7_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #7: MSMT-CSD"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP7_OUTPUT"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_diffusioncsd_7.sh" ]]; then
            echo "ERROR: Step 7 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_diffusioncsd_7.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #7: MSMT-CSD" \
            "$DTICS_SCRIPT_DIR/s_diffusioncsd_7.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 8: 5TT
    #
    # FSL:
    #   preproc/sub-XXXXXX/T1w_in_dwi_space_highres.nii.gz
    #
    # FreeSurfer:
    #   freesurfer_subjects/sub-XXXXXX/mri/aseg.auto.mgz
    #
    # 出力:
    #   5TT.mif
    #   vis.mif
    # ========================================================

    STEP8_OUTPUT="${SUBJECT_DTICS_DIR}/5TT.mif"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP8_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #8: 5TT ($TTGEN_METHOD)"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP8_OUTPUT"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_create5TT_8.sh" ]]; then
            echo "ERROR: Step 8 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_create5TT_8.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if [[ "$TTGEN_METHOD" == "freesurfer" ]]; then

            FS_ASEG="${SUBJECT_FS_DIR}/mri/aseg.auto.mgz"

            if [[ ! -e "$FS_ASEG" ]]; then
                echo "ERROR: FreeSurfer aseg.auto.mgz がありません:"
                echo "  $FS_ASEG"

                FAILED_SUBJECTS+=("$sub")
                continue
            fi

            export TTGEN_METHOD="freesurfer"
            export FS_ASEG="$FS_ASEG"

        else

            export TTGEN_METHOD="fsl"

            unset FS_ASEG

        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #8: 5TT ($TTGEN_METHOD)" \
            "$DTICS_SCRIPT_DIR/s_create5TT_8.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 9: ROI tractography
    #
    # 出力:
    #   Tensor_Det_300000.tck
    # ========================================================

    STEP9_OUTPUT="${SUBJECT_DTICS_DIR}/Tensor_Det_300000.tck"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP9_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #9: ROI tractography"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP9_OUTPUT"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_tractography_ROI_9.sh" ]]; then
            echo "ERROR: Step 9 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_tractography_ROI_9.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #9: ROI tractography" \
            "$DTICS_SCRIPT_DIR/s_tractography_ROI_9.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 10: Whole-brain tractography
    #
    # 出力:
    #   CSD_Prob_ACT_500_<subject>.tck
    # ========================================================

    STEP10_OUTPUT="${SUBJECT_DTICS_DIR}/CSD_Prob_ACT_500_${sub}.tck"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP10_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #10: Whole-brain tractography"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP10_OUTPUT"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_tractography_wholebrain_10.sh" ]]; then
            echo "ERROR: Step 10 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_tractography_wholebrain_10.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #10: Whole-brain tractography" \
            "$DTICS_SCRIPT_DIR/s_tractography_wholebrain_10.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 11-1: WM mask
    # ========================================================

    STEP11_WM_MASK="${SUBJECT_DTICS_DIR}/WM_mask.mif"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP11_WM_MASK" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #11-1: WM mask"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP11_WM_MASK"

    else

        if ! cd "$SUBJECT_DTICS_DIR"; then
            echo "ERROR: subject dticsd directoryへ移動できません:"
            echo "  $SUBJECT_DTICS_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #11-1: WM mask" \
            mrconvert \
            "$STEP8_OUTPUT" \
            -coord 3 2 \
            "$STEP11_WM_MASK" \
            -force
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 11-2: Seed image
    # ========================================================

    STEP11_SEED="${SUBJECT_DTICS_DIR}/seed_image.mif"


    if [[ "$SKIP_EXISTING" == true && -e "$STEP11_SEED" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #11-2: Seed image"
        echo "------------------------------------------------------------"
        echo "SKIP: $STEP11_SEED"

    else

        if ! cd "$SUBJECT_DTICS_DIR"; then
            echo "ERROR: subject dticsd directoryへ移動できません:"
            echo "  $SUBJECT_DTICS_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #11-2: Seed image" \
            mrconvert \
            "$STEP8_OUTPUT" \
            -coord 3 2 \
            "$STEP11_SEED" \
            -force
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # Step 11-3: Angle comparison
    #
    # 出力:
    #   CSD_Prob_500_leftV1_test_angle10.tck
    #   CSD_Prob_500_leftV1_test_angle20.tck
    #   CSD_Prob_500_leftV1_test_angle30.tck
    #   CSD_Prob_500_leftV1_test_angle40.tck
    # ========================================================

    ANGLE10="${SUBJECT_DTICS_DIR}/CSD_Prob_500_leftV1_test_angle10.tck"
    ANGLE20="${SUBJECT_DTICS_DIR}/CSD_Prob_500_leftV1_test_angle20.tck"
    ANGLE30="${SUBJECT_DTICS_DIR}/CSD_Prob_500_leftV1_test_angle30.tck"
    ANGLE40="${SUBJECT_DTICS_DIR}/CSD_Prob_500_leftV1_test_angle40.tck"


    if [[ "$SKIP_EXISTING" == true && \
          -e "$ANGLE10" && \
          -e "$ANGLE20" && \
          -e "$ANGLE30" && \
          -e "$ANGLE40" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "Step #11-3: Angle comparison"
        echo "------------------------------------------------------------"
        echo "SKIP: angle 10/20/30/40 の全ファイルが存在します"

    else

        if [[ ! -x "$DTICS_SCRIPT_DIR/s_tractography_ROI_parameters_11.sh" ]]; then
            echo "ERROR: Step 11 script が見つかりません:"
            echo "  $DTICS_SCRIPT_DIR/s_tractography_ROI_parameters_11.sh"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$DTICS_SCRIPT_DIR"; then
            echo "ERROR: dticsd directoryへ移動できません:"
            echo "  $DTICS_SCRIPT_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "Step #11-3: Angle comparison" \
            "$DTICS_SCRIPT_DIR/s_tractography_ROI_parameters_11.sh" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # pyAFQ
    #
    # 出力:
    #   <subject>_ses-01_dir-PA_desc-bundles_tractography.trk
    # ========================================================

    AFQ_OUTPUT="${SUBJECT_PYAFQ_DIR}/${sub}_ses-01_dir-PA_desc-bundles_tractography.trk"


    if [[ "$SKIP_EXISTING" == true && -e "$AFQ_OUTPUT" ]]; then

        echo
        echo "------------------------------------------------------------"
        echo "pyAFQ"
        echo "------------------------------------------------------------"
        echo "SKIP: $AFQ_OUTPUT"

    else

        if [[ ! -f "$PYAFQ_DIR/runAFQ.py" ]]; then
            echo "ERROR: runAFQ.py が見つかりません:"
            echo "  $PYAFQ_DIR/runAFQ.py"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! cd "$PYAFQ_DIR"; then
            echo "ERROR: pyafq directoryへ移動できません:"
            echo "  $PYAFQ_DIR"

            FAILED_SUBJECTS+=("$sub")
            continue
        fi


        if ! run_command \
            "pyAFQ: $sub" \
            python \
            "$PYAFQ_DIR/runAFQ.py" \
            "$sub"
        then
            FAILED_SUBJECTS+=("$sub")
            continue
        fi

    fi


    # ========================================================
    # 被験者完了
    # ========================================================

    echo
    echo "============================================================"
    echo " Completed subject: $sub"
    echo "============================================================"
    echo


done


# ============================================================
# 最終結果
# ============================================================

echo
echo
echo "============================================================"
echo " All processing finished"
echo "============================================================"


if [[ ${#FAILED_SUBJECTS[@]} -eq 0 ]]; then

    echo
    echo "すべての被験者の処理が正常に完了しました。"
    echo

else

    echo
    echo "以下の被験者でエラーが発生しました:"
    echo

    for sub in "${FAILED_SUBJECTS[@]}"; do
        echo "  - $sub"
    done

    echo
    echo "失敗した被験者数: ${#FAILED_SUBJECTS[@]}"
    echo

    exit 1

fi