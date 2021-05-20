# GENERATING IMAGE METADATA FROM SATELLITE IMAGES

"""
After running this, load the records into geocrud.image_bounds table, then create
the 2 views using create_image_bounds_views.sql

James' original script (gen_image_md_from_rfi_masked_images.py) had ways to deal with cases where there were
multiple RFI masks for the same image. Since we mask RFI afterwards generating zonal stats, not before,
we don't need this anymore.
"""

import os
import rasterio
# import pandas as pd
import csv

# Relevant Scottish images:

#scotland_images = pd.read_csv("rfi_id_sheet_14_10_2020.csv")

# Define list of images and function:

def generate_metadata(path_to_sat_images, out_csv_name):

    sat_images_to_use = []

    for root, folders, files in os.walk(path_to_sat_images, followlinks=True):

        # Generate list of satellite images to use:

        for file in files:

            # This splits the extension and the filename into a vector, and removes the filename
            # to check if it's a TIF file:

            if os.path.splitext(file)[-1] == ".tif":

                file_to_use = os.path.join(root, file)
                sat_images_to_use.append(file_to_use)

    with open(out_csv_name, "w", newline='') as output:

        my_writer = csv.writer(output, delimiter=",", quotechar='"', quoting=csv.QUOTE_NONNUMERIC)

        # Initialise header row

        my_writer.writerow(["path_to_img", "img_min_x", "img_min_y", "img_max_x", "img_max_y"])

        print('Images used:')
        for img in sat_images_to_use:
            # If path is non-empty (sat_images_to_use will also contain NAs):
            if os.path.exists(img):
                # Print file name to check what's being used:
                print(str(img))
                # Append a row to the CSV containing filename and bounds:
                with rasterio.open(img) as src:
                    my_writer.writerow([
                        img,
                        src.bounds.left,
                        src.bounds.bottom,
                        src.bounds.right,
                        src.bounds.top
                    ])