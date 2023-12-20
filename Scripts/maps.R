#Libraries
library(data.table)
library(terra)
library(purrr)
library(tidyterra)
library(rnaturalearth)
library(patchwork)
library(sf)

#Folder containing outputs from FishMIP models
base_folder <- "/rd/gem/private/users/camillan/Extract_tcblog10_Data/Output/sumSize_annual/sizeConsidered10g_10kg/EEZsummaries/gridded_outputs/"
#Listing all relevant files to calculate biomass projections
global_files <- list.files(base_folder, full.names = T)
#Models
members <- str_extract(global_files, "outputs//(.*)_(h|s)", group = 1) |> 
  unique()
#Keys
PICTS_keys <- read_csv("Outputs/SouthPacific_EEZ-GBR_keys.csv") |> 
  filter(name != "GBR")

for(m in members){
  #Load all data available for a single FishMIP model
  df_model <- str_subset(global_files, m) |> 
    #Ignore columns SOVEREIGN1-3 - not needed here
    map_df(~fread(., drop = paste0("SOVEREIGN", 1:3))) |> 
    #Extract data only for years to be used in maps
    filter(year >= 2010 & year <= 2020 | year >= 2045 & year <= 2055 | year >= 2085 & year <= 2095) |> 
    #Do not keep data before 2021 for scenario ssp585
    filter(!((year >= 2015 & year <= 2020) & scenario == "ssp585")) |> 
    #If EEZ is not a PICT mark as NA
    mutate(eez = case_when(!eez %in% PICTS_keys$MRGID ~ NA,
                           T ~ eez),
           #Create new group column to calculate means
           group = case_when(year <= 2020 ~ "reference",
                             year >= 2045 & year <= 2055 ~ "mean50",
                             year >= 2085 & year <= 2095 ~ "mean80"),
           #The mean50 and mean80 groups also need to have the scenario as part of the label
           group = case_when(group != "reference" ~ str_c(group, scenario, sep = "_"),
                             T ~ group)) |> 
    #Remove EEZs classified as NA (no PICTs)
    drop_na(eez) |> 
    #Calculate mean for ensemble member
    group_by(x, y, mem, esm, eez, GEONAME, group) |> 
    summarise(mean_bio = mean(biomass, na.rm = T)) |> 
    pivot_wider(names_from = group, values_from = mean_bio) |> 
    ungroup() |> 
    mutate(rel_change_mean50_ssp126 = ((mean50_ssp126-reference)/reference)*100,
           rel_change_mean50_ssp585 = ((mean50_ssp585-reference)/reference)*100,
           rel_change_mean80_ssp126 = ((mean80_ssp126-reference)/reference)*100,
           rel_change_mean80_ssp585 = ((mean80_ssp585-reference)/reference)*100)
    
  #Create name to save file  
  f_out <- file.path("Outputs", str_c(m, "_map_data.csv"))

  #Save results
  df_model |> 
    fwrite(f_out)
}

#Load grid sample
mask_base <- read_csv("Outputs/mask_1deg.csv") |> 
  select(!mask) |> 
  rename(x = Lon, y = Lat)

#Listing all relevant files to calculate biomass projections
maps_data <- list.files("Outputs/", pattern = "_map_data.csv", full.names = T) |> 
  map_df(~fread(.)) |> 
  #Calculations performed by year and EEZ
  group_by(x, y, eez, GEONAME) |> 
  #Apply calculations to biases only
  summarise(across(reference:rel_change_mean80_ssp585, 
                   #Listing statistics to be calculated
                   list(median = median), 
                   #Setting column names
                   .names = "{.col}_{.fn}")) |> 
  right_join(mask_base, by = c("x", "y")) |> 
  ungroup()


#Create raster with data frame above
reference <- maps_data |> 
  select(x, y, reference_median) |> 
  rast(crs = "epsg:4326") |> 
  rotate()

#Base map
world <- ne_countries(returnclass = "sf") |> 
  st_shift_longitude() |>
  filter(continent == "Oceania" | subregion == "South-Eastern Asia")

#picts
picts <- read_sf("Outputs/SouthPacific_EEZ-GBR.shp") |> 
  filter(name != "GBR") |> 
  st_shift_longitude()

main <- maps_data |> 
  mutate(x = x%%360) |> 
  ggplot(aes(x, y, fill = reference_median))+
  geom_tile()+
  scale_fill_distiller(palette = "YlGn", na.value = NA)+
  geom_sf(inherit.aes = F, data = world)+
  geom_sf(inherit.aes = F, data = picts, fill = NA, aes(color = id), 
          show.legend = F, linewidth = 0.5)+
  theme_bw()

p50_126 <- maps_data |>
  mutate(x = x%%360) |> 
  ggplot(aes(x, y, fill = rel_change_mean50_ssp126_median))+
  geom_tile()+
  scale_fill_distiller(palette = "BrBG", na.value = NA,
                       limits = c(-75, 75),
                       breaks = seq(-75, 75, length.out = 11))+
  geom_sf(inherit.aes = F, data = world)+
  geom_sf(inherit.aes = F, data = picts, fill = NA, aes(color = id), 
          show.legend = F, linewidth = 0.5)+
  theme_bw()+
  guides(fill = guide_legend(title = "% change"))+
  labs(title = "Mean % change 2045-2055 SSP1-2.6")

p50_585 <- maps_data |> 
  mutate(x = x%%360) |> 
  ggplot(aes(x, y, fill = rel_change_mean50_ssp585_median))+
  geom_tile()+
  scale_fill_distiller(palette = "BrBG", na.value = NA,
                       limits = c(-75, 75),
                       breaks = seq(-75, 75, length.out = 11))+
  geom_sf(inherit.aes = F, data = world)+
  geom_sf(inherit.aes = F, data = picts, fill = NA, aes(color = id), 
          show.legend = F, linewidth = 0.5)+
  theme_bw()+
  guides(fill = guide_legend(title = "% change"))+
  labs(title = "Mean % change 2045-2055 SSP5-8.5")

p80_126 <- maps_data |> 
  mutate(x = x%%360) |> 
  ggplot(aes(x, y, fill = rel_change_mean80_ssp126_median))+
  geom_tile()+
  scale_fill_distiller(palette = "BrBG", na.value = NA,
                       limits = c(-75, 75),
                       breaks = seq(-75, 75, length.out = 11))+
  geom_sf(inherit.aes = F, data = world)+
  geom_sf(inherit.aes = F, data = picts, fill = NA, aes(color = id), 
          show.legend = F, linewidth = 0.5)+
  theme_bw()+
  guides(fill = guide_legend(title = "% change"))+
  labs(title = "Mean % change 2085-2095 SSP1-2.6")

p80_585 <- maps_data |> 
  mutate(x = x%%360) |> 
  ggplot(aes(x, y, fill = rel_change_mean80_ssp585_median))+
  geom_tile()+
  scale_fill_distiller(palette = "BrBG", na.value = NA,
                       limits = c(-75, 75),
                       breaks = seq(-75, 75, length.out = 11))+
  geom_sf(inherit.aes = F, data = world)+
  geom_sf(inherit.aes = F, data = picts, fill = NA, aes(color = id), 
          show.legend = F, linewidth = 0.5)+
  theme_bw()+
  guides(fill = guide_legend(title = "% change"))+
  labs(title = "Mean % change 2085-2095 SSP5-8.5")



(p50_126+p50_585)/(p80_126+p80_585)

ggsave("Outputs/sample_maps_perc_change.pdf", device = "pdf", width = 14, height = 9)

