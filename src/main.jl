#=
    main.jl

Contains functions for the `process_datastore.jl` main program file.
=#

"""
    create_processed_statistics!(
        mod::Module,
        num_lids::Float64,
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64,
    )

Create processed statistics in `mod` based on the contents of the input datastore.

The arguments are used to tweak details regarding the processing:
- `num_lids`: Number of `location_id` objects included in the resulting datastore (e.g. for testing).
- `thermal_conductivity_weight`: How thermal conductivity of the materials is sampled.
- `interior_node_depth`: How deep the interior thermal node is positioned within the structure.
- `variation_period`: "Period of variations" as defined in EN ISO 13786:2017 Annex C.

Essentially performs the following steps:
1. Limit `location_id`s based on the given `num_lids`.
2. Call [`add_building_stock_year!`](@ref) to parse years from `building_stock` names.
3. Call [`create_building_stock_statistics!`](@ref) to create processed building stock statistics.
4. Call [`create_structure_statistics!`](@ref) to create processed structural statistics.
5. Call [`create_ventilation_and_fenestration_statistics!`](@ref) to create processed ventilation and fenestration statistics.
"""
function create_processed_statistics!(
    mod::Module,
    num_lids::Float64,
    thermal_conductivity_weight::Float64,
    interior_node_depth::Float64,
    variation_period::Float64,
)
    # Determine and filter the included `location_id`s.
    num_lids = Int64(min(length(mod.location_id()), num_lids))
    lids = mod.location_id()[1:num_lids]
    @info "Including `location_id`s up to `$(num_lids)`..."
    @time filter_entity_class!(mod.location_id; location_id=lids)

    # Process data
    @info "Add `building_stock_year` parameter..."
    @time add_building_stock_year!(mod)
    @info "Creating final building stock statistics..."
    @time create_building_stock_statistics!(mod; location_id=lids)
    @info """
    Creating structural statistics in module `$(mod)` using the following parameters:
    - `thermal_conductivity_weight` = $(thermal_conductivity_weight)
    - `interior_node_depth` = $(interior_node_depth)
    - `variation_period` = $(variation_period) seconds
    """
    @time create_structure_statistics!(
        mod;
        location_id=lids,
        thermal_conductivity_weight=thermal_conductivity_weight,
        interior_node_depth=interior_node_depth,
        variation_period=variation_period
    )
    @info "Creating ventilation and fenestration statistics..."
    @time create_ventilation_and_fenestration_statistics!(mod; location_id=lids)
end


"""
    import_processed_data(
        url_out::String;
        scramble_data = false,
        mod::Module = @__MODULE__,
        fields::Vector{Symbol}=[
            :building_period,
            :building_stock,
            :building_type,
            :heat_source,
            :location_id,
            :structure_type,
            :building_stock_statistics,
            :structure_statistics,
            :ventilation_and_fenestration_statistics
        ]
    )

Imports the processed data from module `mod` into the datastore at `url_out`.

The `mod` keyword can be used to tweak which Module the data is accessed from.
The `scramble_data` keyword can be used to scramble the database if needed.
The `fields` keyword can be used to control which object and relationship
classes are imported into the desired url.
"""
function import_processed_data(
    url_out::String;
    scramble_data=false,
    mod::Module=@__MODULE__,
    fields::Vector{Symbol}=[
        :building_period,
        :building_stock,
        :building_type,
        :heat_source,
        :location_id,
        :structure_type,
        :building_stock_statistics,
        :structure_statistics,
        :ventilation_and_fenestration_statistics
    ]
)
    @info "Importing processed data into output datastore at `$(url_out)`..."
    data = [getfield(mod, f) for f in fields]
    if scramble_data
        for d in data
            @info "Scrambling `$(d)`..."
            @time scramble_parameter_data!(d)
        end
    end
    @time import_data(url_out, data, "Import processed FinnishBuildingStockData.")
end


"""
    data_from_package(filepaths::String...)

Read and form [`FinnishBuildingStockData.RawSpineData`](@ref) from Data Packages at `filepaths`.
"""
function data_from_package(filepaths::String...)
    @info "Importing Data Packages..."
    @time begin
        rsd = RawSpineData()
        dps = read_datapackage.(filepaths)
    end
    for dp in dps
        @time import_datapackage!(rsd, dp)
    end
    @info "Removing duplicate entries..."
    @time begin
        for fn in fieldnames(RawSpineData)
            unique!(getfield(rsd, fn))
        end
    end
    return rsd
end


"""
    data_from_url(urls::String...; upgrade=false, filters=Dict())

Read and form [`FinnishBuildingStockData.RawSpineData`](@ref) from Spine Datastores at `urls`.
"""
function data_from_url(urls::String...; upgrade=false, filters=Dict())
    @info "Importing from URLs..."
    rsd = RawSpineData()
    for url in urls
        raw = SpineInterface._db(url; upgrade=upgrade) do db
            SpineInterface._export_data(db; filters=filters)
        end
        merge_data!(rsd, RawSpineData(raw))
    end
    return rsd
end


"""
    serialize_processed_data

Serialize processed data as a `RawSpineData` to speed up processing.
"""
function serialize_processed_data(
    m::Module,
    hsh::UInt64;
    filepath::String=string("data\\", hsh, ".ser"),
    processed_data_fields=[
        (:_spine_object_classes, :building_period),
        (:_spine_object_classes, :building_stock),
        (:_spine_object_classes, :building_type),
        (:_spine_object_classes, :heat_source),
        (:_spine_object_classes, :location_id),
        (:_spine_object_classes, :structure_type),
        (:_spine_relationship_classes, :building_stock_statistics),
        (:_spine_relationship_classes, :structure_statistics),
        (:_spine_relationship_classes, :ventilation_and_fenestration_statistics)
    ]
)
    rsd = RawSpineData()
    merge_data!(
        rsd,
        [
            RawSpineData(to_dict(getfield(m, f)[k]))
            for (f, k) in processed_data_fields
        ]...
    )
    return serialize(filepath, rsd)
end