library(terra)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(metR)
library(dplyr)
library(viridis)

# ----------------------------------
# Compute richness (true integer)
# ----------------------------------

afro_richness <- rast("afrotheria_richness_africa.tif")
ext_expanded <- ext(afro_richness)
ext_expanded[3] <- ext_expanded[3] - 3  # Lower the Y-min (Southern boundary)
afro_extended <- extend(afro_richness, ext_expanded)

# ----------------------------------
# Smooth raster (Gaussian kernel ~1 cell radius)
# ----------------------------------

w <- focalMat(afro_extended, d = 1, type = "Gauss")
afro_smooth <- focal(
  afro_extended,
  w = w,
  fun = sum,
  na.rm = TRUE,
  pad = TRUE,     # keeps edges from being NA
  NAonly = FALSE
)

# Rescale
afro_smooth_scaled <- afro_smooth *
  max(values(afro_richness)) /
  max(values(afro_smooth))

# ----------------------------------
# Convert rasters to dataframes
# ----------------------------------

afro_df <- as.data.frame(afro_richness, xy = TRUE)
colnames(afro_df) <- c("x", "y", "richness")
afro_df <- afro_df %>% filter(!is.na(richness) & richness > 0)

afro_df_smooth <- as.data.frame(afro_smooth_scaled, xy = TRUE)
colnames(afro_df_smooth) <- c("x", "y", "richness")
afro_df_smooth <- afro_df_smooth %>% filter(!is.na(richness))

# ----------------------------------
# Contour breaks: larger intervals for smooth plots
# ----------------------------------

max_r <- max(values(afro_richness), na.rm = TRUE)
breaks <- seq(1, max_r, by = 2)  # 1,3,5,7,... up to max richness

# ----------------------------------
# Load Africa outline (continent only)
# ----------------------------------

africa_outline <- ne_countries(continent = "Africa", returnclass = "sf")

# ----------------------------------
# 1. Smoothed contours only
# ----------------------------------

p_smooth <- ggplot() +
  geom_sf(data = africa_outline, fill = NA, color = "lightgrey", linewidth = 0.5) +
  geom_contour(data = afro_df_smooth, aes(x = x, y = y, z = richness),
               breaks = breaks, color = "black", linewidth = 0.5) +
  geom_text_contour(data = afro_df_smooth, aes(x = x, y = y, z = richness),
                    breaks = breaks, size = 3, stroke = 0.2) +
  labs(title = "Isoclines of Afrothere diversity across Africa (smoothed, d=1)",
       x = "Longitude", y = "Latitude") +
  theme_minimal(base_size = 14)

# ----------------------------------
# 2. Raw integer contours (unsmoothed)
# ----------------------------------

p_contours_raw <- ggplot() +
  geom_sf(data = africa_outline, fill = NA, color = "lightgrey", linewidth = 0.5) +
  geom_contour(data = afro_df, aes(x = x, y = y, z = richness),
               breaks = seq(1, max_r, 1), color = "black", linewidth = 0.4) +
  geom_text_contour(data = afro_df, aes(x = x, y = y, z = richness),
                    breaks = breaks, size = 3, stroke = 0.2) +
  labs(title = "Isoclines of Afrothere diversity across Africa (raw)",
       x = "Longitude", y = "Latitude") +
  theme_minimal(base_size = 14)

# ----------------------------------
# 3. Smoothed contours + true richness raster behind
# ----------------------------------

p_smooth_overlay <- ggplot() +
  geom_raster(data = afro_df, aes(x = x, y = y, fill = richness)) +
  geom_sf(data = africa_outline, fill = NA, color = "lightgrey", linewidth = 0.5) +
  geom_contour(data = afro_df_smooth, aes(x = x, y = y, z = richness),
               breaks = breaks, color = "black", linewidth = 0.5) +
  geom_text_contour(data = afro_df_smooth, aes(x = x, y = y, z = richness),
                    breaks = breaks, size = 3, stroke = 0.2) +
  scale_fill_viridis(name = "Species Richness", option = "F", direction = -1) +
  labs(title = "Afrotheria: species richness + smoothed isoclines (d=1)",
       x = "Longitude", y = "Latitude") +
  theme_minimal(base_size = 14)

# ----------------------------------
# Optional: save plots
# ----------------------------------

ggsave("afro_richness_contours_smooth.png", p_smooth, width = 12, height = 10, dpi = 300)
ggsave("afro_richness_contours_raw.png", p_contours_raw, width = 12, height = 10, dpi = 300)
ggsave("afro_richness_smooth_overlay.png", p_smooth_overlay, width = 12, height = 10, dpi = 300)

# ----------------------------------
# Display plots
# ----------------------------------

p_smooth
p_contours_raw
p_smooth_overlay
