# src/R/01_extract_dia_2008.R

rm(list = ls()); graphics.off()

source("src/R/utils/dia_helpers.R")

URL <- "https://p2008.org/cands08/endorse08el2.html"

# --- Scrape page ---
lines <- scrape_body_lines(URL)

# DIA 2008 page includes party sections and then candidate headers
party <- NA_character_
candidate <- NA_character_

is_endorsement <- str_detect(lines, "^(Gov\\.|U\\.S\\.\\s*Sen\\.|U\\.S\\.\\s*Rep\\.|Sen\\.|Rep\\.)")

rows <- list()

for (ln in lines) {

  # Party markers on page
  if (ln == "R E P U B L I C A N S") { party <- "R"; candidate <- NA_character_; next }
  if (ln == "D E M O C R A T S")     { party <- "D"; candidate <- NA_character_; next }

  # Candidate headers: short standalone lines after party has been set
  # (This heuristic may need small tweaks if the page layout changes.)
  if (!is.na(party) &&
      !is_endorsement &&
      nchar(ln) <= 35 &&
      str_detect(ln, "^[A-Za-z .'-]+$") &&
      !str_detect(ln, "Endorsements|Senators|House members|Governors|Notes|see also|through")) {
    candidate <- ln
    next
  }

  # Endorsement lines start with office prefix
  if (!is.na(party) && str_detect(ln, "^(Gov\\.|U\\.S\\.\\s*Sen\\.|U\\.S\\.\\s*Rep\\.)")) {

    # Example structure: "Gov. Jane Doe (TX) (Jan. 02, 2008) [optional note]"
    m <- str_match(ln, "^(.*)\\(([^)]+)\\)\\s*(.*)$")
    endorser_part <- str_squish(m[1, 2])
    state_part <- str_squish(m[1, 3])
    rest <- str_squish(m[1, 4])

    date_in_parens <- str_match(rest, "\\(([^)]+)\\)")[1, 2]
    endorsement_date_raw <- ifelse(!is.na(date_in_parens), date_in_parens, NA_character_)

    # Anything else after removing the (date) is treated as a note
    source_notes <- NA_character_
    if (!is.na(date_in_parens)) {
      source_notes <- str_squish(str_replace(rest, fixed(paste0("(", date_in_parens, ")")), ""))
      if (is.na(source_notes) || source_notes == "") source_notes <- NA_character_
    }

    dt <- parse_dia_date(endorsement_date_raw)

    rows[[length(rows) + 1]] <- tibble(
      party = party,
      candidate_name_raw = candidate,
      endorser_name_raw = endorser_part,
      endorser_state = state_part,
      endorser_position_raw = endorser_part,
      endorsement_date_raw = endorsement_date_raw,
      endorsement_date = dt$date,
      date_precision = dt$precision,
      made_up_date = dt$made_up,
      source_notes = source_notes
    )
  }
}

df <- bind_rows(rows)

# Build canonical output
out <- as_canonical_dia(
  df,
  cycle = 2008,
  party = df$party, # uses parsed party per row
  source_id = "DIA_p2008",
  source_url = URL,
  source_citation = "p2008.org: 'Endorsements by Congressmen, Senators and Governors—Feb. 5 edition' (scraped via R script)"
)

# as_canonical_dia expects a single party value; handle row-wise party here:
out$party <- df$party
out$contest_id <- paste0(out$cycle, out$party)

# Write output
out_dir <- file.path("data", "interim", "dia")
ensure_dir(out_dir)

out_file <- file.path(out_dir, "DIA_2008_parsed.csv")
write.csv(out, out_file, row.names = FALSE)

message("Wrote: ", out_file)
