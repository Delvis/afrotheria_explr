# =====================================
# Build Afrotheria Cache (FINAL)
# =====================================

library(terra)
library(sf)
library(dplyr)

# Load raw data
source("load_afrotheres.R")


# ---- Convert maps to sf ----
maps_sf <- lapply(names(maps), function(sp){
  
  x <- maps[[sp]]
  
  # skip empty geometries
  if(is.null(x) || nrow(x) == 0){
    return(NULL)
  }
  
  x_africa <- crop(x, africa_extent)
  
  if(is.null(x_africa) || nrow(x_africa) == 0){
    return(NULL)
  }
  
  st_as_sf(x_africa) |>
    mutate(species = sp)
})

# Remove NULLs
maps_sf <- maps_sf[!sapply(maps_sf, is.null)]


# ---- Combine ----
all_species_sf <- bind_rows(maps_sf) |>
  st_transform(4326)


# ---- Save raster separately ----
writeRaster(
  afro_richness,
  "afrotheria_richness_africa.tif",
  overwrite = TRUE
)


# ---- Save cache ----
saveRDS(
  list(
    all_species_sf = all_species_sf,
    africa_extent = africa_extent,
    build_date = Sys.Date(),
    data_version = "MDD v1.2"
  ),
  "afrotheria_cache.rds"
)


cat("Cache built successfully\n")
