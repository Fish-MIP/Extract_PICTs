# Extract PICTs
This repository contains the workflow developed to extract ISIMIP3B (CMIP6) input and output data for all scenarios to carry out vulnerability assessments for the South Pacific by the [Fisheries and Marine Ecosystem Model Intercomparison Project (Fish-MIP) group](https://www.isimip.org/about/marine-ecosystems-fisheries/).  
  
The workflow includes a combination of `R` and `Python` scripts.
  
## Model data
All model data used in this workflow is hosted in the [DKRZ server](https://www.dkrz.de/en). If you do not have a DKRZ account, you can set up a new account by following [these instructions](https://www.isimip.org/dashboard/accessing-isimip-data-dkrz-server/).  
  
Note that all `Python` scripts (`*.py`) can be run directly in the DKRZ server. To do this, you will need to do the following after connecting to DKRZ:
1. Load the `Python` module using the following line: `module load python3`.
2. Run the `*.py` scripts of interest. For example: `python3 NAME_OF_SCRIPT.py`.
  
## Economic Exclusive Zone (EEZ) shapefile
The EEZs shapefile came from [VLIZ](https://doi.org/10.14284/386). You will need to download these files before you can create the mask used in this workflow to extract relevant data.  
  
## Running scripts in your local machine
All `Python` scripts containing `Python` code (including files ending in `*.py`, `*.Rmd`, and `*.ipynb`) can be run in your local machine. You will need to make sure that all `Python` packages and their dependencies included in these files are installed locally. You do not need to install packages individually, instead we are including an `environment.yml` file, which has all necessary information to replicate the environment in which these scripts where developed.  
  
You will need to have `anaconda` or `miniconda` installed in your local machine before you can use the `environment.yml` file to start the installation of all necessary packages. Open the Anaconda Prompt and type the following line: `conda env create -f environment.yml`. This process make take a few minutes. When installation is completed, you can check the environment has been successfully installed by typing the following line: `conda env list`. If the `CMIP6_data` environment is printed in your screen, you have installed all necessary `Python` packages successfully. You will need to activate this environment by typing `conda activate CMIP6_data` before you can run the `Python` scripts in this repository.  
  
**Note that you will need to install the environment in your local machine only once, but you will need to activate the environment before running any scripts.**  
