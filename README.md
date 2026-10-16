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

`file_manifest.json` and `SHA256SUMS.txt` record the paths, sizes and SHA-256 checksums of all 1,030 files in the original `EV Code` folder. Thirty files are stored directly in this repository, and 1,000 matrices are stored in the release archive. Restoring the release inputs recovers the complete original file structure. To check the archive without extracting it, run `python download_mc_inputs.py --verify-only`.

The README, checksum manifest and download helper are publication aids outside the original `EV Code` directory.
