# Endorsements Dataset – Methodology & Design Decisions

## 1. Purpose
This project constructs a unified, event-level dataset of elite political endorsements in U.S. primary elections by combining multiple heterogeneous raw sources. The goal is to produce a transparent, reproducible dataset suitable for academic research, with full provenance and clear handling of discrepancies across sources.

---

## 2. Unit of Observation
The unit of observation is an **endorsement event**.

> One row represents one endorser endorsing one candidate in a given contest (cycle × party), optionally with a date.

This structure preserves maximal flexibility: the data can later be aggregated by candidate, endorser, time period, or institution.

---

## 3. Canonical Data Schema

All raw sources are mapped into a common canonical schema before merging.

### 3.1 Identifiers
- `endorsement_uid` – project-generated unique identifier  
- `cycle` – election year (e.g., 2008, 2012)  
- `party` – `D`, `R`, or `NA`  
- `contest_id` – concatenation of cycle and party (e.g., `2008D`, `2012R`)  

### 3.2 Candidate
- `candidate_name_raw` – name as it appears in the source  
- `candidate_name` – standardized name  

### 3.3 Endorser
- `endorser_name_raw`  
- `endorser_name` – standardized  
- `endorser_state`  
- `endorser_position_raw`  
- `endorser_position` – standardized bucket (e.g., Governor, Senator, Representative, Other)  

### 3.4 Timing
- `endorsement_date_raw`  
- `endorsement_date` – ISO formatted date (YYYY-MM-DD) or NA  
- `date_precision` – `exact`, `month`, `year`, or `unknown`  
- `made_up_date` – indicator (1 if date was imputed or approximated)  

### 3.5 Source / Provenance
- `source_id` – e.g., `TPD`, `DIA_p2008`, `DIA_p2012`, `538`  
- `source_url`  
- `source_citation`  
- `source_row_id` – ID if provided by source  
- `source_notes`  

### 3.6 Weights and Flags
- `weight_points`  
- `weight_system`  
- `is_second_choice`  
- `is_organization`  

---

## 4. Raw Data Sources

The dataset integrates three types of raw sources:

1. **TPD (Cohen et al., *The Party Decides*)**  
   Public academic dataset providing endorsement events, IDs, and weighting schemes.

2. **FiveThirtyEight hybrid dataset**  
   Includes TPD data plus FiveThirtyEight-collected endorsement information not publicly released at the raw level. Used internally for validation and augmentation but not redistributed.

3. **Democracy in Action (p2008.org, p2012.org)**  
   Publicly accessible endorsement listings scraped directly from the web.

Each source is documented separately in `docs/source_cards.md`.

---

## 5. Standardization Rules

### 5.1 Name standardization
All candidate and endorser names are mapped using explicit crosswalk tables:
- `candidate_name_crosswalk.csv`
- `endorser_name_crosswalk.csv`

Raw names are never overwritten.

### 5.2 Date handling
- Unparseable or missing dates are coded as `endorsement_date = NA`
- `date_precision` records how precise the date is
- Any imputed or inferred date is flagged with `made_up_date = 1`

No silent imputation is permitted.

---

## 6. Deduplication Identity

Two rows are treated as the same endorsement event if they match on:

> `(cycle, party, candidate_name, endorser_name)`

Dates are used for validation and conflict resolution but not required for identity.

---

## 7. Source Priority Order

When the same endorsement appears in multiple sources, the canonical record is selected using:

> **TPD > FiveThirtyEight > Democracy in Action**

Interpretation:
- TPD is the authoritative academic baseline
- FiveThirtyEight is used when TPD is missing information
- DIA is used to fill gaps not covered by either

Provenance from all contributing sources is preserved in the final dataset.

---

## 8. Reproducibility and Public Release

Publicly available raw sources (TPD, DIA) are redistributed in this repository.  
Restricted sources (FiveThirtyEight raw files) are excluded but used internally to construct the final dataset.

All cleaning, standardization, and merging steps are implemented in scripts so that the final dataset can be reproduced by anyone with access to the public raw sources.
