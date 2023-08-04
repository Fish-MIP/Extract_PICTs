#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
library(shiny)
library(plotly)
library(DT)
library(tidyverse)


fishmip <- read.csv(file="http://portal.sf.utas.edu.au/thredds/fileServer/gem/fishmip/FAO_report/EEZ_tcb.csv")

#fishmip <- read.csv(file="http://portal.sf.utas.edu.au/thredds/fileServer/gem/fishmip/FAO_report/EEZ_tcb_disaggregated.csv")

# percentchange only
  fishmip <- fishmip[fishmip$dataType=="per",]
  fishmip <- fishmip[fishmip$value !="Inf",]
# fishmip <- fishmip[fishmip$esm =="gfdl-esm4",]
#  fishmip <- fishmip[fishmip$esm =="ipsl-cm6a-lr",]
  
  # ipsl-cm6a-lr
# multimodel mean & sd
# fishmip<-fishmip %>% group_by(year,EEZ,ssp) %>%
#   summarise(mean = mean(value,na.rm=T), sd = sd(value,na.rm=T),median=median(value,na.rm=T),min=min(value,na.rm=T),max=max(value,na.rm=T))

 fishmip$EEZ<-as.factor(fishmip$EEZ)
# # fishmip$model<-as.factor(fishmip$model)
# # fishmip$esm<-as.factor(fishmip$esm)

fishmip$ssp<-as.factor(fishmip$ssp)

top_seven <-subset(fishmip,EEZ %in% c("China","Indonesia","Peru","United.States","India","Vietnam", "Russia"))
 
 p <- ggplot(top_seven, aes(x="year", y="mean",colour="ssp")) +
   geom_line(alpha=0.9) +
   geom_ribbon(aes(ymin=mean - SD, ymax=mean + SD,fill=ssp), alpha=0.2,color=NA)+
    facet_grid(vars(EEZ), scales = "free")+
    #theme(legend.position = "none") +
   theme_minimal() +
   ylab("Multimodel mean % change exploitable biomass")

jpeg("EEZ_scen.jpeg")
p
dev.off()

#
# 
# ui <- fluidPage(
#   sidebarLayout(
#     sidebarPanel(
#       h2("FishMIP Ensemble EEZ Projections"),
#       selectInput(inputId = "EEZ", label = "EEZ",
#                   choices = levels(fishmip$EEZ),
#                   selected = "Australia"),
#            # selectInput(inputId = "model", "Model",
#            #         choices = levels(fishmip$model),
#            #         selected = "BOATS"),
#            #  selectInput(inputId = "esm", "CMIP6 Model",
#            #                    choices = levels(fishmip$esm),
#            #                     # multiple = TRUE,
#            #                     selected = c("gfdl-esm4")),
#       downloadButton(outputId = "download_data", label = "Download"),
#     ),
#     mainPanel(
#       plotlyOutput(outputId = "plot"), br(),
#       em("Postive and negative percentages indicate an increase and decrease from the historical reference period (mean 1990-1999)"),
#       br(), br(), br(),
#       DT::dataTableOutput(outputId = "table")
#     )
#   )
# )
# 
# 
# server <- function(input, output) {
#   filtered_data <- reactive({
#     subset(fishmip,
#            EEZ %in% input$EEZ)})
#   
#   output$plot <- renderPlotly({
#     ggplotly({
#       p <- ggplot(filtered_data(), aes_string(x="year", y="mean",colour="ssp")) +
#         geom_line(alpha=0.5) +
#         geom_ribbon(aes(ymin=mean-sd, ymax=mean +sd,fill=ssp), alpha=0.2,color=NA)+
#         # #theme(legend.position = "none") +
#         theme_minimal() +
#         ylab("Multimodel mean % change exploitable biomass")
# 
#       p
#     })
#   })
#   
#   output$table <- DT::renderDataTable({
#     filtered_data()
#   })
#   
#   output$download_data <- downloadHandler(
#     filename = "download_data.csv",
#     content = function(file) {
#       data <- filtered_data()
#       write.csv(data, file, row.names = FALSE)
#     }
#   )
#   
# }
# 
# shinyApp(ui = ui, server = server)