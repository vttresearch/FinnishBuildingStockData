#=
    structural.jl

This file contains types and functions for processing the structural building stock data.
Here, we refine the raw structural data into something we can combine with the statistical data.
=#

"""
    Layer

A `struct` representing a structural layer.

Contains the following fields:
- `number::Int`: Indicates the *depth* of the layer within the structure. Negative values indicate layers inside the primary thermal insulation layer, 0 indicates the primary thermal insulation layer, and positive values indicate layers outside the primary insulation layer.
- `tag::Symbol`: A tag explaining the purpose of each layer.
- `id::Object`: Unique identifier for each structural layer.
- `material::Object`: The material of the structural layer.
"""
struct Layer
    number::Int
    tag::Symbol
    id::Object
    material::Object
end


"""
    Property

A convenience `struct` handling minimum and load-bearing properties of structural layers.

Contains the following fields:
- `min::Real`: The minimum property of the structural layer when it is non-load-bearing.
- `loadbering::Real`: The minimum load-bearing when it is load-bearing.
"""
mutable struct Property
    min::Real
    loadbearing::Real
end
Property(val::Real) = Property(val, val)
Property(val::Nothing) = Property(0.0, 0.0)

# Base arithmetic for `Property`
Base.:+(p1::Property, p2::Property) =
    Property(p1.min + p2.min, p1.loadbearing + p2.loadbearing)
Base.:+(p::Property, num::Number) = Property(p.min + num, p.loadbearing + num)
Base.:+(num::Number, p::Property) = +(p, num)
Base.:*(p1::Property, p2::Property) =
    Property(p1.min * p2.min, p1.loadbearing * p2.loadbearing)
Base.:*(p::Property, num::Number) = Property(p.min * num, p.loadbearing * num)
Base.:*(num::Number, p::Property) = *(p, num)


"""
    PropertyLayer

A `struct` storing the [`Property`](@ref)s of structural layers, used for calculations.

Contains the following fields:
- `number::Int`: Indicates the *depth* of the layer within the structure. Negative values indicate layers inside the primary thermal insulation layer, 0 indicates the primary thermal insulation layer, and positive values indicate layers outside the primary insulation layer.
- `R::Property`: The thermal resistance of the structural layer in [m2K/W], both for load-bearing and non-load-bearing variants of the layer.
- `C::Property`: The heat capacity of the structural layer in [J/m2K], both for load-bearing and non-load-bearing variants of the layer.
- `interior::Bool`: A flag whether this layer lies between the interior surface and the primary thermal insulation layer of the structure.
- `exterior::Bool`: A flag whether this layer lies between the exterior surface and the primary thermal insulation layer of the structure.
- `ground::Bool`: A flag whether this layer lies between the ground and the primary thermal insulation layer of the structure.
"""
struct PropertyLayer
    number::Int
    R::Property
    C::Property
    interior::Bool
    exterior::Bool
    ground::Bool
end

# Base arithmetic for `PropertyLayers`
function Base.isless(l1::Union{Layer,PropertyLayer}, l2::Union{Layer,PropertyLayer})
    isless(l1.number, l2.number)
end


"""
    layer_number_weight(layer::Union{Layer,PropertyLayer})

Returns 0.5 if layer.num == 0, otherwise returns 1.
"""
function layer_number_weight(layer::Union{Layer,PropertyLayer})
    return layer.number == 0 ? 0.5 : 1
end


"""
    total_building_type_weight(source::Object, structure::Object; mod::Module = @__MODULE__)

Return the total `building_type_weight` of the `structure` from `mod`, 0 if not applicable.
"""
function total_building_type_weight(
    source::Object,
    structure::Object;
    mod::Module=@__MODULE__
)
    reduce(
        +,
        mod.building_type_weight(
            source=source,
            structure=structure,
            building_type=bt,
        ) for
        bt in mod.source__structure__building_type(source=source, structure=structure) if
        !isnothing(
            mod.building_type_weight(
                source=source,
                structure=structure,
                building_type=bt,
            ),
        );
        init=0.0
    )::Float64
end


"""
    order_layers(source::Object, structure::Object; mod::Module = @__MODULE__)

Order the structural layers of `(source, structure)` from `mod` according to the `layer_number`s.

Returns an array of [`Layer`](@ref)s, sorted according to the `layer_number` parameter,
as well as the unique array of `layer_number`s.
"""
function order_layers(source::Object, structure::Object; mod::Module=@__MODULE__)
    layers = sort([
        Layer(
            Int(
                mod.layer_number(
                    source=src,
                    structure=str,
                    layer_id=id,
                    structure_material=mat,
                ),
            ),
            mod.layer_tag(
                source=src,
                structure=str,
                layer_id=id,
                structure_material=mat,
            ),
            id,
            mat,
        ) for
        (src, str, id, mat) in mod.source__structure__layer_id__structure_material(
            source=source,
            structure=structure,
            _compact=false,
        )
    ])
    layer_numbers = unique(map(l -> l.number, layers))
    return layers, layer_numbers
end


"""
    isloadbearing(source::Object, structure::Object; mod::Module = @__MODULE__)

Check if `structure` from `mod` can be load-bearing and return a `Bool`.

A `structure` is interpreted as potentially load-bearing
if any of its layers has a `layer_load_bearing_thickness_mm` value in the raw input data.
"""
function isloadbearing(source::Object, structure::Object; mod::Module=@__MODULE__)
    loadbearing =
        !all(
            isnothing.(
                mod.layer_load_bearing_thickness_mm(
                    source=src,
                    structure=str,
                    layer_id=id,
                    structure_material=mat,
                ) for
                (src, str, id, mat) in mod.source__structure__layer_id__structure_material(
                    source=source,
                    structure=structure,
                    _compact=false,
                )
            ),
        )
end


"""
    _thermal_resistance(
        source::Object,
        structure::Object,
        layer::Layer,
        thickness::SpineInterface.Parameter,
        R_itp::Interpolations.Extrapolation;
        weight::Float64 = 0.5,
        mod::Module = @__MODULE__,
    )

Calculate the thermal resistance [W/m2K] of a single homogeneous structural `layer`.

For regular material layers, the thermal resistance is calculated as:
```math
R = \\frac{\\textit{thickness}}{\\textit{thermal conductivity}}
```
but for layers with `ventilation space` as the material,
linearly interpolated tabulated values from the raw input data are used instead.
The `weight` keyword can be used to tweak the thermal conductivity
of the materials between their min and max values.
"""
function _thermal_resistance(
    source::Object,
    structure::Object,
    layer::Layer,
    thickness::SpineInterface.Parameter,
    R_itp::Interpolations.Extrapolation;
    weight::Float64=0.5,
    mod::Module=@__MODULE__
)
    if layer.material.name == Symbol("ventilation space")
        R = R_itp(
            thickness(
                source=source,
                structure=structure,
                layer_id=layer.id,
                structure_material=layer.material,
            ),
        )
    else
        R = (
            thickness(
                source=source,
                structure=structure,
                layer_id=layer.id,
                structure_material=layer.material,
            ) * 1e-3 / thermal_conductivity(layer.material; weight=weight, mod=mod)
        )
    end
    return R
end


"""
    layer_thermal_resistance(
        source::Object,
        structure::Object,
        layers::Array{Layer,1},
        R_itp::Interpolations.Extrapolation;
        weight::Float64 = 0.5
        mod::Module = @__MODULE__
    )

Calculate the thermal resistance [m2K/W] of a potentially heterogeneous structural layer as:
```math
R = \\left(\\sum_{i \\in \\text{overlapping}} \\frac{\\textit{layer weight}(i)*\\textit{thermal conductivity}(i)}{\\textit{thickness}(i)} \\right)^{-1}
```
Returns a [`Property`](@ref) with the thermal resistance for the minimum thickness `min`,
and the thermal resistance for the load-bearing thickness `loadbearing`.
The thermal resistance is assumed to be zero if it cannot be calculated using the parameters
(e.g. when thickess is zero).
The `weight` keyword can be used to tweak the thermal conductivity of the materials between their min and max values.
The `mod` keyword defines the Module from which the data is accessed.
"""
function layer_thermal_resistance(
    source::Object,
    structure::Object,
    layers::Array{Layer,1},
    R_itp::Interpolations.Extrapolation;
    weight::Float64=0.5,
    mod::Module=@__MODULE__
)
    thicknesses = [mod.layer_minimum_thickness_mm, mod.layer_load_bearing_thickness_mm]
    R = zeros(length(thicknesses))
    for (i, thickness) in enumerate(thicknesses)
        r =
            1 / reduce(
                +,
                mod.layer_weight(
                    source=source,
                    structure=structure,
                    layer_id=l.id,
                    structure_material=l.material,
                ) / _thermal_resistance(
                    source,
                    structure,
                    l,
                    thickness,
                    R_itp;
                    weight=weight,
                    mod=mod
                ) for l in layers if !isnothing(
                    thickness(
                        source=source,
                        structure=structure,
                        layer_id=l.id,
                        structure_material=l.material,
                    ),
                );
                init=0
            )
        if !isnan(r) && !isinf(r)
            R[i] = r
        end
    end
    return Property(R[1], R[2] == 0 ? R[1] : R[2])
end


"""
    layer_heat_capacity(
        source::Object,
        structure::Object,
        layers::Array{Layer,1};
        mod::Module = @__MODULE__
    )

Calculate the effective heat capacity [J/m2K] of a potentially heterogeneous structural layer as:
```math
C = \\sum_{i \\in \\text{overlapping}} \\textit{layer weight}(i) * \\textit{specific heat capacity}(i) * \\textit{density}(i) * \\textit{thickness}(i)
```
Returns a [`Property`](@ref) with the effective heat capacity for the minimum thickness `min`,
and the effective heat capacity for the load-bearing thickness `loadbearing`.
The thermal capacity is assumed to be zero if it cannot be calculated using the parameters
(e.g. when thickness is zero).
The `mod` keyword defines the Module from which the data is accessed.
"""
function layer_heat_capacity(
    source::Object,
    structure::Object,
    layers::Array{Layer,1};
    mod::Module=@__MODULE__
)
    thicknesses = [mod.layer_minimum_thickness_mm, mod.layer_load_bearing_thickness_mm]
    C = zeros(length(thicknesses))
    for (i, thickness) in enumerate(thicknesses)
        c = reduce(
            +,
            mod.layer_weight(
                source=source,
                structure=structure,
                layer_id=l.id,
                structure_material=l.material,
            ) *
            specific_heat_capacity(l.material; mod=mod) *
            density(l.material; mod=mod) *
            (
                thickness(
                    source=source,
                    structure=structure,
                    layer_id=l.id,
                    structure_material=l.material,
                ) * 1e-3
            ) for l in layers if !isnothing(
                thickness(
                    source=source,
                    structure=structure,
                    layer_id=l.id,
                    structure_material=l.material,
                ),
            );
            init=0
        )
        if !isnan(c) && !isinf(c)
            C[i] = c
        end
    end
    return Property(C[1], C[2] == 0 ? C[1] : C[2])
end


"""
    layers_with_properties(
        source::Object,
        structure::Object,
        R_itp::Interpolations.Extrapolation;
        thermal_conductivity_weight::Float64
        mod::Module = @__MODULE__,
    )

Calculate the properties of the structural layers while combining overlapping layers.

Returns an array of unique `structure_material`s for the load-bearing layers,
as well as an array of the processed [`PropertyLayer`](@ref)s.
The keywords can be used to tweak material properties between their min and max values,
while the `mod` keyword defines the Module from which the data is accessed.

Essentially, this function performs the following steps:
1. Order and create the [`Layer`](@ref)s in the structure using [`order_layers`](@ref).
2. Identify the load bearing materials.
3. Identify whether the structure is ground-coupled or not.
4. Calculate the layer properties using [`layer_thermal_resistance`](@ref) and [`layer_heat_capacity`](@ref).
5. Create the final array of [`PropertyLayer`](@ref)s using the calculated layer properties.
"""
function layers_with_properties(
    source::Object,
    structure::Object,
    R_itp::Interpolations.Extrapolation;
    thermal_conductivity_weight::Float64,
    mod::Module=@__MODULE__
)
    # Order and find important layers and load-bearing material.
    layers, layer_numbers = order_layers(source, structure; mod=mod)
    load_bearing_materials = unique(
        getfield.(
            filter(l -> l.tag == Symbol("load-bearing structure"), layers),
            :material,
        ),
    )
    exterior_tags = [Symbol("exterior finish"), Symbol("crawl space")]
    ground_tags = [Symbol("ground")]
    exterior_number = try
        first(filter(l -> l.tag in exterior_tags, layers)).number
    catch
        -1
    end
    ground_number = try
        first(filter(l -> l.tag in ground_tags, layers)).number
    catch
        -1
    end

    # Process layers
    layers_with_properties = Array{PropertyLayer,1}(
        PropertyLayer(
            num,
            layer_thermal_resistance(
                source,
                structure,
                overlap,
                R_itp;
                weight=thermal_conductivity_weight,
                mod=mod
            ),
            layer_heat_capacity(source, structure, overlap; mod=mod),
            num <= 0,
            0 <= num <= exterior_number,
            0 <= num <= ground_number
        )
        for num in layer_numbers
    )
    return load_bearing_materials, layers_with_properties
end


"""
    calculate_ground_resistance_m2K_W(Rf::Float64, Rp::Float64)

Calculate the effective ground thermal resistance [m2K/W].

```math
R_g = \\left( \\frac{0.114}{0.7044 + R_f + R_p} + \\frac{0.8768}{2.818 + R_f} \\right)^{-1}
```

The calculation is based on the simple method proposed by K.Kissock in:
`Simplified Model for Ground Heat Transfer from Slab-on-Grade Buildings, (c) 2013 ASHRAE`,
where:
- `Rf` stands for the total thermal resistance of the floor structures.
- `Rp` stands for the additional ground perimeter insulation thermal resistance (assumed 0 since no data).
Note that the correction factor `C` can only be taken into account later on,
when the dimensions of the building are known!
"""
function calculate_ground_resistance_m2K_W(Rf::Float64, Rp::Float64)
    Float64(1.0 / (0.114 / (0.7044 + Rf + Rp) + 0.8768 / (2.818 + Rf)))
end


"""
    account_for_surface_resistance_in_effective_thermal_mass!(
        C::Property,
        surface_resistance::Float64,
        variation_period::Float64
    )

Account for the `surface_resistance` and the assumed `variation_period` ("period of the variations").

The effective thermal mass is calculated according to *EN ISO 13786:2017 Annex C.2.4 Effective thickness method*.
When used for a [`Property`](@ref), calculates the effective thermal mass separately for both `min` and `loadbearing` values.
"""
function account_for_surface_resistance_in_effective_thermal_mass!(
    C::Property,
    surface_resistance::Float64,
    variation_period::Float64,
)
    C.min = account_for_surface_resistance_in_effective_thermal_mass!(
        C.min,
        surface_resistance,
        variation_period,
    )
    C.loadbearing = account_for_surface_resistance_in_effective_thermal_mass!(
        C.loadbearing,
        surface_resistance,
        variation_period,
    )
end
function account_for_surface_resistance_in_effective_thermal_mass!(
    C::Float64,
    surface_resistance::Float64,
    variation_period::Float64,
)
    return sqrt(C^2 / (1 + (2 * π / variation_period)^2 * C^2 * surface_resistance^2))
end


"""
    calculate_structure_properties(
        source::Object,
        structure::Object;
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64,
        mod::Module = @__MODULE__,
    )

Calculate the properties of `(source, structure)` from `mod` based on the raw structural data.

This function calculates the following properties for each `(source, structure)`:

1. U-value [W/m2K] from the interior into the structure itself.
2. U-value [W/m2K] from the structure into exterior air.
3. U-value [W/m2K] from the structure into ground.
4. Total U-value [W/m2K] through the structure from interior to exterior (mainly for cross-referencing purposes).
5. Effective thermal mass [J/m2K] of the structure (calculated from layers inside the primary insulation).

**Note that for internal structure types, all structural layers are included in the effective thermal mass!**

The U-values are calculated as the inverse of the total thermal resistance of the structural layers:
```math
U = R_{\\text{total}}^{-1} = \\left( \\sum_{l \\in \\text{layers}} R_{l} \\right)^{-1}
```
The zeroth layer is considered as the boundary between internal layers and external layers,
and contains the primary thermal insulation layer for envelope structures.
As such, half of the zeroth layer is considered as an internal layer, and the other half as an external layer.

If a structure contains an `exterior finish` or `crawl space` layer,
the U-value to the exterior air will be calculated until that layer.
If a structure contains the `ground` layer, the U-value to the ground will be calculated until that layer.
If a structure contains both (e.g. base floors with crawl spaces),
both U-values will be calculated separately, and the total U-value will be calculated based on them,
as if they were parallel thermal resistances.

All the above parameters are calculated separately for the non-load-bearing and load-bearing variants
of the structure.

The keywords can be used to tweak material properties between their min and max values,
the assumed "depth" of the temperature node, and the "period of variations" as explained in EN ISO 13786:2017.

Essentially, this function performs the following steps:
1. Linearly interpolate the thermal resistance of ventilation spaces based on the raw input data.
2. Calculate the properties of the structural layers using [`layers_with_properties`](@ref).
3. Check if the structure can be load-bearing using [`isloadbearing`](@ref).
4. Calculate the total effective thermal mass of the structure by summing the effective thermal mass of the interior layers.
5. Call [`account_for_surface_resistance_in_effective_thermal_mass!`](@ref) with the assumed `variation_period`.
6. Call [`calculate_ground_resistance_m2K_W`](@ref) using the method by Kissock et al. 2013.
7. Calculate the thermal resistances for the different parts of the structure, accounting for surface resistances and the assumed `interior_node_depth`.
8. Calculate the final U-values for the different parts of the structure based on the above thermal resistances.
"""
function calculate_structure_properties(
    source::Object,
    structure::Object;
    thermal_conductivity_weight::Float64,
    interior_node_depth::Float64,
    variation_period::Float64,
    mod::Module=@__MODULE__
)
    # Fetch the structure type
    typ = first(mod.structure__structure_type(structure=structure))

    # Form the linear interpolator for the thermal resistance of potential ventilation spaces in the structure.
    R_map = mod.thermal_resistance_m2K_W(
        ventilation_space_heat_flow_direction=first(
            mod.structure_type__ventilation_space_heat_flow_direction(structure_type=typ),
        ),
    )
    R_ventilation_space = LinearInterpolation(
        R_map.indexes,
        R_map.values;
        extrapolation_bc=Flat()
    )

    # Calculate properties of the structural layers and form layer sets of particular interest.
    load_bearing_materials, layers = layers_with_properties(
        source,
        structure,
        R_ventilation_space;
        thermal_conductivity_weight=thermal_conductivity_weight,
        mod=mod
    )
    layer_tiers = [:interior, :exterior, :ground]
    layer_dict =
        Dict(tier => filter(l -> getproperty(l, tier), layers) for tier in layer_tiers)

    # Check if the structure can be load-bearing
    loadbearing = isloadbearing(source, structure; mod=mod)

    # Calculate the total effective thermal mass of the structure
    C = Property(
        sum(layer_number_weight(l) * l.C.min for l in layer_dict[:interior]),
        sum(layer_number_weight(l) * l.C.loadbearing for l in layer_dict[:interior]),
    )
    account_for_surface_resistance_in_effective_thermal_mass!(
        C,
        mod.interior_resistance_m2K_W(structure_type=typ),
        variation_period,
    )

    # If structure is internal, need to account for the "exterior" layers as well.
    if mod.is_internal(
        structure_type=first(mod.structure__structure_type(structure=structure)),
    )
        C_ext = Property(
            sum(layer_number_weight(l) * l.C.min for l in layer_dict[:exterior]),
            sum(layer_number_weight(l) * l.C.loadbearing for l in layer_dict[:exterior]),
        )
        account_for_surface_resistance_in_effective_thermal_mass!(
            C_ext,
            mod.exterior_resistance_m2K_W(structure_type=typ),
            variation_period,
        )
        C += C_ext
    end

    # Calculate the base thermal resistances [m2K/W] of the different parts of the structure.
    R_dict = Dict{Symbol,Property}(
        tier => Property(
            sum(layer_number_weight(l) * l.R.min for l in layer_dict[tier]),
            sum(layer_number_weight(l) * l.R.loadbearing for l in layer_dict[tier]),
        ) for tier in layer_tiers if !isempty(layer_dict[tier])
    )

    # Include surface resistances and tweak the "depth" of the structure node.
    # Exterior resistance with partial interior resistance due to depth of the interior node
    if haskey(R_dict, :exterior)
        R_dict[:exterior] +=
            mod.exterior_resistance_m2K_W(structure_type=typ) +
            (1 - interior_node_depth) * R_dict[:interior]
    end

    # Calculate the effective ground thermal resistance according to Kissock2013, interior node depth accounted for.
    if haskey(R_dict, :ground)
        R_dict[:ground].min = (
            calculate_ground_resistance_m2K_W(
                R_dict[:ground].min +
                R_dict[:interior].min +
                mod.interior_resistance_m2K_W(structure_type=typ),
                0.0,
            ) - interior_node_depth * R_dict[:interior].min
        )
        R_dict[:ground].loadbearing = (
            calculate_ground_resistance_m2K_W(
                R_dict[:ground].loadbearing +
                R_dict[:interior].loadbearing +
                mod.interior_resistance_m2K_W(structure_type=typ),
                0.0,
            ) - interior_node_depth * R_dict[:interior].loadbearing
        )
    end

    # Modify the interior node depth and include interior surface resistance.
    if haskey(R_dict, :interior)
        R_dict[:interior] *= interior_node_depth
        R_dict[:interior] += mod.interior_resistance_m2K_W(structure_type=typ)
    end

    # Scale the `:exterior` and `:ground` parallel thermal resistances based on their respective U-values.
    inf_tuple = (min=Inf, loadbearing=Inf)
    for tier in [:exterior, :ground]
        if !isnothing(get(R_dict, tier, nothing))
            R_dict[tier].min /= (
                1.0 / R_dict[tier].min / (
                    1.0 / get(R_dict, :exterior, inf_tuple).min +
                    1.0 / get(R_dict, :ground, inf_tuple).min
                )
            )
            R_dict[tier].loadbearing /= (
                1.0 / R_dict[tier].loadbearing / (
                    1.0 / get(R_dict, :exterior, inf_tuple).loadbearing +
                    1.0 / get(R_dict, :ground, inf_tuple).loadbearing
                )
            )
        end
    end

    # Calculate the U-values [W/m2K] for different parts of the structure.
    U_dict = Dict{Symbol,Property}(
        tier => Property(1.0 / R_dict[tier].min, 1.0 / R_dict[tier].loadbearing) for
        tier in layer_tiers if !isempty(layer_dict[tier])
    )

    # Calculate the total U-value [W/m2K] through the entire structure.
    U_dict[:total] = Property(
        1.0 / (
            R_dict[:interior].min +
            1.0 / (
                1.0 / get(R_dict, :exterior, inf_tuple).min +
                1.0 / get(R_dict, :ground, inf_tuple).min
            )
        ),
        1.0 / (
            R_dict[:interior].loadbearing +
            1.0 / (
                1.0 / get(R_dict, :exterior, inf_tuple).loadbearing +
                1.0 / get(R_dict, :ground, inf_tuple).loadbearing
            )
        ),
    )
    return loadbearing, load_bearing_materials, C, U_dict, R_dict
end


"""
    BuildingStructure

A `struct` representing a structure with all its important properties.

Contains the following fields:
1. `name::Symbol`: Name of the structure, combined from the `source` and `structure` identifiers.
2. `type::Object`: The type of the structure, e.g. `exterior_wall`, `roof`, or `light_partition_wall`.
3. `year::Float64`: Year of the `source` including this structure, after which the structure is assumed to be in use.
4. `internal::Bool`: A flag indicating whether the structure is an internal structure, as opposed to envelope structures.
5. `loadbearing::Bool` A flag indicating whether the structure can be load-bearing.
6. `load_bearing_materials::Array{Object,1}`: An array of the load-bearing materials used in this structure.
7. `design_U_value::Property`: The original design U-value [W/m2K] of the structure in the raw input data.
8. `U_value_dict::Dict{Symbol,Property}`: Holds all the different U-values [W/m2K] between the ambient, structural, and interior air nodes.
9. `effective_thermal_mass::Property`: Effective thermal mass of the structure [J/m2K].
10. `linear_thermal_bridges::Property`: Linear thermal bridges [W/mK] of the structure based on raw input data.
11. `building_types::Array{Object,1}`: List of `building_type`s employing this structure.

The constructor essentially performs the following steps:
1. Define the `name`, `type`, `year`, `internal`, `design_U_value`, `linear_thermal_bridges`, and `building_types` based on raw input data.
2. Determine the `loadbearing`, `load_bearing_materials`, `effective_thermal_mass`, and `U_value_dict` via the [`calculate_structure_properties`](@ref) function.
3. Create the final `BuildingStructure`.
"""
struct BuildingStructure
    name::Symbol
    type::Object
    year::Float64
    internal::Bool
    loadbearing::Bool
    load_bearing_materials::Array{Object,1}
    design_U_value::Property
    U_value_dict::Dict{Symbol,Property}
    effective_thermal_mass::Property
    linear_thermal_bridges::Property
    building_types::Array{Object,1}
    function BuildingStructure(
        source::Object,
        structure::Object;
        thermal_conductivity_weight::Float64,
        interior_node_depth::Float64,
        variation_period::Float64,
        mod::Module=@__MODULE__
    )
        # Determine some base properties of the structure based on raw input data.
        name = Symbol(string(source.name) * ":" * string(structure.name))
        type = first(mod.structure__structure_type(structure=structure))
        year = mod.source_year(source=source)
        internal = mod.is_internal(structure_type=type)
        design_U_value =
            Property(mod.design_U_W_m2K(source=source, structure=structure))
        linear_thermal_bridges =
            Property(mod.linear_thermal_bridge_W_mK(structure_type=type))

        # Determine the building types this structure is applicable for.
        building_types = [
            building_type for building_type in mod.source__structure__building_type(
                source=source,
                structure=structure,
            ) if !isnothing(
                mod.building_type_weight(
                    source=source,
                    structure=structure,
                    building_type=building_type,
                ),
            ) &&
            mod.building_type_weight(
                source=source,
                structure=structure,
                building_type=building_type,
            ) > 0
        ]

        # Calculate the technical properties of the structure.
        loadbearing, load_bearing_materials, effective_thermal_mass, U_value_dict =
            calculate_structure_properties(
                source,
                structure;
                thermal_conductivity_weight=thermal_conductivity_weight,
                interior_node_depth=interior_node_depth,
                variation_period=variation_period,
                mod=mod
            )

        # Create the final `BuildingStructure` struct
        new(
            name,
            type,
            year,
            internal,
            loadbearing,
            load_bearing_materials,
            design_U_value,
            U_value_dict,
            effective_thermal_mass,
            linear_thermal_bridges,
            building_types,
        )
    end
end
