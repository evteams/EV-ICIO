# EV-ICIO

R code and input data for EV–ICIO table construction and the production of data and results reported in the paper.

The repository contains two stages: `EV-table-construction/` establishes the EV table and its Monte Carlo matrices; `EV Code/` produces the paper's analysis data and results.

## EV-table construction

The following construction scripts and the current author-supplied parameter workbook are provided in [`EV-table-construction/`](EV-table-construction/):

| File | Role |
| --- | --- |
| [`EVmodel.R`](EV-table-construction/EVmodel.R) | Constructs baseline EV–ICIO technical coefficients and splits final demand into EV and conventional-vehicle accounts |
| [`MC.R`](EV-table-construction/MC.R) | Independently constructs Monte Carlo coefficient matrices; the default setting generates 1,000 `A_MC_*.rds` files |
| [`Adata_v6.xlsx`](EV-table-construction/Adata_v6.xlsx) | Parameter workbook containing country selection, bill-of-materials shares, sourcing parameters and trade inputs |

The scripts also read external `2022_SML.csv` and `2017_SML.csv` ICIO source tables, which are not included among these three files. They retain their original path settings, with `D:/Data/EV` as the default project directory; see their settings blocks and supported environment variables when preparing inputs and output locations. `EVmodel.R` requires the R package `openxlsx`; `MC.R` requires `openxlsx` and `Matrix`.

## Paper data production and analysis

The `EV Code` folder contains the current analysis scripts and input data. Corrections are recorded in Git history and the module READMEs. It contains four analysis modules:

| Directory | Analysis |
| --- | --- |
| `EV Code/Fig3_production` | Vehicle production emissions and Monte Carlo calculations |
| `EV Code/Fig4_sector` | Sector-share Monte Carlo medians and uncertainty intervals |
| `EV Code/Fig5_lifecycle` | Vehicle life-cycle emissions |
| `EV Code/Fig6_parity` | Carbon parity times and scenarios |

## Large Monte Carlo inputs

The 1,000 `A_MC_*.rds` files total approximately 36 GiB. They are distributed in a lossless archive attached to the [Monte Carlo input matrices release](https://github.com/evteams/EV-ICIO/releases/tag/mc-inputs-20261016).

After downloading or cloning this repository, run the following command from its root to download the matrices into their original directory:

```sh
python download_mc_inputs.py
```

The downloader requires Python 3.11 or newer and uses only its standard library. It verifies the archive and all 1,000 original files against their SHA-256 checksums, and restores the original directory structure. Existing files whose checksums match are retained. Allow approximately 38 GiB of disk space for the archive and matrices. Files must be present in:

```text
EV Code/Fig3_production/input/MC/
```

Alternatively, download the archive from the release page or use GitHub CLI, then run the helper to verify and extract it:

```sh
gh release download mc-inputs-20261016 --repo evteams/EV-ICIO --pattern "EV-ICIO_MC_inputs.tar.xz"
python download_mc_inputs.py --archive EV-ICIO_MC_inputs.tar.xz
```

## Running the paper analyses

Run the relevant R script with its adjacent `input` directory available. For example, from this repository's root:

```sh
Rscript "EV Code/Fig3_production/Fig3_production.R"
Rscript "EV Code/Fig4_sector/Fig4_sector.R"
Rscript "EV Code/Fig5_lifecycle/Fig5_lifecycle.R"
Rscript "EV Code/Fig6_parity/Fig6_parity.R"
```

See the original scripts for required R packages and analysis settings. Output directories are created by the scripts. The Figure 3 Monte Carlo analysis uses the large input matrices described above.

### Analysis input update on 21 October 2026

The code and required inputs in the four analysis modules were synchronized with the author's updated analysis folders. For EV production, China's sector-D direct emission intensity is the original value multiplied by 1.12533, and China's C27 intensity is set directly to 0.0156 kt CO2 per million USD. ICEV calculations retain the original emission intensities. The included Fig5 and Fig6 production inputs use the same calibration; do not apply these adjustments a second time to those intermediate inputs.

Fig4 now evaluates the original 1,000 EV A matrices and exports MC sector-share medians and intervals. Fig5 retains its existing recycling treatment. Fig6 contains only the main-text scenarios, excludes recycling, and uses production-year use-phase intensities. No SI packages, plotting files or simulation outputs are included in this synchronization.

Fig5 and Fig6 can be run with their included compact production inputs. Running Fig3 writes its results to its own output directory; it does not automatically overwrite the inputs of the other modules. The original A files remain unchanged and continue to be distributed through the existing release archive.



## File integrity

`file_manifest.json` and `SHA256SUMS.txt` record the paths, sizes and SHA-256 checksums of all 1,029 files in the current `EV Code` folder. 29 files are stored directly in this repository, and 1,000 matrices are stored in the release archive. Restoring the release inputs recovers the complete analysis input structure. To check the archive without extracting it, run `python download_mc_inputs.py --verify-only`.

The README, checksum manifest and download helper are publication aids outside the `EV Code` directory.

`EV_table_construction_manifest.json` separately records the paths, sizes and SHA-256 checksums of the three construction files, including the current parameter workbook. Their checksums are also included in `SHA256SUMS.txt`.
