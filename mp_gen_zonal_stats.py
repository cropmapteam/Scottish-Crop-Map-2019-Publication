"""
    use python multiprocessing to process zonal stats in parallel
    using blocks of partitioned zonal shapefiles
"""
import glob
import os
from multiprocessing import Pool
import click
# is our python stuff to generate the zonal stats
from gen_zonal_stats import mp_fetch_zonal_stats_for_shapefile


@click.command()
@click.argument('path_to_shapefiles', type=click.Path(exists=True))
@click.argument('image_metadata_fname', type=click.Path(exists=True))
@click.argument('output_path', type=click.Path(exists=True))
@click.argument('num_of_cores', type=click.IntRange(min=1, max=os.cpu_count()))

def fetch_zonal_stats_for_shapefiles(path_to_shapefiles, image_metadata_fname, output_path, num_of_cores):
    """

    :param path_to_shapefiles: is the folder of shapefiles we want to generate zonal statistics for
    :param image_metadata_fname: the path to the image metadata i.e. data/image_bounds_meta.csv
    :param output_path: where to output the zonal stats csvs
    :param num_of_cores: the number of cpu cores to spread zonal stats over epcc vm has 16 so specify 12
    :return:
    """
    jobs = []
    path_to_shps = os.path.join(path_to_shapefiles, "*.shp")

    # assemble jobs list: [[zones_shp_fname, image_metadata_fname, output_path], ...]
    # each item in the list is a new job that will processed
    for zones_shp_fname in glob.glob(path_to_shps):
        jobs.append([zones_shp_fname, image_metadata_fname, output_path])

    pool = Pool(processes=num_of_cores)
    pool.map(mp_fetch_zonal_stats_for_shapefile, jobs)


if __name__ == "__main__":
    fetch_zonal_stats_for_shapefiles()
