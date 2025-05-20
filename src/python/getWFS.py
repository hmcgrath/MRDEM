import os
import geopandas as gpd
import rasterio
import requests
from shapely.geometry import box
from rasterio.merge import merge
from rasterio.enums import Resampling
#from rasterstats import zonal_stats
from gdal_vrt import build_combined_raster
from gdal_crop_hm import get_extent_from_raster
from gdal_crop_hm import checkextent_warp
import subprocess

basewfsgrid = "fielpath/WSF/World Settlement Footprint.shp"
mainblddir = "/filepath"

def remove_empty_tifs(builds):
    excluded_files = ['/WSF/WSF2019_v1_-130_74.tif', '/WSF/WSF2019_v1_-128_74.tif']
    return [tif for tif in builds if os.path.exists(tif) and os.path.getsize(tif) > 0 and tif not in excluded_files]

def getWSFfromOnline(selecteddirectory, buffered_shape, dsm):
    print('Starting getting WSF tiles: ')
    bshape = gpd.read_file(buffered_shape)

    # Open WFS grid
    wfs_grid = gpd.read_file(basewfsgrid)
    wfs_crs = wfs_grid.crs
    
    # Transform input bounding box to the WFS CRS (4326)
    bbox_4326 = bshape.to_crs(wfs_crs)
    
    # Find intersection of bbox_4326 with WFS grid
    intersection = gpd.overlay(wfs_grid, bbox_4326, how='intersection')
    
    if intersection.empty:
        print('No intersection - no buildings')
        dsm.to_file('COP30_3979_CGVD_Bld2.tif', driver='GTiff')
        return
    
    # Get the list of tiles to download
    qlist = intersection['Lon'].astype(int).astype(str) + "_" + intersection['Lat'].astype(int).astype(str)

    builds = []
    for tile_no in qlist:
        tile_no = tile_no.replace(" ", "")
        print(f"Processing tile: {tile_no}")
        
        url = f'https://download.geoservice.dlr.de/WSF2015/files/WSF2015_v2_{tile_no}.tif'
        print(f"URL: {url}")
        
        outfile = os.path.join(mainblddir, f'WSF2019_v1_{tile_no}.tif')
        print(f"Name of outfile for building is: {outfile}")
        
        # Check if the file exists before downloading
        if not os.path.exists(outfile):
            print(f"File does not exist. Downloading: {outfile}")
            # Download the tile if the file does not exist
            # urllib.request.urlretrieve(url, outfile)
            response = requests.get(url, stream=True)
            if response.status_code == 200:
                with open(outfile, 'wb') as file:
                    for chunk in response.iter_content(chunk_size=8192):
                        file.write(chunk)
                print(f"File downloaded successfully: {outfile}")
            else:
                print(f"Failed to download file. Status code: {response.status_code}")
        else:
            print(f"File already exists: {outfile}")
        
        # Add the file to the builds list
        builds.append(outfile)
    
    print(f'List of files to extract/merge: {builds}')
    #gdal built vrt: #first check if ther are empty tifs: 
    builds = remove_empty_tifs(builds)
    print("these are the non-zero files. ")
    print(builds)
    # If there are files to merge, read and merge them
    if builds:
        print('Start to read and merge WSF')
        # Call the function to create the combined VRT
        bcvrt = os.path.join(selecteddirectory, "buildingscombined.vrt")
        build_combined_raster(builds, dsm, bcvrt)
        # Define output TIFF path
        bc_tif = os.path.join(selecteddirectory, "bc.tif")
        buildingstif = os.path.join(selecteddirectory, "BuildingsCombined.tif")
        # Convert VRT to TIFF
        gdalwarp_command = [
            'gdal_translate',
           "-of", "GTiff",
            "-ot", "Byte",
            bcvrt, 
            bc_tif 
        ]
        # Execute the gdalwarp command
        subprocess.run(gdalwarp_command)

        print(f"Saved {bc_tif} successfully.")
        # Get the bounding box from the DSM raster
        extent = get_extent_from_raster(dsm)
        checkextent_warp(extent, bc_tif, buildingstif)
        print(f"Warped {buildingstif} successfully.")
        #### redone up to heere: 

        #find if any buildings: 
        from countnonzero import count_non_zero_pixels
        howmanysettledpixels = count_non_zero_pixels(buildingstif)
        if howmanysettledpixels >0:
            print('Doing building stuff')
            mask_out_buildings('BuildingsCombined.tif')
            from maskWSFinterpolate import maskoutbuildings
            desttif = os.path.join(selecteddirectory, "COP30_3979_CGVD_Bld2.tif")
            maskoutbuildings(selecteddirectory, dsm, buildingstif, output_file="COP30_3979_CGVD_Bld2.tif", xy=3, pe_thresh=1.0, max_distance=3000)
        else:
            print('No buildings')
            import shutil
            desttif = os.path.join(selecteddirectory, "COP30_3979_CGVD_Bld2.tif")
            shutil.copy('BuildingsCombined.tif', desttif)




    #     print("Buildings raster created, now determine if you need to mask out buildings:")
    #     print(mean_value)
        
    #     if mean_value == 0 or mean_value != mean_value:  # NaN check
    #         print('No buildings')
    #         dsm.to_file('COP30_3979_CGVD_Bld2.tif', driver='GTiff')
    #     else:
    #         print('Doing building stuff')
    #         mask_out_buildings('BuildingsCombined.tif')
    # else:
    #     print('Skip buildings')
    #     dsm.to_file('COP30_3979_CGVD_Bld2.tif', driver='GTiff')

def download_file(url, outfile):
    # Download the file from the URL and save it to the output file
    response = requests.get(url, stream=True)
    with open(outfile, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)


def mask_out_buildings(raster_file):
    # Function to mask out buildings - Placeholder function for your specific logic
    print(f"Masking out buildings from {raster_file}")
    # Implement the actual logic to mask out buildings as needed
    pass
