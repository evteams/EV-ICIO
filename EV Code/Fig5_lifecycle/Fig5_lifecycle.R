
# Figure 5: manufacturing + energy production + driving + recycling


# 1. Settings and relative paths
Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
seed <- 20260919L
lifetime_km <- 200000
countries <- c("CHN", "DEU", "JPN", "KOR", "MEX", "USA")
stages <- c("Production", "Energy production", "Driving", "Recycling", "Total")

source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
input_dir <- file.path(project_dir, "input")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, showWarnings = FALSE)
read_input <- function(file) read.csv(file.path(input_dir, file), fileEncoding = "UTF-8-BOM")

# 2. Read original values and Fig3 draws
energy <- read_input("vehicle_energy_2023.csv")
grid <- read_input("grid_intensity_2023.csv")
gasoline <- read_input("gasoline_intensity_2023.csv")
sales_mix <- read_input("bev_phev_sales_2023.csv")
recycling <- read_input("recycling_credit_fractions.csv")
ranges <- read_input("sampling_ranges.csv")
production <- readRDS(file.path(input_dir, "production_draws.rds"))
n_A <- production$Settings$N_A_EV
n_price <- production$Settings$N_price
n_lifecycle <- n_A * n_price

draw_uniform <- function(parameter, n) {
  r <- ranges[ranges$Parameter == parameter, ]
  runif(n, r$Low, r$High)
}
summarize_MC <- function(x) {
  # Central 95% simulation uncertainty interval, not a confidence interval for the mean.
  q <- quantile(x, c(.025, .5, .975), names = FALSE, type = 7)
  data.frame(N = length(x), Mean = mean(x), Median = q[2], Low = q[1], High = q[3], SD = sd(x))
}
stage_rows <- difference_rows <- list()
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(seed)

# 3. Country-by-country MC
for (cc in countries) {
  message("Fig5 ", cc, ": ", n_A, " A x ", n_price, " prices = ", n_lifecycle, " EV/use cases")
  e <- energy[energy$Country == cc, ]
  g <- grid[grid$Country == cc, ]
  f <- gasoline[gasoline$Country == cc, ]
  s <- sales_mix[sales_mix$Country == cc, ]
  r <- recycling[recycling$Country == cc, ]
  BEV_share <- s$BEV_sales_source_units / (s$BEV_sales_source_units + s$PHEV_sales_source_units)
  PHEV_share <- 1 - BEV_share
  credit_EV <- r$Credit_fraction[r$Vehicle == "EV"]
  credit_ICEV <- r$Credit_fraction[r$Vehicle == "ICEV"]

  # Indirect intensity = calibrated direct intensity x original ratio.
  grid_BEV <- g$BEV_direct_kgCO2_kWh * (1 + g$BEV_indirect_direct_ratio)
  grid_PHEV <- g$PHEV_direct_kgCO2_kWh * (1 + g$PHEV_indirect_direct_ratio)
  gasoline_PHEV <- f$PHEV_WTT_direct_kgCO2_L * (1 + f$PHEV_WTT_indirect_direct_ratio)
  gasoline_ICEV <- f$ICEV_WTT_direct_kgCO2_L * (1 + f$ICEV_WTT_indirect_direct_ratio)

  prices <- production$Price_draws[[cc]]
  coefficient_EV <- production$EV_coefficients[, cc, "Total"]
  coefficient_ICEV <- production$ICEV_coefficients[cc, "Total"]
  # b: kt CO2/million USD; price: USD/vehicle; b x price / 1000: t CO2/vehicle.
  EV_production <- as.vector(outer(prices$Price_EV_USD / 1000, coefficient_EV))
  ICEV_production <- coefficient_ICEV * prices$Price_ICEV_USD / 1000

  # One independent use realization per A-price case: 5,000,000 per country.
  # UF is independent of q; one shared q changes PHEV electricity and fuel consumption.
  UF <- draw_uniform("UF", n_lifecycle)
  q_energy <- draw_uniform("PHEV_energy_multiplier", n_lifecycle)
  km_to_tonnes <- lifetime_km / 1000  # kg/km x km -> t CO2

  # Energy production
  BEV_WTT <- e$BEV_EC_kWh_km * e$BEV_k_rw * e$BEV_k_loss * grid_BEV * km_to_tonnes
  PHEV_WTT <- UF * e$PHEV_EC_kWh_km * q_energy * e$PHEV_k_rw_elec *
    e$PHEV_k_loss * grid_PHEV * km_to_tonnes +
    (1 - UF) * e$PHEV_FC_L_km * q_energy * e$PHEV_k_rw_fuel * gasoline_PHEV * km_to_tonnes
  ICEV_WTT <- e$ICEV_FC_WTT_L_km * e$ICEV_k_rw_WTT * gasoline_ICEV * km_to_tonnes

  # Driving 
  PHEV_driving <- (1 - UF) * e$PHEV_FC_L_km * q_energy * e$PHEV_k_rw_fuel *
    f$PHEV_TTW_kgCO2_L * km_to_tonnes
  ICEV_driving <- e$ICEV_FC_TTW_L_km * e$ICEV_k_rw_TTW * f$ICEV_TTW_kgCO2_L * km_to_tonnes
  EV <- list(Production = EV_production,
    "Energy production" = BEV_share * BEV_WTT + PHEV_share * PHEV_WTT,
    Driving = PHEV_share * PHEV_driving)
  
  # ICEV has one fixed A and 5000 prices. Do not claim 5 million unique ICEV draws.
  ICEV <- list(Production = ICEV_production,
    "Energy production" = rep(ICEV_WTT, n_price), Driving = rep(ICEV_driving, n_price))

  # Fixed-fraction recycling credit; normally negative 
  EV$Recycling <- credit_EV * Reduce(`+`, EV)
  ICEV$Recycling <- credit_ICEV * Reduce(`+`, ICEV)
  EV$Total <- Reduce(`+`, EV)
  ICEV$Total <- Reduce(`+`, ICEV)
  draws <- list(EV = EV, ICEV = ICEV)

  for (vehicle in names(draws)) {
    for (stage in stages) {
      stage_rows[[length(stage_rows) + 1L]] <- cbind(
        data.frame(Country = cc, Vehicle = vehicle, Stage = stage),
        summarize_MC(draws[[vehicle]][[stage]]), Unit = "t CO2/vehicle")
    }
  }
  
  # Pair ICEV by the same price ID; calculate differences BEFORE quantiles.
  for (stage in stages) {
    difference <- EV[[stage]] - rep(ICEV[[stage]], times = n_A)
    difference_rows[[length(difference_rows) + 1L]] <- cbind(
      data.frame(Country = cc, Stage = stage), summarize_MC(difference),
      Probability_EV_lower = mean(difference < 0),
      Difference = "EV - ICEV", Unit = "t CO2/vehicle")
  }

  rm(draws, EV, ICEV, difference, EV_production, ICEV_production, UF, q_energy,
     PHEV_WTT, PHEV_driving)
  invisible(gc(FALSE))
}

# 4. Save stage, paired-difference and total results
stage_summary <- do.call(rbind, stage_rows)
difference_summary <- do.call(rbind, difference_rows)
total_table <- function(table, prefix) {
  x <- table[table$Stage == "Total", c("Country", "N", "Mean", "Median", "Low", "High", "SD")]
  names(x)[-1] <- paste0(prefix, "_", names(x)[-1])
  x
}
total_EV <- total_table(stage_summary[stage_summary$Vehicle == "EV", ], "EV")
total_ICEV <- total_table(stage_summary[stage_summary$Vehicle == "ICEV", ], "ICEV")
total_difference <- total_table(difference_summary, "EV_minus_ICEV")
total_summary <- Reduce(function(x, y) merge(x, y, by = "Country", sort = FALSE),
  list(total_EV, total_ICEV, total_difference))
total_summary <- total_summary[match(countries, total_summary$Country), ]
total_summary$Unit <- "t CO2/vehicle"

write.csv(stage_summary, file.path(output_dir, "Fig5_stage_summary.csv"), row.names = FALSE)
write.csv(difference_summary, file.path(output_dir, "Fig5_EV_minus_ICEV_summary.csv"), row.names = FALSE)
write.csv(total_summary, file.path(output_dir, "Fig5_total_summary.csv"), row.names = FALSE)
saveRDS(list(Settings = list(Countries = countries, Lifetime_km = lifetime_km, Seed = seed,
  N_A_EV = n_A, N_A_ICEV = 1L, N_price = n_price, N_use_per_country = n_lifecycle,
  Use_sampling = "UF independent of one shared PHEV electricity/fuel multiplier",
  Interval_level = 0.95, Interval_probabilities = c(.025, .975),
  Quantile_type = 7L), Stage_summary = stage_summary,
  Difference_summary = difference_summary, Total_summary = total_summary),
  file.path(output_dir, "Fig5_results.rds"))
message("Fig5 completed: ", output_dir)
