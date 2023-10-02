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
    object_classes::Vector
    relationship_classes::Vector
    objects::Vector
    relationships::Vector
    object_parameters::Vector
    relationship_parameters::Vector
    object_parameter_values::Vector
    relationship_parameter_values::Vector
    function RawBuildingStockData()
        new([Vector{Any}() for fn in fieldnames(RawBuildingStockData)]...)
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
    import_source__structure!(rbsd, dp)
    import_source__structure__building_type!(rbsd, dp)
    import_source__structure__layer_id__structure_material!(rbsd, dp)
    import_structure__structure_type!(rbsd, dp)
    import_structure_material__frame_material!(rbsd, dp)
    import_structure_type__ventilation_space_heat_flow_direction!(rbsd, dp)
    import_fenestration_source__building_type!(rbsd, dp)
    import_ventilation_source__building_type!(rbsd, dp)
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
    import_source!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `source` ObjectClass from `dp`.
"""
function import_source!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["sources"],
        :source,
        [:source_year, :source_description],
    )
end


"""
    import_structure!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `structure` ObjectClass from `dp`.
"""
function import_structure!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["structure_descriptions"],
        :structure,
    )
end


"""
    import_structure_material!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `structure_material` ObjectClass from `dp`.
"""
function import_structure_material!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["materials"],
        :structure_material,
        [
            :minimum_density_kg_m3,
            :maximum_density_kg_m3,
            :minimum_specific_heat_capacity_J_kgK,
            :maximum_specific_heat_capacity_J_kgK,
            :minimum_thermal_conductivity_W_mK,
            :maximum_thermal_conductivity_W_mK,
            :material_notes
        ]
    )
end


"""
    import_structure_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `structure_type` ObjectClass from `dp`.
"""
function import_structure_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["types"],
        :structure_type,
        [
            :interior_resistance_m2K_W,
            :exterior_resistance_m2K_W,
            :linear_thermal_bridge_W_mK,
            :is_internal,
            :structure_type_notes
        ]
    )
end


"""
    import_ventilation_space_heat_flow_direction!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import `ventilation_space_heat_flow_direction` ObjectClass from `dp`.
"""
function import_ventilation_space_heat_flow_direction!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rbsd,
        dp["types"],
        :ventilation_space_heat_flow_direction
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
    push!(rbsd.object_classes, string(oc))
    append!(rbsd.objects, unique(df[!, oc]))
end
function _import_oc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    oc::Symbol,
    params::Vector{Symbol}
)
    # Import the object class and objects
    _import_oc!(rbsd, df, oc)
    # Import the desired parameter defaults.
    append!(
        rbsd.object_parameters,
        [
            [string(oc), string(param), nothing]
            for param in params
        ]
    )
    # Import the parameter values.
    append!(
        rbsd.object_parameter_values,
        [
            [string(oc), r[oc], string(param), r[param]]
            for r in eachrow(df)
            for param in params
        ]
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
        [:share],
    )
end


"""
    import_source__structure!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["structure_descriptions"],
        :source__structure,
        [
            :design_U_W_m2K,
            :structure_description,
            :structure_notes
        ]
    )
end


"""
    import_source__structure__building_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure__building_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["structure_descriptions"],
        :source__structure__building_type,
        :building_type,
        5:10,
        :building_type_weight,
        [:building_type_weight]
    )
end


"""
    import_source__structure__layer_id__structure_material!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure__layer_id__structure_material!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["structure_layers"],
        :source__structure__layer_id__structure_material,
        [
            :layer_weight,
            :layer_number,
            :layer_minimum_thickness_mm,
            :layer_load_bearing_thickness_mm,
            :layer_tag,
            :layer_notes
        ]
    )
end


"""
    import_structure__structure_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure__structure_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["structure_layers"],
        :structure__structure_type
    )
end


"""
    import_structure_material__frame_material!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure_material__frame_material!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["materials"],
        :structure_material__frame_material
    )
end


"""
    import_structure_type__ventilation_space_heat_flow_direction!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure_type__ventilation_space_heat_flow_direction!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["types"],
        :structure_type__ventilation_space_heat_flow_direction
    )
end


"""
    import_fenestration_source__building_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_fenestration_source__building_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["fenestration"],
        :fenestration_source__building_type,
        [
            :U_value_W_m2K,
            :solar_energy_transmittance,
            :frame_area_fraction,
            :notes
        ];
        object_classes=[:source, :building_type]
    )
end


"""
    import_ventilation_source__building_type!(
        rbsd::RawBuildingStockData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_ventilation_source__building_type!(
    rbsd::RawBuildingStockData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rbsd,
        dp["ventilation"],
        :ventilation_source__building_type,
        [
            :min_ventilation_rate_1_h,
            :max_ventilation_rate_1_h,
            :min_n50_infiltration_rate_1_h,
            :max_n50_infiltration_rate_1_h,
            :min_infiltration_factor,
            :max_infiltration_factor,
            :min_HRU_efficiency,
            :max_HRU_efficiency,
            :notes
        ];
        object_classes=[:source, :building_type]
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
        params::Vector{Symbol};
        object_classes::Vector{Symbol}=Symbol.(split(string(rc), "__"))
    )
Helper function for generic RelationshipClass imports.

`stackname`, `stackrange`, and `rename_value` can be used to manipulate
the DataFrame shape prior to extracting the relationship class,
while `params` is used to read parameter values if any.
`object_classes` can be used to set RelationshipClass dimensions manually.
These can be omitted if not needed.
"""
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol,
    stackname::Symbol,
    stackrange::UnitRange{Int64},
    rename_value::Symbol,
    params::Vector{Symbol};
    object_classes::Vector{Symbol}=Symbol.(split(string(rc), "__"))
)
    # Reshape dataframe prior to extracting relationships.
    df = rename(stack(df, stackrange), [:variable => stackname, :value => rename_value])
    # Fetch and add the relevant relationships
    _import_rc!(rbsd, df, rc, params; object_classes=object_classes)
end
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol,
    params::Vector{Symbol};
    object_classes::Vector{Symbol}=Symbol.(split(string(rc), "__"))
)
    # Import the relationship class in question.
    _import_rc!(rbsd, df, rc; object_classes=object_classes)
    # Import relationship parameter defaults.
    append!(
        rbsd.relationship_parameters,
        [string(rc), string(param), nothing]
        for param in params
    )
    # Import relationship parameter values.
    append!(
        rbsd.relationship_parameter_values,
        [string(rc), [r[oc] for oc in object_classes], string(param), r[param]]
        for r in eachrow(df)
        for param in params
    )
end
function _import_rc!(
    rbsd::RawBuildingStockData,
    df::DataFrame,
    rc::Symbol;
    object_classes::Vector{Symbol}=Symbol.(split(string(rc), "__"))
)
    # Add relationships
    push!(rbsd.relationship_classes, string(rc))
    append!(
        rbsd.relationships,
        unique(
            [string(rc), [r[oc] for oc in object_classes]]
            for r in eachrow(df)
        )
    )
end