#=
    raw_data.jl

This file contains functions for reading the raw building stock
data directly from the Data Packages without the need to
swing it through Spine Datastores. Unfortunately, Spine Datastores
become prohibitively slow to read and write to at full-Finland-scales.
=#

"""
    RawBuildingStockData

A `struct` for holding the raw Spine Datastore contents.
"""
struct RawBuildingStockData
    building_period::ObjectClass
    building_stock::ObjectClass
    building_type::ObjectClass
    frame_material::ObjectClass
    heat_source::ObjectClass
    layer_id::ObjectClass
    location_id::ObjectClass
    source::ObjectClass
    structure::ObjectClass
    structure_material::ObjectClass
    structure_type::ObjectClass
    ventilation_space_heat_flow_direction::ObjectClass
    building_stock__building_type__building_period__location_id__heat_source::RelationshipClass
    building_type__location_id__building_period::RelationshipClass
    building_type__location_id__frame_material::RelationshipClass
    fenestration_source__building_type::RelationshipClass
    source__structure::RelationshipClass
    source__structure__building_type::RelationshipClass
    source__structure__layer_id__structure_material::RelationshipClass
    structure__structure_type::RelationshipClass
    structure_material__frame_material::RelationshipClass
    structure_type__ventilation_space_heat_flow_direction::RelationshipClass
    ventilation_source__building_type::RelationshipClass
    function RawBuildingStockData()
        # Define the last fieldnames index with an ObjectClass
        last_oc_ind = 12
        # Initialize the Datastore structure.
        new(
            [
                ObjectClass(oc, Array{ObjectLike,1}())
                for oc in collect(fieldnames(RawBuildingStockData)[1:last_oc_ind])
            ]...,
            [
                RelationshipClass(rc, Symbol.(split(string(rc), "__")), Array{RelationshipLike,1}())
                for rc in collect(fieldnames(RawBuildingStockData)[last_oc_ind+1:end])
            ]...
        )
    end
end


"""
    read_datapackage(datpack_path::String)

Read the resources of a Data Package into a dictionary of DataFrames.
"""
function read_datapackage(datpack_path::String)
    # Read `datapackage.json` and extract resource filepaths and filenames.
    dp = JSON.parsefile(datpack_path * "datapackage.json")
    files = get.(dp["resources"], "path", nothing)
    names = first.(split.(getindex.(split.(files, '\\'), 2), '.'))
    # Return a dictionary mapping filename to its path.
    return Dict(
        string(name) => DataFrame(CSV.File(datpack_path * file))
        for (name, file) in zip(names, files)
    )
end

#=
"""
    import_statistical_datapackage!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )

Imports a statistical datapackage into a `RawBuildingStockData` struct.
"""
function import_statistical_datapackage!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    # We'll first have to import the object classes to ensure consistency.
    import_building_period!(rbsd, dp)
    import_building_stock!(rbsd, dp)
    import_building_type!(rbsd, dp)
    import_frame_material!(rbsd, dp)
    import_heat_source!(rbsd, dp)
    import_location_id!(rbsd, dp)
    # Next, we can import the actual more complicated data.
end
=#


"""
    import_building_period!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the `building_period` object class from `dp`.
"""
function import_building_period!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["building_periods"],
        :building_period,
        [:period_start, :period_end]
    )
end


"""
    import_building_stock!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `building_stock` ObjectClass from `dp`.
"""
function import_building_stock!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["numbers_of_buildings"],
        :building_stock
    )
end


"""
    import_building_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `building_type` ObjectClass from `dp`.
"""
function import_building_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["average_floor_areas_m2"],
        :building_type
    )
end


"""
    import_frame_material!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `frame_material` ObjectClass from `dp`.
"""
function import_frame_material!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["frame_material_shares"],
        :frame_material,
        4:8,
    )
end


"""
    import_heat_source!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `heat_source` ObjectClass from `dp`.
"""
function import_heat_source!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["numbers_of_buildings"],
        :heat_source,
        6:15,
    )
end


"""
    import_location_id!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `location_id` ObjectClass from `dp`.
"""
function import_location_id!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["municipalities"],
        :location_id,
        [:location_name],
    )
end


"""
    _import_oc!(
        rbsd::RawBuildingStockData,
        df::DataFrame,
        oc::Symbol,
        stackrange::UnitRange{Int64},
        params::Vector{Symbol}
    )
Helper function for generic ObjectClass imports.

The `stackrange` can be used to manipulate
the DataFrame shape prior to extracting the object class,
while `params` is used to read parameter values if any.
Both can be omitted if not needed.
"""
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol,
    stackrange::UnitRange{Int64},
)
    # Reshape dataframe prior to extracting objects.
    df = rename(stack(df, stackrange), :variable => oc)
    # Fetch and add the relevant objects
    _import_oc!(rbsd, df, oc)
end
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol
)
    # Fetch and add the relevant objects
    objs = unique(df[!, oc])
    add_objects!(
        getfield(rbsd, oc),
        Object.(Symbol.(objs), oc)
    )
end
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol,
    params::Vector{Symbol}
)
    # Form parameter value Dict
    objcls = getfield(rbsd, oc)
    # Add objects with parameter values and defaults
    add_object_parameter_values!(
        objcls,
        Dict(
            Object(Symbol(r[oc]), oc) => Dict(
                param => parameter_value(r[param])
                for param in params
            )
            for r in eachrow(df)
        )
    )
    add_object_parameter_defaults!(
        objcls,
        Dict(param => parameter_value(nothing) for param in params)
    )
end