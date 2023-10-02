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
def_data = fbsd.read_datapackage(def_structural_path)


## Test initializing a `RawBuildingStockData` container

rbsd = fbsd.RawBuildingStockData()


## Test importing statistical data into the raw data container
@time fbsd.import_building_period!(rbsd, stat_data)
@time fbsd.import_building_stock!(rbsd, stat_data)
@time fbsd.import_building_type!(rbsd, stat_data)
@time fbsd.import_frame_material!(rbsd, stat_data)
@time fbsd.import_heat_source!(rbsd, stat_data)
@time fbsd.import_location_id!(rbsd, stat_data)
#=
@time fbsd.import_building_stock__building_type__building_period__location_id__heat_source!(rbsd, stat_data)
@time fbsd.import_building_type__location_id__building_period!(rbsd, stat_data)
@time fbsd.import_building_type__location_id__frame_material!(rbsd, stat_data)
=#
# Test importing the whole statistical data package at once
@time fbsd.import_statistical_datapackage!(rbsd, stat_data)


## Test importing structural data into the raw data container
#=
@time fbsd.import_layer_id!(rbsd, def_data)
@time fbsd.import_source!(rbsd, def_data)
@time fbsd.import_structure!(rbsd, def_data)
@time fbsd.import_structure_material!(rbsd, def_data)
@time fbsd.import_structure_type!(rbsd, def_data)
@time fbsd.import_ventilation_space_heat_flow_direction!(rbsd, def_data)
@time fbsd.import_source__structure!(rbsd, def_data)
@time fbsd.import_source__structure__building_type!(rbsd, def_data)
@time fbsd.import_source__structure__layer_id__structure_material!(rbsd, def_data)
@time fbsd.import_structure__structure_type!(rbsd, def_data)
@time fbsd.import_structure_material__frame_material!(rbsd, def_data)
@time fbsd.import_structure_type__ventilation_space_heat_flow_direction!(rbsd, def_data)
@time fbsd.import_fenestration_source__building_type!(rbsd, def_data)
@time fbsd.import_ventilation_source__building_type!(rbsd, def_data)
=#
# Test importing the whole structural data package at once
@time fbsd.import_structural_datapackage!(rbsd, def_data)