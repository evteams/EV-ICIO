
# Figure 4: sector shares of manufacturing emissions 

Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))

# 1. Settings and relative paths
countries <- c("CHN", "DEU", "JPN", "KOR", "MEX", "USA")
china_EV_multiplier <- 1.15
source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
input_dir <- file.path(project_dir, "input")
output_dir <- file.path(project_dir, "output")
dir.create(output_dir, showWarnings = FALSE)

# 2. Read A, output and direct CO2
raw_A <- read.csv(file.path(input_dir, "AEV_v6.csv"), check.names = FALSE)
nodes <- as.character(raw_A[[1]])
A <- as.matrix(raw_A[-1])
dimnames(A) <- list(nodes, nodes)
X <- read.csv(file.path(input_dir, "XEV_v6.csv"))
CO2 <- read.csv(file.path(input_dir, "co2_sector_energy_combustion.csv"))
production <- X[[2]][match(nodes, X[[1]])]
emissions <- CO2$co2_kt[match(nodes, CO2$fd_id)]
f_ICEV <- emissions / production
f_ICEV[production == 0 & emissions == 0] <- 0
f_EV <- f_ICEV
china_nodes <- nodes %in% c("CHN_C27", "CHN_D")
f_EV[china_nodes] <- f_EV[china_nodes] * china_EV_multiplier

# 3. Solve only the 12 target columns of B 
# (I-A)B=S: each column of S selects one vehicle node 
targets <- c(paste0(countries, "_EV"), paste0(countries, "_FV"))
S <- matrix(0, length(nodes), length(targets))
S[cbind(match(targets, nodes), seq_along(targets))] <- 1
B <- solve(diag(length(nodes)) - A, S)
colnames(B) <- targets
rm(raw_A, A)

# 4. Aggregate supplier nodes into sectors 
# Contributions are coefficients: kt CO2/million USD 
# Price and Y cancel from sector shares 
region <- substr(nodes, 1, 3)
sector <- substring(nodes, 5)
sector_codes <- sort(unique(sector))
rows <- list()
for (cc in countries) {
  for (vehicle in c("EV", "ICEV")) {
    target <- paste0(cc, if (vehicle == "EV") "_EV" else "_FV")
    f <- if (vehicle == "EV") f_EV else f_ICEV
    node_values <- f * B[, target]
    is_domestic <- region == cc
    domestic <- tapply(node_values[is_domestic], sector[is_domestic], sum)[sector_codes]
    abroad <- tapply(node_values[!is_domestic], sector[!is_domestic], sum)[sector_codes]
    domestic[is.na(domestic)] <- 0
    abroad[is.na(abroad)] <- 0
    # Denominator includes ALL sectors, domestic + foreign 
    total <- domestic + abroad
    denominator <- sum(total)
    result <- data.frame(Country = cc, Vehicle = vehicle, Sector = sector_codes,
      Domestic_ktCO2_per_million_USD = as.numeric(domestic),
      Abroad_ktCO2_per_million_USD = as.numeric(abroad),
      Total_ktCO2_per_million_USD = as.numeric(total),
      Domestic_share = as.numeric(domestic / denominator),
      Abroad_share = as.numeric(abroad / denominator),
      Total_share = as.numeric(total / denominator))
    result$Rank_by_domestic <- rank(-result$Domestic_share, ties.method = "first")
    result$Rank_by_total <- rank(-result$Total_share, ties.method = "first")
    rows[[length(rows) + 1]] <- result[order(result$Rank_by_domestic), ]
  }
}
sector_results <- do.call(rbind, rows)


# 5. Save shares and the top 10 domestic contributors 
# The top 10 keep the all-sector denominator
write.csv(sector_results, file.path(output_dir, "Fig4_all_sector_shares.csv"), row.names = FALSE)
write.csv(subset(sector_results, Rank_by_domestic <= 10),
          file.path(output_dir, "Fig4_top10_sector_shares.csv"), row.names = FALSE)

