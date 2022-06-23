#=
    FinnishBuildingStockData.jl

The main module file.
=#

module FinnishBuildingStockData

using SpineInterface
using Interpolations
using Test
using Random

include("util.jl")
include("materials.jl")
include("structural.jl")
include("structural_tests.jl")
include("statistical.jl")
include("statistical_tests.jl")
include("ventilation_and_fenestration.jl")
include("main.jl")

# Exports required for main program
export using_spinedb,
    filter_entity_class!,
    run_structural_tests,
    run_statistical_tests,
    create_processed_statistics,
    import_processed_data
# Exports required for testscript
export add_building_stock_year!,
    create_building_stock_statistics!,
    create_structure_statistics,
    create_ventilation_and_fenestration_statistics,
    scramble_parameter_data!,
    import_data

end # module
