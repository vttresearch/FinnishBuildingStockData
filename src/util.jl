#=
    util.jl

Contains miscellaneous utility functions.
=#

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
    _scramble_parameter_value(val::AbstractParameterValue)

Scramble the values of a parameter. Different methods employed for different types of `AbstractParameterValue`.
"""
_scramble_parameter_value(val::AbstractParameterValue) =
    parameter_value(_scramble_value(val.value))
_scramble_parameter_value(val::SpineInterface.NothingParameterValue) =
    parameter_value(nothing)


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
