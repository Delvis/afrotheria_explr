library(shiny)
library(leaflet)
library(sf)
library(terra)
library(dplyr)

# Load your data
source("load_afrotheres.R")

# Prepare sf polygons
maps_sf <- lapply(names(maps), function(sp){
  
  x <- maps[[sp]]
  x_africa <- crop(x, africa_extent)
  
  st_as_sf(x_africa) |>
    mutate(species = sp)
})

all_species_sf <- bind_rows(maps_sf)
all_species_sf <- st_transform(all_species_sf, 4326)


# Function: species at point
get_species_at_point <- function(lat, lng){
  
  pt <- st_sfc(
    st_point(c(lng, lat)),
    crs = 4326
  )
  
  hits <- st_intersects(pt, all_species_sf, sparse = FALSE)
  
  unique(all_species_sf$species[hits[1,]])
}


# ---- UI ----
ui <- fluidPage(
  
  titlePanel("AfrotheriAtlas: Afrothere Species Query"),
  
  leafletOutput("map", height = 700),
  
  verbatimTextOutput("info")
)


# ---- SERVER ----
server <- function(input, output){
  
  output$map <- renderLeaflet({
    
    leaflet(all_species_sf) %>%
      addProviderTiles("CartoDB.Positron") %>%
      addPolygons(
        fillColor = "green",
        fillOpacity = 0.1,
        color = "black",
        weight = 0.3
      ) %>%
      setView(lng = 20, lat = 0, zoom = 3)
    
  })
  
  
  observeEvent(input$map_click, {
    
    lat <- input$map_click$lat
    lng <- input$map_click$lng
    
    sp <- get_species_at_point(lat, lng)
    
    output$info <- renderText({
      
      if(length(sp) == 0){
        
        "No Afrotheria species here."
        
      } else {
        
        paste0(
          "Richness: ", length(sp), "\n\n",
          paste(sp, collapse = ", ")
        )
        
      }
      
    })
    
  })
  
}


shinyApp(ui, server)
