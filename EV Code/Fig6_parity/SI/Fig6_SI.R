# Figure 6 SI technology-scenario Monte Carlo analysis / 图6 SI技术情景MC。
# BAU, Battery, Steel, ACES, ACES + Battery, ACES + Steel, ACES + Battery + Steel.
# 对应SI图：六种相对BAU情景，以及左上角BAU绝对parity。
# Core calculations only: no recycling, plotting or reference-result checks.
# 仅保留核心计算：不计回收，不含制图代码和结果核对步骤。

# 1. Settings and portable paths / 参数与可移动路径
Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
input_dir <- file.path(project_dir, "input")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

countries <- c("CHN", "DEU", "JPN", "KOR", "MEX", "USA")
years <- 2023:2030
n_joint <- 5000L
price_seed <- 20261005L
use_seed <- 2026100601L
read_input <- function(name) read.csv(file.path(input_dir, name), check.names = FALSE)
coeff_EV <- read_input("production_coefficients_EV.csv")
coeff_ICEV <- read_input("production_coefficients_ICEV.csv")
price_ranges <- read_input("vehicle_price_ranges_2023.csv")
grid <- read_input("grid_factors_2023_2030.csv")
vehicle <- read_input("vehicle_use_2023.csv")
steel_path <- read_input("steel_factors_2023_2030.csv")
battery <- read_input("battery_parameters.csv")
ranges <- read_input("sampling_ranges.csv")
scenario_table <- read_input("scenarios_SI.csv")
scenarios <- scenario_table$Scenario
electricity_columns <- names(coeff_EV)[startsWith(names(coeff_EV), "D_")]
suppliers <- substring(electricity_columns, 3)

# 2. Price and use draws / 每国5000组价格与使用参数，跨年份/情景共享
uniform_draws <- function(variable) {
  r <- ranges[ranges$Variable == variable, ]
  runif(n_joint, r$Lower, r$Upper)
}
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(price_seed)
price_draws <- list()
for (cc in countries) {
  ev_range <- price_ranges[price_ranges$Country == cc & price_ranges$Vehicle == "EV", ]
  ice_range <- price_ranges[price_ranges$Country == cc & price_ranges$Vehicle == "ICEV", ]
  price_draws[[cc]] <- data.frame(Sample_id = seq_len(n_joint),
    Price_EV_USD = runif(n_joint, ev_range$Price_min_USD, ev_range$Price_max_USD),
    Price_ICEV_USD = runif(n_joint, ice_range$Price_min_USD, ice_range$Price_max_USD))
}
set.seed(use_seed)
use_draws <- list()
for (cc in countries) {
  use_draws[[cc]] <- data.frame(Sample_id = seq_len(n_joint), UF = uniform_draws("UF"),
    PHEV_energy_multiplier = uniform_draws("PHEV_energy_multiplier"))
}
# EV和ICEV价格独立抽样；相同编号用于配对，不表示两种价格相等。
# Unified with Fig5: UF is independent of q; one shared q affects PHEV EC and FC.
# 与图5统一：UF独立于q；同一q同时作用于PHEV电耗和油耗，汽油WTT/TTW共用。

# 3. Annual battery chemistry and steel paths / 年度技术路径
phase <- (years - min(years)) / (max(years) - min(years))
lfp_share <- battery$LFP_share_2023 + (battery$LFP_share_2030 - battery$LFP_share_2023) * phase
chemistry_intensity <- (1 - lfp_share) * battery$NMC811_kgCO2e_per_kWh +
  lfp_share * battery$LFP_kgCO2e_per_kWh
battery_reduction <- battery$Battery_component_2023_tCO2e_per_EV *
  (1 - chemistry_intensity / chemistry_intensity[1])
steel_factor <- steel_path$Steel_factor_vs_2023[match(years, steel_path$Year)]
# 6.17 t is an existing battery-component proxy, not an extra production burden.
# 6.17t是基期电池组成代理：只扣化学替代带来的减排，不再次加6.17。

# 4. Distribution summaries / 中位数及95%分位区间，不是均值置信区间
statistics <- function(x, suffix) {
  total <- length(x)
  finite <- as.numeric(x)
  finite <- finite[is.finite(finite)]
  q <- if (length(finite)) quantile(finite, c(.025, .5, .975), names = FALSE, type = 7) else rep(NA_real_, 3)
  out <- data.frame(Mean = if (length(finite)) mean(finite) else NA_real_,
    Median = q[2], Low = q[1], High = q[3], SD = if (length(finite) > 1) sd(finite) else NA_real_,
    N_total = total, N_finite = length(finite), N_negative = sum(finite < 0))
  names(out) <- paste0(names(out), suffix)
  out
}
parity_rows <- advance_rows <- use_rows <- list()
factorized <- list()

# 5. Scenario calculations / 固定A，按供应国改变D和C24A排放系数
for (cc in countries) {
  message("Fig6 SI: ", cc)
  e <- coeff_EV[coeff_EV$Country == cc, ]
  e <- e[order(e$A_id), ]
  i <- coeff_ICEV[coeff_ICEV$Country == cc, ]
  v <- vehicle[vehicle$Country == cc, ]
  # One country-specific annual mileage for BEV, PHEV and ICEV (km/vehicle/year).
  # 同一国家三种车型统一使用annual_km；ICEV由每公里强度计算年排放。
  annual_km <- v$annual_km
  v$ICEV_WTT <- v$ICEV_WTT_kgCO2_per_km * annual_km / 1000
  v$ICEV_TTW <- v$ICEV_TTW_kgCO2_per_km * annual_km / 1000
  p <- price_draws[[cc]]
  u <- use_draws[[cc]]
  # e/i: production coefficients; v: fixed vehicle parameters; p/u: paired draws.
  # e/i为生产系数，v为固定车辆参数，p/u为同编号的价格/使用抽样。
  n_A <- nrow(e)
  country_grid <- grid[grid$Country == cc, ]
  country_grid <- country_grid[match(years, country_grid$Year), ]
  b_EV <- array(NA_real_, c(n_A, length(years), length(scenarios)),
    dimnames = list(e$A_id, years, scenarios))
  b_ICEV <- matrix(NA_real_, length(years), length(scenarios), dimnames = list(years, scenarios))
  annual_saving <- electric_WTT <- array(NA_real_, c(length(years), n_joint, length(scenarios)),
    dimnames = list(years, u$Sample_id, scenarios))

  # Gasoline factors and TTW stay fixed at 2023 values / 汽油因子及TTW不随电网变化
  gasoline_WTT <- v$PHEV_share * (1 - u$UF) * v$PHEV_FC * u$PHEV_energy_multiplier *
    v$PHEV_k_rw_fuel * v$gas_WTT_total * annual_km / 1000
  driving_TTW <- v$PHEV_share * (1 - u$UF) * v$PHEV_FC * u$PHEV_energy_multiplier *
    v$PHEV_k_rw_fuel * v$gas_TTW_EF * annual_km / 1000
  ICEV_annual <- v$ICEV_WTT + v$ICEV_TTW

  for (yi in seq_along(years)) {
    year <- years[yi]
    supplier_grid <- grid[grid$Year == year, ]
    supplier_grid <- supplier_grid[match(suppliers, supplier_grid$Country), ]
    # Preserve BEV/PHEV-specific calibrated direct intensities and indirect/direct ratios.
    # 保留中美等车型各自校准强度；间接强度=直接强度×间接/直接比例。
    bau_factor <- country_grid$BAU[yi]
    bev_grid <- v$BEV_grid_direct_2023 * bau_factor +
      v$BEV_grid_direct_2023 * v$BEV_grid_indirect_share * bau_factor
    phev_grid <- v$PHEV_grid_direct_2023 * bau_factor +
      v$PHEV_grid_direct_2023 * v$PHEV_grid_indirect_share * bau_factor
    bev_electric <- v$BEV_EC * v$BEV_k_rw * v$BEV_k_loss * bev_grid * annual_km / 1000
    phev_electric <- u$UF * v$PHEV_EC * u$PHEV_energy_multiplier *
      v$PHEV_k_rw_elec * v$PHEV_k_loss * phev_grid * annual_km / 1000
    electric_BAU <- v$BEV_share * bev_electric + v$PHEV_share * phev_electric

    for (si in seq_along(scenarios)) {
      scenario <- scenario_table[si, ]
      name <- scenario$Scenario
      grid_path <- scenario$Grid_path
      # Exact emission-vector update for fixed A / 固定A下的精确系数重组，不需再求逆。
      new_ev <- e$b_total + as.numeric(as.matrix(e[, electricity_columns]) %*% (supplier_grid[[grid_path]] - 1))
      new_ice <- i$b_total + sum(as.numeric(i[, electricity_columns]) * (supplier_grid[[grid_path]] - 1))
      if (scenario$Steel == 1) {
        new_ev <- new_ev + e$b_C24A * (steel_factor[yi] - 1)
        new_ice <- new_ice + i$b_C24A * (steel_factor[yi] - 1)
      }
      delta <- if (scenario$Battery == 1) battery_reduction[yi] else 0
      electricity <- electric_BAU * country_grid[[grid_path]][yi] / bau_factor
      saving <- ICEV_annual - electricity - gasoline_WTT - driving_TTW
      # b: kt CO2/million USD; price: USD/vehicle; production: t CO2/vehicle.
      production_EV <- outer(new_ev, p$Price_EV_USD) / 1000 - delta
      production_ICEV <- new_ice * p$Price_ICEV_USD / 1000
      premium <- sweep(production_EV, 2, production_ICEV, "-")
      tau <- sweep(premium, 2, saving, "/")
      tau[, saving <= 0] <- NA_real_
      # 保留负生产差对应的负parity；年使用减排非正则记NA，不伪造有限追平时间。
      # Production-year snapshot: hold this year's use emissions constant throughout parity.
      if (name == "BAU") {
        tau_BAU <- tau
        median_BAU <- median(tau_BAU, na.rm = TRUE)
      }
      parity_rows[[length(parity_rows) + 1]] <- cbind(data.frame(Country = cc, Year = year,
        Scenario = name, N_A = n_A, N_joint = n_joint,
        N_nonpositive_annual_saving = sum(saving <= 0) * n_A), statistics(tau, "_years"))
      if (name != "BAU") {
        advance <- tau_BAU - tau
        percent <- 100 * advance / tau_BAU
        percent[!is.finite(tau_BAU) | tau_BAU <= 0] <- NA_real_
        median_scenario <- median(tau, na.rm = TRUE)
        advance_rows[[length(advance_rows) + 1]] <- cbind(data.frame(Country = cc, Year = year, Scenario = name),
          statistics(advance, "_Advance_years"), statistics(percent, "_Advance_percent"),
          Difference_of_medians_years = median_BAU - median_scenario,
          Reduction_of_medians_percent = if (is.finite(median_BAU) && median_BAU > 0)
            100 * (median_BAU - median_scenario) / median_BAU else NA_real_)
        rm(advance, percent)
      }
      use_rows[[length(use_rows) + 1]] <- cbind(data.frame(Country = cc, Year = year, Scenario = name,
        ICEV_WTT = v$ICEV_WTT, ICEV_TTW = v$ICEV_TTW,
        Mean_EV_production_t = mean(production_EV), Mean_ICEV_production_t = mean(production_ICEV)),
        statistics(electricity, "_Electric_WTT"), statistics(gasoline_WTT, "_Gasoline_WTT"),
        statistics(driving_TTW, "_TTW"), statistics(saving, "_Annual_saving"))
      b_EV[, yi, name] <- new_ev
      b_ICEV[yi, name] <- new_ice
      annual_saving[yi, , name] <- saving
      electric_WTT[yi, , name] <- electricity
      rm(production_EV, production_ICEV, premium, tau)
    }
    message("  ", year, " complete")
  }
  factorized[[cc]] <- list(A_id = e$A_id, Prices = p, Use_draws = u, b_EV = b_EV, b_ICEV = b_ICEV,
    Annual_mileage_km_per_vehicle_year = annual_km,
    Annual_saving = annual_saving, Electric_WTT = electric_WTT,
    Gasoline_WTT = gasoline_WTT, TTW = driving_TTW, ICEV_annual_tCO2 = ICEV_annual)
  rm(tau_BAU)
  invisible(gc(FALSE))
}

# 6. Save data, not graphs / 仅保存数据；完整交叉分布用因子分解文件重建
parity <- do.call(rbind, parity_rows)
advance <- do.call(rbind, advance_rows)
write.csv(parity, file.path(output_dir, "Fig6_SI_parity_2023_2030.csv"), row.names = FALSE)
write.csv(advance, file.path(output_dir, "Fig6_SI_advance_vs_BAU_2023_2030.csv"), row.names = FALSE)
write.csv(do.call(rbind, use_rows), file.path(output_dir, "Fig6_SI_production_and_use_summary.csv"), row.names = FALSE)
joint <- lapply(countries, function(cc) cbind(Country = cc, price_draws[[cc]], use_draws[[cc]][-1]))
write.csv(do.call(rbind, joint), file.path(output_dir, "Fig6_SI_price_use_draws.csv"), row.names = FALSE)
write.csv(data.frame(Year = years, LFP_capacity_share = lfp_share,
  Battery_intensity_kgCO2e_per_kWh = chemistry_intensity,
  Battery_reduction_tCO2e_per_EV = battery_reduction, Steel_factor_vs_2023 = steel_factor),
  file.path(output_dir, "Fig6_SI_annual_technology_parameters.csv"), row.names = FALSE)
saveRDS(list(Settings = list(Years = years, Scenarios = scenario_table, N_joint = n_joint,
  Price_seed = price_seed, Use_seed = use_seed,
  Use_sampling = "UF independent of one shared PHEV electricity/fuel multiplier",
  Annual_mileage_km_per_vehicle_year = setNames(vehicle$annual_km, vehicle$Country),
  Mileage_scope = "Same fixed country mileage for BEV, PHEV and ICEV; ICEV annual WTT/TTW calculated from kg CO2/km",
  Interval_level = 0.95, Interval_probabilities = c(.025, .975), Quantile_type = 7L,
  No_recycling = TRUE, Parity = "signed production-year snapshot"),
  Battery_reduction_tCO2e_per_EV = battery_reduction, Countries = factorized),
  file.path(output_dir, "Fig6_SI_factorized_MC.rds"))
message("Fig6 SI complete: ", output_dir)
