MapGDMLight<-function(rastTrans){
  #Maps general dissimilarity
  
  #Args:
  #   occ.table:  data frame with species occurrence information. 
  #               Must contain lon,lat,species and site columns.
  #   env.vars:   RasterStack or RasterBrick of environmental 
  #               variables that define gradients of interest
  #
  #Returns:
  #   A raster showing the general dissimilarity model
  
  require(gdm)
  require(raster)
  #Plot dissimilarity
  cellsWData<-Which(!is.na(rastTrans[[1]]),cells=T)
  rastDat<-rastTrans[cellsWData]
  pcaSamp <- prcomp(rastDat)
  pcaRast <- predict(rastTrans, pcaSamp, index=1:3)
  
  # scale rasters
  pcaRast[[1]] <- (pcaRast[[1]]-pcaRast[[1]]@data@min) /
    (pcaRast[[1]]@data@max-pcaRast[[1]]@data@min)*255
  pcaRast[[2]] <- (pcaRast[[2]]-pcaRast[[2]]@data@min) /
    (pcaRast[[2]]@data@max-pcaRast[[2]]@data@min)*255
  pcaRast[[3]] <- (pcaRast[[3]]-pcaRast[[3]]@data@min) /
    (pcaRast[[3]]@data@max-pcaRast[[3]]@data@min)*255
  
  return(pcaRast)
}

