library(terra)
ui_command <- commandArgs(trailingOnly = TRUE)
fname <- ui_command[1]


gridlist <- paste0("/filepath/", fname ,".csv", sep="")

gediforest = "gediForest_adjusted.tif"
caforest = "caforest_adjusted.tif"



mergeforests <- function(i) {
  g <- rast(gediforest)
  g <- g * 0.65
  g[g == 0] <- 0
  g[is.na(g)] <- 0
  g[is.nan(g)] <- 0

  # Trim Canada to US border
  border <- rast("border.tif")
  border[is.na(border)] <- 2
  border[border == 1] <- 0
  border[border == 2] <- 1

  c <- rast(caforest)
  c[c == 0] <- 0
  c[is.na(c)] <- 0

  # Compute sum and handle averaging for non-zero overlapping cells
  mo <- g + c
  both_non_zero <- (g > 0) & (c > 0)  # Identify pixels where both rasters have non-zero values
  mo[both_non_zero] <- (g[both_non_zero] + c[both_non_zero]) / 2  # Compute average

  writeRaster(mo, "mergedForest.tif", overwrite = TRUE)
  }


gl <- read.csv(gridlist)
glid <- gl$id
for (i in glid){
  print(i)
  if (file.exists("mergedForest.tif")) {
        print("overwriting the mergedForest")
        wd <- paste0("/filepath/", i, sep="")
        setwd(wd)
        mergeforests(i)
   }else{
  #setworking directory:
    wd <- paste0("/filepath/", i, sep="")
    setwd(wd)
    mergeforests(i)
   
    }
}
