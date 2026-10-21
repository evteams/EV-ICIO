# Figure 4 sector-share MC 
# EV: 1000 original A samples; ICEV: fixed A 
# No price sampling, plotting or diagnostic outputs 

library(Matrix)
Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))

# 1. Settings and relative paths 
countries <- c("CHN", "DEU", "JPN", "KOR", "MEX", "USA")
n_A <- 1000L
china_D_multiplier <- 1.12533
china_C27_intensity <- 0.0156 # kt CO2/million USD; absolute intensity, not a multiplier.
production_calibration <- list(China_D_multiplier = china_D_multiplier,
  China_C27_intensity = china_C27_intensity, Unit = "kt CO2/million USD",
  Scope = "EV production only; ICEV unadjusted")
solver <- "woodbury" # Exact for this A family; "direct" solves each A separately.
source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
input_dir <- file.path(project_dir, "input")
# Shared raw A folder
A_dir <- file.path(project_dir, "..", "Fig3_production", "input", "MC")
output_dir <- file.path(project_dir, "output", "MC")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# 2. Direct emission intensities
raw_A <- read.csv(file.path(input_dir, "AEV_v6.csv"), check.names = FALSE)
nodes <- as.character(raw_A[[1]])
A_fixed <- as.matrix(raw_A[-1])
dimnames(A_fixed) <- list(nodes, nodes)
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
region <- substr(nodes, 1, 3)
sector <- substring(nodes, 5)
sector_codes <- sort(unique(sector))
origins <- c("Domestic", "Abroad", "Total")

# 3. B-column selectors and sector shares
selector <- function(targets) {
  S <- matrix(0, length(nodes), length(targets))
  S[cbind(match(targets, nodes), seq_along(targets))] <- 1
  S
}
sector_shares <- function(B, f) {
  contribution <- sweep(as.matrix(B), 1, f, "*")
  denominator <- colSums(contribution)
  shares <- array(0, c(length(countries), length(sector_codes), length(origins)),
    dimnames = list(countries, sector_codes, origins))
  for (j in seq_along(countries)) {
    domestic_nodes <- region == countries[j]
    domestic <- tapply(contribution[domestic_nodes, j], sector[domestic_nodes], sum)[sector_codes]
    abroad <- tapply(contribution[!domestic_nodes, j], sector[!domestic_nodes], sum)[sector_codes]
    domestic[is.na(domestic)] <- 0
    abroad[is.na(abroad)] <- 0
    shares[j, , "Domestic"] <- domestic / denominator[j]
    shares[j, , "Abroad"] <- abroad / denominator[j]
    shares[j, , "Total"] <- (domestic + abroad) / denominator[j]
  }
  shares
}

# 4. ICEV uses its own fixed supply chain 
B_ICEV <- solve(diag(length(nodes)) - A_fixed, selector(paste0(countries, "_FV")))
ICEV_shares <- sector_shares(B_ICEV, f_ICEV)
rm(raw_A, A_fixed, B_ICEV)

# 5. Solve EV columns for all original A samples
S_EV <- selector(paste0(countries, "_EV"))
A_files <- file.path(A_dir, sprintf("A_MC_%04d.rds", seq_len(n_A)))
A_reference <- readRDS(A_files[1])
changed_columns <- which(grepl("_EV$", nodes))
reference_columns <- as.matrix(A_reference[, changed_columns, drop = FALSE])
if (solver == "woodbury") {
  # The supplied matrices vary only in EV columns
  LU_reference <- lu(Diagonal(length(nodes)) - A_reference)
  B_reference <- as.matrix(solve(LU_reference, S_EV))
}
EV_shares <- array(NA_real_, c(n_A, length(countries), length(sector_codes), length(origins)),
  dimnames = list(seq_len(n_A), countries, sector_codes, origins))
for (m in seq_len(n_A)) {
  A <- if (m == 1) A_reference else readRDS(A_files[m])
  if (solver == "direct") B <- solve(Diagonal(length(nodes)) - A, S_EV)
  else if (m == 1) B <- B_reference
  else {
    delta <- as.matrix(A[, changed_columns, drop = FALSE]) - reference_columns
    W <- as.matrix(solve(LU_reference, delta))
    B <- B_reference + W %*% solve(diag(length(changed_columns)) - W[changed_columns, , drop = FALSE],
                                   B_reference[changed_columns, , drop = FALSE])
  }
  # Normalize by this draw's ALL-sector total 
  EV_shares[m, , , ] <- sector_shares(B, f_EV)
  if (m %% 100 == 0) message("Sector MC: ", m, "/", n_A)
}

# 6. Marginal medians and MC distribution intervals
rows <- list()
for (cc in countries) for (vehicle in c("EV", "ICEV")) {
  for (ss in sector_codes) for (origin in origins) {
    values <- if (vehicle == "EV") EV_shares[, cc, ss, origin] else ICEV_shares[cc, ss, origin]
    q <- quantile(values, c(.025, .5, .975), names = FALSE, type = 7)
    rows[[length(rows) + 1]] <- data.frame(Country = cc, Vehicle = vehicle, Sector = ss,
      Origin = origin, N_A = length(values), Mean = mean(values), Median = q[2],
      Low = q[1], High = q[3], SD = if (length(values) > 1) sd(values) else 0)
  }
}
SI_summary <- do.call(rbind, rows)
SI_summary$Sector_display <- ifelse(SI_summary$Sector == "FV", "ICEV", SI_summary$Sector)
SI_summary$Error_minus <- SI_summary$Median - SI_summary$Low
SI_summary$Error_plus <- SI_summary$High - SI_summary$Median

# 7. Main-text tables: medians only 
rows <- list()
for (cc in countries) for (vehicle in c("EV", "ICEV")) {
  selected <- SI_summary[SI_summary$Country == cc & SI_summary$Vehicle == vehicle, ]
  get_median <- function(origin) {
    x <- selected[selected$Origin == origin, ]
    x$Median[match(sector_codes, x$Sector)]
  }
  result <- data.frame(Country = cc, Vehicle = vehicle, Sector = sector_codes,
    Sector_display = ifelse(sector_codes == "FV", "ICEV", sector_codes),
    Domestic_median = get_median("Domestic"), Abroad_median = get_median("Abroad"),
    Total_median = get_median("Total"))
  result$Rank_by_domestic <- rank(-result$Domestic_median, ties.method = "first")
  result$Rank_by_total <- rank(-result$Total_median, ties.method = "first")
  # Select sectors ONCE after summarizing all draws
  rows[[length(rows) + 1]] <- result[order(result$Rank_by_domestic), ]
}
main_medians <- do.call(rbind, rows)
write.csv(main_medians, file.path(output_dir, "Fig4_main_all_sectors_median.csv"), row.names = FALSE)
write.csv(subset(main_medians, Rank_by_domestic <= 10),
          file.path(output_dir, "Fig4_main_top10_median.csv"), row.names = FALSE)
write.csv(SI_summary, file.path(output_dir, "Fig4_SI_sector_MC_intervals.csv"), row.names = FALSE)
# Current figure: select ten sectors separately for each domestic/foreign group.

by_origin <- SI_summary[SI_summary$Origin != "Total", c("Country", "Vehicle", "Origin", "Sector", "Sector_display", "Median")]
top10_by_origin <- do.call(rbind, lapply(split(by_origin,
  list(by_origin$Country, by_origin$Vehicle, by_origin$Origin), drop = TRUE), function(x) {
    x <- x[order(-x$Median, x$Sector_display, method = "radix"), ]
    x <- head(x, 10L)
    x$Rank <- seq_len(nrow(x))
    x
  }))
write.csv(top10_by_origin, file.path(output_dir, "Fig4_main_top10_by_origin.csv"), row.names = FALSE)
saveRDS(list(Settings = list(Countries = countries, Sectors = sector_codes, N_A_EV = n_A,
  N_A_ICEV = 1L, Solver = solver, Production_calibration = production_calibration,
  Quantile_type = 7L, Percentiles = c(.025, .5, .975)),
  EV_shares = EV_shares, ICEV_shares = ICEV_shares),
  file.path(output_dir, "Fig4_sector_MC_draws.rds"))
