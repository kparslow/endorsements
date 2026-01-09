# src/R/01_extract_dia_2012.R

rm(list = ls()); graphics.off()

source("src/R/utils/dia_helpers.R")

URL <- "https://p2012.org/candidates/natendorse.html"

lines <- scrape_body_lines(URL)

# The 2012 page is Republican national endorsements and is candidate-sectioned.
party <- "R"
cycle <- 2012

# Candidate header list (kept explicit for stability; you can expand later)
known_candidates <- c(
  "Mitt Romney", "Newt Gingrich", "Rick Santorum", "Ron Paul",
  "Jon Huntsman", "Michele Bachmann", "Rick Perry", "Herman Cain"
)

current_candidate <- NA_character_
rows <- list()

for (ln in lines) {

  # Update candidate when we hit a known candidate header
  if (ln %in% known_candidates) {
    current_candidate <- ln
    next
  }

  # Endorsement lines
  if (str_detect(ln, "^(\\*?)(Gov\\.|Sen\\.|Rep\\.)")) {

    starred <- str_detect(ln, "^\\*")
    ln2 <- str_replace(ln, "^\\*", "") %>% str_squish()

    # Pull "X (ST) rest"
    m <- str_match(ln2, "^(.*)\\(([^)]+)\\)\\s*(.*)$")
    endorser_part <- str_squish(m[1, 2])
    state_part <- str_squish(m[1, 3])
    rest <- str_squish(m[1, 4])

    # Extract mm/dd/yy date token if present
    date_token <- str_match(rest, "^(\\d{2}/\\d{2}/\\d{2})")[1, 2]
    endorsement_date_raw <- ifelse(!is.na(date_token), date_token, NA_character_)

    # Preserve any trailing parenthetical note
    paren_note <- str_match(rest, "\\((.*)\\)$")[1, 2]

    notes <- c()
    if (starred) notes <- c(notes, "starred_endorsement")
    if (!is.na(paren_note)) notes <- c(notes, paren_note)
    source_notes <- ifelse(length(notes) > 0, paste(notes, collapse = " | "), NA_character_)

    dt <- parse_dia_date(endorsement_date_raw)

    rows[[length(rows) + 1]] <- tibble(
      candidate_name_raw = current_candidate,
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

out <- as_canonical_dia(
  df,
  cycle = cycle,
  party = party,
  source_id = "DIA_p2012",
  source_url = URL,
  source_citation = "p2012.org: 'National Endorsements (2012 Republican presidential candidates)' (scraped via R script)"
)

out_dir <- file.path("data", "interim", "dia")
ensure_dir(out_dir)

out_file <- file.path(out_dir, "DIA_2012_parsed.csv")
write.csv(out, out_file, row.names = FALSE)

message("Wrote: ", out_file)
