#=
    FinnishBuildingStockData.jl

The main module file.
=#

module FinnishBuildingStockData

using SpineInterface
using Interpolations
using Test
using Random
using JSON
using CSV
using DataFrames

include("raw_data.jl")
include("util.jl")
include("materials.jl")
include("structural.jl")
include("structural_tests.jl")
include("statistical.jl")
include("statistical_tests.jl")
include("ventilation_and_fenestration.jl")
include("main.jl")

# Exports required for main program
export create_processed_statistics!,
    import_processed_data,
    run_structural_tests,
    run_statistical_tests,
    using_spinedb
# Exports required for testscripts
export add_building_stock_year!,
    calculate_structure_properties,
    create_building_stock_statistics!,
    create_structure_statistics!,
    create_ventilation_and_fenestration_statistics!,
    data_from_package,
    data_from_url,
    filter_entity_class!,
    filter_module!,
    layers_with_properties,
    import_data,
    scramble_parameter_data!,
    merge_spine_modules!
end # module
