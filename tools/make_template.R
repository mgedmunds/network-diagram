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

date_style <- createStyle(numFmt = "DD/MM/YYYY")

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

  # Header row
  hdr_df <- as.data.frame(t(headers), stringsAsFactors = FALSE)
  writeData(wb, name, hdr_df, colNames = FALSE, startRow = 1)
  addStyle(wb, name, hdr_style,
           rows = 1, cols = seq_along(headers), gridExpand = TRUE)

  # Example row
  eg_df <- as.data.frame(example, stringsAsFactors = FALSE)
  writeData(wb, name, eg_df, colNames = FALSE, startRow = 2)
  addStyle(wb, name, example_style,
           rows = 2, cols = seq_along(headers), gridExpand = TRUE)

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
  list(style = note_style,    text = "2.  Fill in the 'settings' sheet — one row per location linked to the outbreak."),
  list(style = note_style,    text = "    Assign each setting a unique integer ID starting from 1."),
  list(style = note_style,    text = "3.  Fill in 'case_settings' — one row per case x setting combination."),
  list(style = note_style,    text = "4.  Fill in 'visit_dates' — one row per date a case visited a setting."),
  list(style = note_style,    text = "5.  Fill in 'contacts' (optional) — one row per known transmission link."),
  list(style = note_style,    text = "6.  Delete the example rows (shaded grey, italic) before uploading."),
  list(style = note_style,    text = "7.  Save as .xlsx and upload using the Upload button in the network tool."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "RULES"),
  list(style = note_style,    text = "•  case_id must be unique in 'cases' and match exactly across all other sheets."),
  list(style = note_style,    text = "•  setting_id must be a unique whole number in 'settings' and match across all other sheets."),
  list(style = note_style,    text = "•  Dates must be entered as Excel dates in DD/MM/YYYY format — not as plain text."),
  list(style = note_style,    text = "   Click on a date cell and use the date picker, or type the date and confirm it shows as a date."),
  list(style = note_style,    text = "•  Do not rename or reorder the sheet tabs."),
  list(style = note_style,    text = "•  Do not rename or reorder the column headers."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "VALIDATION — what the cells will check as you type"),
  list(style = note_style,    text = "•  onset_date, visit_date: must be a valid date (DD/MM/YYYY). Text will be rejected."),
  list(style = note_style,    text = "•  setting_id in 'settings': must be a whole number greater than zero."),
  list(style = note_style,    text = "•  case_id and setting_id in other sheets: not enforced in Excel — the upload tool"),
  list(style = note_style,    text = "   will flag any IDs that do not match the cases or settings sheets on import."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "DROPDOWN FIELDS — select from the list; do not type free text"),
  list(style = note_style,    text = "•  age_group:          Under 1 year | 1-4 years | 5-17 years | 18-29 years | 30-49 years | 50+"),
  list(style = note_style,    text = "•  vaccination_status: Unvaccinated | 1 dose | 2 doses | Unknown"),
  list(style = note_style,    text = "•  case_status:        Confirmed | Probable | Possible"),
  list(style = note_style,    text = "•  link_type:          Confirmed | Suspected"),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "SETTING TYPE"),
  list(style = note_style,    text = "•  setting_type is free text — you define the categories for this outbreak."),
  list(style = note_style,    text = "•  Use consistent capitalisation across all rows (e.g. always 'School', not 'school')."),
  list(style = note_style,    text = "•  Suggested values: School, Household, Healthcare, Community, Workplace, Childcare."),
  list(style = note_style,    text = ""),
  list(style = section_style, text = "CONTACTS SHEET"),
  list(style = note_style,    text = "•  Optional. Leave blank if transmission links are not known."),
  list(style = note_style,    text = "•  'from' is the source case; 'to' is the case who was infected."),
  list(style = note_style,    text = "•  The app can derive Suspected links automatically from shared settings and timing.")
)

for (i in seq_along(readme_rows)) {
  writeData(wb, "README", readme_rows[[i]]$text, startRow = i, colNames = FALSE)
  addStyle(wb, "README", readme_rows[[i]]$style, rows = i, cols = 1)
}

# ---- cases ------------------------------------------------------------------

add_sheet(
  wb, "cases",
  headers    = c("case_id", "onset_date", "age_group", "vaccination_status", "case_status"),
  example    = list("C001", as.Date("2026-04-01"), "5-17 years", "Unvaccinated", "Confirmed"),
  col_widths = c(12, 15, 15, 20, 14),
  date_cols  = 2,
  dropdowns  = list(
    list(col = 3, formula = '"Under 1 year,1-4 years,5-17 years,18-29 years,30-49 years,50+"'),
    list(col = 4, formula = '"Unvaccinated,1 dose,2 doses,Unknown"'),
    list(col = 5, formula = '"Confirmed,Probable,Possible"')
  ),
  validations = list(
    # onset_date must be a real date (col 2)
    list(col = 2, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)

# ---- settings ---------------------------------------------------------------

add_sheet(
  wb, "settings",
  headers    = c("setting_id", "setting_name", "setting_type"),
  example    = list(1L, "Oakfield Primary School", "School"),
  col_widths = c(12, 35, 16),
  validations = list(
    # setting_id must be a whole number > 0
    list(col = 1, type = "whole", operator = "greaterThan", value = 0)
  )
)

# ---- case_settings ----------------------------------------------------------

add_sheet(
  wb, "case_settings",
  headers    = c("case_id", "setting_id"),
  example    = list("C001", 1L),
  col_widths = c(12, 14)
)

# ---- visit_dates ------------------------------------------------------------

add_sheet(
  wb, "visit_dates",
  headers    = c("case_id", "setting_id", "visit_date"),
  example    = list("C001", 1L, as.Date("2026-04-03")),
  col_widths = c(12, 14, 15),
  date_cols  = 3,
  validations = list(
    list(col = 3, type = "date", operator = "between",
         value = as.Date(c("2000-01-01", "2100-01-01")))
  )
)

# ---- contacts ---------------------------------------------------------------

add_sheet(
  wb, "contacts",
  headers    = c("from", "to", "link_type"),
  example    = list("C001", "C002", "Suspected"),
  col_widths = c(12, 12, 14),
  dropdowns  = list(
    list(col = 3, formula = '"Confirmed,Suspected"')
  )
)

# ---- Save -------------------------------------------------------------------

saveWorkbook(wb, OUT_PATH, overwrite = TRUE)
message("Template saved to: ", normalizePath(OUT_PATH))
