library(data.table)
library(tidyverse)

#Folder containing outputs from FishMIP models
base_folder <- "/rd/gem/private/users/camillan/Extract_tcblog10_Data/Output/sumSize_annual/sizeConsidered10g_10kg/EEZsummaries/gridded_outputs/"

#Output folder
out_folder <- "Outputs/yearly_biomass_values"
  
#Create a new folder and store all data frames in preparation for compression
if(!dir.exists(out_folder)){
  dir.create(out_folder, recursive = T)
}

#Listing all relevant files to calculate biomass projections
global_files <- list.files(base_folder, full.names = T)

#Models
members <- str_extract(global_files, "outputs//(.*)_(h|s)", group = 1) |> 
  unique()

#Loading PICTs EEZ mask and GBR boundaries 
mask <- read_csv("Outputs/mask_1deg.csv") |> 
  #Adding names to identify PICTS
  left_join(read_csv("Outputs/SouthPacific_EEZ-GBR_keys.csv", col_select = c(name, MRGID)),
            by = c("mask"= "MRGID"))

#Defining function to extract biomass data for all PICTs from FishMIP outputs
for(m in members){
  da <- str_subset(global_files, m) |> 
    #Ignore columns SOVEREIGN1-3 - not needed here
    map_df(~fread(., drop = c(paste0("SOVEREIGN", 1:3), "area_m", "eez", "GEONAME"))) |> 
    #Select data from 1985
    filter(year >= 1985) |> 
    #Rename coordinates
    rename(Lon = x, Lat = y) |> 
    #Applying mask to classify by PICT
    right_join(mask, by = c("Lon", "Lat"))|> 
    #Remove grid cells that are not within PICT boundaries
    drop_na(mask) |> 
    #Remove GBR
    filter(mask != 9999) |> 
    #Reorganise data to calculate SSP2-4.5
    pivot_wider(names_from = scenario, values_from = biomass) |> 
    rowwise() |> 
    mutate(ssp245 = mean(c(ssp126, ssp585))) |> 
    ungroup() |> 
    #Merge mem and esm into a single column
    unite("mem", mem:esm, sep = "_", remove = T) |> 
    #Reorganise data to calculate summary statistics
    pivot_longer(historical:ssp245, names_to = "scenario", values_to = "biomass") |> 
    #Remove rows with NA values in biomass column
    drop_na(biomass) |>  
    #Calculation descriptive statistics
    group_by(year, mem, mask, name, scenario) |> 
    summarise(min = min(biomass, na.rm = T),
              mean = mean(biomass, na.rm = T),
              median = median(biomass, na.rm = T),
              sd = sd(biomass, na.rm = T),
              max = max(biomass, na.rm = T)) |> 
    ungroup() |> 
    #Reorganise data before saving
    pivot_wider(names_from = scenario, names_sep = "_", values_from = c(min, mean, median, sd, max))
  
  #Create name to save file  
  f_out <- file.path(out_folder, str_c(m, "_biomass_estimates.csv"))
  
  #Saving results for each model
  da |> 
    fwrite(f_out)
}

#Zip folder ready to share
zip(str_c(out_folder, ".zip"), out_folder)
