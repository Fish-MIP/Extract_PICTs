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

#Indicate location of EEZ masks and area rasters and transform from km2 to m2
area_60arcmin = xr.open_dataarray('Masks/PICT/masked-grid-area_ipsl-cm6a-lr_60arcmin.nc')*1e6
#Mask for DBPM model
area_120arcmin = xr.open_dataarray('Masks/PICT/masked-grid-area_ipsl-cm6a-lr_120arcmin.nc')*1e6

#Indicate experiments of interest
experiment = ['historical', 'picontrol', 'ssp126', 'ssp585']

#Indicate models of interest
models = ['GFDL-ESM4', 'IPSL-CM6A-LR']

#Loading data that is not CF compliant
def load_ds_noncf(fn, start, end):
    '''
    This function loads non-CF compliant datasets where dates cannot be read. It takes the following inputs:
    fn - ('string') refers to full filepath where the non-CF compliant dataset is located
    start - ('numeric') refers to the start year of the dataset
    end - ('numeric') refers to the end year of the dataset
    The start and end parameters are used to present dates correctly in the time dimension
    '''
    ds = xr.open_dataset(fn, decode_times = False)
    #Get start and end years for projections
    years = (end-start)+1
    if len(ds.time)/years == 1:
        freq = 'YS'
    elif len(ds.time)/years == 12:
        freq = 'MS'
    ds['time'] = pd.date_range(f'{start}-01-01', periods = len(ds.time), freq = freq)
    return ds

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
  file_list = glob(os.path.join(dp, '*.nc'))
  exps = [e for e in experiment if e in dp][0]
  #Find the correct folder to store files
  dir_out =  base_out + re.split(base_dir, dp)[-1]
  #Ensure folder exists
  os.makedirs(dir_out, exist_ok = True)
  
  for f in file_list:
    ###Loop through each file
    var_int = re.split('_\\d{2,3}a', re.split(f'{exps}_', f)[-1])[0]
    #Extracting base file name to create output
    base_file = re.split(dp+'/', f)[-1].replace('global_', 'SouthPacific-GBR_mean-').replace('.nc', '.csv')
    path_out = os.path.join(dir_out, base_file)
    #Getting start and end of data
    yr_min_hist, yr_max_hist = re.split("_", re.findall("\d{4}_\d{4}", re.split("/", f)[-1])[0])
    
    #Loading data
    try:
        ds = xr.open_dataset(f)
    except:
        print('Time in historical data is not cf compliant. Fixing dates based on years in file name.')
        try:
          ds = load_ds_noncf(f, int(yr_min_hist), int(yr_max_hist))
        except:
          print(f'Could NOT open file: {f}')
    
    #Loading correct grid area and mask rasters that match the model
    if '60arc' in f:
      area = area_60arcmin
    elif '120arc' in f:
      area = area_120arcmin
    
    #Getting name of variable in dataset
    vars_list = list(ds.keys())
    if len(vars_list) > 1:
      var_ds = [v for v in vars_list if v in var_int][0]
    else:
      var_ds = vars_list[0]
    #Turning into data array and rechunking data
    try:
      ds = ds[var_int].chunk({'time': 12})
    except:
      ds = ds[var_ds].chunk({'time': 12})
    #Adding mask
    ds.coords['mask'] = (('lat', 'lon'), area.mask.values)

    #Calculating monthly means
    month_mean = []
    for yr, da in ds.groupby('time.year'):
      for mth, da_m in da.groupby('time.month'):
          month_mean.append(da_m.groupby('mask').mean())
    month_mean = xr.concat(month_mean, dim = 'time')
    #Saving results
    #If depth (lev) is included in the dataset, the select top 200 m
    if 'lev' in month_mean.coords:
      month_mean = month_mean.sel(lev = slice(0, 200))
      for i, d in enumerate(month_mean.lev.values):
        if len(np.unique(month_mean.lev.values)) < len(month_mean.lev.values):
          depth = i
        else:
          depth = str(int(d))
        path_out_d = re.split(var_int, path_out)
        path_out_d =  f'{path_out[0]}{var_int}_depth-{depth}m{path_out[1]}'
        month_mean.isel(lev = i).to_pandas().to_csv(path_out_d, na_rep = np.nan)
    else:
      month_mean.to_pandas().to_csv(path_out, na_rep = np.nan)
