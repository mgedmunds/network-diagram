# =============================================================================
# Measles Outbreak Network Explorer
# -----------------------------------------------------------------------------
# Interactive R Shiny dashboard for visualising a measles outbreak across
# settings, handling cases that visit MULTIPLE settings (case x setting
# affiliation / bipartite network). Key epidemiological parameters (incubation
# and infectious periods) are editable on the "Assumptions & parameters" tab and
# update the model live.
#
# Views:
# 1. Settings <-> settings (shared cases) -- bipartite projection onto settings
# 2. Cases x settings (bipartite) -- shows multi-setting cases directly
# 3. Case-to-case (transmission links) -- from the contacts sheet OR derived
#    from shared settings + timing
#
# TO RUN:
# install.packages(c("shiny","bslib","visNetwork","dplyr","tidyr",
#                    "lubridate","igraph","plotly","DT","purrr","tibble",
#                    "jsonlite"))
# shiny::runApp("app.R")
# =============================================================================

library(shiny)
library(bslib)
library(visNetwork)
library(dplyr)
library(tidyr)
library(lubridate)
library(igraph)
library(plotly)
library(DT)
library(purrr)
library(tibble)
library(jsonlite)
library(DiagrammeR)   # ERD diagram in Reference tab (new dependency)

# ---- Configuration ----------------------------------------------------------
# 10 perceptually distinct colours (D3 category10). Assigned in order to whatever
# setting types appear in the loaded data — no types are pre-coded.
SETTING_PALETTE <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
  "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"
)
CASE_COLOUR <- "#444444"

colour_map <- function(types) {
  types <- unique(types[!is.na(types)])
  setNames(SETTING_PALETTE[(seq_along(types) - 1L) %% length(SETTING_PALETTE) + 1L], types)
}

# Default epidemiological parameters (measles, approximate). All editable in-app.
DEF_INC_MIN   <- 7   # incubation, exposure -> onset, minimum (days)
DEF_INC_MAX   <- 21  # incubation, exposure -> onset, maximum (days)
DEF_INF_BEFORE <- 4  # infectious period: days before onset
DEF_INF_AFTER  <- 4  # infectious period: days after onset

# ---- UI helpers -------------------------------------------------------------
info <- function(msg) {
  tooltip(span(style = "cursor:help; color:#2c7fb8; font-weight:bold; margin-left:4px;", "ⓘ"),
          msg, placement = "right")
}
hdr <- function(title, msg) {
  card_header(class = "d-flex justify-content-between align-items-center",
              span(title), info(msg))
}
# Inline SVG arrow for the bipartite legend. direction: "right", "left", "both", or "none".
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
ERD_GRAPHVIZ <- '
digraph erd {
  graph [rankdir=TB fontname="Helvetica" fontsize=11 bgcolor="white"
         pad="0.5" nodesep="1.0" ranksep="0.8"]
  node  [fontname="Helvetica" fontsize=10 shape=plaintext]
  edge  [fontname="Helvetica" fontsize=9 color="#555555"
         arrowhead=crow arrowtail=tee dir=both]

  { rank=same; CASES; SETTINGS }
  { rank=same; VISIT_DATES; CONTACTS }

  CASES [label=<
    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <TR><TD COLSPAN="3" BGCOLOR="#2c7fb8" ALIGN="CENTER"><FONT COLOR="white"><B> cases </B></FONT></TD></TR>
      <TR><TD ALIGN="LEFT"><U>case_id</U></TD><TD ALIGN="LEFT">character</TD><TD>PK</TD></TR>
      <TR><TD ALIGN="LEFT">onset_date</TD><TD ALIGN="LEFT">date</TD><TD>required</TD></TR>
      <TR><TD ALIGN="LEFT">age_group</TD><TD ALIGN="LEFT">character</TD><TD> </TD></TR>
      <TR><TD ALIGN="LEFT">vaccination_status</TD><TD ALIGN="LEFT">character</TD><TD> </TD></TR>
      <TR><TD ALIGN="LEFT">case_status</TD><TD ALIGN="LEFT">character</TD><TD> </TD></TR>
    </TABLE>>]

  SETTINGS [label=<
    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <TR><TD COLSPAN="3" BGCOLOR="#31a354" ALIGN="CENTER"><FONT COLOR="white"><B> settings </B></FONT></TD></TR>
      <TR><TD ALIGN="LEFT"><U>setting_id</U></TD><TD ALIGN="LEFT">integer</TD><TD>PK</TD></TR>
      <TR><TD ALIGN="LEFT">setting_name</TD><TD ALIGN="LEFT">character</TD><TD>required</TD></TR>
      <TR><TD ALIGN="LEFT">setting_type</TD><TD ALIGN="LEFT">character</TD><TD>required</TD></TR>
    </TABLE>>]

  CASE_SETTINGS [label=<
    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <TR><TD COLSPAN="3" BGCOLOR="#e6550d" ALIGN="CENTER"><FONT COLOR="white"><B> case_settings </B></FONT></TD></TR>
      <TR><TD ALIGN="LEFT"><U>case_id</U></TD><TD ALIGN="LEFT">character</TD><TD>PK + FK</TD></TR>
      <TR><TD ALIGN="LEFT"><U>setting_id</U></TD><TD ALIGN="LEFT">integer</TD><TD>PK + FK</TD></TR>
      <TR><TD ALIGN="LEFT">has_other_visits</TD><TD ALIGN="LEFT">logical</TD><TD> </TD></TR>
    </TABLE>>]

  VISIT_DATES [label=<
    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <TR><TD COLSPAN="3" BGCOLOR="#756bb1" ALIGN="CENTER"><FONT COLOR="white"><B> visit_dates </B></FONT></TD></TR>
      <TR><TD ALIGN="LEFT"><U>case_id</U></TD><TD ALIGN="LEFT">character</TD><TD>PK + FK</TD></TR>
      <TR><TD ALIGN="LEFT"><U>setting_id</U></TD><TD ALIGN="LEFT">integer</TD><TD>PK + FK</TD></TR>
      <TR><TD ALIGN="LEFT"><U>visit_date</U></TD><TD ALIGN="LEFT">date</TD><TD>PK</TD></TR>
      <TR><TD ALIGN="LEFT"><I>epi_category</I></TD><TD ALIGN="LEFT"><I>character</I></TD><TD><I>derived</I></TD></TR>
    </TABLE>>]

  CONTACTS [label=<
    <TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0">
      <TR><TD COLSPAN="3" BGCOLOR="#de2d26" ALIGN="CENTER"><FONT COLOR="white"><B> contacts </B></FONT></TD></TR>
      <TR><TD ALIGN="LEFT">from</TD><TD ALIGN="LEFT">character</TD><TD>FK</TD></TR>
      <TR><TD ALIGN="LEFT">to</TD><TD ALIGN="LEFT">character</TD><TD>FK</TD></TR>
      <TR><TD ALIGN="LEFT">link_type</TD><TD ALIGN="LEFT">character</TD><TD>required</TD></TR>
    </TABLE>>]

  CASES         -> CASE_SETTINGS [label=" 1:N "]
  SETTINGS      -> CASE_SETTINGS [label=" 1:N "]
  CASE_SETTINGS -> VISIT_DATES   [label=" 1:N "]
  CASES         -> CONTACTS      [label=" 1:N\n(from + to) " style=dashed]
}
'

# Auto-export ERD to docs/ whenever the app file is sourced (soft dep on DiagrammeRsvg)
tryCatch({
  if (requireNamespace("DiagrammeRsvg", quietly = TRUE))
    writeLines(DiagrammeRsvg::export_svg(grViz(ERD_GRAPHVIZ)), "docs/erd.svg")
}, error = function(e) NULL)

DICT_TABLES <- list(
  cases = tibble::tribble(
    ~Field,                ~Type,       ~Key,  ~Required, ~Description,
    "case_id",             "character", "PK",  "Yes",     "Unique case identifier. Join key across all tables. Must be unique within the dataset.",
    "onset_date",          "date",      "—",   "Yes",     "Symptom onset date. Drives the time slider, epidemic curve, and all epi-period derivations (exposure window, infectious period).",
    "age_group",           "character", "—",   "No",      "Age band. Fixed values: &lt;1 year, 1–4 years, 5–17 years, 18–29 years, 30–49 years, 50+ years. Aligned with UKHSA reporting and vaccination schedule milestones.",
    "vaccination_status",  "character", "—",   "No",      "Measles vaccination history at time of illness. Values: Unvaccinated, 1 dose, 2 doses, Unknown.",
    "case_status",         "character", "—",   "No",      "Classification of the case. Values: Confirmed, Probable, Possible. Definition pending."
  ),
  settings = tibble::tribble(
    ~Field,          ~Type,       ~Key,  ~Required, ~Description,
    "setting_id",    "integer",   "PK",  "Yes",     "Surrogate primary key. Unique integer assigned to each setting. Used as the join key in case_settings and visit_dates.",
    "setting_name",  "character", "—",   "Yes",     "Human-readable name for the setting. Free text; should be unique within the dataset.",
    "setting_type",  "character", "—",   "Yes",     "User-defined categorical label (e.g. School, Household). Not pre-coded — values come from the data. Drives node colour and the setting-type filter."
  ),
  case_settings = tibble::tribble(
    ~Field,              ~Type,       ~Key,       ~Required, ~Description,
    "case_id",           "character", "PK + FK",  "Yes",     "Composite primary key. FK to cases.case_id.",
    "setting_id",        "integer",   "PK + FK",  "Yes",     "Composite primary key. FK to settings.setting_id.",
    "has_other_visits",  "logical",   "—",        "No",      "TRUE if the case visited this setting on dates outside all epi windows (e.g. routine household residence). Specific dates for those visits are not recorded in visit_dates."
  ),
  visit_dates = tibble::tribble(
    ~Field,           ~Type,       ~Key,        ~Required, ~Description,
    "case_id",        "character", "PK + FK",   "Yes",     "Composite primary key. FK to case_settings.case_id.",
    "setting_id",     "integer",   "PK + FK",   "Yes",     "Composite primary key. FK to case_settings.setting_id.",
    "visit_date",     "date",      "PK",        "Yes",     "Date of an epi-relevant visit. One row per calendar day per case-setting pair.",
    "epi_category",   "character", "(derived)", "—",       "<i>Not stored. Computed at runtime</i> from visit_date vs onset_date using current parameters.<br><b>Exposure window:</b> onset &minus; inc_max &le; date &le; onset &minus; inc_min<br><b>Infectious period:</b> onset &minus; inf_before &le; date &le; onset + inf_after<br><b>Both:</b> dates span both windows across the case&ndash;setting pair (e.g. household resident)<br><b>Neither:</b> date outside all windows. Recalculates automatically when parameters change."
  ),
  contacts = tibble::tribble(
    ~Field,       ~Type,       ~Key,  ~Required, ~Description,
    "from",       "character", "FK",  "Yes",     "Source case. FK to cases.case_id.",
    "to",         "character", "FK",  "Yes",     "Recipient case. FK to cases.case_id.",
    "link_type",  "character", "—",   "Yes",     "Strength of evidence: <b>Confirmed</b> (epidemiologically established) or <b>Suspected</b> (plausible based on timing and shared setting)."
  )
)

# ---- Demo data --------------------------------------------------------------
make_demo_data <- function() {
  set.seed(42)
  all_settings <- tibble::tribble(
    ~setting_id, ~setting_name,              ~setting_type,
    1L,          "Oakfield Primary",         "School",
    2L,          "St Mary's Secondary",      "School",
    3L,          "Hillside Nursery",         "Community",
    4L,          "Faith Community Centre",   "Community",
    5L,          "Maple Street Household",   "Household",
    6L,          "Birch Close Household",    "Household",
    7L,          "Riverside GP Surgery",     "Healthcare",
    8L,          "Central Hospital ED",      "Healthcare")
  community  <- all_settings |> filter(setting_type != "Healthcare")
  healthcare <- all_settings |> filter(setting_type == "Healthcare")
  comm_w     <- c(.24, .20, .16, .14, .13, .13)
  n <- 15
  cases <- tibble::tibble(
    case_id            = sprintf("C%03d", seq_len(n)),
    onset_date         = as.Date("2026-04-01") + sample(0:56, n, replace = TRUE),
    age_group          = sample(c("<1 year","1–4 years","5–17 years","18–29 years","30–49 years","50+ years"),
                                n, TRUE, c(.10,.20,.30,.20,.12,.08)),
    vaccination_status = sample(c("Unvaccinated","1 dose","2 doses","Unknown"),
                                n, TRUE, c(.5,.2,.2,.1)),
    case_status        = sample(c("Confirmed","Probable","Possible"),
                                n, TRUE, c(.6,.3,.1))) |> arrange(onset_date)

  prim <- sample(seq_len(nrow(community)), n, replace = TRUE, prob = comm_w)

  # Helper: pick n_dates distinct dates from a window vector
  pick_dates <- function(window, n_dates) sort(sample(window, min(n_dates, length(window))))

  visit_rows <- purrr::map_dfr(seq_len(n), function(i) {
    onset     <- cases$onset_date[i]
    inf_win   <- seq(onset - DEF_INF_BEFORE, onset + DEF_INF_AFTER)
    exp_win   <- seq(onset - DEF_INC_MAX,    onset - DEF_INC_MIN)

    prim_stype <- community$setting_type[prim[i]]
    # Households: case is resident, so record dates spanning both the exposure and infectious windows.
    # Other settings: 1–3 visits during the infectious period only.
    prim_dates <- if (prim_stype == "Household")
                    c(pick_dates(exp_win, sample(2:4, 1)),
                      pick_dates(inf_win, sample(2:4, 1)))
                  else pick_dates(inf_win, sample(1:3, 1, prob = c(.4, .4, .2)))
    rows <- tibble::tibble(case_id    = cases$case_id[i],
                           setting_id = community$setting_id[prim[i]],
                           visit_date = prim_dates)

    if (runif(1) < 0.70) {
      h <- healthcare[sample(nrow(healthcare), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          setting_id = h$setting_id,
                          visit_date = onset + sample(1:3, 1))) }

    if (runif(1) < 0.65) {
      s_exp      <- community[sample(seq_len(nrow(community))[-prim[i]], 1), ]
      exp_dates  <- if (s_exp$setting_type == "Household") onset - sample(DEF_INC_MIN:DEF_INC_MAX, 1)
                    else pick_dates(exp_win, sample(1:2, 1))
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          setting_id = s_exp$setting_id,
                          visit_date = exp_dates)) }

    if (runif(1) < 0.35) {
      s_hist <- community[sample(seq_len(nrow(community)), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id    = cases$case_id[i],
                          setting_id = s_hist$setting_id,
                          visit_date = onset - sample(22:30, 1))) }
    rows
  }) |> arrange(case_id, visit_date)

  visit_dates   <- visit_rows |> distinct(case_id, setting_id, visit_date)
  case_settings <- visit_rows |>
    distinct(case_id, setting_id) |>
    left_join(all_settings |> select(setting_id, setting_type), by = "setting_id") |>
    mutate(has_other_visits = setting_type == "Household") |>
    select(case_id, setting_id, has_other_visits)
  settings <- all_settings |> semi_join(case_settings, by = "setting_id")

  prim_id <- community$setting_id[prim]
  contacts <- purrr::map_dfr(seq_len(n)[-1], function(i) {
    cand <- cases[seq_len(i - 1), ]
    w    <- ifelse(prim_id[seq_len(i - 1)] == prim_id[i], 5, 1)
    j    <- sample(seq_len(nrow(cand)), 1, prob = w)
    tibble::tibble(from = cand$case_id[j], to = cases$case_id[i],
                   link_type = sample(c("Confirmed","Suspected"), 1, prob = c(.7,.3)))
  })
  list(cases = cases, settings = settings, case_settings = case_settings,
       visit_dates = visit_dates, contacts = contacts)
}

flat_visits <- function(d) {
  d$case_settings |>
    left_join(d$settings, by = "setting_id") |>
    left_join(d$visit_dates, by = c("case_id", "setting_id"))
}

# ---- View builders ----------------------------------------------------------
build_setting_projection <- function(visits, ll, colours) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  nodes <- visits |> distinct(case_id, setting_name, setting_type) |>
    count(setting_name, setting_type, name = "cases") |>
    transmute(id = setting_name, label = setting_name, group = setting_type,
              value = cases, color = unname(colours[setting_type]), shape = "dot",
              title = paste0("<b>", setting_name, "</b><br>", setting_type,
                             "<br>Cases linked here: ", cases))
  per_case <- visits |> distinct(case_id, setting_name) |> group_by(case_id) |>
    summarise(s = list(sort(unique(setting_name))), .groups = "drop") |>
    filter(lengths(s) >= 2)
  edges <- purrr::map_dfr(per_case$s, function(s) {
    m <- t(combn(s, 2)); tibble::tibble(from = m[, 1], to = m[, 2]) })
  if (nrow(edges)) {
    edges <- edges |> count(from, to, name = "weight") |>
      transmute(from, to, value = weight,
                title = paste0(weight, " shared case(s) connect these settings"))
  } else edges <- tibble::tibble(from = character(), to = character(),
                                 value = numeric(), title = character())
  list(nodes = nodes, edges = edges)
}

build_bipartite <- function(visits, ll, colours,
                            inf_before = DEF_INF_BEFORE, inf_after  = DEF_INF_AFTER,
                            inc_min    = DEF_INC_MIN,    inc_max    = DEF_INC_MAX) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  has_dates <- "visit_date" %in% names(visits) && any(!is.na(visits$visit_date))
  vv <- visits |> left_join(ll |> select(case_id, onset_date), by = "case_id")
  vv <- vv |> mutate(
    in_infectious = !is.na(onset_date) & !is.na(visit_date) &
      visit_date >= onset_date - inf_before & visit_date <= onset_date + inf_after,
    in_exposure   = !is.na(onset_date) & !is.na(visit_date) &
      visit_date >= onset_date - inc_max    & visit_date <= onset_date - inc_min,
    visit_cat = if (!has_dates) "other" else dplyr::case_when(
      in_infectious & in_exposure ~ "both",
      in_infectious               ~ "infectious",
      in_exposure                 ~ "exposure",
      TRUE                        ~ "other"))

  setting_nodes <- vv |> distinct(setting_name, setting_type, case_id) |>
    count(setting_name, setting_type, name = "cases") |>
    transmute(id = paste0("set::", setting_name), label = setting_name,
              group = setting_type, kind = "Setting",
              color = unname(colours[setting_type]), shape = "square",
              size  = 14 + 4 * sqrt(cases),
              title = paste0("<b>", setting_name, "</b><br>", setting_type,
                             "<br>Distinct cases: ", cases))
  nset <- vv |> distinct(case_id, setting_name) |> count(case_id, name = "ns")
  case_nodes <- vv |> distinct(case_id) |>
    left_join(ll |> select(case_id, onset_date), by = "case_id") |>
    left_join(nset, by = "case_id") |>
    transmute(id = case_id, label = "", group = "Case", kind = "Case",
              color = CASE_COLOUR, shape = "dot", size = 8,
              title = paste0("<b>", case_id, "</b><br>Onset: ", onset_date,
                             "<br>Settings visited: ", ns))

  # Aggregate multiple visit dates per case × setting to one edge.
  # Priority order: both > infectious > exposure > other.
  cat_rank <- c(other = 1L, exposure = 2L, infectious = 3L, both = 4L)
  edges_agg <- vv |>
    group_by(case_id, setting_name, setting_type) |>
    summarise(
      visit_cat = {
        cats <- unique(visit_cat)
        # "both" if dates span the exposure window AND the infectious period, even if no single
        # date falls in both simultaneously (e.g. a household resident present across both windows)
        if (any(cats %in% c("exposure", "both")) && any(cats %in% c("infectious", "both"))) "both"
        else names(which.max(cat_rank[cats]))
      },
      date_label = {
        ds <- sort(unique(visit_date[!is.na(visit_date)]))
        if (!has_dates || length(ds) == 0) ""
        else if (length(ds) == 1) paste0("<br>Date: ", ds[1])
        else paste0("<br>Dates: ", paste(format(ds, "%d %b"), collapse = ", "))
      },
      .groups = "drop")
  edges <- edges_agg |>
    transmute(
      from      = case_id,
      to        = paste0("set::", setting_name),
      visit_cat = visit_cat,
      dashes    = visit_cat == "other",
      arrows    = dplyr::case_when(
                    visit_cat == "infectious" ~ "to",
                    visit_cat == "exposure"   ~ "from",
                    visit_cat == "both"       ~ "to;from",
                    TRUE                      ~ ""),
      color     = dplyr::case_when(
                    visit_cat == "infectious" ~ "#d62728",
                    visit_cat == "exposure"   ~ "#1f77b4",
                    visit_cat == "both"       ~ "#9467bd",
                    TRUE                      ~ "#9aa0a6"),
      title     = paste0(
                    "<b>", htmltools::htmlEscape(case_id), "</b> visited <b>",
                    htmltools::htmlEscape(setting_name), "</b>",
                    date_label,
                    dplyr::case_when(
                      visit_cat == "both"       ~
                        "<br>Present — during both windows<br><i>Falls within both the infectious period and exposure window</i>",
                      visit_cat == "infectious" ~
                        "<br>Present — during infectious period<br><i>Case may have transmitted infection here</i>",
                      visit_cat == "exposure"   ~
                        "<br>Present — during exposure window<br><i>Case may have acquired infection here</i>",
                      TRUE ~
                        "<br>Present — outside both windows<br><i>Not considered relevant to transmission</i>")))
  list(nodes = bind_rows(setting_nodes, case_nodes), edges = edges)
}

# Derive SUSPECTED case-to-case links from shared settings + onset timing.
# A suspected link (earlier -> later case) is drawn when two cases attended the
# same setting and the later onset falls within [inc_min - inf_before,
# inc_max + inf_after] days after the earlier onset.
derive_suspected_links <- function(ll, visits, inc_min, inc_max, inf_before, inf_after) {
  empty <- tibble(from = character(), to = character(), link_type = character())
  if (nrow(visits) == 0) return(empty)
  onset <- setNames(ll$onset_date, ll$case_id)
  pair_list <- visits |> distinct(case_id, setting_name) |> group_by(setting_name) |>
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
    distinct(from, to) |> mutate(link_type = "Suspected")
}

build_contacts_network <- function(ll, contacts, visits, colours) {
  primary <- if (nrow(visits))
    visits |> arrange(visit_date) |> group_by(case_id) |> slice(1) |> ungroup() |>
      select(case_id, setting_type)
  else tibble(case_id = character(), setting_type = character())

  n_settings  <- visits |> distinct(case_id, setting_name) |> count(case_id, name = "n_settings")
  case_settings <- visits |> distinct(case_id, setting_name, setting_type)
  onset <- setNames(ll$onset_date, ll$case_id)

  nodes <- ll |>
    left_join(primary,     by = "case_id") |>
    left_join(n_settings,  by = "case_id") |>
    mutate(setting_type = ifelse(is.na(setting_type), "Other", setting_type),
           n_settings   = coalesce(n_settings, 0L)) |>
    transmute(id = case_id, label = case_id, group = setting_type,
              color = coalesce(unname(colours[setting_type]), "#7f7f7f"),
              title = paste0("<b>", htmltools::htmlEscape(case_id), "</b><br>Onset: ", onset_date,
                             "<br>Settings visited: ", n_settings))

  edges <- contacts |> filter(from %in% nodes$id, to %in% nodes$id) |>
    mutate(
      gap = purrr::map2_int(from, to, function(f, t) {
        d1 <- onset[[f]]; d2 <- onset[[t]]
        if (is.na(d1) || is.na(d2)) NA_integer_ else as.integer(abs(as.Date(d2) - as.Date(d1)))
      }),
      common_text = purrr::map2_chr(from, to, function(f, t) {
        shared <- intersect(
          case_settings$setting_name[case_settings$case_id == f],
          case_settings$setting_name[case_settings$case_id == t])
        if (length(shared) == 0) return("None recorded")
        rows <- case_settings[case_settings$case_id == f & case_settings$setting_name %in% shared, ]
        paste(paste0(htmltools::htmlEscape(rows$setting_name), " (", htmltools::htmlEscape(rows$setting_type), ")"), collapse = "<br>")
      }),
      title = paste0(
        htmltools::htmlEscape(link_type), " link",
        ifelse(!is.na(gap), paste0("<br>Onset gap: ", gap, ifelse(gap == 1, " day", " days")), ""),
        "<br>Common settings: ", common_text)
    ) |>
    transmute(from, to, dashes = link_type == "Suspected", title)

  list(nodes = nodes, edges = edges)
}

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

epi_curve <- function(ll) {
  if (nrow(ll) == 0) return(plotly_empty())
  d <- ll |> mutate(week = floor_date(onset_date, "week", week_start = 1)) |> count(week)
  p <- ggplot2::ggplot(d, ggplot2::aes(week, n)) +
    ggplot2::geom_col(fill = "#2c7fb8") + ggplot2::labs(x = NULL, y = "New cases") +
    ggplot2::theme_minimal(base_size = 12)
  ggplotly(p)
}

header_tooltips <- function(tips) {
  JS(sprintf(
    "function(thead){ var tips=%s; $(thead).find('th').each(function(i){ if(tips[i]){ $(this).attr('title', tips[i]); $(this).css('text-decoration','underline dotted'); $(this).css('cursor','help'); } }); }",
    jsonlite::toJSON(tips)))
}
metric_tips_lookup <- c(
  Node        = "The individual case or the setting this row describes.",
  Kind        = "Whether this node is a Case or a Setting (Who visited where view only).",
  Degree      = "Number of direct links. For a setting: how many case-visits it has. For a case: how many settings it visited (Who visited where) or contacts it has.",
  Betweenness = "How often this node lies on the connecting path between others. A high value flags a 'bridge' joining otherwise separate parts of the outbreak.")
ll_tips_lookup <- c(
  case_id            = "Unique identifier for each case.",
  onset_date         = "Date the case first developed symptoms. Drives the time slider, epidemic curve and infectious-period logic.",
  age_group          = "Age band of the case.",
  vaccination_status = "Recorded measles vaccination status of the case.",
  case_status        = "Classification of the case: Confirmed, Probable, or Possible.",
  settings_visited   = "Number of distinct settings this case is recorded as having visited.")

# ---- Definitions content ----------------------------------------------------
definitions_md <- '
## Definitions

Terms used in this tool and what they mean in the context of outbreak investigation.

---

### Confirmed source

A case that has been identified through investigation as the verified origin of
transmission to another case. A confirmed link is one where an epidemiological
connection has been established — for example a named household contact, a
documented exposure event, or otherwise verified contact — and is recorded as
such in the contacts data. Shown as a **solid line** in the Who infected whom view.

### Suspected source

A case with a plausible but unverified link to a later case. A suspected link
may be recorded as "Suspected" in the contacts data, or derived automatically
by this tool when two cases attended the same setting and the gap between their
onset dates falls within the range expected given the incubation and infectious
periods. Shown as a **dashed line** in the Who infected whom view. See the
**Assumptions & parameters** tab for how the derived rule is defined and how to
adjust the parameters.

---

### Setting

A place where one or more cases were present during the outbreak — for example a
school, healthcare facility, community group, or household. Settings are the
nodes in the Settings network and Who visited where views.

### Transmission link

A directional connection from an earlier case (the source) to a later case (the
recipient), indicating a possible or confirmed route of infection. Arrows point
from source to recipient in the Who infected whom view.

### Degree

The number of direct links a node has. In the Who infected whom view this is the
total number of transmission links (in or out). In the Who visited where view it is the
number of settings a case visited, or the number of cases linked to a setting.
A high-degree node is a hub — either a case linked to many others, or a setting
attended by many cases.

### Betweenness

How often a node lies on the shortest connecting path between other nodes in the
network. A high betweenness value flags a "bridge" — a case or setting that
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
investigation, not laboratory-proven transmission. Confirmed and suspected
classifications reflect the strength of epidemiological evidence at the time of
recording, not a clinical or virological standard.*
'

# ---- How-to-use content -----------------------------------------------------
how_to_use_md <- '
## What this tool is for

This dashboard turns an outbreak line list into an interactive picture of **how
cases and settings are connected**. You do not need any experience with network
diagrams - this page explains every part. A single case can visit **many
settings**; each visit date is one row in the **visit_dates** table.

## The three views (sidebar control)

**Settings network** - each dot is a place; two places are joined when a case
visited both (thicker line = more shared cases). Best for seeing how settings
are connected.

**Who visited where** - shows cases (dark dots) and settings (coloured squares);
each line is a visit. A multi-setting case appears joined to several squares.

**Who infected whom** - suspected transmission links between cases, either taken
from the contacts sheet or derived from shared settings and timing. How
"suspected" is defined, and the parameters behind it, are on the
**Assumptions & parameters** tab.

## Reading the network

Colour = setting type (legend). Size = number of cases. Hover any dot or line for
details, drag to rearrange, click to highlight connections. In the Who visited
where view, line colour and arrows show the direction of potential transmission:
**red arrow → setting** = present during infectious period (may have spread
infection there); **blue arrow → case** = present during exposure window (may
have acquired infection there); **purple ↔** = present during both windows;
**grey dashed** = outside both windows (not transmission-relevant).

## Time slider, epidemic curve, metrics

Drag either end of the onset date slider to narrow or widen the window, or press
play to advance the end date and watch the outbreak grow. The bar chart shows new
cases per week. **Degree** = number of direct links; **Betweenness** = how often
a node bridges otherwise separate clusters.

## Ways to use it

Find hub settings (large, high-degree), bridge settings (high betweenness),
and - in the Who visited where view - settings where infection was likely spread
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

- **Setting node** - a place where cases were present (school, healthcare centre,
  community group, household).
- **Case node** - an individual confirmed or probable case.
- **Shared-case link (Settings network view)** - drawn whenever at least one
  case attended both settings. This is based purely on **co-attendance**; it
  makes no timing assumption. The line weight is the number of shared cases.
- **Visit link (Who visited where view)** - one line per recorded visit of a case to a
  setting.

### When is a visit "infectious"?

In the Who visited where view each visit is classified using the **infectious period**:
a visit is marked red when its date falls from *infectious-days-before* to
*infectious-days-after* the case onset — meaning the case was infectious at the
time of the visit. This is a **necessary but not sufficient** condition for
onward transmission: it shows that the case could have been infectious at that
setting, but does not confirm that a susceptible person was present or went on
to develop symptoms within the incubation period. Visits outside that window are
shown grey and represent possible exposure to infection (the case may have
acquired infection there). Measles is commonly treated as infectious from about
4 days before to 4 days after rash onset; this is the default and can be changed
below.

### When is a transmission link "confirmed" vs "suspected"?

- **Confirmed** - a link established during investigation (for example a named
  household or close contact, or an otherwise verified epidemiological link), as
  recorded in the contacts sheet. Shown as a solid line.
- **Suspected** - a plausible but unverified link. Shown as a dashed line. A
  suspected link can come from either:
  1. a row marked "Suspected" in the contacts sheet, or
  2. **derivation by the tool** (if you select that option below): two cases
     attended the **same setting**, and the later case onset falls a plausible
     interval after the earlier one, given the incubation and infectious periods.

### The derived-link rule

A susceptible case is exposed during a source case infectious period, then
develops symptoms after the incubation period. So the gap between an earlier
(source) onset and a later (infectee) onset is plausible when it lies between
**(incubation minimum minus infectious-days-before)** and **(incubation maximum
plus infectious-days-after)** days. The tool draws a suspected link, from the
earlier to the later case, for every co-attending pair whose onset gap falls in
that window.

### Default parameters (measles, approximate)

- **Incubation period** (exposure to symptom onset): about 7 to 21 days.
- **Infectious period**: about 4 days before to 4 days after onset.

These are typical published ranges and will vary by source, case definition and
jurisdiction. Treat them as starting points and adjust to your local guidance.

### Caveats

Co-attendance and timing make a link **plausible**, not proven - two cases at the
same setting in a consistent window may still be unrelated, and true links may be
missing if visits were not recorded. Use the diagram to generate and prioritise
hypotheses, alongside your wider outbreak knowledge.
'

# ---- UI ---------------------------------------------------------------------
ui <- page_navbar(
  title = "Measles Outbreak Network Explorer",
  theme = bs_theme(version = 5, bootswatch = "flatly"), id = "nav",
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
  "))),

  nav_panel("Dashboard",
    layout_sidebar(
      sidebar = sidebar(width = 340,
        tags$label(class = "form-label mb-0",
          "Filter by onset date",
          info("Filters to cases whose symptom onset falls within this date range. Visit dates are filtered to the same window.")),
        sliderInput("asof", label = NULL, min = Sys.Date() - 60, max = Sys.Date(),
                    value = c(Sys.Date() - 60, Sys.Date()), timeFormat = "%d %b %Y",
                    animate = animationOptions(interval = 900)),
        checkboxGroupInput("types",
          label = tagList("Include setting types",
            info("Tick or untick to focus on particular kinds of setting.")),
          choices = character(0), selected = character(0)),
        checkboxGroupInput("case_status_filter",
          label = tagList("Case status",
            info("Filter by how firmly the case has been classified. Confirmed and Probable are included by default; untick to exclude or tick Possible to include.")),
          choices  = c("Confirmed", "Probable", "Possible"),
          selected = c("Confirmed", "Probable")),
        hr(),
        helpText("See ", strong("Definitions"), ", ", strong("How to use"), " and ",
                 strong("Assumptions & parameters"), " tabs at the top.")),

      layout_columns(col_widths = c(8, 4),
        card(class = "network-card",
          card_header(class = "d-flex justify-content-between align-items-center",
            div(class = "d-flex align-items-center gap-2",
              span("Network"),
              selectInput("view", NULL, width = "290px",
                choices = c("Settings network"  = "projection",
                            "Who visited where" = "bipartite",
                            "Who infected whom" = "contacts"),
                selected = "bipartite")),
            div(class = "d-flex align-items-center gap-2",
              tags$button(id = "net-toggle-btn",
                class = "btn btn-sm btn-outline-secondary",
                onclick = "toggleNetwork()", "Maximise"),
              info(paste0("Settings network links places that share a case. ",
                          "Who visited where shows cases and settings together. ",
                          "Who infected whom uses the contacts table or links derived from timing ",
                          "(see Assumptions & parameters).")))),
          uiOutput("bipartite_key"),
          visNetworkOutput("net", height = "560px")),
        card(hdr("Epidemic curve",
                 "New cases per week by onset date. A rising curve means the outbreak is still growing."),
             plotlyOutput("curve", height = "300px")),
        card(hdr("Network metrics - most connected nodes",
                 "Ranks nodes by how connected they are. Hover the column headings for definitions."),
             DTOutput("metrics")),
        card(hdr("Line list (filtered)",
                 "Case records currently shown, with how many settings each visited. Hover headings for definitions."),
             DTOutput("ll")))
    )),

  nav_panel("Source data",
    div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
      card(hdr("Cases",
               "One row per case. The primary case record — onset date drives the time slider, epidemic curve and infectious-period logic."),
           DTOutput("src_cases")),
      card(hdr("Case settings",
               "One row per case × setting combination. Records which cases visited which settings and whether the case also visited on non-epidemiologically-relevant dates (has_other_visits)."),
           DTOutput("src_case_settings")),
      card(hdr("Visit dates",
               "One row per epidemiologically relevant visit date. A single case × setting pair can appear on multiple rows here, one per date."),
           DTOutput("src_visit_dates")),
      card(hdr("Contacts",
               "One row per recorded transmission link. Optional — if not supplied, case-to-case links can be derived from shared settings and timing instead."),
           DTOutput("src_contacts")))),

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
          radioButtons("susp_source",
            "How should SUSPECTED case-to-case links be defined?",
            c("As recorded in the contacts sheet"                                    = "file",
              "Derive from shared settings + timing (uses the parameters above)"     = "derive"),
            selected = "file"),
          uiOutput("susp_readout"),
          actionButton("reset_params", "Reset to defaults",
                       class = "btn-outline-secondary btn-sm"))))),

  # ---- Reference tab (dev only — remove before release) ----------------------
  nav_panel("Reference",
    div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
      card(
        hdr("Schema diagram",
            "Entity-relationship diagram. Underlined fields are primary keys. Italic epi_category is derived at runtime and not stored."),
        card_body(
          grVizOutput("erd_plot", height = "500px"),
          div(style = "margin-top:8px;",
              downloadButton("download_erd", "Download SVG", class = "btn-outline-secondary btn-sm")))
      ),
      card(
        hdr("Data dictionary", "Field-level definitions. epi_category in visit_dates is computed live from parameters and is never stored."),
        card_body(
          navset_tab(
            nav_panel("cases",         DTOutput("dict_cases")),
            nav_panel("settings",      DTOutput("dict_settings")),
            nav_panel("case_settings", DTOutput("dict_case_settings")),
            nav_panel("visit_dates",   DTOutput("dict_visit_dates")),
            nav_panel("contacts",      DTOutput("dict_contacts"))
          )
        )
      )
    )
  ),

  nav_spacer(),
  nav_item(tags$span(style = "color:#888; font-size:0.85em;", "Measles outbreak visualiser"))
)

# ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  raw <- reactive({
    make_demo_data()
  })

  observeEvent(raw(), {
    d    <- raw()
    rng  <- range(c(d$cases$onset_date, d$visit_dates$visit_date), na.rm = TRUE)
    updateSliderInput(session, "asof", min = rng[1], max = rng[2], value = c(rng[1], rng[2]))
    types <- unique(d$settings$setting_type)
    updateCheckboxGroupInput(session, "types", choices = types, selected = types)
    statuses <- if ("case_status" %in% names(d$cases))
      intersect(c("Confirmed","Probable","Possible"), unique(d$cases$case_status))
    else c("Confirmed","Probable","Possible")
    updateCheckboxGroupInput(session, "case_status_filter",
      choices = statuses, selected = intersect(statuses, c("Confirmed","Probable")))
  })

  params <- reactive({
    g <- function(x, d) if (is.null(x) || is.na(x)) d else x
    list(inc_min    = g(input$inc_min,    DEF_INC_MIN),
         inc_max    = g(input$inc_max,    DEF_INC_MAX),
         inf_before = g(input$inf_before, DEF_INF_BEFORE),
         inf_after  = g(input$inf_after,  DEF_INF_AFTER))
  })

  observeEvent(input$reset_params, {
    updateNumericInput(session, "inc_min",    value = DEF_INC_MIN)
    updateNumericInput(session, "inc_max",    value = DEF_INC_MAX)
    updateNumericInput(session, "inf_before", value = DEF_INF_BEFORE)
    updateNumericInput(session, "inf_after",  value = DEF_INF_AFTER)
    updateRadioButtons(session, "susp_source", selected = "file")
  })

  output$susp_readout <- renderUI({
    p  <- params(); lb <- p$inc_min - p$inf_before; ub <- p$inc_max + p$inf_after
    div(style = "background:#eef6fb; border-left:4px solid #2c7fb8; padding:8px 12px; margin:8px 0; border-radius:4px;",
        HTML(sprintf(paste0("With the current values, a <b>suspected</b> link is drawn from an ",
                            "earlier case to a later case who shared a setting when the later onset is between ",
                            "<b>%g</b> and <b>%g days</b> after the earlier one. The bipartite view marks a visit ",
                            "as infectious when it falls from <b>%g days before</b> to <b>%g days after</b> onset."),
                     lb, ub, p$inf_before, p$inf_after)))
  })

  output$bipartite_key <- renderUI({
    req(input$view == "bipartite")
    div(style = "display:flex; flex-direction:column; gap:6px; font-size:0.82em; padding:4px 2px 6px 2px;",
      tags$span(leg_arrow("#d62728", "right"), "Infectious period — may have spread infection here"),
      tags$span(leg_arrow("#1f77b4", "left"),  "Exposure window — may have been infected here"),
      tags$span(leg_arrow("#9467bd", "both"),  "Both windows overlap"),
      tags$span(leg_arrow("#9aa0a6", dashed = TRUE), "Outside both windows"))
  })

  filtered <- reactive({
    d   <- raw()
    cs  <- d$cases |> filter(onset_date >= input$asof[1], onset_date <= input$asof[2])
    if ("case_status" %in% names(cs))
      cs <- cs |> filter(is.na(case_status) | case_status %in% input$case_status_filter)
    st  <- d$settings |> filter(setting_type %in% input$types)
    cst <- d$case_settings |> filter(case_id %in% cs$case_id, setting_id %in% st$setting_id)
    st  <- st |> filter(setting_id %in% cst$setting_id)
    vd  <- d$visit_dates |> filter(case_id %in% cs$case_id, setting_id %in% cst$setting_id)
    ct  <- d$contacts |> filter(from %in% cs$case_id, to %in% cs$case_id)
    list(cases = cs, settings = st, case_settings = cst, visit_dates = vd, contacts = ct)
  })

  netdata <- reactive({
    f    <- filtered()
    fv   <- flat_visits(f)
    p    <- params()
    cols <- colour_map(f$settings$setting_type)
    switch(input$view,
      projection = build_setting_projection(fv, f$cases, cols),
      bipartite  = build_bipartite(fv, f$cases, cols, p$inf_before, p$inf_after, p$inc_min, p$inc_max),
      contacts   = {
        ct <- if (input$susp_source == "derive")
          derive_suspected_links(f$cases, fv, p$inc_min, p$inc_max, p$inf_before, p$inf_after)
        else f$contacts
        build_contacts_network(f$cases, ct, fv, cols)
      })
  })

  output$net <- renderVisNetwork({
    nd <- netdata(); v <- input$view
    vis_edges <- if ("visit_cat" %in% names(nd$edges))
      nd$edges |> select(-visit_cat) else nd$edges
    vn <- visNetwork(nd$nodes, vis_edges) |>
      visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
                 nodesIdSelection = TRUE) |>
      visPhysics(stabilization = TRUE,
                 barnesHut = list(gravitationalConstant = -3500, springLength = 130))
    vn <- if (v == "contacts") visEdges(vn, arrows = "to", smooth = TRUE)
          else if (v == "bipartite") visEdges(vn, smooth = FALSE)
          else visEdges(vn, smooth = TRUE, color = list(color = "#9aa0a6", opacity = 0.7))
    cols <- colour_map(filtered()$settings$setting_type)
    leg <- lapply(names(cols), function(s)
      list(label = s, shape = if (v == "bipartite") "square" else "dot",
           color = unname(cols[[s]])))
    if (v == "bipartite") leg <- c(leg, list(list(label = "Case", shape = "dot", color = CASE_COLOUR)))
    vn |> visLegend(useGroups = FALSE, addNodes = leg, position = "left", width = 0.18)
  })

  output$curve   <- renderPlotly({ epi_curve(filtered()$cases) })

  output$metrics <- renderDT({
    mt   <- network_metrics(netdata()$nodes, netdata()$edges)
    tips <- vapply(names(mt),
                   function(n) if (n %in% names(metric_tips_lookup)) metric_tips_lookup[[n]] else "", character(1))
    datatable(mt, rownames = FALSE,
              options = list(pageLength = 8, dom = "tp", headerCallback = header_tooltips(unname(tips))))
  })

  src_dt <- function(df) datatable(df, rownames = FALSE, filter = "top",
    options = list(pageLength = 15, scrollX = TRUE, dom = "lftip"))

  output$src_cases         <- renderDT({ src_dt(raw()$cases) })
  output$src_case_settings <- renderDT({ src_dt(raw()$case_settings) })
  output$src_visit_dates   <- renderDT({ src_dt(raw()$visit_dates) })
  output$src_contacts      <- renderDT({
    ct <- raw()$contacts
    if (nrow(ct) == 0)
      src_dt(tibble::tibble(message = "No contacts sheet supplied — using demo data or file has no contacts tab."))
    else src_dt(ct)
  })

  output$ll <- renderDT({
    f  <- filtered()
    nv <- f$case_settings |> distinct(case_id, setting_id) |> count(case_id, name = "settings_visited")
    df <- f$cases |> left_join(nv, by = "case_id") |>
      mutate(settings_visited = tidyr::replace_na(settings_visited, 0L))
    tips <- vapply(names(df),
                   function(n) if (n %in% names(ll_tips_lookup)) ll_tips_lookup[[n]] else "", character(1))
    datatable(df, rownames = FALSE,
              options = list(pageLength = 6, scrollX = TRUE, dom = "tp",
                             headerCallback = header_tooltips(unname(tips))))
  })

  # ---- Reference tab outputs --------------------------------------------------
  output$erd_plot <- renderGrViz({ grViz(ERD_GRAPHVIZ) })

  output$download_erd <- downloadHandler(
    filename = "network-diagram-schema.svg",
    content  = function(file) {
      if (!requireNamespace("DiagrammeRsvg", quietly = TRUE))
        stop("Install the DiagrammeRsvg package to enable SVG download.")
      writeLines(DiagrammeRsvg::export_svg(grViz(ERD_GRAPHVIZ)), file)
    }
  )

  dict_dt <- function(tbl)
    datatable(tbl, rownames = FALSE, escape = FALSE,
              options = list(dom = "t", pageLength = 20, ordering = FALSE,
                             columnDefs = list(list(width = "45%", targets = 4))))

  output$dict_cases         <- renderDT({ dict_dt(DICT_TABLES$cases) })
  output$dict_settings      <- renderDT({ dict_dt(DICT_TABLES$settings) })
  output$dict_case_settings <- renderDT({ dict_dt(DICT_TABLES$case_settings) })
  output$dict_visit_dates   <- renderDT({ dict_dt(DICT_TABLES$visit_dates) })
  output$dict_contacts      <- renderDT({ dict_dt(DICT_TABLES$contacts) })

}

shinyApp(ui, server)
