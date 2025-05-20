import os
import csv
import subprocess
from osgeo import gdal  

# Function to extract extent from a raster
def get_extent(raster_path):
    ds = gdal.Open(raster_path)
    gt = ds.GetGeoTransform()
    width = ds.RasterXSize
    height = ds.RasterYSize
    
    # Calculate extent based on geotransform and size
    xmin = gt[0]
    xmax = gt[0] + gt[1] * width
    ymin = gt[3] + gt[5] * height
    ymax = gt[3]
    
    return xmin, ymin, xmax, ymax

# Input files

mcd_pre_infile = 'filepath/Forest_height_2019_NAM.tif'
csvtiles = '/filepath/shapefile/gridlist.csv'



# Loop over each iteration or file (add more paths if needed)


# Open the CSV file
with open(csvtiles, newline='') as csvfile:
    csvreader = csv.DictReader(csvfile)  # Using DictReader to access columns by name
    
    # Iterate through each row
    for row in csvreader:
        print(row['id'])  # Print the value of the 'id' column
        i = row['id']

        #setwd: 
        wd = '/filepath/' + i 
        os.chdir(wd)

        cutline_shapefile = '/filepath/' + i + '/buffered.shp'
        output_raster_path = '/filepath/' + i + '/gfor_temp.tif'
        gediforest_output = '/filepath/' + i + '/gediforest.tif'
        reference_raster_path = '/filepath/' + i + '/COP30_3979_CGVD_Bld2.tif'  # Reference raster to match

        # Get the extent of the reference raster
        xmin, ymin, xmax, ymax = get_extent(reference_raster_path)
        #remove gedi:
        try:
            os.remove(gediforest_output)
            os.remove(output_raster_path)
        except OSError:
            pass

        # Step 1: Mask and crop to cutline (first gdalwarp)
        command_1 = [
            "gdalwarp",
            "-cutline", cutline_shapefile,
            "-crop_to_cutline",
            mcd_pre_infile,
            output_raster_path
        ]
        subprocess.run(command_1, check=True)

        # Step 2: Align to the reference raster, resample, and adjust extent/resolution (second gdalwarp)
        command_2 = [
            "gdalwarp",
            "-co", "BIGTIFF=YES",           # BigTIFF option for large files
            "-t_srs", "EPSG:3979",           # Set the target SRS to match the reference raster
            "-tr", "30", "30",               # Set target resolution to 30x30
            "-tap",                          # Align output with target raster grid
            "-r", "bilinear",                # Bilinear resampling
            "-dstnodata", "-32767",          # Set NoData value for output
            "-te", str(xmin), str(ymin), str(xmax), str(ymax),  # Set the extent to match reference raster
            output_raster_path,              # Input raster (cropped and masked)
            gediforest_output                # Output file
        ]
        subprocess.run(command_2, check=True)

        print(f"Iteration {i}: Process completed for {gediforest_output}")

print("All iterations completed!")
