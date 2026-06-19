# =============================================================================
# Measles Outbreak Network Explorer
# -----------------------------------------------------------------------------
# Interactive R Shiny dashboard for visualising a measles outbreak across
# contexts, handling cases that visit MULTIPLE contexts (case x context
# affiliation / bipartite network). Key epidemiological parameters (incubation
# and infectious periods) are editable on the "Assumptions & parameters" tab and
# update the model live.
#
# Views:
# 1. Contexts <-> contexts (shared cases) -- bipartite projection onto contexts
# 2. Cases x contexts (bipartite) -- shows multi-context cases directly
# 3. Case-to-case (transmission links) -- from likely_index_case field in cases
#    from shared contexts + timing
#
# TO RUN:
# install.packages(c("shiny","bslib","visNetwork","dplyr","tidyr","readxl",
#                    "lubridate","igraph","plotly","DT","purrr","tibble",
#                    "jsonlite"))
# shiny::runApp("app.R")
# =============================================================================

# Version read from VERSION file. Patch auto-increment via git removed —
# system2() is not safe in WebR (Shinylive) across all runtime versions.
APP_VERSION <- tryCatch(
  trimws(readLines("VERSION", n = 1)),
  error = function(e) "0.1"
)

# Core Shiny framework and Bootstrap 5 UI components (cards, layout, tooltips)
library(shiny)
library(bslib)
# Interactive network diagram renderer (wraps the vis.js JavaScript library)
library(visNetwork)
# Data wrangling
library(dplyr)
library(tidyr)
library(readxl)      # Reading .xlsx files uploaded by the user
library(lubridate)   # Date arithmetic (floor_date for weekly epi curve)
# Network analysis: calculates degree and betweenness metrics from the graph
library(igraph)
# Charts and tables
library(plotly)
library(DT)          # Interactive data tables with column filtering
# Utility
library(jsonlite)    # validate() calls use shiny::validate() explicitly to avoid jsonlite masking
library(purrr)
library(tibble)
library(ggplot2)     # Epi curve chart (converted to plotly via ggplotly)

# ---- Configuration ----------------------------------------------------------
# 10 perceptually distinct colours (D3 category10). Assigned in order to whatever
# context types appear in the loaded data — no types are pre-coded.
CONTEXT_PALETTE <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
)
CASE_COLOUR <- "#444444"

# Assigns a colour from CONTEXT_PALETTE to each context type found in the data.
# Uses modular indexing so it cycles gracefully if there are more than 10 types.
# Returns a named character vector: names are context type strings, values are hex colours.
colour_map <- function(types) {
  types <- unique(types[!is.na(types)])
  setNames(CONTEXT_PALETTE[(seq_along(types) - 1L) %% length(CONTEXT_PALETTE) + 1L], types)
}

# Default epidemiological parameters (measles, approximate). All editable in-app.
DEF_INC_MIN   <- 7   # incubation, exposure -> onset, minimum (days)
DEF_INC_MAX   <- 21  # incubation, exposure -> onset, maximum (days)
DEF_INF_BEFORE <- 4  # infectious period: days before onset
DEF_INF_AFTER  <- 4  # infectious period: days after onset

# ---- UI helpers -------------------------------------------------------------
# Renders a blue ⓘ icon with a hover tooltip. Used throughout the UI
# to attach plain-language explanations to labels and card headers.
info <- function(msg) {
  tooltip(span(style = "cursor:help; color:#2c7fb8; font-weight:bold; margin-left:4px;", "ⓘ"),
          msg, placement = "right")
}
# Convenience wrapper: creates a card header with a title and an info tooltip
# aligned to opposite ends of the header bar.
hdr <- function(title, msg) {
  card_header(class = "d-flex justify-content-between align-items-center",
              span(title), info(msg))
}
# Draws a small inline SVG arrow used in the bipartite view legend.
# direction controls which arrowheads appear; dashed draws a dashed line.
leg_arrow <- function(color, direction = "none", dashed = FALSE) {
  dash  <- if (dashed) ' stroke-dasharray="5,3"' else ''
  x1    <- if (direction %in% c("left",  "both")) 11L else 3L
  x2    <- if (direction %in% c("right", "both")) 31L else 39L
  left  <- if (direction %in% c("left",  "both"))
              sprintf('<polygon points="11,4 3,7 11,10" fill="%s"/>', color) else ''
  right <- if (direction %in% c("right", "both"))
              sprintf('<polygon points="31,4 39,7 31,10" fill="%s"/>', color) else ''
  HTML(sprintf(
    '<svg width="44" height="14" style="vertical-align:middle;margin-right:6px;overflow:visible;"><line x1="%d" y1="7" x2="%d" y2="7" stroke="%s" stroke-width="2.5"%s/>%s%s</svg>',
    x1, x2, color, dash, left, right))
}

# ---- Schema diagram & data dictionary --------------------------------------
# GraphViz source for the entity-relationship diagram shown in the Reference tab.
# Defines each table as a labelled node with its fields, and draws 1:N relationships
# between them as directed edges.
# Field-level definitions for all five tables, displayed in the Reference tab.
# Stored as a named list of data frames so the Reference tab can render each
# table independently with its own DT output.
DICT_TABLES <- list(
  cases = tibble::tribble(
    ~Field,                ~Type,       ~Key,  ~Required, ~Description,
    "case_id",             "character", "PK",  "Yes",     "Unique case identifier. Join key across all tables. Must be unique within the dataset.",
    "onset_date",          "date",      "—",   "Yes",     "Symptom onset date. Drives the time slider, epidemic curve, and all epi-period derivations (exposure window, infectious period).",
    "age_group",           "character", "—",   "No",      "Age band. Fixed values: &lt;1 year, 1–4 years, 5–17 years, 18–29 years, 30–49 years, 50+ years. Aligned with UKHSA reporting and vaccination schedule milestones.",
    "vaccination_status",  "character", "—",   "No",      "Measles vaccination history at time of illness. Values: Unvaccinated, 1 dose, 2 doses, Unknown.",
    "case_status",         "character", "—",   "No",      "Classification of the case. Values: Confirmed, Probable, Possible. Definition pending."
  ),
  contexts = tibble::tribble(
    ~Field,          ~Type,       ~Key,  ~Required, ~Description,
    "context_id",    "integer",   "PK",  "Yes",     "Surrogate primary key. Unique integer assigned to each context. Used as the join key in case_contexts and visit_dates.",
    "context_name",  "character", "—",   "Yes",     "Human-readable name for the context. Free text; should be unique within the dataset.",
    "context_type",  "character", "—",   "Yes",     "User-defined categorical label (e.g. School, Household). Not pre-coded — values come from the data. Drives node colour and the context-type filter."
  ),
  case_contexts = tibble::tribble(
    ~Field,             ~Type,       ~Key,        ~Required, ~Description,
    "case_id",          "character", "PK + FK",   "Yes",     "Composite primary key. FK to cases.case_id.",
    "context_id",       "integer",   "PK + FK",   "Yes",     "Composite primary key. FK to contexts.context_id.",
    "exposure_relevance", "character", "—",       "No",      "Practitioner judgement on the epi relevance of this case-context link. Values: <b>Infectious period</b> (case may have spread infection here), <b>Exposure window</b> (case may have acquired infection here), <b>Both</b> (relevant to both windows, e.g. household resident), <b>Neither</b> (link recorded but not considered transmission-relevant). Stored in the workbook; not derived from visit dates."
  ),
  visit_dates = tibble::tribble(
    ~Field,           ~Type,       ~Key,        ~Required, ~Description,
    "case_id",        "character", "PK + FK",   "Yes",     "Composite primary key. FK to case_contexts.case_id.",
    "context_id",     "integer",   "PK + FK",   "Yes",     "Composite primary key. FK to case_contexts.context_id.",
    "visit_date",     "date",      "PK",        "Yes",     "Date of an epi-relevant visit. One row per calendar day per case-context pair."
  )
)

# ---- Demo data --------------------------------------------------------------
# Generates a realistic synthetic outbreak dataset used when no file is uploaded.
# Produces four tables (cases, contexts, case_contexts, visit_dates) with
# plausible visit patterns. likely_index_case is populated directly on cases.
make_demo_data <- function() {
  # Fixed seed so the demo is reproducible each time the app starts
  set.seed(42)
  all_contexts <- tibble::tribble(
    ~context_id, ~context_name,              ~context_type,
    1L,          "Oakfield Primary",         "School",
    2L,          "St Mary's Secondary",      "School",
    3L,          "Hillside Nursery",         "Community",
    4L,          "Faith Community Centre",   "Community",
    5L,          "Maple Street Household",   "Household",
    6L,          "Birch Close Household",    "Household",
    7L,          "Riverside GP Surgery",     "Healthcare",
    8L,          "Central Hospital ED",      "Healthcare")
  # Split contexts into community (where primary exposure happens) and healthcare
  # (where cases are seen after onset). comm_w gives unequal sampling weights
  # so schools are over-represented, matching typical measles outbreak patterns.
  community  <- all_contexts |> filter(context_type != "Healthcare")
  healthcare <- all_contexts |> filter(context_type == "Healthcare")
  comm_w     <- c(.24, .20, .16, .14, .13, .13)
  n <- 15
  # Generate the cases table: 15 cases with random onset dates over an 8-week period
  cases <- tibble::tibble(
    case_id            = sprintf("C%03d", seq_len(n)),
    onset_date         = as.Date("2026-04-01") + sample(0:56, n, replace = TRUE),
    age_group          = sample(c("<1 year","1–4 years","5–17 years","18–29 years","30–49 years","50+ years"),
                                n, TRUE, c(.10,.20,.30,.20,.12,.08)),
    vaccination_status = sample(c("Unvaccinated","1 dose","2 doses","Unknown"),
                                n, TRUE, c(.5,.2,.2,.1)),
    case_status        = sample(c("Confirmed","Probable","Possible"),
                                n, TRUE, c(.6,.3,.1))) |> arrange(onset_date)

  # Assign each case a primary community context (weighted towards schools)
  prim <- sample(seq_len(nrow(community)), n, replace = TRUE, prob = comm_w)

  # Helper: pick n_dates distinct dates from a window vector
  pick_dates <- function(window, n_dates) sort(sample(window, min(n_dates, length(window))))

  # Build visit_dates rows for each case.
  # Each case gets visits to their primary context, and with some probability
  # also visits to a healthcare setting and a secondary exposure context.
  visit_rows <- purrr::map_dfr(seq_len(n), function(i) {
    onset     <- cases$onset_date[i]
    inf_win   <- seq(onset - DEF_INF_BEFORE, onset + DEF_INF_AFTER)
    exp_win   <- seq(onset - DEF_INC_MAX,    onset - DEF_INC_MIN)

    prim_ctype <- community$context_type[prim[i]]
    # Households: case is resident, so record dates spanning both the exposure and infectious windows.
    # Other contexts: 1–3 visits during the infectious period only.
    prim_dates <- if (prim_ctype == "Household")
                    c(pick_dates(exp_win, sample(2:4, 1)),
                      pick_dates(inf_win, sample(2:4, 1)))
                  else pick_dates(inf_win, sample(1:3, 1, prob = c(.4, .4, .2)))
    rows <- tibble::tibble(case_id    = cases$case_id[i],
                           context_id = community$context_id[prim[i]],
                           visit_date = prim_dates)

    # 70% chance the case visited a healthcare setting shortly after onset
    if (runif(1) < 0.70) {
      h <- healthcare[sample(nrow(healthcare), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          context_id = h$context_id,
                          visit_date = onset + sample(1:3, 1))) }

    # 65% chance the case also attended a second community context during their exposure window
    if (runif(1) < 0.65) {
      s_exp      <- community[sample(seq_len(nrow(community))[-prim[i]], 1), ]
      exp_dates  <- if (s_exp$context_type == "Household") onset - sample(DEF_INC_MIN:DEF_INC_MAX, 1)
                    else pick_dates(exp_win, sample(1:2, 1))
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          context_id = s_exp$context_id,
                          visit_date = exp_dates)) }

    # 35% chance of a historically recorded visit well outside the epi windows (noise)
    if (runif(1) < 0.35) {
      s_hist <- community[sample(seq_len(nrow(community)), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          context_id = s_hist$context_id,
                          visit_date = onset - sample(22:30, 1))) }
    rows
  }) |> arrange(case_id, visit_date)

  # Derive the three relational tables from the visit rows
  visit_dates   <- visit_rows |> distinct(case_id, context_id, visit_date)
  # Compute exposure_relevance for demo data using the default epi windows,
  # mirroring the practitioner judgement that real users would enter in the workbook.
  er <- visit_dates |>
    left_join(cases |> select(case_id, onset_date), by = "case_id") |>
    mutate(
      in_infectious = visit_date >= onset_date - DEF_INF_BEFORE & visit_date <= onset_date + DEF_INF_AFTER,
      in_exposure   = visit_date >= onset_date - DEF_INC_MAX    & visit_date <= onset_date - DEF_INC_MIN
    ) |>
    group_by(case_id, context_id) |>
    summarise(any_infectious = any(in_infectious, na.rm = TRUE),
              any_exposure   = any(in_exposure,   na.rm = TRUE),
              .groups = "drop") |>
    mutate(exposure_relevance = dplyr::case_when(
      any_infectious & any_exposure ~ "Both",
      any_infectious                ~ "Infectious period",
      any_exposure                  ~ "Exposure window",
      TRUE                          ~ "Neither")) |>
    select(case_id, context_id, exposure_relevance)
  case_contexts <- visit_rows |> distinct(case_id, context_id) |>
    left_join(er, by = c("case_id", "context_id")) |>
    mutate(exposure_relevance = coalesce(exposure_relevance, "Neither"))
  # Keep only contexts that at least one case actually visited
  contexts <- all_contexts |> semi_join(case_contexts, by = "context_id")

  # Assign likely_index_case for each case (except the first).
  # Cases sharing a primary context are 5x more likely to be linked.
  prim_id <- community$context_id[prim]
  index_cases <- c(NA_character_, purrr::map_chr(seq_len(n)[-1], function(i) {
    cand <- cases[seq_len(i - 1), ]
    w    <- ifelse(prim_id[seq_len(i - 1)] == prim_id[i], 5, 1)
    j    <- sample(seq_len(nrow(cand)), 1, prob = w)
    cand$case_id[j]
  }))
  cases <- cases |> mutate(likely_index_case = index_cases)

  list(cases = cases, contexts = contexts, case_contexts = case_contexts,
       visit_dates = visit_dates)
}

# Joins case_contexts, contexts, and visit_dates into a single flat table.
# This denormalised view is what the network view builders consume — one row
# per case × context × visit_date combination, with context name and type included.
flat_visits <- function(d) {
  result <- d$case_contexts |>
    left_join(d$contexts, by = "context_id") |>
    left_join(d$visit_dates, by = c("case_id", "context_id"))
  # exposure_relevance should be present in case_contexts (either from the
  # uploaded workbook or from make_demo_data). Guard against templates that
  # omit it so the bipartite view doesn't crash.
  if (!"exposure_relevance" %in% names(result))
    result <- result |> mutate(exposure_relevance = "Neither")
  result
}

# Classifies each case-context combination by when the case was present,

# ---- View builders ----------------------------------------------------------
# Each build_* function takes the flat visits table (from flat_visits()), the
# filtered linelist, and the colour map, and returns a list(nodes, edges) ready
# for visNetwork. The three functions correspond to the three network views.

# Contexts network view: one node per context, edges between contexts that share
# a case. Edge weight = number of shared cases. Node size = number of linked cases.
build_context_projection <- function(visits, ll, colours) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  nodes <- visits |> distinct(case_id, context_name, context_type) |>
    count(context_name, context_type, name = "cases") |>
    transmute(id = context_name, label = context_name, group = context_type,
              value = cases, color = unname(colours[context_type]), shape = "dot",
              title = paste0("<b>", context_name, "</b><br>", context_type,
                             "<br>Cases linked here: ", cases))
  # For each case that visited multiple contexts, generate all pairwise context combinations.
  # These become the edges (one edge per shared-case pair, then counted for weight).
  per_case <- visits |> distinct(case_id, context_name) |> group_by(case_id) |>
    summarise(s = list(sort(unique(context_name))), .groups = "drop") |>
    filter(lengths(s) >= 2)
  edges <- purrr::map_dfr(per_case$s, function(s) {
    m <- t(combn(s, 2)); tibble::tibble(from = m[, 1], to = m[, 2]) })
  if (nrow(edges)) {
    edges <- edges |> count(from, to, name = "weight") |>
      transmute(from, to, value = weight,
                title = paste0(weight, " shared case(s) connect these contexts"))
  } else edges <- tibble::tibble(from = character(), to = character(),
                                 value = numeric(), title = character())
  list(nodes = nodes, edges = edges)
}

# Who visited where view: a bipartite graph with two node types.
# Case nodes (dark dots, unlabelled) connect to context nodes (coloured squares).
# Edge colour and arrow direction encode the exposure_relevance category, showing
# whether the case was infectious here, may have been exposed here, or both.
build_bipartite <- function(visits, ll, colours) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  # Check whether visit_date data is available — affects tooltip date display
  has_dates <- "visit_date" %in% names(visits) && any(!is.na(visits$visit_date))

  # Context nodes use "ctx::" prefix on their IDs to avoid collisions with case IDs
  context_nodes <- visits |> distinct(context_name, context_type, case_id) |>
    count(context_name, context_type, name = "cases") |>
    transmute(id = paste0("ctx::", context_name), label = context_name,
              group = context_type, kind = "Context",
              color = unname(colours[context_type]), shape = "square",
              size  = 14 + 4 * sqrt(cases),
              title = paste0("<b>", context_name, "</b><br>", context_type,
                             "<br>Distinct cases: ", cases))
  nset <- visits |> distinct(case_id, context_name) |> count(case_id, name = "ns")
  case_nodes <- visits |> distinct(case_id) |>
    left_join(ll |> select(case_id, onset_date), by = "case_id") |>
    left_join(nset, by = "case_id") |>
    transmute(id = case_id, label = "", group = "Case", kind = "Case",
              color = CASE_COLOUR, shape = "dot", size = 8,
              title = paste0("<b>", case_id, "</b><br>Onset: ", onset_date,
                             "<br>Contexts visited: ", ns))

  # Collapse multiple visit dates per case-context pair into a single label
  # for the edge tooltip. If only one date, show it directly; multiple dates
  # are listed as "Dates: 01 Apr, 03 Apr, …"
  edges_agg <- visits |>
    group_by(case_id, context_name, context_type, exposure_relevance) |>
    summarise(
      date_label = {
        ds <- sort(unique(visit_date[!is.na(visit_date)]))
        if (!has_dates || length(ds) == 0) ""
        else if (length(ds) == 1) paste0("<br>Date: ", ds[1])
        else paste0("<br>Dates: ", paste(format(ds, "%d %b"), collapse = ", "))
      },
      .groups = "drop"
    )

  # Set edge colour, arrow direction, and dash style based on exposure_relevance:
  #   Infectious period → red arrow pointing TO the context (case spread here)
  #   Exposure window   → blue arrow pointing FROM the context (case caught it here)
  #   Both              → purple bidirectional arrow
  #   Neither           → grey dashed line (present but not relevant)
  edges <- edges_agg |>
    transmute(
      from               = case_id,
      to                 = paste0("ctx::", context_name),
      exposure_relevance = exposure_relevance,
      dashes             = exposure_relevance == "Neither",
      arrows             = dplyr::case_when(
                             exposure_relevance == "Infectious period" ~ "to",
                             exposure_relevance == "Exposure window"   ~ "from",
                             exposure_relevance == "Both"              ~ "to;from",
                             TRUE                                      ~ ""),
      color              = dplyr::case_when(
                             exposure_relevance == "Infectious period" ~ "#d62728",
                             exposure_relevance == "Exposure window"   ~ "#1f77b4",
                             exposure_relevance == "Both"              ~ "#9467bd",
                             TRUE                                      ~ "#9aa0a6"),
      title              = paste0(
                             "<b>", htmltools::htmlEscape(case_id), "</b> visited <b>",
                             htmltools::htmlEscape(context_name), "</b>",
                             date_label,
                             dplyr::case_when(
                               exposure_relevance == "Both"              ~
                                 "<br>Present — during both windows<br><i>Falls within both the infectious period and exposure window</i>",
                               exposure_relevance == "Infectious period" ~
                                 "<br>Present — during infectious period<br><i>Case may have transmitted infection here</i>",
                               exposure_relevance == "Exposure window"   ~
                                 "<br>Present — during exposure window<br><i>Case may have acquired infection here</i>",
                               TRUE ~
                                 "<br>Present — outside both windows<br><i>Not considered relevant to transmission</i>")))
  list(nodes = bind_rows(context_nodes, case_nodes), edges = edges)
}

# Derive POSSIBLE case-to-case links from shared contexts + onset timing.
# A possible link (earlier -> later case) is drawn when two cases attended the
# same context and the later onset falls within [inc_min - inf_before,
# inc_max + inf_after] days after the earlier onset.
derive_possible_links <- function(ll, visits, inc_min, inc_max, inf_before, inf_after) {
  empty <- tibble(from = character(), to = character(), link_type = character())
  if (nrow(visits) == 0) return(empty)
  onset <- setNames(ll$onset_date, ll$case_id)
  pair_list <- visits |> distinct(case_id, context_name) |> group_by(context_name) |>
    summarise(cz = list(sort(unique(case_id))), .groups = "drop") |>
    filter(lengths(cz) >= 2)
  if (nrow(pair_list) == 0) return(empty)
  pairs <- purrr::map_dfr(pair_list$cz, function(cz) {
    m <- t(combn(cz, 2)); tibble::tibble(a = m[, 1], b = m[, 2]) })
  if (nrow(pairs) == 0) return(empty)
  lb <- inc_min - inf_before; ub <- inc_max + inf_after
  pairs |>
    mutate(gap  = as.numeric(as.Date(onset[b]) - as.Date(onset[a])),
           from = ifelse(gap >= 0, a, b), to = ifelse(gap >= 0, b, a),
           agap = abs(gap)) |>
    filter(agap > 0, agap >= lb, agap <= ub) |>
    distinct(from, to) |> mutate(link_type = "Possible")
}

# Who infected whom view: one node per case, edges from likely_index_case field.
# Node colour reflects the case's primary context type.
build_transmission_network <- function(ll, visits, colours) {
  if (!("likely_index_case" %in% names(ll)))
    ll <- ll |> mutate(likely_index_case = NA_character_)

  edges_raw <- ll |>
    filter(!is.na(likely_index_case) & nchar(likely_index_case) > 0) |>
    select(from = likely_index_case, to = case_id)

  primary <- if (nrow(visits) > 0)
    visits |> arrange(visit_date) |> group_by(case_id) |> slice(1) |> ungroup() |>
      select(case_id, context_type)
  else tibble(case_id = character(), context_type = character())

  n_contexts   <- visits |> distinct(case_id, context_name) |> count(case_id, name = "n_contexts")
  ctx_tbl      <- visits |> distinct(case_id, context_name, context_type)
  onset        <- setNames(ll$onset_date, ll$case_id)

  nodes <- ll |>
    left_join(primary,    by = "case_id") |>
    left_join(n_contexts, by = "case_id") |>
    mutate(context_type = coalesce(context_type, "Other"),
           n_contexts   = coalesce(n_contexts, 0L)) |>
    transmute(id = case_id, label = case_id, group = context_type,
              color = coalesce(unname(colours[context_type]), "#7f7f7f"),
              title = paste0("<b>", htmltools::htmlEscape(case_id), "</b><br>Onset: ", onset_date,
                             "<br>Contexts visited: ", n_contexts))

  if (nrow(edges_raw) == 0)
    return(list(nodes = nodes, edges = tibble(from = character(), to = character())))

  edges <- edges_raw |> filter(from %in% nodes$id, to %in% nodes$id) |>
    mutate(
      gap = purrr::map2_int(from, to, function(f, t) {
        d1 <- onset[[f]]; d2 <- onset[[t]]
        if (is.na(d1) || is.na(d2)) NA_integer_ else as.integer(abs(as.Date(d2) - as.Date(d1)))
      }),
      common_text = purrr::map2_chr(from, to, function(f, t) {
        shared <- intersect(ctx_tbl$context_name[ctx_tbl$case_id == f],
                            ctx_tbl$context_name[ctx_tbl$case_id == t])
        if (length(shared) == 0) "None recorded"
        else paste(paste0(htmltools::htmlEscape(shared)), collapse = "<br>")
      }),
      title = paste0(
        "<b>", htmltools::htmlEscape(from), "</b> → <b>", htmltools::htmlEscape(to), "</b>",
        ifelse(!is.na(gap), paste0("<br>Onset gap: ", gap, ifelse(gap == 1, " day", " days")), ""),
        "<br>Shared contexts: ", common_text)
    ) |>
    transmute(from, to, title)

  list(nodes = nodes, edges = edges)
}

# Possible links network: nodes and edges for the Possible links page.
# Candidate pairs already captured by likely_index_case are excluded.
build_possible_net <- function(ll, candidates, visits, colours) {
  if (nrow(candidates) == 0)
    return(list(nodes = tibble(id=character(), label=character()),
                edges = tibble(from=character(), to=character())))

  primary <- if (nrow(visits) > 0)
    visits |> arrange(visit_date) |> group_by(case_id) |> slice(1) |> ungroup() |>
      select(case_id, context_type)
  else tibble(case_id = character(), context_type = character())

  onset <- setNames(ll$onset_date, ll$case_id)
  involved <- unique(c(candidates$from, candidates$to))

  nodes <- ll |> filter(case_id %in% involved) |>
    left_join(primary, by = "case_id") |>
    mutate(context_type = coalesce(context_type, "Other")) |>
    transmute(id = case_id, label = case_id, group = context_type,
              color = coalesce(unname(colours[context_type]), "#7f7f7f"),
              title = paste0("<b>", htmltools::htmlEscape(case_id), "</b><br>Onset: ", onset_date))

  edges <- candidates |>
    mutate(
      title = paste0("<b>", htmltools::htmlEscape(from), "</b> → <b>",
                     htmltools::htmlEscape(to), "</b><br>Onset gap: ",
                     as.integer(as.Date(onset[to]) - as.Date(onset[from])), " days"),
      color = "#e67e22",
      dashes = TRUE
    ) |>
    select(from, to, title, color, dashes)

  list(nodes = nodes, edges = edges)
}

# Calculates degree and betweenness for every node in the current network view.
# Uses igraph to build the graph, then maps results back to display labels.
# The "Kind" column (Case / Context) is included only for the bipartite view,
# where nodes represent two different entity types.
network_metrics <- function(nodes, edges) {
  if (nrow(nodes) == 0)
    return(data.frame(Node = character(), Degree = integer(), Betweenness = numeric()))
  g <- igraph::graph_from_data_frame(
    d        = if (nrow(edges)) edges[, c("from", "to")] else data.frame(from = character(), to = character()),
    vertices = nodes["id"], directed = FALSE)
  ord <- igraph::V(g)$name
  lbl <- setNames(if ("label" %in% names(nodes)) nodes$label else nodes$id, nodes$id)
  out <- data.frame(Node = unname(lbl[ord]), Degree = igraph::degree(g),
                    Betweenness = round(igraph::betweenness(g), 1), row.names = NULL)
  if ("kind" %in% names(nodes)) {
    knd    <- setNames(nodes$kind, nodes$id)
    out$Kind <- unname(knd[ord]); out <- out[, c("Node", "Kind", "Degree", "Betweenness")]
  }
  out[order(-out$Degree), ]
}

# Draws a weekly bar chart of new cases by onset date.
# week_start = 1 means weeks run Monday–Sunday (ISO standard).
# Built with ggplot2 then converted to an interactive plotly chart.
epi_curve <- function(ll) {
  if (nrow(ll) == 0) return(plotly_empty())
  d <- ll |> mutate(week = floor_date(onset_date, "week", week_start = 1)) |> count(week)
  p <- ggplot2::ggplot(d, ggplot2::aes(week, n)) +
    ggplot2::geom_col(fill = "#2c7fb8") + ggplot2::labs(x = NULL, y = "New cases") +
    ggplot2::theme_minimal(base_size = 12)
  ggplotly(p)
}

# Generates a JavaScript callback for DT that attaches tooltip text to each
# column heading. The tips vector must align positionally with the table columns.
header_tooltips <- function(tips) {
  JS(sprintf(
    "function(thead){ var tips=%s; $(thead).find('th').each(function(i){ if(tips[i]){ $(this).attr('title', tips[i]); $(this).css('text-decoration','underline dotted'); $(this).css('cursor','help'); } }); }",
    jsonlite::toJSON(tips)))
}
# Tooltip text for the network metrics and line list tables, keyed by column name
metric_tips_lookup <- c(
  Node        = "The individual case or the context this row describes.",
  Kind        = "Whether this node is a Case or a Context (Who visited where view only).",
  Degree      = "Number of direct links. For a context: how many case-visits it has. For a case: how many contexts it visited (Who visited where) or transmission links it has (Who infected whom).",
  Betweenness = "How often this node lies on the connecting path between others. A high value flags a 'bridge' joining otherwise separate parts of the outbreak.")
ll_tips_lookup <- c(
  case_id            = "Unique identifier for each case.",
  onset_date         = "Date the case first developed symptoms. Drives the time slider, epidemic curve and infectious-period logic.",
  age_group          = "Age band of the case.",
  vaccination_status = "Recorded measles vaccination status of the case.",
  case_status        = "Classification of the case: Confirmed, Probable, or Possible.",
  contexts_visited   = "Number of distinct contexts this case is recorded as having visited.")

# ---- Definitions content ----------------------------------------------------
definitions_md <- '
## Definitions

Terms used in this tool and what they mean in the context of outbreak investigation.

---

### Likely index case

The case identified by the investigating practitioner as the probable source of
infection for another case. Recorded in the **likely_index_case** field of the
cases table. Shown as a directed arrow in the **Who infected whom** view.

### Possible undetected link

A pair of cases flagged by the tool as a plausible transmission pair based on
shared context attendance and onset timing — but not yet captured in the
likely_index_case field. Shown on the **Possible links** page with supporting
data to help the practitioner assess whether to record the link. See
**Assumptions & parameters** for the timing rule and parameters.

---

### Context

A place where one or more cases were present during the outbreak — for example a
school, healthcare facility, community group, or household. Contexts are the
nodes in the Contexts network and Who visited where views.

### Transmission link

A directional connection from an earlier case (the source) to a later case (the
recipient), indicating a possible or probable route of infection. Arrows point
from source to recipient in the Who infected whom view.

### Degree

The number of direct links a node has. In the Who infected whom view this is the
total number of transmission links (in or out). In the Who visited where view it is the
number of contexts a case visited, or the number of cases linked to a context.
A high-degree node is a hub — either a case linked to many others, or a context
attended by many cases.

### Betweenness

How often a node lies on the shortest connecting path between other nodes in the
network. A high betweenness value flags a "bridge" — a case or context that
connects otherwise separate parts of the outbreak. Removing a high-betweenness
node would fragment the network into more isolated clusters.

### Infectious period

The window of time during which a case can transmit infection to others. In this
tool it is defined as a set number of days before and after symptom onset. Visits
that fall within this window are highlighted in red in the Who visited where view,
indicating the case was infectious at the time — a necessary but not sufficient
condition for onward transmission. Whether transmission actually occurred also
depends on whether a susceptible person was present and went on to develop
symptoms within the incubation period; that cross-case timing logic is applied
only in the Who infected whom view. The default values are based on
published measles parameters and can be adjusted on the **Assumptions &
parameters** tab.

### Incubation period

The time between a susceptible person being exposed to infection and developing
symptoms. Used by the tool to define the plausible onset-gap range for deriving
suspected case-to-case links. The default values are based on published measles
parameters and can be adjusted on the **Assumptions & parameters** tab.

---

*All links are epidemiological connections recorded or inferred during
investigation, not laboratory-proven transmission. Probable and possible
classifications reflect the strength of epidemiological evidence at the time of
recording, not a clinical or virological standard.*
'

# ---- How-to-use content -----------------------------------------------------
how_to_use_md <- '
## What this tool is for

This dashboard turns an outbreak line list into an interactive picture of **how
cases and contexts are connected**. You do not need any experience with network
diagrams - this page explains every part. A single case can visit **many
contexts**; each visit date is one row in the **visit_dates** table.

## The three views (sidebar control)

**Contexts network** - each dot is a place; two places are joined when a case
visited both (thicker line = more shared cases). Best for seeing how contexts
are connected.

**Who visited where** - shows cases (dark dots) and contexts (coloured squares);
each line is a visit. A multi-context case appears joined to several squares.

**Who infected whom** - transmission links between cases, taken from the
likely_index_case field in the cases data. Each arrow points from the
recorded source to the recipient.

**Possible links** (separate tab) - candidate pairs not yet recorded in
likely_index_case, derived from shared contexts and onset timing. Includes
a table of supporting data to help judge each candidate.

## Reading the network

Colour = context type (legend). Size = number of cases. Hover any dot or line for
details, drag to rearrange, click to highlight connections. In the Who visited
where view, line colour and arrows show the direction of potential transmission:
**red arrow → context** = present during infectious period (may have spread
infection there); **blue arrow → case** = present during exposure window (may
have acquired infection there); **purple ↔** = present during both windows;
**grey dashed** = outside both windows (not transmission-relevant).

## Time slider, epidemic curve, metrics

Drag either end of the onset date slider to narrow or widen the window, or press
play to advance the end date and watch the outbreak grow. The bar chart shows new
cases per week. **Degree** = number of direct links; **Betweenness** = how often
a node bridges otherwise separate clusters.

## Ways to use it

Find hub contexts (large, high-degree), bridge contexts (high betweenness),
and - in the Who visited where view - contexts where infection was likely spread
(red) versus caught (blue). Combine with the epidemic curve to judge the
trajectory and prioritise vaccination, isolation or communication.

## Interpretation

Links are epidemiological connections recorded or inferred during investigation,
not laboratory-proven transmission. See the Assumptions & parameters tab for the
exact definitions and the editable epidemiological parameters.
'

# ---- Assumptions content ----------------------------------------------------
assumptions_md <- '
## Assumptions behind the diagram

This page documents how every link in the tool is defined, and lets you change
the key epidemiological parameters. **Changes update the dashboard immediately.**

### Nodes and edges

- **Context node** - a place where cases were present (school, healthcare centre,
  community group, household).
- **Case node** - an individual confirmed or probable case.
- **Shared-case link (Contexts network view)** - drawn whenever at least one
  case attended both contexts. This is based purely on **co-attendance**; it
  makes no timing assumption. The line weight is the number of shared cases.
- **Visit link (Who visited where view)** - one line per recorded visit of a case to a
  context.

### When is a visit "infectious"?

In the Who visited where view each visit is classified using the **infectious period**:
a visit is marked red when its date falls from *infectious-days-before* to
*infectious-days-after* the case onset — meaning the case was infectious at the
time of the visit. This is a **necessary but not sufficient** condition for
onward transmission: it shows that the case could have been infectious at that
context, but does not confirm that a susceptible person was present or went on
to develop symptoms within the incubation period. Visits outside that window are
shown grey and represent possible exposure to infection (the case may have
acquired infection there). Measles is commonly treated as infectious from about
4 days before to 4 days after rash onset; this is the default and can be changed
below.

### Who infected whom — and the Possible links page

The **Who infected whom** view shows links recorded in the **likely_index_case**
field of the cases table. Each case can name one source — the practitioner\'s
judgement based on the investigation.

The **Possible links** page shows candidate pairs not yet captured by
likely_index_case: cases who shared a context and whose onset gap falls within
the plausible transmission window (defined below). Use it to identify links that
may have been missed.

### The derived-link rule

A susceptible case is exposed during a source case infectious period, then
develops symptoms after the incubation period. So the gap between an earlier
(source) onset and a later (infectee) onset is plausible when it lies between
**(incubation minimum minus infectious-days-before)** and **(incubation maximum
plus infectious-days-after)** days. The tool draws a possible link, from the
earlier to the later case, for every co-attending pair whose onset gap falls in
that window.

### Default parameters (measles, approximate)

- **Incubation period** (exposure to symptom onset): about 7 to 21 days.
- **Infectious period**: about 4 days before to 4 days after onset.

These are typical published ranges and will vary by source, case definition and
jurisdiction. Treat them as starting points and adjust to your local guidance.

### Caveats

Co-attendance and timing make a link **plausible**, not proven - two cases at the
same context in a consistent window may still be unrelated, and true links may be
missing if visits were not recorded. Use the diagram to generate and prioritise
hypotheses, alongside your wider outbreak knowledge.
'

# ---- Timeline helpers -------------------------------------------------------
# The timeline panel shows a Gantt-style chart below the network diagram.
# When the user clicks a node, it renders epi windows and visit dates for
# that case or context. These two helpers are used by the server's renderUI
# to size the panel dynamically before rendering the plotly chart.

# Returns the number of chart rows that will be drawn for a given selection,
# so the container height can be set before the plot renders.
nrow_timeline <- function(sel, f, view = "bipartite") {
  if (view == "contacts" && sel %in% f$cases$case_id) {
    ll <- f$cases
    if (!("likely_index_case" %in% names(ll))) ll$likely_index_case <- NA_character_
    linked_from <- ll$case_id[!is.na(ll$likely_index_case) & ll$likely_index_case == sel]
    linked_to   <- ll$likely_index_case[ll$case_id == sel]
    linked_to   <- linked_to[!is.na(linked_to) & nchar(linked_to) > 0]
    associated  <- unique(c(sel, linked_from, linked_to))
    return(length(associated[associated %in% ll$case_id]))
  }
  if (sel %in% f$cases$case_id)
    return(length(unique(f$visit_dates$context_id[f$visit_dates$case_id == sel])))
  clean  <- sub("^ctx::", "", sel)
  ctx_r  <- f$contexts[f$contexts$context_name == clean, ]
  if (nrow(ctx_r) == 0) return(0L)
  ctx_id <- ctx_r$context_id[1]
  linked <- unique(f$visit_dates$case_id[f$visit_dates$context_id == ctx_id])
  length(linked[linked %in% f$cases$case_id])
}

# Builds the plotly timeline chart for the selected node.
#
# Case selected: one row per context visited. Epi windows (exposure, infectious)
#   and onset line are drawn as full-height background shapes spanning all rows,
#   so they read as single blocks. Visit dots show attendance days per context.
#
# Context selected: one row per case linked to that context. Each case gets its
#   own epi window segments and onset marker (dates differ per case). Visit dots
#   show only days that case attended the selected context.
build_timeline_plot <- function(sel, f, p, view = "bipartite") {
  cases_df <- f$cases; ctx_df <- f$contexts; vd <- f$visit_dates
  is_case  <- sel %in% cases_df$case_id
  clean    <- sub("^ctx::", "", sel)
  is_ctx   <- !is_case && clean %in% ctx_df$context_name
  if (!is_case && !is_ctx) return(plotly_empty())

  if (view == "contacts" && is_case) {
    # ---- Contacts view: case selected -------------------------------------------
    # Rows: selected case + direct transmission neighbours, sorted by onset date.
    # Selected case row highlighted in yellow.
    ll <- cases_df
    if (!("likely_index_case" %in% names(ll))) ll$likely_index_case <- NA_character_
    linked_from <- ll$case_id[!is.na(ll$likely_index_case) & ll$likely_index_case == sel]
    linked_to   <- ll$likely_index_case[ll$case_id == sel]
    linked_to   <- linked_to[!is.na(linked_to) & nchar(linked_to) > 0]
    associated  <- unique(c(sel, linked_from, linked_to))
    associated  <- associated[associated %in% ll$case_id]
    onset_vals  <- setNames(ll$onset_date, ll$case_id)
    associated  <- associated[order(sapply(associated, function(id) onset_vals[[id]]))]
    if (length(associated) == 0) return(plotly_empty())

    segs <- list(); pts <- list(); y_order <- character(0)
    for (cid in associated) {
      onset <- onset_vals[[cid]]
      segs[[paste0(cid, "_exp")]] <- data.frame(
        y_label = cid, x0 = onset - p$inc_max, x1 = onset - p$inc_min,
        seg_type = "Exposure window", stringsAsFactors = FALSE)
      segs[[paste0(cid, "_inf")]] <- data.frame(
        y_label = cid, x0 = onset - p$inf_before, x1 = onset + p$inf_after,
        seg_type = "Infectious period", stringsAsFactors = FALSE)
      pts[[paste0(cid, "_onset")]] <- data.frame(
        y_label = cid, x = onset, pt_type = "Onset date", stringsAsFactors = FALSE)
      y_order <- c(y_order, cid)
    }
    all_segs <- do.call(rbind, segs)
    all_pts  <- do.call(rbind, pts)
    all_segs$x0 <- as.Date(all_segs$x0, origin = "1970-01-01")
    all_segs$x1 <- as.Date(all_segs$x1, origin = "1970-01-01")
    all_pts$x   <- as.Date(all_pts$x,   origin = "1970-01-01")

    sel_pos   <- which(rev(y_order) == sel) - 1L
    highlight <- list(type = "rect", xref = "paper", yref = "y",
      x0 = 0, x1 = 1, y0 = sel_pos - 0.45, y1 = sel_pos + 0.45,
      fillcolor = "rgba(255,230,100,0.35)", line = list(width = 0), layer = "below")

    fig <- plot_ly()
    exp_d <- all_segs[all_segs$seg_type == "Exposure window", ]
    if (nrow(exp_d) > 0)
      fig <- add_segments(fig, data = exp_d,
        x = ~x0, xend = ~x1, y = ~y_label, yend = ~y_label,
        line = list(color = "#aec7e8", width = 14),
        name = "Exposure window", legendgroup = "exp", showlegend = TRUE)
    inf_d <- all_segs[all_segs$seg_type == "Infectious period", ]
    if (nrow(inf_d) > 0)
      fig <- add_segments(fig, data = inf_d,
        x = ~x0, xend = ~x1, y = ~y_label, yend = ~y_label,
        line = list(color = "#fc8d8d", width = 14),
        name = "Infectious period", legendgroup = "inf", showlegend = TRUE)
    onset_d <- all_pts[all_pts$pt_type == "Onset date", ]
    if (nrow(onset_d) > 0)
      fig <- add_markers(fig, data = onset_d, x = ~x, y = ~y_label,
        marker = list(symbol = "line-ns-open", size = 22, color = "#333",
                      line = list(width = 2.5, color = "#333")),
        name = "Onset date", legendgroup = "onset", showlegend = TRUE)

    n_rows <- length(y_order)
    return(fig |> layout(
      height = n_rows * 36L + 130L,
      shapes = list(highlight),
      yaxis  = list(categoryorder = "array", categoryarray = rev(y_order), title = ""),
      xaxis  = list(type = "date", title = "", dtick = 7 * 86400000, tickformat = "%d %b", tickangle = -45,
                   minor = list(dtick = 86400000, showgrid = TRUE, gridcolor = "rgba(0,0,0,0.12)")),
      legend = list(orientation = "h", x = 0, y = -0.25),
      margin = list(l = 80, b = 90)))

  } else if (is_case) {
    # ---- Case selected -------------------------------------------------------
    cr    <- cases_df[cases_df$case_id == sel, ]
    onset <- cr$onset_date[1]

    # Visit dates for this case, joined to context names
    cv <- vd[vd$case_id == sel, ]
    if (nrow(cv) == 0) return(plotly_empty())
    cv <- merge(cv, ctx_df[, c("context_id", "context_name")], by = "context_id")
    # as.Date recovers the Date class lost when merge strips it to numeric
    cv$visit_date <- as.Date(cv$visit_date, origin = "1970-01-01")
    ctx_order <- unique(cv$context_name)

    # Full-height background rectangles for epi windows; vertical dashed line for onset.
    # format() converts Date to ISO string required by plotly shape x coordinates.
    shapes <- list(
      list(type = "rect", xref = "x", yref = "paper",
           x0 = format(onset - p$inc_max,    "%Y-%m-%d"),
           x1 = format(onset - p$inc_min,    "%Y-%m-%d"),
           y0 = 0, y1 = 1, layer = "below",
           fillcolor = "rgba(174,199,232,0.45)", line = list(width = 0)),
      list(type = "rect", xref = "x", yref = "paper",
           x0 = format(onset - p$inf_before, "%Y-%m-%d"),
           x1 = format(onset + p$inf_after,  "%Y-%m-%d"),
           y0 = 0, y1 = 1, layer = "below",
           fillcolor = "rgba(252,141,141,0.45)", line = list(width = 0)),
      list(type = "line", xref = "x", yref = "paper",
           x0 = format(onset, "%Y-%m-%d"), x1 = format(onset, "%Y-%m-%d"),
           y0 = 0, y1 = 1,
           line = list(color = "#333", width = 2, dash = "dash"))
    )

    # Background shapes do not appear in the plotly legend automatically.
    # Empty-data traces (x = numeric(0)) add legend entries without drawing anything.
    fig <- plot_ly() |>
      add_trace(type = "scatter", mode = "markers",
        x = numeric(0), y = character(0),
        marker = list(color = "rgba(174,199,232,0.85)", size = 14, symbol = "square"),
        name = "Exposure window", legendgroup = "exp", showlegend = TRUE) |>
      add_trace(type = "scatter", mode = "markers",
        x = numeric(0), y = character(0),
        marker = list(color = "rgba(252,141,141,0.85)", size = 14, symbol = "square"),
        name = "Infectious period", legendgroup = "inf", showlegend = TRUE) |>
      add_trace(type = "scatter", mode = "markers",
        x = numeric(0), y = character(0),
        marker = list(color = "#333", size = 14, symbol = "line-ns-open",
                      line = list(color = "#333", width = 2)),
        name = "Onset date", legendgroup = "onset", showlegend = TRUE) |>
      add_markers(data = cv, x = ~visit_date, y = ~context_name,
        marker = list(symbol = "circle", size = 9, color = "#636363",
                      line = list(width = 1, color = "#444")),
        name = "Visit date", legendgroup = "visit", showlegend = TRUE)

    n_rows <- length(ctx_order)
    fig |> layout(
      height = n_rows * 36L + 130L,
      shapes = shapes,
      yaxis  = list(categoryorder = "array", categoryarray = rev(ctx_order), title = ""),
      xaxis  = list(type = "date", title = "", dtick = 7 * 86400000, tickformat = "%d %b", tickangle = -45,
                   minor = list(dtick = 86400000, showgrid = TRUE, gridcolor = "rgba(0,0,0,0.12)")),
      legend = list(orientation = "h", x = 0, y = -0.25),
      margin = list(l = 160, b = 90))

  } else {
    # ---- Context selected ----------------------------------------------------
    ctx_r  <- ctx_df[ctx_df$context_name == clean, ]
    ctx_id <- ctx_r$context_id[1]
    linked <- unique(vd$case_id[vd$context_id == ctx_id])
    linked <- linked[linked %in% cases_df$case_id]
    # Sort by onset date so the chart reads chronologically top to bottom
    linked <- linked[order(cases_df$onset_date[match(linked, cases_df$case_id)])]
    if (length(linked) == 0) return(plotly_empty())

    segs    <- list()
    pts     <- list()
    y_order <- character(0)

    for (cid in linked) {
      cr    <- cases_df[cases_df$case_id == cid, ]
      onset <- cr$onset_date[1]
      segs[[paste0(cid, "_exp")]] <- data.frame(
        y_label = cid, x0 = onset - p$inc_max, x1 = onset - p$inc_min,
        seg_type = "Exposure window", stringsAsFactors = FALSE)
      segs[[paste0(cid, "_inf")]] <- data.frame(
        y_label = cid, x0 = onset - p$inf_before, x1 = onset + p$inf_after,
        seg_type = "Infectious period", stringsAsFactors = FALSE)
      pts[[paste0(cid, "_onset")]] <- data.frame(
        y_label = cid, x = onset, pt_type = "Onset date", stringsAsFactors = FALSE)
      # Visit dots only for this context, not all contexts the case visited
      vdates <- sort(unique(vd$visit_date[vd$case_id == cid & vd$context_id == ctx_id]))
      if (length(vdates) > 0)
        pts[[paste0(cid, "_v")]] <- data.frame(
          y_label = cid, x = vdates, pt_type = "Visit date", stringsAsFactors = FALSE)
      y_order <- c(y_order, cid)
    }

    all_segs <- do.call(rbind, segs)
    all_pts  <- do.call(rbind, pts)
    # rbind strips the Date class to numeric; restore with as.Date
    all_segs$x0 <- as.Date(all_segs$x0, origin = "1970-01-01")
    all_segs$x1 <- as.Date(all_segs$x1, origin = "1970-01-01")
    all_pts$x   <- as.Date(all_pts$x,   origin = "1970-01-01")

    fig <- plot_ly()
    exp_d <- all_segs[all_segs$seg_type == "Exposure window", ]
    if (nrow(exp_d) > 0)
      fig <- add_segments(fig, data = exp_d,
        x = ~x0, xend = ~x1, y = ~y_label, yend = ~y_label,
        line = list(color = "#aec7e8", width = 14),
        name = "Exposure window", legendgroup = "exp", showlegend = TRUE)
    inf_d <- all_segs[all_segs$seg_type == "Infectious period", ]
    if (nrow(inf_d) > 0)
      fig <- add_segments(fig, data = inf_d,
        x = ~x0, xend = ~x1, y = ~y_label, yend = ~y_label,
        line = list(color = "#fc8d8d", width = 14),
        name = "Infectious period", legendgroup = "inf", showlegend = TRUE)
    onset_d <- all_pts[all_pts$pt_type == "Onset date", ]
    if (nrow(onset_d) > 0)
      fig <- add_markers(fig, data = onset_d, x = ~x, y = ~y_label,
        marker = list(symbol = "line-ns-open", size = 22, color = "#333",
                      line = list(width = 2.5, color = "#333")),
        name = "Onset date", legendgroup = "onset", showlegend = TRUE)
    visit_d <- all_pts[all_pts$pt_type == "Visit date", ]
    if (nrow(visit_d) > 0)
      fig <- add_markers(fig, data = visit_d, x = ~x, y = ~y_label,
        marker = list(symbol = "circle", size = 9, color = "#636363",
                      line = list(width = 1, color = "#444")),
        name = "Visit date", legendgroup = "visit", showlegend = TRUE)

    n_rows <- length(y_order)
    fig |> layout(
      height = n_rows * 36L + 130L,
      yaxis  = list(categoryorder = "array", categoryarray = rev(y_order), title = ""),
      xaxis  = list(type = "date", title = "", dtick = 7 * 86400000, tickformat = "%d %b", tickangle = -45,
                   minor = list(dtick = 86400000, showgrid = TRUE, gridcolor = "rgba(0,0,0,0.12)")),
      legend = list(orientation = "h", x = 0, y = -0.25),
      margin = list(l = 80, b = 90))
  }
}

# ---- UI ---------------------------------------------------------------------
ui <- page_navbar(
  title = paste0("Network explorer v", APP_VERSION),
  theme = bs_theme(version = 5, bootswatch = "flatly"), id = "nav", selected = "Home",
  header = tags$head(tags$style(HTML("
    .vis-tooltip {
      z-index: 99999 !important;
      max-width: 300px !important;
      white-space: normal !important;
      word-wrap: break-word !important;
      line-height: 1.6 !important;
      padding: 8px 12px !important;
      font-size: 0.88em !important;
    }
    .vis-network {
      overflow: visible !important;
    }
    .network-card,
    .network-card .card-body {
      overflow: visible !important;
    }
    .network-card .card-header select {
      margin-bottom: 0 !important;
    }
    .network-expanded {
      position: fixed !important;
      inset: 0 !important;
      z-index: 9997 !important;
      border-radius: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      display: flex !important;
      flex-direction: column !important;
      overflow: visible !important;
    }
    .network-expanded .card-body {
      flex: 1 !important;
      min-height: 0 !important;
      overflow: visible !important;
    }
    .network-expanded #net {
      height: 100% !important;
    }
    .timeline-expanded {
      position: fixed !important;
      inset: 0 !important;
      z-index: 9998 !important;
      border-radius: 0 !important;
      width: 100vw !important;
      height: 100vh !important;
      display: flex !important;
      flex-direction: column !important;
      overflow: hidden !important;
    }
    .timeline-expanded .card-body {
      flex: 1 !important;
      min-height: 0 !important;
      overflow-y: auto !important;
      padding: 4px !important;
    }
    .timeline-expanded #timeline_body_div {
      max-height: none !important;
      overflow-y: visible !important;
    }
    #node_selector {
      margin-bottom: 0 !important;
      font-size: 0.85em !important;
    }
  ")),
  tags$script(HTML("
    function toggleNetwork() {
      var card = document.querySelector('.network-card');
      var btn  = document.getElementById('net-toggle-btn');
      if (card.classList.toggle('network-expanded')) {
        btn.textContent = 'Minimise';
        document.body.style.overflow = 'hidden';
      } else {
        btn.textContent = 'Maximise';
        document.body.style.overflow = '';
      }
    }
    function toggleTimeline() {
      var card = document.querySelector('.timeline-card');
      var btn  = document.getElementById('timeline_expand_btn');
      if (card.classList.toggle('timeline-expanded')) {
        btn.textContent = 'Collapse';
        document.body.style.overflow = 'hidden';
      } else {
        btn.textContent = 'Expand';
        document.body.style.overflow = '';
      }
    }
  "))),

  nav_panel("Home",
    div(style = "max-width:800px; margin:40px auto; padding:0 16px;",
      card(
        card_header(h4(paste0("Network explorer v", APP_VERSION), class = "mb-0")),
        card_body(
          p("This tool visualises a measles outbreak as an interactive network, showing how cases and places (contexts — such as schools, households, and healthcare settings) are connected. Use it to identify hub contexts, bridge cases, and potential transmission routes."),
          p("Upload your outbreak data below, then navigate to the ", tags$strong("Dashboard"), " tab to explore the network. If no file is uploaded, the tool runs on built-in demo data so you can explore the features straight away."),
          div(class = "alert alert-warning d-flex gap-2", role = "alert",
            tags$strong("Important:"),
            "Do not upload files containing personal identifiable information (PII). Use anonymised or pseudonymised data only — case IDs must not include names, dates of birth, addresses, or NHS numbers."),
          hr(),
          fileInput("file", "Upload outbreak file (.xlsx)", accept = ".xlsx"),
          helpText("The file must contain four sheets: cases, contexts, case_contexts, and visit_dates."),
          actionButton("go_dashboard", "Go to Dashboard →", class = "btn btn-primary mt-2"))))),

  nav_panel("Dashboard",
    layout_sidebar(
      sidebar = sidebar(width = 300,
        helpText("Upload data on the ", tags$strong("Home"), " tab. Demo data is used if no file is loaded."),
        tags$label(class = "form-label mb-0",
          "Filter by onset date",
          info("Filters to cases whose symptom onset falls within this date range. Visit dates are filtered to the same window.")),
        sliderInput("asof", label = NULL, min = Sys.Date() - 60, max = Sys.Date(),
                    value = c(Sys.Date() - 60, Sys.Date()), timeFormat = "%d %b %Y",
                    animate = animationOptions(interval = 900)),
        checkboxGroupInput("types",
          label = tagList("Contexts to include",
            info("Tick or untick to focus on particular kinds of context.")),
          choices = character(0), selected = character(0)),
        checkboxGroupInput("case_status_filter",
          label = tagList("Case status",
            info("Filter by how firmly the case has been classified. Confirmed and Probable are included by default; untick to exclude or tick Possible to include.")),
          choices  = c("Confirmed", "Probable", "Possible"),
          selected = c("Confirmed", "Probable")),
        hr(),
        helpText("See ", strong("Definitions"), ", ", strong("How to use"), " and ",
                 strong("Assumptions & parameters"), " tabs at the top.")),

      card(class = "network-card",
        card_header(class = "d-flex justify-content-between align-items-center",
          span("Network"),
          div(class = "d-flex align-items-center gap-2",
            selectInput("node_selector", NULL, choices = c("-- Select node --" = ""), width = "190px"),
            selectInput("view", NULL, width = "220px",
              choices = c("Contexts network"  = "projection",
                          "Who visited where" = "bipartite",
                          "Who infected whom" = "contacts"),
              selected = "bipartite"),
            tags$button(id = "net-toggle-btn",
              class = "btn btn-sm btn-outline-secondary",
              onclick = "toggleNetwork()", "Maximise"),
            info(paste0("Contexts network links places that share a case. ",
                        "Who visited where shows cases and contexts together. ",
                        "Who infected whom shows transmission links from the likely_index_case field in the cases table. ",
                        "Use the node selector to highlight a node and view its timeline below.")))),
        div(style = "position:relative;",
          uiOutput("network_legend"),
          visNetworkOutput("net", height = "60vh"))),

      card(
        class = "timeline-card",
        card_header(class = "d-flex justify-content-between align-items-center",
          span("Timeline"),
          div(class = "d-flex align-items-center gap-2",
            info("Select a node in the network above to see its timeline. For a case: exposure and infectious windows span all visited contexts as a single block, with dots for each visit day. For a context: one row per linked case showing their individual epi windows and visit dots."),
            tags$button(
              id = "timeline_expand_btn",
              class = "btn btn-outline-secondary btn-sm py-0",
              onclick = "toggleTimeline()",
              "Expand"))),
        card_body(
          padding = 0,
          div(id = "timeline_body_div",
              style = "max-height: 30vh; min-height: 120px; overflow-y: auto; padding: 4px;",
              uiOutput("timeline_container"))))
    )),

  nav_panel("Data",
    div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
      card(hdr("Epidemic curve",
               "New cases per week by onset date. A rising curve means the outbreak is still growing."),
           plotlyOutput("curve", height = "300px")),
      layout_columns(col_widths = c(6, 6),
        card(hdr("Network metrics — most connected nodes",
                 "Ranks nodes by how connected they are. Hover the column headings for definitions."),
             DTOutput("metrics")),
        card(hdr("Line list (filtered)",
                 "Case records currently shown, with how many contexts each visited. Hover headings for definitions."),
             DTOutput("ll"))))),

  nav_panel("Source data",
    div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
      card(hdr("Cases",
               "One row per case. The primary case record — onset date drives the time slider, epidemic curve and infectious-period logic."),
           DTOutput("src_cases")),
      card(hdr("Case contexts",
               "One row per case × context combination. exposure_relevance records the practitioner's judgement on the epi relevance of each link."),
           DTOutput("src_case_contexts")),
      card(hdr("Visit dates",
               "One row per epidemiologically relevant visit date. A single case × context pair can appear on multiple rows here, one per date."),
           DTOutput("src_visit_dates")),
    )),

  nav_panel("Definitions",
    div(style = "max-width:860px; margin:0 auto; padding:8px 4px;",
        card(card_body(markdown(definitions_md))))),

  nav_panel("How to use",
    div(style = "max-width:860px; margin:0 auto; padding:8px 4px;",
        card(card_body(markdown(how_to_use_md))))),

  nav_panel("Assumptions & parameters",
    div(style = "max-width:900px; margin:0 auto; padding:8px 4px;",
      card(card_body(markdown(assumptions_md))),
      card(card_header("Editable parameters - changes update the model live"),
        card_body(
          layout_columns(col_widths = c(6, 6),
            numericInput("inc_min",    "Incubation period – minimum (days, exposure to onset)",
                         DEF_INC_MIN,    min = 1, max = 40, step = 1),
            numericInput("inc_max",    "Incubation period – maximum (days, exposure to onset)",
                         DEF_INC_MAX,    min = 1, max = 40, step = 1),
            numericInput("inf_before", "Infectious period – days before onset",
                         DEF_INF_BEFORE, min = 0, max = 14, step = 1),
            numericInput("inf_after",  "Infectious period – days after onset",
                         DEF_INF_AFTER,  min = 0, max = 14, step = 1)),
          actionButton("reset_params", "Reset to defaults",
                       class = "btn-outline-secondary btn-sm"))))),

  # ---- Reference tab (dev only — remove before release) ----------------------
  nav_panel("Reference",
    div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
      card(
        hdr("Schema diagram",
            "Entity-relationship diagram. Underlined fields are primary keys."),
        card_body(
          p(class = "text-muted",
            "Schema diagram available in ", tags$code("docs/erd.svg"), " in the project repository.")
        )
      ),
      card(
        hdr("Data dictionary", "Field-level definitions for all tables in the workbook."),
        card_body(
          navset_tab(
            nav_panel("cases",         DTOutput("dict_cases")),
            nav_panel("contexts",      DTOutput("dict_contexts")),
            nav_panel("case_contexts", DTOutput("dict_case_contexts")),
            nav_panel("visit_dates",   DTOutput("dict_visit_dates"))
          )
        )
      )
    )
  ),

  nav_panel("Possible links",
    div(style = "max-width:1200px; margin:0 auto; padding:8px 4px;",
      card(card_body(
        p("Candidate case-to-case links derived from shared contexts and onset timing, using the epi parameters on the ",
          tags$strong("Assumptions & parameters"), " tab. Only pairs ",
          tags$strong("not already captured by the likely_index_case field"), " are shown."),
        p(class = "text-muted mb-0",
          "Use the table below to assess each candidate. Recording an accepted link is done by updating ",
          tags$code("likely_index_case"), " in your data."))),
      card(hdr("Candidate network",
               "Possible undetected links shown as orange dashed arrows. Node colour = primary context type."),
           visNetworkOutput("possible_links_net", height = "40vh")),
      card(hdr("Assessment table",
               "One row per candidate pair. Sortable and filterable. Use exposure_relevance to judge plausibility — pairs where neither case has a relevant classification at the shared context are weaker candidates."),
           DTOutput("possible_links_table")))),

  nav_spacer(),
  nav_item(tags$span(style = "color:#888; font-size:0.85em;", paste0("Measles outbreak explorer v", APP_VERSION)))
)

# ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  # ---- Reactive data chain --------------------------------------------------
  # Data flows through three chained reactives:
  #   raw()      — loads once from file or demo data; invalidates only when a new file is uploaded
  #   filtered() — applies the sidebar filters (date range, context types, case status)
  #   netdata()  — builds the nodes/edges for the currently selected network view
  # Keeping these separate means parameter changes (inc_min etc.) only re-run
  # netdata(), not the file read or filtering.

  # raw(): reads and validates the uploaded Excel file, or returns demo data.
  # validate() stops execution and shows a user-facing error message if checks fail.
  raw <- reactive({
    if (is.null(input$file)) return(make_demo_data())

    sheets <- readxl::excel_sheets(input$file$datapath)

    # Helper: format a list of IDs for error messages, capped at 5
    fmt_ids <- function(ids) {
      if (length(ids) <= 5) paste(ids, collapse = ", ")
      else paste0(paste(head(ids, 5), collapse = ", "), " … and ", length(ids) - 5, " more")
    }

    # Check required sheets exist before attempting to read
    missing_sheets <- setdiff(c("cases", "contexts", "case_contexts", "visit_dates"), sheets)
    shiny::validate(
      need(length(missing_sheets) == 0,
           paste0("The uploaded file is missing required sheet(s): ",
                  paste(missing_sheets, collapse = ", "), ". ",
                  "The sheet tab names must match exactly (they are case-sensitive). ",
                  "Expected tabs: cases, contexts, case_contexts, visit_dates ",
                  "Re-download the template if unsure."))
    )

    # Read the four required sheets; convert date columns that Excel may have
    # stored as numeric serial numbers rather than formatted dates
    cs  <- readxl::read_excel(input$file$datapath, sheet = "cases")
    st  <- readxl::read_excel(input$file$datapath, sheet = "contexts")
    cst <- readxl::read_excel(input$file$datapath, sheet = "case_contexts")
    vd  <- readxl::read_excel(input$file$datapath, sheet = "visit_dates")
    cs$onset_date <- as.Date(cs$onset_date)
    vd$visit_date <- as.Date(vd$visit_date)
    # Check required columns in each sheet
    miss_cs  <- setdiff(c("case_id", "onset_date"), names(cs))
    miss_st  <- setdiff(c("context_id", "context_name", "context_type"), names(st))
    miss_cst <- setdiff(c("case_id", "context_id"), names(cst))
    miss_vd  <- setdiff(c("case_id", "context_id", "visit_date"), names(vd))
    shiny::validate(
      need(length(miss_cs) == 0,
           paste0("The 'cases' sheet is missing column(s): ",
                  paste(miss_cs, collapse = ", "), ". ",
                  "Required columns are case_id and onset_date. ",
                  "Check the column headers in row 1 match exactly — they are case-sensitive.")),
      need(length(miss_st) == 0,
           paste0("The 'contexts' sheet is missing column(s): ",
                  paste(miss_st, collapse = ", "), ". ",
                  "Required columns are context_id, context_name and context_type. ",
                  "Check the column headers in row 1 match exactly — they are case-sensitive.")),
      need(length(miss_cst) == 0,
           paste0("The 'case_contexts' sheet is missing column(s): ",
                  paste(miss_cst, collapse = ", "), ". ",
                  "Required columns are case_id and context_id. ",
                  "Check the column headers in row 1 match exactly — they are case-sensitive.")),
      need(length(miss_vd) == 0,
           paste0("The 'visit_dates' sheet is missing column(s): ",
                  paste(miss_vd, collapse = ", "), ". ",
                  "Required columns are case_id, context_id and visit_date. ",
                  "Check the column headers in row 1 match exactly — they are case-sensitive."))
    )

    # FK integrity checks
    bad_case_cst  <- setdiff(unique(cst$case_id),    unique(cs$case_id))
    bad_ctx_cst   <- setdiff(unique(cst$context_id), unique(st$context_id))
    bad_case_vd   <- setdiff(unique(vd$case_id),     unique(cs$case_id))
    bad_ctx_vd    <- setdiff(unique(vd$context_id),  unique(st$context_id))
    shiny::validate(
      need(length(bad_case_cst) == 0,
           paste0("The 'case_contexts' sheet contains case_id value(s) not found in 'cases': ",
                  fmt_ids(bad_case_cst), ". ",
                  "Every case_id in case_contexts must match a case_id in the cases sheet. ",
                  "Check for typos, or add the missing cases to the cases sheet first.")),
      need(length(bad_ctx_cst) == 0,
           paste0("The 'case_contexts' sheet contains context_id value(s) not found in 'contexts': ",
                  fmt_ids(bad_ctx_cst), ". ",
                  "Every context_id in case_contexts must match a context_id in the contexts sheet. ",
                  "Check for typos, or add the missing contexts to the contexts sheet first.")),
      need(length(bad_case_vd) == 0,
           paste0("The 'visit_dates' sheet contains case_id value(s) not found in 'cases': ",
                  fmt_ids(bad_case_vd), ". ",
                  "Every case_id in visit_dates must match a case_id in the cases sheet. ",
                  "Check for typos, or add the missing cases to the cases sheet first.")),
      need(length(bad_ctx_vd) == 0,
           paste0("The 'visit_dates' sheet contains context_id value(s) not found in 'contexts': ",
                  fmt_ids(bad_ctx_vd), ". ",
                  "Every context_id in visit_dates must match a context_id in the contexts sheet. ",
                  "Check for typos, or add the missing contexts to the contexts sheet first."))
    )

    list(cases = cs, contexts = st, case_contexts = cst, visit_dates = vd)
  })

  # When new data loads, reset the date slider to span the full dataset date range
  # and rebuild the context type and case status filter checkboxes from the data.
  observeEvent(raw(), {
    d    <- raw()
    rng  <- range(c(d$cases$onset_date, d$visit_dates$visit_date), na.rm = TRUE)
    updateSliderInput(session, "asof", min = rng[1], max = rng[2], value = c(rng[1], rng[2]))
    types <- unique(d$contexts$context_type)
    updateCheckboxGroupInput(session, "types", choices = types, selected = types)
    # Only show case statuses that actually appear in this dataset
    statuses <- if ("case_status" %in% names(d$cases))
      intersect(c("Confirmed","Probable","Possible"), unique(d$cases$case_status))
    else c("Confirmed","Probable","Possible")
    updateCheckboxGroupInput(session, "case_status_filter",
      choices = statuses, selected = intersect(statuses, c("Confirmed","Probable")))
  })

  # params(): collects the four epi parameter inputs into a named list.
  # Falls back to defaults if any input is NULL or NA (e.g. cleared by user).
  params <- reactive({
    g <- function(x, d) if (is.null(x) || is.na(x)) d else x
    list(inc_min    = g(input$inc_min,    DEF_INC_MIN),
         inc_max    = g(input$inc_max,    DEF_INC_MAX),
         inf_before = g(input$inf_before, DEF_INF_BEFORE),
         inf_after  = g(input$inf_after,  DEF_INF_AFTER))
  })

  # Restores all four parameter inputs and the possible-link source to their defaults
  observeEvent(input$reset_params, {
    updateNumericInput(session, "inc_min",    value = DEF_INC_MIN)
    updateNumericInput(session, "inc_max",    value = DEF_INC_MAX)
    updateNumericInput(session, "inf_before", value = DEF_INF_BEFORE)
    updateNumericInput(session, "inf_after",  value = DEF_INF_AFTER)
  })

  observeEvent(input$go_dashboard, {
    nav_select("nav", "Dashboard")
  })

  # filtered(): applies the sidebar controls to all five tables.
  # Filter order matters: cases are filtered first by date and status, then
  # case_contexts is filtered to those cases and selected context types,
  # then contexts is trimmed to only those still in case_contexts. This cascade
  # ensures no orphaned nodes appear in the network.
  filtered <- reactive({
    d         <- raw()
    # If types checkbox is empty (race condition on data load), show all context types
    types_sel <- if (length(input$types) == 0) unique(d$contexts$context_type) else input$types
    cs  <- d$cases |> filter(onset_date >= input$asof[1], onset_date <= input$asof[2])
    if ("case_status" %in% names(cs))
      cs <- cs |> filter(is.na(case_status) | case_status %in% input$case_status_filter)
    st  <- d$contexts |> filter(context_type %in% types_sel)
    cst <- d$case_contexts |> filter(case_id %in% cs$case_id, context_id %in% st$context_id)
    st  <- st |> filter(context_id %in% cst$context_id)
    vd  <- d$visit_dates |> filter(case_id %in% cs$case_id, context_id %in% cst$context_id)
    list(cases = cs, contexts = st, case_contexts = cst, visit_dates = vd)
  })

  # filtered(): applies the three sidebar filters to all five tables in sequence.
  # Context filtering cascades: filter cases → filter case_contexts to those cases
  # → filter contexts to those that still have linked cases.
  # This ensures the network only shows contexts with at least one visible case.

  # netdata(): flattens the tables, assigns colours, then calls the appropriate
  # view builder. exposure_relevance is read directly from case_contexts.
  # The contacts view reads likely_index_case from cases; possible links page
  # from shared contexts + timing, depending on the user's radio button choice.
  netdata <- reactive({
    f    <- filtered()
    p    <- params()
    fv   <- flat_visits(f)
    cols <- colour_map(f$contexts$context_type)
    switch(input$view,
      projection = build_context_projection(fv, f$cases, cols),
      bipartite  = build_bipartite(fv, f$cases, cols),
      contacts   = build_transmission_network(f$cases, fv, cols))
  })

  # Renders the network diagram. exposure_relevance is dropped from edges before
  # passing to visNetwork (it was only needed for colour/arrow assignment).
  # Node clicks fire a JS event that updates input$node_selector (the toolbar dropdown),
  # which drives the timeline panel below.
  output$net <- renderVisNetwork({
    nd <- netdata(); v <- input$view
    vis_edges <- if ("exposure_relevance" %in% names(nd$edges))
      nd$edges |> select(-exposure_relevance) else nd$edges
    vn <- visNetwork(nd$nodes, vis_edges) |>
      visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)) |>
      visPhysics(stabilization = TRUE,
                 barnesHut = list(gravitationalConstant = -3500, springLength = 130)) |>
      visEvents(click = "function(params) {
        var node = params.nodes.length > 0 ? String(params.nodes[0]) : '';
        Shiny.setInputValue('net_node_clicked', {node: node, ts: new Date().getTime()}, {priority: 'event'});
      }")
    # Edge style differs by view: contacts uses directional arrows; bipartite
    # uses straight lines (arrows already encoded per-edge); projection uses
    # grey semi-transparent curves
    vn <- if (v == "contacts") visEdges(vn, arrows = "to", smooth = TRUE)
          else if (v == "bipartite") visEdges(vn, smooth = FALSE)
          else visEdges(vn, smooth = TRUE, color = list(color = "#9aa0a6", opacity = 0.7))
    vn
  })

  # ---- Node selector (toolbar dropdown) -------------------------------------
  # Update node selector choices whenever the network data changes.
  # Resets selection to blank so a stale node from the previous view is not shown.
  observe({
    nd  <- netdata()
    lbl <- if ("label" %in% names(nd$nodes))
      ifelse(nd$nodes$label == "" | is.na(nd$nodes$label), nd$nodes$id, nd$nodes$label)
    else nd$nodes$id
    choices <- c("-- Select node --" = "", setNames(nd$nodes$id, lbl))
    updateSelectInput(session, "node_selector", choices = choices, selected = "")
  })

  # Canvas click → update the toolbar dropdown (visual sync)
  observeEvent(input$net_node_clicked, {
    updateSelectInput(session, "node_selector", selected = input$net_node_clicked$node)
  }, ignoreInit = TRUE)

  # Toolbar dropdown change → highlight node in canvas
  observeEvent(input$node_selector, {
    sel <- input$node_selector
    if (!is.null(sel) && nchar(trimws(sel)) > 0)
      visNetworkProxy("net") |> visSelectNodes(id = list(sel))
  }, ignoreInit = TRUE)

  # Combined legend overlay: context type colours (all views) plus bipartite
  # edge direction key (bipartite view only). Floats over the canvas so the
  # network fills the full card width.
  output$network_legend <- renderUI({
    f <- filtered(); v <- input$view
    cols  <- colour_map(f$contexts$context_type)
    is_bip <- v == "bipartite"

    make_dot <- function(label, colour, square = FALSE)
      div(style = "display:flex; align-items:center; gap:6px; margin-bottom:3px;",
        tags$span(style = paste0(
          "width:12px; height:12px; flex-shrink:0; background:", colour, ";",
          "border-radius:", if (square) "2px" else "50%", ";")),
        tags$span(label, style = "font-size:0.78em; line-height:1.3;"))

    ctx_items <- lapply(names(cols), function(s) make_dot(s, unname(cols[[s]]), square = is_bip))
    if (is_bip)
      ctx_items <- c(ctx_items, list(make_dot("Case", CASE_COLOUR, square = FALSE)))

    edge_items <- if (is_bip) list(
      tags$hr(style = "margin:5px 0;"),
      tags$span(leg_arrow("#d62728", "right"),
        tags$span("Infectious period", style = "font-size:0.78em;")), tags$br(),
      tags$span(leg_arrow("#1f77b4", "left"),
        tags$span("Exposure window",  style = "font-size:0.78em;")), tags$br(),
      tags$span(leg_arrow("#9467bd", "both"),
        tags$span("Both windows",     style = "font-size:0.78em;")), tags$br(),
      tags$span(leg_arrow("#9aa0a6", dashed = TRUE),
        tags$span("Outside both",     style = "font-size:0.78em;"))
    ) else NULL

    div(style = paste0(
          "position:absolute; top:48px; left:8px; z-index:100;",
          "background:rgba(255,255,255,0.92); border:1px solid #dee2e6;",
          "border-radius:4px; padding:6px 10px; pointer-events:none;"),
      do.call(tagList, ctx_items),
      if (!is.null(edge_items)) do.call(tagList, edge_items))
  })

  output$curve   <- renderPlotly({ epi_curve(filtered()$cases) })

  output$metrics <- renderDT({
    mt   <- network_metrics(netdata()$nodes, netdata()$edges)
    # Map column names to tooltip text using the lookup defined above
    tips <- vapply(names(mt),
                   function(n) if (n %in% names(metric_tips_lookup)) metric_tips_lookup[[n]] else "", character(1))
    datatable(mt, rownames = FALSE,
              options = list(pageLength = 8, dom = "tp", headerCallback = header_tooltips(unname(tips))))
  })

  # Shared DT options for the Source data tab tables: filterable, paginated, scrollable
  src_dt <- function(df) datatable(df, rownames = FALSE, filter = "top",
    options = list(pageLength = 15, scrollX = TRUE, dom = "lftip"))

  output$src_cases         <- renderDT({ src_dt(raw()$cases) })
  output$src_case_contexts <- renderDT({ src_dt(raw()$case_contexts) })
  output$src_visit_dates   <- renderDT({ src_dt(raw()$visit_dates) })

  # ---- Possible links page --------------------------------------------------
  # Derives candidate pairs from shared contexts + timing, excludes pairs
  # already captured by likely_index_case, and enriches with case/context data.
  possible_links_data <- reactive({
    f  <- filtered()
    p  <- params()
    fv <- flat_visits(f)
    ll <- f$cases
    if (!("likely_index_case" %in% names(ll)))
      ll <- ll |> mutate(likely_index_case = NA_character_)

    known_keys <- ll |>
      filter(!is.na(likely_index_case) & nchar(likely_index_case) > 0) |>
      mutate(key = paste(likely_index_case, case_id)) |>
      pull(key)

    candidates <- derive_possible_links(ll, fv, p$inc_min, p$inc_max, p$inf_before, p$inf_after)
    if (nrow(candidates) == 0) return(tibble())

    candidates <- candidates |>
      filter(!paste(from, to) %in% known_keys)
    if (nrow(candidates) == 0) return(tibble())

    onset <- setNames(ll$onset_date, ll$case_id)
    # Ensure optional columns exist so the downstream select/rename logic is
    # unconditional regardless of what the uploaded file contained.
    for (col in c("age_group", "vaccination_status", "case_status"))
      if (!col %in% names(ll)) ll[[col]] <- NA_character_
    case_info <- ll |> select(case_id, onset_date, age_group, vaccination_status, case_status)
    ctx_tbl   <- fv |> select(case_id, context_name, context_type, exposure_relevance) |> distinct()

    ctx_rows <- purrr::map2_dfr(candidates$from, candidates$to, function(f_id, t_id) {
      fc <- ctx_tbl |> filter(case_id == f_id)
      tc <- ctx_tbl |> filter(case_id == t_id)
      shared <- inner_join(fc, tc, by = c("context_name", "context_type"), suffix = c("_from", "_to"))
      if (nrow(shared) == 0)
        tibble(from = f_id, to = t_id, shared_contexts = "—",
               context_types = "—", source_relevance = "—", case_relevance = "—")
      else
        tibble(from = f_id, to = t_id,
               shared_contexts  = paste(shared$context_name,         collapse = "; "),
               context_types    = paste(shared$context_type,         collapse = "; "),
               source_relevance = paste(shared$exposure_relevance_from, collapse = "; "),
               case_relevance   = paste(shared$exposure_relevance_to,   collapse = "; "))
    })

    candidates |>
      mutate(gap_days = as.integer(as.Date(onset[to]) - as.Date(onset[from]))) |>
      left_join(case_info, by = c("from" = "case_id")) |>
      rename(source_onset = onset_date, source_age    = age_group,
             source_vacc  = vaccination_status, source_status = case_status) |>
      left_join(case_info, by = c("to" = "case_id")) |>
      rename(case_onset = onset_date, case_age    = age_group,
             case_vacc  = vaccination_status, case_status = case_status) |>
      left_join(ctx_rows, by = c("from", "to")) |>
      select(-link_type)
  })

  output$possible_links_table <- renderDT({
    d <- possible_links_data()
    if (nrow(d) == 0)
      return(datatable(
        data.frame(Message = "No undetected possible links with current filters and parameters."),
        rownames = FALSE, options = list(dom = "t")))
    display <- d |> transmute(
      `Possible source`    = from,
      `Possible case`      = to,
      `Source onset`       = source_onset,
      `Case onset`         = case_onset,
      `Gap (days)`         = gap_days,
      `Shared context(s)`  = shared_contexts,
      `Context type(s)`    = context_types,
      `Source relevance`   = source_relevance,
      `Case relevance`     = case_relevance,
      `Source age group`   = source_age,
      `Case age group`     = case_age,
      `Source vaccination` = source_vacc,
      `Case vaccination`   = case_vacc,
      `Source status`      = source_status,
      `Case status`        = case_status)
    datatable(display, rownames = FALSE, filter = "top",
              options = list(pageLength = 15, scrollX = TRUE, dom = "lftip"))
  })

  output$possible_links_net <- renderVisNetwork({
    d    <- possible_links_data()
    f    <- filtered()
    fv   <- flat_visits(f)
    cols <- colour_map(f$contexts$context_type)
    nd   <- build_possible_net(f$cases, d, fv, cols)
    if (nrow(nd$nodes) == 0)
      return(visNetwork(
        tibble(id = "x", label = "No possible links found"),
        tibble(from = character(), to = character())) |>
        visOptions(nodesIdSelection = FALSE))
    visNetwork(nd$nodes, nd$edges) |>
      visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)) |>
      visEdges(arrows = "to", smooth = TRUE) |>
      visPhysics(stabilization = TRUE,
                 barnesHut = list(gravitationalConstant = -3500, springLength = 130))
  })

  # Line list: filtered cases with a count of how many contexts each case visited
  output$ll <- renderDT({
    f  <- filtered()
    nv <- f$case_contexts |> distinct(case_id, context_id) |> count(case_id, name = "contexts_visited")
    df <- f$cases |> left_join(nv, by = "case_id") |>
      mutate(contexts_visited = tidyr::replace_na(contexts_visited, 0L))
    tips <- vapply(names(df),
                   function(n) if (n %in% names(ll_tips_lookup)) ll_tips_lookup[[n]] else "", character(1))
    datatable(df, rownames = FALSE,
              options = list(pageLength = 6, scrollX = TRUE, dom = "tp",
                             headerCallback = header_tooltips(unname(tips))))
  })

  # Timeline panel: placeholder when nothing selected, otherwise a heading + plotlyOutput
  # sized to fit its content. Scrolls when the chart is taller than the 30vh max-height.
  output$timeline_container <- renderUI({
    sel  <- input$node_selector
    view <- input$view
    if (is.null(sel) || nchar(trimws(sel)) == 0)
      return(div(style = "padding:32px; text-align:center; color:#888; font-size:0.9em;",
                 "Click a node in the network above — or use the node selector — to see its timeline here."))
    f      <- filtered()
    n_rows <- nrow_timeline(sel, f, view)
    if (n_rows == 0)
      return(div(style = "padding:20px; color:#888;", "No timeline data available for this node."))
    is_case <- sel %in% f$cases$case_id
    clean   <- sub("^ctx::", "", sel)
    heading <- if (view == "contacts" && is_case)
      paste0("Cases linked to ", sel)
    else if (is_case)
      paste0("Contexts visited by ", sel)
    else
      paste0("Cases associated with ", clean)
    tagList(
      div(style = "padding:6px 8px 4px; font-weight:600; font-size:0.88em; color:#333; border-bottom:1px solid #dee2e6; margin-bottom:2px;",
          heading),
      plotlyOutput("timeline_plot", height = paste0(max(150L, n_rows * 36L + 130L), "px")))
  })

  output$timeline_plot <- renderPlotly({
    sel  <- input$node_selector
    view <- input$view
    req(!is.null(sel) && nchar(trimws(sel)) > 0)
    build_timeline_plot(sel, filtered(), params(), view)
  })

  # ---- Reference tab outputs --------------------------------------------------
  dict_dt <- function(tbl)
    datatable(tbl, rownames = FALSE, escape = FALSE,
              options = list(dom = "t", pageLength = 20, ordering = FALSE,
                             columnDefs = list(list(width = "45%", targets = 4))))

  output$dict_cases         <- renderDT({ dict_dt(DICT_TABLES$cases) })
  output$dict_contexts      <- renderDT({ dict_dt(DICT_TABLES$contexts) })
  output$dict_case_contexts <- renderDT({ dict_dt(DICT_TABLES$case_contexts) })
  output$dict_visit_dates   <- renderDT({ dict_dt(DICT_TABLES$visit_dates) })

}

shinyApp(ui, server)
