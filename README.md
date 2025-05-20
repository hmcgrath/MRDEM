# MRDEM
code to extract settled areas and forests from Copernicus GLO30 for Canada

## Description
This code is a mix of python and R scripts which uses several online datasets to remove settled features and forests to create a bare-earth terrain model from the Copernicus GLO30 surface model. 
The auxilliary datasets include: 
- Copernicus GLO 30 Digital Elevation Model: https://portal.opentopography.org/raster?opentopoID=OTSDEM.032021.4326.3, https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM
- World Settlement Footprint: https://geoservice.dlr.de/web/maps/eoc:wsfevolution
- Global Forest Canopy Height, 2019: https://glad.umd.edu/dataset/gedi
- Canadian Forest Elevation(Ht) Mean 2015: https://open.canada.ca/data/en/dataset/7cbdfae1-f724-4679-8f0f-1c611f17186f

### Steps: 
1. Extract data from COP GLO 30
2. Extract settlement data
3. Process settlement data to remove expected buildings present in DSM. 
4. Fill the removed settled areas
5. Extract Canadian forests data and process
6. Extract Global Forest Canopy data and process
7. Merge the forests datasets
8. Subtract the forest from the GLO30 with settlements removed. 

### Requirements
In R, the whitebox tools libary is used, in Python, GDAL and rasterio are used extensively. 

### Contact
if you have questions or issues, please submit an issue in the repository. 

