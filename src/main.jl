#=
    main.jl

Contains functions for the `process_datastore.jl` main program file.
=#

"""
    create_processed_statistics(
        num_lids::Float64,
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64;
        mod::Module = Main
    )

Create processed statistics based on the contents of the input datastore.

The arguments are used to tweak details regarding the processing:
- `num_lids`: Number of `location_id` objects included in the resulting datastore (e.g. for testing).
- `thermal_conductivity_weight`: How thermal conductivity of the materials is sampled.
- `interior_node_depth`: How deep the interior thermal node is positioned within the structure.
- `variation_period`: "Period of variations" as defined in EN ISO 13786:2017 Annex C.
The `mod` keyword can be used to tweak the Module scope of the function.

Essentially performs the following steps:
1. Limit `location_id`s based on the given `num_lids`.
2. Call [`add_building_stock_year!`](@ref) to parse years from `building_stock` names.
3. Call [`create_building_stock_statistics`](@ref) to create processed building stock statistics.
4. Call [`create_structure_statistics`](@ref) to create processed structural statistics.
5. Call [`create_ventilation_and_fenestration_statistics`](@ref) to create processed ventilation and fenestration statistics.
6. Return the interesting `RelationshipClass`es and parameters.
"""
function create_processed_statistics(
    num_lids::Float64,
    thermal_conductivity_weight::Float64,
    interior_node_depth::Float64,
    variation_period::Float64;
    mod::Module = Main,
)
    # Determine and filter the included `location_id`s.
    num_lids = Int64(min(length(mod.location_id()), num_lids))
    lids = mod.location_id()[1:num_lids]
    @info "Including `location_id`s up to `$(num_lids)`..."
    @time filter_entity_class!(mod.location_id; location_id = lids)

    # Process data
    @info "Add `building_stock_year` parameter..."
    @time building_stock_year = add_building_stock_year!(; mod = mod)
    @info "Creating final building stock statistics..."
    @time building_stock_statistics =
        create_building_stock_statistics(; location_id = lids, mod = mod)
    @info """
    Creating structural statistics in module `$(mod)` using the following parameters:
    - `thermal_conductivity_weight` = $(thermal_conductivity_weight)
    - `interior_node_depth` = $(interior_node_depth)
    - `variation_period` = $(variation_period) seconds
    """
    @time structure_statistics = create_structure_statistics(;
        location_id = lids,
        thermal_conductivity_weight = thermal_conductivity_weight,
        interior_node_depth = interior_node_depth,
        variation_period = variation_period,
        mod = mod,
    )
    @info "Creating ventilation and fenestration statistics..."
    @time ventilation_and_fenestration_statistics =
        create_ventilation_and_fenestration_statistics(; location_id = lids, mod = mod)

    # Return stuff
    return building_stock_year,
    building_stock_statistics,
    structure_statistics,
    ventilation_and_fenestration_statistics
end


"""
    import_processed_data(url_out::String; scramble_data = false, mod::Module = Main)

Imports the processed data from module `mod` into the datastore at `url_out`.

The `mod` keyword can be used to tweak which Module the data is accessed from.
The `scramble_data` keyword can be used to scramble the database if needed.
"""
function import_processed_data(url_out::String; scramble_data = false, mod::Module = Main)
    @info "Importing processed data into output datastore at `$(url_out)`..."
    data = [
        mod.building_period,
        mod.building_stock,
        mod.building_type,
        mod.heat_source,
        mod.location_id,
        mod.structure_type,
        mod.building_stock_statistics,
        mod.structure_statistics,
        mod.ventilation_and_fenestration_statistics,
    ]
    if scramble_data
        for d in data
            @info "Scrambling `$(d)`..."
            @time scramble_parameter_data!(d)
        end
    end
    @time import_data(url_out, data, "Import processed FinnishBuildingStockData.")
end
