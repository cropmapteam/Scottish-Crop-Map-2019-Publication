# Scottish-Crop-Map-2019-Publication
Within this repository you will find the code used to produce zonal statistics from radar images and the code used to perform random forest models on those statistics.

The Experimental Statistics ‘Crop Map of Scotland’ is a map of all the agricultural fields in Scotland categorised into the likely main crop types which were grown in 2019. The statistics from the map are designated as ‘experimental’ because the methods used to assign the crop types are novel and are under review.

This repository contains the code used to develop methods and statistics for the first iteration of the Scottish Crop Map field predictions for 2019.

Further details regarding this publication are available on the Scottish Government website, please follow this link https://www.gov.scot/ISBN/978-1-80201-000-8.

If you are interested in reviewing our methods and data please get in touch at agric.stats@gov.scot.

## Zonal Statistics
This branch contains code used to transform satellite images into a dataset. This dataset is then used in the random forest modelling (see the `random_forest` branch).

Radar images from the Sentinel-1 satellites between Mar-Oct 2019 are used for this purpose. These images are available on the [CEDA](https://www.ceda.ac.uk/) archive and are obtained using the [Simple ARD](https://jncc.gov.uk/our-work/simple-ard-service/) service by [JNCC](https://jncc.gov.uk/), who also pre-process the images and provide extensive technical support.

The `geoprocessing` branch shows the code used to:

* Create zonal statistics from satellite images
* Validate results from these zonal statistics
* Group zonal statistics into six-day blocks

This code cannot be run as-is: it requires access to satellite images as well as additional files such as field shapefiles and image metadata, which we cannot share in this repository. For more information on this process, please get in touch at the above email address. The output dataset can be provided upon request (this is needed to run the random forest model code).

Earlier versions of some of these scripts, as well as an additional README file, is provided in our [Scotland-crop-map](https://github.com/cropmapteam/Scotland-crop-map) repository (in collaboration with EDINA).

## Random Forest Model
The `random_forest` branch shows code used to create the random forest model and its predictions. This has been split into 5 different sections:
* Interpolating & Preparing Data - code to deal with missing data and format the zonal statistics dataset 
* Random Forest Modelling - code to create the model
* Model Improvements & Variable Selection - comments about changes made to the model and code used for several different selection methods 
* Running Code on Reduced Zonal Data - code to run the model on the reduced dataset 
* Probability Cut-Off on Predictions - code to deal with overestimation by using class probabilities on model predictions
