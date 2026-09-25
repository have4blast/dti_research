#!/usr/bin/env python3
import os
import os.path as op
import sys

import nibabel as nib
import numpy as np
from AFQ.api.participant import ParticipantAFQ
from AFQ.definitions.image import ImageFile

BASE_PATH = '/home/brain/dti_research'
DATA_PATH = '/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw'
SUBJECT_ID = sys.argv[1] if len(sys.argv) > 1 else 'sub-032301'

preproc_dir = op.join(BASE_PATH, 'preproc', SUBJECT_ID)
raw_dwi_dir = op.join(DATA_PATH, SUBJECT_ID, 'ses-01', 'dwi')
tract_dir = op.join(BASE_PATH, 'derivatives', 'tractography', SUBJECT_ID)
out_dir = op.join(BASE_PATH, 'derivatives', 'pyafq', SUBJECT_ID)

dwi_path = op.join(preproc_dir, f'{SUBJECT_ID}_ses-01_dir-PA_dwi_aftereddy.nii.gz')
bval_path = op.join(raw_dwi_dir, f'{SUBJECT_ID}_ses-01_dwi.bval')
bvec_path = op.join(preproc_dir, f'{SUBJECT_ID}_ses-01_dir-PA_dwi_aftereddy.eddy_rotated_bvecs')
mask_path = op.join(preproc_dir, 'b0_1_PA_aftereddy_brain_mask.nii.gz')
tck_candidates = [
    op.join(tract_dir, f'CSD_Prob_ACT_500_{SUBJECT_ID}.tck'),
    op.join(tract_dir, 'CSD_Prob_ACT_500.tck'),
]
tck_path = next((path for path in tck_candidates if op.isfile(path)), tck_candidates[0])

required_inputs = {
    'dwi': dwi_path,
    'bval': bval_path,
    'bvec': bvec_path,
    'mask': mask_path,
    'tck': tck_path,
}
os.makedirs(out_dir, exist_ok=True)
missing = [(name, path) for name, path in required_inputs.items() if not op.isfile(path)]
if missing:
    details = '\n'.join(f'  {name}: {path}' for name, path in missing)
    raise FileNotFoundError(f'Missing AFQ input files for {SUBJECT_ID}:\n{details}')

dwi_image = nib.load(dwi_path)
mask_image = nib.load(mask_path)
if dwi_image.ndim != 4 or mask_image.shape != dwi_image.shape[:3]:
    raise ValueError(
        f'DWI/mask geometry mismatch: DWI={dwi_image.shape}, mask={mask_image.shape}'
    )

with open(bval_path, encoding='ascii') as bval_file:
    bvals = np.fromstring(bval_file.read(), sep=' ')
bvecs = np.loadtxt(bvec_path)
if bvecs.ndim == 1:
    bvecs = bvecs.reshape(1, -1)
if bvals.size != dwi_image.shape[3] or bvecs.shape != (3, dwi_image.shape[3]):
    raise ValueError(
        f'DWI gradient mismatch: DWI volumes={dwi_image.shape[3]}, '
        f'bvals={bvals.size}, bvecs={bvecs.shape}'
    )

print(f'Running AFQ for {SUBJECT_ID}')
for name, path in required_inputs.items():
    print(f'  {name}: {path}')

brain_mask_definition = ImageFile(
	path=mask_path,
	suffix='mask',
	filters={'scope': 'my_preproc_pipeline'})

myafq = ParticipantAFQ(
	dwi_path,
	bval_path,
	bvec_path,
	out_dir,
	import_tract=tck_path,
	brain_mask_definition=brain_mask_definition,
	mapping_definition=None)

myafq.export_all()