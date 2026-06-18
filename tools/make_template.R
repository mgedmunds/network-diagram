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

example_style <- createStyle(
  fontColour     = "#999999",
  fgFill         = "#F5F5F5",
  textDecoration = "italic"
)

date_style     <- createStyle(numFmt = "DD/MM/YYYY")

# Light blue = auto-generated/formula field, locked (read-only)
locked_style   <- createStyle(fgFill = "#E8F0FE", locked = TRUE)
unlocked_style <- createStyle(locked = FALSE)

note_style <- createStyle(
  fontColour = "#2C3E50",
  fontSize   = 11
)

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

# Amber highlight for duplicate CIMS_id values
dup_style <- createStyle(
  bgFill      = "#FFD700",
  fontColour  = "#000000"
)

# Yellow background for user input cells in the Date Helper tab
input_style <- createStyle(
  fgFill        = "#FFF9C4",
  border        = "Bottom",
  borderColour  = "#CCCCCC"
)

# Green header for output section of Date Helper
output_hdr_style <- createStyle(
  fontColour     = "#FFFFFF",
  fgFill         = "#27AE60",
  textDecoration = "bold",
  border         = "Bottom",
  borderColour   = "#1E8449"
)

# Grey text/background for weekend rows in Date Helper
weekend_style <- createStyle(
  bgFill     = "#E8E8E8",
  fontColour = "#999999"
)


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
                      validations = list()) {
  addWorksheet(wb, name, tabColour = "#2980B9")

  eg_df <- as.data.frame(example, stringsAsFactors = FALSE)
  names(eg_df) <- headers
  writeDataTable(wb, name, eg_df,
                 startRow    = 1,
                 startCol    = 1,
                 tableName   = name,
                 tableStyle  = "TableStyleLight1",
                 headerStyle = hdr_style,
                 withFilter  = TRUE,
                 bandedRows  = FALSE)

  addStyle(wb, name, example_style,
           rows = 2, cols = seq_along(headers), gridExpand = TRUE, stack = TRUE)

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
  list(style = note_style,    text = "1.  Fill in the 'cases' sheet first — one row per case."),
  list(style = note_style,    text = "2.  Fill in the 'contexts' sheet — one row per location linked to the outbreak."),
  list(style = note_style,    text = "3.  Fill in 'case_contexts' — one row per case x context combination."),
  list(style = note_style,    text = "4.  Fill in 'visit_dates' — one row per date a case visited a context."),
  list(style = note_style,    text = "    Use the 'Date Helper' tab to generate blocks of dates efficiently (see below)."),
  list(style = note_style,    text = "5.  Fill in 'contacts' (optional) — one row per known transmission link."),
  list(style = note_style,    text = "6.  Delete the example rows (shaded grey, italic) before uploading."),
  list(style = note_style,    text = "7.  Save as .xlsx and upload using the Upload button in the network tool."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "RULES"),
  list(style = note_style,    text = "•  case_id and context_id are AUTO-GENERATED — do not type in these columns."),
  list(style = note_style,    text = "   case_id is always C-001, C-002 … based on row position (locked, blue shading)."),
  list(style = note_style,    text = "   context_id is always Ctxt-001, Ctxt-002 … based on row position (locked, blue shading)."),
  list(style = note_style,    text = "•  age is AUTO-CALCULATED from date_of_birth and onset_date — do not type in this column (locked, blue shading)."),
  list(style = note_style,    text = "•  CIMS_id: if a cell turns amber/yellow, a duplicate CIMS_id has been entered — check and correct before uploading."),
  list(style = note_style,    text = "•  Do not delete rows — IDs are based on row position and will renumber if rows are removed."),
  list(style = note_style,    text = "•  Dates must be entered as Excel dates in DD/MM/YYYY format — not as plain text."),
  list(style = note_style,    text = "   Click on a date cell and use the date picker, or type the date and confirm it shows as a date (not text)."),
  list(style = note_style,    text = "•  Do not rename or reorder the sheet tabs."),
  list(style = note_style,    text = "•  Do not rename or reorder the column headers."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "VALIDATION — what the cells will check as you type"),
  list(style = note_style,    text = "•  date_of_birth, onset_date, visit_date: must be a valid date (DD/MM/YYYY). Text will be rejected."),
  list(style = note_style,    text = "•  CIMS_id: turns amber if the same value appears more than once in the column."),
  list(style = note_style,    text = "•  case_id in 'case_contexts', 'visit_dates', 'contacts': dropdown shows only IDs from the 'cases' sheet."),
  list(style = note_style,    text = "•  context_id in 'case_contexts', 'visit_dates': dropdown shows only IDs from the 'contexts' sheet."),
  list(style = note_style,    text = "   Fill 'cases' and 'contexts' first — their IDs will then appear in the dropdowns."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DROPDOWN FIELDS — select from the list; do not type free text"),
  list(style = note_style,    text = "•  gender:             Male | Female | Other | Unknown"),
  list(style = note_style,    text = "•  case_status:        Confirmed | Probable | Possible"),
  list(style = note_style,    text = "•  vaccination_status: Unvaccinated | 1 dose | 2 doses | Unknown"),
  list(style = note_style,    text = "•  link_type:          Probable | Possible"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DATE HELPER TAB — efficient bulk visit date entry"),
  list(style = note_style,    text = "•  Use the 'Date Helper' tab to generate a block of visit dates for one case x context at a time."),
  list(style = note_style,    text = "•  Select the case, context, start date, and end date from the yellow input cells."),
  list(style = note_style,    text = "•  Dates are listed automatically. Weekend rows are shaded grey — skip them if not relevant."),
  list(style = note_style,    text = "•  Select the rows with dates (columns A–C), copy, then paste into the visit_dates sheet."),
  list(style = note_style,    text = "•  Repeat for each case x context pair."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTEXT TYPE"),
  list(style = note_style,    text = "•  context_type is free text — you define the categories for this outbreak."),
  list(style = note_style,    text = "•  Use consistent capitalisation across all rows (e.g. always 'School', not 'school')."),
  list(style = note_style,    text = "•  Suggested values: School, Household, Healthcare, Community, Workplace, Childcare."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTACTS SHEET"),
  list(style = note_style,    text = "•  Optional. Leave blank if transmission links are not known."),
  list(style = note_style,    text = "•  'from' is the source case; 'to' is the case who was infected."),
  list(style = note_style,    text = "•  The app can derive Possible links automatically from shared contexts and timing.")
)

for (i in seq_along(readme_rows)) {
  writeData(wb, "README", readme_rows[[i]]$text, startRow = i, colNames = FALSE)
  addStyle(wb, "README", readme_rows[[i]]$style, rows = i, cols = 1)
}


# ---- cases ------------------------------------------------------------------
# Columns:
#   A  case_id          — auto-generated formula (C-001, C-002 ...), locked
#   B  CIMS_id          — manual entry; amber highlight on duplicate
#   C  forename         — free text
#   D  surname          — free text
#   E  date_of_birth    — date; drives age calculation
#   F  onset_date       — date; drives age calculation and epi-window logic
#   G  age              — formula: DATEDIF(DOB, onset_date, "Y"), locked
#   H  gender           — dropdown
#   I  postcode         — free text
#   J  case_status      — dropdown
#   K  vaccination_status — dropdown

add_sheet(
  wb, "cases",
  headers    = c("case_id", "CIMS_id", "forename", "surname",
                 "date_of_birth", "onset_date", "age",
                 "gender", "postcode", "case_status", "vaccination_status"),
  example    = list("", "CIMS-123", "Jane", "Smith",
                    as.Date("1995-03-15"), as.Date("2026-04-01"), "",
                    "Female", "SW1A 1AA", "Confirmed", "Unvaccinated"),
  col_widths = c(10, 14, 14, 14, 16, 16, 8, 12, 14, 14, 20),
  date_cols  = c(5, 6),
  dropdowns  = list(
    list(col = 8,  formula = '"Male,Female,Other,Unknown"'),
    list(col = 10, formula = '"Confirmed,Probable,Possible"'),
    list(col = 11, formula = '"Unvaccinated,1 dose,2 doses,Unknown"')
  ),
  validations = list(
    list(col = 5, type = "date", operator = "between",
         value = as.Date(c("1900-01-01", "2100-01-01"))),
    list(col = 6, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)

# case_id: row-position formula, always present regardless of other fields
writeFormula(wb, "cases",
             rep('"C-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)

# age: years between DOB and onset_date; IFERROR guards against inverted dates
age_formulas <- paste0(
  'IF(AND(E', 2:1001, '<>"",F', 2:1001, '<>""),',
  'IFERROR(DATEDIF(E', 2:1001, ',F', 2:1001, ',"Y"),"err"),"")'
)
writeFormula(wb, "cases", age_formulas, startRow = 2, startCol = 7)

# Locked (blue shading): case_id (col 1) and age (col 7) — formula-driven
addStyle(wb, "cases", locked_style,
         rows = 2:1001, cols = c(1, 7), gridExpand = TRUE, stack = TRUE)

# Unlocked: all other data columns
addStyle(wb, "cases", unlocked_style,
         rows = 2:1001, cols = c(2:6, 8:11), gridExpand = TRUE, stack = TRUE)

# Duplicate detection: CIMS_id (col 2) turns amber if the same value appears more than once
conditionalFormatting(wb, "cases",
                      cols  = 2,
                      rows  = 2:1001,
                      type  = "expression",
                      rule  = "COUNTIF($B$2:$B$1001,B2)>1",
                      style = dup_style)

protectWorksheet(wb, "cases", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)


# ---- contexts ---------------------------------------------------------------
# context_id (col 1) is auto-generated: Ctxt-001, Ctxt-002 ... based on row position.

add_sheet(
  wb, "contexts",
  headers    = c("context_id", "context_name", "context_type"),
  example    = list("", "Oakfield Primary School", "School"),
  col_widths = c(12, 35, 16)
)

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
# case_id and context_id dropdowns pull from their respective sheets.
# Only valid IDs (those already entered) appear in the dropdown.

add_sheet(
  wb, "case_contexts",
  headers    = c("case_id", "context_id"),
  example    = list("C-001", "Ctxt-001"),
  col_widths = c(12, 14),
  dropdowns  = list(
    list(col = 1, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 2, formula = "OFFSET(contexts!$A$2,0,0,COUNTA(contexts!$B$2:$B$1001),1)")
  )
)


# ---- visit_dates ------------------------------------------------------------
# One row per calendar date a case visited a context.
# Use the Date Helper tab to generate blocks of dates efficiently.

add_sheet(
  wb, "visit_dates",
  headers    = c("case_id", "context_id", "visit_date"),
  example    = list("C-001", "Ctxt-001", as.Date("2026-04-03")),
  col_widths = c(12, 14, 15),
  date_cols  = 3,
  dropdowns  = list(
    list(col = 1, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 2, formula = "OFFSET(contexts!$A$2,0,0,COUNTA(contexts!$B$2:$B$1001),1)")
  ),
  validations = list(
    list(col = 3, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)


# ---- contacts ---------------------------------------------------------------
# Optional. One row per recorded transmission link.
# from = source case; to = recipient case; link_type = Probable or Possible.

add_sheet(
  wb, "contacts",
  headers    = c("from", "to", "link_type"),
  example    = list("C-001", "C-002", "Possible"),
  col_widths = c(12, 12, 14),
  dropdowns  = list(
    list(col = 1, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 2, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 3, formula = '"Probable,Possible"')
  )
)


# ---- Date Helper ------------------------------------------------------------
# Generates a consecutive list of dates for a chosen case x context pair.
# User fills 4 yellow input cells; dates auto-populate below (up to 60 days).
# Weekend rows are shaded grey — skip these if weekend visits are not relevant.
# Select columns A–C from the date rows and paste into the visit_dates sheet.

addWorksheet(wb, "Date Helper", tabColour = "#27AE60")
setColWidths(wb, "Date Helper", cols = 1:4, widths = c(14, 18, 15, 8))
freezePane(wb, "Date Helper", firstRow = TRUE)

# Title and instructions
writeData(wb, "Date Helper", "VISIT DATE HELPER",
          startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "Date Helper", title_style, rows = 1, cols = 1)

writeData(wb, "Date Helper",
          "Use this tab to generate visit dates for one case x context at a time.",
          startRow = 2, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper",
          "Fill in the four yellow cells below. Dates generate automatically. Weekend rows are shaded grey.",
          startRow = 3, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper",
          "When ready: select the date rows (columns A-C), copy, and paste into the visit_dates sheet.",
          startRow = 4, startCol = 1, colNames = FALSE)
addStyle(wb, "Date Helper", note_style, rows = 2:4, cols = 1, gridExpand = TRUE)

# Input labels (col A) and input cells (col B)
writeData(wb, "Date Helper", "Case ID",    startRow = 6, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "Context ID", startRow = 7, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "Start date", startRow = 8, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "End date",   startRow = 9, startCol = 1, colNames = FALSE)

label_style <- createStyle(fontColour = "#2C3E50", fontSize = 11, textDecoration = "bold")
addStyle(wb, "Date Helper", label_style, rows = 6:9, cols = 1, gridExpand = TRUE)

# Yellow background on input cells (col B, rows 6-9)
addStyle(wb, "Date Helper", input_style, rows = 6:9, cols = 2, gridExpand = TRUE)

# Date format on start/end date input cells
addStyle(wb, "Date Helper", date_style, rows = 8:9, cols = 2, gridExpand = TRUE, stack = TRUE)

# Dropdowns: case_id and context_id from their respective sheets
dataValidation(wb, "Date Helper", col = 2, rows = 6,
               type  = "list",
               value = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)")
dataValidation(wb, "Date Helper", col = 2, rows = 7,
               type  = "list",
               value = "OFFSET(contexts!$A$2,0,0,COUNTA(contexts!$B$2:$B$1001),1)")

# Date validation on start/end input cells
dataValidation(wb, "Date Helper", col = 2, rows = 8:9,
               type = "date", operator = "between",
               value = as.Date(c("2000-01-01", "2100-01-01")))

# Output section header (row 11)
writeData(wb, "Date Helper",
          "Generated dates — copy columns A to C into the visit_dates sheet:",
          startRow = 11, startCol = 1, colNames = FALSE)
addStyle(wb, "Date Helper", note_style, rows = 11, cols = 1)

# Output column headers (row 12)
writeData(wb, "Date Helper", "case_id",    startRow = 12, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "context_id", startRow = 12, startCol = 2, colNames = FALSE)
writeData(wb, "Date Helper", "visit_date", startRow = 12, startCol = 3, colNames = FALSE)
writeData(wb, "Date Helper", "Day",        startRow = 12, startCol = 4, colNames = FALSE)
addStyle(wb, "Date Helper", output_hdr_style, rows = 12, cols = 1:4, gridExpand = TRUE)

# Output rows 13-72 (60 days max — covers any realistic epi window)

# Col A: repeat the selected case_id for every output row
writeFormula(wb, "Date Helper",
             rep('IF($B$6<>"",$B$6,"")', 60),
             startRow = 13, startCol = 1)

# Col B: repeat the selected context_id for every output row
writeFormula(wb, "Date Helper",
             rep('IF($B$7<>"",$B$7,"")', 60),
             startRow = 13, startCol = 2)

# Col C: date = start_date + offset; blank if beyond end_date or inputs missing
date_formulas <- paste0(
  'IF(OR(ISBLANK($B$8),ISBLANK($B$9)),"",',
  'IF($B$8+', 0:59, '<=$B$9,$B$8+', 0:59, ',""))'
)
writeFormula(wb, "Date Helper", date_formulas, startRow = 13, startCol = 3)

# Col D: day-of-week abbreviation (Mon, Tue, ...) to help identify weekends
day_formulas <- paste0('IF(C', 13:72, '<>"",TEXT(C', 13:72, ',"ddd"),"")')
writeFormula(wb, "Date Helper", day_formulas, startRow = 13, startCol = 4)

# Date format on the visit_date output column
addStyle(wb, "Date Helper", date_style,
         rows = 13:72, cols = 3, gridExpand = TRUE, stack = TRUE)

# Grey shading on weekend rows (Sat/Sun) so staff can easily skip them.
# WEEKDAY(...,2) returns 6 for Saturday, 7 for Sunday (Monday = 1 mode).
conditionalFormatting(wb, "Date Helper",
                      cols  = 1:4,
                      rows  = 13:72,
                      type  = "expression",
                      rule  = "WEEKDAY($C13,2)>5",
                      style = weekend_style)


# ---- Save -------------------------------------------------------------------

saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
message("Template saved to: ", normalizePath(OUT_PATH))
