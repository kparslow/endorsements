# Source Cards — Raw Data Provenance

This document records the provenance, structure, and intended use of each raw data source used to construct the endorsements dataset.

---

## 1. TPD (Cohen et al., *The Party Decides*)

**Source ID:** `TPD`

**Files:**
- `Cohen_Data_Raw.xls`
- `TPD_Codebook.doc`

**Coverage:** Presidential primary endorsements, approximately 1980–2012 (both parties)

**Unit of observation:** Individual endorsement events, with unique endorsement and endorser IDs

**Origin:**
The dataset is produced by Marty Cohen, David Karol, Hans Noel, and John Zaller as part of the project *The Party Decides*. It is publicly distributed for academic research via Marty Cohen’s website and related replication materials.

**How obtained:**
Downloaded from the authors’ website and associated replication materials.

**Licensing / sharing:**
Publicly released for academic research by the authors (Cohen, Karol, Noel, and Zaller). Redistribution of the raw data and derived datasets is permitted with appropriate citation to the original authors and source.

**What’s inside:**
The dataset includes unique IDs for endorsements and endorsers, candidate identifiers, endorsement dates, endorser positions, organizational flags, second-choice indicators, and weighting systems defined in the accompanying codebook.

**Data quality and quirks:**
- Provides canonical IDs and structured metadata
- Some older cycles may have less precise dates
- Names require standardization for merging

**Role in this project:**
TPD serves as the authoritative academic baseline. When multiple sources report the same endorsement, the TPD version is treated as canonical unless missing.

---

## 2. FiveThirtyEight Hybrid Dataset

**Source ID:** `538`

**Files:**
- `538_Raw_Data.xlsx` (restricted; not redistributed)

**Coverage:** Primarily 2012 Republican primary endorsements

**Unit of observation:** Individual endorsement events with weighting

**Origin:**
FiveThirtyEight compiled and curated endorsement data for use in their endorsement-based forecasting and analysis, combining Party Decides data with their own additional collection and cleaning.

**How obtained:**
Provided via direct email communication rather than public download.

**Licensing / sharing:**
This file contains a mixture of publicly available Party Decides data (Cohen et al.) and endorsement data collected and curated by FiveThirtyEight. While summary statistics and visualizations were publicly released by FiveThirtyEight, the raw endorsement-level data were not publicly distributed. This file is therefore treated as restricted: it is used to construct derived datasets and for validation, but is not redistributed in this repository.

**What’s inside:**
Event-level endorsements including candidate, endorser, endorser type, date, state, and weight points. Some fields originate from TPD; others are unique to FiveThirtyEight’s collection.

**Data quality and quirks:**
- Includes weight points and richer date coverage
- Some proprietary fields cannot be publicly redistributed

**Role in this project:**
Used to augment and validate TPD data when TPD is missing information, but not treated as the primary public source.

---

## 3. Democracy in Action (p2008.org, p2012.org)

**Source ID:** `DIA_p2008`, `DIA_p2012`

**Files:**
- `DIA_2008_extract.R` → outputs `DIA_2008_endorsements_parsed.xlsx`
- `DIA_2012_extract.R` → outputs `DIA_2012_endorsements_parsed.xlsx`

**Coverage:**
- 2008 and 2012 presidential primaries

**Unit of observation:** Individual endorsement events

**Origin:**
Public political information websites:
- https://p2008.org
- https://p2012.org

These sites publish endorsement lists for candidates during U.S. presidential primaries.

**How obtained:**
Web pages were scraped using R (rvest) via custom extraction scripts.

**Licensing / sharing:**
Data scraped from publicly accessible political information websites. These sites publish factual political endorsement information intended for public use. Extracted data are redistributed here for research purposes with attribution to the original websites.

**What’s inside:**
Endorser names, states, endorsement dates (sometimes inferred), and indicator flags for imputed dates or special notes.

**Data quality and quirks:**
- Dates sometimes inferred from text and flagged as `made_up_date`
- Names and titles are not standardized
- No built-in weighting system

**Role in this project:**
Used to fill gaps in coverage and improve date completeness where TPD or FiveThirtyEight do not report an endorsement.
