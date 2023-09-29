#=
    testscript.jl

A testing script for direct raw data input and processing.
=#

## Necessary packages and definitions

using FinnishBuildingStockData
import FinnishBuildingStockData as fbsd
using JSON
using CSV
using DataFrames

# Define paths to the datasets to be processed
statistical_path = "data/finnish_building_stock_forecasts/"
RT_structural_path = "data/finnish_RT_structural_data/"
def_structural_path = "data/Finnish-building-stock-default-structural-data/"


## Test reading data into dataframes

stat_data = fbsd.read_datapackage(statistical_path)
RT_data = fbsd.read_datapackage(RT_structural_path)
def_structural_path = fbsd.read_datapackage(def_structural_path)


## Test initializing a `RawBuildingStockData` container

rbsd = fbsd.RawBuildingStockData()


## Test importing stuff into the raw data container

@time fbsd.import_building_period!(rbsd, stat_data)
@time fbsd.import_building_stock!(rbsd, stat_data)
@time fbsd.import_building_type!(rbsd, stat_data)
@time fbsd.import_frame_material!(rbsd, stat_data)