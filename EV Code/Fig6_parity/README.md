# Figure 6 main-text calculation

This directory contains the main-text R calculation and its own input data only. SI scripts, SI inputs, simulation outputs and plotting files are not included.

## Run

From the repository root:

```sh
Rscript "EV Code/Fig6_parity/Fig6_parity.R"
```

Alternatively, open the complete `Fig6_parity.R` script in RStudio and source it. The script uses base R, resolves its adjacent `input/` directory automatically, and writes results to `output/`.

## Inputs

| File | Contents |
| --- | --- |
| `production_coefficients_EV.csv` | EV production coefficients for the original 1,000 A realizations, with supplier-country electricity contributions |
| `production_coefficients_ICEV.csv` | Fixed ICEV production coefficients and electricity contributions |
| `production_calibration.csv` | Production-calibration values and MD5 hashes binding the EV/ICEV coefficient files to this version |
| `vehicle_price_ranges_2023.csv` | EV and ICEV price bounds in USD/vehicle |
| `grid_factors_2023_2030.csv` | Fixed BAU, Solar, Wind and ACES electricity pathways |
| `vehicle_use_2023.csv` | Vehicle shares, energy use, calibrated grid intensities, annual mileage, gasoline factors and ICEV per-kilometre WTT/TTW intensities |
| `sampling_ranges.csv` | Uniform bounds for UF, the shared PHEV energy multiplier and the MEG endpoint |
| `scenarios_main_text.csv` | BAU, Solar, Wind, MEG, ACES and ACES + MEG definitions |

Annual mileage is fixed at China 10,220; Germany 12,320; Japan 8,060; South Korea 11,936; Mexico 12,832; United States 17,873 km/vehicle/year. Within each country, BEV, PHEV and ICEV use the same `annual_km`. ICEV WTT/TTW inputs are in kg CO2/km; the code multiplies these by current annual mileage and divides by 1,000 to obtain t CO2/year. Vehicle energy consumption and the calibrated BEV/PHEV electricity intensities are unchanged.

Updated on 21 October 2026: the included production coefficients already apply China's sector-D raw direct emission intensity multiplied by 1.12533 and China's C27 intensity fixed at 0.0156 kt CO2 per million USD, for EV production only. ICEV intensities remain unadjusted. The script checks the supplied calibration metadata and coefficient-file hashes before running. Physical use-stage grid intensities are separate inputs and are not rescaled by these monetary-intensity adjustments.

The calculation crosses 1,000 A realizations with 5,000 paired price/use vectors per country. UF and the shared PHEV electricity/fuel multiplier are independent; the MEG endpoint is sampled from 3%-7% and phased in linearly to 2030. Seeds, scenario paths and no-recycling assumptions are unchanged. Low and High are the 2.5th and 97.5th simulation percentiles, not confidence intervals for a mean. Signed parity uses production-year use-phase intensities, held fixed during payback.

This upload replaces code and inputs only. Full simulation outputs and figures have not been regenerated or uploaded. The author's local SI package is unchanged; prior published versions remain recoverable through Git history.
