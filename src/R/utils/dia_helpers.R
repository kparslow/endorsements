# src/R/utils/dia_helpers.R

suppressPackageStartupMessages({
  library(rvest)
  library(stringr)
  library(lubridate)
  library(dplyr)
  library(tibble)
})

# ----------------------------
# Utilities
# ----------------------------

ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
}

scrape_body_lines <- function(url) {
  x <- read_html(url)
  txt <- x %>% html_nodes("body") %>% html_text()
  lines <- str_split(txt, "\n", simplify = TRUE) %>% as.character()
  lines <- str_squish(lines)
  lines <- lines[nzchar(lines)]
  lines
}

# Map DIA title prefix to a standardized bucket
bucket_position <- function(x) {
  # x may include prefix like "Gov." or "Sen." or "Rep."
  ifelse(
    str_detect(x, "\\bGov\\."), "Governor",
    ifelse(str_detect(x, "\\bSen\\.|U\\.S\\.\\s*Sen\\."), "Senator",
           ifelse(str_detect(x, "\\bRep\\.|U\\.S\\.\\s*Rep\\."), "Representative", NA_character_))
  )
}

# Parse dates flexibly + record precision + whether imputed
parse_dia_date <- function(x) {
  x <- str_squish(x)
  if (is.na(x) || x == "") {
    return(list(date = as.Date(NA), precision = "unknown", made_up = 1))
  }

  # 1) mm/dd/yy
  dt1 <- suppressWarnings(as.Date(x, format = "%m/%d/%y"))
  if (!is.na(dt1)) return(list(date = dt1, precision = "exact", made_up = 0))

  # 2) "Jan. 31, 2008"
  dt2 <- suppressWarnings(as.Date(x, format = "%b. %d, %Y"))
  if (!is.na(dt2)) return(list(date = dt2, precision = "exact", made_up = 0))

  # 3) "January 31, 2008"
  dt3 <- suppressWarnings(as.Date(x, format = "%B %d, %Y"))
  if (!is.na(dt3)) return(list(date = dt3, precision = "exact", made_up = 0))

  # 4) Month Year (impute 15th)
  m <- str_match(x, "^([A-Za-z]+)\\s+(\\d{4})")
  if (!is.na(m[1, 1])) {
    dtm <- suppressWarnings(as.Date(paste0(m[1, 1], " ", m[1, 2], "-15"), format = "%B %Y-%d"))
    if (!is.na(dtm)) return(list(date = dtm, precision = "month", made_up = 1))
  }

  # 5) Year only (impute mid-year)
  y <- str_match(x, "(\\d{4})")
  if (!is.na(y[1, 2])) {
    dty <- as.Date(paste0(y[1, 2], "-07-01"))
    return(list(date = dty, precision = "year", made_up = 1))
  }

  list(date = as.Date(NA), precision = "unknown", made_up = 1)
}

# Return a canonical-schema tibble given minimal DIA fields
as_canonical_dia <- function(df, cycle, party, source_id, source_url, source_citation) {
  df %>%
    mutate(
      cycle = as.integer(cycle),
      party = party,
      contest_id = paste0(cycle, party),

      # placeholders for Stage 2 crosswalk standardization
      candidate_name = NA_character_,
      endorser_name = NA_character_,

      endorser_position = bucket_position(endorser_position_raw),

      # weights don't exist in DIA
      weight_points = NA_real_,
      weight_system = NA_character_,

      # flags not available in DIA
      is_second_choice = NA_integer_,
      is_organization = NA_integer_,

      # provenance
      source_id = source_id,
      source_url = source_url,
      source_citation = source_citation,
      source_row_id = NA_character_
    ) %>%
    select(
      cycle, party, contest_id,
      candidate_name_raw, candidate_name,
      endorser_name_raw, endorser_name,
      endorser_state,
      endorser_position_raw, endorser_position,
      endorsement_date_raw, endorsement_date, date_precision, made_up_date,
      source_id, source_url, source_citation, source_row_id, source_notes,
      weight_points, weight_system,
      is_second_choice, is_organization
    )
}
