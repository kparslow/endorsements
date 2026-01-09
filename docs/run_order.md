# Run order (pipeline)

Stage 1: Extract to interim
1. Extract DIA 2008 → data/interim/dia/DIA_2008_parsed.csv
2. Extract DIA 2012 → data/interim/dia/DIA_2012_parsed.csv
3. Extract TPD → data/interim/tpd/TPD_parsed.csv
4. (Restricted) Extract 538 → data/interim/538/538_parsed.csv (not redistributed)

Stage 2: Standardize
5. Build crosswalks (candidate/endorser/position)
6. Apply crosswalks to each source interim file

Stage 3: Merge + deduplicate
7. Merge sources using priority TPD > 538 > DIA
8. Produce master endorsement-events file

Stage 4: Release
9. Export data/cleaned/endorsements_events.csv and docs/codebook.md
