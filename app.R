# =========================================
# AfrotheriAtlas v2
# Interactive Afrotheria Community Explorer
# =========================================

library(shiny)
library(leaflet)
library(sf)
library(terra)
library(dplyr)
library(DT)
library(viridis)
library(shinycssloaders)

# -------------------------------
# 1. Load cached data
# -------------------------------
if(!file.exists("afrotheria_cache.rds")){
  stop("Cache not found. Run build_afrotheres_cache.R first.")
}

cache <- readRDS("afrotheria_cache.rds")
all_species_sf <- cache$all_species_sf
africa_extent  <- cache$africa_extent

# Load richness raster separately
afro_richness <- rast("afrotheria_richness_africa.tif")
afro_richness <- project(afro_richness, "EPSG:4326") # lon/lat

# -------------------------------
# 2. Point query function
# -------------------------------
get_species_at_point <- function(lat, lng){
  pt <- st_sfc(st_point(c(lng, lat)), crs = 4326)
  hits <- st_intersects(pt, all_species_sf, sparse = FALSE)
  unique(all_species_sf$species[hits[1,]])
}

# -------------------------------
# 3. UI
# -------------------------------
ui <- fluidPage(
  
  titlePanel("AfrotheriAtlas 🐘🗺️ — Afrotheria Community Explorer"),
  
  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectInput(
        "species_filter",
        "Highlight species:",
        choices = c("All", sort(unique(all_species_sf$species)))
      ),
      downloadButton("download", "Download Community"),
      hr(),
      h4("Community Composition"),
      DTOutput("species_table")
    ),
    
    mainPanel(
      leafletOutput("map", height = 650) |> withSpinner(),
      br(),
      plotOutput("hist", height = 200)
    )
  )
)

# -------------------------------
# 4. Server
# -------------------------------
server <- function(input, output, session){
  
  current_species <- reactiveVal(character(0))
  
  # ---- Render Leaflet map ----
  output$map <- renderLeaflet({
    
    pal <- colorNumeric(
      palette = viridis(20),
      domain = values(afro_richness),
      na.color = "transparent"
    )
    
    leaflet() %>%
      addProviderTiles("CartoDB.Positron", group = "Base map") %>%
      
      # Species polygons layer
      addPolygons(
        data = all_species_sf,
        fillColor = "green",
        fillOpacity = 0.15,
        color = "black",
        weight = 0.3,
        group = "Species ranges"
      ) %>%
      
      # Richness raster layer
      addRasterImage(
        afro_richness,
        colors = pal,
        opacity = 1,
        group = "Species richness"
      ) %>%
      
      # Layer control: radio base groups
      addLayersControl(
        baseGroups = c("Species ranges", "Species richness"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>%
      
      addScaleBar(position = "bottomleft", options = scaleBarOptions(imperial = FALSE)) %>%
      
      setView(lng = 20, lat = 0, zoom = 3)
  })
  
  # ---- Click query ----
  observeEvent(input$map_click, {
    lat <- input$map_click$lat
    lng <- input$map_click$lng
    sp <- get_species_at_point(lat, lng)
    current_species(sp)
    
    # Add marker
    leafletProxy("map") %>%
      clearMarkers() %>%
      addMarkers(lng = lng, lat = lat)
  })
  
  # ---- Species table ----
  output$species_table <- renderDT({
    sp <- current_species()
    if(length(sp) == 0) return(NULL)
    
    datatable(
      data.frame(Species = sort(sp)),
      rownames = FALSE,
      options = list(pageLength = 10, dom = "tip")
    )
  })
  
  # ---- Download community ----
  output$download <- downloadHandler(
    filename = function() paste0("afrotheria_community_", Sys.Date(), ".csv"),
    content = function(file){
      sp <- current_species()
      if(length(sp) == 0){
        write.csv(data.frame(), file, row.names = FALSE)
        return()
      }
      
      # Get last clicked coordinates
      click <- input$map_click
      lat <- click$lat
      lng <- click$lng
      
      # Compute richness at point
      richness_val <- length(sp)
      
      df <- data.frame(
        richness = richness_val,
        lat = lat,
        lng = lng,
        species = sp
      )
      
      write.csv(df, file, row.names = FALSE)
    }
  )
  
  
  # ---- Richness histogram ----
  output$hist <- renderPlot({
    sp <- current_species()
    if(length(sp) == 0) return(NULL)
    
    vals <- values(afro_richness)
    vals <- vals[!is.na(vals)]
    
    # Compute histogram without plotting to get midpoints
    h <- hist(vals, breaks = seq(0, max(vals), by = 1), plot = FALSE)
    
    # Plot histogram
    plot(h, col = "grey80", border = "white",
         main = "Richness Distribution", xlab = "Species Richness")
    
    # Find the bin midpoint for the clicked richness
    richness_val <- length(sp)
    # closest midpoint
    bin_idx <- which.min(abs(h$mids - richness_val))
    abline(v = h$mids[bin_idx], col = "#3498db", lwd = 3)
  })
  
  
  # ---- Species highlighting ----
  observe({
    req(input$species_filter)
    
    leafletProxy("map") %>%
      clearGroup("highlight")
    
    if(input$species_filter != "All"){
      sel <- all_species_sf |> filter(species == input$species_filter)
      leafletProxy("map") %>%
        addPolygons(
          data = sel,
          fillColor = "red",
          fillOpacity = 0.4,
          color = "darkred",
          weight = 1,
          group = "highlight"
        )
    }
  })
  
}

# -------------------------------
# 5. Run App
# -------------------------------
shinyApp(ui, server)
