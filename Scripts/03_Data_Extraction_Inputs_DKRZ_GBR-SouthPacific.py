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
base_out = 'Extract_PICTs/InputData'

#Base directory where data is currently stored
base_dir = '/work/bb0820/ISIMIP/ISIMIP3b/InputData/climate/ocean/uncorrected/global/monthly'

#Calculate distance from coastline and mask - 50 km from coastline
#Also calculate means for entire EEZ
#Indicating location of masks
#Depth mask
# depth_mask = xr.open_dataarray('/work/bb0820/ISIMIP/ISIMIP3b/InputData/geo_conditions/ocean/ipsl-cm6a-lr_r1i1p1f1_picontrol_deptho_60arcmin_global_fixed.nc')

#EEZs and GBR mask- change to meters before applying weights
area = xr.open_dataarray('Masks/PICT/masked-grid-area_ipsl-cm6a-lr_60arcmin.nc')
#Removing latitudes outside area of interest and masking open ocean areas
# area = area.where(depth_mask < 200)
#Calculating total area per AOI
mask_area_tot = area.groupby('mask').sum()

#Remove depth mask - no longer needed
# del depth_mask

#Indicate experiments of interest
experiment = ['historical', 'picontrol', 'ssp126', 'ssp585']

#Indicate models of interest
models = ['GFDL-ESM4', 'IPSL-CM6A-LR']


###### Defining useful functions ######

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


## Extracting surface data
def masking_data(ds, var_int):
  #Getting name of variables available in dataset
  var_ds = list(ds.keys())
  #If there are multiple variable, keep variable that is similar to variable in file name
  if len(var_ds) > 1:
    var_ds = [v for v in var_ds if v in var_int][0]
  else:
    var_ds = var_ds[0]
  #Extracting only variable of interest
  try:
    ds = ds[var_int].chunk({'time': 12})
  except:
    ds = ds[var_ds].chunk({'time': 12})
  
  #Checking if dataset has depth levels - If so, keep only surface data
  if 'lev' in ds.coords:
    ds = ds.isel(lev = 0)
  elif 'olevel' in ds.coords:
    ds = ds.isel(olevel = 0)
  elif 'olevel_2' in ds.coords:
    ds = ds.isel(olevel_2 = 0)
  
  #Return masked dataset
  return ds

## Calculating mean grid cell values for surface 
#Yearly weighted average
def weighted_mean(ds, mask, mask_area_total, path_out_nc, path_out_csv):
  #Multiplying values for grid cell area
  ds_weight = ds*mask
  #Calculating means per month/year
  year_mean = []
  try:
    for yr, da in ds_weight.groupby('time.year'):
      year_mean.append(da.groupby('mask').sum())
  except:
    for yr, da in ds_weight.groupby('year'):
      year_mean.append(da.groupby('mask').sum())
  
  #Transform data frame into data array
  year_mean = xr.concat(year_mean, dim = 'time')
  #Divide by total area per EEZ/GBR
  year_mean = year_mean/mask_area_total

  #Saving results
  #Netcdf output
  year_mean.to_netcdf(path_out_nc)
  #CSV output
  year_mean.to_pandas().to_csv(path_out_csv, na_rep = np.nan)

#### Applying functions to all files in directories of interest
#Ensuring base directory exists
os.makedirs(base_out, exist_ok = True)

dir_str = []
#Constructing full directory paths - Adding experiment
for exp in experiment:
  #Adding models
  for m in models:
    fp = os.path.join(base_dir, exp, m)
    dir_str.append(fp)

###Loop through each directory
for dp in dir_str:
  #Find netcdf files for expriments and models of interest
  file_list = glob(os.path.join(dp, '*60arcmin*.nc'))
  exps = [e for e in experiment if e in dp][0]
  #Find the correct folder to store files
  dir_out =  base_out + re.split(base_dir, dp)[-1]
  #Ensure folder exists
  os.makedirs(dir_out, exist_ok = True)
  
  for f in file_list:
    ###Loop through each file
    var_int = re.split('_\\d{2,3}a', re.split(f'{exps}_', f)[-1])[0]
    #Extracting base file name to create output
    base_file = re.split(dp+'/', f)[-1].replace('global_monthly', 'SouthPacific-GBR_weighted-mean-yearly')
    path_out_ncfile = os.path.join(dir_out, base_file)
    path_out_csvfile = path_out_ncfile.replace('.nc', '.csv')
    
    #Loading data
    try:
        ds = xr.open_dataset(f)
    except:
        print('Time in historical data is not cf compliant. Fixing dates based on years in file name.')
        try:
          ds = load_ds_noncf(f)
        except:
          print(f'Time could not be decoded for file: {f}')
          pass
    
    #Masking data and calculating weighted mean
    try:
      ds is not None
      try:
        ds_mask = masking_data(ds, var_int)
        del ds
        weighted_mean(ds_mask, area, mask_area_tot, path_out_ncfile, path_out_csvfile)
      except:
        print(f'File could not be processed: {f}')
        pass
    except:
      pass
    

