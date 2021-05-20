# Zonal Statistics
This branch contains code used to transform satellite images into a dataset. This dataset is then used in the random forest modelling (see the `random_forest` branch).

Radar images from the Sentinel-1 satellites between Mar-Oct 2019 are used for this purpose. These images are available on the [CEDA](https://www.ceda.ac.uk/) archive and are obtained using the [Simple ARD](https://jncc.gov.uk/our-work/simple-ard-service/) service by [JNCC](https://jncc.gov.uk/), who also pre-process the images and provide extensive technical support.

The `geoprocessing` branch shows the code used to:

* Create zonal statistics from satellite images
* Validate results from these zonal statistics
* Group zonal statistics into six-day blocks

This code cannot be run as-is: it requires access to satellite images as well as additional files such as field shapefiles and image metadata, which we cannot share in this repository. For more information on this process, please get in touch at agric.stats@gov.scot. The output dataset can be provided upon request (this is needed to run the random forest model code).

Earlier versions of some of these scripts, as well as an additional README file, is provided in our [Scotland-crop-map](https://github.com/cropmapteam/Scotland-crop-map) repository (in collaboration with EDINA).

## Generating zonal statistics
The `gen_image_md.py`, `gen_zonal_stats.py`, `mp_gen_zonal_stats.py`, and `validation.py` scripts are used to generate image metadata, load and write zonal statistics, and validate results. For more information on these scripts and the process, see the README in the [geoprocessing](https://github.com/cropmapteam/Scotland-crop-map/tree/geoprocessing/zonal_experiments) branch of the [Scotland-crop-map](https://github.com/cropmapteam/Scotland-crop-map) repository.

These scripts need the following files:

* A shapefile with the required geometries you want to generate zonal statistics for. these need to be sufficiently small to be captured in one or more images.
* Access to satellite images.

## Generating dates and pass lookups
The `gen_dates.R` script is used to generate a list of dates to validate results against in the `validation.py` script. The `gen_pass_lookup.R` script is used to generate a lookup of dates and 'passes' based on the Sentinel-1 footprint for Scotland (in 2019). These passes are six-day blocks where a given field is likely to have had at least one image taken by either the ascending or descending satellite (with the exception of some islands). These scripts need a metadata CSV and a shapefile of the footprint of Sentinel-1 images.

The `read_and_transform_zonal_stats.R` script uses the dataset generated by `gen_zonal_stats.py` or `mp_gen_zonal_stats.py` to average daily zonal statistics over six-day passes generated by `gen_pass_lookup.R`. This averaged zonal statistics dataset is used in the random forest modelling code. The data was averaged by pass to limit the amount of field-date combinations with a missing value (which had to be removed prior to modelling).
