import csv
import os
from datetime import date
import rasterio
from rasterio.windows import Window
from rasterstats import zonal_stats
import numpy as np
import fiona
import shapely
from shapely.geometry import shape, Polygon
#from shapely.wkt import loads
from shapely.wkb import loads
import click


def get_aoi_from_shapefile(shp_fname, buffer_d=100):
    """
    from a shapefile obtain it`s buffered extent as an AOI

    :param shp_fname:
    :param buffer_d:
    :return:
    """
    aoi_min_x, aoi_min_y, aoi_max_x, aoi_max_y = None, None, None, None

    if os.path.exists(shp_fname):
        with fiona.open(shp_fname, "r") as shp_src:
            (min_x, min_y, max_x, max_y) = shp_src.bounds
            shp_src_extent = Polygon([(min_x, min_y), (max_x, min_y), (max_x, max_y), (min_x, max_y)])
            aoi = shp_src_extent.buffer(buffer_d)
            (aoi_min_x, aoi_min_y, aoi_max_x, aoi_max_y) = aoi.bounds

    return aoi_min_x, aoi_min_y, aoi_max_x, aoi_max_y



def fetch_image_metadata_from_csv_filtered(md_csv_fname, zones_shp_fname, buffer_d=100):

    image_metadata = None
    all_record_count, filtered_record_count = 0, 0

    if os.path.exists(zones_shp_fname):
        aoi_geom = None

        if os.path.exists(zones_shp_fname):
            with fiona.open(zones_shp_fname, "r") as shp_src:
                (min_x, min_y, max_x, max_y) = shp_src.bounds
                shp_src_extent = Polygon([(min_x, min_y), (max_x, min_y), (max_x, max_y), (min_x, max_y)])
                aoi_geom = shp_src_extent.buffer(buffer_d)

        if aoi_geom is not None:
            image_metadata = {}

            if os.path.exists(md_csv_fname):
                with open(md_csv_fname, "r", newline='') as inpf:
                    my_reader = csv.DictReader(inpf)
                    for r in my_reader:
                        # TODO - check what type the geom is before importing
                        # e.g. had to convert the old code from shapely.wkt.loads(.) to shapely.wkb.loads(., hex=True)
                        # to be able to load hexadecimal binary geometries (generated in PostgreSQL)
                        path_to_img = r["path_to_img"]
                        image_day = r["image_day"]
                        image_month = r["image_month"]
                        image_year = r["image_year"]
                        geom_bng = r["geom_bng"]
                        md_geom = shapely.wkb.loads(geom_bng, hex = True)
                        if md_geom.intersects(aoi_geom):
                            image_metadata[path_to_img] = [image_day, image_month, image_year]
                            filtered_record_count += 1
                        all_record_count += 1

    return image_metadata


def fetch_zonal_polygons_from_shapefile(shp_fname):

    zonal_polygons = {}

    if os.path.exists(shp_fname):

        with fiona.open(shp_fname, "r") as shp_src:
            # TODO - check the shapefile has the required fields
            # do something like this:
            if all(i in ["GID", "FID_1", "geometry", "LCGROUP", "LCTYPE"] for i in (shp_src.schema["properties"]).keys()):
                for feature in shp_src:
                    gid = feature["properties"]["GID"]
                    fid_1 = feature["properties"]["FID_1"]
                    geom = shape(feature["geometry"])
                    area = geom.area
                    lcgroup = feature["properties"]["LCGROUP"]
                    lctype = feature["properties"]["LCTYPE"]
                    zonal_polygons[gid] = {
                        "geom": geom,
                        "area": area,
                        "fid_1": fid_1,
                        "lcgroup": lcgroup,
                        "lctype": lctype
                    }
            # If names are not that (but instead in lower-case):
            else:
                for feature in shp_src:
                    gid = feature["properties"]["gid"]
                    fid_1 = feature["properties"]["fid_1"]
                    geom = shape(feature["geometry"])
                    area = geom.area
                    lcgroup = feature["properties"]["lcgroup"]
                    lctype = feature["properties"]["lctype"]
                    zonal_polygons[gid] = {
                        "geom": geom,
                        "area": area,
                        "fid_1": fid_1,
                        "lcgroup": lcgroup,
                        "lctype": lctype
                    }

    return zonal_polygons

def fetch_window_from_raster(fname, aoi_geo_min_x, aoi_geo_min_y, aoi_geo_max_x, aoi_geo_max_y, band=1, dbg=False):
    """
    use rasterio to fetch a sub-window from a raster

    :param fname: the raster to fetch from
    :param aoi_geo_min_x: llx of sub-window to fetch
    :param aoi_geo_min_y: lly of sub-window to fetch
    :param aoi_geo_max_x: urx of sub-window to fetch
    :param aoi_geo_max_y: ury of sub-window to fetch
    :param band: band to fetch from the raster
    :param dbg: print debug messages
    :return: the sub-region as a NumPy ndarray, the affine transformation matrix for the sub-window
    """

    the_window = None
    window_all_nodata = False

    with rasterio.open(fname) as src:

        w = src.width
        h = src.height
        max_row = h  # y
        max_col = w  # x

        if dbg:
            print("Width: {}".format(w))
            print("Height: {}".format(h))

        # get transform for whole image that maps pixel (row,col) location to geospatial (x,y) location
        affine = src.transform

        if dbg:
            print(rasterio.transform.xy(affine, rows=[0, max_row], cols=[0, max_col]))

        rows, cols = rasterio.transform.rowcol(affine, xs=[aoi_geo_min_x, aoi_geo_max_x],
                                               ys=[aoi_geo_min_y, aoi_geo_max_y])

        aoi_img_min_col = cols[0]
        aoi_img_min_row = rows[0]
        aoi_img_max_col = cols[1]
        aoi_img_max_row = rows[1]

        if dbg:
            print(aoi_img_min_col, aoi_img_min_row, aoi_img_max_col, aoi_img_max_row)

        aoi_width = aoi_img_max_col - aoi_img_min_col
        aoi_height = aoi_img_min_row - aoi_img_max_row

        if dbg:
            print(aoi_width, aoi_height)

        # just read a window from the complete image
        # rasterio.windows.Window(col_off, row_off, width, height)
        this_window = Window(aoi_img_min_col, aoi_img_min_row - aoi_height, aoi_width, aoi_height)
        the_window = src.read(band, window=this_window)


        #possibly unreliable test to check if the returned window is all nodata values i.e. the part of
        #the image contains no RS data

        if dbg:
            print("Testing if entire window is nodata for img {}".format(fname))
            print("Window Shape", the_window.shape, the_window.shape[0], the_window.shape[1])

        if the_window.shape[1] == 0:
            # this will be the case if the requested window fell completely outside the extent of the image
            window_all_nodata = True
        else:
            # Check if the returned window has zeros in the minimum, maximum, and the mean.
            # If it does, assume no data is contained within the window.
            minimum = the_window.min(initial=0)
            maximum = the_window.max(initial=0)
            mean = the_window.mean()
            if dbg:
                print("Minimum: {}, Maximum: {}, Mean: {}".format(minimum, maximum, mean))
            # If these values are null or equal to 0, deem window to be nodata.
            if (np.isnan(minimum) or minimum == 0) and (np.isnan(maximum) or maximum == 0) and (
                    np.isnan(mean) or mean == 0):
                window_all_nodata = True

            # NB: Original script checked for first/last values and had the following note:

            # TODO - replace with more robust np.isnan(src.read(1)).all() calls to check entire window for nodata
            # however this will be complicated in cases where the window has pixel value 0 which in the S1 data
            # seems to be the 'yellow' strip of data which runs round the edge of the scene

        if dbg:
            print(the_window.size)

        if dbg:
            if window_all_nodata:
                print("window seems to be all nodata")
                print((the_window[0]).tolist())
                print((the_window[the_window.shape[0] - 1]).tolist())
            else:
                print("window seems NOT to be all nodata")
                print((the_window[0]).tolist())
                print((the_window[the_window.shape[0] - 1]).tolist())

            # the affine transformation of a window differs from the entire image
            # https://github.com/mapbox/rasterio/blob/master/docs/topics/windowed-rw.rst
            # so get transform just for the window that maps pixel (row, col) location to geospatial (x,y) location
        win_affine = src.window_transform(this_window)
        # print(win_affine)

        affine = win_affine

    # return the window (NumPy) array, the transformation matrix for the window providing img->geo location, and a
    # flag indicating if we think the window is just all nodata
    return the_window, affine, window_all_nodata


def my_variance(x):
    """
    rasterstats does not provide a variance statistic as part of the
    suite of zonal statistics that it provides so we need to use it`s
    ability to include user-defined statistics to return the variance

    https://pythonhosted.org/rasterstats/manual.html#user-defined-statistics
    https://docs.scipy.org/doc/numpy/reference/generated/numpy.var.html

    :param x:
    :return:
    """
    return np.var(x)


def generate_zonal_stats(image_metadata, zones_shp_fname, output_path):
    """

    :param image_metadata:
    :param zones_shp_fname:
    :return:
    """
    out_data = {}
    gt_polygons = fetch_zonal_polygons_from_shapefile(shp_fname=zones_shp_fname)
    aoi_geo_min_x, aoi_geo_min_y, aoi_geo_max_x, aoi_geo_max_y = get_aoi_from_shapefile(zones_shp_fname)
    zs_fname = os.path.join(output_path, (os.path.split(zones_shp_fname)[-1]).replace(".shp", "_zonal_stats_for_ml.csv"))

    with open(zs_fname, "w", newline='') as outpf:

        all_dates = []

        for img_fname in image_metadata:
            image_day = image_metadata[img_fname][0]
            image_month = image_metadata[img_fname][1]
            image_year = image_metadata[img_fname][2]
            image_date = str(date(int(image_year), int(image_month), int(image_day)))
            if image_date not in all_dates:
                all_dates.append(image_date)
        indexed_all_dates = {}

        # In case there are no dates, use this header:
        header = ["Id", "FID_1", "LCGROUP", "LCTYPE", "AREA"]

        idx = 1
        for i in sorted(all_dates):
            indexed_all_dates[idx] = i
            idx += 1
            # In case there are dates, append this with dates:
            header = ["Id", "FID_1", "LCGROUP", "LCTYPE", "AREA"]
            # band1 is VV
            # band2 is VH
            for b in (1, 2):
                for i in sorted(indexed_all_dates.keys()):
                    datestamp = indexed_all_dates[i]
                    if b == 1:
                        header.append("_".join([datestamp, "VV", "mean"]))
                        header.append("_".join([datestamp, "VV", "range"]))
                        header.append("_".join([datestamp, "VV", "variance"]))
                    if b == 2:
                        header.append("_".join([datestamp, "VH", "mean"]))
                        header.append("_".join([datestamp, "VH", "range"]))
                        header.append("_".join([datestamp, "VH", "variance"]))

        # write the header to the csv
        my_writer = csv.writer(outpf, delimiter=',', quotechar='"', quoting=csv.QUOTE_NONNUMERIC)
        my_writer.writerow(header)

        # loop through images
        for img_fname in image_metadata:

            image_day = image_metadata[img_fname][0]
            image_month = image_metadata[img_fname][1]
            image_year = image_metadata[img_fname][2]

            image_date = str(date(int(image_year), int(image_month), int(image_day)))

            this_win_b1, this_affine_b1, window_all_nodata_b1 = fetch_window_from_raster(img_fname, aoi_geo_min_x, aoi_geo_min_y, aoi_geo_max_x, aoi_geo_max_y, band=1)
            this_win_b2, this_affine_b2, window_all_nodata_b2 = fetch_window_from_raster(img_fname, aoi_geo_min_x, aoi_geo_min_y, aoi_geo_max_x, aoi_geo_max_y, band=2)

            # skip calculating zonal stats for images where the returned window onto the image is all 'nodata'
            if (not window_all_nodata_b1) and (not window_all_nodata_b2):
                # in each image window, loop through gt polygons
                for gid in gt_polygons:
                    gt_poly = gt_polygons[gid]["geom"]
                    gt_poly_area = gt_polygons[gid]["area"]
                    gt_fid_1 = gt_polygons[gid]["fid_1"]
                    lcgroup = gt_polygons[gid]["lcgroup"]
                    lctype = gt_polygons[gid]["lctype"]

                    # fetch zonal stats for the polygon from band1 of the image window
                    zs_b1 = zonal_stats(
                        gt_poly,
                        this_win_b1,
                        affine=this_affine_b1,  # affine needed as we are passing in an ndarray
                        stats=["count", "mean", "range"],  # zonal stats we want
                        add_stats={'variance': my_variance},
                        all_touched=False  # include every cell touched by geom or only cells with center within geom
                    )[0]
                    skip = False

                    # we need to skip cases where the data is like this
                    if zs_b1["mean"] == "" and zs_b1["range"] == "" and zs_b1["variance"] == "--":
                        skip = True

                    # or this
                    if zs_b1["mean"] == "0.0" and zs_b1["range"] == "0.0" and zs_b1["variance"] == "0.0":
                        skip = True

                    # add the zonal stats from band1 to the output data
                    if not skip:
                        if gid not in out_data:
                            out_data[gid] = {
                                "gt_fid_1": gt_fid_1,
                                "lcgroup": lcgroup,
                                "lctype": lctype,
                                "area": gt_poly_area,
                                "band_data": {
                                    1: {},
                                    2: {}
                                }
                            }

                        band_n = 1
                        out_data[gid]["band_data"][band_n][image_date] = [zs_b1["mean"], zs_b1["range"], zs_b1["variance"]]

                    # fetch zonal stats for the polygon from band2 of the image window
                    zs_b2 = zonal_stats(
                        gt_poly,
                        this_win_b2,
                        affine=this_affine_b2,  # affine needed as we are passing in an ndarray
                        stats=["count", "mean", "range"],  # zonal stats we want
                        add_stats={'variance': my_variance},
                        all_touched=False  # include every cell touched by geom or only cells with center within geom
                    )[0]
                    skip = False

                    # we need to skip cases where the data is like this
                    if zs_b2["mean"] == "" and zs_b2["range"] == "" and zs_b2["variance"] == "--":
                        skip = True

                    # or this
                    if zs_b2["mean"] == "0.0" and zs_b2["range"] == "0.0" and zs_b2["variance"] == "0.0":
                        skip = True

                    # add the zonal stats from band2 to the output data
                    if not skip:
                        if gid not in out_data:
                            out_data[gid] = {
                                "gt_fid_1": gt_fid_1,
                                "lcgroup": lcgroup,
                                "lctype": lctype,
                                "area": gt_poly_area,
                                "band_data": {
                                    1: {},
                                    2: {}
                                }
                            }

                        band_n = 2
                        out_data[gid]["band_data"][band_n][image_date] = [zs_b2["mean"], zs_b2["range"], zs_b2["variance"]]
            else:
                print("Skipped {} since window seemed to contain no data".format(img_fname))

        # write out all the output data to the csv
        for gt_poly_id in sorted(out_data.keys()):
            ml_data = [gt_poly_id]
            fid_1 = out_data[gt_poly_id]["gt_fid_1"]
            ml_data.append(fid_1)

            lcgroup = out_data[gt_poly_id]["lcgroup"]
            ml_data.append(lcgroup)

            lctype = out_data[gt_poly_id]["lctype"]
            ml_data.append(lctype)

            area = out_data[gt_poly_id]["area"]
            ml_data.append(area)

            for b in (1, 2):
                band_data = out_data[gt_poly_id]["band_data"][b]
                for i in sorted(indexed_all_dates.keys()):
                    datestamp = indexed_all_dates[i]
                    zs_mean = None
                    zs_range = None
                    zs_variance = None
                    if datestamp in band_data:
                        zs_mean = band_data[datestamp][0]
                        zs_range = band_data[datestamp][1]
                        zs_variance = band_data[datestamp][2]
                    ml_data.append(zs_mean)
                    ml_data.append(zs_range)
                    ml_data.append(zs_variance)
            my_writer.writerow(ml_data)

    return zs_fname


@click.command()
@click.argument('zones_shp_fname', type=click.Path(exists=True))
@click.argument('image_metadata_fname', type=click.Path(exists=True))
@click.argument('output_path', type=click.Path(exists=True))

def fetch_zonal_stats_for_shapefile(zones_shp_fname, image_metadata_fname, output_path):
    # get image metadata which determines which images we collect zonal stats from
    image_metadata = fetch_image_metadata_from_csv_filtered(image_metadata_fname, zones_shp_fname, buffer_d=100)

    # generate zonal stats
    print("[1] generating zonal stats for {}".format(zones_shp_fname))
    generate_zonal_stats(image_metadata, zones_shp_fname, output_path)


def mp_fetch_zonal_stats_for_shapefile(job_params):
    """

    version of fetch_zonal_stats_from_shapefile() to have list of params
    mapped to it in a processing pool

    :param job_params: params of fetch_zonal_stats_from_shapefile() as a list
    :return:
    """
    zones_shp_fname = job_params[0]
    image_metadata_fname = job_params[1]
    output_path = job_params[2]

    # get image metadata which determines which images we collect zonal stats from
    image_metadata = fetch_image_metadata_from_csv_filtered(image_metadata_fname, zones_shp_fname, buffer_d=100)

    # generate zonal stats
    print("[1] generating zonal stats for {}".format(zones_shp_fname))
    generate_zonal_stats(image_metadata, zones_shp_fname, output_path)


if __name__ == "__main__":
    fetch_zonal_stats_for_shapefile()
