# =============================================================================
# ARCHIVED PAGES — reference shelf, NOT sourced by the app
# =============================================================================
# This file is a parking lot for pages and their supporting code that have been
# removed from app.R but may be re-added later. It is deliberately NOT sourced by
# app.R and does not run. Treat it as a snapshot, not live code:
#   - Code here may drift out of sync with the current schema over time.
#   - To restore a page, lift the relevant UI + server + helper blocks back into
#     app.R and re-test in RStudio.
#
# A faithful full-app snapshot from just before these removals also exists in git
# under the tag:  pre-page-removal-2026-06-22
#
# Removed on 2026-06-22 (branch: amendments-batch-1):
#   1. Data tab            — epidemic curve + filtered line list (+ filter banner)
#   2. Possible links tab  — candidate transmission links view
#
# NOTE: the "Network metrics — most connected nodes" table that used to sit on
# the Data tab was NOT removed. It was relocated into a slide-out overlay panel
# on the Network model page (handle on the right edge). Its server code
# (output$metrics) and metric_tips_lookup therefore remain live in app.R.
# =============================================================================


# =============================================================================
# 1. DATA TAB  (removed 2026-06-22)
# =============================================================================
# Held a filter-summary banner, the epidemic curve, the network metrics table
# (now relocated — see note above) and the filtered line list.

# ---- UI (was a nav_panel in the page_navbar) --------------------------------
# nav_panel("Data",
#   div(style = "max-width:1100px; margin:0 auto; padding:8px 4px;",
#     uiOutput("filter_summary"),
#     card(
#       card_header(class = "d-flex justify-content-between align-items-center",
#         span("Epidemic curve",
#              info("New cases per week by onset date. A rising curve means the outbreak is still growing.")),
#         div(class = "d-flex align-items-center gap-2",
#           tags$span("Colour by", class = "small text-muted"),
#           div(style = "min-width:180px;",
#             selectInput("curve_group", NULL,
#                         choices = c("No grouping" = "none"), width = "180px")))),
#       plotlyOutput("curve", height = "320px")),
#     layout_columns(col_widths = c(6, 6),
#       card(min_height = "440px",
#            hdr("Network metrics — most connected nodes",
#                "Ranks nodes by how connected they are. Hover the column headings for definitions."),
#            DTOutput("metrics")),               # <-- relocated to network overlay, still live
#       card(min_height = "440px",
#            hdr("Line list (filtered)",
#                "Case records currently shown, with how many contexts each visited. Hover headings for definitions."),
#            DTOutput("ll"))))),

# ---- Server: epidemic curve -------------------------------------------------
output$curve   <- renderPlotly({
  grp <- if (is.null(input$curve_group)) "none" else input$curve_group
  ttl <- curve_title(input$asof, input$types,
                     unique(raw()$contexts$context_type), input$case_status_filter)
  epi_curve(filtered()$cases, group_by = grp, title = ttl)
})

# ---- Server: filter summary banner ------------------------------------------
# Plain-language banner on the Data tab summarising the filters currently applied.
# Filters live on the Network model tab; this just reflects their state here.
output$filter_summary <- renderUI({
  dr <- input$asof
  date_txt <- if (length(dr) == 2)
    paste0(format(dr[1], "%d %b %Y"), " to ", format(dr[2], "%d %b %Y")) else "all dates"
  all_types <- unique(raw()$contexts$context_type)
  ctx_txt <- if (length(input$types) == 0 || length(input$types) >= length(all_types))
    "all context types" else paste(input$types, collapse = ", ")
  conf_txt <- if (length(input$case_status_filter) == 0)
    "none selected" else paste(input$case_status_filter, collapse = ", ")
  div(class = "alert alert-light border d-flex flex-wrap gap-3 align-items-center py-2 mb-3",
      role = "status",
      tags$span(tags$strong("Dates: "), date_txt),
      tags$span(tags$strong("Contexts: "), ctx_txt),
      tags$span(tags$strong("Case confidence: "), conf_txt),
      tags$span(class = "text-muted ms-auto small",
                "Filters are changed on the ", tags$strong("Network model"), " tab."))
})

# ---- Server: filtered line list ---------------------------------------------
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

# ---- Server: curve_group choices (was inside observeEvent(raw(), {...})) -----
# These lines populated the epi-curve "Colour by" selector when new data loaded.
# Re-insert into the existing observeEvent(raw(), {...}) block if restoring.
#   # Offer epi-curve colour-by options only for attributes present in the data
#   grp_opts <- c("No grouping" = "none")
#   if ("vaccination_status" %in% names(d$cases)) grp_opts <- c(grp_opts, "Vaccination status" = "vaccination_status")
#   if ("gender" %in% names(d$cases))             grp_opts <- c(grp_opts, "Gender" = "gender")
#   if ("case_status" %in% names(d$cases))        grp_opts <- c(grp_opts, "Case confidence" = "case_status")
#   updateSelectInput(session, "curve_group", choices = grp_opts, selected = "none")

# ---- Helper: epi_curve ------------------------------------------------------
# Draws a weekly bar chart of new cases by onset date.
# week_start = 1 means weeks run Monday–Sunday (ISO standard).
# group_by optionally colours (stacks) bars by a case attribute; missing values
# are grouped as "Unknown". Built with ggplot2 then converted to plotly.
epi_curve <- function(ll, group_by = "none", title = NULL) {
  if (nrow(ll) == 0) return(plotly_empty())
  ll <- ll |> mutate(week = floor_date(onset_date, "week", week_start = 1))
  if (group_by != "none" && group_by %in% names(ll)) {
    gv <- as.character(ll[[group_by]])
    ll$.grp <- ifelse(is.na(gv) | trimws(gv) == "", "Unknown", gv)
    d <- ll |> count(week, .grp)
    p <- ggplot2::ggplot(d, ggplot2::aes(week, n, fill = .grp)) +
      ggplot2::geom_col() +
      ggplot2::labs(x = "Week of onset", y = "New cases", fill = NULL, title = title)
  } else {
    d <- ll |> count(week)
    p <- ggplot2::ggplot(d, ggplot2::aes(week, n)) +
      ggplot2::geom_col(fill = "#2c7fb8") +
      ggplot2::labs(x = "Week of onset", y = "New cases", title = title)
  }
  ggplotly(p + ggplot2::theme_minimal(base_size = 12))
}

# ---- Helper: curve_title ----------------------------------------------------
# Builds a descriptive epi-curve title covering person, place and time from the
# active filters, so the chart documents exactly which subset of cases it shows.
curve_title <- function(date_range, context_types, all_context_types, statuses) {
  person <- if (length(statuses) == 0) "Cases" else paste0(nice_join(statuses), " cases")
  # Only name contexts when filtered to a genuine subset of those available
  place  <- if (length(context_types) && length(context_types) < length(all_context_types))
              paste0(" in ", nice_join(context_types)) else ""
  time   <- if (length(date_range) == 2)
              paste0(", ", format(date_range[1], "%d %b %Y"), " to ", format(date_range[2], "%d %b %Y")) else ""
  paste0(person, place, " by week of onset", time)
}

# ---- Helper: nice_join (used only by curve_title) ---------------------------
# Joins a character vector into a natural-language list:
# "a", "a and b", or "a, b and c".
nice_join <- function(x) {
  if (length(x) <= 1) return(paste(x, collapse = ""))
  paste(paste(x[-length(x)], collapse = ", "), "and", x[length(x)])
}

# ---- Lookup: ll_tips_lookup (line-list column tooltips) ---------------------
ll_tips_lookup <- c(
  case_id            = "Unique identifier for each case.",
  onset_date         = "Date the case first developed symptoms. Drives the time slider, epidemic curve and infectious-period logic.",
  age_group          = "Age band of the case.",
  gender             = "Recorded gender of the case.",
  vaccination_status = "Recorded measles vaccination status of the case.",
  case_status        = "Case confidence — how firmly the case is classified: Confirmed, Probable, or Possible.",
  contexts_visited   = "Number of distinct contexts this case is recorded as having visited.")


# =============================================================================
# 2. POSSIBLE LINKS TAB  (removed 2026-06-22)
# =============================================================================
# Showed candidate case-to-case transmission links derived from shared contexts
# and onset timing, excluding pairs already captured by likely_index_case.

# ---- UI (was a nav_panel in the page_navbar) --------------------------------
# nav_panel("Possible links",
#   div(style = "max-width:1200px; margin:0 auto; padding:8px 4px;",
#     card(card_body(
#       p("Candidate case-to-case links derived from shared contexts and onset timing, using the epi parameters on the ",
#         tags$strong("Assumptions & parameters"), " tab. Only pairs ",
#         tags$strong("not already captured by the likely_index_case field"), " are shown."),
#       p(class = "text-muted mb-0",
#         "Use the table below to assess each candidate. Recording an accepted link is done by updating ",
#         tags$code("likely_index_case"), " in your data."))),
#     card(hdr("Candidate network",
#              "Possible undetected links shown as orange dashed arrows. Node colour = primary context type."),
#          visNetworkOutput("possible_links_net", height = "40vh")),
#     card(hdr("Assessment table",
#              "One row per candidate pair. Sortable and filterable. Use exposure_relevance to judge plausibility — pairs where neither case has a relevant classification at the shared context are weaker candidates."),
#          DTOutput("possible_links_table")))),

# ---- Server: possible_links_data --------------------------------------------
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

# ---- Server: possible_links_table -------------------------------------------
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
    `Source confidence`  = source_status,
    `Case confidence`    = case_status)
  datatable(display, rownames = FALSE, filter = "top",
            options = list(pageLength = 15, scrollX = TRUE, dom = "lftip"))
})

# ---- Server: possible_links_net ---------------------------------------------
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

# ---- Helper: derive_possible_links ------------------------------------------
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

# ---- Helper: build_possible_net ---------------------------------------------
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
