#!/usr/bin/env python3
import os
import os.path as op
import sys

BASE = '/home/brain/dti_research'
DATA = '/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw'
SUBJECT_ID = sys.argv[1] if len(sys.argv) > 1 else 'sub-032301'
PREPROC = op.join(BASE, 'preproc', SUBJECT_ID)
RAW_DWI = op.join(DATA, SUBJECT_ID, 'ses-01', 'dwi')
TRACT = op.join(BASE, 'derivatives', 'tractography', SUBJECT_ID)

checks = {
    'dwi': op.join(PREPROC, f'{SUBJECT_ID}_ses-01_dir-PA_dwi_aftereddy.nii.gz'),
    'bval': op.join(RAW_DWI, f'{SUBJECT_ID}_ses-01_dwi.bval'),
    'bvec': op.join(PREPROC, f'{SUBJECT_ID}_ses-01_dir-PA_dwi_aftereddy.eddy_rotated_bvecs'),
    'mask': op.join(PREPROC, 'b0_1_PA_aftereddy_brain_mask.nii.gz'),
    'tck': op.join(TRACT, 'CSD_Prob_ACT_500.tck'),
}

missing = []
for k,p in checks.items():
    if not op.exists(p):
        missing.append((k,p))

if missing:
    print('Missing required inputs:')
    for k,p in missing:
        print(f" - {k}: {p}")
    raise SystemExit(2)

print('All required input files were found:')
for k,p in checks.items():
    print(f" - {k}: {p}")
