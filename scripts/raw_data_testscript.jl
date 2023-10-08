#=
    raw_data_testscript.jl

A testing script for direct raw data input and processing.
=#

## Necessary packages and definitions

using FinnishBuildingStockData
fbsd = FinnishBuildingStockData

# Define paths to the datasets to be processed
statistical_path = "data/finnish_building_stock_forecasts/"
RT_structural_path = "data/finnish_RT_structural_data/"
def_structural_path = "data/Finnish-building-stock-default-structural-data/"

# Define url for archetype building definitions
defs_url = "sqlite:///C:\\_SYMLINKS\\archetype_definitions.sqlite"

# Define parameter values and modules for processing.
m_data = Module()
m_defs = Module()
num_lids = 3.0 # Limit number of location ids to save time on test processing.
tcw = 0.5
ind = 0.1
vp = 2225140.0

## Test reading data into dataframes
#=
stat_data = fbsd.read_datapackage(statistical_path)
RT_data = fbsd.read_datapackage(RT_structural_path)
def_data = fbsd.read_datapackage(def_structural_path)
=#

## Test initializing a `RawSpineData` container
#=
rsd = fbsd.RawSpineData()


## Test importing statistical data into the raw data container
#=
@time fbsd.import_building_period!(rsd, stat_data)
@time fbsd.import_building_stock!(rsd, stat_data)
@time fbsd.import_building_type!(rsd, stat_data)
@time fbsd.import_frame_material!(rsd, stat_data)
@time fbsd.import_heat_source!(rsd, stat_data)
@time fbsd.import_location_id!(rsd, stat_data)
@time fbsd.import_building_stock__building_type__building_period__location_id__heat_source!(rsd, stat_data)
@time fbsd.import_building_type__location_id__building_period!(rsd, stat_data)
@time fbsd.import_building_type__location_id__frame_material!(rsd, stat_data)
=#
# Test importing the whole statistical data package at once
@info "Importing statistical data..."
@time fbsd.import_statistical_datapackage!(rsd, stat_data)


## Test importing structural data into the raw data container
#=
@time fbsd.import_layer_id!(rsd, def_data)
@time fbsd.import_source!(rsd, def_data)
@time fbsd.import_structure!(rsd, def_data)
@time fbsd.import_structure_material!(rsd, def_data)
@time fbsd.import_structure_type!(rsd, def_data)
@time fbsd.import_ventilation_space_heat_flow_direction!(rsd, def_data)
@time fbsd.import_source__structure!(rsd, def_data)
@time fbsd.import_source__structure__building_type!(rsd, def_data)
@time fbsd.import_source__structure__layer_id__structure_material!(rsd, def_data)
@time fbsd.import_structure__structure_type!(rsd, def_data)
@time fbsd.import_structure_material__frame_material!(rsd, def_data)
@time fbsd.import_structure_type__ventilation_space_heat_flow_direction!(rsd, def_data)
@time fbsd.import_fenestration_source__building_type!(rsd, def_data)
@time fbsd.import_ventilation_source__building_type!(rsd, def_data)
=#
# Test importing the whole structural data package at once
@info "Importing structural data..."
@time fbsd.import_structural_datapackage!(rsd, def_data)
@time fbsd.import_structural_datapackage!(rsd, RT_data)


## Test using_spinedb

@time "Generating convenience functions..."
@time using_spinedb(rsd, m)
=#

## Test importing data from Data Packages.

@time data = data_from_package(
    statistical_path,
    RT_structural_path,
    def_structural_path
)


## Test generating convenience functions for raw data

@info "Generating convenience functions..."
@time using_spinedb(data, m_data)


## Run input data tests to see if they pass

@info "Running structural input data tests..."
@time run_structural_tests(; limit=Inf, mod=m_data)
@info "Running statistical input data tests..."
@time run_statistical_tests(; limit=Inf, mod=m_data)


## Test importing definitions from URL

@info "Import definitions from URL..."
@time defs = using_spinedb(defs_url, m_defs)


## Test merging data and definitions

@info "Merge definitions and data..."
@time m_data_and_defs = fbsd.merge_spine_modules(m_data, m_defs)


## Test processing the data

@time create_processed_statistics!(m_data_and_defs, num_lids, tcw, ind, vp)


## Test importing processed data. NOTE! This can take a long while with large datasets.

@time import_processed_data("sqlite://"; mod=m_data_and_defs)


## Test post-process filtering

@info "Filtering module..."
@time filter_module!(
    m_data_and_defs;
    obj_classes=[
        :building_period,
        :building_stock,
        :building_type,
        :heat_source,
        :location_id,
        :structure_type
    ],
    rel_classes=[
        :building_stock_statistics,
        :structure_statistics,
        :ventilation_and_fenestration_statistics
    ]
)