#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Sep 24 20:36:49 2022

@author: hem000
"""
import os
import json
import geopandas as gpd
import requests
import time
#import rasterio
import csv
from shapely.geometry import Point, Polygon
from osgeo import ogr, osr

folder = 'Astrid' #change this to your folder
outfile = 'COP30.tif'

import geopandas as gpd
import csv

# Open GeoJSON file #made from wsf dataset to identify which tifs from wsf to download
geojson_file = "/WSF/World Settlement Footprint.shp"
gdf = gpd.read_file(geojson_file)

# Open CSV file
csv_file = "csvlist of tiles to process"
path = "pathtosavedatato"
# Iterate through CSV file
# List to store latitude and longitude values
buffer_extents = []
os.chdir("your working dir")


with open(csv_file, 'r') as csvfile:
    csv_reader = csv.DictReader(csvfile)
    for row in csv_reader:
        # Get GRID_ID from CSV
        grid_id = row['id']
        
        selected_feature = gdf[gdf['id'] == grid_id].iloc[0]

        # Transform CRS
        target_crs = 'EPSG:4326'
        gdf = gdf.to_crs(target_crs)
        selected_feature = gdf[gdf['id'] == grid_id].iloc[0]  # Update feature after CRS transformation

        # Get minimum bounding box coordinates
        minx, miny, maxx, maxy = selected_feature.geometry.bounds
        print(minx)
              
        #setup request parameters:
        u_params = {'south': miny, 
                    'north': maxy,
                    'west': minx, 
                    'east': maxx,
                    'outputFormat':'GTiff',
                    'API_Key':''} #add yoru api key here
        
        print(u_params)
        response = requests.get('https://portal.opentopography.org/API/globaldem?demtype=COP30', params=u_params, stream=True)
        
        if response.status_code == 200:
            print('Success!')
            outfile = "yourfilepath/" + "COP" + "_" + grid_id + ".tif"
            #change working directory: 
            #os.chdir(od)
            #depending on the size of the data you've requested, 
            #you may want to access it in chunks so that you don't use up too much memory.
            with open(outfile, 'wb') as f:
                    for chunk in response:
                        f.write(chunk)
            print('COP 30 file written')            
        else:
            print(response)
            print('Not Found.')
           
        time.sleep(10)
        os.chdir(path)


print('Script Complete')
    