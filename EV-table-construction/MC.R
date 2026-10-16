###############################################################################
# EV-ICIO Monte Carlo model (v4)
# Independent file: no other R script is loaded or required.
###############################################################################

################################### settings ##################################
G <- 77L                         # number of countries
N <- 50L                         # number of ICIO sectors
M <- G * N

nmc <- 1000L                    # MONTE CARLO ITERATIONS: edit here
mc_range <- 0.10                # uniform range: 90%-110% of the baseline
mc_seed <- 20260821L            # reproducible random seed

path <- "D:/Data/EV"
adata <- Sys.getenv("EV_ADATA", paste0(path, "/Data/Adata_v6.xlsx"))
year <- "2022"
fvyear <- "2017"
outdir <- paste0(path, "/re/MC")

# Optional environment overrides are only for quick test runs; normal use keeps
# the two values above unchanged.
if (nzchar(Sys.getenv("EV_MC_ITERATIONS")))
  nmc <- as.integer(Sys.getenv("EV_MC_ITERATIONS"))
if (nzchar(Sys.getenv("EV_MC_RANGE")))
  mc_range <- as.numeric(Sys.getenv("EV_MC_RANGE"))
if (nzchar(Sys.getenv("EV_MC_OUTPUT_DIR")))
  outdir <- Sys.getenv("EV_MC_OUTPUT_DIR")
###############################################################################

library(Matrix)
library(openxlsx)


############################### read ICIO data ################################
read_icio <- function(y) {
  dt <- read.csv(paste0(path, "/Data/", y, "_SML.csv"), row.names = 1,
                 check.names = FALSE)
  z <- as.matrix(dt[1:M, 1:M])
  outpos <- match("OUT", names(dt))
  fdcols <- (M + 1L):(outpos - 1L)
  Y <- as.matrix(dt[1:M, fdcols])
  X <- rowSums(z) + rowSums(Y)
  A <- sweep(z, 2L, X, "/")
  A[!is.finite(A) | A < 0] <- 0
  dimnames(A) <- list(rownames(dt)[1:M], names(dt)[1:M])
  A
}

A <- read_icio(year)
fvA <- read_icio(fvyear)
seclist <- rownames(A)
coulist <- unique(sub("_.*$", "", seclist))
if (length(coulist) != G || nrow(A) != M) stop("ICIO dimensions do not match G and N.")

# Producing countries are selected in Countries$Include_base.
countries <- read.xlsx(adata, sheet = "Countries", check.names = FALSE)
countries$ISO3 <- toupper(trimws(countries$ISO3))
selected <- countries$ISO3[toupper(trimws(countries$Include_base)) == "TRUE"]
selected <- selected[selected %in% coulist]
sorder <- match(selected, coulist)

# BOM_raw is the only BOM input. Country profile: exact ISO3; otherwise OTHERS.
groups <- c("T", "M", "E", "I", "EE", "HV", "SHARED")
bom <- read.xlsx(adata, sheet = "BOM_raw", check.names = FALSE)
bom$country_code <- toupper(trimws(bom$country_code))
bom$item_id <- toupper(trimws(bom$item_id))
bom$group <- toupper(trimws(bom$group))
bom$bom_share <- as.numeric(bom$bom_share)
profiles <- unique(bom$country_code)
if (!"OTHERS" %in% profiles) stop("BOM_raw must contain the OTHERS profile.")

bomshare <- matrix(0, length(profiles), length(groups),
                   dimnames = list(profiles, groups))
eweight <- matrix(0, length(profiles), 2L,
                  dimnames = list(profiles, c("C26", "C27")))
for (p in profiles) {
  b <- bom[bom$country_code == p, ]
  bomshare[p, ] <- sapply(groups, function(g) sum(b$bom_share[b$group == g]))
  e26 <- sum(b$bom_share[b$item_id %in% c("BMS", "VCU")])
  e27 <- sum(b$bom_share[b$item_id %in% c("MCU", "OBC", "DCDC", "PDU")])
  eweight[p, ] <- c(e26, e27) / (e26 + e27)
}
if (any(abs(rowSums(bomshare) - 1) > 1e-8)) stop("Each BOM_raw profile must sum to one.")

# Domestic sourcing rates.
alpha <- read.xlsx(adata, sheet = "Alpha_2020", check.names = FALSE)
alpha$ISO3 <- toupper(trimws(alpha$ISO3))
alpha <- alpha[match(coulist, alpha$ISO3), ]
alpha0 <- cbind(T = as.numeric(alpha$alpha_T),
                M = as.numeric(alpha$alpha_M),
                E = as.numeric(alpha$alpha_E))
rownames(alpha0) <- coulist

# C29 baseline intensity and manually specified TLS and VA shares.
intensity <- read.xlsx(adata, sheet = "ICIO_intensity", check.names = FALSE)
intensity$ISO3 <- toupper(trimws(intensity$ISO3))
intensity <- intensity[match(coulist, intensity$ISO3), ]
u_base <- setNames(as.numeric(intensity$u_intermediate), coulist)
TLS_share <- setNames(as.numeric(intensity[[6L]]), coulist)
VA_share <- setNames(as.numeric(intensity[[7L]]), coulist)
u_target <- 1 - TLS_share - VA_share

# Imported origin shares. The domestic diagonal is removed and each foreign
# column is normalized to one, as in v4.
read_import <- function(sheet) {
  x <- read.xlsx(adata, sheet = sheet, check.names = FALSE)
  rcode <- toupper(trimws(x[[1L]]))
  origin <- match(coulist, rcode)
  if (anyNA(origin)) stop(sheet, " is missing an ICIO origin country.")
  destination <- match(coulist, toupper(trimws(names(x))))
  if (anyNA(destination)) stop(sheet, " is missing an ICIO destination country.")
  ccode <- toupper(trimws(names(x)[destination]))
  out <- sapply(x[destination], function(z) as.numeric(z[origin]))
  rownames(out) <- coulist
  colnames(out) <- ccode
  out <- out[coulist, coulist, drop = FALSE]
  out[!is.finite(out) | out < 0] <- 0
  diag(out) <- 0
  total <- colSums(out)
  out[, total > 0] <- sweep(out[, total > 0, drop = FALSE], 2L,
                            total[total > 0], "/")
  out
}

piM0 <- read_import("IMshareM")
piC0 <- read_import("IMshareC")

# Scale each EV column to the target implied by the manual TLS and VA shares.
c29 <- match(paste0(coulist, "_C29"), colnames(A))
u_A <- setNames(colSums(A[, c29, drop = FALSE]), coulist)
if (anyNA(c(u_base[selected], TLS_share[selected], VA_share[selected])))
  stop("ICIO_intensity is missing an EV country or share.")
if (max(abs(u_A[selected] - u_base[selected])) > 1e-6)
  stop("ICIO_intensity$u_intermediate does not match the 2022 A matrix.")
if (any(u_base[selected] <= 0))
  stop("ICIO_intensity$u_intermediate must be positive for every EV country.")
if (any(TLS_share[selected] < 0 | VA_share[selected] < 0 |
        TLS_share[selected] + VA_share[selected] >= 1))
  stop("TLS and VA shares must be nonnegative and sum to less than one.")
u_scale <- u_target / u_base
message("EV columns will be scaled to 1 - TLS share - VA share for ",
        length(selected), " countries.")
fvinput <- fvA[, c29[sorder], drop = FALSE]
colnames(fvinput) <- paste0(selected, "_FV")


############################ four sampling functions ###########################
# 1. One bounded composition: every positive element stays in [90%,110%]
#    of baseline and the draw sums exactly to one.
draw_share <- function(x) {
  if (abs(sum(x) - 1) > 1e-8) stop("A sampled composition must sum to one.")
  if (mc_range == 0) return(x)
  positive <- which(x > 0)
  if (length(positive) <= 1L) return(x)
  pivot <- positive[which.max(x[positive])]
  other <- setdiff(positive, pivot)
  low <- x * (1 - mc_range)
  high <- x * (1 + mc_range)
  for (attempt in 1:10000) {
    out <- x
    out[other] <- runif(length(other), low[other], high[other])
    out[pivot] <- 1 - sum(out[other])
    if (out[pivot] >= low[pivot] && out[pivot] <= high[pivot]) return(out)
  }
  stop("Could not draw a bounded composition.")
}

# 2. Country-specific seven-group BOM shares.
draw_bom <- function(x) {
  out <- x
  for (p in rownames(x)) out[p, ] <- draw_share(x[p, ])
  out
}

# 3. Domestic sourcing rates. T and M use the same standardized shock;
#    E is independent. The interval is symmetric around the baseline and is
#    narrowed only when 90%-110% would cross 0 or 1.
draw_alpha <- function(x) {
  out <- x
  for (i in seq_len(nrow(x))) {
    ztm <- runif(1L, -1, 1)
    ze <- runif(1L, -1, 1)
    if (all(is.finite(x[i, c("T", "M")]))) {
      hT <- min(mc_range * x[i, "T"], x[i, "T"], 1 - x[i, "T"])
      hM <- min(mc_range * x[i, "M"], x[i, "M"], 1 - x[i, "M"])
      out[i, "T"] <- x[i, "T"] + ztm * hT
      out[i, "M"] <- x[i, "M"] + ztm * hM
    }
    if (is.finite(x[i, "E"])) {
      hE <- min(mc_range * x[i, "E"], x[i, "E"], 1 - x[i, "E"])
      out[i, "E"] <- x[i, "E"] + ze * hE
    }
  }
  out
}

# 4. Imported origin shares. Structural zeros and the domestic diagonal stay 0;
#    every positive destination column remains a bounded composition.
draw_import <- function(x) {
  out <- x
  for (j in seq_len(ncol(x))) {
    positive <- which(x[, j] > 0)
    if (length(positive) > 0L) out[positive, j] <- draw_share(x[positive, j])
  }
  diag(out) <- 0
  out
}


############################ construct one A matrix ############################
make_AEV <- function(bom_i, alpha_i, piM_i, piC_i) {
  evinput <- matrix(0, M, length(selected),
                    dimnames = list(seclist, paste0(selected, "_EV")))
  r26 <- which(endsWith(seclist, "_C26"))
  r27 <- which(endsWith(seclist, "_C27"))
  r29 <- which(endsWith(seclist, "_C29"))
  
  for (j in seq_along(selected)) {
    country <- selected[j]
    c <- match(country, coulist)
    profile <- if (country %in% rownames(bom_i)) country else "OTHERS"
    beta <- u_base[country] * bom_i[profile, ] * u_scale[country]
    
    # T and M -> C27; both use IMshareM.
    evinput[r27[c], j] <- evinput[r27[c], j] +
      alpha_i[c, "T"] * beta["T"] + alpha_i[c, "M"] * beta["M"]
    evinput[r27, j] <- evinput[r27, j] +
      piM_i[, c] * ((1 - alpha_i[c, "T"]) * beta["T"] +
                      (1 - alpha_i[c, "M"]) * beta["M"])
    
    # E -> C26 and C27; the within-E weights come from baseline BOM_raw items.
    for (sector in c("C26", "C27")) {
      rows <- if (sector == "C26") r26 else r27
      budget <- beta["E"] * eweight[profile, sector]
      evinput[rows[c], j] <- evinput[rows[c], j] + alpha_i[c, "E"] * budget
      evinput[rows, j] <- evinput[rows, j] +
        piC_i[, c] * (1 - alpha_i[c, "E"]) * budget
    }
    
    # I -> C26; EE -> C26+C27+C29; HV -> C29; SHARED -> full C29 column.
    basis <- A[r26, c29[c]]
    evinput[r26, j] <- evinput[r26, j] + beta["I"] * basis / sum(basis)
    
    rows <- c(r26, r27, r29)
    basis <- A[rows, c29[c]]
    evinput[rows, j] <- evinput[rows, j] + beta["EE"] * basis / sum(basis)
    
    basis <- A[r29, c29[c]]
    evinput[r29, j] <- evinput[r29, j] + beta["HV"] * basis / sum(basis)
    
    basis <- A[, c29[c]]
    evinput[, j] <- evinput[, j] + beta["SHARED"] * basis / sum(basis)
  }
  
  if (any(abs(colSums(evinput) + TLS_share[selected] + VA_share[selected] - 1) > 1e-8))
    stop("An EV column plus its TLS and VA shares does not equal one.")
  
  top <- cbind(A, evinput, fvinput)
  newnames <- c(colnames(evinput), colnames(fvinput))
  bottom <- matrix(0, length(newnames), ncol(top),
                   dimnames = list(newnames, colnames(top)))
  Matrix(rbind(top, bottom), sparse = TRUE)
}


############################ Monte Carlo simulation ############################
set.seed(mc_seed)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nmc)) {
  bom_i <- draw_bom(bomshare)
  alpha_i <- draw_alpha(alpha0)
  piM_i <- draw_import(piM0)
  piC_i <- draw_import(piC0)
  
  A_MC <- make_AEV(bom_i, alpha_i, piM_i, piC_i)
  saveRDS(A_MC, file.path(outdir, sprintf("A_MC_%04d.rds", i)))
  
  #if (i == 1L || i %% 50L == 0L || i == nmc)
  message("Monte Carlo iteration ", i, "/", nmc, " completed.")
}

message("MC_v4 completed. Results: ", outdir)
