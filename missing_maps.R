# Function to test if species has valid geometry
check_species_map <- function(sp){
  map <- tryCatch(get_mdd_map(sp), error = function(e) NULL)
  
  # Check if map is NULL or has zero geometries
  if(is.null(map) || inherits(map, "sf") && nrow(map) == 0 || inherits(map, "SpatVector") && nrow(map) == 0){
    return(FALSE)
  } else {
    return(TRUE)
  }
}

# Run check for all species
results <- data.frame(
  species = afro_names,
  has_map = sapply(afro_names, check_species_map)
)

# Species missing ranges
missing_species <- results %>% filter(!has_map)

print(missing_species)

# The results indicate that the only African species missing is T. senegalensis
# I've downloaded it manually.

# -------------------------------
# Load your KML for Trichechus senegalensis
# -------------------------------
senegalensis_sf <- st_read("Trichechus_senegalensis.kml", quiet = TRUE)

# Make sure it is in the same CRS as the other maps (lon/lat WGS84)
senegalensis_sf <- st_transform(senegalensis_sf, 4326)

# Convert to terra SpatVector (matches 'maps' object)
senegalensis_vect <- vect(senegalensis_sf)

# Add it to the maps list
maps[["Trichechus senegalensis"]] <- senegalensis_vect