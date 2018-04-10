#Load libraries
library(gdm)
library(leaflet)
library(raster)
library(rgdal)
library(rgeos)
library(shiny)
library(shinycssloaders)
library(shinyjs)
library(png)

#Load functions
source("FindNextLight2.R")
source("MapGDMLight.R")
source("extractMainVeg2.R")
source("helpers.R")
source("Misc.R")
source("rgbPalette.R")

# Load app data
load("appData/occ.table2.RData")
load("appData/gdm.ebird.all.RData") #ebird.all ~ gbd2017
load("appData/gdm.raster.ebird.all.RData") #ebird.all ~ gbd2017
load('appData/col_runap.RData')
load("appData/results.RData")
env.data<-stack("./appData/env.data5.utm.grd")
env.data.coarse<-stack("./appData/env.data20.utm.grd")
dem.data <- raster("./appData/dem_utm.tif")
vias <- raster("./appData/distFromRoadsRivers.tif")

col@data$DEPARTAMEN <- as.character(col@data$DEPARTAMEN)
occ.coords<-data.frame(getLatLon(occ.table[,c("lon","lat")], projection(env.data)))

ui <- fluidPage(
  # Call font
  tags$link(
    rel = "stylesheet",
    href="https://fonts.googleapis.com/css?family=Raleway:400,400i|Roboto:300,300i,400,400i,700,700i"
  ),
  #tags$style("h2{font-family: 'Open Sans'}"),

  ## Call css 
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "chapman.css")
  ),
  tags$head(includeHTML(("muestreo-analytics.html"))),

  useShinyjs(),
  inlineCSS(appCSS),
  
  titlePanel("Chapman: Sistema de recomendación de muestreo"),
  sidebarLayout(
    sidebarPanel(
      h4(HTML("<b>Seleccione área de interés:<b>")),
      selectInput("aoi", label=NULL, width = '70%',
                  choices = c('COLOMBIA', sort(unique(col@data$DEPARTAMEN)))),
      actionButton(inputId ="see", label="Ver Resultados",class="btn-primary"),
      br(),br(),
      withBusyIndicatorUI(
        actionButton(inputId ="go", label="Personalizar (beta)",class="btn-primary")
      ),
      br(),
      
      h4(HTML("<b>Descargar:<b>")),
      radioButtons("resultType",label="Escoja resultado",
                   choices=c("Precalculado","Personalizado"),
                   selected="Precalculado"),
      h5(HTML("<b>  a. Capa de puntos:<b>")),
      downloadButton('dwnShape', 'Puntos (.shp)'),
      h5(HTML("<b>  b. Raster:<b>")),
      downloadButton('dwnRaster', 'Raster (.tif)'),    
      h5(HTML("<b>  c. Tabla localidades:<b>")),
      
      downloadButton('dwnTable', 'Localidades (.csv)'),
      
      br(),
      br(),
      br(),
      img(src = "humboldt-01.png", height = 87, width = 80),
      img(src = "Logo_GBD_Final-01.png", height = 108, width = 241)
    ),
    mainPanel(
      tabsetPanel(id = "inTabset",
        tabPanel('Inicio', includeMarkdown("introMD.md")),
        tabPanel('Acerca de', includeMarkdown("aboutMD.md")),
        tabPanel('Resultados',
                 fluidRow(withSpinner(leafletOutput("resultMap", width = "100%", height = 500),
                                      type = 1)),
                 img(src = "legend.png", height = 50.7, width = 303),
                 br(),
                 fluidRow(tableOutput("resultTable"))
                 ),
        tabPanel('Personalizar',
                 fluidRow(
                   h5(HTML("<b>Busque el sitio más complementario:<b>")),
                   column(width = 2, withBusyIndicatorUI(actionButton(inputId = "findNext", label=" Sugerir", icon =icon('angle-up')))),
                   column(width = 2, actionButton(inputId = "ignoreSite",label=" Descartar", icon =icon('angle-down'))),
                   column(width = 1, h6(HTML("Latitud"))),
                   column(width = 2, textInput(inputId="lat", label = NULL, width = '200px', value=0)),
                   column(width = 1, h6(HTML("Longitud"))),
                   column(width = 2, textInput(inputId="lon", label = NULL, width = '200px', value=0)),
                   column(width = 1, actionButton(inputId = "goMap", label="Añadir"))
                 ),
                 fluidRow(withSpinner(plotOutput("nicemap", width = "100%", height = 500),
                                      type = 1)), 
                 radioButtons("mapType", label="Mostrar:", choices=c("Comunidades","Complementariedad"), selected="Comunidades", inline=T),
                 br(), br(),
                 fluidRow(tableOutput("table1")))
      )
      )
    )
  )

server <- function(input, output, session) {
  disable(id = "findNext", selector = NULL)
  disable(id = "ignoreSite", selector = NULL)
  disable(id = "addCustomSite", selector = NULL)
  disable(id = "lat", selector = NULL)
  disable(id = "lon", selector = NULL)
  disable(id = "goMap", selector = NULL)
  
  rv <- reactiveValues()
  observeEvent(input$go,{
    withBusyIndicatorServer("go",{
      updateTabsetPanel(session, "inTabset", selected = "Personalizar")
      rv$aoi<-NULL
      rv$gdm.raster<-NULL
      rv$env.data.aoi<-NULL
      rv$out.table <- NULL
      rv$dist.raster <- NULL
      
      ## Disable Buttoms
      disable(id = "findNext", selector = NULL)
      disable(id = "ignoreSite", selector = NULL)
      disable(id = "addCustomSite", selector = NULL)
      disable(id = "lat", selector = NULL)
      disable(id = "lon", selector = NULL)
      
      if(input$aoi=="COLOMBIA"){
        rv$env.data.aoi <- env.data.coarse
        rv$aoi <- env.data.coarse[[1]]
      } else {
        rv$aoi <- col[col@data$DEPARTAMEN==input$aoi, ]
        rv$env.data.aoi <- env.data
      }
      rv$gdm.raster <- results[[input$aoi]]$gdm.col.aoi
      enable(id = "findNext", selector = NULL)
      enable(id = "ignoreSite", selector = NULL)
      enable(id = "goMap", selector = NULL)
      enable(id = "lat", selector = NULL)
      enable(id = "lon", selector = NULL)
    })
  })
  
  observeEvent(input$see,{
    withBusyIndicatorServer("go",{
      updateTabsetPanel(session, "inTabset", selected = "Resultados")
    })
  })
  
  observeEvent(input$findNext,{withBusyIndicatorServer("findNext",{
    if(!is.null(rv$out.table)){
      res <- FindNextLight2(gdm.rast, occ.table, rv$env.data.aoi, rv$aoi,
                           add.site=rv$out.table[, 1:2])
      rv$out.table <- rbind(rv$out.table, res$dist.table[1, ])
      rv$dist.raster <- res$dist.raster
    } else {
      res <- FindNextLight2(gdm.rast, occ.table, rv$env.data.aoi, rv$aoi,
                           add.site=NULL)
      rv$out.table <- res$dist.table[1, ]
      rv$dist.raster <- res$dist.raster
    }
  })
  })
  
  observeEvent(input$ignoreSite, {
    ignore.cell<-cellFromXY(rv$env.data.aoi[[1]], rv$out.table[nrow(rv$out.table), 1:2])
    rv$env.data.aoi[ignore.cell] <- NA
    rv$gdm.raster[ignore.cell] <- NA
    if(nrow(rv$out.table)==1){
      rv$out.table <- NULL
    } else {
      rv$out.table <- rv$out.table[1:(nrow(rv$out.table)-1), ]
    }
  })
  
  
  observeEvent(input$goMap,{
    addRow <- data.frame(getUTMcoords(
      data.frame(x=as.numeric(input$lon), 
                 y=as.numeric(input$lat))), dist=NA)
    rv$out.table <- rbind(rv$out.table, addRow)
  })
  
  #Plot precalculated results in Leaflet
  
  output$resultMap <- renderLeaflet({
    comRaster<-results[[input$aoi]]$gdm.col.aoi
    if(input$aoi=="COLOMBIA"){
      radSize<-14142.14
    } else {
      radSize<-3535.534
    }
    suggested<-results[[input$aoi]]$table1
    bounds<-getLatLon(data.frame(lon=c(extent(comRaster)@xmin,extent(comRaster)@xmax),
                                 lat=c(extent(comRaster)@ymin,extent(comRaster)@ymax)),
                      projection(comRaster))
    niceLeaf <- leaflet(comRaster[[1]]) %>%
            addTiles(group = 'Mapa base') %>%
            addProviderTiles("Esri.WorldImagery",group="Satélite") %>%
            addRasterImage(comRaster[[1]], colors = rgbPalette(comRaster), opacity =0.8, group = "Comunidades") %>%
            addLayersControl(baseGroups=c("Mapa base","Satélite"),overlayGroups = c("Comunidades", "Muestreado","Sugerido", "Área sugerida"),
                             options = layersControlOptions(collapsed = FALSE)) %>%
            fitBounds(lng1=min(bounds[,1]),
                      lng2=max(bounds[,1]),
                      lat1=min(bounds[,2]),
                      lat2=max(bounds[,2])) %>%
            addCircleMarkers(lng = ~lon, lat = ~lat, data = occ.coords, group = "Muestreado", color= "#333333",
                             fillColor = '#fcf9d5', fillOpacity = 1, weight = 0.5, radius = 5,
                             label = occ.table$locality) %>%
            addMarkers(lng = ~Longitud, lat = ~Latitud, data = suggested,
                       group = "Sugerido", label = paste0("Sitio: ",suggested$Sitio))%>%
            addCircles(lng = ~Longitud, lat = ~Latitud, data = suggested,
               group = "Área sugerida", radius=radSize, fillColor="dodgerblue", fillOpacity=0.6,weight=0,
               label = paste0("Sitio: ",suggested$Sitio))
    
    niceLeaf
  })
  
  #Plot interactive map using regular plotRGB function
  
  output$nicemap <- renderPlot({
    if(input$mapType=="Comunidades"){
      if(!is.null(rv$gdm.raster)){
        plotRGB(rv$gdm.raster)
        if(input$aoi!="COLOMBIA"){
          plot(rv$aoi,add=T,border="grey20")
        }
        points(occ.table[,3:2],pch=21,col="grey10",bg="#fcf9d5",cex=1.2)
        if(!is.null(rv$out.table)){
          points(rv$out.table,pch=25,col="grey10",bg="cyan",cex=2)
          legend("bottomright",c("Sitios muestreados","Sitios sugeridos"),
                 col=c("grey10","grey10"),
                 pt.bg=c("#fcf9d5","cyan"),
                 pch=c(21,25),
                 bg="white",
                 bty="n")
        } else {
          legend("bottomright",c("Sitios muestreados"),
                 col=c("grey10"),
                 pt.bg=c("#fcf9d5"),
                 pch=c(21),
                 bg="white",
                 bty="n")
        }
      }
    }
    
    if(input$mapType=="Complementariedad"){
      if(!is.null(rv$dist.raster)){
        plot(rv$dist.raster,ext=rv$gdm.raster,col=colorRampPalette(c("forestgreen","yellow","red"))(255))
        plot(rv$aoi,add=T,border="grey20")
        
        points(occ.table[,3:2],pch=21,col="grey10",bg="#fcf9d5",cex=1.2)
        if(!is.null(rv$out.table)){
          points(rv$out.table,pch=25,col="grey10",bg="cyan",cex=2)
          legend("bottomright",c("Sitios muestreados","Sitios sugeridos"),
                 col=c("grey10","grey10"),
                 pt.bg=c("#fcf9d5","cyan"),
                 pch=c(21,25),
                 bg="white",bty="n")
        } else {
          legend("bottomright",c("Sitios muestreados"),
                 col=c("grey10"),
                 pt.bg=c("#fcf9d5"),
                 pch=c(21),
                 bg="white")
        }
      }
    }
  })
  
  #This is the table for interactive results
  
  output$table1<-renderTable({
    if(!is.null(rv$out.table)){
      coords<-getLatLon(rv$out.table[,1:2],projection(env.data))
      res2<<-data.frame(
        Sitio=1:nrow(rv$out.table),
        Latitud=coords[,2], 
        Longitud=coords[,1],
        Elevación=extract(dem.data, rv$out.table[, 1:2]),
        Municipio=extract(col, rv$out.table[, 1:2])$NOMBRE_ENT,
        RUNAP=extract(runap, rv$out.table[, 1:2])$nombre,
        CercaniaViasKm=extract(vias, rv$out.table[, 1:2])/1000,
        Coberturas=extractMainVeg2(rv$out.table[, 1:2],env.data[[8:20]]),
        ED_Total=rv$out.table[,3])
      res3 <<- cbind(res2, coords)
      res2
    }
  })
  
  #This is the table for precalculated results
  
  output$resultTable<-renderTable({
    results[[input$aoi]]$table1
  })
  
  output$dwnTable <- downloadHandler(
    filename = 'samplingSuggestions.csv',
    content = function(filename) {
      if(input$resultType=="Personalizado"){
        write.csv(res3, filename, row.names = F, fileEncoding = "UTF-8")
      } 
      if(input$resultType=="Precalculado"){
        write.csv(results[[input$aoi]]$table1, filename, row.names = F, fileEncoding = "UTF-8")
      }
    })
  
  output$dwnShape <- downloadHandler(
    filename = 'samplingSuggestions.zip',
    content = function(filename) {
      if(input$resultType=="Precalculado"){
        c.cols <- results[[input$aoi]]$table1[, c('Sitio','Latitud', 'Longitud')]
        coordinates(c.cols) =~ Longitud+Latitud
        c.cols@proj4string@projargs <- '+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs'
        c.cols@data <- results[[input$aoi]]$table1
      } 
      if(input$resultType=="Personalizado"){
        c.cols <- res2[, c('Sitio','Latitud', 'Longitud')]
        coordinates(c.cols) =~ Longitud+Latitud
        c.cols@proj4string@projargs <- '+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs'
        c.cols@data <- res2
      } 
      
      writeZip(c.cols, filename, .file = 'Sitios_muestreo')
    })
  
  output$dwnRaster <- downloadHandler(
    filename = 'gdmRaster.tif',
    content = function(filename) {
      outRaster<-results[[input$aoi]]$gdm.col.aoi
      outRaster<-projectRaster(outRaster,crs='+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs')
      writeRaster(outRaster, filename=filename, options="INTERLEAVE=BAND", format="GTiff", overwrite=TRUE)
    })
}


shinyApp(ui = ui, server = server)