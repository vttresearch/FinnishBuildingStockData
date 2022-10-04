#=
    process_datastore.jl

Contains the main program for Spine Toolbox,
processing raw building stock data into input for the archetype building stock model.
=#

using Pkg
Pkg.activate(@__DIR__)
using FinnishBuildingStockData
m = FinnishBuildingStockData

# Check that necessary input arguments are provided
if length(ARGS) < 2
    @error """
    `process_datastore.jl` requires at least the following input arguments:
    1. A database url for the raw input datastore.
    2. A database url for the output datastore.

    Furthermore, the following optional keyword arguments can be provided:
    3. scramble=false, to scramble the data in the resulting datastore (e.g. for confidentiality reasons)
    4. num_lids=Inf, number of `location_id` objects included in the resulting datastore (e.g. for testing)
    5. thermal_conductivity_weight=0.5, how thermal conductivity of the materials is sampled. Average by default.
    6. interior_node_depth=0.1, how deep the interior thermal node is positioned within the structure. Based on the calibrations performed in https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model
    7. variation_period=2225140, "period of variations" as defined in EN ISO 13786:2017 Annex C. Based on the calibrations performed in https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model
    """
else
    # Process command line arguments
    url_in = popfirst!(ARGS)
    url_out = popfirst!(ARGS)
    kws = Dict(key => value for (key, value) in split.(ARGS, '='))
    scramble_data = parse(Bool, get(kws, "scramble", "false"))
    num_lids = parse(Float64, get(kws, "num_lids", "Inf"))
    tcw = parse(Float64, get(kws, "thermal_conductivity_weight", "0.5"))
    ind = parse(Float64, get(kws, "interior_node_depth", "0.1"))
    vp = parse(Float64, get(kws, "variation_period", "2225140"))

    # Open input datastore and run tests.
    @info "Opening input datastore at `$(url_in)`..."
    @time using_spinedb(url_in, m)
    @info "Running structural input data tests..."
    @time run_structural_tests(; limit = Inf, mod = m)
    @info "Running statistical input data tests..."
    @time run_statistical_tests(; limit = Inf, mod = m)

    # Process stuff
    create_processed_statistics!(m, num_lids, tcw, ind, vp)

    # Import processed data into the datastore at `url_out`
    import_processed_data(url_out; scramble_data = scramble_data)
    @info "Done"
end
