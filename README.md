Step 1: b=0 イメージ抽出（fslroi）
位相エンコード方向（AP・PA）ごとのb=0イメージを複数枚抽出し、後のTOPUP補正に利用する。
| ファイル名            | 内容                                 | 備考                                      |
| ---------------- | ---------------------------------- | --------------------------------------- |
| `b0_PA_1.nii.gz` | PA方向（Posterior→Anterior）の1枚目のb=0画像 | fmapディレクトリ内の `*_dir-PA_epi.nii.gz` から抽出 |
| `b0_PA_2.nii.gz` | 同上、2枚目                             |                                         |
| `b0_PA_3.nii.gz` | 同上、3枚目                             |                                         |
| `b0_AP_1.nii.gz` | AP方向（Anterior→Posterior）の1枚目のb=0画像 | fmapディレクトリ内の `*_dir-AP_epi.nii.gz` から抽出 |
| `b0_AP_2.nii.gz` | 同上、2枚目                             |                                         |
| `b0_AP_3.nii.gz` | 同上、3枚目                             |                                         |

Step 1: b=0 イメージ抽出（fslroi）
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
| ファイル名               | 内容                            | 備考                  |
| ------------------- | ----------------------------- | ------------------- |
| `APPAb0_all.nii.gz` | 6枚のb=0画像を時系列方向（4次元）に結合したNIfTI | `AP3枚 + PA3枚` の合計6枚 |

Step 3: TOPUPの実行
TOPUPは、APとPAの位相反転ペアから**磁場歪み（susceptibility distortion）**を推定し、補正用マップを生成する。

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

