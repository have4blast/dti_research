# CLAUDE.md

このファイルは、Claude Codeがこのリポジトリ（`dti_research`）でDTI解析のコード作成・修正・実行・デバッグを行う際に、毎回参照すべきプロジェクトの背景情報をまとめたものです。

このファイルは2026-09-26時点で、実際のプロジェクトファイル・環境・ログを調査して作成しました。「確認済みの事実」と「研究方針・将来計画・仮説」を区別して記載しています。不明な項目は `TODO: Confirm ...` と明記しています。

---

# Project Overview

修士研究として実施している、拡散テンソル画像（DTI）解析パイプラインのリポジトリです。安静時脳波（EEG）研究とペアになるマルチモーダル研究の、MRI/DTI側の解析環境にあたります（EEG解析コード自体はこのリポジトリには存在しません。詳細は「EEG Analysis」参照）。

パイプラインの中心は以下の3つです。

1. FSL（TOPUP/eddy）とMRtrix3によるDTI/CSD前処理・テンソル推定・トラクトグラフィー
2. FreeSurfer（主にSynthSegによる自動セグメンテーション）による解剖学的制約付きトラクトグラフィー（ACT）用データの生成
3. pyAFQによる自動化ファイバー束（bundle）認識とtract-profile算出

主要な処理フローとオプションは [README.md](README.md) に日本語で詳細に記載されています。過去のデバッグ経緯・既知の障害は [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) にまとめられています。作業前に両方に目を通してください。

---

# Research Goal

研究タイトル：「脳波とMRIを用いたマルチモダリティ解析による加齢に伴う脳の構造的および機能的変化」

研究目的：健常な加齢に伴う脳の構造的・機能的変化を明らかにし、将来的に認知機能低下や認知症の前臨床的な変化を捉えるための基礎的な指標を検討する。

- MRI / DTI：脳白質の構造的変化を評価する（本リポジトリの主対象）
- EEG：脳領域間の機能的connectivityやnetwork propertiesを評価する（別プロジェクト、詳細後述）
- 認知機能：TMTなどを用いて評価する

最終的には「脳構造」「脳機能」「認知機能」の関係をマルチモーダルに解析することを目指す。**この最終目標はまだ実装されていない研究方針であり、既に得られた結果ではない。**

---

# Dataset

- データセットは **MPI-LEMON（Leipzig Mind-Body-Brain, MPILMBB）データセット** に由来する（`raw`データのパスが `/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw` であることから確認）。LEMONは公開されているマルチモーダル加齢研究データセットで、構造MRI・拡散MRI・安静時fMRI・安静時EEGを含む。
- 被験者ディレクトリ数：外部データ (`/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw`) に227名（`sub-032301`〜`sub-032528`付近、一部欠番あり）。BIDS形式（`sub-*/ses-01/{anat,dwi,fmap,func}`）。
- リポジトリ内 `raw/` には3名分のみ存在（動作確認・テスト用と推測される。詳細は `TODO: Confirm raw/ 内の3被験者がテスト用途か本解析対象かを確認`）。
- DWIデータ仕様（`sub-032301`のJSON/mrinfoから確認、他被験者も同一プロトコルの可能性が高いが未確認）：
  - 3T Siemens Verio、マルチバンド撮像（`MultibandAccelerationFactor: 2`）
  - シングルシェル：b=0（7ボリューム）+ b=1000（60方向）、合計67ボリューム
  - Voxel size：約1.72 × 1.72 × 1.7 mm（`mrinfo`実測値）
  - PhaseEncodingDirection: `j-`（本編DWI）。fmap内にAP/PA両方向のスピンエコーEPIがあり、TOPUP用に使用
  - TotalReadoutTime: 0.04914 s
  - `TODO: Confirm 全227被験者で撮像プロトコルが同一かどうか（個体差・撮像年の違いの有無）`
- 構造画像：T1w（MP2RAGE由来 `acq-mp2rage_T1w`）、T2w、FLAIRも取得されている。DTIパイプラインで実際に使われているのはT1wのみ（`TODO: Confirm T2w/FLAIRが現在の解析で使用されているか`）。
- 認知機能データ（TMTなど）・被験者属性（年齢群など）は、本リポジトリ内には見当たらない。`TODO: Confirm 認知機能データ・年齢群情報の保管場所`。

---

# Data Structure

被験者IDは一貫して `sub-XXXXXX` 形式。処理ステップ間のファイルの流れは以下（詳細は [README.md](README.md) 冒頭の対応表を参照）。

```
/media/sf_share/MRI_MPILMBB_LEMON/MRI_Raw/<sub>/ses-01/{anat,dwi,fmap,func}/  … 外部の元データ（読み取り専用として扱う）
  └─(Step1-2: fslroi/fslmerge)
preproc/<sub>/                     … TOPUP・eddy・T1アライメント等の前処理出力
  └─(Step3: TOPUP, Step4: eddy, Step5: FLIRTでDWI空間へT1整列)
derivatives/dticsd/<sub>/           … MRtrixによるテンソル推定・CSD・5TT・トラクトグラフィー
  └─(Step6: dwi2tensor/tensor2metric → FA/MD/AD/RD/PDD)
  └─(Step7: dwi2response/dwi2fod → WM/GM/CSF FOD)
  └─(Step8: 5ttgen → 5TT.mif, ACT用)
  └─(Step9: tckgen ROIベース)
derivatives/tractography/<sub>/     … トラクトグラフィー出力（.tck）
  └─(Step10: 全脳ACTトラクトグラフィー)
  └─(Step11: angle条件比較)
derivatives/pyafq/<sub>/            … pyAFQによるbundle認識・profile出力
freesurfer_subjects/<sub>/mri/aseg.auto.mgz  … FreeSurfer SynthSegによる自動セグメンテーション（ACT用5TT生成に使用）
```

`raw/` はいわゆる「元データ」に相当し、`.gitignore` でも除外されている（Git管理外）。**`raw/` および `/media/sf_share/.../MRI_Raw` 以下のファイルは絶対に上書き・削除しない。**

---

# DTI Analysis Pipeline

実装済みのステップ（[README.md](README.md) に対応するStep番号を付記）。すべてMRtrix3（`.mif`形式）とFSLを併用する構成。

| Step | 内容 | 主なコマンド | スクリプト |
|---|---|---|---|
| 1 | AP/PA b=0画像抽出 | `fslroi` | `preproc/s_fsltopup_3.sh` 内 |
| 2 | b=0画像の統合 | `fslmerge` | 同上 |
| 3 | TOPUP（磁場歪み補正マップ推定） | `topup` | `preproc/s_fsltopup_3.sh`, `scripts/s_fsltopup_3_auto.sh` |
| 4 | eddy（動き・渦電流・磁場歪み補正） | `bet`, `eddy_cpu` | `preproc/s_fsleddy_4.sh`, `scripts/s_fsleddy_4_auto.sh` |
| 5 | T1をDWI空間へ位置合わせ | `flirt` 等 | `preproc/s_T1wflirt_5.sh`, `scripts/s_T1wflirt_5_auto.sh` |
| 6 | テンソル推定・FA/AD/RD/MD算出 | `dwi2tensor`, `tensor2metric` | `derivatives/dticsd/s_diffusiontensor_6.sh`, `scripts/s_diffusiontensor_6_auto.sh` |
| 7 | MSMT-CSDによるFOD推定（dhollander法） | `dwi2response dhollander`, `dwi2fod msmt_csd` | `derivatives/dticsd/s_diffusioncsd_7.sh`, `scripts/s_diffusioncsd_7_auto.sh` |
| 8 | 5TT生成（ACT用、FSL方式 or FreeSurfer方式） | `5ttgen fsl` / `5ttgen freesurfer`, `5tt2vis` | `derivatives/dticsd/s_create5TT_8.sh`, `scripts/s_create5TT_8_auto.sh` |
| 9 | ROIトラクトグラフィー | `tckgen -algorithm iFOD2 -seed_dynamic` | `derivatives/dticsd/s_tractography_ROI_9.sh` |
| 10 | 全脳（確率的）トラクトグラフィー | `tckgen -algorithm iFOD2 -backtrack -crop_at_gmwmi` | `derivatives/dticsd/s_tractography_wholebrain_10.sh` |
| 11 | 曲率角度（`-angle` 10/20/30/40°）のパラメータ比較 | `tckgen` | `derivatives/dticsd/s_tractography_ROI_parameters_11.sh` |
| （実験的） | SLF I/II/III の手動ROIベース束分割 | `tckedit -include/-exclude` | `derivatives/dticsd/s_dissect_SLF_12.sh` |

被験者ごとの自動実行は `auto_run.sh`（Step1〜11 + FreeSurfer + pyAFQを通しで実行、`fsl`/`freesurfer`両モード対応、`--from-subject`/`--skip-existing`オプションあり）と `scripts/resume_freesurfer_afq.sh`（FreeSurfer以降を再開）に統合されている。各ステップを全被験者に個別実行する `*_auto.sh` 系スクリプトも `scripts/` にある。

## 既知の注意点・バグ（2026-09-26に修正済み）

- **Step 9（`s_tractography_ROI_9.sh`）**: 旧版では `TRACT_INPUT` を指定しない場合、`iFOD2` の入力にWM FODではなく元DWIファイルが使われてしまう不整合があった。**修正済み**：`TRACT_INPUT` の既定値が被験者別のWM FOD（`WM_FOD_PA_<被験者ID>.mif`）になり、明示指定しなくても正しい入力が使われる。
- **Step 10（`s_tractography_wholebrain_10.sh`）**: 旧版では出力ファイル名に `ACT` を含むが、`ACT_5TT` を指定しない限り既定コマンドに `-act 5TT.mif` が付与されなかった。**修正済み**：`ACT_5TT` の既定値が被験者別ディレクトリの `5TT.mif` になり、当該ファイルが存在すれば明示指定なしでもACTが有効になる。ACTを無効化したい場合は `ACT_5TT=""` を明示的に指定する。
- **5ttgen（FSL FIRST方式）は既知の障害あり**: 全被験者的にセグメンテーション失敗＋segmentation faultが発生する事象が確認されている（詳細: `derivatives/dticsd/ERROR_REPORT_5TTGen_FIRST_Failure.md`, `PROJECT_SUMMARY.md`）。この問題を回避するため、**FreeSurfer（SynthSeg）方式の5TT生成（`TTGEN_METHOD=freesurfer`）が現在の主要な運用パス**になっている。`hsvs`/`gif`等の代替バックエンドも試行されたが解決には至っていない（`scripts/5ttgen_fallback.sh` 参照）。

---

# Structural MRI / FreeSurfer

- FreeSurferバージョン：**8.2.0**（`/usr/local/freesurfer/8.2.0`、`build-stamp.txt`より確認）。
- `SUBJECTS_DIR`：プロジェクト独自に `/home/brain/dti_research/freesurfer_subjects` を使用（環境変数 `FREESURFER_SUBJECTS_DIR` で上書き可能）。標準の`$FREESURFER_HOME/subjects`ではない。
- **`recon-all` は本リポジトリのスクリプトからは呼び出されていない**（`grep`で不使用を確認）。使われているのは `mri_synthseg`（FreeSurfer 8.x同梱のディープラーニングベース自動セグメンテーション）のみ：`scripts/s_freesurfer_synthseg_auto.sh` が各被験者のT1w画像から `--fast --autocrop --cpu` オプションで `aseg.auto.mgz` を生成する。フル皮質再構成（表面再構成・皮質厚推定等）は行われていない。
- 用途：生成された `aseg.auto.mgz` はMRtrixのACT用5TT画像生成（Step 8, FreeSurfer方式）の入力としてのみ使用される。DWI空間への変換は `s_create5TT_8.sh` / `scripts/s_tractography_8_11_auto.sh` 内で `anat2dwialign_mrtrix.txt` を用いて行われる。
- 現状：227被験者ディレクトリ中226名分で `aseg.auto.mgz` が生成済み（調査時点）。

---

# pyAFQ

- インストール状況：`pyAFQ 2.0`（`/home/brain/.local/lib/python3.10/site-packages`、`pip show pyAFQ`で確認）。Python 3.10.12環境。
- 依存：dipy 1.10.0、nibabel、numpy 等（pyAFQの依存として自動導入）。
- 実行コード：`derivatives/pyafq/runAFQ.py`（被験者IDを引数に取る）。`AFQ.api.participant.ParticipantAFQ` を使用し、**MRtrixで生成した`.tck`ファイルを`import_tract`で読み込む方式**（pyAFQ自身にはtractographyをさせていない）。
- 入力：
  - DWI: `preproc/<sub>/<sub>_ses-01_dir-PA_dwi_aftereddy.nii.gz`
  - bval: 元データの `<sub>_ses-01_dwi.bval`
  - bvec: eddy補正後の回転済みbvec（`*_dwi_aftereddy.eddy_rotated_bvecs`）
  - brain mask: `preproc/<sub>/b0_1_PA_aftereddy_brain_mask.nii.gz`（`ImageFile` definitionで指定）
  - import tractogram: `derivatives/tractography/<sub>/CSD_Prob_ACT_500_<sub>.tck`（Step 10の全脳ACTトラクトグラフィー出力）
- `mapping_definition=None`（既定のMNIテンプレートへのマッピングを使用していると推測される。`TODO: Confirm mapping_definition=Noneの場合の実際のwarp/registration手法`）。
- bundle認識：pyAFQの既定のwaypoint ROI/bundle定義セットを使用（本リポジトリ内でカスタムbundle定義は確認できなかった。`TODO: Confirm カスタムbundle辞書の有無`）。
- 出力：`myafq.export_all()` を呼び出しており、FA/MD/AD/RD等を含むtract profile、bundleごとのtrk、可視化用HTML（`derivatives/pyafq/<sub>.html`）などpyAFQ標準の全出力が生成される想定。
- 実行状況：一部被験者で `run_pyafq_sub-032301.sh`（単一被験者用ラッパー）や `scripts/resume_freesurfer_afq.sh`（パイプライン全体の一部として自動実行）経由で実行済み。全227名分の完了は確認できていない（「Current Progress」参照）。
- 補足：`derivatives/pyafq/check_pyafq_inputs.py` は、pyAFQ実行前の入力ファイル存在チェック用スクリプト。

---

# EEG Analysis

**本リポジトリ内にEEG解析コード・EEGデータは存在しない**（`eeg`/`EEG`/`TMT`で全文検索したが該当ファイルなし）。また、この環境にはPython `mne` パッケージもインストールされていない。

研究計画としては、安静時EEGから以下を解析する方針（ユーザー提供情報。**実装・実行状況は未確認の研究方針**）：

- 周波数帯：theta, alpha, beta
- Long-range functional connectivity（phase-basedのconnectivity指標）
- グラフ理論指標：global efficiency, local efficiency, path length, hub関連指標

`TODO: Confirm EEG解析プロジェクトの実体（別リポジトリ／別マシン／別ディレクトリのパス）`。DTI側のコード変更時、EEG側の実装詳細を推測して記述しないこと。

---

# EEG-DTI Integration

現時点で、本リポジトリにEEGとDTIを統合する解析コードは存在しない（TODO/研究方針の段階）。

想定されている研究方針（**仮説であり、確定した解析計画ではない**）：

```
DTI white matter integrity（FA/MD/AD/RD、tract profile）
   → EEG functional connectivity（theta/alpha/beta帯のphase-based connectivity, graph theory指標）
      → cognitive performance（TMT等）
```

この関係性を検討する可能性がある、という段階。DTI側の被験者ID・データパスとEEG側の被験者IDの対応関係については、`TODO: Confirm EEGデータの被験者ID命名規則とDTI側sub-IDとの対応関係`。**被験者IDの対応関係は絶対に推測で変更・生成しないこと**（Development Rules参照）。

---

# Cognitive Measures

TMT（Trail Making Test）等の認知機能指標を使用する研究方針。本リポジトリ内にTMTデータ・解析コードは見当たらない。`TODO: Confirm 認知機能データの保管場所・フォーマット・対応する被験者ID`。

---

# Software Environment

実行環境から直接確認できた情報のみ記載（2026-09-26調査時点）。

| ソフトウェア | バージョン | 確認方法 |
|---|---|---|
| OS | Ubuntu 22.04.5 LTS (Jammy) | `/etc/os-release` |
| Python | 3.10.12 | `python3 --version` |
| FSL | 6.0.7.17（`FSLDIR=/usr/local/fsl`） | `$FSLDIR/etc/fslversion` |
| MRtrix3 | 3.0.4-48-gfdec23df | `mrconvert --version` |
| FreeSurfer | 8.2.0（`/usr/local/freesurfer/8.2.0`） | `build-stamp.txt` |
| pyAFQ | 2.0 | `pip show pyAFQ` |
| dipy | 1.10.0 | `python3 -c "import dipy"` |
| MNE | 未インストール（このマシン／この環境には存在しない） | `import mne` → `ModuleNotFoundError` |

`TODO: Confirm EEG解析（MNE等）がどの環境・マシンで実行されているか（このマシンとは別の可能性が高い）`。

---

# Directory Structure

```
dti_research/
├── CLAUDE.md                    … 本ファイル
├── README.md                    … Step1〜11の詳細な処理内容・入出力・コマンド例（日本語）
├── PROJECT_SUMMARY.md           … 5ttgen/FIRST障害の診断記録と対応履歴
├── auto_run.sh                  … 全被験者・全ステップの自動実行（fsl/freesurferモード対応、要注意：現在ローカル変更あり）
├── single_auto_run.sh           … 単一被験者に対しStep3-5（前処理）のみ実行する簡易版
├── auto_run.log                 … auto_run.shの実行ログ（大容量、被験者ごとの処理状況を追える）
├── resume_freesurfer_afq.log    … resume_freesurfer_afq.shの実行ログ
├── raw/                         … 元データ（Git管理外、外部データのローカルコピーはごく一部の3被験者のみ）
├── preproc/                     … Step1-5の前処理出力（被験者ディレクトリ + 前処理スクリプト本体）
├── derivatives/
│   ├── dticsd/                  … Step6-11のMRtrix処理スクリプト本体 + 被験者ごとの出力（テンソル・FOD・5TT・ROIトラクト）
│   ├── tractography/            … 被験者ごとの全脳トラクトグラフィー出力（.tck）
│   └── pyafq/                   … pyAFQ実行スクリプト（runAFQ.py等） + 被験者ごとの出力
├── freesurfer_subjects/         … FreeSurfer SUBJECTS_DIR（各被験者の mri/aseg.auto.mgz）
├── first/                       … T1のN4/BET/FLIRT/5ttgen試行スクリプト（`first.sh`、5ttgen障害調査の一環）
├── scripts/                     … 全被験者自動実行用ラッパースクリプト群（*_auto.sh）、resume_freesurfer_afq.sh
├── image/                       … スクリーンショット等
└── test.nii.gz, output.txt など … 動作確認・デバッグ用の一時ファイル
```

`.gitignore` により、`raw/`、被験者ごとの大容量出力（`derivatives/*/sub-*`、`freesurfer_subjects/sub-*`、`preproc/sub-*`）、各種バイナリ画像形式（`*.nii.gz`, `*.mif`, `*.mat`等）はGit管理外。**リポジトリにコミットされているのはスクリプト・ドキュメント・設定ファイルのみ**であることに注意。

---

# Current Progress

調査時点（2026-09-26）でファイルシステムから確認できた状態。被験者単位の完了数は目安であり、テスト実行や失敗リトライを含む可能性があるため、正確な完了被験者リストが必要な場合は都度ログ・出力ファイルを確認すること。

## DONE（実装・スクリプト化され、少なくとも一部被験者で実行確認済み）

1. **データ確認**：MPI-LEMONデータセットのBIDS構造、DWI撮像パラメータ（b=1000シングルシェル、60方向+b0×7、TOPUP用AP/PA fieldmap）を確認済み。
2. **Preprocessing（Step1-5）**：TOPUP/eddy/T1アライメントのスクリプトを実装済み。`preproc/`配下に少なくとも21被験者分の `T1w_in_dwi_space_highres.nii.gz` が生成済み。
3. **Tensor fitting / FA・MD・AD・RD算出（Step6）**：`s_diffusiontensor_6.sh` 実装済み、複数被験者で実行済み。
4. **Tractography（Step7-10）**：CSD（WM/GM/CSF FOD）、5TT、ROI/全脳トラクトグラフィーのスクリプトを実装済み。WM_FOD生成済み約20被験者、5TT生成済み約19被験者、全脳ACTトラクトグラフィー完了約15被験者。
5. **pyAFQ連携**：`runAFQ.py`によるbundle認識・tract profile出力（`export_all()`）のコードが動作する状態まで実装済み。一部被験者で実行済み（HTML可視化出力を確認）。
6. **FreeSurfer（SynthSeg）による5TT代替パス**：FSL FIRSTのsegfault問題を受け、SynthSegベースの`aseg.auto.mgz`生成とACT用5TT変換の運用フローを確立。227名中226名分の`aseg.auto.mgz`を生成済み。

## IN PROGRESS

- **全被験者への前処理〜トラクトグラフィーの展開**：`auto_run.sh`（FSL方式）は直近の実行ログで `sub-032316` のeddy処理中に停止（`Terminated`）しており、全227名の完走はしていない。
- **全被験者へのFreeSurfer/ACT/pyAFQパイプライン展開**：`resume_freesurfer_afq.sh` による再開実行は最後の被験者（`sub-032528`）まで到達しているが、当該被験者は前処理（preproc）が未完了のためpyAFQ等が失敗している。つまり「最後まで到達した」ことと「全員分完了した」ことは別（未完了の被験者が途中に残っている可能性がある）。
- **tractごとの白質指標算出**：pyAFQ `export_all()` により個別被験者のtract profileは出力されるが、複数被験者分を集約・比較するためのコード（グループ解析用スクリプト）はリポジトリ内に見当たらない。

## TODO（未着手・コード未確認）

7. tractごとの白質指標を全被験者分集約するスクリプト
8. 年齢群比較（年齢群の定義自体も未確認）
9. EEG connectivityとの関連解析（EEG側のコード・データが本リポジトリに存在しない）
10. 認知機能（TMT等）との関連解析
11. マルチモーダル解析（構造×機能×認知）

---

# Planned Analysis

以下はユーザーの研究方針として共有された将来計画であり、**現時点で実装・実行されているものではない**。

- DTIから得られる白質構造指標（tractごとのFA/MD/AD/RD）と、EEGから得られる安静時functional connectivity・network指標との関連解析
- TMT等の認知機能指標との関連解析
- 年齢群間でのDTI指標比較
- 「DTI white matter integrity → EEG functional connectivity → cognitive performance」という関係性の検討（仮説段階）

これらに着手する際は、まず実装方針をユーザーと確認すること（Development Rules 11参照）。

---

# Development Rules

このプロジェクトでコードを変更・実行する際は、以下のルールに従うこと。

1. 既存コードを変更する前に、関連ファイル（該当スクリプト、対応するREADMEの節、`PROJECT_SUMMARY.md`の関連記述）を確認する。
2. 元データ（`raw/`、`/media/sf_share/.../MRI_Raw`）を直接変更しない。
3. 既存の解析結果（`preproc/sub-*`, `derivatives/*/sub-*`, `freesurfer_subjects/sub-*`等）を勝手に上書きしない。上書きが必要な場合は明示的な確認を取る。
4. 入力・出力ファイルを明確にする（特にMRtrixの `.mif` はどのステップの出力かを明記する）。
5. 解析条件・パラメータ（`-algorithm`, `-angle`, `-select`, `-maxlength`など）を変更する場合は明示し、変更理由を記録する。
6. 乱数を使用する場合（確率的トラクトグラフィー等）はseedを固定する。既存スクリプトにseed固定の記述がない場合は、追加前にユーザーに確認する。
7. 大規模解析（全227被験者への展開）の前に少数被験者でテストする。
8. 実行時間が長い処理（TOPUP、eddy、トラクトグラフィー等）では、まずsubsetまたは`--dry-run`で動作確認する。
9. エラーが発生した場合、原因を確認してから修正する（憶測で回避策を入れない）。過去の障害調査例：`derivatives/dticsd/ERROR_REPORT_5TTGen_FIRST_Failure.md`。
10. 既存の研究方針（FreeSurfer方式への切り替え、pyAFQのtractogramインポート方式など）を勝手に変更しない。
11. 研究上の判断（解析パラメータの選定、bundle定義の変更、年齢群の定義など）が必要な場合は、コードを変更する前に確認する。
12. 不明なパラメータやデータ仕様を推測しない。本ファイルの `TODO: Confirm ...` 項目は、実際のファイル・ログから確認できてから埋める。
13. 実際のファイル・コード・設定から確認できた情報を優先する（本ファイルの記述より実際のコードが正）。
14. 「実装済み」「実行済み」「予定」「仮説」を明確に区別する（本ファイルの「Current Progress」「Planned Analysis」の区分を維持する）。
15. 解析結果を生成するコードでは、再現性を確保する（使用したコマンド・パラメータ・ソフトウェアバージョンをログに残す）。
16. 被験者IDの対応関係（`sub-XXXXXX`、EEG側のID等）を変更・推測しない。
17. 新しい処理を追加する場合、既存の自動実行パイプライン（`auto_run.sh`, `scripts/resume_freesurfer_afq.sh`, `scripts/*_auto.sh`）への影響を確認する。

---

# Important Notes

- `auto_run.sh` と他の3スクリプト（`s_tractography_ROI_9.sh`, `s_tractography_ROI_parameters_11.sh`, `s_tractography_wholebrain_10.sh`）にあった未コミットの変更は2026-09-26にコミット済み。作業開始前は念のため `git status`/`git diff` で最新状態を確認すること。
- パイプラインは **FSL方式** と **FreeSurfer(SynthSeg)方式** の2系統があり、`TTGEN_METHOD`（`fsl`/`freesurfer`）で切り替える。FSL方式は5ttgen(FIRST)のsegfault既知問題があるため、5TT生成に関しては**FreeSurfer方式が推奨されている**（`PROJECT_SUMMARY.md`参照）。
- Step 9/10のトラクトグラフィーは、以前は環境変数（`TRACT_INPUT`, `WM_FOD`, `ACT_5TT`等）を明示的に指定しないと、意図しない入力（元DWIやACTなし）で実行されてしまう既知の落とし穴があった（「DTI Analysis Pipeline」内の既知の注意点を参照）。2026-09-26の修正により、環境変数を指定しなくても被験者別のWM FOD・5TTが既定値として使われるようになった。
- pyAFQは自前でトラクトグラフィーを行わず、MRtrixの`.tck`をインポートする構成になっている点に注意（純粋なpyAFQデフォルトパイプラインとは異なる）。
- FreeSurferは `recon-all` を使用しておらず、`mri_synthseg` による自動セグメンテーションのみを行っている。皮質厚・表面積などのFreeSurfer標準の構造指標は算出されていない。
- EEG関連の情報（解析コード、データ、進捗）は本リポジトリの外にあると考えられる。EEG側の情報が必要な作業を依頼された場合は、まずユーザーに実体のパス・状況を確認すること。
