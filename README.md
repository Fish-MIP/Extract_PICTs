[![FAIR checklist badge](https://fairsoftwarechecklist.net/badge.svg)](https://fairsoftwarechecklist.net/v0.2?f=21&a=30112&i=31321&r=123)

# Assessing fish biomass changes in Pacific Island Countries and Territories (PICTs) under different climate change scenarios
This repository contains the workflow developed to extract ISIMIP3B (CMIP6) input and output data for all scenarios to carry out vulnerability assessments for the South Pacific by the [Fisheries and Marine Ecosystem Model Intercomparison Project (Fish-MIP) group](https://www.isimip.org/about/marine-ecosystems-fisheries/).  
  
The workflow includes a combination of `R` (files ending in `.Rmd` and `.md`) and `Python` (files ending in `.py`) scripts. These files can be found under the `Scripts` folder.  
  
**Note:** You will notice that there are two `R` files with the same name, but different files extension (`.Rmd` and `.md`). These two files contain the same information, the difference is that the `.md` files are shown nicely in GitHub, while the `.Rmd` files are easier to work with in RStudio. In other words, if you would like to have a quick look at the content of the `R` scripts in your browser, we recommend you use the files ending in `.md`. But if you would like to run the script in your own computer, we recommend you use the files ending in `.Rmd`.  
  
## Model data
All model data used in this workflow is hosted in the [DKRZ server](https://www.dkrz.de/en). If you do not have a DKRZ account, you can set up a new account by following [these instructions](https://www.isimip.org/dashboard/accessing-isimip-data-dkrz-server/).  
  
Note that all `Python` scripts (`*.py`) can be run directly in the DKRZ server. To do this, you will need to do the following after connecting to DKRZ:
1. Load the `Python` module using the following line: `module load python3`.
2. Run the `*.py` scripts of interest. For example: `python3 NAME_OF_SCRIPT.py`.
  
## Economic Exclusive Zone (EEZ) shapefile
The EEZs shapefile came from [VLIZ](https://doi.org/10.14284/386). You will need to download these files before you can create the mask used in this workflow to extract relevant data.  
  
## Running scripts in your local machine

### `Python` scripts
All `Python` scripts containing `Python` code (files ending in `*.py`) can be run in your local machine, but you will need remote access to the DKRZ server to access model data. You will need to make sure that all `Python` packages and their dependencies included in these files are installed locally. You do not need to install packages individually, instead we are including an `requirements.txt` file, which has all necessary information to replicate the environment in which these scripts where developed.  
  
You will need to have `anaconda` or `miniconda` installed in your local machine before you can use the `requirements.txt` file to start the installation of all necessary packages. Open the Anaconda Prompt and type the following line: `conda create -n ENVNAME --file requirements.txt`. This process make take a few minutes. When installation is completed, you can check the environment has been successfully installed by typing the following line: `conda env list`. If the new environment is printed in your screen, you have installed all necessary `Python` packages successfully. You will need to activate this environment by typing `conda activate ENVNAME` before you can run the `Python` scripts in this repository.  
  
**Note that you will need to install the environment in your local machine only once, but you will need to activate the environment before running any scripts.**  
  
### `R` scripts
If you are using the `R` notebooks, run the following two lines in the RStudio console:  
  
```
  source("installing_R_libraries.R")  
  checking_libraries()
```
  
The lines above will run a function that automatically checks if any `R` libraries used in this repository are not installed in your machine. If any libraries are missing, it will install them automatically. Bear in mind that these notebooks were developed in `R` version 4.3.0, so you may need to upgrade your `R` version if you encounter any problems during package installation.
  
## Do you have any comments or questions?
If you found any issues with the code, have questions, or ideas on how to improve the code, you can reach out by creating a [new issue](https://github.com/Fish-MIP/Extract_PICTs/issues).  
  
