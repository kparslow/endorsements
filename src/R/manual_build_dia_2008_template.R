# src/R/manual_build_dia_2008_template.R
# Build a fill-in XLSX from a saved DIA HTML page (2008 early endorsements)
# Robust to multiple candidate headers inside the same <p> (e.g., Paul -> Giuliani)
# Creates 2 sheets:
#   - manual_template: line-level entries to hand-audit
#   - candidate_counts: counts by party x candidate_raw

rm(list = ls()); graphics.off()

suppressPackageStartupMessages({
  library(rvest)
  library(xml2)
  library(stringr)
  library(dplyr)
  library(tibble)
  library(openxlsx)
})

# ----------------------------
# Paths
# ----------------------------
in_path  <- "data/archive/dia/dia_2008_early_endorsements.html"
out_dir  <- file.path("data", "manual", "dia")
out_path <- file.path(out_dir, "DIA_2008_manual_template.xlsx")

if (!file.exists(in_path)) stop("HTML file not found: ", in_path)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ----------------------------
# Helpers
# ----------------------------

# Convert an HTML node to a clean vector of text lines, using <br> as line breaks.
node_to_lines_stream <- function(node) {
  html <- as.character(node)
  html <- gsub("(?i)<br\\s*/?>", "\n", html, perl = TRUE)
  html <- gsub("&nbsp;", " ", html, fixed = TRUE)
  txt  <- gsub("<[^>]+>", "", html)
  txt  <- gsub("\\r", "", txt)
  
  lines <- unlist(strsplit(txt, "\n", fixed = TRUE))
  lines <- str_squish(lines)
  lines <- lines[nzchar(lines)]
  
  # Drop common filler tokens (keep "none" because it's informative)
  drop <- c("and", "former", ". . .", "Notes.", "see also:")
  lines <- lines[!(tolower(lines) %in% tolower(drop))]
  
  lines
}

# endorsement-like if it contains a state/district paren
looks_like_endorsement <- function(x) {
  str_detect(x, "\\([A-Za-z]{2,6}(-\\d+)?\\)")
}

extract_state <- function(x) {
  m <- str_match(x, ".*?\\(([^)]+)\\)")
  ifelse(is.na(m[,2]), NA_character_, str_squish(m[,2]))
}

extract_date_raw <- function(x) {
  parens <- str_match_all(x, "\\(([^)]+)\\)")[[1]]
  if (nrow(parens) == 0) return(NA_character_)
  vals <- str_squish(parens[,2])
  if (length(vals) <= 1) return(NA_character_)  # only state/district present
  
  vals2 <- vals[-1]
  idx <- which(
    str_detect(vals2, "(?i)\\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\\b") |
      str_detect(vals2, "\\b\\d{4}\\b")
  )
  if (length(idx) == 0) return(NA_character_)
  vals2[idx[1]]
}

parse_date_best_effort <- function(x) {
  if (is.na(x) || !nzchar(x)) return(as.Date(NA))
  
  x2 <- str_squish(x)
  x2 <- str_remove(x2, "^(announced|reported)\\s+")
  x2 <- str_remove(x2, "\\.$")
  
  suppressWarnings({
    d1 <- as.Date(x2, format = "%b. %d, %Y")
    if (!is.na(d1)) return(d1)
    d2 <- as.Date(x2, format = "%b %d, %Y")
    if (!is.na(d2)) return(d2)
    d3 <- as.Date(x2, format = "%B %d, %Y")
    if (!is.na(d3)) return(d3)
  })
  
  # Do not invent dates for "July 2006" or "2006" here—leave for manual audit.
  as.Date(NA)
}

split_office_name <- function(raw_line) {
  x <- str_squish(raw_line)
  x <- str_remove(x, "^\\?\\?\\s*")
  x <- str_remove(x, "^\\+\\s*")
  
  before_state <- str_squish(str_split_fixed(x, "\\(", 2)[,1])
  
  patterns <- c(
    "^(Gov\\.)\\s+(.*)$",
    "^(U\\.S\\.\\s+Rep\\.)\\s+(.*)$",
    "^(U\\.S\\.\\s+Sen\\.)\\s+(.*)$",
    "^(Rep\\.)\\s+(.*)$",
    "^(Sen\\.)\\s+(.*)$",
    "^(Delegate\\s+to\\s+Congress)\\s+(.*)$",
    "^(Speaker)\\s+(.*)$"
  )
  
  for (p in patterns) {
    m <- str_match(before_state, p)
    if (!all(is.na(m))) {
      return(list(office = str_squish(m[1,2]), name = str_squish(m[1,3])))
    }
  }
  
  m2 <- str_match(before_state, "^([^\\s]+\\.)\\s+(.*)$")
  if (!all(is.na(m2))) {
    return(list(office = str_squish(m2[1,2]), name = str_squish(m2[1,3])))
  }
  
  list(office = NA_character_, name = NA_character_)
}

# ----------------------------
# 1) Read saved HTML and locate the main table + party columns
# ----------------------------
doc <- read_html(in_path)

tab1 <- xml_find_first(doc, "/html/body/table[1]")
if (inherits(tab1, "xml_missing")) {
  tabs <- html_elements(doc, "table")
  if (length(tabs) == 0) stop("No <table> elements found in saved HTML.")
  tab1 <- tabs[[1]]
}

tds <- xml_find_all(tab1, ".//td[@valign='top' and @width='50%']")
if (length(tds) < 2) {
  tds <- html_elements(tab1, "tbody > tr > td")
}
if (length(tds) < 2) stop("Could not identify two party columns in table[1].")

rep_td <- tds[[1]]
dem_td <- tds[[2]]

# ----------------------------
# 2) Extract candidate list per column (from <b><u>…</u></b>)
# ----------------------------
candidate_list_from_td <- function(td_node) {
  u_nodes <- xml_find_all(td_node, ".//b/u")
  if (length(u_nodes) == 0) return(character(0))
  cands <- str_squish(xml_text(u_nodes))
  cands <- cands[nzchar(cands)]
  # preserve order, drop duplicates
  cands[!duplicated(cands)]
}

rep_candidates <- candidate_list_from_td(rep_td)
dem_candidates <- candidate_list_from_td(dem_td)

# ----------------------------
# 3) Convert td into a single line stream + assign candidates by header lines
# ----------------------------
extract_rows_from_td_stream <- function(td_node, party_label, candidate_names) {
  # Entire column as a line stream (robust to multiple headers per <p>)
  lines <- node_to_lines_stream(td_node)
  
  # Some candidate headers might not appear perfectly alone; but on DIA they usually do.
  # We'll treat a line as a header if it matches exactly one candidate name.
  cand_set <- unique(candidate_names)
  
  rows <- list()
  current_candidate <- NA_character_
  
  for (ln in lines) {
    # Candidate header?
    if (ln %in% cand_set) {
      current_candidate <- ln
      next
    }
    
    # Keep endorsement lines only
    if (!looks_like_endorsement(ln)) next
    
    rows[[length(rows) + 1]] <- tibble(
      cycle = 2008L,
      party = party_label,
      candidate_raw = current_candidate,
      raw_line = ln
    )
  }
  
  bind_rows(rows)
}

rep_rows <- extract_rows_from_td_stream(rep_td, "R", rep_candidates)
dem_rows <- extract_rows_from_td_stream(dem_td, "D", dem_candidates)

out <- bind_rows(rep_rows, dem_rows)

if (nrow(out) == 0) {
  stop("Extracted 0 rows. The saved HTML may not match the expected DIA structure.")
}

# ----------------------------
# 4) Derived fields for manual auditing
# ----------------------------
out <- out %>%
  mutate(
    source_file = in_path,
    source_type = "DIA (saved HTML)",
    source_page = "2008 early endorsements",
    
    state_or_district = extract_state(raw_line),
    endorsement_date_raw = vapply(raw_line, extract_date_raw, character(1)),
    endorsement_date = vapply(endorsement_date_raw, parse_date_best_effort, as.Date(NA)),
    
    tmp_split = lapply(raw_line, split_office_name),
    endorser_office = vapply(tmp_split, function(x) x$office, character(1)),
    endorser_name   = vapply(tmp_split, function(x) x$name, character(1)),
    
    notes = NA_character_,
    needs_review = 1L
  ) %>%
  mutate(
    row_id = sprintf("DIA2008_%04d", row_number())
  ) %>%
  select(
    row_id, cycle, party, candidate_raw,
    endorser_name, endorser_office, state_or_district,
    endorsement_date_raw, endorsement_date,
    notes, needs_review,
    raw_line, source_type, source_file, source_page
  )

# ----------------------------
# 5) Candidate counts
# ----------------------------
counts <- out %>%
  mutate(candidate_raw = ifelse(is.na(candidate_raw) | candidate_raw == "", "(missing)", candidate_raw)) %>%
  count(party, candidate_raw, name = "n_rows") %>%
  arrange(party, desc(n_rows), candidate_raw)

# ----------------------------
# 6) Write XLSX (2 sheets)
# ----------------------------
wb <- createWorkbook()

addWorksheet(wb, "manual_template")
writeData(wb, "manual_template", out)
freezePane(wb, "manual_template", firstRow = TRUE)
addFilter(wb, "manual_template", rows = 1, cols = 1:ncol(out))
setColWidths(wb, "manual_template", cols = 1:ncol(out), widths = "auto")

addWorksheet(wb, "candidate_counts")
writeData(wb, "candidate_counts", counts)
freezePane(wb, "candidate_counts", firstRow = TRUE)
addFilter(wb, "candidate_counts", rows = 1, cols = 1:ncol(counts))
setColWidths(wb, "candidate_counts", cols = 1:ncol(counts), widths = "auto")

message("Workbook sheets BEFORE save: ", paste(names(wb), collapse = ", "))
saveWorkbook(wb, out_path, overwrite = TRUE)

message("Wrote: ", out_path)
message("Rows: ", nrow(out))
message("Party breakdown:")
print(table(out$party))
message("Top candidates by extracted rows:")
print(head(counts, 20))
