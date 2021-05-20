
"""
    mp_py_zonal_stats.py will produce a csv for every partition of zones that zonal stats were calculated for
    this script concatenates these individual csv`s into a single csv. Concatenation is complicated by the fact
    that each of the individual csv`s may have a different number of columns as reflecting the images/dates which
    were available for that particular parttions. So the single concatenated csv file has a column count equal to
    the number of columns across the entire dataset with null values for the gaps.
    the script also does a bunch of validation of the individual csv files that mp_py_zonal_stats.py produced by
    checking the csvs against the src shapefiles and reports cases of:
    - missing csvs, i.e. have the src shapefile but no csv
    - reporting csv`s which have no records
    - reporting csv`s which have a record count which differs from the feature count of the src shapefile
    missing csv`s would indicate the processing job failed and needs to be investigated/re-ran
    csv`s which have no records would indicate that the src shape partition fell entirely outside image coverage
    csv`s which have a record count which is not equal to feature count of src shapefile would indicate that some of the
     features in the shapefile fell outside image coverage
"""
import csv
import glob
import os
import fiona


def form_empty_out_record():
    """
    representation of a record in the csv of S1 zonal stats that are passed to the R ml process
    this is the 5 std Id, FID_1, LCGROUP, LCTYPE, AREA columns
    plus number_of_dates x number_of_bands x number of zs stats i.e. 50 x 2 x 3 = 300
    so 305 columns overall
    IF dates changes this will need updated
    :return:
    """
    processed_scenes_dates = {
        1: '2019-03-01',
        2: '2019-03-02',
        3: '2019-03-03',
        4: '2019-03-04',
        5: '2019-03-05',
        6: '2019-03-06',
        7: '2019-03-07',
        8: '2019-03-08',
        9: '2019-03-09',
        10: '2019-03-10',
        11: '2019-03-11',
        12: '2019-03-12',
        13: '2019-03-13',
        14: '2019-03-14',
        15: '2019-03-15',
        16: '2019-03-16',
        17: '2019-03-17',
        18: '2019-03-18',
        19: '2019-03-19',
        20: '2019-03-20',
        21: '2019-03-21',
        22: '2019-03-22',
        23: '2019-03-23',
        24: '2019-03-24',
        25: '2019-03-25',
        26: '2019-03-26',
        27: '2019-03-27',
        28: '2019-03-28',
        29: '2019-03-29',
        30: '2019-03-30',
        31: '2019-03-31',
        32: '2019-04-01',
        33: '2019-04-02',
        34: '2019-04-03',
        35: '2019-04-04',
        36: '2019-04-05',
        37: '2019-04-06',
        38: '2019-04-07',
        39: '2019-04-08',
        40: '2019-04-09',
        41: '2019-04-10',
        42: '2019-04-11',
        43: '2019-04-12',
        44: '2019-04-13',
        45: '2019-04-14',
        46: '2019-04-15',
        47: '2019-04-16',
        48: '2019-04-17',
        49: '2019-04-18',
        50: '2019-04-19',
        51: '2019-04-20',
        52: '2019-04-21',
        53: '2019-04-22',
        54: '2019-04-23',
        55: '2019-04-24',
        56: '2019-04-25',
        57: '2019-04-26',
        58: '2019-04-27',
        59: '2019-04-28',
        60: '2019-04-29',
        61: '2019-04-30',
        62: '2019-05-01',
        63: '2019-05-02',
        64: '2019-05-03',
        65: '2019-05-04',
        66: '2019-05-05',
        67: '2019-05-06',
        68: '2019-05-07',
        69: '2019-05-08',
        70: '2019-05-09',
        71: '2019-05-10',
        72: '2019-05-11',
        73: '2019-05-12',
        74: '2019-05-13',
        75: '2019-05-14',
        76: '2019-05-15',
        77: '2019-05-16',
        78: '2019-05-17',
        79: '2019-05-18',
        80: '2019-05-19',
        81: '2019-05-20',
        82: '2019-05-21',
        83: '2019-05-22',
        84: '2019-05-23',
        85: '2019-05-25',
        86: '2019-05-26',
        87: '2019-05-27',
        88: '2019-05-28',
        89: '2019-05-29',
        90: '2019-05-30',
        91: '2019-05-31',
        92: '2019-06-10',
        93: '2019-06-08',
        94: '2019-06-16',
        95: '2019-06-03',
        96: '2019-06-05',
        97: '2019-06-07',
        98: '2019-06-23',
        99: '2019-06-30',
        100: '2019-06-04',
        101: '2019-06-24',
        102: '2019-06-12',
        103: '2019-06-19',
        104: '2019-06-25',
        105: '2019-06-26',
        106: '2019-06-22',
        107: '2019-06-21',
        108: '2019-06-09',
        109: '2019-06-13',
        110: '2019-06-18',
        111: '2019-06-28',
        112: '2019-06-11',
        113: '2019-06-06',
        114: '2019-06-14',
        115: '2019-06-27',
        116: '2019-06-15',
        117: '2019-06-17',
        118: '2019-06-01',
        119: '2019-06-20',
        120: '2019-06-02',
        121: '2019-06-29',
        122: '2019-07-01',
        123: '2019-07-02',
        124: '2019-07-03',
        125: '2019-07-04',
        126: '2019-07-05',
        127: '2019-07-06',
        128: '2019-07-07',
        129: '2019-07-08',
        130: '2019-07-09',
        131: '2019-07-10',
        132: '2019-07-11',
        133: '2019-07-12',
        134: '2019-07-13',
        135: '2019-07-14',
        136: '2019-07-15',
        137: '2019-07-16',
        138: '2019-07-17',
        139: '2019-07-18',
        140: '2019-07-19',
        141: '2019-07-20',
        142: '2019-07-21',
        143: '2019-07-22',
        144: '2019-07-23',
        145: '2019-07-24',
        146: '2019-07-25',
        147: '2019-07-26',
        148: '2019-07-27',
        149: '2019-07-28',
        150: '2019-07-29',
        151: '2019-07-30',
        152: '2019-07-31',
        153: '2019-08-01',
        154: '2019-08-02',
        155: '2019-08-03',
        156: '2019-08-04',
        157: '2019-08-05',
        158: '2019-08-06',
        159: '2019-08-07',
        160: '2019-08-08',
        161: '2019-08-09',
        162: '2019-08-10',
        163: '2019-08-11',
        164: '2019-08-12',
        165: '2019-08-13',
        166: '2019-08-14',
        167: '2019-08-15',
        168: '2019-08-16',
        169: '2019-08-17',
        170: '2019-08-18',
        171: '2019-08-19',
        172: '2019-08-20',
        173: '2019-08-21',
        174: '2019-08-22',
        175: '2019-08-23',
        176: '2019-08-24',
        177: '2019-08-25',
        178: '2019-08-26',
        179: '2019-08-27',
        180: '2019-08-28',
        181: '2019-08-29',
        182: '2019-08-30',
        183: '2019-08-31',
        184: '2019-09-01',
        185: '2019-09-02',
        186: '2019-09-03',
        187: '2019-09-04',
        188: '2019-09-05',
        189: '2019-09-06',
        190: '2019-09-07',
        191: '2019-09-08',
        192: '2019-09-09',
        193: '2019-09-10',
        194: '2019-09-11',
        195: '2019-09-12',
        196: '2019-09-13',
        197: '2019-09-14',
        198: '2019-09-15',
        199: '2019-09-16',
        200: '2019-09-17',
        201: '2019-09-18',
        202: '2019-09-19',
        203: '2019-09-20',
        204: '2019-09-21',
        205: '2019-09-22',
        206: '2019-09-23',
        207: '2019-09-24',
        208: '2019-09-25',
        209: '2019-09-26',
        210: '2019-09-27',
        211: '2019-09-28',
        212: '2019-09-29',
        213: '2019-09-30',
        214: '2019-10-01',
        215: '2019-10-02',
        216: '2019-10-03',
        217: '2019-10-04',
        218: '2019-10-05',
        219: '2019-10-06',
        220: '2019-10-07',
        221: '2019-10-08',
        222: '2019-10-09',
        223: '2019-10-10',
        224: '2019-10-11',
        225: '2019-10-12',
        226: '2019-10-13',
        227: '2019-10-14',
        228: '2019-10-15',
        229: '2019-10-16',
        230: '2019-10-17',
        231: '2019-10-18',
        232: '2019-10-19',
        233: '2019-10-20',
        234: '2019-10-21',
        235: '2019-10-22',
        236: '2019-10-23',
        237: '2019-10-24',
        238: '2019-10-25',
        239: '2019-10-26',
        240: '2019-10-27',
        241: '2019-10-28',
        242: '2019-10-29',
        243: '2019-10-30',
        244: '2019-10-31'
    }

    out_record = {
        1: ["Id", None],
        2: ["FID_1", None],
        3: ["LCGROUP", None],
        4: ["LCTYPE", None],
        5: ["AREA", None]
    }

    lut = {"Id": 1, "FID_1": 2, "LCGROUP": 3, "LCTYPE": 4, "AREA": 5}

    idx = 6
    for b in ("VV", "VH"):
        for i in range(1, len(processed_scenes_dates)+1):
            for stat in ("mean", "range", "variance"):
                fld_name = "{}_{}_{}".format(processed_scenes_dates[i], b, stat)
                out_record[idx] = [fld_name, None]
                lut[fld_name] = idx
                idx += 1

    return out_record, lut


def concat_and_validate(path_to_zs_csvs, path_to_src_shps, zs_csv_ptn, output_csv_fn):
    """
    concatenate _zonal_stats_for_ml.csv files produced for each partition into a
    single csv file and do validation of the individual csv`s to check expected
    number of records against input zones etc.
    The concatenation is complicated by the fact that the number of columns
    present in each partition can vary depending on the number of images/dates that
    were present for that particular set of zones
    :param path_to_zs_csvs: the path to the folder of csv`s that mp_py_zonal_stats.py produced
    :param path_to_src_shps: the path to the folder of shapefiles that contain the partitioned zones
    :param zs_csv_ptn: a pattern used to identify the indv csvs files i.e. "*_for_ml.csv"
    :param output_csv_fn: the name of the new single csv file that indv files are concatenated into
    :return:
    """

    ml_csv_expected_count = 0
    ml_csv_actual_count = 0
    missing_or_empty = {"missing": [], "empty": [], "difft_counts": []}
    shp_counts = {}
    print("\nDoing validation - issues will be reported below")

    for fn in glob.glob(os.path.join(path_to_src_shps, "*.shp")):
        p_id = (os.path.splitext(os.path.split(fn)[-1])[0]).split("_")[-1]
        with fiona.open(fn) as shp_src:
            num_features = len(shp_src)
            shp_counts[p_id] = num_features

        expected_csv = os.path.join(path_to_zs_csvs, "tile_name_{}_zonal_stats_for_ml.csv".format(p_id))
        if os.path.exists(expected_csv):
            ml_csv_actual_count += 1
        else:
            missing_or_empty["missing"].append(expected_csv)

        ml_csv_expected_count += 1

    p_number = 1
    to_concat = []

    for fn in glob.glob(os.path.join(path_to_zs_csvs, zs_csv_ptn)):
        p_id = ((os.path.splitext(os.path.split(fn)[-1])[0]).replace("_zonal_stats_for_ml", "")).split("_")[-1]
        num_columns = -999
        row_count = 0
        with open(fn, "r") as inpf:
            my_reader = csv.DictReader(inpf)
            num_columns = len(my_reader.fieldnames)
            for r in my_reader:
                row_count += 1

            if row_count == 0:
                missing_or_empty["empty"].append(fn)
            else:
                to_concat.append(fn)

        num_of_zones_in_shp = None
        if p_id in shp_counts:
            num_of_zones_in_shp = shp_counts[p_id]

        # print("PartitionNumber: {} {} has {} records, {} columns".format(
        #    p_number, fn, row_count, num_columns
        # ))

        if num_of_zones_in_shp is None:
            print("Warning! - number of expected rows not available")
        else:
            if row_count != 0:
                if row_count != num_of_zones_in_shp:
                    missing_or_empty["difft_counts"].append(
                        {"fn": fn, "shp_f_count": num_of_zones_in_shp, "csv_r_count": row_count}
                    )
        p_number += 1

    print("\nThere are {} of {} expected CSVs".format(ml_csv_actual_count, ml_csv_expected_count))

    if len(missing_or_empty["missing"]) > 0:
        print("\nThe following CSVs are missing:")
        for i in missing_or_empty["missing"]:
            print(i)

    if len(missing_or_empty["empty"]) > 0:
        print("\nThe following csv`s contain no records:")
        for i in missing_or_empty["empty"]:
            print(i)

    if len(missing_or_empty["difft_counts"]) > 0:
        print("\nThe following csv`s contain difft number of records from those in shape src:")
        for i in missing_or_empty["difft_counts"]:
            msg_str = "{} features in shp: {}, records in csv: {}".format(
                i["fn"], i["shp_f_count"], i["csv_r_count"]
            )
            print(msg_str)

    print("\nConcatenating individual CSVs into a single CSV...")

    out_record, lut = form_empty_out_record()
    header = []
    upper_col_idx = len(out_record) + 1

    for i in range(1, upper_col_idx):
        header.append(out_record[i][0])

    with open(output_csv_fn, "w", newline='') as outpf:
        my_writer = csv.writer(outpf, delimiter=",", quotechar='"', quoting=csv.QUOTE_NONNUMERIC)

        my_writer.writerow(header)

        for fn in glob.glob(os.path.join(path_to_zs_csvs, zs_csv_ptn)):
            if (fn not in missing_or_empty["missing"]) and (fn not in missing_or_empty["empty"]):
                with open(fn, "r") as inpf:
                    my_reader = csv.DictReader(inpf)
                    fields_in_this_csv = []

                    for f in my_reader.fieldnames:
                        k = lut[f]
                        fields_in_this_csv.append((k, f))

                    for r in my_reader:
                        out_record, lut = form_empty_out_record()

                        for ff in fields_in_this_csv:
                            field_id = ff[0]

                            field_name = ff[1]
                            out_record[field_id][1] = r[field_name]

                        out_record_to_write = []
                        for i in range(1, upper_col_idx):
                            # TODO - write the data to the final concat csv as non-strings
                            # if i == 1:
                            #     out_record_to_write.append(int(out_record[i][1]))
                            # if (i > 1) and (i < 5):
                            #     out_record_to_write.append(out_record[i][1])
                            # else:
                            #     out_record_to_write.append(float(out_record[i][1]))

                            out_record_to_write.append(out_record[i][1])
                        my_writer.writerow(out_record_to_write)


def main():
    path_to_zs_csvs = "/home/james/geocrud/mpzs/for_ml"
    path_to_src_shps = "/home/james/geocrud/partitions"
    zs_csv_ptn = "*_for_ml.csv"
    output_csv_fn = "/home/james/Desktop/scotland_unlabelled_data_for_ml.csv"
    concat_and_validate(path_to_zs_csvs, path_to_src_shps, zs_csv_ptn, output_csv_fn)


if __name__ == "__main__":
    main()
