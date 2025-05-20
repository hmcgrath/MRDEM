#forest model
#library(terra)
library(whitebox)

gridlist <- "filepath/shapefile/gridlist.csv"

dsm <- "COP30_3979_CGVD_Bld2.tif"   ## check name
forest <- "gediforest.tif"
USborder <- "/filepath/canvec_1M_CA_Admin_shp/USCanada.tif"



gdalWarpFunction <- function(hri, ex, outclip, s_in, restype){
  print('now start gdalUtils')
  library(gdalUtils)
  #rgdal::GDALinfo(hri)
  #terra order: (xmin, xmax, ymin, ymax)
  #gdal: <xmin> <ymin> <xmax> <ymax>
  gdalwarp(srcfile =  hri,
           s_srs = s_in,
           dstfile = outclip,
           of="GTiff",
           te= c(ex[1], ex[3], ex[2],ex[4]),
           t_srs = 'EPSG:3979',
           tr = c(30,30) ,
           r = restype,
           ovr = 'AUTO-n',
           #mask = 'tmpCliptif.tif',
           output_Raster=TRUE
  )
  
}

processGforest <- function(t){
  
  library(terra)
  #weigsht forest 50%
  g <- rast(forest)
  g[g > 26] <- 0
  
  #mask out canada:
  #cda <- mask(rast(USborder), g)
  cdabrd <- "border.tif"
  ex <- ext(g)
  gdalWarpFunction(USborder, ex, cdabrd, 'EPSG:3979', "nearest")
  
  ##so, now mask out non-US places. 
  cborder <- rast(cdabrd)
  gediforest <- g * cborder
  
  
  # Check if onlybuildings.tif exists
  if (!file.exists("onlybuildings.tif")) {
    print("onlybuildings.tif does not exist, writing caforest_adjusted.tif from 's'")
    pring('write it as is. ')
    writeRaster(gediforest , "gediForest_adjusted.tif", overwrite=TRUE)
    }else{
      #do stuff with MASK for buildings. 
      buidins <-rast("onlybuildings.tif")
      invbuildings <- subst(buidins, NA, 5)
      invbuildings[invbuildings == 1] <- NA
      
      newtrees <- mask(gediforest, invbuildings)
      writeRaster(newtrees, "gediForest_adjusted.tif", overwrite=TRUE)
  }
  
  print("finished:")

}


#read grid list: 
gl <- read.csv(gridlist)
glid <- gl$id
for (i in glid){
  print(i)
  #setworking directory:
  wd <- paste0("/filepath/", i, sep="")
  setwd(wd)
  if (file.exists("gediForest_adjusted.tif")) {
    print("skip this tile")
  }else{
    processGforest(i)
  }
}
