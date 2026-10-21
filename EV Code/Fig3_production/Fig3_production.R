
# Figure 3 manufacturing Monte Carlo analysis

library(Matrix)
Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))

# 1. Settings and paths
countries <- c("CHN", "DEU", "JPN", "KOR", "MEX", "USA")
n_A <- 1000L
n_price <- 5000L
seed <- 20261005L
china_D_multiplier <- 1.12533
china_C27_intensity <- 0.0156 # kt CO2/million USD; absolute intensity, not a multiplier.
production_calibration <- list(China_D_multiplier = china_D_multiplier,
  China_C27_intensity = china_C27_intensity, Unit = "kt CO2/million USD",
  Scope = "EV production only; ICEV unadjusted")
solver <- "woodbury" 

source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
input_dir <- file.path(project_dir, "input")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, showWarnings = FALSE)
A_dir <- file.path(input_dir, "MC")
# Prefer this package's MC folder; use the existing shared original matrices if absent.
if (!file.exists(file.path(A_dir, "A_MC_0001.rds")))
  A_dir <- file.path(project_dir, "..", "EV Code", "Fig3_production", "input", "MC")

# 2. Read the raw inputs and construct direct emission intensities 
raw_A <- read.csv(file.path(input_dir, "AEV_v6.csv"), check.names = FALSE)
nodes <- as.character(raw_A[[1]])
A_ICEV <- as.matrix(raw_A[-1])
dimnames(A_ICEV) <- list(nodes, nodes)
X <- read.csv(file.path(input_dir, "XEV_v6.csv"))
CO2 <- read.csv(file.path(input_dir, "co2_sector_energy_combustion.csv"))
production <- X[[2]][match(nodes, X[[1]])]
emissions <- CO2$co2_kt[match(nodes, CO2$fd_id)]
f_ICEV <- emissions / production
f_ICEV[production == 0 & emissions == 0] <- 0
f_EV <- f_ICEV
# Apply each supplier-node correction once, for EV targets in every country.

f_EV[nodes == "CHN_D"] <- f_ICEV[nodes == "CHN_D"] * china_D_multiplier
f_EV[nodes == "CHN_C27"] <- china_C27_intensity

sales <- read.csv(file.path(input_dir, "vehicle_sales_2023.csv"))
trade <- read.csv(file.path(input_dir, "vehicle_trade_2023.csv"))
ranges <- read.csv(file.path(input_dir, "vehicle_price_ranges_2023.csv"))

# 3. Draw independent prices; derive Y from the same price 
# Y is in million USD 
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(seed)
price_draws <- list()
for (cc in countries) {
  s <- sales[sales$Country == cc, ]
  EV_sales <- s$Passenger_sales_2023_vehicles * s$EV_share_2023_percent / 100
  ICEV_sales <- s$Passenger_sales_2023_vehicles - EV_sales
  p_EV <- ranges[ranges$Country == cc & ranges$Vehicle == "EV", ]
  p_ICEV <- ranges[ranges$Country == cc & ranges$Vehicle == "ICEV", ]
  t_EV <- trade[trade$Country == cc & trade$Vehicle == "EV", ]
  t_ICEV <- trade[trade$Country == cc & trade$Vehicle == "ICEV", ]
  price_EV <- runif(n_price, p_EV$Price_min_USD, p_EV$Price_max_USD)
  price_ICEV <- runif(n_price, p_ICEV$Price_min_USD, p_ICEV$Price_max_USD)
  price_draws[[cc]] <- data.frame(Country = cc, Price_id = seq_len(n_price),
    Price_EV_USD = price_EV, Price_ICEV_USD = price_ICEV,
    Y_EV_million_USD = EV_sales * price_EV / 1e6 + t_EV$Exports_million_USD - t_EV$Imports_million_USD,
    Y_ICEV_million_USD = ICEV_sales * price_ICEV / 1e6 + t_ICEV$Exports_million_USD - t_ICEV$Imports_million_USD)
}

# 4. Solve the required B columns and aggregate domestic/foreign coefficients
selector <- function(targets) {
  S <- matrix(0, length(nodes), length(targets))
  S[cbind(match(targets, nodes), seq_along(targets))] <- 1
  S
}
supplier_countries <- unique(substr(nodes, 1, 3))
electricity_suppliers <- sort(supplier_countries)
component_names <- c("b_total", "b_C24A", paste0("D_", electricity_suppliers))
coefficients <- function(B, f) {
  contribution <- sweep(as.matrix(B), 1, f, "*")
  b <- matrix(0, length(countries), 3,
    dimnames = list(countries, c("Domestic", "Abroad", "Total")))
  for (j in seq_along(countries)) {
    domestic <- substr(nodes, 1, 3) == countries[j]
    b[j, "Domestic"] <- sum(contribution[domestic, j])
    b[j, "Abroad"] <- sum(contribution[!domestic, j])
    b[j, "Total"] <- sum(contribution[, j])
  }
  # Retain the same solved columns for downstream Fig5/Fig6 and the source-country diagram.

  components <- cbind(b_total = b[, "Total"],
    b_C24A = colSums(contribution[endsWith(nodes, "_C24A"), , drop = FALSE]),
    t(contribution[match(paste0(electricity_suppliers, "_D"), nodes), , drop = FALSE]))
  dimnames(components) <- list(countries, component_names)
  by_source <- rowsum(contribution, group = substr(nodes, 1, 3), reorder = FALSE)
  by_source <- by_source[supplier_countries, , drop = FALSE]
  colnames(by_source) <- countries
  list(Summary = b, Components = components, By_source = by_source)
}
S_ICEV <- selector(paste0(countries, "_FV"))
B_ICEV <- solve(diag(length(nodes)) - A_ICEV, S_ICEV)
ICEV_calculation <- coefficients(B_ICEV, f_ICEV)
b_ICEV <- ICEV_calculation$Summary
rm(raw_A, A_ICEV, B_ICEV)

S_EV <- selector(paste0(countries, "_EV"))
A_files <- file.path(A_dir, sprintf("A_MC_%04d.rds", seq_len(n_A)))
A_reference <- readRDS(A_files[1])
changed_columns <- which(grepl("_EV$", nodes))
reference_columns <- as.matrix(A_reference[, changed_columns, drop = FALSE])
if (solver == "woodbury") {
  # The supplied A family changes only EV columns
  LU_reference <- lu(Diagonal(length(nodes)) - A_reference)
  B_reference <- as.matrix(solve(LU_reference, S_EV))
}
b_EV <- array(NA_real_, c(n_A, length(countries), 3),
  dimnames = list(seq_len(n_A), countries, c("Domestic", "Abroad", "Total")))
components_EV <- array(NA_real_, c(n_A, length(countries), length(component_names)),
  dimnames = list(seq_len(n_A), countries, component_names))
sources_EV <- array(NA_real_, c(n_A, length(supplier_countries), length(countries)),
  dimnames = list(seq_len(n_A), supplier_countries, countries))
for (m in seq_len(n_A)) {
  A <- if (m == 1) A_reference else readRDS(A_files[m])
  if (solver == "direct") B <- solve(Diagonal(length(nodes)) - A, S_EV)
  else if (m == 1) B <- B_reference
  else {
    # Woodbury identity: exact solution for each supplied A
    delta <- as.matrix(A[, changed_columns, drop = FALSE]) - reference_columns
    W <- as.matrix(solve(LU_reference, delta))
    B <- B_reference + W %*% solve(diag(length(changed_columns)) - W[changed_columns, , drop = FALSE],
                                   B_reference[changed_columns, , drop = FALSE])
  }
  EV_calculation <- coefficients(B, f_EV)
  b_EV[m, , ] <- EV_calculation$Summary
  components_EV[m, , ] <- EV_calculation$Components
  sources_EV[m, , ] <- EV_calculation$By_source
  if (m %% 100 == 0) message("Solved A: ", m, "/", n_A)
}

# 5. Cross every A with all prices and summarize
# b: kt CO2/million USD; single vehicle: t CO2; total: Mt CO2.
summarize_MC <- function(x) {
  q <- quantile(x, c(.025, .5, .975), names = FALSE, type = 7)
  data.frame(N = length(x), Mean = mean(x), Median = q[2], Low = q[1], High = q[3], SD = sd(x))
}
rows <- list()
for (cc in countries) {
  p <- price_draws[[cc]]
  for (vehicle in c("EV", "ICEV")) {
    price <- p[[paste0("Price_", vehicle, "_USD")]]
    Y <- p[[paste0("Y_", vehicle, "_million_USD")]]
    for (origin in c("Domestic", "Abroad", "Total")) {
      b <- if (vehicle == "EV") b_EV[, cc, origin] else b_ICEV[cc, origin]
      labels <- data.frame(Country = cc, Vehicle = vehicle, Origin = origin,
        N_A = if (vehicle == "EV") n_A else 1L, N_price = n_price)
      rows[[length(rows) + 1]] <- cbind(labels, Measure = "Total_MtCO2",
        summarize_MC(as.vector(outer(b, Y / 1000))))
      rows[[length(rows) + 1]] <- cbind(labels, Measure = "Per_vehicle_tCO2",
        summarize_MC(as.vector(outer(b, price / 1000))))
    }
  }
}
MC_summary <- do.call(rbind, rows)

# 6. Save MC outputs
write.csv(MC_summary, file.path(output_dir, "Fig3_summary.csv"), row.names = FALSE)
write.csv(do.call(rbind, price_draws), file.path(output_dir, "Price_and_Y_draws.csv"), row.names = FALSE)
saveRDS(list(Settings = list(Countries = countries, N_A_EV = n_A, N_A_ICEV = 1L,
  N_price = n_price, Seed = seed, Solver = solver, Production_calibration = production_calibration),
  Price_draws = price_draws, EV_coefficients = b_EV, ICEV_coefficients = b_ICEV,
  Scenario_coefficients = list(Suppliers = electricity_suppliers, EV = components_EV,
    ICEV = ICEV_calculation$Components),
  Source_coefficients = list(Suppliers = supplier_countries, EV = sources_EV,
    ICEV = ICEV_calculation$By_source),
  Summary = MC_summary), file.path(output_dir, "Fig3_results.rds"))
