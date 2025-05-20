#settelmentremoval
library(raster)
library(sf)
library(sp)
library(rgdal)
library(whitebox)

maindir<- "set main working directory"
setwd(maindir)

cop <- "dsm30.tif"
xy <- 7
pe_thresh <- 55

###########
# Define the function to fill NoData using GDAL
fill_raster_iteratively <- function(input_raster, output_raster, max_distance = 7, gdal_path = "gdal_fillnodata.py") {
  # Temporary raster to handle iterations
  temp_raster <- "temp_filled.tif"
  filled <- FALSE
  
  while (!filled) {
    # Run gdal_fillnodata.py command
    cmd <- sprintf(
      "%s -md %d -of GTiff -co COMPRESS=LZW %s %s",
      gdal_path, max_distance, input_raster, temp_raster
    )
    system(cmd, intern = TRUE)
    
    # Check if there are remaining NoData values
    check_cmd <- sprintf("gdalinfo -stats %s", temp_raster)
    gdal_info <- system(check_cmd, intern = TRUE)
    
    # Extract NoData count from gdalinfo
    nodata_line <- grep("NoData Value", gdal_info, value = TRUE)
    nodata_value <- as.numeric(gsub(".*NoData Value=([-0-9.]+).*", "\\1", nodata_line))
    
    # If no NoData values remain, stop iterating
    if (is.na(nodata_value) || nodata_value == 0) {
      filled <- TRUE
    } else {
      # Update input raster for the next iteration
      file.copy(temp_raster, input_raster, overwrite = TRUE)
    }
  }
}
################

maskoutbuildings <- function(bldingrasters){
  
  # Error handling for raster loading
  library(terra)
  tryCatch({
    dsm <- rast(cop)
    print("COP Dsm opened")
  }, error = function(e) {
    cat("Error loading COP Dsm raster: ", e$message, "\n")
  })
  
  tryCatch({
    blds <- rast(bldingrasters)
    print("buildings opened")
  }, error = function(e) {
    cat("Error loading BuildingsCombined raster: ", e$message, "\n")
  })
  
  # Reclassify buildings raster
  blds[blds < 2] <- NA
  blds[blds > 0 ] <- 1
  print('Reclassed to NA and 1')
  writeRaster(blds, "onlybuildings.tif", overwrite=TRUE)
  # Mask DSM with buildings raster
  tryCatch({
    wbt_percent_elev_range( cop,
                            output = "DSM_Per.tif",
                            filterx = xy,
                            filtery = xy)
    #open raster and mask per w/ only buildings
    maskbldelev <- mask(rast("DSM_Per.tif"), blds)
    print('Masked DSM with buildings raster')
    writeRaster(maskbldelev, 'Buildings_w_PER_fromDSM.tif', overwrite=TRUE)
  }, error = function(e) {
    cat("Error applying mask: ", e$message, "\n")
  })
  
  # Check if all values are NA in the masked raster
  if (all(is.na(values(maskbldelev)))) {
    print("All values in the mask are NA")
    wbt_gaussian_filter(input = cop,
                        output = 'COP30_3979_CGVD_Bld2.tif',
                        sigma = 0.75
    )
  } else {
    # If not all are NA, proceed with saving the result
    tryCatch({
      writeRaster(maskbldelev, 'origMask.tif', overwrite=TRUE)
      print('Masked raster written to "origMask.tif"')

      
      filt4bldmask <- rast("Buildings_w_PER_fromDSM.tif")
      
      filt4bldmask[filt4bldmask < pe_thresh] <- NA
      print("applied pe_thresh")
      maskpartbldelev <- mask(dsm, filt4bldmask, inverse=TRUE)
      print("surface masked with PER, invbldmastk we want to now fill the NA")
      writeRaster(maskpartbldelev, 'invbldmastk.tif', overwrite=TRUE)
      ##library(terra)
      #ras <- rast("invbldmastk.tif")
      
      #run PER on Full data then mask: gdal NODATA fill 
      library(gdalUtils)
      gdal_fillnodata_path <- "/usr/bin/gdal_fillnodata.py"  # Update this path if needed
      ### filling: 
      #fill_raster_iteratively("invbldmastk.tif", "bldRemoved.tif", max_distance = 7)
      gdal_fillnodata(
        src_dataset = "invbldmastk.tif",
        dst_dataset = "bldRemoved.tif",
        band = 1,
        max_distance = 7,  # Fill distance
        iterations = 30    # Number of iterations
      )
      
      
      #smooth building
      wbt_gaussian_filter(input = 'bldRemoved.tif',
                          output = 'COP30_3979_CGVD_Bld2.tif',
                          sigma = 0.75)

      
      #smooth building
      print("now final gaus")
      wbt_gaussian_filter(input = 'bldRemoved.tif',
                          output = 'COP30_3979_CGVD_Bld2.tif',
                          sigma = 0.75)
      ######################end new way
    }, error = function(e) {
      cat("Error writing raster: ", e$message, "\n")
    })
  }
  
  
}
#######################################
# Define the function to fill NoData using GDAL
fill_raster_iteratively <- function(input_raster, output_raster, max_distance = 100, gdal_path = "gdal_fillnodata.py") {
  # Temporary raster to handle iterations
  temp_raster <- "temp_filled.tif"
  filled <- FALSE
  
  while (!filled) {
    # Run gdal_fillnodata.py command
    cmd <- sprintf(
      "%s -md %d -of GTiff -co COMPRESS=LZW %s %s",
      gdal_path, max_distance, input_raster, temp_raster
    )
    system(cmd, intern = TRUE)
    
    # Check if there are remaining NoData values
    check_cmd <- sprintf("gdalinfo -stats %s", temp_raster)
    gdal_info <- system(check_cmd, intern = TRUE)
    
    # Extract NoData count from gdalinfo
    nodata_line <- grep("NoData Value", gdal_info, value = TRUE)
    nodata_value <- as.numeric(gsub(".*NoData Value=([-0-9.]+).*", "\\1", nodata_line))
    
    # If no NoData values remain, stop iterating
    if (is.na(nodata_value) || nodata_value == 0) {
      filled <- TRUE
    } else {
      # Update input raster for the next iteration
      file.copy(temp_raster, input_raster, overwrite = TRUE)
    }
  }
}



listoftiles <- list.dirs(path = maindir, full.names = TRUE, recursive = TRUE)
#drop: src, shapefile, R
# Directories to remove
dirs_to_remove <- c("folder in directory to skip")

# Remove specified directories
listoftiles <- setdiff(listoftiles, dirs_to_remove)
print(listoftiles)

# Define the filenames
buildingsraster = "BuildingsCombined.tif"
invbldmastk = "invbldmastk.tif"
copb = "COP30_3979_CGVD_Bld2.tif"


for(i in listoftiles){
  print(i)
  setwd(i)
  getwd()
  
 
  # First check if 'invbldmastk.tif' exists
  if (file.exists(copb)) {
    print("Found 'COP30_3979_CGVD_Bld2.tif'. Skipping.")
  } else {
    # If '"COP30_3979_CGVD_Bld2.tif".tif' does not exist, proceed with the existing check for 'BuildingsCombined.tif'
    if (file.exists(buildingsraster)) {
      maskoutbuildings(buildingsraster)
    } else {
      print("Not building raster in this directory:")
      print(i)
    }
  }
}