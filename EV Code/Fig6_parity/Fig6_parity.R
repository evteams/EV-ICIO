# Backward-compatible main-text entry / 兼容原命令的正文入口。
# Main text and SI now have independent scripts and input folders.
# 正文：main_text/Fig6_parity.R；SI：SI/Fig6_SI.R。
# Annual mileage is read from each package's input/vehicle_use_2023.csv.
Sys.unsetenv("LC_ALL")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "English_United States.utf8"))
source_paths <- unlist(lapply(sys.frames(), function(x) x$ofile))
file_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(source_paths)) dirname(normalizePath(tail(source_paths, 1))) else
  if (length(file_arg)) dirname(normalizePath(sub("^--file=", "", file_arg[1]))) else getwd()
source(file.path(project_dir, "main_text", "Fig6_parity.R"))
