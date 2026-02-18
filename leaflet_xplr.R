# =========================================
# Interactive Afrotheria Map for Africa
# =========================================

# Load libraries
library(terra)
library(leaflet)
library(dplyr)

# -------------------------------
# 1. Source the first script
# -------------------------------
source("load_afrotheres.R")  # your first script

# -------------------------------
# 2. Prepare species presence polygons
# -------------------------------
# We want a list of species polygons cropped to Africa
# 'maps' already contains SpatVectors for each species

# Crop each species to Africa and convert to sf for leaflet
maps_sf <- lapply(names(maps), function(sp) {
  x <- maps[[sp]]
  x_africa <- crop(x, africa_extent)  # ensure only Africa
  sf::st_as_sf(x_africa) %>% mutate(species = sp)
})
names(maps_sf) <- names(maps)

# -------------------------------
# 3. Combine into one dataframe for leaflet
# -------------------------------
all_species_sf <- dplyr::bind_rows(maps_sf)

# -------------------------------
# 4. Create interactive leaflet map
# -------------------------------
leaflet_map <- leaflet(all_species_sf) %>%
  addProviderTiles("CartoDB.Positron") %>%
  addPolygons(
    fillColor = "green",
    fillOpacity = 0.1,
    color = "black",
    weight = 0.3,
    label = ~species,  # shows species on hover
    highlightOptions = highlightOptions(
      weight = 2,
      color = "blue",
      bringToFront = TRUE,
      fillOpacity = 0.6
    )
  ) %>%
  setView(lng = 20, lat = 0, zoom = 3) %>%  # center on Africa
  addLegend(
    position = "bottomright",
    colors = "green",
    labels = "Afrotheria species range",
    opacity = 0.5
  )

# -------------------------------
# 5. Print interactive map
# -------------------------------
leaflet_map
