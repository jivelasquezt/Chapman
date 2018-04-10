#coords must be x, y or lon,lat
getLatLon<-function(coords, proj.str){
  headers<-colnames(coords)
  require(raster)
  require(sp)
  coordinates(coords)<-c(1,2)
  projection(coords)<-proj.str
  new.coords<-spTransform(coords,"+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs")
  new.coords<-new.coords@coords
  colnames(new.coords)<-headers
  return(new.coords)
}

getUTMcoords<-function(coords){
  headers<-colnames(coords)
  require(raster)
  require(sp)
  coordinates(coords)<-c(1,2)
  projection(coords)<-"+proj=longlat +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +no_defs"
  new.coords<-spTransform(coords,"+proj=utm +zone=18 +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs")
  new.coords<-new.coords@coords
  colnames(new.coords)<-headers
  return(new.coords)
}

writeZip <- function(x, FILE, .file = 'Sitios_muestreos', .driver = "ESRI Shapefile", ...) {
  tmpDir <- tempdir()
  writeOGR(x, dsn = tmpDir, layer = .file, driver = .driver, overwrite_layer=T, check_exists=T)
  f <- list.files(path = tmpDir, full.names = TRUE,
                  pattern=paste0(strsplit(.file, ".", fixed=T)[[1]][1], ".*"))
  zip(paste0(tmpDir, '/', .file, ".zip"), f, flags="-9Xjm", zip="zip")
  file.copy(paste0(tmpDir, '/', .file, ".zip"), FILE)
  file.remove(paste0(.file, ".zip"))
}
