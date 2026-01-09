# src/R/audit_538_counts_2008_2012.R
# Produce endorsement counts by candidate for 2008 and 2012 from FiveThirtyEight

rm(list = ls()); graphics.off()

suppressPackageStartupMessages({
  library(openxlsx)
  library(dplyr)
  library(stringr)
  library(tibble)
})

# ----------------------------
# 0) Read FiveThirtyEight data
# ----------------------------
in_path <- "data/raw/538_raw.xlsx"
if (!file.exists(in_path)) stop("File not found: ", in_path)

df <- openxlsx::read.xlsx(in_path, sheet = "Raw data", detectDates = TRUE) %>%
  as_tibble()

names(df) <- make.names(names(df), unique = TRUE)

contest_col  <- names(df)[tolower(names(df)) == "contest"][1]
endorsee_col <- names(df)[tolower(names(df)) == "endorsee"][1]

if (is.na(contest_col))  stop("Couldn't find `contest` column.")
if (is.na(endorsee_col)) stop("Couldn't find `endorsee` column.")

# ----------------------------
# 1) Parse cycle and party
# ----------------------------
df2 <- df %>%
  mutate(
    contest  = str_squish(as.character(.data[[contest_col]])),
    endorsee = str_squish(as.character(.data[[endorsee_col]])),
    cycle = as.integer(str_extract(contest, "^\\d{4}")),
    party = str_extract(contest, "[RD]$")
  ) %>%
  filter(cycle %in% c(2008L, 2012L)) %>%
  filter(!is.na(party)) %>%
  filter(!is.na(endorsee), endorsee != "")

# ----------------------------
# 2) Count endorsements
# ----------------------------
counts <- df2 %>%
  group_by(cycle, party, endorsee) %>%
  summarise(n_endorsements_538 = n(), .groups = "drop")

# ----------------------------
# 3) Split by year
# ----------------------------
counts_2008 <- counts %>%
  filter(cycle == 2008) %>%
  arrange(party, desc(n_endorsements_538), endorsee)

counts_2012 <- counts %>%
  filter(cycle == 2012) %>%
  arrange(party, desc(n_endorsements_538), endorsee)

# ----------------------------
# 4) Write outputs
# ----------------------------
out_dir <- file.path("data", "audit", "538")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(counts_2008,
          file.path(out_dir, "538_counts_2008_by_candidate.csv"),
          row.names = FALSE)

write.csv(counts_2012,
          file.path(out_dir, "538_counts_2012_by_candidate.csv"),
          row.names = FALSE)

# ----------------------------
# 5) Print summary to console
# ----------------------------
cat("\n2008 totals by party:\n")
print(counts_2008 %>% group_by(party) %>% summarise(total = sum(n_endorsements_538)))

cat("\n2012 totals by party:\n")
print(counts_2012 %>% group_by(party) %>% summarise(total = sum(n_endorsements_538)))

cat("\nFiles written to: data/audit/538/\n")
