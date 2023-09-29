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
    import_building_stock__building_type__building_period__location_id__heat_source!(rbsd, dp)
    import_building_type__location_id__building_period!(rbsd, dp)
    import_building_type__location_id__frame_material!(rbsd, dp)
end


"""
    import_structural_datapackage!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )

Imports a structural datapackage into a `RawBuildingStockData` struct.
"""
function import_structural_datapackage!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    # We'll first have to import the object classes to ensure consistency.
    import_layer_id!(rbsd, dp)
    import_source!(rbsd, dp)
    import_structure!(rbsd, dp)
    import_structure_material!(rbsd, dp)
    import_structure_type!(rbsd, dp)
    import_ventilation_space_heat_flow_direction!(rbsd, dp)
    # Next, we can import the actual more complicated data.
    import_fenestration_source__building_type(rbsd, dp)
    import_source__structure(rbsd, dp)
    import_source__structure__building_type(rbsd, dp)
    import_source__structure__layer_id__structure_material(rbsd, dp)
    import_structure__structure_type(rbsd, dp)
    import_structure_material__frame_material(rbsd, dp)
    import_structure_type__ventilation_space_heat_flow_direction(rbsd, dp)
    import_ventilation_source__building_type(rbsd, dp)
end


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
    import_layer_id!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `layer_id` ObjectClass from `dp`.
"""
function import_layer_id!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["structure_layers"],
        :layer_id,
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
    args...
)
    # Reshape dataframe prior to extracting objects.
    df = rename(stack(df, stackrange), :variable => oc)
    # Fetch and add the relevant objects
    _import_oc!(rbsd, df, oc, args...)
end
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol
)
    # Fetch and add the relevant objects
    objs = unique(df[!, oc])
    objcls = getfield(rbsd, oc)
    add_objects!(
        objcls,
        _get(objcls, Symbol.(objs))
    )
end
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol,
    params::Vector{Symbol}
)
    # Fetch the desired object class.
    objcls = getfield(rbsd, oc)
    # Add objects with parameter values and defaults
    add_object_parameter_values!(
        objcls,
        Dict(
            _get(objcls, Symbol(r[oc])) => Dict(
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


"""
    import_building_stock__building_type__building_period__location_id__heat_source!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_stock__building_type__building_period__location_id__heat_source!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["numbers_of_buildings"],
        :building_stock__building_type__building_period__location_id__heat_source,
        :heat_source,
        6:15,
        :number_of_buildings,
        [:location_name],
        [:number_of_buildings],
    )
end


"""
    import_building_type__location_id__building_period!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_type__location_id__building_period!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["average_floor_areas_m2"],
        :building_type__location_id__building_period,
        :building_period,
        4:15,
        :average_floor_area_m2,
        [:location_name],
        [:average_floor_area_m2],
    )
end


"""
    import_building_type__location_id__frame_material!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_type__location_id__frame_material!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["frame_material_shares"],
        :building_type__location_id__frame_material,
        :frame_material,
        4:8,
        :share,
        [:location_name],
        [:share],
    )
end


"""
    _import_rc!(
        rbsd::RawBuildingStockData,
        df::DataFrame,
        rc::Symbol,
        stackname::Symbol,
        stackrange::UnitRange{Int64},
        rename_value::Symbol,
        drops::Vector{Symbol},
        params::Vector{Symbol}
    )
Helper function for generic RelationshipClass imports.

`stackname`, `stackrange`, `rename_value`, and `drops` can be used to manipulate
the DataFrame shape prior to extracting the relationship class,
while `params` is used to read parameter values if any.
These can be omitted if not needed.
"""
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol,
    stackname::Symbol,
    stackrange::UnitRange{Int64},
    rename_value::Symbol,
    drops::Vector{Symbol},
    params::Vector{Symbol}
)
    # Reshape dataframe prior to extracting relationships.
    df = rename(stack(df, stackrange), [:variable => stackname, :value => rename_value])
    # Fetch and add the relevant relationships
    _import_rc!(rbsd, df, rc, drops, params)
end
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol,
    drops::Vector{Symbol},
    params::Vector{Symbol}
)
    # Drop desired column prior to extracting relationships.
    df = select(df, Not(drops))
    _import_rc!(rbsd, df, rc, params)
end
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol,
    params::Vector{Symbol}
)
    # Fetch the desired relationshipclass
    relcls = getfield(rbsd, rc)
    # Add relationships with parameter values and defaults
    add_relationship_parameter_values!(
        relcls,
        Dict(
            Tuple(
                getfield(rbsd, oc)(Symbol(r[oc]))
                for oc in relcls.intact_object_class_names
            ) => Dict(
                param => parameter_value(r[param])
                for param in params
            )
            for r in eachrow(df)
        )
    )
    add_relationship_parameter_defaults!(
        relcls,
        Dict(param => parameter_value(nothing) for param in params)
    )
end