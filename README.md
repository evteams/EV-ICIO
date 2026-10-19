# EV-ICIO

R code and input data for EV–ICIO table construction and the production of data and results reported in the paper.

The repository contains two stages: `EV-table-construction/` establishes the EV table and its Monte Carlo matrices; `EV Code/` produces the paper's analysis data and results.

## EV-table construction

The following three original files are provided in [`EV-table-construction/`](EV-table-construction/) without changes to their contents:

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
| `EV Code/Fig4_sector` | Sector contributions to production emissions |
| `EV Code/Fig5_lifecycle` | Vehicle life-cycle emissions |
| `EV Code/Fig6_parity` | Independent main-text and SI carbon-parity packages |

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
Rscript "EV Code/Fig6_parity/main_text/Fig6_parity.R"
Rscript "EV Code/Fig6_parity/SI/Fig6_SI.R"
```

See the original scripts for required R packages and analysis settings. Output directories are created by the scripts. The Figure 3 Monte Carlo analysis uses the large input matrices described above.

## Figure 6 mileage correction (2026-10-19)

Figure 6 now has independent `main_text/` and `SI/` folders, each with its own R script and complete `input/`. The former `EV Code/Fig6_parity/Fig6_parity.R` command is retained as a main-text compatibility entry.

Annual mileage follows the manuscript table: China 10,220; Germany 12,320; Japan 8,060; South Korea 11,936; Mexico 12,832; United States 17,873 km/vehicle/year. Within each country, BEV, PHEV and ICEV use the same fixed mileage. ICEV WTT and TTW are stored per kilometre and converted to annual emissions by the code, preventing obsolete annual totals from persisting after a mileage edit.

This update replaces Figure 6 inputs and code only. Formal simulation outputs and figures have not been regenerated or uploaded. The 1,000 A matrices and their release archive are unchanged.

## File integrity

`file_manifest.json` and `SHA256SUMS.txt` record the paths, sizes and SHA-256 checksums of all 1,043 files in the current `EV Code` folder. 43 files are stored directly in this repository, and 1,000 matrices are stored in the release archive. Restoring the release inputs recovers the complete original file structure. To check the archive without extracting it, run `python download_mc_inputs.py --verify-only`.

The README, checksum manifest and download helper are publication aids outside the `EV Code` directory.

`EV_table_construction_manifest.json` separately records the paths, sizes and SHA-256 checksums of the three original construction files. Their checksums are also included in `SHA256SUMS.txt`.
