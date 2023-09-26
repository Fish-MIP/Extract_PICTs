#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
# library(shiny)
# library(plotly)
# library(DT)
# library(tidyverse)


#file="http://portal.sf.utas.edu.au/thredds/catalog/gem/fishmip/ISIMIP3a/InputData/fishing/histsoc/catalog.html?dataset=fishmip/ISIMIP3a/InputData/fishing/histsoc/calibration_catch_histsoc_1850_2004.csv"
#fishmip <- read_csv(file="http://portal.sf.utas.edu.au/thredds/fileServer/gem/fishmip/ISIMIP3a/InputData/fishing/histsoc/calibration_catch_histsoc_1850_2004.csv")
#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
## Loading R libraries

library(shiny)
library(plotly)
library(DT)
library(tidyverse)
library(ncdf4)
library(sass)

# library(reticulate)
# library(metR)
# library(lubridate)
library(raster)
library(sf)
library(terra)


# get the mask for regional ecosystem models
mask <- read.csv(file="../Data/FAO-EEZ-corrected_1degmask.csv")
PICTS_key<-read.csv(file="../Data/SouthPacific_EEZ-GBR_keys.csv")
PICTS_key$region<-paste("X",PICTS_key$ID,sep="")
mask<-mask[which(mask$region %in% PICTS_key$region),]
mask<-merge(mask,PICTS_key)[,-1]
names(mask)<-c("Lon","Lat","region","ID")
#THREDDS folder with the different climate forcings
regions<-unique(mask$region)

#thredds_dir<-"http://portal.sf.utas.edu.au/thredds/dodsC/gem/fishmip/PICTs/Yearly_Rasters/OutputData"
gem_dir<-"/rd/gem/private/fishmip_outputs/ISIMIP3b/OutputData/marine-fishery_global"
#model<-"APECOSM"
model <- c("APECOSM","BOATS","DBEM","DBPM","EcoOcean","EcoTroph","FEISTY","MACROECOLOGICAL","ZooMSS")
#ESMname ="ipsl-cm6a-lr"
ESMname =c("ipsl-cm6a-lr","gfdl-esm4")
#modelscen = "historical"
modelscen = c("historical","ssp126","ssp585")
varNames=c("tcb")


ui <- fluidPage(
  theme = bslib::bs_theme(bootswatch = "yeti"),
  titlePanel(title = span(img(src = "fishmiplogo.jpg", height = 35), "")),
  sidebarLayout(
    sidebarPanel(
      h2("FishMIP Output Explorer"),
      
      selectInput(inputId = "region", label = "Region:",
                  choices = regions,
                  selected = "Vanuatu"),
      
      selectInput(inputId = "model", label = "Model:",
                  choices = model,
                  selected = "APECOSM"),
      
      selectInput(inputId = "ESMname", label = "Earth System Model:",
                  choices = ESMname,
                  selected = "ipsl-cm6a-lr"),
      
      # select the scenario
      selectInput(inputId = "modelscen", "Scenario",
                  choices = modelscen,
                  selected = "historical"),
      
      
      #to select the variable
      selectInput("variable", "Variable:", choices=varNames,selected ="tcb"),
      
      
      downloadButton(outputId = "download_data", label = "Download"),
      br(),
      
      # Sidepanel instructions
      
      h4("Instructions:"),
      p("1. Select a region from the dropdown."),
      p("2. Choose a FishMIP-Earth System model"),
      p("3. Select the scenario"),
      p("4. Select the variable to plot"),
      p("5. Click the 'Download' button to download data."),
      p("6. View climatology and time-series plots to the right."),
      br(),
      p("Some selections make take longer to load.")
    ),
    mainPanel(
      em("Climatology"),
      plotlyOutput(outputId = "plot1",width="100%"),
      em("Monthly time-series (black) and long-term trend (blue)"),
      plotOutput(outputId = "plot2",width="100%"),
      br(),
      br()
    )
  )
)


server <- function(input, output) {
  
  
  
  
  filtered_mask <- reactive({
    
    subset(mask,
           region %in% input$region)
    
    # mask<-subset(mask,region %in% "Vanuatu")
    })
  
  
  filtered_data <- reactive({
    
    mask_to_use <- st_as_sf(filtered_mask(), coords = c("Lon", "Lat"))
    #mask_to_use <- st_as_sf(mask, coords = c("Lon", "Lat"))
    
    file_subdir<-paste(gem_dir,
                       model=input$model,
                       ESMname =input$ESMname,
                       modelscen=input$modelscen,sep="/")
    
    #file_subdir<-paste(gem_dir,model=model,ESMname =ESMname,modelscen=modelscen,sep="/")

    if (input$modelscen == "historical" & input$model %in% c("APECOSM","DBPM")){
    file_subdir<-paste(gem_dir,
                         model=input$model,
                         ESMname =input$ESMname,
                         modelscen=input$modelscen,sep="/")
    
    
     file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_monthly_1850_2014.nc",sep="_")
    }

    if (input$modelscen == "historical" & input$model %in% c("BOATS","EcoOcean","FEISTY","MACROECOLOGICAL","ZooMSS")){
      file_subdir<-paste(gem_dir,
                         model=input$model,
                         ESMname =input$ESMname,
                         modelscen=input$modelscen,sep="/")
      
      
      file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_monthly_1950_2014.nc",sep="_")
    }
    
    if (input$modelscen == "historical" & input$model %in% c("MACROECOLOGICAL","ZooMSS","EcoTroph")){
      file_subdir<-paste(gem_dir,
                         model=input$model,
                         ESMname =input$ESMname,
                         modelscen=input$modelscen,sep="/")
      
      
      file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_annual_1950_2014.nc",sep="_")
  
      
    }
    
    if (input$modelscen == "historical" & input$model %in% c("DBEM")){
      file_subdir<-paste(gem_dir,
                         model=input$model,
                         ESMname =input$ESMname,
                         modelscen=input$modelscen,sep="/")
      
      
      file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_annual_1951_2014.nc",sep="_")
     
    }
    
    
    
    if (input$modelscen != "historical"){
      file_subdir<-paste(gem_dir,
                         model=input$model,
                         ESMname =input$ESMname,
                         "future",sep="/")
      
      file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_monthly_2015_2100.nc",sep="_")
        if (input$model %in% c("MACROECOLOGICAL","ZooMSS","EcoTroph","DBEM")){
          file_name<-paste(model=str_to_lower(input$model),ESMname=input$ESMname,"nobasd",modelscen=input$modelscen,"nat","default",varNames=input$variable,"global_annual_2015_2100.nc",sep="_")
        }

             }
    
    #file_name<-paste(model=str_to_lower(model),ESMname=ESMname,"nobasd",modelscen=modelscen,"nat","default",varNames=varNames,"global_monthly_1850_2014.nc",sep="_")
    
    file_to_get<-paste(file_subdir,file_name,sep="/")
    
    # terra::rast("http://portal.sf.utas.edu.au/thredds/fileServer/gem/fishmip/ISIMIP3a/InputData/climate/ocean/obsclim/global/monthly/historical/GFDL-MOM6-COBALT2/gfdl-mom6-cobalt2_obsclim_intppdiat_60arcmin_global_monthly_1961_2010.nc")
    # nc<-terra::rast("Masks_netcdf_csv/gfdl-mom6-cobalt2_obsclim_intppdiat_60arcmin_global_monthly_1961_2010.nc")
    # nc<-ncdf4::nc_open(file="Masks_netcdf_csv/gfdl-mom6-cobalt2_obsclim_intppdiat_60arcmin_global_monthly_1961_2010.nc",return_on_error=TRUE)
    # file_to_get<-"Masks_netcdf_csv/gfdl-mom6-cobalt2_obsclim_intppdiat_60arcmin_global_monthly_1961_2010.nc"
    
    
    #file_to_get<-paste("apecosm_ipsl-cm6a-lr_nobasd_historical_nat_default_tcb_mean-yearly_1850_2014.nc")
    
    gridded_ts <- brick(file.path(file_to_get))
    #gridded_ts <- terra::rast(file.path(file_to_get))
    # Set the raster data's CRS to match the polygon's CRS
    #gridded_ts <- brick(file_to_get)
    crs(gridded_ts) = crs(mask_to_use)
    # Crop raster data to the extent of the polygon
    temp <- crop(gridded_ts, extent(mask_to_use))
    # Mask the cropped raster using the polygon
    gridded_ts <- mask(temp, mask_to_use)
    return(gridded_ts)
  })
  
  # gridded_ts_df <- as.data.frame(gridded_ts, xy = TRUE)
  # names(gridded_ts_df)<-c("lon","lat","var")
  #  
  # mean <- gridded_ts_df %>%
  # group_by(lat, lon) %>% 
  # summarise(mean = mean(var, na.rm = F))
  
  output$plot1 <- renderPlotly({
    #plot(mean(gridded_ts))
    #plot(mean(filtered_data()))
    #clim<-terra::app(filtered_data(),fun=mean,cores=5)
    #clim<-mean(gridded_ts)
    clim<-mean(filtered_data())
    clim_df<-as.data.frame(clim, xy = TRUE)
    names(clim_df)<-c("lon","lat","var")
    ggplotly({
      p<- ggplot() +
        geom_raster(data = clim_df , aes(x = lon, y = lat, fill = var)) +
        scale_fill_viridis_c(guide=guide_colorbar(title = paste(input$variable))) +
        coord_quickmap() +
        theme_classic()
      p
    })
    
    
  })
  
  output$plot2 <- renderPlot({
    ## calculate spatially weighthed average of variables selected
    #ts<-cellStats(filtered_data(), 'mean')
    #aggregation_function <- mean
    #ts<-terra::global(gridded_ts,mean)
    #ts<-cellStats(gridded_ts, 'mean')
    ts<-cellStats(filtered_data(), 'mean')
    #timevals<-seq(as.Date("1850-01-01"),as.Date("2014-12-01"), by="month")
    if(input$modelscen=="historical"& input$model %in% c("APECOSM","DBPM")){
      #timevals<-str_split(names(ts),"X")
      timevals<-seq(as.Date("1850-01-01"),as.Date("2014-12-01"), by="month")
    }
    
    if(input$modelscen=="historical"& input$model %in% c("BOATS","EcoOcean","EcoTroph","FEISTY")){
      #timevals<-str_split(names(ts),"X")
      timevals<-seq(as.Date("1950-01-01"),as.Date("2014-12-01"), by="month")
    }
    
    if(input$modelscen=="historical"& input$model %in% c("MACROECOLOGICAL","ZooMSS","EcoTroph")){
      #timevals<-str_split(names(ts),"X")
      timevals<-seq(as.Date("1950-01-01"),as.Date("2014-12-01"), by="year")
    }
    
    if(input$modelscen=="historical"& input$model %in% c("DBEM")){
      #timevals<-str_split(names(ts),"X")
      timevals<-seq(as.Date("1951-01-01"),as.Date("2014-12-01"), by="year")
    }
    
    if(input$modelscen!="historical"){
      #timevals<-str_split(names(ts),"X")
      timevals<-seq(as.Date("2015-01-01"),as.Date("2100-12-01"), by="month")
      if (input$model %in%c("MACROECOLOGICAL","ZooMSS","EcoTroph","DBEM")) {timevals<-seq(as.Date("2015-01-01"),as.Date("2100-12-01"), by="year")
      }
    }
    df<-data.frame(time=as.Date(timevals),val=ts)
    ggplot(df,aes(x=time,y=val)) +
      geom_line() + 
      geom_smooth(colour="steelblue")+
      theme_classic() +
      theme(axis.text = element_text(size=12),
            axis.title = element_text(size=14))+
      xlab("") +
      ylab(paste(input$variable))
    
    #plot(timevals,ts,typ="l",ylab=input$variable)
    
  })
  
  output$download_data <- downloadHandler(
    filename = "download_data.csv",
    content = function(file) {
      data<-as.data.frame(filtered_data(), xy = TRUE)
      if(input$modelscen=="historical"){
        #timevals<-str_split(names(ts),"X")
        timevals<-seq(as.Date("1850-01-01"),as.Date("2014-12-01"), by="month")
      }
      if(input$modelscen!="historical"){
        #timevals<-str_split(names(ts),"X")
        timevals<-seq(as.Date("2015-01-01"),as.Date("2100-12-01"), by="month")
      }
      colnames(data)<-c("lon","lat",as.character(timevals))
      write.csv(data, file, row.names = FALSE)
    }
  )
  
}

shinyApp(ui = ui, server = server)