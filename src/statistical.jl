#=
    statistical.jl

This file contains functions for processing the statistical data.
=#

"""
    _average_gross_floor_area_m2_per_building_values(;
        building_stock=anything,
        building_type=anything,
        building_period=anything,
        location_id=anything,
        heat_source=anything,
        mod::Module = Main
    )

Create the `average_gross_floor_area_m2_per_building` parameter values
for the `building_stock_statistics` `RelationshipClass`.

Essentially, this function loops over all
`(building_stock, building_type, building_period, location_id, heat_source)`
in the data, and fetches the corresponding
`average_floor_area_m2(building_type, location_id, building_period)` data.
The calculations can be limited to only the desired object classes
by using the optional keyword arguments, and the `mod` keyword is used to
tweak the Module scope of the calculations.
"""
function _average_gross_floor_area_m2_per_building_values(;
    building_stock = anything,
    building_type = anything,
    building_period = anything,
    location_id = anything,
    heat_source = anything,
    mod::Module = Main,
)
    average_gross_floor_area_m2_per_building_values = Dict(
        (bsy, bt, bp, lid, hs) => Dict(
            :average_gross_floor_area_m2_per_building => parameter_value(
                mod.average_floor_area_m2(
                    building_type = bt,
                    location_id = lid,
                    building_period = bp,
                ),
            ),
        ) for (bsy, bt, bp, lid, hs) in
        mod.building_stock__building_type__building_period__location_id__heat_source(
            building_stock = building_stock,
            building_type = building_type,
            building_period = building_period,
            location_id = location_id,
            heat_source = heat_source;
            _compact = false,
        )
    )
    return average_gross_floor_area_m2_per_building_values
end


"""
    create_building_stock_statistics!(mod::Module;
        building_stock=anything,
        building_type=anything,
        building_period=anything,
        location_id=anything,
        heat_source=anything,
    )

Create the `building_stock_statistics` `RelationshipClass` in `mod` to house the building stock forecasts.

Based on the `building_stock__building_type__building_period__location_id__heat_source` relationship,
but with some renaming to make the data more flexible.
Furthermore, includes the `average_floor_area_m2` data as well.
Optional keyword arguments can be used to limit the scope of the calculations,
and the `mod` keyword is used to tweak the Module scope of the calculations.
"""
function create_building_stock_statistics!(
    mod::Module;
    building_stock = anything,
    building_type = anything,
    building_period = anything,
    location_id = anything,
    heat_source = anything,
)
    object_class_names =
        [:building_stock, :building_type, :building_period, :location_id, :heat_source]
    building_stock_statistics = RelationshipClass(
        :building_stock_statistics,
        object_class_names,
        mod.building_stock__building_type__building_period__location_id__heat_source(
            building_stock = building_stock,
            building_type = building_type,
            building_period = building_period,
            location_id = location_id,
            heat_source = heat_source;
            _compact = false,
        ),
        mergewith(
            merge,
            filtered_parameter_values(
                mod.building_stock__building_type__building_period__location_id__heat_source;
                building_stock = building_stock,
                building_type = building_type,
                building_period = building_period,
                location_id = location_id,
                heat_source = heat_source,
            ),
            _average_gross_floor_area_m2_per_building_values(;
                building_stock = building_stock,
                building_type = building_type,
                building_period = building_period,
                location_id = location_id,
                heat_source = heat_source,
                mod = mod,
            ),
        ),
        merge(
            mod.building_stock__building_type__building_period__location_id__heat_source.parameter_defaults,
            Dict(:average_gross_floor_area_m2_per_building => parameter_value(nothing)),
        ),
    )
    # Create the associated parameters
    params = [
        key => Parameter(key, [building_stock_statistics]) for
        key in keys(building_stock_statistics.parameter_defaults)
    ]
    # Evaluate the RelationshipClass and the associated parameters into the desired `mod`.
    @eval mod building_stock_statistics = $building_stock_statistics
    for (name, param) in params
        @eval mod $name = $param
    end
end


"""
    add_building_stock_year!(mod::Module)

Add the `building_stock_year` parameter for the `building_stock` objects in `mod`.

Currently, the `building_stock_year` is parsed from the name of the `building_stock`
objects, assuming the names are formatted like `<NAME>_<YEAR>`.
"""
function add_building_stock_year!(mod::Module)
    # Create new parameter
    building_stock_year = Parameter(:building_stock_year, [mod.building_stock])
    # Add parameter values for existing `building_stock` objects.
    for bs in mod.building_stock.objects
        mod.building_stock.parameter_values[bs][:building_stock_year] =
            parameter_value(parse(Float64, split(string(bs.name), "_")[2]))
    end
    # Add default parameter value
    mod.building_stock.parameter_defaults[:building_stock_year] = parameter_value(nothing)
    # Eval the created parameter into the correct module.
    @eval mod building_stock_year = $building_stock_year
end


"""
    _add_light_wall_types_and_is_load_bearing!(mod::Module)

Add new `structure_type`s for non-load-bearing exterior and partition walls,
as well as a new parameter `is_load_bearing` for whether the structure type is load-bearing.

Note that this function operates in Module `mod`!

Essentially, all the structure types in the raw data are assumed to be load-bearing.
This function creates the `light_exterior_wall` and `light_partition_wall`
`structure_types` assuming identical properties to their load-bearing counterparts,
except that the `:is_load_bearing` flag is set to `false`.
"""
function _add_light_wall_types_and_is_load_bearing!(mod::Module)
    # Create new parameter
    is_load_bearing = Parameter(:is_load_bearing, [mod.structure_type])
    # Add parameter values for existing structure types
    for st in mod.structure_type()
        mod.structure_type.parameter_values[st][:is_load_bearing] = parameter_value(true)
    end
    mod.structure_type.parameter_defaults[:is_load_bearing] = parameter_value(nothing)
    # Add the new structure type objects for light structures and their "parents".
    # NOTE! Link to pre-existing objects instead of creating new ones if possible.
    objs = [
        isnothing(mod.structure_type(Symbol("light_exterior_wall"))) ?
        Object(Symbol("light_exterior_wall")) :
        mod.structure_type(Symbol("light_exterior_wall")) =>
            mod.structure_type(Symbol("exterior_wall")),
        isnothing(mod.structure_type(Symbol("light_partition_wall"))) ?
        Object(Symbol("light_partition_wall")) :
        mod.structure_type(Symbol("light_partition_wall")) =>
            mod.structure_type(Symbol("partition_wall")),
    ]
    add_objects!(mod.structure_type, getfield.(objs, 1))
    # Add parameter values for the new structure types
    for (obj, parent) in objs
        mod.structure_type.parameter_values[obj][:structure_type_notes] =
            parameter_value("Automatically generated.")
        mod.structure_type.parameter_values[obj][:exterior_resistance_m2K_W] =
            mod.structure_type.parameter_values[parent][:exterior_resistance_m2K_W]
        mod.structure_type.parameter_values[obj][:interior_resistance_m2K_W] =
            mod.structure_type.parameter_values[parent][:interior_resistance_m2K_W]
        mod.structure_type.parameter_values[obj][:linear_thermal_bridge_W_mK] =
            mod.structure_type.parameter_values[parent][:linear_thermal_bridge_W_mK]
        mod.structure_type.parameter_values[obj][:is_load_bearing] = parameter_value(false)
        mod.structure_type.parameter_values[obj][:is_internal] =
            mod.structure_type.parameter_values[parent][:is_internal]
    end
    # Eval is_load_bearing to the desired `mod`
    @eval mod is_load_bearing = $is_load_bearing
end


"""
    _map_structure_types(is_load_bearing::SpineInterface.Parameter; mod::Module = Main)

Maps `structure_type` to its load-bearing variant. Only `light` structures are affected.

Note that this function operates in Module `mod`, set to `Main` by default!

Essentially, returns a `Dict` mapping each `structure_type` to itself,
with the exception of the `light_exterior_wall` and `light_partition_wall`
being mapped to `exterior_wall` and `partition_wall` repsectively.
"""
function _map_structure_types(is_load_bearing::SpineInterface.Parameter; mod::Module = Main)
    Dict(
        st =>
            is_load_bearing(structure_type = st) ? st :
            first(
                filter(s -> string(s.name) == string(st.name)[7:end], mod.structure_type()),
            ) for st in mod.structure_type()
    )
end


"""
    _form_building_structures(;
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64,
        mod::Module = Main,
    )

Forms the `BuildingStructure` for each structure in Module `mod`.

Essentially, loops over each `(source, structure)` in the raw input data,
and creates a corresponding `BuildingStructure` using the desired properties.
The keywords can be used to tweak material properties between their min and max values.
Note that only structures with [`total_building_type_weight`](@ref)
greater than zero are handled to avoid unnecessary calculations.
"""
function _form_building_structures(;
    thermal_conductivity_weight::Float64,
    interior_node_depth::Float64,
    variation_period::Float64,
    mod::Module = Main,
)
    [
        BuildingStructure(
            src,
            str;
            thermal_conductivity_weight = thermal_conductivity_weight,
            interior_node_depth = interior_node_depth,
            variation_period = variation_period,
            mod = mod,
        ) for (src, str) in mod.source__structure() if
        total_building_type_weight(src, str; mod = mod) > 0
    ]
end


"""
    _filter_relevant_building_structures(
        building_structures::Array{BuildingStructure,1},
        building_type::Object,
        building_period::Object,
        structure_type::Object,
        st_map::Dict;
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = Main,
    )

Find the `BuildingStructures` matching the provided criteria from data in `mod`.

Essentially, this function returns a filtered `Array` of `BuildingStructures`,
that match the desired `structure_type`, `building_type`, and `building_period`.
If nothing is found, relaxes the `building_period` `period_start`
by `lookback_if_empty = 10` and tries again.
If nothing is found after `max_lookbacks = 20`, throws an error.
"""
function _filter_relevant_building_structures(
    building_structures::Array{BuildingStructure,1},
    building_type::Object,
    building_period::Object,
    structure_type::Object,
    st_map::Dict;
    lookback_if_empty::Int64 = 10,
    max_lookbacks::Int64 = 20,
    mod::Module = Main,
)
    n = 0
    relevant_building_structures = Array{BuildingStructure,1}()
    while isempty(relevant_building_structures) && n <= max_lookbacks
        relevant_building_structures = filter(
            structure ->
                structure.type == st_map[structure_type] &&
                    building_type in structure.building_types &&
                    mod.period_start(building_period = building_period) -
                    n * lookback_if_empty <= structure.year &&
                    structure.year <= mod.period_end(building_period = building_period),
            building_structures,
        )
        n += 1
    end
    if isempty(relevant_building_structures)
        @error "No relevant structures can be found for `$(building_type):$(building_period):$(structure_type)`"
    else
        return relevant_building_structures
    end
end


"""
    _structure_type_parameter_values(
        building_structures::Array{BuildingStructure,1},
        inds::NamedTuple,
        is_load_bearing::SpineInterface.Parameter;
        mod::Module = Main,
    )

Aggregate the `building_structures` parameters from `mod` into a parameter value `Dict`.

**NOTE! The `share` parameter is never allowed to be zero, with a 1e-6 always added to the share.**
Adding 1e-6 to the share means that an even mix of materials is assumed if no meaningful data is found.

Essentially, this function performs the following steps:
1. Maps `structure_type` into its load-bearing variant via [`_map_structure_types`](@ref).
2. Filters out irrelevant structures based in `inds` using [`_filter_relevant_building_structures`](@ref).
3. Calculates the normalized weights of the relevant structures based on the `(building_type, location_id, frame_material)` frame material share data.
4. Calculates the aggregated average properties of the relevant structures, weighted using the normalized frame material weights.

Yielding the following weighted average structural parameters:
- `effective_thermal_mass_J_m2K`: Effective thermal mass of the structure.
- `linear_thermal_bridges_W_mK`: Linear thermal bridges of the structure.
- `design_U_value_W_m2K`: Design U-value of the structure, based on U-values in the input data, and used mainly as a reference for `total_U_value_W_m2K`.
- `total_U_value_W_m2K`: Estimated total U-value through the structure, accounting for both ambient air and ground interaction. Used mainly as a comparison against `design_U_value_W_m2K`.
- `external_U_value_to_ambient_air_W_m2K`: U-value portion from inside the structure into ambient air.
- `external_U_value_to_ground_W_m2K`: U-value portion from inside the structure into the ground.
- `internal_U_value_to_structure_W_m2K`: U-value portion from the interior air into the structure.
"""
function _structure_type_parameter_values(
    building_structures::Array{BuildingStructure,1},
    inds::NamedTuple,
    is_load_bearing::SpineInterface.Parameter;
    mod::Module = Main,
)
    (bt, bp, lid, st) = inds
    st_map = _map_structure_types(is_load_bearing; mod = mod)
    # Only consider structures for the correct period and building type.
    relevant_building_structures = _filter_relevant_building_structures(
        building_structures,
        bt,
        bp,
        st,
        st_map;
        lookback_if_empty = 10,
        mod = mod,
    )
    # Calculate the frame material weights for the structures.
    total_frame_material_share = sum(
        mod.share(building_type = bt, location_id = lid, frame_material = mat) + 1e-6
        for structure in relevant_building_structures for
        mat in mod.structure_material__frame_material(
            structure_material = structure.load_bearing_materials,
        )
    )
    frame_material_weight = Dict(
        structure =>
            sum(
                mod.share(building_type = bt, location_id = lid, frame_material = mat) +
                1e-6 for mat in mod.structure_material__frame_material(
                    structure_material = structure.load_bearing_materials,
                )
            ) / total_frame_material_share for structure in relevant_building_structures
    )
    if !isapprox(sum(values(frame_material_weight)), 1)
        @error "Frame material weights don't add up to one! `$(inds)` results in `$(sum(values(frame_material_weight)))`"
    end
    # Select which property to use depending on whether the structure is load-bearing
    property = is_load_bearing(structure_type = st) ? :loadbearing : :min
    # Form the parameter value array
    parameter_values = merge(
        Dict(
            param_name => parameter_value(
                sum(
                    frame_material_weight[structure] *
                    getfield(getfield(structure, field), property) for
                    structure in relevant_building_structures
                ),
            ) for (param_name, field) in Dict(
                :effective_thermal_mass_J_m2K => :effective_thermal_mass,
                :linear_thermal_bridges_W_mK => :linear_thermal_bridges,
                :design_U_value_W_m2K => :design_U_value,
            )
        ),
        Dict(
            param_name => parameter_value(
                sum(
                    frame_material_weight[structure] * getfield(
                        get(structure.U_value_dict, key, Property(0.0)),
                        property,
                    ) for structure in relevant_building_structures
                ),
            ) for (param_name, key) in Dict(
                :total_U_value_W_m2K => :total,
                :external_U_value_to_ambient_air_W_m2K => :exterior,
                :external_U_value_to_ground_W_m2K => :ground,
                :internal_U_value_to_structure_W_m2K => :interior,
            )
        ),
    )
    return parameter_values
end


"""
    create_structure_statistics!(
        mod::Module;
        building_type=anything,
        building_period=anything,
        location_id=anything,
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64,
    )

Create the `structure_statistics` `RelationshipClass` to house the structural data from `mod`.

The keywords can be used to filter produced data,
as well as tweak how the different material properties are weighted:
0 uses the minimum values, and 1 uses the maximum values.
`interior_node_depth` is used to calculate the thermal resistance into the structure node,
and `variation_period` affects the effective thermal mass accounting for surface resistance.

Essentially, this function performs the following steps:
1. Creates the `is_load_bearing` parameter via [`_add_light_wall_types_and_is_load_bearing!`](@ref)
2. Forms all `BuildingStructures` using [`_form_building_structures`](@ref)
3. Creates and returns the `structure_statistics` `RelationshipClass`, with its parameters calculated using [`_structure_type_parameter_values`](@ref)

The `RelationshipClass` stores the following structural parameters:
- `effective_thermal_mass_J_m2K`: Effective thermal mass of the structure.
- `linear_thermal_bridges_W_mK`: Linear thermal bridges of the structure.
- `design_U_value_W_m2K`: Design U-value of the structure, based on U-values in the input data, and used mainly as a reference for `total_U_value_W_m2K`.
- `total_U_value_W_m2K`: Estimated total U-value through the structure, accounting for both ambient air and ground interaction. Used mainly as a comparison against `design_U_value_W_m2K`.
- `external_U_value_to_ambient_air_W_m2K`: U-value portion from inside the structure into ambient air.
- `external_U_value_to_ground_W_m2K`: U-value portion from inside the structure into the ground.
- `internal_U_value_to_structure_W_m2K`: U-value portion from the interior air into the structure.
"""
function create_structure_statistics!(
    mod::Module;
    building_type = anything,
    building_period = anything,
    location_id = anything,
    thermal_conductivity_weight::Float64,
    interior_node_depth::Float64,
    variation_period::Float64,
)
    # Add non-load bearing wall types and a parameter to indicate this.
    _add_light_wall_types_and_is_load_bearing!(mod)
    # Form the building structures.
    building_structures = _form_building_structures(
        thermal_conductivity_weight = thermal_conductivity_weight,
        interior_node_depth = interior_node_depth,
        variation_period = variation_period;
        mod = mod,
    )
    # Create the new relationship class
    obj_clss = [:building_type, :building_period, :location_id, :structure_type]
    rels = [
        (building_type = bt, building_period = bp, location_id = lid, structure_type = st) for (bt, lid, bp) in mod.building_type__location_id__building_period(
            building_type = building_type,
            location_id = location_id,
            building_period = building_period;
            _compact = false,
        ) for st in mod.structure_type()
    ]
    structure_statistics = RelationshipClass(
        :structure_statistics,
        obj_clss,
        rels,
        Dict(
            tuple(inds...) => _structure_type_parameter_values(
                building_structures,
                inds,
                mod.is_load_bearing;
                mod = mod,
            ) for inds in rels
        ),
        Dict(
            :effective_thermal_mass_J_m2K => parameter_value(nothing),
            :linear_thermal_bridges_W_mK => parameter_value(nothing),
            :design_U_value_W_m2K => parameter_value(nothing),
            :total_U_value_W_m2K => parameter_value(nothing),
            :external_U_value_to_ambient_air_W_m2K => parameter_value(0.0),
            :external_U_value_to_ground_W_m2K => parameter_value(0.0),
            :internal_U_value_to_structure_W_m2K => parameter_value(nothing),
        ),
    )
    # Create the associated parameters
    params = [
        key => Parameter(key, [structure_statistics]) for
        key in keys(structure_statistics.parameter_defaults)
    ]
    # Eval the RelationshipClass and parameters to the desired `mod`
    @eval mod structure_statistics = $structure_statistics
    for (name, param) in params
        @eval mod $name = $param
    end
end


"""
    create_ventilation_and_fenestration_statistics!(
        mod::Module;
        building_type=anything,
        location_id=anything,
        building_period=anything,
        ventilation_rate_weight::Float64=0.5,
        n50_infiltration_rate_weight::Float64=0.5,
        infiltration_factor_weight::Float64=0.5,
        HRU_efficiency_weight::Float64=0.5,
        lookback_if_empty::Int64=10,
        max_lookbacks::Int64=20,
    )

Create the `ventilation_and_fenestration_statistics` `RelationshipClass`
to house ventilation and fenestration data from `mod`.

The `ObjectClass` keywords can be used to filter the processed data,
while the `weight` keywords can be used to tweak how the properties are sampled:
0 uses the minimum value, and 1 uses the maximum value.
The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.

The `RelationshipClass` stores the following ventilation and fenestration parameters:
- `ventilation_rate_1_h`: Calculated using [`mean_ventilation_rate`](@ref)
- `infiltration_rate_1_h`: Calculated using [`mean_infiltration_rate`](@ref)
- `HRU_efficiency`: Calculated using [`mean_hru_efficiency`](@ref)
- `window_U_value_W_m2K`: Calculated using [`mean_window_U_value`](@ref)
- `total_normal_solar_energy_transmittance`: Calculated using [`mean_total_normal_solar_energy_transmittance`](@ref)
"""
function create_ventilation_and_fenestration_statistics!(
    mod::Module;
    building_type = anything,
    location_id = anything,
    building_period = anything,
    ventilation_rate_weight::Float64 = 0.5,
    n50_infiltration_rate_weight::Float64 = 0.5,
    infiltration_factor_weight::Float64 = 0.5,
    HRU_efficiency_weight::Float64 = 0.5,
    lookback_if_empty::Int64 = 10,
    max_lookbacks::Int64 = 20,
)
    obj_clss = [:building_type, :building_period, :location_id]
    rels = [
        (building_type = bt, building_period = bp, location_id = lid) for
        (bt, lid, bp) in mod.building_type__location_id__building_period(
            building_type = building_type,
            location_id = location_id,
            building_period = building_period;
            _compact = false,
        )
    ]
    ventilation_and_fenestration_statistics = RelationshipClass(
        :ventilation_and_fenestration_statistics,
        obj_clss,
        rels,
        Dict(
            tuple(bt, bp, lid) => Dict(
                :ventilation_rate_1_h => parameter_value(
                    mean_ventilation_rate(
                        bp,
                        bt;
                        weight = ventilation_rate_weight,
                        lookback_if_empty = lookback_if_empty,
                        max_lookbacks = max_lookbacks,
                        mod = mod,
                    ),
                ),
                :infiltration_rate_1_h => parameter_value(
                    mean_infiltration_rate(
                        bp,
                        bt;
                        n50_weight = n50_infiltration_rate_weight,
                        factor_weight = infiltration_factor_weight,
                        lookback_if_empty = lookback_if_empty,
                        max_lookbacks = max_lookbacks,
                        mod = mod,
                    ),
                ),
                :HRU_efficiency => parameter_value(
                    mean_hru_efficiency(
                        bp,
                        bt;
                        weight = HRU_efficiency_weight,
                        lookback_if_empty = lookback_if_empty,
                        max_lookbacks = max_lookbacks,
                        mod = mod,
                    ),
                ),
                :window_U_value_W_m2K => parameter_value(
                    mean_window_U_value(
                        bp,
                        bt;
                        lookback_if_empty = lookback_if_empty,
                        max_lookbacks = max_lookbacks,
                        mod = mod,
                    ),
                ),
                :total_normal_solar_energy_transmittance => parameter_value(
                    mean_total_normal_solar_energy_transmittance(
                        bp,
                        bt;
                        lookback_if_empty = lookback_if_empty,
                        max_lookbacks = max_lookbacks,
                        mod = mod,
                    ),
                ),
            ) for (bt, bp, lid) in rels
        ),
        Dict(
            param => parameter_value(nothing) for param in [
                :ventilation_rate_1_h,
                :infiltration_rate_1_h,
                :HRU_efficiency,
                :window_U_value_W_m2K,
                :total_normal_solar_energy_transmittance,
            ]
        ),
    )
    # Create the associated parameters
    params = [
        name => Parameter(name, [ventilation_and_fenestration_statistics]) for
        name in keys(ventilation_and_fenestration_statistics.parameter_defaults)
    ]
    # Evaluate the RelationshipClass and parameters to the desired `mod`
    @eval mod ventilation_and_fenestration_statistics =
        $ventilation_and_fenestration_statistics
    for (name, param) in params
        @eval mod $name = $param
    end
end
