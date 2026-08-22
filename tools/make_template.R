# tools/make_template.R
#
# Generates the data entry Excel template for the outbreak network tool.
#
# Run from RStudio:
#   source("tools/make_template.R")
#
# Requires:
#   install.packages("openxlsx")
#
# Output:
#   templates/outbreak_data_template.xlsx
#
# Rerun this script whenever the schema changes to keep the template in sync.
#
# NOTE: The derived 'contexts' column in the cases sheet uses TEXTJOIN with
# implicit array evaluation and requires Excel 365 / Office 2021 or later.

library(openxlsx)

OUT_PATH <- "templates/outbreak_data_template.xlsx"
dir.create("templates", showWarnings = FALSE)

# ---- Styles -----------------------------------------------------------------

hdr_style <- createStyle(
  fontColour      = "#FFFFFF",
  fgFill          = "#2C3E50",
  textDecoration  = "bold",
  border          = "Bottom",
  borderColour    = "#7F8C8D",
  halign          = "left"
)

# Maroon header — marks the columns the network tool actually reads (case_id,
# onset_date, age_group, gender, vaccination_status, case_status,
# likely_index_case, primary_context_type). Blue (hdr_style) = fields collected
# for the linelist but not used by the tool. Overlaid on the table header after
# the sheet is written.
maroon_hdr_style <- createStyle(
  fontColour      = "#FFFFFF",
  fgFill          = "#800000",
  textDecoration  = "bold",
  border          = "Bottom",
  borderColour    = "#5C0000",
  halign          = "left"
)

example_style <- createStyle(
  fontColour     = "#999999",
  fgFill         = "#F5F5F5",
  textDecoration = "italic"
)

date_style     <- createStyle(numFmt = "DD/MM/YYYY")
locked_style   <- createStyle(fgFill = "#E8F0FE", locked = TRUE)   # light blue = auto/formula
unlocked_style <- createStyle(locked = FALSE)

note_style <- createStyle(fontColour = "#2C3E50", fontSize = 11)

title_style <- createStyle(
  fontColour     = "#2C3E50",
  fontSize       = 14,
  textDecoration = "bold"
)

section_style <- createStyle(
  fontColour     = "#7F8C8D",
  fontSize       = 11,
  textDecoration = "bold"
)

dup_style      <- createStyle(bgFill = "#FFD700", fontColour = "#000000")
self_ref_style <- createStyle(bgFill = "#FFCCCC", fontColour = "#CC0000")

input_style <- createStyle(fgFill = "#FFF9C4", border = "Bottom", borderColour = "#CCCCCC")

output_hdr_style <- createStyle(
  fontColour     = "#FFFFFF",
  fgFill         = "#27AE60",
  textDecoration = "bold",
  border         = "Bottom",
  borderColour   = "#1E8449"
)

weekend_style <- createStyle(bgFill = "#E8E8E8", fontColour = "#999999")


# ---- Workbook ---------------------------------------------------------------

wb <- createWorkbook()


# ---- Helper: add a data sheet -----------------------------------------------
# headers     — character vector of column names (in order)
# example     — list of example values (one per column)
# col_widths  — numeric vector of column widths
# date_cols   — integer vector of column indices to format as dates
# dropdowns   — list of list(col, formula): Excel list-string dropdowns
# validations — list of list(col, type, ...): other dataValidation calls
#               Supported types: "whole", "date", "custom"

add_sheet <- function(wb, name, headers, example, col_widths = NULL,
                      date_cols = NULL, dropdowns = list(),
                      validations = list(), nrows = 1, has_example = TRUE) {
  addWorksheet(wb, name, tabColour = "#2980B9")

  # Build data frame: 1 example row + (nrows-1) blank rows.
  # Pre-sizing the table to nrows means the Excel Table covers all rows from
  # the start and does not need to auto-expand as data is entered.
  # Names must be set on both frames before rbind — R auto-names from cell
  # values so the two frames would otherwise have mismatched column names.
  eg_df <- as.data.frame(example, stringsAsFactors = FALSE)
  names(eg_df) <- headers
  if (nrows > 1) {
    blank <- lapply(example, function(x) if (inherits(x, "Date")) as.Date(NA) else "")
    blank_df <- as.data.frame(blank, stringsAsFactors = FALSE)
    names(blank_df) <- headers
    extra_rows <- blank_df[rep(1L, nrows - 1L), ]
    rownames(extra_rows) <- NULL
    eg_df <- rbind(eg_df, extra_rows)
    rownames(eg_df) <- NULL
  }
  writeDataTable(wb, name, eg_df,
                 startRow    = 1,
                 startCol    = 1,
                 tableName   = name,
                 tableStyle  = "TableStyleLight1",
                 headerStyle = hdr_style,
                 withFilter  = TRUE,
                 bandedRows  = FALSE)

  if (has_example) {
    addStyle(wb, name, example_style,
             rows = 2, cols = seq_along(headers), gridExpand = TRUE, stack = TRUE)
  }

  if (!is.null(date_cols)) {
    addStyle(wb, name, date_style,
             rows = 2:2000, cols = date_cols, gridExpand = TRUE, stack = TRUE)
  }

  freezePane(wb, name, firstRow = TRUE)

  if (!is.null(col_widths)) {
    setColWidths(wb, name, cols = seq_along(headers), widths = col_widths)
  } else {
    setColWidths(wb, name, cols = seq_along(headers), widths = "auto")
  }

  for (dd in dropdowns) {
    dataValidation(wb, name,
                   col   = dd$col,
                   rows  = 2:2000,
                   type  = "list",
                   value = dd$formula)
  }

  for (v in validations) {
    if (v$type == "whole") {
      dataValidation(wb, name,
                     col      = v$col,
                     rows     = 2:2000,
                     type     = "whole",
                     operator = v$operator,
                     value    = v$value)
    } else if (v$type == "date") {
      dataValidation(wb, name,
                     col      = v$col,
                     rows     = 2:2000,
                     type     = "date",
                     operator = v$operator,
                     value    = v$value)
    } else if (v$type == "custom") {
      dataValidation(wb, name,
                     col   = v$col,
                     rows  = 2:2000,
                     type  = "custom",
                     value = v$value)
    }
  }
}


# ---- README -----------------------------------------------------------------

addWorksheet(wb, "README", tabColour = "#E74C3C")
setColWidths(wb, "README", cols = 1, widths = 90)

readme_rows <- list(
  list(style = title_style,   text = "OUTBREAK NETWORK TOOL — DATA ENTRY TEMPLATE"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "HOW TO FILL IN THIS TEMPLATE"),
  list(style = note_style,    text = "This workbook contains example data for a fictional 20-case measles outbreak."),
  list(style = note_style,    text = "Use it to explore the network tool, or overwrite the data with your outbreak data."),
  list(style = note_style,    text = ""),
  list(style = note_style,    text = "1.  Fill in (or overwrite) the 'cases' sheet — one row per case."),
  list(style = note_style,    text = "2.  Fill in (or overwrite) the 'contexts' sheet — one row per location linked to the outbreak."),
  list(style = note_style,    text = "    Context types are validated against the 'Lookups' tab — add types there if needed."),
  list(style = note_style,    text = "3.  Fill in (or overwrite) 'case_contexts' — one row per case x context combination."),
  list(style = note_style,    text = "    Once filled, the 'contexts' column in the cases sheet will populate automatically."),
  list(style = note_style,    text = "4.  Fill in (or overwrite) 'visit_dates' — one row per date a case visited a context."),
  list(style = note_style,    text = "5.  Save as .xlsx and upload using the Upload button in the network tool."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "COLUMN HEADER COLOURS (cases sheet)"),
  list(style = note_style,    text = "•  MAROON headers are the columns the network tool reads: case_id, age_group, gender,"),
  list(style = note_style,    text = "   onset_date, case_status, vaccination_status, likely_index_case, primary_context_type."),
  list(style = note_style,    text = "   Do not rename these headers — the upload matches them by name (case-sensitive)."),
  list(style = note_style,    text = "•  DARK BLUE headers are collected for your linelist but are NOT used by the network tool."),
  list(style = note_style,    text = "   You can leave them blank if you only want the network views."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "RULES"),
  list(style = note_style,    text = "•  case_id, context_id, age, age_group, exposure_window, infectious_period, and contexts"),
  list(style = note_style,    text = "   are AUTO-GENERATED — do not type in these columns (locked, blue shading)."),
  list(style = note_style,    text = "   case_id: C-001, C-002 … based on row position."),
  list(style = note_style,    text = "   context_id: Ctxt-001, Ctxt-002 … based on row position."),
  list(style = note_style,    text = "   age / age_group: calculated from date_of_birth and onset_date."),
  list(style = note_style,    text = "   exposure_window: date range 21 to 7 days before onset_date (measles incubation default)."),
  list(style = note_style,    text = "   infectious_period: date range 4 days before to 4 days after onset_date (measles default)."),
  list(style = note_style,    text = "   contexts: lists all context names linked to the case in the case_contexts sheet (semi-colon separated)."),
  list(style = note_style,    text = "•  CIMS_id: turns amber/yellow if a duplicate is detected — check and correct before uploading."),
  list(style = note_style,    text = "•  Do not delete rows — IDs are based on row position and will renumber if rows are removed."),
  list(style = note_style,    text = "•  Dates must be entered as Excel dates (DD/MM/YYYY) — not plain text."),
  list(style = note_style,    text = "•  Do not rename or reorder sheet tabs or column headers."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTEXTS COLUMN — one-time formula setup (do this once after filling the sheet)"),
  list(style = note_style,    text = "The 'contexts' column (AD) in the cases sheet is blank when the template first opens."),
  list(style = note_style,    text = "After filling in cases, contexts, and case_contexts, add the formula:"),
  list(style = note_style,    text = "  1. Click cell AD2 in the cases sheet."),
  list(style = note_style,    text = "  2. Type = then copy and paste the formula text below into the formula bar."),
  list(style = note_style,    text = "  3. Press Ctrl+Shift+Enter — NOT plain Enter. The formula bar must show {=...} with curly braces."),
  list(style = note_style,    text = "     If you see plain =... without curly braces, delete and re-enter using Ctrl+Shift+Enter."),
  list(style = note_style,    text = "  4. Copy AD2 (Ctrl+C), select AD3:AD1001, paste (Ctrl+V)."),
  list(style = note_style,    text = "     Check a few of the pasted cells — they should also show {=...} with curly braces."),
  list(style = note_style,    text = ""),
  list(style = note_style,    text = '     IF(A2="","",IFERROR(TEXTJOIN("; ",TRUE,IF(ISNUMBER(MATCH(A2&contexts!$A$2:$A$1001,case_contexts!$A$2:$A$2001&case_contexts!$B$2:$B$2001,0)),contexts!$B$2:$B$1001,"")),""))'),
  list(style = note_style,    text = ""),
  list(style = note_style,    text = "  Shows all context names linked to each case, semi-colon separated. Requires Excel 2019 or 365."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "VALIDATION — what the cells will check as you type"),
  list(style = note_style,    text = "•  date_of_birth, onset_date, visit_date: must be a valid date. Text is rejected."),
  list(style = note_style,    text = "•  CIMS_id: turns amber if the same value appears more than once."),
  list(style = note_style,    text = "•  context_type: must match a value in the 'Lookups' tab (Setting Types list)."),
  list(style = note_style,    text = "   To add a new type, go to the Lookups tab and add it to the Setting Types column."),
  list(style = note_style,    text = "•  case_id in 'case_contexts' and 'visit_dates': dropdown shows only IDs from the cases sheet."),
  list(style = note_style,    text = "•  context_id in 'case_contexts', 'visit_dates': dropdown shows only IDs from the contexts sheet."),
  list(style = note_style,    text = "   Fill 'cases' and 'contexts' first — their IDs will then appear in the dropdowns."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DROPDOWN FIELDS — select from the list; do not type free text"),
  list(style = note_style,    text = "•  gender:              Male | Female | Other | Unknown"),
  list(style = note_style,    text = "•  ethnicity:           Values from the Lookups tab, Ethnicity column (ONS 2021 categories)"),
  list(style = note_style,    text = "•  case_status (Case confidence): Confirmed | Probable | Possible"),
  list(style = note_style,    text = "•  confirmation_test_result: Saliva/Serum IgM positive or negative | PCR positive or negative | Not tested | Pending"),
  list(style = note_style,    text = "•  vaccination_status:  Unvaccinated | 1 dose | 2 doses | Unknown"),
  list(style = note_style,    text = "•  vaccination_confirmation_method: CHIS | GP | Occupational Health | Parent/guardian | Other | Unknown"),
  list(style = note_style,    text = "•  travel_history:      Yes | No | Unknown"),
  list(style = note_style,    text = "•  likely_index_case:   Any case_id already in the cases sheet (turns red if set to the case's own ID)"),
  list(style = note_style,    text = "•  probable_epi_link:   Yes | No | Unknown"),
  list(style = note_style,    text = "•  primary_context_type: Values from the Lookups tab (Setting Types, editable)"),
  list(style = note_style,    text = "•  status:              Open | Closed"),
  list(style = note_style,    text = "•  genotype:            free text (e.g. B3, D8) — not a dropdown"),
  list(style = note_style,    text = "•  exposure_relevance (case_contexts sheet): Infectious period | Exposure window | Both | Neither"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "LOOKUPS TAB — managing context types"),
  list(style = note_style,    text = "•  The 'Lookups' tab contains the Setting Types list used to validate context_type entries."),
  list(style = note_style,    text = "•  To add a type: type it in the next empty row of the Setting Types column."),
  list(style = note_style,    text = "•  To remove a type: delete the cell contents (do not leave blank rows in the middle of the list)."),
  list(style = note_style,    text = "•  To edit a type: overtype the existing value."),
  list(style = note_style,    text = "•  Changes take effect immediately in the context_type dropdown."),
  list(style = note_style,    text = "")
)

for (i in seq_along(readme_rows)) {
  writeData(wb, "README", readme_rows[[i]]$text, startRow = i, colNames = FALSE)
  addStyle(wb, "README", readme_rows[[i]]$style, rows = i, cols = 1)
}


# ---- Lookups ----------------------------------------------------------------
# Single-column list of valid setting/context types. Not an Excel Table —
# kept as a plain named range (ContextTypes) so validation references it cleanly.
# Users can add, remove, or edit values freely; no sheet protection applied.

addWorksheet(wb, "Lookups", tabColour = "#E67E22")
setColWidths(wb, "Lookups", cols = 1:3, widths = c(28, 62, 54))

writeData(wb, "Lookups", "Setting Types", startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "Lookups", hdr_style, rows = 1, cols = 1)

default_types <- c("School", "Household", "Healthcare", "Community",
                   "Workplace", "Childcare", "Place of worship", "Transport")
writeData(wb, "Lookups", default_types, startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, "Lookups", note_style, rows = 2:(1 + length(default_types)), cols = 1)

# Ethnicity list (column C) — ONS 2021 census 18+1 categories. Referenced by the
# ethnicity dropdown on the cases sheet. Editable like Setting Types.
ons_ethnicity <- c(
  "White: English, Welsh, Scottish, Northern Irish or British",
  "White: Irish",
  "White: Gypsy or Irish Traveller",
  "White: Roma",
  "White: Other White",
  "Mixed: White and Black Caribbean",
  "Mixed: White and Black African",
  "Mixed: White and Asian",
  "Mixed: Other Mixed",
  "Asian: Indian",
  "Asian: Pakistani",
  "Asian: Bangladeshi",
  "Asian: Chinese",
  "Asian: Other Asian",
  "Black: African",
  "Black: Caribbean",
  "Black: Other Black",
  "Other: Arab",
  "Other: Any other ethnic group"
)
writeData(wb, "Lookups", "Ethnicity", startRow = 1, startCol = 3, colNames = FALSE)
addStyle(wb, "Lookups", hdr_style, rows = 1, cols = 3)
writeData(wb, "Lookups", ons_ethnicity, startRow = 2, startCol = 3, colNames = FALSE)
addStyle(wb, "Lookups", note_style, rows = 2:(1 + length(ons_ethnicity)), cols = 3)

# Instructions in column B
writeData(wb, "Lookups", "About this tab", startRow = 1, startCol = 2, colNames = FALSE)
addStyle(wb, "Lookups", hdr_style, rows = 1, cols = 2)

lookup_instructions <- c(
  "This tab holds reference lists used by dropdown menus in the workbook.",
  "It is not protected — edit it freely to suit your outbreak.",
  "",
  "Setting Types (column A)",
  "  The list of valid values for the context_type field on the contexts sheet.",
  "  • Add new types by typing in the next empty cell below the last entry.",
  "  • Remove a type by deleting the cell content.",
  "  • Leave no blank rows between entries — the dropdown reads up to the first gap.",
  "  • The context_type dropdown on the contexts sheet updates automatically.",
  "",
  "Ethnicity (column C)",
  "  The list of valid values for the ethnicity field on the cases sheet.",
  "  ONS 2021 census categories. Edit the same way as Setting Types.",
  "  • Leave no blank rows between entries — the dropdown reads up to the first gap.",
  "",
  "Do not rename or delete the 'Setting Types' (A1) or 'Ethnicity' (C1) headers."
)
writeData(wb, "Lookups", lookup_instructions, startRow = 2, startCol = 2, colNames = FALSE)
addStyle(wb, "Lookups", note_style,
         rows = 2:(1 + length(lookup_instructions)), cols = 2)


# ---- Dummy data (fictional 20-case measles outbreak) ------------------------
# Respects relational rules: case_id / context_id are formula columns — left
# blank here and overwritten by writeFormula after each sheet is created.
# visit_dates are generated programmatically from onset dates and epi windows.

onset_dates <- as.Date(c(
  "2026-03-05","2026-03-12","2026-03-14","2026-03-15","2026-03-18",
  "2026-03-19","2026-03-21","2026-03-23","2026-03-25","2026-03-26",
  "2026-03-28","2026-03-30","2026-04-01","2026-04-03","2026-04-04",
  "2026-04-07","2026-04-08","2026-04-10","2026-04-12","2026-04-15"
))

cases_d <- data.frame(
  case_id            = rep("", 20),
  CIMS_id            = paste0("CIMS-", formatC(1:20, width = 4, flag = "0")),
  forename           = c("Sophie","Liam","Emma","Noah","Olivia","Jack","Amelia",
                         "Harry","Isla","George","Poppy","Charlie","Grace","Oscar",
                         "Freya","Alfie","Millie","Ethan","Chloe","William"),
  surname            = c("Barker","Patel","Johnson","Williams","Ahmed","Thompson",
                         "Davies","Evans","Wilson","Clarke","Roberts","Walker",
                         "Wright","Hill","Green","Scott","Baker","Mitchell",
                         "Turner","Collins"),
  date_of_birth      = as.Date(c(
    "2017-06-15","2017-03-22","2019-08-10","2016-11-05","1985-04-20",
    "2021-02-14","2021-09-30","1978-07-08","2017-05-17","1985-03-11",
    "1990-08-25","2011-12-01","2018-04-03","2016-07-19","2022-01-10",
    "2016-09-28","2021-11-22","1980-05-13","1992-10-07","2015-02-28"
  )),
  age                = rep("", 20),
  age_group          = rep("", 20),
  gender             = c("Female","Male","Female","Male","Female","Male","Female",
                         "Male","Female","Male","Female","Male","Female","Male",
                         "Female","Male","Female","Male","Female","Male"),
  postcode           = c("SW1A 1AA","E1 6RF","SW1A 1AA","W1A 0AX","SE1 7PB",
                         "EC1A 1BB","WC2N 5DU","NW1 4NP","SW1A 1AA","E1 6RF",
                         "N7 8DG","SE5 0HW","SW1A 1AA","W1A 0AX","EC1A 1BB",
                         "WC2N 5DU","NW1 4NP","SW3 4SX","E14 5AB","N7 8DG"),
  case_status        = c("Confirmed","Confirmed","Confirmed","Confirmed","Confirmed",
                         "Confirmed","Probable","Confirmed","Confirmed","Confirmed",
                         "Probable","Confirmed","Confirmed","Probable","Confirmed",
                         "Probable","Confirmed","Possible","Confirmed","Probable"),
  onset_date         = onset_dates,
  vaccination_status = c("Unvaccinated","Unvaccinated","Unvaccinated","1 dose",
                         "Unvaccinated","Unvaccinated","Unvaccinated","Unvaccinated",
                         "1 dose","2 doses","Unvaccinated","Unvaccinated","1 dose",
                         "Unvaccinated","Unvaccinated","1 dose","Unvaccinated",
                         "Unvaccinated","Unvaccinated","1 dose"),
  likely_index_case  = c("","C-001","C-001","C-001","C-002",
                         "C-001","C-005","C-001","C-001","C-002",
                         "C-005","C-005","C-009","C-004","C-006",
                         "C-012","C-009","C-008","C-011","C-007"),
  contexts           = rep("", 20),
  stringsAsFactors   = FALSE
)

# Additional linelist fields (external collection — not read by the network tool,
# except primary_context_type which is stored-only for now). Derived from the
# existing case attributes where sensible so the demo stays internally consistent.
cases_d$ethnicity       <- ons_ethnicity[c(1,10,5,1,11,15,2,1,8,1,18,12,1,16,7,13,1,5,10,1)]
cases_d$utla            <- c("Westminster","Tower Hamlets","Westminster","Camden",
                             "Southwark","Islington","Camden","Camden","Westminster",
                             "Tower Hamlets","Islington","Southwark","Westminster",
                             "Camden","Islington","Camden","Camden",
                             "Kensington and Chelsea","Tower Hamlets","Islington")
cases_d$report_date     <- onset_dates + 5
cases_d$date_of_rash    <- onset_dates + 3
cases_d$exposure_window   <- rep("", 20)   # formula column
cases_d$infectious_period <- rep("", 20)   # formula column
cases_d$genotype        <- rep(c("B3", "D8"), length.out = 20)
cases_d$confirmation_test_result <- ifelse(
  cases_d$case_status == "Confirmed", "Saliva IgM positive",
  ifelse(cases_d$case_status == "Probable", "Not tested", "Pending"))
cases_d$vaccination_confirmation_method <- ifelse(
  cases_d$vaccination_status == "Unknown", "Unknown",
  ifelse(cases_d$vaccination_status == "Unvaccinated", "Parent/guardian", "GP"))
cases_d$vaccination_notes <- rep("", 20)
cases_d$travel_history  <- rep("No", 20)
cases_d$travel_history[c(5, 12, 18)] <- "Yes"
cases_d$travel_history_details <- rep("", 20)
cases_d$travel_history_details[c(5, 12, 18)] <- c(
  "Recent travel to Romania", "Recent travel to Italy",
  "Visited France 10 days before onset")
cases_d$probable_epi_link <- ifelse(cases_d$likely_index_case == "", "Unknown", "Yes")
cases_d$total_contacts    <- c(24,18,31,12,40,8,15,22,19,27,11,33,16,20,9,14,28,7,21,17)
cases_d$vulnerable_contacts <- c(2,1,3,0,5,1,0,2,1,3,0,4,1,2,0,1,3,0,2,1)
cases_d$primary_context_type <- rep("", 20)   # filled below from case_contexts
cases_d$status          <- c(rep("Closed", 15), rep("Open", 5))
cases_d$date_closed     <- onset_dates + 21
cases_d$date_closed[cases_d$status == "Open"] <- as.Date(NA)

contexts_d <- data.frame(
  context_id   = rep("", 15),
  context_name = c(
    "Oakfield Primary School",    "Sunnydale Day Nursery",
    "14 Elm Street",              "7 Birchwood Close",
    "22 Maple Avenue",            "9 Riverside Drive",
    "31 Oak Lane",                "Westside Community Centre",
    "St Peters Church",           "City General Hospital",
    "Northside GP Surgery",       "Greentech Solutions",
    "Town Market",                "Metro Bus Station",
    "Broadfield Secondary School"
  ),
  context_type = c(
    "School","Childcare",
    "Household","Household","Household","Household","Household",
    "Community","Place of worship","Healthcare","Healthcare",
    "Workplace","Community","Transport","School"
  ),
  stringsAsFactors = FALSE
)

case_contexts_d <- data.frame(
  case_id = c(
    "C-001","C-001",
    "C-002","C-002",
    "C-003","C-003",
    "C-004","C-004",
    "C-005","C-005",
    "C-006","C-006",
    "C-007","C-007","C-007",
    "C-008","C-008",
    "C-009","C-009",
    "C-010",
    "C-011","C-011",
    "C-012","C-012",
    "C-013","C-013","C-013",
    "C-014","C-014",
    "C-015","C-015",
    "C-016","C-016","C-016",
    "C-017",
    "C-018",
    "C-019","C-019",
    "C-020","C-020"
  ),
  context_id = c(
    "Ctxt-001","Ctxt-003",
    "Ctxt-001","Ctxt-004",
    "Ctxt-003","Ctxt-011",
    "Ctxt-001","Ctxt-005",
    "Ctxt-008","Ctxt-009",
    "Ctxt-002","Ctxt-006",
    "Ctxt-002","Ctxt-007","Ctxt-013",
    "Ctxt-001","Ctxt-010",
    "Ctxt-001","Ctxt-009",
    "Ctxt-004",
    "Ctxt-008","Ctxt-012",
    "Ctxt-009","Ctxt-015",
    "Ctxt-001","Ctxt-009","Ctxt-014",
    "Ctxt-005","Ctxt-014",
    "Ctxt-002","Ctxt-006",
    "Ctxt-008","Ctxt-013","Ctxt-015",
    "Ctxt-002",
    "Ctxt-010",
    "Ctxt-011","Ctxt-012",
    "Ctxt-007","Ctxt-015"
  ),
  exposure_relevance = c(
    "Infectious period","Both",
    "Exposure window","Both",
    "Exposure window","Neither",
    "Exposure window","Both",
    "Exposure window","Infectious period",
    "Exposure window","Both",
    "Exposure window","Both","Infectious period",
    "Exposure window","Infectious period",
    "Exposure window","Infectious period",
    "Exposure window",
    "Exposure window","Both",
    "Exposure window","Infectious period",
    "Exposure window","Exposure window","Infectious period",
    "Exposure window","Exposure window",
    "Exposure window","Exposure window",
    "Exposure window","Both","Infectious period",
    "Exposure window",
    "Exposure window",
    "Exposure window","Exposure window",
    "Exposure window","Infectious period"
  ),
  stringsAsFactors = FALSE
)

# Generate visit_dates from epi windows (measles defaults: inc 7-21d, inf -4 to +4d)
onset_lookup <- setNames(onset_dates, paste0("C-", formatC(1:20, width = 3, flag = "0")))

weekday_seq <- function(start, end) {
  if (end < start) return(as.Date(character(0)))
  d <- seq(start, end, by = "day")
  d[!weekdays(d) %in% c("Saturday", "Sunday")]
}

visit_list <- lapply(seq_len(nrow(case_contexts_d)), function(i) {
  onset <- onset_lookup[[case_contexts_d$case_id[i]]]
  exp   <- weekday_seq(onset - 21, onset - 7)
  inf   <- weekday_seq(onset - 4,  onset + 4)
  dates <- switch(case_contexts_d$exposure_relevance[i],
    "Exposure window"   = { if (length(exp) > 4) tail(exp, 4) else exp },
    "Infectious period" = { if (length(inf) > 4) head(inf, 4) else inf },
    "Both"              = c(tail(exp, 3), head(inf, 3)),
    as.Date(character(0))
  )
  if (length(dates) == 0) return(NULL)
  data.frame(case_id    = case_contexts_d$case_id[i],
             context_id = case_contexts_d$context_id[i],
             visit_date = sort(dates),
             stringsAsFactors = FALSE)
})
visit_dates_d <- do.call(rbind, Filter(Negate(is.null), visit_list))
rownames(visit_dates_d) <- NULL

# primary_context_type: the context type of each case's first linked context.
# Derived here only to give the demo plausible values; the app stores it but
# does not yet use it.
demo_ids <- paste0("C-", formatC(1:20, width = 3, flag = "0"))
cases_d$primary_context_type <- vapply(demo_ids, function(cid) {
  ctx <- case_contexts_d$context_id[case_contexts_d$case_id == cid]
  if (length(ctx) == 0) return("")
  n <- as.integer(sub("Ctxt-", "", ctx[1]))
  contexts_d$context_type[n]
}, character(1), USE.NAMES = FALSE)

# Final cases column order — logical linelist flow (see docs/amendments.md).
cases_col_order <- c(
  "case_id", "CIMS_id", "forename", "surname", "date_of_birth", "age",
  "age_group", "gender", "ethnicity", "postcode", "utla", "report_date",
  "onset_date", "date_of_rash", "exposure_window", "infectious_period",
  "case_status", "genotype", "confirmation_test_result", "vaccination_status",
  "vaccination_confirmation_method", "vaccination_notes", "travel_history",
  "travel_history_details", "likely_index_case", "probable_epi_link",
  "total_contacts", "vulnerable_contacts", "primary_context_type", "contexts",
  "status", "date_closed")
cases_d <- cases_d[, cases_col_order]


# ---- cases ------------------------------------------------------------------
# 32-column linelist in logical case-management order. Header colour marks
# whether the network tool reads the column (maroon) or it is external
# collection only (blue). Column letters below drive the formulas.
#   A  case_id                 — MAROON, auto-formula (C-001…), locked
#   B  CIMS_id                 — manual; amber highlight on duplicate
#   C  forename                — free text
#   D  surname                 — free text
#   E  date_of_birth           — date; drives age
#   F  age                     — formula DATEDIF(DOB, onset_date), locked
#   G  age_group               — MAROON, formula (UKHSA bands), locked
#   H  gender                  — MAROON, dropdown
#   I  ethnicity               — dropdown (ONS list, Lookups col C)
#   J  postcode                — free text
#   K  utla                    — free text
#   L  report_date             — date
#   M  onset_date              — MAROON, date; drives age and epi windows
#   N  date_of_rash            — date
#   O  exposure_window         — formula range from onset (−21 to −7), locked
#   P  infectious_period       — formula range from onset (−4 to +4), locked
#   Q  case_status             — MAROON, dropdown (shown as "Case confidence")
#   R  genotype                — free text
#   S  confirmation_test_result — dropdown
#   T  vaccination_status      — MAROON, dropdown
#   U  vaccination_confirmation_method — dropdown
#   V  vaccination_notes       — free text
#   W  travel_history          — dropdown (Yes/No/Unknown)
#   X  travel_history_details  — free text
#   Y  likely_index_case       — MAROON, dropdown: any case_id in this table
#   Z  probable_epi_link       — dropdown (Yes/No/Unknown)
#   AA total_contacts          — whole number
#   AB vulnerable_contacts     — whole number
#   AC primary_context_type    — MAROON, dropdown (Lookups context types); stored, not yet used
#   AD contexts                — formula: semi-colon list of linked context names, locked
#   AE status                  — dropdown (Open/Closed)
#   AF date_closed             — date

add_sheet(
  wb, "cases",
  headers     = names(cases_d),
  example     = as.list(cases_d[1, ]),
  col_widths  = c(10, 14, 14, 14, 16, 8, 14, 12, 42, 12, 18, 14, 14, 14, 26, 26,
                  14, 12, 22, 18, 26, 20, 14, 28, 16, 16, 14, 18, 20, 40, 10, 14),
  nrows       = 1000,
  has_example = FALSE,
  date_cols   = c(5, 12, 13, 14, 32),
  dropdowns   = list(
    list(col = 8,  formula = '"Male,Female,Other,Unknown"'),
    list(col = 9,  formula = "OFFSET(Lookups!$C$2,0,0,COUNTA(Lookups!$C$2:$C$100),1)"),
    list(col = 17, formula = '"Confirmed,Probable,Possible"'),
    list(col = 19, formula = '"Saliva IgM positive,Saliva IgM negative,Serum IgM positive,Serum IgM negative,PCR positive,PCR negative,Not tested,Pending"'),
    list(col = 20, formula = '"Unvaccinated,1 dose,2 doses,Unknown"'),
    list(col = 21, formula = '"CHIS,GP,Occupational Health,Parent/guardian,Other,Unknown"'),
    list(col = 23, formula = '"Yes,No,Unknown"'),
    list(col = 25, formula = "cases!$A$2:$A$1001"),
    list(col = 26, formula = '"Yes,No,Unknown"'),
    list(col = 29, formula = "OFFSET(Lookups!$A$2,0,0,COUNTA(Lookups!$A$2:$A$100),1)"),
    list(col = 31, formula = '"Open,Closed"')
  ),
  validations = list(
    list(col = 5,  type = "date", operator = "between",
         value = as.Date(c("1900-01-01", "2100-01-01"))),
    list(col = 12, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01"))),
    list(col = 13, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01"))),
    list(col = 14, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01"))),
    list(col = 32, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01"))),
    list(col = 27, type = "whole", operator = "greaterThanOrEqual", value = 0),
    list(col = 28, type = "whole", operator = "greaterThanOrEqual", value = 0)
  )
)
# Write remaining 19 cases (row 2 already written via example above)
writeData(wb, "cases", cases_d[-1, ], startRow = 3, startCol = 1, colNames = FALSE)

# Maroon headers — columns the network tool reads
addStyle(wb, "cases", maroon_hdr_style,
         rows = 1, cols = c(1, 7, 8, 13, 17, 20, 25, 29),
         gridExpand = TRUE, stack = TRUE)

# case_id (A): row-position formula, fires regardless of other columns
writeFormula(wb, "cases",
             rep('"C-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)

# age (F): whole years between date_of_birth (E) and onset_date (M)
age_formulas <- paste0(
  'IF(AND(E', 2:1001, '<>"",M', 2:1001, '<>""),',
  'IFERROR(DATEDIF(E', 2:1001, ',M', 2:1001, ',"Y"),"err"),"")'
)
writeFormula(wb, "cases", age_formulas, startRow = 2, startCol = 6)

# age_group (G): UKHSA reporting bands derived from age (F)
# Bands: <1 year | 1-4 | 5-17 | 18-29 | 30-49 | 50+
age_group_formulas <- paste0(
  'IF(F', 2:1001, '="","",IF(F', 2:1001, '<1,"<1 year",IF(F', 2:1001,
  '<5,"1–4 years",IF(F', 2:1001, '<18,"5–17 years",IF(F', 2:1001,
  '<30,"18–29 years",IF(F', 2:1001, '<50,"30–49 years","50+ years"))))))'
)
writeFormula(wb, "cases", age_group_formulas, startRow = 2, startCol = 7)

# exposure_window (O): date range from onset_date (M) — inc period 21 to 7 days
# before onset. Text so it reads as a range; uses the fixed measles defaults.
exp_formulas <- paste0(
  'IF(M', 2:1001, '="","",TEXT(M', 2:1001, '-21,"DD/MM/YYYY")&" – "&TEXT(M',
  2:1001, '-7,"DD/MM/YYYY"))'
)
writeFormula(wb, "cases", exp_formulas, startRow = 2, startCol = 15)

# infectious_period (P): date range from onset_date (M) — 4 days before to 4
# days after onset (fixed measles defaults).
inf_formulas <- paste0(
  'IF(M', 2:1001, '="","",TEXT(M', 2:1001, '-4,"DD/MM/YYYY")&" – "&TEXT(M',
  2:1001, '+4,"DD/MM/YYYY"))'
)
writeFormula(wb, "cases", inf_formulas, startRow = 2, startCol = 16)

# contexts (col AD): NOT pre-populated — openxlsx cannot reliably write complex
# cross-sheet formulas to OOXML. Column is styled and locked ready to receive
# the formula. Instructions and the formula text are in the README tab.
# The user pastes the formula into AD2 and copies down once after setup.

# Locked (blue): auto-generated / formula columns — never edited
# case_id (1), age (6), age_group (7), exposure_window (15), infectious_period (16), contexts (30)
addStyle(wb, "cases", locked_style,
         rows = 2:1001, cols = c(1, 6, 7, 15, 16, 30), gridExpand = TRUE, stack = TRUE)

# Unlocked: all editable columns
addStyle(wb, "cases", unlocked_style,
         rows = 2:1001,
         cols = c(2:5, 8:14, 17:29, 31, 32), gridExpand = TRUE, stack = TRUE)

# Amber highlight on CIMS_id (col B) if the value appears more than once
conditionalFormatting(wb, "cases",
                      cols  = 2,
                      rows  = 2:1001,
                      type  = "expression",
                      rule  = "COUNTIF($B$2:$B$1001,B2)>1",
                      style = dup_style)

# Red highlight on likely_index_case (col Y) if it matches the case's own case_id.
# LEN()>0 used instead of <>"" because openxlsx may not XML-escape <> in CF rules.
conditionalFormatting(wb, "cases",
                      cols  = 25,
                      rows  = 2:1001,
                      type  = "expression",
                      rule  = "AND(LEN($Y2)>0,$Y2=$A2)",
                      style = self_ref_style)

protectWorksheet(wb, "cases", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)


# ---- contexts ---------------------------------------------------------------
# context_id (col 1) auto-generated. context_type validated against ContextTypes
# named range in the Lookups tab.

add_sheet(
  wb, "contexts",
  headers     = c("context_id", "context_name", "context_type"),
  example     = list("", contexts_d$context_name[1], contexts_d$context_type[1]),
  col_widths  = c(12, 35, 20),
  nrows       = 1000,
  has_example = FALSE,
  dropdowns   = list(
    list(col = 3, formula = "OFFSET(Lookups!$A$2,0,0,COUNTA(Lookups!$A$2:$A$100),1)")
  )
)
writeData(wb, "contexts", contexts_d[-1, ], startRow = 3, startCol = 1, colNames = FALSE)

writeFormula(wb, "contexts",
             rep('"Ctxt-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)
addStyle(wb, "contexts", locked_style,
         rows = 2:1001, cols = 1, gridExpand = TRUE, stack = TRUE)
addStyle(wb, "contexts", unlocked_style,
         rows = 2:1001, cols = 2:3, gridExpand = TRUE, stack = TRUE)
protectWorksheet(wb, "contexts", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)


# ---- case_contexts ----------------------------------------------------------
# exposure_relevance: practitioner judgement on each case-context link —
# Infectious period, Exposure window, Both, or Neither.
# Replaces the previously derived visit_relevance; the app reads this directly.

add_sheet(
  wb, "case_contexts",
  headers     = c("case_id", "context_id", "exposure_relevance"),
  example     = as.list(case_contexts_d[1, ]),
  col_widths  = c(12, 14, 20),
  has_example = FALSE,
  dropdowns   = list(
    list(col = 1, formula = "cases!$A$2:$A$1001"),
    list(col = 2, formula = "contexts!$A$2:$A$1001"),
    list(col = 3, formula = '"Infectious period,Exposure window,Both,Neither"')
  )
)
writeData(wb, "case_contexts", case_contexts_d[-1, ], startRow = 3, startCol = 1, colNames = FALSE)


# ---- visit_dates ------------------------------------------------------------

add_sheet(
  wb, "visit_dates",
  headers     = c("case_id", "context_id", "visit_date"),
  example     = list(visit_dates_d$case_id[1], visit_dates_d$context_id[1],
                     visit_dates_d$visit_date[1]),
  col_widths  = c(12, 14, 15),
  has_example = FALSE,
  date_cols   = 3,
  dropdowns   = list(
    list(col = 1, formula = "cases!$A$2:$A$1001"),
    list(col = 2, formula = "contexts!$A$2:$A$1001")
  ),
  validations = list(
    list(col = 3, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)
writeData(wb, "visit_dates", visit_dates_d[-1, ], startRow = 3, startCol = 1, colNames = FALSE)



# ---- Named ranges -----------------------------------------------------------
# All main tables are already named Excel Tables (accessible as cases[col], etc.).
# These additional named regions register the data extents in the Name Manager
# for reference in formulas outside the tables.
# ContextTypes is the key operational named range — used by the contexts
# sheet to validate context_type entries against the Lookups tab.

createNamedRegion(wb, sheet = "cases",         rows = 1:1001, cols = 1:32, name = "CasesRange")
createNamedRegion(wb, sheet = "contexts",      rows = 1:1001, cols = 1:3,  name = "ContextsRange")
createNamedRegion(wb, sheet = "case_contexts", rows = 1:2001, cols = 1:3,  name = "CaseContextsRange")
createNamedRegion(wb, sheet = "visit_dates",   rows = 1:2001, cols = 1:3,  name = "VisitDatesRange")
createNamedRegion(wb, sheet = "Lookups",       rows = 2:100,  cols = 1,    name = "ContextTypes")


# ---- Save -------------------------------------------------------------------

saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
message("Template saved to: ", normalizePath(OUT_PATH))
