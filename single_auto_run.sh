#!/bin/bash

LOGFILE="./auto_run.log"
# Accept subject id as first arg, default to sub-032301
subj_id=${1:-sub-032301}

echo "===== Auto Run Started: $(date) (subject=${subj_id}) =====" >> "$LOGFILE"

# 実行したいスクリプトを順番に列挙
SCRIPTS=(
    "/home/brain/dti_research/preproc/s_fsltopup_3.sh"
    "/home/brain/dti_research/preproc/s_fsleddy_4.sh"
    "/home/brain/dti_research/preproc/s_T1wflirt_5.sh"
)

# 指定された順番で順次実行
for script in "${SCRIPTS[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo "Skipped: $script not found." | tee -a "$LOGFILE"
        continue
    fi

    echo "Running $script for ${subj_id} ..." | tee -a "$LOGFILE"
    bash "$script" "${subj_id}" >> "$LOGFILE" 2>&1

    if [[ $? -eq 0 ]]; then
        echo "$script completed successfully for ${subj_id}." | tee -a "$LOGFILE"
    else
        echo "Error occurred while running $script for ${subj_id}." | tee -a "$LOGFILE"
    fi
done

echo "===== Auto Run Finished: $(date) (subject=${subj_id}) =====" >> "$LOGFILE"