library(shiny)
library(bslib)
library(visNetwork)
library(igraph)
library(plotly)
library(DT)
library(dplyr)
library(lubridate)
library(jsonlite)

# readxl uses compiled C libraries — may not be available in WebR
readxl_ok <- tryCatch({ library(readxl); TRUE }, error = function(e) FALSE)

ui <- page_fluid(
  theme = bs_theme(bootswatch = "flatly"),

  h2("Network Explorer — Shinylive compatibility test"),
  p("This page confirms which R packages are available in WebAssembly (WebR).
     Green = loaded OK. Any FAIL here needs a replacement in the main app."),

  card(
    card_header("Package availability"),
    card_body(tableOutput("pkg_status"))
  ),

  layout_columns(
    col_widths = c(6, 6),
    card(
      card_header("visNetwork + igraph rendering test"),
      card_body(visNetworkOutput("net", height = "280px"))
    ),
    card(
      card_header("plotly rendering test"),
      card_body(plotlyOutput("plt", height = "280px"))
    )
  ),

  card(
    card_header("DT table test"),
    card_body(DTOutput("tbl"))
  )
)

server <- function(input, output, session) {

  output$pkg_status <- renderTable({
    pkgs <- c("shiny", "bslib", "visNetwork", "igraph",
              "plotly", "DT", "dplyr", "lubridate", "jsonlite")

    versions <- sapply(pkgs, function(p) {
      tryCatch(as.character(packageVersion(p)), error = function(e) "FAIL")
    })

    data.frame(
      Package = c(pkgs, "readxl"),
      Result = c(
        ifelse(versions == "FAIL", "FAIL", paste("OK —", versions)),
        if (readxl_ok) paste("OK —", packageVersion("readxl"))
        else "FAIL — not in WebR repo; will need openxlsx2 as replacement"
      )
    )
  })

  output$net <- renderVisNetwork({
    # Simple ring graph to confirm igraph → visNetwork pipeline works
    g <- make_ring(6)
    V(g)$name  <- paste0("C-00", 1:6)
    V(g)$color <- "#4E79A7"
    d <- toVisNetworkData(g)
    visNetwork(d$nodes, d$edges, height = "280px") |>
      visNodes(shape = "circle") |>
      visOptions(highlightNearest = TRUE) |>
      visPhysics(stabilization = FALSE)
  })

  output$plt <- renderPlotly({
    df <- tibble(
      week  = seq(ymd("2024-01-01"), by = "week", length.out = 8),
      cases = c(1, 2, 4, 6, 3, 2, 1, 1)
    )
    plot_ly(df, x = ~week, y = ~cases, type = "bar",
            marker = list(color = "#4E79A7")) |>
      layout(xaxis = list(title = "Week of onset"),
             yaxis = list(title = "Cases"),
             title  = "Epidemic curve (synthetic test data)")
  })

  output$tbl <- renderDT({
    tibble(
      Component      = c("Network metrics", "Excel file upload", "Epidemic curve", "Data tables"),
      Package        = c("igraph", "readxl", "plotly", "DT"),
      `This session` = c(
        "See network above",
        if (readxl_ok) "Available" else "NOT AVAILABLE — needs openxlsx2",
        "See chart above",
        "This table is rendered by DT"
      )
    )
  }, options = list(dom = "t"), rownames = FALSE)
}

shinyApp(ui, server)
