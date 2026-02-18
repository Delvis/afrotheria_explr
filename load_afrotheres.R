# =========================================
# Afrotheria Richness Map for Africa 
# =========================================

library(mdd)
library(terra)
library(dplyr)
library(ggplot2)
library(viridis)
library(rnaturalearth)
library(rnaturalearthdata)

# -------------------------------
# 1. Load species list
# -------------------------------
species.list <- read.csv("MDD_v1.2_6485species.csv")

# Filter Afrotheria
afrotheres <- species.list[species.list$majorSubtype %in% "Afrotheria", ]

# Convert scientific names from underscores to spaces
afro_names <- gsub("_", " ", afrotheres$sciName)

# -------------------------------
# 2. Download range maps safely
# -------------------------------
maps <- list()
for (sp in afro_names) {
  cat("Downloading:", sp, "\n")
  maps[[sp]] <- tryCatch(get_mdd_map(sp), error = function(e) NA)
}

source("missing_maps.R") # gets the African manatee

# Keep only successfully downloaded maps
maps <- maps[!sapply(maps, function(x) all(is.na(x)))]

# Convert to terra SpatVectors if needed
maps <- lapply(maps, function(x) {
  if (inherits(x, "sf")) vect(x) else x
})

# -------------------------------
# 3. Define African extent
# -------------------------------
africa_extent <- ext(-25, 60, -35, 38)  # xmin, xmax, ymin, ymax

# -------------------------------
# 4. Rasterize species ranges
# -------------------------------
# Define raster template for Africa (0.5° resolution)
template <- rast(
  extent = africa_extent,
  res = 0.5,
  vals = 0
)

# Rasterize each species
raster_list <- lapply(maps, function(x) {
  x_africa <- crop(x, africa_extent)  # crop to Africa
  rasterize(x_africa, template, field = 1, background = 0)
})

# -------------------------------
# 5. Stack rasters and compute richness
# -------------------------------
rstack <- rast(raster_list)
afro_richness <- sum(rstack)

# -------------------------------
# 6. Plot richness map
# -------------------------------
plot(
  afro_richness,
  main = "Afrotheria Species Richness in Africa",
  col = viridis(20),
  axes = TRUE,
  box = TRUE
)

# Optional: save raster for future use
writeRaster(afro_richness, "afrotheria_richness_africa.tif", overwrite = TRUE)

# -------------------------------
# 6. Convert raster to dataframe
# -------------------------------
afro_df <- as.data.frame(afro_richness, xy = TRUE)
colnames(afro_df) <- c("x", "y", "richness")

# Remove NA or zero cells if desired
afro_df <- afro_df %>% filter(!is.na(richness) & richness > 0)

# -------------------------------
# 7. Get Africa country borders
# -------------------------------
africa_countries <- ne_countries(
  continent = "Africa",
  returnclass = "sf"
)

arabian_countries <- ne_countries(returnclass = "sf") %>% 
  filter(admin %in% c("Saudi Arabia", "Yemen", "Oman", "United Arab Emirates", 
                      "Qatar", "Bahrain", "Kuwait"))

afroarabia_countries <- rbind(africa_countries, arabian_countries)


# -------------------------------
# 8. Plot richness map
# -------------------------------
p <- ggplot() +
  geom_raster(data = afro_df, aes(x = x, y = y, fill = richness)) +
  geom_sf(data = afroarabia_countries, fill = NA, color = "black", size = 0.4) +
  scale_fill_viridis(
    name = "Species Richness",
    option = "F",
    direction = -1
  ) +
  coord_sf(xlim = c(-25, 60), ylim = c(-35, 38), expand = FALSE) +
  labs(
    title = "Afrotheria Species Richness in Afroarabia",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    legend.position = "right",
    plot.title = element_text(hjust = 0.5, face = "bold")
  )

# -------------------------------
# 9. Save high-resolution image
# -------------------------------
ggsave(
  filename = "afrotheria_richness_afroarabia.png",
  plot = p,
  width = 12,
  height = 10,
  dpi = 360  # retina quality
)

