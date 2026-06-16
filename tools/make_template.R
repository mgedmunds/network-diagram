# tools/make_template.R
#
# Generates the Stage 1 data entry Excel template for the outbreak network tool.
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
locked_style   <- createStyle(fgFill = "#E8F0FE", locked = TRUE)   # light blue = auto-generated, read-only
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
#               Extra args (operator, value) are passed through to dataValidation()

add_sheet <- function(wb, name, headers, example, col_widths = NULL,
                      date_cols = NULL, dropdowns = list(),
                      validations = list()) {
  addWorksheet(wb, name, tabColour = "#2980B9")

  # Write data as a named Excel table (table name matches schema table name).
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

  # Style the example row as grey italic
  addStyle(wb, name, example_style,
           rows = 2, cols = seq_along(headers), gridExpand = TRUE, stack = TRUE)

  # Date format on date columns (applies to all data rows including example)
  if (!is.null(date_cols)) {
    addStyle(wb, name, date_style,
             rows = 2:2000, cols = date_cols, gridExpand = TRUE, stack = TRUE)
  }

  # Freeze header row
  freezePane(wb, name, firstRow = TRUE)

  # Column widths
  if (!is.null(col_widths)) {
    setColWidths(wb, name, cols = seq_along(headers), widths = col_widths)
  } else {
    setColWidths(wb, name, cols = seq_along(headers), widths = "auto")
  }

  # Dropdown validation (list type) on data rows
  for (dd in dropdowns) {
    dataValidation(
      wb, name,
      col   = dd$col,
      rows  = 2:2000,
      type  = "list",
      value = dd$formula
    )
  }

  # Other validations (whole, date, custom formula)
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
  list(style = note_style,    text = "    Assign each context a unique integer ID starting from 1."),
  list(style = note_style,    text = "3.  Fill in 'case_contexts' — one row per case x context combination."),
  list(style = note_style,    text = "4.  Fill in 'visit_dates' — one row per date a case visited a context."),
  list(style = note_style,    text = "5.  Fill in 'contacts' (optional) — one row per known transmission link."),
  list(style = note_style,    text = "6.  Delete the example rows (shaded grey, italic) before uploading."),
  list(style = note_style,    text = "7.  Save as .xlsx and upload using the Upload button in the network tool."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "RULES"),
  list(style = note_style,    text = "•  case_id and context_id are AUTO-GENERATED — do not type in these columns."),
  list(style = note_style,    text = "   case_id fills as C-001, C-002 … when you enter onset_date on each row."),
  list(style = note_style,    text = "   context_id fills as Ctxt-001, Ctxt-002 … when you enter context_name on each row."),
  list(style = note_style,    text = "   These columns are shaded blue and locked. If the ID does not appear, check the adjacent column is filled."),
  list(style = note_style,    text = "•  Do not delete rows — IDs are based on row position and will renumber if rows are removed."),
  list(style = note_style,    text = "•  Dates must be entered as Excel dates in DD/MM/YYYY format — not as plain text."),
  list(style = note_style,    text = "   Click on a date cell and use the date picker, or type the date and confirm it shows as a date."),
  list(style = note_style,    text = "•  Do not rename or reorder the sheet tabs."),
  list(style = note_style,    text = "•  Do not rename or reorder the column headers."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "VALIDATION — what the cells will check as you type"),
  list(style = note_style,    text = "•  onset_date, visit_date: must be a valid date (DD/MM/YYYY). Text will be rejected."),
  list(style = note_style,    text = "•  case_id in 'case_contexts', 'visit_dates', 'contacts': dropdown shows only IDs from the 'cases' sheet."),
  list(style = note_style,    text = "•  context_id in 'case_contexts', 'visit_dates': dropdown shows only IDs from the 'contexts' sheet."),
  list(style = note_style,    text = "   Fill 'cases' and 'contexts' first — their IDs will then appear in the dropdowns."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DROPDOWN FIELDS — select from the list; do not type free text"),
  list(style = note_style,    text = "•  age_group:          Under 1 year | 1-4 years | 5-17 years | 18-29 years | 30-49 years | 50+"),
  list(style = note_style,    text = "•  vaccination_status: Unvaccinated | 1 dose | 2 doses | Unknown"),
  list(style = note_style,    text = "•  case_status:        Confirmed | Probable | Possible"),
  list(style = note_style,    text = "•  link_type:          Confirmed | Suspected"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTEXT TYPE"),
  list(style = note_style,    text = "•  context_type is free text — you define the categories for this outbreak."),
  list(style = note_style,    text = "•  Use consistent capitalisation across all rows (e.g. always 'School', not 'school')."),
  list(style = note_style,    text = "•  Suggested values: School, Household, Healthcare, Community, Workplace, Childcare."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTACTS SHEET"),
  list(style = note_style,    text = "•  Optional. Leave blank if transmission links are not known."),
  list(style = note_style,    text = "•  'from' is the source case; 'to' is the case who was infected."),
  list(style = note_style,    text = "•  The app can derive Suspected links automatically from shared contexts and timing.")
)

for (i in seq_along(readme_rows)) {
  writeData(wb, "README", readme_rows[[i]]$text, startRow = i, colNames = FALSE)
  addStyle(wb, "README", readme_rows[[i]]$style, rows = i, cols = 1)
}

# ---- cases ------------------------------------------------------------------
# case_id (col 1) is auto-generated: C-001, C-002 … based on row position.
# The formula fires when onset_date (col 2) is non-empty.
# Col 1 is locked; all other data columns are unlocked.

add_sheet(
  wb, "cases",
  headers    = c("case_id", "onset_date", "age_group", "vaccination_status", "case_status"),
  example    = list("", as.Date("2026-04-01"), "5-17 years", "Unvaccinated", "Confirmed"),
  col_widths = c(12, 15, 15, 20, 14),
  date_cols  = 2,
  dropdowns  = list(
    list(col = 3, formula = '"Under 1 year,1-4 years,5-17 years,18-29 years,30-49 years,50+"'),
    list(col = 4, formula = '"Unvaccinated,1 dose,2 doses,Unknown"'),
    list(col = 5, formula = '"Confirmed,Probable,Possible"')
  ),
  validations = list(
    list(col = 2, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)

writeFormula(wb, "cases",
             rep('"C-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)
addStyle(wb, "cases", locked_style,   rows = 2:1001, cols = 1,   gridExpand = TRUE, stack = TRUE)
addStyle(wb, "cases", unlocked_style, rows = 2:1001, cols = 2:5, gridExpand = TRUE, stack = TRUE)
protectWorksheet(wb, "cases", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)

# ---- contexts ---------------------------------------------------------------
# context_id (col 1) is auto-generated: Ctxt-001, Ctxt-002 … based on row position.
# The formula fires when context_name (col 2) is non-empty.
# Col 1 is locked; all other data columns are unlocked.

add_sheet(
  wb, "contexts",
  headers    = c("context_id", "context_name", "context_type"),
  example    = list("", "Oakfield Primary School", "School"),
  col_widths = c(12, 35, 16)
)

writeFormula(wb, "contexts",
             rep('"Ctxt-"&TEXT(ROW()-1,"000")', 1000),
             startRow = 2, startCol = 1)
addStyle(wb, "contexts", locked_style,   rows = 2:1001, cols = 1,   gridExpand = TRUE, stack = TRUE)
addStyle(wb, "contexts", unlocked_style, rows = 2:1001, cols = 2:3, gridExpand = TRUE, stack = TRUE)
protectWorksheet(wb, "contexts", protect = TRUE,
                 lockSelectingLockedCells = FALSE,
                 lockInsertingRows        = FALSE)

# ---- case_contexts ----------------------------------------------------------
# case_id dropdown pulls from cases col A; context_id from contexts col A

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
# case_id and context_id dropdowns pull from cases and contexts sheets

add_sheet(
  wb, "visit_dates",
  headers    = c("case_id", "context_id", "visit_date"),
  example    = list("C001", 1L, as.Date("2026-04-03")),
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
# from and to dropdowns both pull from cases col A

add_sheet(
  wb, "contacts",
  headers    = c("from", "to", "link_type"),
  example    = list("C001", "C002", "Suspected"),
  col_widths = c(12, 12, 14),
  dropdowns  = list(
    list(col = 1, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 2, formula = "OFFSET(cases!$A$2,0,0,COUNTA(cases!$B$2:$B$1001),1)"),
    list(col = 3, formula = '"Confirmed,Suspected"')
  )
)

# ---- Save -------------------------------------------------------------------

saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
message("Template saved to: ", normalizePath(OUT_PATH))
