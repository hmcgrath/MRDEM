#forest model
#library(terra)
library(whitebox)

ui_command <- commandArgs(trailingOnly = TRUE)
fname <- ui_command[1]


gridlist <- paste0("filepath/", fname ,".csv", sep="")

dsm <- "COP30_3979_CGVD_Bld2.tif"   ## check name
forest <- "caforest.tif"
fires = "fires.shp"  ## check nam... 
firescANADA <- "/filepath/NBAC_2015_15Merge.shp"


processCAforest <- function(t){
  
  library(terra)
  # Check if the fires shapefile exists and is not empty
  if (!file.exists(fires) || length(vect(fires)) == 0) {
    print("Fires shapefile does not exist or is empty. Skipping fire-related processing.")
    # Skip to the buildings check
  } else {
    fires_vector <- vect(fires)
    print(fires)
    # Existing fire processing steps here
    wbt_percent_elev_range(dsm, 'dsm_per_forest.tif', filterx=3, filtery=3)
    # Forest weight: 
    if (file.exists(fires) ){
      if (file.exists("caforest2.tif")){
       forest75 <- rast("caforest2.tif") * 0.75
      }else{
        forest75 <- rast("caforest.tif") * 0.75
      }
      writeRaster(forest75, "caforest75.tif", overwrite=TRUE)
      wbt_percent_elev_range("caforest75.tif", 'caforest_per.tif', filterx=3, filtery=3)
    }else{
        forest75 <- rast(forest) * 0.75
      writeRaster(forest75, "caforest75.tif", overwrite=TRUE)
      wbt_percent_elev_range("caforest75.tif", 'caforest_per.tif', filterx=3, filtery=3)
    }
    gc()
    # Mask DSM and forest: 
    
    ##Make sure shape is right extents;
    # Load the raster and shapefile
    raster_data <- rast(dsm)
    #fires_vector <- vect(fires_shapefile)

    # Get the extent of the raster
    raster_extent <- ext(raster_data)
    #re =c(raster_extent[1], raster_extent[2], raster_extent[3], raster_extent[4])
    #<xmin> <ymin> <xmax> <ymax>
    re =c(raster_extent[1], raster_extent[3], raster_extent[2], raster_extent[4])
    raster_resolution = c(30, 30)
    # Crop the shapefile to match the raster's extent
    fires_cropped <- crop(fires_vector, raster_extent)
    #rasterized_polygon <- rasterize(fires_cropped, raster_data, field = "BURNCLAS", background = NA)
    # Save the cropped shapefile to a new file
    writeVector(fires_cropped, "fires_cropped.shp", overwrite = TRUE)
    #writeRaster(rasterized_polygon, 'fires.tif')

    library(gdalUtils)
    print("Masking DSM with fires...")
    #dsm_masked <- mask(dsm_raster, fires_vector)
    # Run gdalwarp to apply the mask
    gdalwarp(
      srcfile = 'dsm_per_forest.tif', 
      dstfile = 'dsmP_masked_fire.tif',
      cutline = "fires_cropped.shp",       # The shapefile used as a mask
      crop_to_cutline = FALSE,       # Crop the raster to the extent of the mask
      dstnodata = NA
    )
    
    print("Masking forest with fires...")
    #forest_masked <- mask(forest_raster, fires_vector)
    gdalwarp(
      srcfile = 'caforest_per.tif', 
      dstfile = 'forest_masked_fire.tif',
      cutline = "fires_cropped.shp",       # The shapefile used as a mask
      crop_to_cutline = FALSE,       # Crop the raster to the extent of the mask
      dstnodata = NA)
    
    
    #dsmMask <- mask(rast('dsm_per_forest.tif'), vect(fires))
    #forestMask <- mask(rast('caforest_per.tif',), vect(fires))
    print('opening forest masked fire')
    # Set 0 to NA:
    forestMask <- rast("forest_masked_fire.tif")
    print('set 0 to NA')
    forestMask[forestMask == 0 ] <- NA
    print('set anything > 1 to 1')
    forestMask[forestMask > 1] <- 1
    writeRaster(forestMask, 'bindaryforest.tif', overwrite=TRUE)
    vector_data <- as.polygons(forestMask)
    # Crop the shapefile to match the raster's extent
    writeVector(vector_data, 'forestpoly.shp')
    # Mask DSM to forest pixels:
    #dsmMask <- rast('dsmP_masked_fire.tif')
    #dsmforestMask <- mask(dsmMask, forestMask)
    gdalwarp(
      srcfile = 'dsmP_masked_fire.tif', 
      dstfile = 'dsmMa.tif',
      cutline = 'forestpoly.shp',       # The shapefile used as a mask
      crop_to_cutline = FALSE,       # Crop the raster to the extent of the mask
      dstnodata = NA            # Optionally set nodata value for masked areas
    )
    
    dsmforestMask <- rast("dsmMa.tif")
        # Now look at the difference between elevation range of DSM and forest height:
    print('get the difference between the two rasters:')
    print(forestMask)
    print(dsmforestMask)
    difference <- forestMask - dsmforestMask
    # Set threshold for what is still forest
    fireforest <- (difference * 0.01) * forest75
    fireforest[fireforest < 0 ] <- NA ## in fire zones.
    # Merge back into full forest: 
    # Mask original forest w/ fires and stack:
    
    rb <- rast("dsmP_masked_fire.tif")
    nonforest <- setValues(rb, ifelse(!is.na(values(rb)), NA, 1))
    fo <- rast("caforest75.tif")
    fullforest <- fo * nonforest
    
    # Now stack:
    s <- merge(fullforest, fireforest)
    plot(s)
    writeRaster(s, "S.tif", overwrite=TRUE)
  }
  
  # Check if onlybuildings.tif exists
  if (!file.exists("onlybuildings.tif")) {
    print("onlybuildings.tif does not exist, writing caforest_adjusted.tif from 's'")
    if (file.exists("S.tif")) {
    writeRaster(s , "caforest_adjusted.tif", overwrite=TRUE)
    }else{
      #if no 's'there are no files, we just want to copy caforest75 to final raster.
      ##add 75: 
      if (file.exists("caforest2.tif") ){
        forest = "caforest2.tif"
      }else{
        forest = "caforest.tif"
        }
      
      forest75 <- rast(forest) * 0.90
      writeRaster(forest75, "caforest_adjusted.tif", overwrite=TRUE)
      
    }
  } else {
    if (file.exists("S.tif")) {
    # Process buildings if the file exists
    buidins <- rast("onlybuildings.tif")
    invbuildings <- subst(buidins, NA, 5)
    invbuildings[invbuildings == 1] <- NA
    
    newtrees <- mask(s, invbuildings)
    writeRaster(newtrees, "caforest_adjusted.tif", overwrite=TRUE)
    }
    else{
      buidins <- rast("onlybuildings.tif")
      invbuildings <- subst(buidins, NA, 5)
      invbuildings[invbuildings == 1] <- NA
      if (file.exists("caforest2.tif") ){
        forest = "caforest2.tif"
      }else{
        forest = "caforest.tif"
      }
      forest75 <- rast(forest) * 0.90
      writeRaster(forest75, "caforest75.tif", overwrite=TRUE)
      newtrees <- mask(rast("caforest75.tif"), invbuildings)
      writeRaster(newtrees, "caforest_adjusted.tif", overwrite=TRUE)
    }
  }
  
  print("finished:")
  print(t)
}


#read grid list: 
gl <- read.csv(gridlist)
glid <- gl$id
for (i in glid){
  print(i)
  #setworking directory: 
  wd <- paste0("filepath", i, sep="")
  setwd(wd)
  if (file.exists("caforest_adjusted.tif")) {
    print("skip this tile")
    #delete: 
    unlink("caforest_adjusted.tif")
    processCAforest(i)
  }else{
    processCAforest(i)
  }
}
