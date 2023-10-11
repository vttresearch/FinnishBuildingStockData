#=
    raw_data.jl

This file contains functions for reading the raw building stock
data directly from the Data Packages without the need to
swing it through Spine Datastores. Unfortunately, Spine Datastores
become prohibitively slow to read and write to at full-Finland-scales.
=#

"""
    RawSpineData

A `struct` for holding the raw Spine Datastore contents.

Follows the raw JSON formatting of Spine Datastores, with the following fields:
- `object_classes::Vector`
- `object_classes::Vector`
- `objects::Vector`
- `object_parameters::Vector`
- `object_parameter_values::Vector`
- `relationship_classes::Vector`
- `relationships::Vector`
- `relationship_parameters::Vector`
- `relationship_parameter_values::Vector`
- `alternatives::Vector`
- `parameter_value_lists::Vector`
"""
struct RawSpineData
    object_classes::Vector
    objects::Vector
    object_parameters::Vector
    object_parameter_values::Vector
    relationship_classes::Vector
    relationships::Vector
    relationship_parameters::Vector
    relationship_parameter_values::Vector
    alternatives::Vector
    parameter_value_lists::Vector
    function RawSpineData()
        new([Vector{Any}() for fn in fieldnames(RawSpineData)]...)
    end
    function RawSpineData(d::Dict)
        new([d[String(fn)] for fn in fieldnames(RawSpineData)]...)
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
        String(name) => DataFrame(CSV.File(datpack_path * file))
        for (name, file) in zip(names, files)
    )
end


"""
    import_datapackage!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
"""
function import_datapackage!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    if length(dp) == 5
        import_statistical_datapackage!(rsd, dp)
    elseif length(dp) == 8
        import_structural_datapackage!(rsd, dp)
    else
        error("Datapackage length $(length(dp)) not recognized!")
    end
end


"""
    import_statistical_datapackage!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )

Imports a statistical datapackage into a [`FinnishBuildingStockData.RawSpineData`](@ref).
"""
function import_statistical_datapackage!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    # We'll first have to import the object classes to ensure consistency.
    import_building_period!(rsd, dp)
    import_building_stock!(rsd, dp)
    import_building_type!(rsd, dp)
    import_frame_material!(rsd, dp)
    import_heat_source!(rsd, dp)
    import_location_id!(rsd, dp)
    # Next, we can import the actual more complicated data.
    import_building_stock__building_type__building_period__location_id__heat_source!(rsd, dp)
    import_building_type__location_id__building_period!(rsd, dp)
    import_building_type__location_id__frame_material!(rsd, dp)
end


"""
    import_structural_datapackage!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )

Imports a structural datapackage into a [`FinnishBuildingStockData.RawSpineData`](@ref) struct.
"""
function import_structural_datapackage!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    # We'll first have to import the object classes to ensure consistency.
    import_layer_id!(rsd, dp)
    import_source!(rsd, dp)
    import_structure!(rsd, dp)
    import_structure_material!(rsd, dp)
    import_structure_type!(rsd, dp)
    import_ventilation_space_heat_flow_direction!(rsd, dp)
    # Next, we can import the actual more complicated data.
    import_source__structure!(rsd, dp)
    import_source__structure__building_type!(rsd, dp)
    import_source__structure__layer_id__structure_material!(rsd, dp)
    import_structure__structure_type!(rsd, dp)
    import_structure_material__frame_material!(rsd, dp)
    import_structure_type__ventilation_space_heat_flow_direction!(rsd, dp)
    import_fenestration_source__building_type!(rsd, dp)
    import_ventilation_source__building_type!(rsd, dp)
end


"""
    import_building_period!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the `building_period` object class from `dp`.
"""
function import_building_period!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["building_periods"],
        :building_period,
        [:period_start, :period_end]
    )
end


"""
    import_building_stock!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `building_stock` ObjectClass from `dp`.
"""
function import_building_stock!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["numbers_of_buildings"],
        :building_stock
    )
end


"""
    import_building_type!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `building_type` ObjectClass from `dp`.
"""
function import_building_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["average_floor_areas_m2"],
        :building_type
    )
end


"""
    import_frame_material!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `frame_material` ObjectClass from `dp`.
"""
function import_frame_material!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["frame_material_shares"],
        :frame_material,
        4:8,
    )
end


"""
    import_heat_source!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `heat_source` ObjectClass from `dp`.
"""
function import_heat_source!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["numbers_of_buildings"],
        :heat_source,
        6:15,
    )
end


"""
    import_layer_id!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `layer_id` ObjectClass from `dp`.
"""
function import_layer_id!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["structure_layers"],
        :layer_id,
    )
end


"""
    import_location_id!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `location_id` ObjectClass from `dp`.
"""
function import_location_id!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["municipalities"],
        :location_id,
        [:location_name],
    )
end


"""
    import_source!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `source` ObjectClass from `dp`.
"""
function import_source!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["sources"],
        :source,
        [:source_year, :source_description],
    )
end


"""
    import_structure!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `structure` ObjectClass from `dp`.
"""
function import_structure!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
        dp["structure_descriptions"],
        :structure,
    )
end


"""
    import_structure_material!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `structure_material` ObjectClass from `dp`.
"""
function import_structure_material!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `structure_type` ObjectClass from `dp`.
"""
function import_structure_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_oc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import `ventilation_space_heat_flow_direction` ObjectClass from `dp`.
"""
function import_ventilation_space_heat_flow_direction!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    # Abort import if df is empty
    df = dp["ventilation_spaces"][!, 1:4]
    isempty(df) && return nothing
    # Define ventilation space data.
    oc = "ventilation_space_heat_flow_direction"
    param = "thermal_resistance_m2K_W"
    dirs = Symbol.(names(df[!, 2:end]))
    # Import object class and objects
    push!(rsd.object_classes, [oc])
    append!(rsd.objects, [[oc, String(dir)] for dir in dirs])
    # Import parameter defaults.
    push!(rsd.object_parameters, [oc, param, nothing])
    # Import map parameter value.
    append!(
        rsd.object_parameter_values,
        [
            [
                oc,
                String(dir),
                param,
                Dict(
                    "type" => "map",
                    "index_type" => "float",
                    "data" => Dict(zip(df[!, :thickness_mm], df[!, dir]))
                )
            ]
            for dir in dirs
        ]
    )
end


"""
    _import_oc!(
        rsd::RawSpineData,
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
    rsd::RawSpineData,
    df::DataFrame,
    oc::Symbol,
    stackrange::UnitRange{Int64},
    args...
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Reshape dataframe prior to extracting objects.
    df = rename(stack(df, stackrange), :variable => oc)
    # Fetch and add the relevant objects
    _import_oc!(rsd, df, oc, args...)
end
function _import_oc!(
    rsd::RawSpineData,
    df::DataFrame,
    oc::Symbol
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Fetch and add the relevant objects
    push!(rsd.object_classes, [String(oc)])
    append!(
        rsd.objects,
        [[String(oc), String(obj)] for obj in unique(df[!, oc])]
    )
end
function _import_oc!(
    rsd::RawSpineData,
    df::DataFrame,
    oc::Symbol,
    params::Vector{Symbol}
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Import the object class and objects
    _import_oc!(rsd, df, oc)
    # Import the desired parameter defaults.
    append!(
        rsd.object_parameters,
        [
            [String(oc), String(param), nothing]
            for param in params
        ]
    )
    # Import the parameter values.
    append!(
        rsd.object_parameter_values,
        [
            [String(oc), String(r[oc]), String(param), r[param]]
            for r in eachrow(df)
            for param in params
            if !ismissing(r[param])
        ]
    )
end


"""
    import_building_stock__building_type__building_period__location_id__heat_source!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_stock__building_type__building_period__location_id__heat_source!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_type__location_id__building_period!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_building_type__location_id__frame_material!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure__building_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_source__structure__layer_id__structure_material!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure__structure_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
        dp["structure_layers"],
        :structure__structure_type
    )
end


"""
    import_structure_material__frame_material!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure_material__frame_material!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
        dp["materials"],
        :structure_material__frame_material
    )
end


"""
    import_structure_type__ventilation_space_heat_flow_direction!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_structure_type__ventilation_space_heat_flow_direction!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
        dp["types"],
        :structure_type__ventilation_space_heat_flow_direction
    )
end


"""
    import_fenestration_source__building_type!(
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_fenestration_source__building_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        dp::Dict{String,DataFrame}
    )
Import the desired relationship class.
"""
function import_ventilation_source__building_type!(
    rsd::RawSpineData,
    dp::Dict{String,DataFrame}
)
    _import_rc!(
        rsd,
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
        rsd::RawSpineData,
        df::DataFrame,
        rc::Symbol,
        stackname::Symbol,
        stackrange::UnitRange{Int64},
        rename_value::Symbol,
        params::Vector{Symbol};
        object_classes::Vector{Symbol}=Symbol.(split(String(rc), "__"))
    )
Helper function for generic RelationshipClass imports.

`stackname`, `stackrange`, and `rename_value` can be used to manipulate
the DataFrame shape prior to extracting the relationship class,
while `params` is used to read parameter values if any.
`object_classes` can be used to set RelationshipClass dimensions manually.
These can be omitted if not needed.
"""
function _import_rc!(
    rsd::RawSpineData,
    df::DataFrame,
    rc::Symbol,
    stackname::Symbol,
    stackrange::UnitRange{Int64},
    rename_value::Symbol,
    params::Vector{Symbol};
    object_classes::Vector{Symbol}=Symbol.(split(String(rc), "__"))
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Reshape dataframe prior to extracting relationships.
    df = rename(stack(df, stackrange), [:variable => stackname, :value => rename_value])
    # Fetch and add the relevant relationships
    _import_rc!(rsd, df, rc, params; object_classes=object_classes)
end
function _import_rc!(
    rsd::RawSpineData,
    df::DataFrame,
    rc::Symbol,
    params::Vector{Symbol};
    object_classes::Vector{Symbol}=Symbol.(split(String(rc), "__"))
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Import the relationship class in question.
    _import_rc!(rsd, df, rc; object_classes=object_classes)
    # Import relationship parameter defaults.
    append!(
        rsd.relationship_parameters,
        [
            [String(rc), String(param), nothing]
            for param in params
        ]
    )
    # Import relationship parameter values.
    append!(
        rsd.relationship_parameter_values,
        [
            [String(rc), [String(r[oc]) for oc in object_classes], String(param), r[param]]
            for r in eachrow(df)
            for param in params
            if !ismissing(r[param])
        ]
    )
end
function _import_rc!(
    rsd::RawSpineData,
    df::DataFrame,
    rc::Symbol;
    object_classes::Vector{Symbol}=Symbol.(split(String(rc), "__"))
)
    # Abort import if df is empty
    isempty(df) && return nothing
    # Add relationships
    push!(
        rsd.relationship_classes,
        [String(rc), String.(object_classes)]
    )
    append!(
        rsd.relationships,
        unique(
            [String(rc), [String(r[oc]) for oc in object_classes]]
            for r in eachrow(df)
        )
    )
end