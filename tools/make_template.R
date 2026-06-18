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
                      validations = list(), nrows = 1) {
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
  list(style = note_style,    text = "    Context types are validated against the 'Lookups' tab — add types there if needed."),
  list(style = note_style,    text = "3.  Fill in 'case_contexts' — one row per case x context combination."),
  list(style = note_style,    text = "    Once filled, the 'contexts' column in the cases sheet will populate automatically."),
  list(style = note_style,    text = "4.  Fill in 'visit_dates' — one row per date a case visited a context."),
  list(style = note_style,    text = "    Use the 'Date Helper' tab to generate blocks of dates efficiently (see below)."),
  list(style = note_style,    text = "5.  Fill in 'contacts' (optional) — one row per known transmission link."),
  list(style = note_style,    text = "6.  Delete the example rows (shaded grey, italic) before uploading."),
  list(style = note_style,    text = "7.  Save as .xlsx and upload using the Upload button in the network tool."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "RULES"),
  list(style = note_style,    text = "•  case_id, context_id, age, and contexts are AUTO-GENERATED — do not type in these columns (locked, blue shading)."),
  list(style = note_style,    text = "   case_id: C-001, C-002 … based on row position."),
  list(style = note_style,    text = "   context_id: Ctxt-001, Ctxt-002 … based on row position."),
  list(style = note_style,    text = "   age: calculated from date_of_birth and onset_date."),
  list(style = note_style,    text = "   contexts: lists all context names linked to the case in the case_contexts sheet (semi-colon separated)."),
  list(style = note_style,    text = "•  CIMS_id: turns amber/yellow if a duplicate is detected — check and correct before uploading."),
  list(style = note_style,    text = "•  Do not delete rows — IDs are based on row position and will renumber if rows are removed."),
  list(style = note_style,    text = "•  Dates must be entered as Excel dates (DD/MM/YYYY) — not plain text."),
  list(style = note_style,    text = "•  Do not rename or reorder sheet tabs or column headers."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTEXTS COLUMN — one-time formula setup (do this once after filling the sheet)"),
  list(style = note_style,    text = "The 'contexts' column (M) in the cases sheet is blank when the template first opens."),
  list(style = note_style,    text = "After filling in cases, contexts, and case_contexts, add the formula:"),
  list(style = note_style,    text = "  1. Click cell N2 in the cases sheet."),
  list(style = note_style,    text = "  2. Type = then copy and paste the formula text below into the formula bar."),
  list(style = note_style,    text = "  3. Press Ctrl+Shift+Enter — NOT plain Enter. The formula bar must show {=...} with curly braces."),
  list(style = note_style,    text = "     If you see plain =... without curly braces, delete and re-enter using Ctrl+Shift+Enter."),
  list(style = note_style,    text = "  4. Copy N2 (Ctrl+C), select N3:N1001, paste (Ctrl+V)."),
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
  list(style = note_style,    text = "•  case_id in 'case_contexts', 'visit_dates', 'contacts': dropdown shows only IDs from the cases sheet."),
  list(style = note_style,    text = "•  context_id in 'case_contexts', 'visit_dates': dropdown shows only IDs from the contexts sheet."),
  list(style = note_style,    text = "   Fill 'cases' and 'contexts' first — their IDs will then appear in the dropdowns."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DROPDOWN FIELDS — select from the list; do not type free text"),
  list(style = note_style,    text = "•  gender:              Male | Female | Other | Unknown"),
  list(style = note_style,    text = "•  case_status:         Confirmed | Probable | Possible"),
  list(style = note_style,    text = "•  vaccination_status:  Unvaccinated | 1 dose | 2 doses | Unknown"),
  list(style = note_style,    text = "•  context_type:        Values from the Lookups tab (editable)"),
  list(style = note_style,    text = "•  likely_index_case:   Any case_id already in the cases sheet (turns red if set to the case's own ID)"),
  list(style = note_style,    text = "•  link_type:           Probable | Possible"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "LOOKUPS TAB — managing context types"),
  list(style = note_style,    text = "•  The 'Lookups' tab contains the Setting Types list used to validate context_type entries."),
  list(style = note_style,    text = "•  To add a type: type it in the next empty row of the Setting Types column."),
  list(style = note_style,    text = "•  To remove a type: delete the cell contents (do not leave blank rows in the middle of the list)."),
  list(style = note_style,    text = "•  To edit a type: overtype the existing value."),
  list(style = note_style,    text = "•  Changes take effect immediately in the context_type dropdown."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DATE HELPER TAB — efficient bulk visit date entry"),
  list(style = note_style,    text = "•  Use the 'Date Helper' tab to generate a block of visit dates for one case x context at a time."),
  list(style = note_style,    text = "•  Fill in the four yellow cells (case, context, start date, end date)."),
  list(style = note_style,    text = "•  Dates generate automatically. Weekend rows are shaded grey — skip them if not relevant."),
  list(style = note_style,    text = "•  Select the rows with dates (columns A–C), copy, and paste into the visit_dates sheet."),
  list(style = note_style,    text = "•  Repeat for each case x context pair."),
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


# ---- Lookups ----------------------------------------------------------------
# Single-column list of valid setting/context types. Not an Excel Table —
# kept as a plain named range (ContextTypes) so validation references it cleanly.
# Users can add, remove, or edit values freely; no sheet protection applied.

addWorksheet(wb, "Lookups", tabColour = "#E67E22")
setColWidths(wb, "Lookups", cols = 1:2, widths = c(28, 62))

writeData(wb, "Lookups", "Setting Types", startRow = 1, startCol = 1, colNames = FALSE)
addStyle(wb, "Lookups", hdr_style, rows = 1, cols = 1)

default_types <- c("School", "Household", "Healthcare", "Community",
                   "Workplace", "Childcare", "Place of worship", "Transport")
writeData(wb, "Lookups", default_types, startRow = 2, startCol = 1, colNames = FALSE)
addStyle(wb, "Lookups", note_style, rows = 2:(1 + length(default_types)), cols = 1)

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
  "Do not rename or delete the 'Setting Types' header in cell A1."
)
writeData(wb, "Lookups", lookup_instructions, startRow = 2, startCol = 2, colNames = FALSE)
addStyle(wb, "Lookups", note_style,
         rows = 2:(1 + length(lookup_instructions)), cols = 2)


# ---- cases ------------------------------------------------------------------
# Columns:
#   A  case_id           — auto-formula (C-001…), locked
#   B  CIMS_id           — manual; amber highlight on duplicate
#   C  forename          — free text
#   D  surname           — free text
#   E  date_of_birth     — date; drives age
#   F  age               — formula: DATEDIF(DOB, onset_date), locked
#   G  age_group         — formula: UKHSA age band derived from age, locked
#   H  gender            — dropdown
#   I  postcode          — free text
#   J  case_status       — dropdown
#   K  onset_date        — date; drives age and epi-window logic
#   L  vaccination_status — dropdown
#   M  likely_index_case — dropdown: any case_id in this table
#   N  contexts          — formula: semi-colon list of linked context names, locked

add_sheet(
  wb, "cases",
  headers    = c("case_id", "CIMS_id", "forename", "surname",
                 "date_of_birth", "age", "age_group",
                 "gender", "postcode", "case_status", "onset_date",
                 "vaccination_status", "likely_index_case", "contexts"),
  example    = list("", "CIMS-123", "Jane", "Smith",
                    as.Date("1995-03-15"), "", "",
                    "Female", "SW1A 1AA", "Confirmed", as.Date("2026-04-01"),
                    "Unvaccinated", "", ""),
  col_widths = c(10, 14, 14, 14, 16, 8, 14, 12, 14, 14, 16, 20, 16, 45),
  nrows      = 1000,
  date_cols  = c(5, 11),
  dropdowns  = list(
    list(col = 8,  formula = '"Male,Female,Other,Unknown"'),
    list(col = 10, formula = '"Confirmed,Probable,Possible"'),
    list(col = 12, formula = '"Unvaccinated,1 dose,2 doses,Unknown"'),
    list(col = 13, formula = "cases!$A$2:$A$1001")
  ),
  validations = list(
    list(col = 5,  type = "date", operator = "between",
         value = as.Date(c("1900-01-01", "2100-01-01"))),
    list(col = 11, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)

# case_id: row-position formula, fires regardless of other columns
writeFormula(wb, "cases",
             rep('"C-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)

# age: whole years between date_of_birth (E) and onset_date (K)
age_formulas <- paste0(
  'IF(AND(E', 2:1001, '<>"",K', 2:1001, '<>""),',
  'IFERROR(DATEDIF(E', 2:1001, ',K', 2:1001, ',"Y"),"err"),"")'
)
writeFormula(wb, "cases", age_formulas, startRow = 2, startCol = 6)

# age_group: UKHSA reporting bands derived from age (F)
# Bands: <1 year | 1-4 | 5-17 | 18-29 | 30-49 | 50+
age_group_formulas <- paste0(
  'IF(F', 2:1001, '="","",IF(F', 2:1001, '<1,"<1 year",IF(F', 2:1001,
  '<5,"1–4 years",IF(F', 2:1001, '<18,"5–17 years",IF(F', 2:1001,
  '<30,"18–29 years",IF(F', 2:1001, '<50,"30–49 years","50+ years"))))))'
)
writeFormula(wb, "cases", age_group_formulas, startRow = 2, startCol = 7)

# contexts (col N): NOT pre-populated — openxlsx cannot reliably write complex
# cross-sheet formulas to OOXML. Column is styled and locked ready to receive
# the formula. Instructions and the formula text are in the README tab.
# The user pastes the formula into N2 and copies down once after setup.

# Locked (blue): case_id (1), age (6), age_group (7) — auto-generated, never edited
addStyle(wb, "cases", locked_style,
         rows = 2:1001, cols = c(1, 6, 7), gridExpand = TRUE, stack = TRUE)

# Unlocked: all editable columns including contexts (14) — user pastes formula here
addStyle(wb, "cases", unlocked_style,
         rows = 2:1001, cols = c(2:5, 8:14), gridExpand = TRUE, stack = TRUE)

# Amber highlight on CIMS_id (col B) if the value appears more than once
conditionalFormatting(wb, "cases",
                      cols  = 2,
                      rows  = 2:1001,
                      type  = "expression",
                      rule  = "COUNTIF($B$2:$B$1001,B2)>1",
                      style = dup_style)

# Red highlight on likely_index_case (col M) if it matches the case's own case_id.
# LEN()>0 used instead of <>"" because openxlsx may not XML-escape <> in CF rules.
conditionalFormatting(wb, "cases",
                      cols  = 13,
                      rows  = 2:1001,
                      type  = "expression",
                      rule  = "AND(LEN($M2)>0,$M2=$A2)",
                      style = self_ref_style)

protectWorksheet(wb, "cases", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)


# ---- contexts ---------------------------------------------------------------
# context_id (col 1) auto-generated. context_type validated against ContextTypes
# named range in the Lookups tab.

add_sheet(
  wb, "contexts",
  headers    = c("context_id", "context_name", "context_type"),
  example    = list("", "Oakfield Primary School", "School"),
  col_widths = c(12, 35, 20),
  nrows      = 1000,
  dropdowns  = list(
    list(col = 3, formula = "OFFSET(Lookups!$A$2,0,0,COUNTA(Lookups!$A$2:$A$100),1)")
  )
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
# exposure_relevance: practitioner judgement on each case-context link —
# Infectious period, Exposure window, Both, or Neither.
# Replaces the previously derived visit_relevance; the app reads this directly.

add_sheet(
  wb, "case_contexts",
  headers    = c("case_id", "context_id", "exposure_relevance"),
  example    = list("C-001", "Ctxt-001", ""),
  col_widths = c(12, 14, 20),
  dropdowns  = list(
    list(col = 1, formula = "cases!$A$2:$A$1001"),
    list(col = 2, formula = "contexts!$A$2:$A$1001"),
    list(col = 3, formula = '"Infectious period,Exposure window,Both,Neither"')
  )
)


# ---- visit_dates ------------------------------------------------------------

add_sheet(
  wb, "visit_dates",
  headers    = c("case_id", "context_id", "visit_date"),
  example    = list("C-001", "Ctxt-001", as.Date("2026-04-03")),
  col_widths = c(12, 14, 15),
  date_cols  = 3,
  dropdowns  = list(
    list(col = 1, formula = "cases!$A$2:$A$1001"),
    list(col = 2, formula = "contexts!$A$2:$A$1001")
  ),
  validations = list(
    list(col = 3, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)


# ---- contacts ---------------------------------------------------------------

add_sheet(
  wb, "contacts",
  headers    = c("from", "to", "link_type"),
  example    = list("C-001", "C-002", "Possible"),
  col_widths = c(12, 12, 14),
  dropdowns  = list(
    list(col = 1, formula = "cases!$A$2:$A$1001"),
    list(col = 2, formula = "cases!$A$2:$A$1001"),
    list(col = 3, formula = '"Probable,Possible"')
  )
)


# ---- Date Helper ------------------------------------------------------------

addWorksheet(wb, "Date Helper", tabColour = "#27AE60")
setColWidths(wb, "Date Helper", cols = 1:4, widths = c(14, 18, 15, 8))
freezePane(wb, "Date Helper", firstRow = TRUE)

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

writeData(wb, "Date Helper", "Case ID",    startRow = 6, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "Context ID", startRow = 7, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "Start date", startRow = 8, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "End date",   startRow = 9, startCol = 1, colNames = FALSE)

label_style <- createStyle(fontColour = "#2C3E50", fontSize = 11, textDecoration = "bold")
addStyle(wb, "Date Helper", label_style, rows = 6:9, cols = 1, gridExpand = TRUE)
addStyle(wb, "Date Helper", input_style, rows = 6:9, cols = 2, gridExpand = TRUE)
addStyle(wb, "Date Helper", date_style,  rows = 8:9, cols = 2, gridExpand = TRUE, stack = TRUE)

dataValidation(wb, "Date Helper", col = 2, rows = 6,
               type  = "list",
               value = "cases!$A$2:$A$1001")
dataValidation(wb, "Date Helper", col = 2, rows = 7,
               type  = "list",
               value = "contexts!$A$2:$A$1001")
dataValidation(wb, "Date Helper", col = 2, rows = 8:9,
               type = "date", operator = "between",
               value = as.Date(c("2000-01-01", "2100-01-01")))

writeData(wb, "Date Helper",
          "Generated dates — copy columns A to C into the visit_dates sheet:",
          startRow = 11, startCol = 1, colNames = FALSE)
addStyle(wb, "Date Helper", note_style, rows = 11, cols = 1)

writeData(wb, "Date Helper", "case_id",    startRow = 12, startCol = 1, colNames = FALSE)
writeData(wb, "Date Helper", "context_id", startRow = 12, startCol = 2, colNames = FALSE)
writeData(wb, "Date Helper", "visit_date", startRow = 12, startCol = 3, colNames = FALSE)
writeData(wb, "Date Helper", "Day",        startRow = 12, startCol = 4, colNames = FALSE)
addStyle(wb, "Date Helper", output_hdr_style, rows = 12, cols = 1:4, gridExpand = TRUE)

writeFormula(wb, "Date Helper",
             rep('IF($B$6<>"",$B$6,"")', 60),
             startRow = 13, startCol = 1)
writeFormula(wb, "Date Helper",
             rep('IF($B$7<>"",$B$7,"")', 60),
             startRow = 13, startCol = 2)

date_formulas <- paste0(
  'IF(OR(ISBLANK($B$8),ISBLANK($B$9)),"",',
  'IF($B$8+', 0:59, '<=$B$9,$B$8+', 0:59, ',""))'
)
writeFormula(wb, "Date Helper", date_formulas, startRow = 13, startCol = 3)

day_formulas <- paste0('IF(C', 13:72, '<>"",TEXT(C', 13:72, ',"ddd"),"")')
writeFormula(wb, "Date Helper", day_formulas, startRow = 13, startCol = 4)

addStyle(wb, "Date Helper", date_style,
         rows = 13:72, cols = 3, gridExpand = TRUE, stack = TRUE)

conditionalFormatting(wb, "Date Helper",
                      cols  = 1:4,
                      rows  = 13:72,
                      type  = "expression",
                      rule  = "WEEKDAY($C13,2)>5",
                      style = weekend_style)


# ---- Named ranges -----------------------------------------------------------
# All main tables are already named Excel Tables (accessible as cases[col], etc.).
# These additional named regions register the data extents in the Name Manager
# for reference in formulas outside the tables.
# ContextTypes is the key operational named range — used by the contexts
# sheet to validate context_type entries against the Lookups tab.

createNamedRegion(wb, sheet = "cases",         rows = 1:1001, cols = 1:13, name = "CasesRange")
createNamedRegion(wb, sheet = "contexts",      rows = 1:1001, cols = 1:3,  name = "ContextsRange")
createNamedRegion(wb, sheet = "case_contexts", rows = 1:2001, cols = 1:2,  name = "CaseContextsRange")
createNamedRegion(wb, sheet = "visit_dates",   rows = 1:2001, cols = 1:3,  name = "VisitDatesRange")
createNamedRegion(wb, sheet = "contacts",      rows = 1:2001, cols = 1:3,  name = "ContactsRange")
createNamedRegion(wb, sheet = "Lookups",       rows = 2:100,  cols = 1,    name = "ContextTypes")


# ---- Save -------------------------------------------------------------------

saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
message("Template saved to: ", normalizePath(OUT_PATH))
