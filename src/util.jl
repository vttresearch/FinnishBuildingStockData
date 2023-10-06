#=
    util.jl

Contains miscellaneous utility functions and extensions to other modules.
=#

## Extend Base where necessary

Base.String(x::Int64) = String(string(x))
Base.merge!(rsd1::RawSpineData, rsds::RawSpineData...) = _merge_data!(rsd1, rsds...)
function Base.merge(rsds::RawSpineData...)
    args = collect(rsds)
    data = deepcopy(popfirst!(args))
    return _merge_data!(data, args...)
end


## Extend SpineInterface where necessary

SpineInterface.parameter_value(x::String31) = parameter_value(String(x))
SpineInterface.parameter_value(x::Missing) = parameter_value(nothing)
function SpineInterface.using_spinedb(rsd::RawSpineData, mod=@__MODULE__; filters=nothing)
    using_spinedb(
        Dict(
            string(field) => getfield(rsd, field)
            for field in fieldnames(RawSpineData)
        ),
        mod;
        filters=filters
    )
end
SpineInterface.Object(name::Int64, class_name::String) = Object(string(name), class_name)


## Miscellaneous functions

"""
    _merge_data!(rsd1::RawSpineData, rsds::RawSpineData ...)

Helper function for merging [`FinnishBuildingStockData.RawSpineData`](@ref).
"""
function _merge_data!(rsd1::RawSpineData, rsds::RawSpineData...)
    for rsd in rsds
        for fn in fieldnames(RawSpineData)
            unique!(append!(getfield(rsd1, fn), getfield(rsd, fn)))
        end
    end
    return rsd1
end


"""
    _check(cond::Bool, msg::String)

Check the condition `cond`, and print `msg` if `false`.
"""
function _check(cond::Bool, msg::String)
    cond || @warn msg
    return cond
end


"""
    _scramble_value(val)

Scramble a value. Different methods are employed for different types encountered.
If a method isn't specified, the value is simply omitted entirely.
"""
_scramble_value(val) = nothing
_scramble_value(val::Float64) = first(rand(Float64, 1))
_scramble_value(val::Int64) = first(rand(Int64, 1))
_scramble_value(val::String) = randstring()
_scramble_value(val::Symbol) = randstring()
_scramble_value(val::Array) = _scramble_parameter_value.(val)
# TODO: methods for other SpineInterface parameter types.


"""
    _scramble_parameter_value(val::SpineInterface.ParameterValue)

Scramble the values of a `ParameterValue`.
"""
_scramble_parameter_value(val::SpineInterface.ParameterValue) =
    parameter_value(_scramble_value(val.value))


"""
    scramble_parameter_data!(oc::ObjectClass)

Scrambles all parameter data in an object or relationship class.
Methods are provided for object and relationship classes separately.
"""
function scramble_parameter_data!(oc::ObjectClass)
    # scramble default values
    for (par, val) in oc.parameter_defaults
        oc.parameter_defaults[par] = _scramble_parameter_value(val)
    end
    # scramble actual values
    for (obj, val_dict) in oc.parameter_values
        oc.parameter_values[obj] =
            Dict(param => _scramble_parameter_value(val) for (param, val) in val_dict)
    end
end
function scramble_parameter_data!(rc::SpineInterface.RelationshipClass)
    # scramble default values
    for (par, val) in rc.parameter_defaults
        rc.parameter_defaults[par] = _scramble_parameter_value(val)
    end
    # scramble actual values
    for (rel, val_dict) in rc.parameter_values
        rc.parameter_values[rel] =
            Dict(param => _scramble_parameter_value(val) for (param, val) in val_dict)
    end
end


"""
    _relationship_and_unique_entries(relationship::SpineInterface.RelationshipClass, fields::Symbol)

Gets the unique entries in the `relationship` with the desired `fields`.

Returns a `Pair` with the name of the relationship as a `String`, and the entries in an `Array`.
"""
function _relationship_and_unique_entries(
    relationship::SpineInterface.RelationshipClass,
    fields::Symbol,
)
    entries = unique!(map(entry -> getfield(entry, fields), relationship()))
    return string(relationship) => (fields, entries)
end


"""
    _relationship_and_unique_entries(relationship::SpineInterface.RelationshipClass, fields::NTuple{N Symbol})

Gets the unique entries in the `relationship` with the desired `fields`.

Returns a `Pair` with the name of the relationship as a `String`, and the entries in an `Array`.
"""
function _relationship_and_unique_entries(
    relationship::SpineInterface.RelationshipClass,
    fields::NTuple{N,Symbol},
) where {N}
    entries = unique!(
        map(entry -> Tuple(getfield(entry, field) for field in fields), relationship()),
    )
    return string(relationship) => (fields, entries)
end


"""
    filtered_parameter_values(oc::ObjectClass; kwargs...)

Filters the `parameter_values` field of an `ObjectClass` or a `RelationshipClass`.
Methods for the entitity classes are provided separately.
"""
function filtered_parameter_values(oc::ObjectClass; kwargs...)
    filter!(kw -> kw[1] == oc.name, kwargs)
    Dict(
        key => val_dict for
        (key, val_dict) in oc.parameter_values if key in first(kwargs)[2]
    )
end
function filtered_parameter_values(rc::SpineInterface.RelationshipClass; kwargs...)
    kw_index_map = Dict(kw => findfirst(kw[1] .== rc.object_class_names) for kw in kwargs)
    Dict(
        rel => val_dict for (rel, val_dict) in rc.parameter_values if
        all(rel[i] in kw[2] for (kw, i) in kw_index_map)
    )
end


"""
    filter_entity_class!(oc::ObjectClass; kwargs...)

Filters and `ObjectClass` or a `RelationshipClass` to only contain the desired objects or relationships.
Separate methods for `ObjectClass` and `RelationshipClass`.
"""
function filter_entity_class!(oc::ObjectClass; kwargs...)
    filter!(kw -> kw[1] == oc.name, kwargs)
    filter!(obj -> obj in first(kwargs)[2], oc.objects)
    filter!(pair -> pair[1] in oc.objects, oc.parameter_values)
end
function filter_entity_class!(rc::SpineInterface.RelationshipClass; kwargs...)
    kw_index_map = Dict(kw => findfirst(kw[1] .== rc.object_class_names) for kw in kwargs)
    filter!(rel -> all(rel[i] in kw[2] for (kw, i) in kw_index_map), rc.relationships)
    filter!(pair -> pair[1] in rc.relationships, rc.parameter_values)
end


"""
    _get(oc::ObjectClass, name::Symbol)

Helper function to fetch existing object of class `oc` and create it if missing.
"""
function _get(oc::ObjectClass, name::Symbol)
    !isnothing(oc(name)) ? oc(name) : Object(name, oc.name)
end
function _get(oc::ObjectClass, names::Vector{Symbol})
    [_get(oc, name) for name in names]
end


"""
    _clear_spine_parameters!(
        m::Module,
        ps_to_clear::Vector,
        to_clear::Pair{Symbol,Vector{Symbol}},
        msg::String,
    )

Clear loaded spine parameters to remove reference to classes.
"""
function _clear_spine_parameters!(
    m::Module,
    to_clear::Pair{Symbol,Vector{T}},
    msg::String,
) where {T}
    ps_to_clear = []
    for (p, v) in m._spine_parameters
        setdiff!(v.classes, [getfield(m, to_clear[1])[c] for c in to_clear[2]])
        isempty(v.classes) && push!(ps_to_clear, p)
    end
    filter!(x -> !in(first(x), ps_to_clear), m._spine_parameters)
    _clear_symbols!(m, ps_to_clear, msg)
end


"""
    _clear_symbols!(m::Module, syms_to_clear::Vector, msg::String)

Replace symbols in `m` with a `msg` string.
"""
function _clear_symbols!(m::Module, syms_to_clear::Vector, msg::String)
    for s in syms_to_clear
        @eval m begin
            $s = $msg
            export $s
        end
    end
end


"""
    _add_to_spine!(m::Module, ent::Union{Parameter,RelationshipClass})

Add entity `ent` to Spine.
"""
function _add_to_spine!(m::Module, p::Parameter)
    param = get(m._spine_parameters, p.name, nothing)
    if isnothing(param)
        m._spine_parameters[p.name] = p
    else
        unique!(append!(param.classes, p.classes))
    end
end
function _add_to_spine!(m::Module, rc::RelationshipClass)
    m._spine_relationship_classes[rc.name] => rc
end


"""
    _get_spine_parameter(m::Module, name::Symbol, classes::Vector{T})

Helper function to fetch existing Parameter or create one if missing.
"""
function _get_spine_parameter(m::Module, name::Symbol, classes::Vector{T}) where {T<:Union{ObjectClass,RelationshipClass}}
    get(m._spine_parameters, name, Parameter(name, classes))
end