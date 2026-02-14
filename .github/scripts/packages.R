# .github/scripts/packages.R

if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pkg_install(c("base64enc", "crayon"))
