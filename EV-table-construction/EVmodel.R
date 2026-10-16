###############################################################################
# EV-ICIO model (v6)
# BOM_raw in Adata_v6.xlsx is the only source of BOM shares.
###############################################################################

################################### settings ##################################
G <- 77L                         # number of countries
N <- 50L                         # number of ICIO sectors
M <- G * N

path <- "D:/Data/EV"
data_path <- Sys.getenv("EV_DATA_DIR", paste0(path, "/Data"))
adata <- Sys.getenv("EV_ADATA", paste0(data_path, "/Adata_v6.xlsx"))
out_path <- Sys.getenv("EV_OUTPUT_DIR", paste0(path, "/Results_v6"))
write_outputs <- toupper(Sys.getenv("EV_WRITE_OUTPUT", "TRUE")) == "TRUE"

year <- "2022"
fvyear <- "2017"
###############################################################################


library(openxlsx)


############################### read ICIO data ################################
read_icio <- function(y) {
  dt <- read.csv(paste0(data_path, "/", y, "_SML.csv"), row.names = 1,
                 check.names = FALSE)
  if (nrow(dt) < M || ncol(dt) < M) stop("ICIO dimensions do not match G and N.")
  
  z <- as.matrix(dt[1:M, 1:M])
  outpos <- match("OUT", names(dt))
  if (is.na(outpos)) stop("ICIO file has no OUT column.")
  fdcols <- (M + 1L):(outpos - 1L)
  Y <- as.matrix(dt[1:M, fdcols])
  X <- rowSums(z) + rowSums(Y)
  
  A <- sweep(z, 2L, X, "/")
  A[!is.finite(A) | A < 0] <- 0
  dimnames(A) <- list(rownames(dt)[1:M], names(dt)[1:M])
  
  ntype <- length(fdcols) / G
  fd <- sapply(1:G, function(c) {
    k <- (c - 1L) * ntype + 1:ntype
    rowSums(Y[, k, drop = FALSE])
  })
  rownames(fd) <- rownames(A)
  list(A = A, fd = fd)
}

base <- read_icio(year)
nonev <- read_icio(fvyear)
A <- base$A
fd <- base$fd
nonevA <- nonev$A

seclist <- rownames(A)
coulist <- unique(sub("_.*$", "", seclist))
colnames(fd) <- coulist
if (length(coulist) != G || nrow(A) != M)
  stop("ICIO dimensions do not match G and N.")


######################## read parameters from Adata_v6 ########################
# Producing countries are selected by Countries$Include_base.
countries <- read.xlsx(adata, sheet = "Countries", check.names = FALSE)
countries$ISO3 <- toupper(trimws(countries$ISO3))
selected <- countries$ISO3[toupper(trimws(countries$Include_base)) == "TRUE"]
selected <- selected[selected %in% coulist]
sorder <- match(selected, coulist)

# BOM_raw is the only BOM input. Exact ISO3 profile; otherwise OTHERS.
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
if (any(abs(rowSums(bomshare) - 1) > 1e-8))
  stop("Each country profile in BOM_raw must sum to one.")

# Domestic sourcing rates alpha(c,q).
alpha <- read.xlsx(adata, sheet = "Alpha_2020", check.names = FALSE)
alpha$ISO3 <- toupper(trimws(alpha$ISO3))
alpha <- alpha[match(coulist, alpha$ISO3), ]
alpha <- cbind(T = as.numeric(alpha$alpha_T),
               M = as.numeric(alpha$alpha_M),
               E = as.numeric(alpha$alpha_E))
rownames(alpha) <- coulist

# C29 baseline intensity and manually specified TLS and VA shares.
intensity <- read.xlsx(adata, sheet = "ICIO_intensity", check.names = FALSE)
intensity$ISO3 <- toupper(trimws(intensity$ISO3))
intensity <- intensity[match(coulist, intensity$ISO3), ]
u_base <- setNames(as.numeric(intensity$u_intermediate), coulist)
TLS_share <- setNames(as.numeric(intensity[[6L]]), coulist)
VA_share <- setNames(as.numeric(intensity[[7L]]), coulist)
u_target <- 1 - TLS_share - VA_share

# Read and normalize an origin-by-destination country matrix.
read_country_matrix <- function(sheet, normalize = FALSE) {
  x <- read.xlsx(adata, sheet = sheet, check.names = FALSE)
  origin <- match(coulist, toupper(trimws(x[[1L]])))
  destination <- match(coulist, toupper(trimws(names(x))))
  if (anyNA(origin) || anyNA(destination))
    stop(sheet, " does not contain the complete ICIO country list.")
  out <- sapply(x[destination], function(z) as.numeric(z[origin]))
  dimnames(out) <- list(coulist, coulist)
  out[!is.finite(out) | out < 0] <- 0
  if (normalize) {
    diag(out) <- 0
    total <- colSums(out)
    out[, total > 0] <- sweep(out[, total > 0, drop = FALSE], 2L,
                              total[total > 0], "/")
  }
  out
}

# T and M retain the old IMshareM origin distribution; E retains IMshareC.
IMshareM <- read_country_matrix("IMshareM", normalize = TRUE)
IMshareC <- read_country_matrix("IMshareC", normalize = TRUE)
evtrade <- read_country_matrix("EV_trade")
fvtrade <- read_country_matrix("FV_trade")


########################## construct EV input columns #########################
r26 <- match(paste0(coulist, "_C26"), seclist)
r27 <- match(paste0(coulist, "_C27"), seclist)
r29 <- match(paste0(coulist, "_C29"), seclist)
u_A <- setNames(colSums(A[, r29, drop = FALSE]), coulist)
if (anyNA(c(u_base[selected], TLS_share[selected], VA_share[selected])))
  stop("ICIO_intensity is missing an EV country or share.")
if (max(abs(u_A[selected] - u_base[selected])) > 1e-6)
  stop("ICIO_intensity$u_intermediate does not match the 2020 A matrix.")
if (any(u_base[selected] <= 0))
  stop("ICIO_intensity$u_intermediate must be positive for every EV country.")
if (any(TLS_share[selected] < 0 | VA_share[selected] < 0 |
        TLS_share[selected] + VA_share[selected] >= 1))
  stop("TLS and VA shares must be nonnegative and sum to less than one.")
u_scale <- u_target / u_base
message("EV columns will be scaled to 1 - TLS share - VA share for ",
        length(selected), " countries.")

evinput <- matrix(0, M, length(selected),
                  dimnames = list(seclist, paste0(selected, "_EV")))
beta_used <- matrix(0, length(selected), length(groups),
                    dimnames = list(selected, groups))
profile_used <- setNames(character(length(selected)), selected)

for (j in seq_along(selected)) {
  country <- selected[j]
  c <- sorder[j]
  p <- if (country %in% profiles) country else "OTHERS"
  b <- u_base[country] * bomshare[p, ] * u_scale[country]
  beta_used[j, ] <- b
  profile_used[j] <- p
  
  # Battery T and motor M: C27, alpha plus IMshareM.
  for (q in c("T", "M")) {
    evinput[r27[c], j] <- evinput[r27[c], j] + alpha[c, q] * b[q]
    evinput[r27, j] <- evinput[r27, j] +
      (1 - alpha[c, q]) * b[q] * IMshareM[, c]
  }
  
  # Electronic control E: BMS+VCU to C26; MCU+OBC+DCDC+PDU to C27.
  for (sector in c("C26", "C27")) {
    rows <- if (sector == "C26") r26 else r27
    budget <- b["E"] * eweight[p, sector]
    evinput[rows[c], j] <- evinput[rows[c], j] + alpha[c, "E"] * budget
    evinput[rows, j] <- evinput[rows, j] +
      (1 - alpha[c, "E"]) * budget * IMshareC[, c]
  }
  
  # I, EE, HV and shared components follow the original C29 input pattern.
  basis <- A[r26, r29[c]]
  evinput[r26, j] <- evinput[r26, j] + b["I"] * basis / sum(basis)
  
  rows <- c(r26, r27, r29)
  basis <- A[rows, r29[c]]
  evinput[rows, j] <- evinput[rows, j] + b["EE"] * basis / sum(basis)
  
  basis <- A[r29, r29[c]]
  evinput[r29, j] <- evinput[r29, j] + b["HV"] * basis / sum(basis)
  
  basis <- A[, r29[c]]
  evinput[, j] <- evinput[, j] + b["SHARED"] * basis / sum(basis)
}

if (any(!is.finite(evinput)) || any(evinput < 0))
  stop("EV input matrix contains an invalid value.")
if (max(abs(colSums(evinput) + TLS_share[selected] + VA_share[selected] - 1)) > 1e-8)
  stop("An EV column plus its TLS and VA shares does not equal one.")


#################### FV columns and final-demand division #####################
fvinput <- nonevA[, r29[sorder], drop = FALSE]
colnames(fvinput) <- paste0(selected, "_FV")

evfd <- matrix(0, length(selected), G,
               dimnames = list(paste0(selected, "_EV"), coulist))
fvfd <- matrix(0, length(selected), G,
               dimnames = list(paste0(selected, "_FV"), coulist))

for (j in seq_along(selected)) {
  country <- selected[j]
  c <- sorder[j]
  original <- fd[r29[c], ]
  total <- evtrade[country, ] + fvtrade[country, ]
  split <- total > 0
  evfd[j, split] <- original[split] * evtrade[country, split] / total[split]
  fvfd[j, split] <- original[split] * fvtrade[country, split] / total[split]
  fd[r29[c], ] <- original - evfd[j, ] - fvfd[j, ]
}


############################ expand A and output ##############################
AEV <- cbind(A, evinput, fvinput)
newnames <- c(colnames(evinput), colnames(fvinput))
newrows <- matrix(0, length(newnames), ncol(AEV),
                  dimnames = list(newnames, colnames(AEV)))
AEV <- rbind(AEV, newrows)
fdEV <- rbind(fd, evfd, fvfd)
primary_input <- 1 - colSums(AEV)
if (max(abs(colSums(fdEV) - colSums(base$fd))) > 1e-7)
  stop("Final demand is not conserved after the EV/FV split.")

profile_table <- data.frame(country_code = selected,
                            BOM_profile = unname(profile_used),
                            u_target = u_target[selected],
                            bomshare[profile_used, , drop = FALSE],
                            beta_used,
                            u_base = u_base[selected],
                            TLS_share = TLS_share[selected],
                            VA_share = VA_share[selected],
                            scale_factor = u_scale[selected],
                            check.names = FALSE)
names(profile_table)[4:(3 + length(groups))] <- paste0("b_", groups)
names(profile_table)[(4 + length(groups)):(3 + 2 * length(groups))] <-
  paste0("beta_", groups)

if (write_outputs) {
  dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
  write.csv(AEV, paste0(out_path, "/AEV_v6.csv"), quote = FALSE)
  write.csv(fdEV, paste0(out_path, "/fdEV_v6.csv"), quote = FALSE)
  write.csv(data.frame(industry = names(primary_input),
                       primary_input_share = primary_input),
            paste0(out_path, "/Primary_input_v6.csv"),
            row.names = FALSE, quote = FALSE)
  write.csv(profile_table, paste0(out_path, "/BOM_used_v6.csv"),
            row.names = FALSE, quote = FALSE)
}

message("EV-ICIO v6 completed: ", length(selected), " EV countries; A dimension = ",
        nrow(AEV), " x ", ncol(AEV), ".")
