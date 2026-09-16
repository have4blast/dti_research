

#!/bin/bash

set -euo pipefail

PREPROC_DIR=/home/brain/dti_research/preproc
RAW_DIR=/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw

# Accept subject id as first arg, default to sub-032301
subj_id=${1:-sub-032301}

# Allow skipping eddy for dry-run/testing: set SKIP_EDDY=1 in environment
SKIP_EDDY=${SKIP_EDDY:-0}

echo "changing to subject preproc directory: ${PREPROC_DIR}/${subj_id}"
cd "${PREPROC_DIR}/${subj_id}" || { echo "ERROR: cannot cd to ${PREPROC_DIR}/${subj_id}"; exit 1; }

echo "performing FSL BET on PA b=0 image for ${subj_id}"
# Step #1 performing BET on b=0 image (use explicit .nii.gz filename)
# Use the un-prefixed name so downstream scripts/masks stay consistent with other scripts
bet b0_PA_1.nii.gz b0_PA1_brain -m -f 0.2

# Create an index file for EDDY in the subject directory (one entry per volume)
echo "creating index_PA.txt for eddy"
nvols=$(fslval ${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.nii.gz dim4 | tr -d '\n' | xargs)
if [[ -z "${nvols}" || ! "${nvols}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: unable to determine nvols (fslval returned: '${nvols}')." >&2
  exit 1
fi
# Use awk to generate a file with '4' repeated nvols times (avoids SIGPIPE with pipefail)
awk -v n="${nvols}" 'BEGIN{for(i=0;i<n;i++) print 4}' > index_PA.txt

echo "running EDDY on PA data for ${subj_id}" 
if [ "${SKIP_EDDY}" -eq 1 ]; then
  echo "SKIP_EDDY=1; skipping eddy_cpu (dry-run)"
  echo "eddy_cpu would be invoked with:"
  echo "  --imain=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.nii.gz"
  echo "  --mask=b0_PA1_brain_mask.nii.gz"
  echo "  --index=index_PA.txt"
  echo "  --acqp=${PREPROC_DIR}/acquisition_parameters.txt"
  echo "  --bvecs=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.bvec"
  echo "  --bvals=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.bval"
  echo "  --topup=topup_PA_AP_b0"
  echo "  --out=${subj_id}_ses-01_dir-PA_dwi_aftereddy"
else
  # Step #2 running EDDY on PA data
  eddy_cpu \
    --imain=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.nii.gz \
    --mask=b0_PA1_brain_mask.nii.gz \
    --index=index_PA.txt \
    --acqp=${PREPROC_DIR}/acquisition_parameters.txt \
    --bvecs=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.bvec \
    --bvals=${RAW_DIR}/${subj_id}/ses-01/dwi/${subj_id}_ses-01_dwi.bval \
    --fwhm=0 \
    --topup=topup_PA_AP_b0 \
    --flm=quadratic \
    --out=${subj_id}_ses-01_dir-PA_dwi_aftereddy
fi



