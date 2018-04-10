#extractMainVeg2
#Extracts the main vegetation types within a specified buffer from
#coordinates as a text string with percentages

#Args:
# coords: a data frame of x,y coordinates
# veg.data: a raster stack of landcover type categories.
#           Must be in the same coordinate system as coords
# ntypes: the number of landcover types to return

#Returns
# A vector of main landcover type strings per coordinate pair

extractMainVeg2<-function(coords, veg.data, ntypes=3){
  lt <- extract(veg.data, coords)
  result <- apply(lt,1,function(x){
    x<-x[which(x>0)]
    if(length(x)==0){
      return(NA)
    }
    if(length(x)>=ntypes){
      top3<-x[order(x,decreasing=T)][1:ntypes]
    } else {
      top3<-x[order(x,decreasing=T)]
    }
    out.string<-paste0(names(top3)," (", format(top3,digits=2),"%)",collapse=", ")
  })
  return(result)
}