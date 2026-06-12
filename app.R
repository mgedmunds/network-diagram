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
# INPUT (.xlsx) sheets:
# - linelist: case_id, onset_date, age_group, vaccination_status
# - visits: case_id, setting_name, setting_type, visit_date (one row per visit)
# - contacts: from, to, link_type (optional)
# See sample_outbreak_data.xlsx (has a README sheet). Demo data is used if no
# file is uploaded.
#
# TO RUN:
# install.packages(c("shiny","bslib","visNetwork","dplyr","tidyr","readxl",
#                    "lubridate","igraph","plotly","DT","purrr","tibble",
#                    "jsonlite"))
# shiny::runApp("app.R")
# =============================================================================

library(shiny)
library(bslib)
library(visNetwork)
library(dplyr)
library(tidyr)
library(readxl)
library(lubridate)
library(igraph)
library(plotly)
library(DT)
library(purrr)
library(tibble)
library(jsonlite)

# ---- Configuration ----------------------------------------------------------
setting_colours <- c(
  School = "#1f77b4", Healthcare = "#d62728", Community = "#2ca02c",
  Household = "#9467bd", Other = "#7f7f7f"
)
CASE_COLOUR <- "#444444"

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

# ---- Demo data --------------------------------------------------------------
make_demo_data <- function() {
  set.seed(42)
  community <- tibble::tribble(
    ~setting_name,              ~setting_type,
    "Oakfield Primary",         "School",
    "St Mary's Secondary",      "School",
    "Hillside Nursery",         "Community",
    "Faith Community Centre",   "Community",
    "Maple Street Household",   "Household",
    "Birch Close Household",    "Household")
  comm_w <- c(.24, .20, .16, .14, .13, .13)
  healthcare <- tibble::tribble(
    ~setting_name,              ~setting_type,
    "Riverside GP Surgery",     "Healthcare",
    "Central Hospital ED",      "Healthcare")
  n <- 60
  ll <- tibble::tibble(
    case_id            = sprintf("C%03d", seq_len(n)),
    onset_date         = as.Date("2026-04-01") + sample(0:56, n, replace = TRUE),
    age_group          = sample(c("0-4","5-11","12-17","18+"), n, TRUE, c(.3,.35,.2,.15)),
    vaccination_status = sample(c("Unvaccinated","1 dose","2 doses","Unknown"),
                                n, TRUE, c(.5,.2,.2,.1))) |> arrange(onset_date)

  prim <- sample(seq_len(nrow(community)), n, replace = TRUE, prob = comm_w)
  visits <- purrr::map_dfr(seq_len(n), function(i) {
    rows <- tibble::tibble(case_id      = ll$case_id[i],
                           setting_name = community$setting_name[prim[i]],
                           setting_type = community$setting_type[prim[i]],
                           visit_date   = ll$onset_date[i] - sample(0:3, 1))
    if (runif(1) < 0.55) { h <- healthcare[sample(nrow(healthcare), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id = ll$case_id[i],
                          setting_name = h$setting_name, setting_type = h$setting_type,
                          visit_date   = ll$onset_date[i] + sample(1:3, 1))) }
    if (runif(1) < 0.30) { s2 <- community[sample(nrow(community), 1), ]
      rows <- bind_rows(rows, tibble::tibble(case_id = ll$case_id[i],
                          setting_name = s2$setting_name, setting_type = s2$setting_type,
                          visit_date   = ll$onset_date[i] - sample(2:6, 1))) }
    rows
  }) |> arrange(case_id, visit_date) |> distinct(case_id, setting_name, .keep_all = TRUE)

  prim_name <- community$setting_name[prim]
  ct <- purrr::map_dfr(seq_len(n)[-1], function(i) {
    cand <- ll[seq_len(i - 1), ]
    w    <- ifelse(prim_name[seq_len(i - 1)] == prim_name[i], 5, 1)
    j    <- sample(seq_len(nrow(cand)), 1, prob = w)
    tibble::tibble(from = cand$case_id[j], to = ll$case_id[i],
                   link_type = sample(c("Confirmed","Suspected"), 1, prob = c(.7,.3)))
  })
  list(linelist = ll, visits = visits, contacts = ct)
}

# ---- View builders ----------------------------------------------------------
build_setting_projection <- function(visits, ll) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  nodes <- visits |> distinct(case_id, setting_name, setting_type) |>
    count(setting_name, setting_type, name = "cases") |>
    transmute(id = setting_name, label = setting_name, group = setting_type,
              value = cases, color = unname(setting_colours[setting_type]), shape = "dot",
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

build_bipartite <- function(visits, ll, inf_before = DEF_INF_BEFORE, inf_after = DEF_INF_AFTER) {
  if (nrow(visits) == 0)
    return(list(nodes = tibble(id = character(), label = character()),
                edges = tibble(from = character(), to = character())))
  has_dates <- "visit_date" %in% names(visits) && any(!is.na(visits$visit_date))
  vv <- visits |> left_join(ll |> select(case_id, onset_date), by = "case_id")
  vv$infectious <- if (has_dates)
    !is.na(vv$onset_date) & !is.na(vv$visit_date) &
      vv$visit_date >= vv$onset_date - inf_before &
      vv$visit_date <= vv$onset_date + inf_after else FALSE

  setting_nodes <- vv |> distinct(setting_name, setting_type, case_id) |>
    count(setting_name, setting_type, name = "cases") |>
    transmute(id = paste0("set::", setting_name), label = setting_name,
              group = setting_type, kind = "Setting",
              color = unname(setting_colours[setting_type]), shape = "square",
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
  edges <- vv |> transmute(from = case_id, to = paste0("set::", setting_name),
    dashes = if (has_dates) !infectious else FALSE,
    color  = if (has_dates) ifelse(infectious, "#d62728", "#9aa0a6") else "#9aa0a6",
    title  = paste0(case_id, " visited ", setting_name,
                    if (has_dates) paste0(" on ", visit_date) else "",
                    if (has_dates) ifelse(infectious,
                      " (within infectious period – possible onward transmission)",
                      " (outside infectious period – possible exposure)") else ""))
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

build_contacts_network <- function(ll, contacts, visits) {
  primary <- if (nrow(visits))
    visits |> arrange(visit_date) |> group_by(case_id) |> slice(1) |> ungroup() |>
      select(case_id, setting_type)
  else tibble(case_id = character(), setting_type = character())
  nodes <- ll |> left_join(primary, by = "case_id") |>
    mutate(setting_type = ifelse(is.na(setting_type), "Other", setting_type)) |>
    transmute(id = case_id, label = case_id, group = setting_type,
              color = unname(setting_colours[setting_type]),
              title = paste0("<b>", case_id, "</b><br>Onset: ", onset_date,
                             "<br>Earliest setting type: ", setting_type))
  edges <- contacts |> filter(from %in% nodes$id, to %in% nodes$id) |>
    transmute(from, to, dashes = link_type == "Suspected",
              title = paste0(link_type, " link"))
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
  Kind        = "Whether this node is a Case or a Setting (bipartite view only).",
  Degree      = "Number of direct links. For a setting: how many case-visits it has. For a case: how many settings it visited (bipartite) or contacts it has.",
  Betweenness = "How often this node lies on the connecting path between others. A high value flags a 'bridge' joining otherwise separate parts of the outbreak.")
ll_tips_lookup <- c(
  case_id            = "Unique identifier for each case.",
  onset_date         = "Date the case first developed symptoms. Drives the time slider, epidemic curve and infectious-period logic.",
  age_group          = "Age band of the case.",
  vaccination_status = "Recorded measles vaccination status of the case.",
  settings_visited   = "Number of distinct settings this case is recorded as having visited.")

# ---- How-to-use content -----------------------------------------------------
how_to_use_md <- '
## What this tool is for

This dashboard turns an outbreak line list into an interactive picture of **how
cases and settings are connected**. You do not need any experience with network
diagrams - this page explains every part. A single case can visit **many
settings**; each visit is one row in the **visits** table.

## The three views (sidebar control)

**Settings to settings (shared cases)** - each dot is a place; two places are
joined when a case visited both (thicker line = more shared cases). Best for
seeing how settings are connected.

**Cases by settings (bipartite)** - shows cases (dark dots) and settings
(coloured squares); each line is a visit. A multi-setting case appears joined to
several squares.

**Case to case (transmission links)** - suspected who-infected-whom links between
cases, either taken from the contacts sheet or derived from shared settings and
timing. How "suspected" is defined, and the parameters behind it, are on the
**Assumptions & parameters** tab.

## Reading the network

Colour = setting type (legend). Size = number of cases. Hover any dot or line for
details, drag to rearrange, click to highlight connections. In the bipartite
view, **red solid** lines are visits during the infectious period (possible
spread) and **grey dashed** lines are other visits (possible exposure).

## Time slider, epidemic curve, metrics

Slide the date back or press play to watch the outbreak grow. The bar chart shows
new cases per week. **Degree** = number of direct links; **Betweenness** = how
often a node bridges otherwise separate clusters.

## Ways to use it

Find hub settings (large, high-degree), bridge settings (high betweenness),
and - in the bipartite view - settings where infection was likely spread (red)
versus caught (grey). Combine with the epidemic curve to judge the trajectory and
prioritise vaccination, isolation or communication.

## Loading your own data

Upload an .xlsx with sheets **linelist**, **visits** and optional **contacts**.
The sample file has a README describing every column.

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
- **Shared-case link (Settings to settings view)** - drawn whenever at least one
  case attended both settings. This is based purely on **co-attendance**; it
  makes no timing assumption. The line weight is the number of shared cases.
- **Visit link (bipartite view)** - one line per recorded visit of a case to a
  setting.

### When is a visit "infectious"?

In the bipartite view each visit is classified using the **infectious period**:
a visit is treated as infectious (possible onward transmission, shown red) when
its date falls from *infectious-days-before* to *infectious-days-after* the case
onset. Visits outside that window are treated as possible **exposure** (shown
grey). Measles is commonly treated as infectious from about 4 days before to
4 days after rash onset; this is the default and can be changed below.

### When is a case-to-case link "confirmed" vs "suspected"?

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
      max-width: 260px !important;
      white-space: normal !important;
      word-wrap: break-word !important;
      line-height: 1.5 !important;
      padding: 6px 10px !important;
    }
    .network-card,
    .network-card .card-body {
      overflow: visible !important;
    }
  "))),

  nav_panel("Dashboard",
    layout_sidebar(
      sidebar = sidebar(width = 340,
        fileInput("file", "Upload outbreak file (.xlsx)", accept = ".xlsx"),
        helpText("Needs sheets 'linelist' and 'visits' (and optional 'contacts'). ",
                 "Leave empty to explore demo data."),
        radioButtons("view",
          label = tagList("Network view",
            info(paste0("Settings-to-settings links places that share a case. ",
                        "Bipartite shows cases AND settings. Case-to-case uses the contacts ",
                        "table or links derived from timing (see Assumptions & parameters)."))),
          choices = c("Settings ↔ settings (shared cases)" = "projection",
                      "Cases × settings (bipartite)"       = "bipartite",
                      "Case-to-case (transmission links)"       = "contacts"),
          selected = "bipartite"),
        sliderInput("asof", label = NULL, min = Sys.Date() - 60, max = Sys.Date(),
                    value = Sys.Date(), timeFormat = "%d %b %Y",
                    animate = animationOptions(interval = 900)),
        div(style = "margin-top:-10px;", tags$label("Show data up to..."),
            info("Filters to cases with onset by this date and their visits up to it.")),
        checkboxGroupInput("types",
          label = tagList("Include setting types",
            info("Tick or untick to focus on particular kinds of setting.")),
          choices = names(setting_colours), selected = names(setting_colours)),
        hr(),
        helpText("See ", strong("How to use"), " and ",
                 strong("Assumptions & parameters"), " tabs at the top.")),

      layout_columns(col_widths = c(8, 4),
        card(full_screen = TRUE, class = "network-card",
          hdr("Network",
            paste0("Dots are cases and/or settings; lines are links. Colour = setting ",
                   "type. In the bipartite view red solid lines are visits during the ",
                   "infectious period (possible spread) and grey dashed lines are other ",
                   "visits (possible exposure). Hover, drag and click to explore.")),
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

  nav_spacer(),
  nav_item(tags$span(style = "color:#888; font-size:0.85em;", "Measles outbreak visualiser"))
)

# ---- Server -----------------------------------------------------------------
server <- function(input, output, session) {

  raw <- reactive({
    if (is.null(input$file)) return(make_demo_data())
    sheets <- readxl::excel_sheets(input$file$datapath)
    ll <- readxl::read_excel(input$file$datapath, sheet = "linelist")
    vs <- readxl::read_excel(input$file$datapath, sheet = "visits")
    ll$onset_date  <- as.Date(ll$onset_date); vs$visit_date <- as.Date(vs$visit_date)
    ct <- if ("contacts" %in% sheets) readxl::read_excel(input$file$datapath, sheet = "contacts")
          else tibble(from = character(), to = character(), link_type = character())
    validate(
      need(all(c("case_id", "onset_date") %in% names(ll)),
           "linelist sheet must contain case_id and onset_date."),
      need(all(c("case_id", "setting_name", "setting_type") %in% names(vs)),
           "visits sheet must contain case_id, setting_name and setting_type."))
    list(linelist = ll, visits = vs, contacts = ct)
  })

  observeEvent(raw(), {
    d <- raw(); rng <- range(c(d$linelist$onset_date, d$visits$visit_date), na.rm = TRUE)
    updateSliderInput(session, "asof", min = rng[1], max = rng[2], value = rng[2])
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

  filtered <- reactive({
    d  <- raw()
    ll <- d$linelist |> filter(onset_date <= input$asof)
    vs <- d$visits   |> filter(setting_type %in% input$types, case_id %in% ll$case_id,
                                is.na(visit_date) | visit_date <= input$asof)
    ct <- d$contacts |> filter(from %in% ll$case_id, to %in% ll$case_id)
    list(linelist = ll, visits = vs, contacts = ct)
  })

  netdata <- reactive({
    f <- filtered(); p <- params()
    switch(input$view,
      projection = build_setting_projection(f$visits, f$linelist),
      bipartite  = build_bipartite(f$visits, f$linelist, p$inf_before, p$inf_after),
      contacts   = {
        ct <- if (input$susp_source == "derive")
          derive_suspected_links(f$linelist, f$visits, p$inc_min, p$inc_max,
                                 p$inf_before, p$inf_after)
        else f$contacts
        build_contacts_network(f$linelist, ct, f$visits)
      })
  })

  output$net <- renderVisNetwork({
    nd <- netdata(); v <- input$view
    vn <- visNetwork(nd$nodes, nd$edges) |>
      visOptions(highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE),
                 nodesIdSelection = TRUE) |>
      visPhysics(stabilization = TRUE,
                 barnesHut = list(gravitationalConstant = -3500, springLength = 130))
    vn <- if (v == "contacts") visEdges(vn, arrows = "to", smooth = TRUE)
          else if (v == "bipartite") visEdges(vn, smooth = FALSE)
          else visEdges(vn, smooth = TRUE, color = list(color = "#9aa0a6", opacity = 0.7))
    leg <- lapply(names(setting_colours), function(s)
      list(label = s, shape = if (v == "bipartite") "square" else "dot",
           color = unname(setting_colours[[s]])))
    if (v == "bipartite") leg <- c(leg, list(list(label = "Case", shape = "dot", color = CASE_COLOUR)))
    vn |> visLegend(useGroups = FALSE, addNodes = leg, position = "left", width = 0.18)
  })

  output$curve   <- renderPlotly({ epi_curve(filtered()$linelist) })

  output$metrics <- renderDT({
    mt   <- network_metrics(netdata()$nodes, netdata()$edges)
    tips <- vapply(names(mt),
                   function(n) if (n %in% names(metric_tips_lookup)) metric_tips_lookup[[n]] else "", character(1))
    datatable(mt, rownames = FALSE,
              options = list(pageLength = 8, dom = "tp", headerCallback = header_tooltips(unname(tips))))
  })

  output$ll <- renderDT({
    f  <- filtered()
    nv <- f$visits |> distinct(case_id, setting_name) |> count(case_id, name = "settings_visited")
    df <- f$linelist |> left_join(nv, by = "case_id") |>
      mutate(settings_visited = tidyr::replace_na(settings_visited, 0L))
    tips <- vapply(names(df),
                   function(n) if (n %in% names(ll_tips_lookup)) ll_tips_lookup[[n]] else "", character(1))
    datatable(df, rownames = FALSE,
              options = list(pageLength = 6, scrollX = TRUE, dom = "tp",
                             headerCallback = header_tooltips(unname(tips))))
  })
}

shinyApp(ui, server)
