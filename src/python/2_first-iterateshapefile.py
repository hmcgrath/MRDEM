# open shapefile, for loop, select feature, get ID,  buffer, create folder with 'id', save buffer, 

import os
from pathlib import Path
import geopandas as gpd
from shapely.geometry import Polygon
import subprocess
from getWFS import *

maindir = "D:/mcdtm-v2/" #set a main directory
#location of file with tiles to process
matershapefile = "your file/tile location & name"
os.chdir(maindir)

gdf_poly = gpd.read_file(matershapefile)

from shapely.geometry import box
import math

def adjust_buffer_bbox(minx, miny, maxx, maxy, buffer_size=275, divisible_by=30):
    """
    Expands a bounding box by a buffer while ensuring final dimensions are divisible by a specified value.
    
    Parameters:
        minx, miny, maxx, maxy (float): Original bounding box coordinates.
        buffer_size (float): Initial buffer size to apply.
        divisible_by (int): The value both width and height must be divisible by.

    Returns:
        shapely.geometry.Polygon: Adjusted bounding box with correct dimensions.
    """

    # Apply initial buffer
    new_minx = minx - buffer_size
    new_maxx = maxx + buffer_size
    new_miny = miny - buffer_size
    new_maxy = maxy + buffer_size

    # Calculate width and height
    width = new_maxx - new_minx
    height = new_maxy - new_miny

    # Adjust to ensure divisibility
    adjusted_width = math.ceil(width / divisible_by) * divisible_by
    adjusted_height = math.ceil(height / divisible_by) * divisible_by

    # Compute adjustments
    adjusted_buffer_x = (adjusted_width - width) / 2
    adjusted_buffer_y = (adjusted_height - height) / 2

    # Create adjusted bbox
    adjusted_bbox = box(
        new_minx - adjusted_buffer_x,
        new_miny - adjusted_buffer_y,
        new_maxx + adjusted_buffer_x,
        new_maxy + adjusted_buffer_y,
    )

    return adjusted_bbox


# Iterate through the rows of the GeoDataFrame
# Iterate through the rows of the GeoDataFrame
for idx, row in gdf_poly.iterrows():
    # Get the ID from the attribute field (assuming 'id' is the column name)
    feature_id = row['id']
    print(f"Processing feature with ID: {feature_id}")

    # Create a directory for this feature ID
    selecteddirectory = os.path.join(maindir, str(feature_id))
    Path(selecteddirectory).mkdir(parents=True, exist_ok=True)
    
    # Check if "BuildingsCombined.tif" exists in the feature directory
    buildings_combined_path = os.path.join(selecteddirectory, "BuildingsCombined.tif")

    if os.path.exists(buildings_combined_path):
        print("BuildingsCombined.tif already exists. Skipping process.")
    else:
        print("BuildingsCombined.tif not found. Proceeding with processing.")
        
        # Filter the GeoDataFrame to select the current feature by its ID
        selected_feature = gdf_poly[gdf_poly['id'] == feature_id]
        
        # Save the selected feature as a new shapefile in the feature's directory
        selected_feature.to_file(os.path.join(selecteddirectory, 'tile.shp'))

        # Read the saved shapefile and buffer the selected polygon
        selected_buffered_poly = gpd.read_file(os.path.join(selecteddirectory, 'tile.shp'))

        # Check if there are multiple geometries and buffer each one
        buffered_geometries = selected_buffered_poly.geometry.apply(lambda geom: geom.buffer(275))
        # Get bounding box (minx, miny, maxx, maxy) from the GeoDataFrame
        #minx, miny, maxx, maxy = selected_buffered_poly.total_bounds
        #print(f"Bounding Box: {minx}, {miny}, {maxx}, {maxy}")
        #buffered_geometries = adjust_buffer_bbox(minx, miny, maxx, maxy)
        print(buffered_geometries)


        # Create a new GeoDataFrame for the buffered geometries
        buffered_gdf = gpd.GeoDataFrame(selected_buffered_poly.drop(columns='geometry'), geometry=buffered_geometries, crs=selected_buffered_poly.crs)

        # Save the buffered polygon to a new shapefile
        buffered_gdf.to_file(os.path.join(selecteddirectory, 'buffered.shp'))

    # Define the paths and variables
        cutline_shapefile = os.path.join(selecteddirectory, 'buffered.shp')
        mcd_pre_infile = "name/location of dsm to process"
        mcd_clipfile = os.path.join(selecteddirectory, 'dsm30.tif')  # Replace with the actual path to $MCD_CLIPFILE
        
        # Construct the gdalwarp command
        command = [
            'gdalwarp',
            '-cutline', cutline_shapefile,
            '-crop_to_cutline',
            #'-tap', 
            mcd_pre_infile,
            mcd_clipfile
        ]

        # Execute the command using subprocess.run
        try:
            subprocess.run(command, check=True)
            print("gdalwarp command executed successfully")
        except subprocess.CalledProcessError as e:
            print(f"Error occurred: {e}")


        
        bs = os.path.join(selecteddirectory, 'buffered.shp')
        dm = os.path.join(selecteddirectory, 'dsm30.tif')

            # Check if "BuildingsCombined.tif" exists in the current directory
        if os.path.exists("BuildingsCombined.tif"):
            print("do nothing")
        else:
            # Call the function
            getWSFfromOnline(selecteddirectory, bs, dm)

        