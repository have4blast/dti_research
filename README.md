## 処理ステップ間の入力・出力の流れ

このREADMEで説明する処理は、基本的に前のステップで生成したファイルを次のステップ
の入力として使用します。被験者IDを含む実際のパスは、各スクリプトの設定に合わせて
読み替えてください。

| ステップ | 主な入力の由来 | 主な出力 | 次に使用するステップ |
| --- | --- | --- | --- |
| Step 1 | `raw/<被験者ID>/.../fmap/` のAP/PA EPI画像 | `b0_AP_*.nii.gz`, `b0_PA_*.nii.gz` | Step 2 |
| Step 2 | Step 1で抽出したAP/PAのb=0画像 | `APPAb0_all.nii.gz` | Step 3 |
| Step 3 | Step 2の統合b=0画像、`acquisition_parameters.txt` | TOPUPのfield map・係数・補正画像 | EDDY前処理 |
| Step 4 | EDDY前処理で作成した補正済みDWIと脳マスク | `dt_PA.mif`、FA/AD/RD/MDなど | Step 5 |
| Step 5 | EDDY補正済みDWIと脳マスク | `WM_FOD_PA_<被験者ID>.mif` など | Step 7 |
| Step 6 | T1位置合わせ前処理のT1、またはFreeSurferの `aseg.auto.mgz` | `5TT.mif`, `vis.mif` | Step 7のACT処理 |
| Step 7 | Step 5のWM FOD、Step 6の5TT、ROI画像 | `.tck` ストリームライン | 後続解析・可視化 |

### 入力ファイルの由来に関する注意

- `raw/` 以下のDWI、bval、bvec、AP/PA EPI画像は解析の起点となる入力です。
- `preproc/` 以下のファイルは、TOPUP、EDDY、T1画像位置合わせなどの前処理スクリプト
	が生成した中間・最終出力です。
- `derivatives/dticsd/` 以下の応答関数、FOD、5TTは、後続のテンソル解析やトラクト
	グラフィーで使用する派生データです。
- `derivatives/tractography/` 以下の `.tck` はトラクトグラフィーの最終出力であり、
	提示された範囲では別の処理スクリプトの入力にはなっていません。

## Step 1: b=0 イメージ抽出（fslroi）
位相エンコード方向（AP・PA）ごとのb=0イメージを複数枚抽出し、後のTOPUP補正に利用する。
| ファイル名            | 内容                                 | 備考                                      |
| ---------------- | ---------------------------------- | --------------------------------------- |
| `b0_PA_1.nii.gz` | PA方向（Posterior→Anterior）の1枚目のb=0画像 | fmapディレクトリ内の `*_dir-PA_epi.nii.gz` から抽出 |
| `b0_PA_2.nii.gz` | 同上、2枚目                             |                                         |
| `b0_PA_3.nii.gz` | 同上、3枚目                             |                                         |
| `b0_AP_1.nii.gz` | AP方向（Anterior→Posterior）の1枚目のb=0画像 | fmapディレクトリ内の `*_dir-AP_epi.nii.gz` から抽出 |
| `b0_AP_2.nii.gz` | 同上、2枚目                             |                                         |
| `b0_AP_3.nii.gz` | 同上、3枚目                             |                                         |

Step 2: b=0ファイルの統合（fslmerge）
TOPUPで使用するため、異なる位相エンコード方向のb=0画像を1つのファイルにまとめる。
入力はStep 1で抽出した `b0_AP_*.nii.gz` と `b0_PA_*.nii.gz` です。
| ファイル名               | 内容                            | 備考                  |
| ------------------- | ----------------------------- | ------------------- |
| `APPAb0_all.nii.gz` | 6枚のb=0画像を時系列方向（4次元）に結合したNIfTI | `AP3枚 + PA3枚` の合計6枚 |

Step 3: TOPUPの実行
TOPUPは、APとPAの位相反転ペアから**磁場歪み（susceptibility distortion）**を推定し、補正用マップを生成する。

入力はStep 2の `APPAb0_all.nii.gz` と、位相エンコード方向・readout timeを記載した
`preproc/acquisition_parameters.txt` です。ここで生成されたTOPUP出力は、Step 4の
EDDY処理に渡されます。

出力された field.nii.gz と topup_PA_AP_b0_fieldcoef.nii.gz は、次に行う eddy 処理の入力として利用される。
| ファイル名                             | 内容                                  | 備考                      |
| --------------------------------- | ----------------------------------- | ----------------------- |
| `topup_PA_AP_b0_fieldcoef.nii.gz` | 磁場歪み（field inhomogeneity）の**係数マップ** | TOPUPの内部パラメータを格納        |
| `topup_PA_AP_b0_movpar.txt`       | 画像の動きパラメータ                          | 各b=0イメージ間のシフト情報など       |
| `field.nii.gz`                    | **磁場歪みマップ（field map）**              | 歪み補正のための位相変化量（ラジアン/秒など） |
| `unwarped_images.nii.gz`          | **歪み補正後のb=0画像**                     | 各ペア（AP/PA）の歪みが補正された画像   |
| `topup_PA_AP_b0_log.txt`          | TOPUPの処理ログ                          | 実行状況やパラメータの詳細（任意）       |

出力ファイルまとめ
| カテゴリ    | ファイル名                                                                                                    | 内容概要           |
| ------- | -------------------------------------------------------------------------------------------------------- | -------------- |
| 抽出b=0   | `b0_AP_*.nii.gz`, `b0_PA_*.nii.gz`                                                                       | 位相方向別のb=0画像    |
| 結合ファイル  | `APPAb0_all.nii.gz`                                                                                      | TOPUP入力用の統合b=0 |
| TOPUP出力 | `topup_PA_AP_b0_fieldcoef.nii.gz`, `field.nii.gz`, `unwarped_images.nii.gz`, `topup_PA_AP_b0_movpar.txt` | 歪み補正結果とパラメータ   |

| ファイル名                             | 主な内容            | 主な用途             |
| --------------------------------- | --------------- | ---------------- |
| `topup_PA_AP_b0_fieldcoef.nii.gz` | 磁場歪みモデルの係数マップ   | `eddy` での歪み補正に使用 |
| `field.nii.gz`                    | 磁場歪み（field map） | 歪み量の可視化・理解用      |
| `unwarped_images.nii.gz`          | 歪み補正後のb=0画像群    | 補正結果の品質確認        |
| `topup_PA_AP_b0_movpar.txt`       | 各b=0画像の動きパラメータ  | `eddy` での動き補正に利用 |


## Step 4: 拡散テンソル推定と指標計算（dwi2tensor / tensor2metric）

`derivatives/dticsd/s_diffusiontensor_6.sh` は MRtrix のコマンドを使って、前処理済みの DWI データから拡散テンソルを推定し、テンソル由来の指標を計算する処理を行います。スクリプト内の主な処理は以下の2ステップです。

入力はEDDY前処理で作成された `*_dwi_aftereddy.mif` と
`*_aftereddy_brain_mask.nii.gz` です。これらはEDDYで動き・渦電流・磁場歪みを補正した
DWIと、その脳領域マスクです。

- Step #1: テンソル推定
	- コマンド: `dwi2tensor <input_dwi> dt_PA.mif -mask <brain_mask>`
	- 説明: eddy 等で補正済みの DWI 画像（このリポジトリの例では `/home/brain/dti_research/preproc/test/sub-032301_ses-01_dir-PA_dwi_aftereddy.mif`）から拡散テンソル（2nd order tensor）を推定して `dt_PA.mif` として保存します。`-mask` オプションで脳領域マスクを与え、背景やノイズ領域の推定を防ぎます。

- Step #2: テンソル由来指標の計算
	- コマンド: `tensor2metric -fa FA_PA.mif -ad AD_PA.mif -rd RD_PA.mif -adc MD_PA.mif -vector PDD_PA.mif dt_PA.mif`
	- 説明: 推定したテンソル画像 `dt_PA.mif` から各種指標を計算します。主な出力は以下の通りです。

出力ファイルと説明
| ファイル名 | 内容 | 備考 |
| --- | --- | --- |
| `dt_PA.mif` | 推定された拡散テンソル画像（MRtrix .mif 形式） | テンソルデータ本体。テンソル要素を持つボリューム。 |
| `FA_PA.mif` | Fractional Anisotropy（FA）マップ | 0〜1 の無次元量。白質の方向性指標として広く利用される。 |
| `AD_PA.mif` | Axial Diffusivity（AD）マップ | 主方向に沿った拡散係数（通常は単位: mm^2/s）。 |
| `RD_PA.mif` | Radial Diffusivity（RD）マップ | 主方向に直交する方向の平均拡散係数。 |
| `MD_PA.mif` | Mean Diffusivity / ADC（MD/ADC）マップ | 全方向平均拡散係数（MD）。スクリプト内では `-adc MD_PA.mif` として出力される。 |
| `PDD_PA.mif` | Principal Diffusion Direction（主要拡散方向）ベクトル場 | 各ボクセルの主要拡散方向をベクトルで表現（ベクトル画像）。 |

注記・運用上のポイント

- 上のファイル名は例（PA方向）で、被験者IDや位相エンコード方向によってファイル名は変わる場合があります。
- 出力は MRtrix の `.mif` 形式なので、NIfTI 形式に変換する場合は `mrconvert` を使ってください（例: `mrconvert FA_PA.mif FA_PA.nii.gz`）。
- 指標の単位やスケールは元のDWIのヘッダや前処理に依存します。解析間での一貫性（単位・マスク・補間）を確認してください。
- このスクリプトは単純なテンソルモデル（DTI）に基づく計算を行います。CSD/多成分モデルとは解析目的が異なります。

簡単な変換例:
```
# MRtrix .mif を NIfTI に変換
mrconvert FA_PA.mif FA_PA.nii.gz
```

以上が `s_diffusiontensor_6.sh` の処理内容と出力ファイルの説明です。

## Step 5: 多成分モデル（MSMT-CSD）による FOD 推定（dwi2response / dwi2fod）

`derivatives/dticsd/s_diffusioncsd_7.sh` は MRtrix を用いて、応答関数推定と MSMT-CSD による FOD（Fiber Orientation Distribution）推定を行います。スクリプトの主な流れは以下の通りです。

入力はEDDY前処理で作成されたeddy補正済みDWI（`*_dwi_aftereddy.mif`）と脳マスクです。Step 5で
生成されるWM FODは、Step 7のトラクトグラフィーで入力として使用します。

- Step #1: 応答関数（response function）の推定（dhollander 法）
	- コマンド例:
		- `dwi2response dhollander <input_dwi> RF_WM.txt RF_GM.txt RF_CSF.txt -mask <brain_mask> -voxels RF_voxels.mif`
	- 説明: dhollander 法は WM/GM/CSF の応答関数を自動推定します。出力されるテキストファイル（例: `RF_WM_PA.txt`, `RF_GM_PA.txt`, `RF_CSF_PA.txt`）は MSMT-CSD の入力として使います。`-voxels` で応答関数推定に使用したボクセル情報（`RF_voxels_PA.mif`）を保存します。

- Step #2: MSMT-CSD による FOD 推定
	- コマンド例:
		- `dwi2fod msmt_csd <input_dwi> RF_WM.txt WM_FOD.mif RF_GM.txt GM_FOD.mif RF_CSF.txt CSF_FOD.mif -mask <brain_mask>`
	- 説明: 各組織の応答関数を用いて、WM/GM/CSF のそれぞれの FOD（または相当する分布）を計算します。白質 FOD（`WM_FOD_PA.mif`）はトラクトグラフィー（`tckgen` など）で用いる主要な入力です。

出力ファイルと説明
| ファイル名 | 内容 | 備考 |
| --- | --- | --- |
| `RF_WM_PA.txt`, `RF_GM_PA.txt`, `RF_CSF_PA.txt` | WM/GM/CSF の応答関数（テキスト） | MSMT-CSD の入力。各組織の信号特性を記述する。 |
| `RF_voxels_PA.mif` | 応答関数推定に使われたボクセル情報 | 推定の診断や可視化に有用。 |
| `WM_FOD_PA.mif` | 白質の FOD（Fiber Orientation Distribution） | トラクトグラフィーや FOD ベース解析に使用。 |
| `GM_FOD_PA.mif`, `CSF_FOD_PA.mif` | GM / CSF のFOD相当出力 | MSMT モデルの他組織成分。 |

注記・運用上のポイント

- dhollander 法は比較的自動化された手法ですが、データの b 値や SNR に依存します。必要に応じて手動で応答関数を定義することも可能です。
- FOD は MRtrix の `.mif` 形式で出力されます。可視化や他ツールとの連携では `mrconvert` を使えますが、方向情報を保持・利用するために MRtrix ツール群で処理することを推奨します。
- 白質 FOD をトラクトグラフィーに使う際は、`mtnormalise` による正規化や、FOD の閾値処理、シード戦略の設計などの前処理・パラメータ調整を検討してください。
- 出力のファイル名はスクリプト内の例（被験者/PA方向）に合わせています。運用時は被験者IDやセッション情報を付与してください。

簡単な可視化例（MRtrix）:
```
# FOD を視覚確認
mrview WM_FOD_PA.mif -odf.load_sh
```

以上が `s_diffusioncsd_7.sh` の処理内容と出力ファイルの説明です。
```

## Step 6: 5TT画像の生成（5ttgen / 5tt2vis）

`derivatives/dticsd/s_create5TT_8.sh` は、解剖学的制約付きトラクトグラフィー
（ACT: Anatomically-Constrained Tractography）で使用する5TT（5-tissue-type）画像を
生成します。スクリプトは被験者IDを引数で受け取り、出力を
`derivatives/dticsd/<被験者ID>/` に保存します。

FSL方式の入力 `T1w_in_dwi_space_highres.nii.gz` は、Step 4付近のT1画像位置合わせ
処理で作成されたDWI空間のT1画像です。FreeSurfer方式では、FreeSurfer解析結果から
得られた `mri/aseg.auto.mgz` を入力として使用します。

```bash
./derivatives/dticsd/s_create5TT_8.sh sub-032302
```

### FSL方式

既定ではFSL方式を使用します。入力は `s_T1wflirt_5.sh` などのT1位置合わせ前処理で
作成された、DWI空間の `preproc/<被験者ID>/T1w_in_dwi_space_highres.nii.gz` です。

```bash
5ttgen fsl T1w_in_dwi_space_highres.nii.gz 5TT.mif -nocleanup -force
```

FSLの脳抽出・組織分割処理を用いて、T1画像から皮質灰白質、皮質下灰白質、白質、
髄液などの組織成分を推定します。T1画像がDWI空間にあるため、生成された5TTも
DWI空間で利用しやすいことが特徴です。

### FreeSurfer方式

FreeSurfer方式を使用する場合は、FreeSurferの環境設定と被験者ごとのパーセレーション
画像が必要です。T1画像やFreeSurferの被験者ディレクトリそのものではなく、
`aseg.auto.mgz` などの `aseg` パーセレーション画像を入力します。

```bash
set +u
source /usr/local/freesurfer/8.2.0/SetUpFreeSurfer.sh
set -u

TTGEN_METHOD=freesurfer \
FS_ASEG=/home/brain/dti_research/freesurfer_subjects/sub-032302/mri/aseg.auto.mgz \
./derivatives/dticsd/s_create5TT_8.sh sub-032302
```

FreeSurfer方式では、FreeSurferのラベル情報をMRtrixのACT用ラベルへ変換します。
入力される `aseg.auto.mgz` は通常FreeSurferの被験者空間にあるため、DWI空間で
トラクトグラフィーに使用する場合は、別途DWI空間への位置合わせ・変換が必要です。

### 5TT生成後の可視化

生成した5TT画像から、可視化用の画像を作成します。

```bash
5tt2vis 5TT.mif vis.mif -force
```

出力ファイルは以下のとおりです。

| ファイル名 | 内容 | 主な用途 |
| --- | --- | --- |
| `5TT.mif` | 5種類の組織成分を持つ5TT画像 | ACT、解剖学的制約付きトラクトグラフィー |
| `vis.mif` | 5TTを可視化しやすくした画像 | `mrview` での確認 |
| `5ttgen-tmp-*/` | `5ttgen` の中間ファイルとログ | エラー調査。`-nocleanup` 指定時に保持 |

5TTの主な組織成分は、皮質灰白質（cGM）、皮質下灰白質（sGM）、白質（WM）、
髄液（CSF）、病的組織（pathological tissue）です。生成後は、DWI画像と重ね合わせて
位置と向きが一致していることを確認してからトラクトグラフィーに使用してください。

以上が `s_create5TT_8.sh` の処理内容と出力ファイルの説明です。

## Step 7: トラクトグラフィー（tckgen）

トラクトグラフィーでは、MRtrixの `tckgen` を使って、FOD画像やシード画像から
ストリームライン（線維走行）を生成します。主な出力形式は `.tck` です。

### ROIトラクトグラフィー（s_tractography_ROI_9.sh）

`derivatives/dticsd/s_tractography_ROI_9.sh` は、被験者ごとの出力ディレクトリを作成し、
ROIを意識したトラクトグラフィーを実行するためのスクリプトです。現在有効になって
いるコマンドは以下の構成です。

入力のFODはStep 5の `WM_FOD_PA_<被験者ID>.mif`、またはテスト用の
`WM_FOD_test.mif`です。ROIを使用する場合は、ROI作成処理で生成したマスクやシード
画像も入力になります。

既定値を変えずに被験者別の出力へ切り替える場合は、環境変数で入力を指定できます。
FreeSurfer由来の5TTを使う場合は `ACT_5TT` を指定すると `-act` が追加されます。

```bash
WM_FOD=/home/brain/dti_research/derivatives/dticsd/sub-032302/WM_FOD_PA_sub-032302.mif \
ACT_5TT=/home/brain/dti_research/derivatives/dticsd/sub-032302/5TT.mif \
TRACT_INPUT=/home/brain/dti_research/derivatives/dticsd/sub-032302/WM_FOD_PA_sub-032302.mif \
./derivatives/dticsd/s_tractography_ROI_9.sh sub-032302
```

`TRACT_INPUT` を指定しない場合は、元のスクリプトと同じDWIファイルを入力します。

```bash
tckgen <input> \
	-algorithm iFOD2 \
	-seed_dynamic <WM_FOD> \
	-maxlength 250 \
	-select 300000 \
	-nthreads 4 \
	Tensor_Det_300000.tck -force
```

主なオプションは以下のとおりです。

| オプション | 内容 |
| --- | --- |
| `-algorithm iFOD2` | FODに基づく確率的トラクトグラフィーを使用 |
| `-seed_dynamic` | 指定したFODの振幅に基づいてシード点を動的に配置 |
| `-maxlength 250` | ストリームラインの最大長を250 mmに制限 |
| `-select 300000` | 生成するストリームライン数を30万本に設定 |
| `-nthreads 4` | 4スレッドで処理 |

出力ファイルは次のとおりです。

| ファイル名 | 内容 |
| --- | --- |
| `Tensor_Det_300000.tck` | 生成された30万本のストリームライン |

出力先は、スクリプトの設定では以下です。

```text
derivatives/tractography/<被験者ID>/
```

なお、現在の有効なコマンドには次の確認事項があります。`iFOD2` の入力には通常
白質FOD（`WM_FOD_PA_<被験者ID>.mif`）を指定しますが、スクリプトではDWIファイルが
指定されています。また、`-seed_dynamic` のFODパスが被験者別ディレクトリではなく
固定パスになっています。実行時には、入力を被験者別のWM FODへ変更してください。

### 全脳CSDトラクトグラフィー（s_tractography_wholebrain_10.sh）

`s_tractography_wholebrain_10.sh` は、Step 5で生成した白質FODを入力として、全脳の
確率的トラクトグラフィーを実行します。現在有効なコマンドは次のとおりです。

```bash
tckgen WM_FOD_test.mif \
	-algorithm iFOD2 \
	-backtrack \
	-crop_at_gmwmi \
	-maxlength 250 \
	-step 0.8 \
	-select 500 \
	-nthreads 4 \
	CSD_Prob_ACT_500_test.tck
```

`WM_FOD_test.mif` はStep 5（MSMT-CSD）のテスト用WM FOD出力です。被験者別に実行
する場合は、`WM_FOD_PA_<被験者ID>.mif` などのStep 5出力へ置き換えます。

FreeSurfer由来の5TTを使うACT実行例は以下のとおりです。`ACT_5TT` を指定しない
場合は、元のコマンドと同じく `-act` なしで実行されます。

```bash
WM_FOD=/home/brain/dti_research/derivatives/dticsd/sub-032302/WM_FOD_PA_sub-032302.mif \
ACT_5TT=/home/brain/dti_research/derivatives/dticsd/sub-032302/5TT.mif \
TCK_OUTPUT=/home/brain/dti_research/derivatives/tractography/sub-032302/CSD_Prob_ACT_500.tck \
./derivatives/dticsd/s_tractography_wholebrain_10.sh
```

主なオプションと出力は以下のとおりです。

| オプションまたはファイル | 内容 |
| --- | --- |
| `-algorithm iFOD2` | 確率的FODトラクトグラフィー |
| `-backtrack` | 追跡が行き詰まった場合に戻って再試行 |
| `-crop_at_gmwmi` | 灰白質・白質境界（GMWMI）でストリームラインを切断 |
| `-maxlength 250` | 最大ストリームライン長250 mm |
| `-step 0.8` | 追跡ステップ幅0.8 mm |
| `-select 500` | 500本のストリームラインを生成 |
| `CSD_Prob_ACT_500_test.tck` | 全脳トラクトグラフィーの出力 |

ファイル名にはACTを示す `ACT` が含まれていますが、現在有効なコマンドには
`-act 5TT.mif` が指定されていません。そのため、厳密な意味でACTを有効にするには、
以下のように5TT画像を指定する必要があります。

```bash
tckgen WM_FOD_test.mif \
	-algorithm iFOD2 \
	-act 5TT.mif \
	-backtrack \
	-crop_at_gmwmi \
	-seed_dynamic WM_FOD_test.mif \
	-maxlength 250 \
	-step 0.8 \
	-select 300000 \
	-nthreads 4 \
	CSD_Prob_ACT_300000_test.tck
```

この場合、`5TT.mif` はStep 6で生成したWM、GM、CSFなどの組織情報を用いて、解剖学的に妥当な
ストリームライン生成を制約します。5TT、WM FOD、シード画像は同じ空間・グリッドに
そろえてから使用してください。

### トラクトグラフィーのパラメータ比較（s_tractography_ROI_parameters_11.sh）

`s_tractography_ROI_parameters_11.sh` は、Step 5で生成したWM FODを入力として、
`iFOD2` の曲率角度（`-angle`）を変え、トラクトグラフィー結果を比較するための
スクリプトです。現在は角度10、20、30、40度の4条件を実行します。

```bash
tckgen WM_FOD_test.mif -algorithm iFOD2 \
	-mask WM_mask_test.mif \
	-seed_image LV1_test.mif \
	-angle 10 -maxlength 250 -select 500 \
	-nthreads 4 CSD_Prob_500_leftV1_test_angle10.tck
```

入力ファイルの由来は以下のとおりです。

| 入力ファイル | 由来・用途 |
| --- | --- |
| `WM_FOD_test.mif` | Step 5（MSMT-CSD）のテスト用WM FOD出力 |
| `WM_mask_test.mif` | ROIトラクトグラフィー用に作成した追跡可能領域のマスク |
| `LV1_test.mif` | ROI作成ステップで作成したシード画像 |

被験者別のファイルやFreeSurfer由来のROI関連ファイルを使う場合は、次の環境変数を
指定します。指定しない場合は、元のテスト用ファイル名がそのまま使われます。

| 環境変数 | 内容 |
| --- | --- |
| `WM_FOD` | Step 5で作成したWM FOD |
| `WM_MASK` | ROI用マスク。FreeSurferの5TTから作成したマスクも指定可能 |
| `SEED_IMAGE` | ROI作成ステップで作成したシード画像 |

```bash
WM_FOD=/path/to/WM_FOD_PA_sub-032302.mif \
WM_MASK=/path/to/WM_mask_sub-032302.mif \
SEED_IMAGE=/path/to/LV1_sub-032302.mif \
./derivatives/dticsd/s_tractography_ROI_parameters_11.sh
```

各条件の出力は以下のとおりです。

| 条件 | 出力ファイル |
| --- | --- |
| `-angle 10` | `CSD_Prob_500_leftV1_test_angle10.tck` |
| `-angle 20` | `CSD_Prob_500_leftV1_test_angle20.tck` |
| `-angle 30` | `CSD_Prob_500_leftV1_test_angle30.tck` |
| `-angle 40` | `CSD_Prob_500_leftV1_test_angle40.tck` |

`-mask` は追跡可能な領域を制限し、`-seed_image` は指定したROI画像からシード点を
作成します。`-maxlength 250` は最大ストリームライン長、`-select 500` は生成本数、
`-nthreads 4` は使用スレッド数を示します。

このスクリプトで生成された `.tck` ファイルは、提示された後続スクリプトでは入力に
使われておらず、角度条件ごとの比較結果として扱われます。

以上がトラクトグラフィー関連スクリプトの処理内容と出力ファイルの説明です。

## Steps 8-11の被験者別自動実行

`scripts/s_tractography_8_11_auto.sh` は、1人の被験者について、5TT生成、ROI
トラクトグラフィー、全脳ACTトラクトグラフィー、角度比較を順番に実行します。
FSLまたはFreeSurferを5TT生成方法として選択できます。

### FSL方式

Step 5まで完了し、`WM_FOD_PA_<被験者ID>.mif` が存在する状態で実行します。

```bash
./scripts/s_tractography_8_11_auto.sh sub-032302 fsl
```

### FreeSurfer方式

FreeSurferの環境を読み込み、`aseg.auto.mgz` の場所を指定して実行します。
FreeSurferの5TTは、既存の `anat2dwialign_mrtrix.txt` を使ってDWI空間へ変換されます。

```bash
source /usr/local/freesurfer/8.2.0/SetUpFreeSurfer.sh
FS_ASEG=/path/to/sub-032302/mri/aseg.auto.mgz \
./scripts/s_tractography_8_11_auto.sh sub-032302 freesurfer
```

実行前に処理内容だけ確認する場合は、最後に `--dry-run` を付けます。

```bash
./scripts/s_tractography_8_11_auto.sh sub-032302 fsl --dry-run
```

出力は `derivatives/dticsd/<被験者ID>/` の5TTと、
`derivatives/tractography/<被験者ID>/` の `.tck` およびROI用マスクに保存されます。
FSL方式・FreeSurfer方式のどちらでも、tractographyにはDWI空間の5TTと被験者用WM FODを
渡します。

## 各ステップを全被験者に自動実行

各ステップを個別に全被験者へ実行するautoスクリプトも用意しています。被験者は
Step 6・7は `PREPROC_ROOT` 以下、Step 8〜11は `RAW_DIR` 以下の `sub-*` ディレクトリから
自動検出されます。1人の処理が失敗しても
残りの被験者を処理し、最後に失敗した被験者一覧を表示します。

```bash
# Step 6: DTI tensorとFA/AD/RD/MDを全被験者に作成
./scripts/s_diffusiontensor_6_auto.sh

# Step 7: MSMT-CSDとWM/GM/CSF FODを全被験者に作成
./scripts/s_diffusioncsd_7_auto.sh

# Step 8: FSL方式で5TTを全被験者に作成
./scripts/s_create5TT_8_auto.sh

# Step 8: FreeSurfer方式で5TTを全被験者に作成
TTGEN_METHOD=freesurfer \
FREESURFER_SUBJECTS_DIR=/path/to/freesurfer_subjects \
./scripts/s_create5TT_8_auto.sh

# Step 9: ROI tractography
./scripts/s_tractography_ROI_9_auto.sh

# Step 10: 全脳ACT tractography
./scripts/s_tractography_wholebrain_10_auto.sh

# Step 11: 角度比較
./scripts/s_tractography_ROI_parameters_11_auto.sh
```

標準のrawデータ置場を変更する場合は、`RAW_DIR` を指定します。

```bash
RAW_DIR=/path/to/MRI_Raw ./scripts/s_create5TT_8_auto.sh
```

Step 9〜11を実行する前に、各被験者についてStep 7のCSD処理が完了し、
`derivatives/dticsd/<被験者ID>/WM_FOD_PA_<被験者ID>.mif` が作成されている必要があります。

Step 6・7の入力場所を変更する場合は、`PREPROC_ROOT` を指定します。

```bash
PREPROC_ROOT=/path/to/preproc ./scripts/s_diffusioncsd_7_auto.sh
```

