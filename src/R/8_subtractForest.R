library(terra)


ui_command <- commandArgs(trailingOnly = TRUE)
fname <- ui_command[1]


gridlist <- paste0("/filepath/", fname ,".csv", sep="")


dsm = "COP30_3979_CGVD_Bld2.tif"
forest = "mergedForest.tif"

  
  
mergeforestswdsm <- function(i){
  d <- rast(dsm)
  f <- rast(forest)
  f <- subst(f, NA, 0) 
  
  mo <- d - f
  #plot(mo)
  writeRaster(mo, "COPGlo30-srm-frm.tif", overwrite=TRUE)
  
}

filtersandoutliers <- function(){
  library(whitebox)
 
  ######################NEW NEW NEW NEW ########################################
  ######################NEW NEW NEW NEW #######################################
  #the adaptive filters preserve image sharpness and detail while suppressing noise.#
  wbt_adaptive_filter(input= 'COPGlo30-srm-frm.tif', 
                      output = 'f1.tif',
                      filterx = 7,
                      filtery = 7, 
                      threshold = 1.75)
  print('1. adaptive filter complete')
  wbt_adaptive_filter(input= 'f1.tif', 
                      output = 'f2.tif',
                      filterx = 7,
                      filtery = 7, 
                      threshold = 1.75)
  print('2. adaptive filter complete')
  wbt_bilateral_filter(input = 'f2.tif',
                       output = 'f3.tif',
                       sigma_dist = 0.75,
                       sigma_int = 1 )
  print('bilateral  filter complete')
  
  print('fill single cell pits done')
  
  wbt_gaussian_filter(input= 'f3.tif', 
                      output = 'mcdtm.tif',
                      sigma=0.75)
  print('gaussian filter complete')

}

crop_to_poly <- function(i){
 outputtif <- paste0("/filepath/", i, ".tif", sep="") 
 #first buffer poly by 30 so I dont' have gap: 
 library(terra)
 library(whitebox)
 p <- buffer(vect("tile.shp"), width = 30)
 
 #remove files if exist: 
 unlink("envelope30.shx")
 unlink("envelope30.dbf")
 unlink("envelope30.shp")
 unlink("envelope30.prj")
 unlink("tile30.shp")
 unlink("tile30.shx")
 unlink("tile30.dbf")
 unlink("tile30.prj")
 writeVector(p, 'tile30.shp')
 wbt_minimum_bounding_box('tile30.shp', 'envelope30.shp')
 
 
 library(gdalUtils)
 gdalwarp(
   srcfile = 'mcdtm.tif', 
   dstfile = outputtif,
   cutline = "envelope30.shp",       # The shapefile used as a mask
   crop_to_cutline = TRUE,       # Crop the raster to the extent of the mask
   dstnodata = NA
 )
 
}
  

gl <- read.csv(gridlist)
glid <- gl$id
for (i in glid){
  print(i)
  #setworking directory:
  wd <- paste0("/filepath/", i, sep="")
  print(wd)
  setwd(wd)
  if (file.exists("mcdtm.tif")) {
    unlink("mcdtm.tif")
    #print("skip this tile")
    mergeforestswdsm(i)
	  filtersandoutliers()
    crop_to_poly(i)
  }else{
    mergeforestswdsm(i)
    filtersandoutliers()
    crop_to_poly(i)
  }
}
