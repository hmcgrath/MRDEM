#inthis short script
#the user specifies the folder, in dem and refernce output dem to align to. 



#Copernicus DEM - to remove buildings and forests.
library(raster)
library(sf)
library(sp)
library(rgdal)
library(whitebox)


#############user inputs: 
ui_command <- commandArgs(trailingOnly = TRUE)
working_dir <- ui_command[1]
tmpshp <- paste('file.shp', sep='')

maindir <- 'setmainworking_directory'
cgvd <-'/yourfilepath/CGG2013n83a.tif'
cgvd_D <- '/yourfilepath/ca_nrc_CGG2013i08.tif'
egm2008 <- '/yourfilepath/us_nga_egm08_25.tif'

tmpshp <- 'tmp.shp'
#tile definition to process to
mastershape <-  "/tiles_500x.shp"
print('location of shapefile is: ')
print(mastershape)

print('read shapefile')

  ##############
#LOCAL:
#marpir <- 'Y:/FS2_0/ElevationComparison/Ecozones/'
#working_dir <- 'AM0'
#LOC <- 'C:/Users/hmcgrath/Documents/FME/Workspaces/Heather/Creer_MNT30m_EGM2008/grilles_geoid/'
#cgvd <-paste(LOC, 'CGG2013n83a.tif', sep='')
#egm2008 <- paste(LOC,'us_nga_egm08_25.tif', sep='')


wd <- paste(maindir, working_dir, sep='')
setwd(wd)
print('Current working directory is:')
print(wd)

mastergrid <-"tiles_500x.shp"

#ind <- 'cdem-canada-dem-clip-30m-bilinear.tif'
cop <- 'COP30.tif'




############ FUNCTIONS
#########
#1. crop:

gdalWarpFunction <- function(hri, ex, outclip, s_in){
  print('now start gdalUtils')
  library(gdalUtils)
  #rgdal::GDALinfo(hri)
    gdalwarp(srcfile =  hri,
             s_srs = s_in,
             dstfile = outclip,
             of="GTiff",
             te= c(xmin(ex),ymin(ex),xmax(ex),ymax(ex)),
             t_srs = 'EPSG:3979',
             tr = c(30,30) ,
             r = 'bilinear',
             ovr = 'AUTO-n',
             #mask = 'tmpCliptif.tif',
             output_Raster=TRUE
    )

}


checkcommonExtent <- function(first_raster, file){
  
  common_extent <- extent(raster(first_raster))
 
    raster_data <- raster(file)
    raster_extent <- extent(raster_data)
    
    # Update common extent if necessary
    common_extent <- raster::union(common_extent, raster_extent)
 
    
    # Adjust the extent
    raster_data <- crop(raster_data, common_extent)
    
    rs <- resample(raster_data, raster(first_raster), 'bilinear')
    ar <- crop(rs, common_extent)
    writeRaster(ar,file, overwrite=TRUE )
    return(ar)
 
}


getEx <- function(tiles){
  
  wfsGrid <- sf::st_read(tiles)
  #wfsGrid <- readOGR(hrdtmtiles
  selected_features <- subset(wfsGrid, GRID_ID == working_dir)
  extgrid <- extent(selected_features)
  return(extgrid)
}


wbtCalcfunction <- function(a, b, c){
  # Perform raster calculation to sum the rasters
  wbt_raster_calculator(output = 'COP30_3979_CGVD.tif',
                        statement = a+b-c)
  
}

######################################################

if (file.exists('COP30.tif')){
  ex <- getEx(mastergrid)
  gdalWarpFunction(cgvd, ex,'cgvd.tif', 'EPSG:4979')
  #gdalWarpFunction(egm2008, ex,'egm208.tif', 'EPSG:4269')
  gdalWarpFunction(cgvd_D, ex,'cgvdD.tif', 'EPSG:7911')
  gdalWarpFunction(cop, ex,'copgl30_3979.tif', 'EPSG:4326')
  print('aligned egm Geoid file')
  
  library(whitebox)
  #wbt_adaptive_filter(input = 'copgl30_3979.tif',
  #                    output = 'copadapt7.tif', 
  #                    filterx = 7,
  #                    filtery = 7)
  
  
  h <- raster('copgl30_3979.tif')
  eg <- checkcommonExtent('copgl30_3979.tif', 'egm208.tif')
  print('egm aligned')
  c <- checkcommonExtent('copgl30_3979.tif', 'cgvd.tif')
  print('cgvd aligned')
  d <- checkcommonExtent('copgl30_3979.tif', 'cgvdD.tif')
  #wbt_raster_calculator(output = 'COP30_3979_CGVD.tif',
  #                      statement = 'copgl30_3979.tif' + 'egm208.tif'- 'cgvd.tif' 
  #)
  
  d2 <- d /1000
  list <- c('copgl30_3979.tif','egm208.tif', 'cgvd.tif' )
  s <- stack(h, c, d2)
  print('staked all elevels')
  fun <- function(x){return(x[1]+x[2]-x[3])}
  c2 <- calc(s, fun)
  #plot(c2)
  #print('now save vertically adjusted raster:')
  writeRaster(c2, 'COP30_3979_CGVD.tif', overwrite=TRUE)
}else {
  print('do nothing: ')
}

if (file.exists('COP30_3979_CGVD.tif')){
    unlink('cop3979clip.tif')
    unlink('copadapt7.tif')
    #unlink('cop3979clip.tif')
    unlink('cgvd.tif')
    unlink('egm208.tif')
}

