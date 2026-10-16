# EV-ICIO

R code and input data for the EV–ICIO analysis.

The original `EV Code` scripts and input files are provided without changes to their contents. The folder contains four analysis modules:

| Directory | Analysis |
| --- | --- |
| `EV Code/Fig3_production` | Vehicle production emissions and Monte Carlo calculations |
| `EV Code/Fig4_sector` | Sector contributions to production emissions |
| `EV Code/Fig5_lifecycle` | Vehicle life-cycle emissions |
| `EV Code/Fig6_parity` | Carbon-parity times and scenarios |

## Large Monte Carlo inputs

The 1,000 `A_MC_*.rds` files total approximately 36 GiB. They are distributed as assets of the **Monte Carlo input matrices** release rather than stored in Git history.

After downloading or cloning this repository, run the following command from its root to download the matrices into their original directory:

```sh
python download_mc_inputs.py
```

The downloader requires Python 3.11 or newer and uses only its standard library. It resumes by skipping files whose SHA-256 checksums already match and verifies every downloaded file. Allow approximately 37 GiB of additional disk space for the matrices. Files must be present in:

```text
EV Code/Fig3_production/input/MC/
```

Alternatively, use GitHub CLI:

```sh
gh release download mc-inputs-20261016 --repo evteams/EV-ICIO --pattern "A_MC_*.rds" --dir "EV Code/Fig3_production/input/MC"
```

## Running an analysis

Run the relevant R script with its adjacent `input` directory available. For example, from this repository's root:

```sh
Rscript "EV Code/Fig3_production/Fig3_production.R"
Rscript "EV Code/Fig4_sector/Fig4_sector.R"
Rscript "EV Code/Fig5_lifecycle/Fig5_lifecycle.R"
Rscript "EV Code/Fig6_parity/Fig6_parity.R"
```

See the original scripts for required R packages and analysis settings. Output directories are created by the scripts. The Figure 3 Monte Carlo analysis uses the large input matrices described above.

## File integrity

`file_manifest.json` and `SHA256SUMS.txt` record the paths, sizes and SHA-256 checksums of all 1,030 files in the original `EV Code` folder. Thirty files are stored directly in this repository, and 1,000 matrices are stored as release assets. Downloading the release inputs restores the complete original file structure.

The README, checksum manifest and download helper are publication aids outside the original `EV Code` directory.
