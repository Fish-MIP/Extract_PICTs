#!/usr/bin/python

#Libraries
import numpy as np
import xarray as xr
import pandas as pd
from glob import glob
import os
import re

#######################################################################################
#Base directory where outputs will be saved
base_out = 'Extract_PICTs/OutputData'

#Base directory where data is currently stored
base_dir = '/work/bb0820/ISIMIP/ISIMIP3b/OutputData/marine-fishery_global/'

#Indicate location of EEZ masks and area rasters and transform from km2 to m2
area_all = xr.open_dataarray('Masks/PICT/masked-grid-area_1deg.nc')*1e6
#Mask for DBPM model
area_DBPM = xr.open_dataarray('Masks/PICT/masked-grid-area_1deg_DBPM.nc')*1e6
#Mask for DBEM model
area_DBEM = xr.open_dataarray('Masks/PICT/masked-grid-area_05deg.nc')*1e6

#Calculating total area per AOI
tot_area_all = area_all.groupby('mask').sum()
tot_area_DBPM = area_DBPM.groupby('mask').sum()
tot_area_DBEM = area_DBEM.groupby('mask').sum()

#Ensuring base directory exists
os.makedirs(base_out, exist_ok = True)

#Defining useful functions
## Loading data with dates that are not CF compliant
def load_ds_noncf(fn):
    '''
    This function loads non-CF compliant datasets where dates cannot be read. It needs one input:
    fn - ('string') refers to full filepath where the non-CF compliant dataset is located
    '''
    #Loading dataset without decoding times
    ds = xr.open_dataset(fn, decode_times = False)
    
    #Checking time dimension attributes
    #Extracting reference date from units 
    init_date = re.search('\\d{4}-\\d{1,2}-\\d{1,2}', ds.time.attrs['units']).group(0)
    
    #If month is included i the units calculate monthly timesteps
    if 'month' in ds.time.attrs['units']:
      #If month values include decimals, remove decimals
      if ds.time[0] % 1 != 0:
        ds['time'] = ds.time - ds.time%1
      #From the reference time, add number of months included in time dimension
      try:
        new_date = [pd.Period(init_date, 'M')+pd.offsets.MonthEnd(i) for i in ds.time.values]
        #Change from pandas period to pandas timestamp
        new_date =[pd.Period.to_timestamp(i) for i in new_date]
      #If any errors are encountered
      except:
        #If dates are before 1677, then calculate keep pandas period
        new_date = pd.period_range(init_date, periods = len(ds.time.values), freq ='M')
        #Add year and month coordinates in dataset
        ds.coords['year'] = ('time', new_date.year.values)
        ds.coords['month'] = ('time', new_date.month.values)
    
    #Same workflow as above but based on daily timesteps
    elif 'day' in ds.time.attrs['units']:
      if ds.time[0] % 1 != 0:
        ds['time'] = ds.time - ds.time%1
      try:
        new_date = [pd.Period(init_date, 'D')+pd.offsets.Day(i) for i in ds.time.values]
        new_date =[pd.Period.to_timestamp(i) for i in new_date]
      except:
        new_date = pd.period_range(init_date, periods = len(ds.time.values), freq ='D')
        ds.coords['year'] = ('time', new_date.year.values)
        ds.coords['month'] = ('time', new_date.month.values)
    
    #Replace non-cf compliant time to corrected time values
    ds['time'] = new_date
    return ds

#Defining function to calculate sum of values per FAO and EEZ area per month
#Annual weighted mean
def weighted_means(ds, mask, total_area_mask, file_out):
    '''
    This function calculates the sum of biomass per month per regions included in area data array.
    It takes the following inputs:
    ds - ('data array') refers to data array containing data upon which means will be calculated
    mask - ('data array') contains area per pixel and boundaries within which weighted means will 
    be calculated
    file_out - ('string') contains the file path and base file name to be used to save results
    '''
    #Creating empty array to store results
    year_mean = []
    #Multiplying dataset by area in m2
    ds_area = ds*mask
    #Calculating weighted means per year and per region
    if '/picontrol/' not in file_out:
      for yr, da in ds_area.groupby('time.year'):
        #Calculate mean across time and then across space
        da_corr = da.mean('time').groupby('mask').sum()
        #Divide by total area per EEZ/GBR
        da_corr = da_corr/total_area_mask
        #Add year
        da_corr.coords['year'] = yr
        year_mean.append(da_corr)
    else:
      for yr, da in ds_area.groupby('year'):
        #Calculate mean across time and then across space
        da_corr = da.mean('time').groupby('mask').sum()
        #Divide by total area per EEZ/GBR
        da_corr = da_corr/total_area_mask
        #Add year
        da_corr.coords['year'] = yr
        #Add to list holding results
        year_mean.append(da_corr)
    
    #Create data array with results 
    year_mean = xr.concat(year_mean, dim = 'year')
    #Saving results
    yr_min = str(year_mean.year.values.min())
    yr_max = str(year_mean.year.values.max())
    if 'bins' in year_mean.coords:
      for i, b in enumerate(year_mean.bins.values):
        if len(np.unique(year_mean.bins.values)) < len(year_mean.bins.values):
          bin_number = i
        else:
          bin_number = str(int(b))
        path_out_csv = f'{file_out}weighted-mean-yearly_bin-{bin_number}_{yr_min}_{yr_max}.csv'
        path_out_nc = f'{file_out}weighted-mean-yearly_bin-{bin_number}_{yr_min}_{yr_max}.nc'
        year_mean.isel(bins = i).to_pandas().to_csv(path_out_csv, na_rep = np.nan)
        year_mean.isel(bins = i).to_netcdf(path_out_nc)
    else:
      path_out_csv = f'{file_out}weighted-mean-yearly_{yr_min}_{yr_max}.csv'
      path_out_nc = f'{file_out}weighted-mean-yearly_{yr_min}_{yr_max}.nc'
      year_mean.to_pandas().to_csv(path_out_csv, na_rep = np.nan)
      year_mean.to_netcdf(path_out_nc)


#Go through each model/esm/activity and find netcdf files for variable of interest
file_key = f'*/*/*/*.nc'
file_list = glob(os.path.join(base_dir, file_key))

#Saving names of experiments and ESMs to save results of work in the same directory structure
dir_str = []
#Getting list of experiments
for exp in os.listdir(base_dir):
  dir_list = [os.path.join(exp, e) for e in os.listdir(os.path.join(base_dir, exp))]
  #For each experiment get a list of ESMs
  for esm in dir_list:
      dir_list = [os.path.join(esm, a) for a in os.listdir(os.path.join(base_dir, esm))]
      #For each experiment and ESM combination, get a list of files
      for d in dir_list:
          dir_str.append(d)

#Looping through list of files
for f in file_list:
  var_int = re.split('_global', re.split('default_', f)[-1])[0]
  #Find the correct folder to store files
  dir_out =  [d for d in dir_str if d in f]
  #Get the model and ESM to find the correct projection files
  exp, esm = re.split("/", dir_out[0])[:-1]
  print(exp, esm)
  #Looping through each output file
  if len(dir_out) > 1:
    print("check the output directory folder")
  else:
    path_out = os.path.join(base_out, dir_out[0])
    #Ensure folder exists
    os.makedirs(path_out, exist_ok = True)
    #Extracting base file name to create output
    base_file = re.split("global_", re.split("/", f)[-1])[0]
    #Loading datasets
    try:
      ds = xr.open_dataset(f)
    except:
      print('Time in historical data is not cf compliant. Fixing dates based on years in file name.')
      try:
          ds = load_ds_noncf(f)
      except:
          print(f'{f} could not be opened.')
    #Chunking large files
    if exp.lower() == "feisty" and 'gfdl' in esm.lower():
      ds = ds.chunk({'time': 12})
    #Ensure flag values 1e20 are masked
    if (~np.isfinite(ds[var_int])).sum() == 0:
      ds = ds.where(ds < 1e20)
    #Load the correct grid area and mask rasters that match the model
    if (exp.lower() == "dbpm") or ('ipsl' in esm.lower() and exp.lower() == 'zoomss'):
      area = area_DBPM
      tot_area = tot_area_DBPM
    elif exp.lower() == "dbem":
      area = area_DBEM
      tot_area = tot_area_DBEM
    else:
      area = area_all
      tot_area = tot_area_all
    #Calculating monthly sums per EEZ and FAO regions and saving to disk
    weighted_means(ds[var_int], area, tot_area, os.path.join(path_out, base_file))
