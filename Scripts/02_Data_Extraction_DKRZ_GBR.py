#!/usr/bin/python

#Libraries
import numpy as np
import xarray as xr
import pandas as pd
from glob import glob
import os
import re

#######################################################################################
#Variables between the hash lines can be edited
#Variable of interest - as it appears in the models
var_int = input('Write the name of the variable you want to process: ')
#Keywords used to identified the files that will be processed
#These keywords must be present in all files across all models
file_key = input('Write the common file pattern (e.g., *_default_tc_g*.nc): ')
#file_key = '*_default_tc_g*.nc'

#Base directory where outputs will be saved
base_out = 'Extract_PICTs'

#Base directory where data is currently stored
base_dir = '/work/bb0820/ISIMIP/ISIMIP3b/OutputData/marine-fishery_global/'

#Indicate location of EEZ masks and area rasters and transform from km2 to m2
area_all = xr.open_dataarray('Masks/PICT/masked-grid-area_1deg.nc')*1e6
#Mask for DBPM model
area_DBPM = xr.open_dataarray('Masks/PICT/masked-grid-area_1deg_DBPM.nc')*1e6
#Mask for DBEM model
area_DBEM = xr.open_dataarray('Masks/PICT/masked-grid-area_05deg.nc')*1e6
#######################################################################################


#######################################################################################
#The section below will use the input above to find datasets of interest and calculate
#weighted means per year and sector.

#Ensuring base directory exists
os.makedirs(base_out, exist_ok = True)

#Go through each model/esm/activity and find netcdf files for variable of interest
file_key = f'*/*/*/{file_key}'
file_list = glob(os.path.join(base_dir, file_key))
#Removing any files for "picontrol" activity
file_list = [f for f in file_list if "picontrol" not in f]

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

#Defining function to calculate sum of values per FAO and EEZ area per month
def monthly_sum(ds, mask, file_out):
    '''
    This function calculates the sum of biomass per month per regions included in area data array.
    It takes the following inputs:
    ds - ('data array') refers to data array containing data upon which means will be calculated
    mask - ('data array') contains area per pixel and boundaries within which weighted means will 
    be calculated
    file_out - ('string') contains the file path and base file name to be used to save results
    '''
    #Creating empty array to store results
    month_sum = []
    #Multiplying dataset by area in m2
    ds_area = ds*mask
    #Getting timesteps from original dataset
    timesteps = pd.to_datetime([t.isoformat() for t in ds.indexes['time']])
    #Calculating sums per year, per month and per region
    for yr, da in ds_area.groupby('time.year'):
        for mth, da_m in da.groupby('time.month'):
            month_sum.append(da_m.groupby('mask').sum())
    #Create data array with results and transforming to tonnes
    month_sum = xr.concat(month_sum, dim = 'time')*1e-6
    #Adding correct time dimension
    month_sum['time'] = timesteps
    #Saving results
    yr_min = str(ds.time.dt.year.values.min())
    yr_max = str(ds.time.dt.year.values.max())
    if 'bins' in month_sum.coords:
      for i, b in enumerate(month_sum.bins.values):
        if len(np.unique(month_sum.bins.values)) < len(month_sum.bins.values):
          bin_number = i
        else:
          bin_number = str(int(b))
        path_out = f'{file_out}global_tonnes_bin-{bin_number}_{yr_min}_{yr_max}.csv'
        month_sum.isel(bins = i).to_pandas().to_csv(path_out, na_rep = np.nan)
    else:
      path_out = f'{file_out}global_tonnes_{yr_min}_{yr_max}.csv'
      month_sum.to_pandas().to_csv(path_out, na_rep = np.nan)

#Getting list of historical and future projection experiments
file_hist = [f for f in file_list if "historical" in f]
file_non_hist = [f for f in file_list if "historical" not in f]
#Looping through list of files
for f in file_hist:
    #Find the correct folder to store files
    dir_out =  [d for d in dir_str if d in f]
    #Get the model and ESM to find the correct projection files
    exp, esm = re.split("/", dir_out[0])[:-1]
    print(exp, esm)
    future_paths = [d for d in file_non_hist if exp in d]
    future_paths = [d for d in future_paths if esm in d]
    dir_out_future = [d for d in dir_str if d in future_paths[0]]
    if len(dir_out) > 1:
        print("check the output directory folder")
    else:
        path_out = os.path.join(base_out, dir_out[0])
        path_out_future = os.path.join(base_out, dir_out_future[0])
        #Ensure folder exists
        os.makedirs(path_out, exist_ok = True)
        os.makedirs(path_out_future, exist_ok = True)
        #Extracting base file name to create output
        base_file = re.split("global_", re.split("/", f)[-1])[0]
        base_file_126 = re.split("global_", re.split("/", [d for d in future_paths if 'ssp126' in d][0])[-1])[0]
        base_file_585 = re.split("global_", re.split("/", [d for d in future_paths if 'ssp585' in d][0])[-1])[0]
        #Loading datasets
        #Historical
        #Get start and end years for data
        yr_min_hist, yr_max_hist = re.split("_", re.findall("\d{4}_\d{4}", re.split("/", f)[-1])[0])
        try:
            ds = xr.open_dataset(f).sel(time = slice('1950', '2015'))
        except:
            print('Time in historical data is not cf compliant. Fixing dates based on years in file name.')
            try:
                ds = load_ds_noncf(f, int(yr_min_hist), int(yr_max_hist)).sel(time = slice('1950', '2015'))
            except:
                print(f'{f} could not be opened.')
        #Get start and end years for projections
        yr_min_fut, yr_max_fut = re.split("_", re.findall("\d{4}_\d{4}", re.split("/", future_paths[0])[-1])[0])
        ds_126 = load_ds_noncf([d for d in future_paths if 'ssp126' in d][0], int(yr_min_fut), int(yr_max_fut))
        ds_585 = load_ds_noncf([d for d in future_paths if 'ssp585' in d][0], int(yr_min_fut), int(yr_max_fut))
        if exp.lower() == "feisty" and 'gfdl' in esm.lower():
            ds = ds.chunk({'time': 12})
            ds_126 = ds_126.chunk({'time': 12})
            ds_585 = ds_585.chunk({'time': 12})
        #Ensure flag values 1e20 are masked
        if (~np.isfinite(ds[var_int])).sum() == 0:
            ds = ds.where(ds < 1e20)
            ds_126 = ds_126.where(ds_126 < 1e20)
            ds_585 = ds_585.where(ds_585 < 1e20)
        #Load the correct grid area and mask rasters that match the model
        if (exp.lower() == "dbpm") or ('ipsl' in esm.lower() and exp.lower() == 'zoomss'):
            area = area_DBPM
        elif exp.lower() == "dbem":
            area = area_DBEM
        else:
            area = area_all
        #Calculating monthly sums per EEZ and FAO regions and saving to disk
        #Historical
        monthly_sum(ds[var_int], area, os.path.join(path_out, base_file))
        #SSP126
        monthly_sum(ds_126[var_int], area, os.path.join(path_out_future, base_file_126))
        #SSP585
        monthly_sum(ds_585[var_int], area, os.path.join(path_out_future, base_file_585))
