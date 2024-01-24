library(data.table)
library(tidyverse)

#Output folder
out_folder <- "Outputs"
  
#Create a new folder and store all data frames in preparation for compression
if(!dir.exists(out_folder)){
  dir.create(out_folder, recursive = T)
}

#Loading FishMIP biomass data
bio_picts <- read_csv("Outputs/average_yearly_means_picts_1985-2100.csv")|>
  #Removing GBR data
  filter(mask != 9999)

#Loading PICTs EEZ mask and GBR boundaries 
mask <- read_csv("Outputs/mask_1deg.csv") |> 
  #Adding names to identify PICTS
  left_join(read_csv("Outputs/SouthPacific_EEZ-GBR_keys.csv", col_select = c(name, MRGID)),
            by = c("mask"= "MRGID"))

#Calculating scenario SSP2-4.5
ensemble_bio <- bio_picts |> 
  #Reorganise data to calculate SSP2-4.5
  pivot_wider(names_from = scenario, values_from = mean_annual_bio) |> 
  rowwise() |> 
  mutate(ssp245 = mean(c(ssp126, ssp585))) |> 
  ungroup() |> 
  #Applying mask to classify by PICT
  right_join(mask |> distinct(mask, name), by = "mask") |>
  #Reorganise data to calculate summary statistics
  pivot_longer(historical:ssp245, names_to = "scenario", values_to = "biomass") |> 
  #Remove rows with NA values in biomass column
  drop_na(biomass) |>  
  #Calculation descriptive statistics
  group_by(year, mask, name, scenario) |> 
  summarise(min = min(biomass, na.rm = T),
            mean = mean(biomass, na.rm = T),
            median = median(biomass, na.rm = T),
            sd = sd(biomass, na.rm = T),
            max = max(biomass, na.rm = T)) |> 
  ungroup() |> 
  #Reorganise data before saving
  pivot_wider(names_from = scenario, names_sep = "_", values_from = c(min, mean, median, sd, max)) |> 
  #Sort by mask ID
  arrange(mask)
  
#Create name to save file  
f_out <- file.path(out_folder, "fishmip_ensemble_biomass_estimates.csv")
  
#Saving results for each model
ensemble_bio |> 
  write_csv(f_out)
