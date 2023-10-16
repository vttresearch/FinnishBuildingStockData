#=
    util.jl

Contains miscellaneous utility functions and extensions to other modules.
=#

## Extend Base where necessary

Base.String(x::Int64) = String(string(x))


## Extend SpineInterface where necessary

SpineInterface.parameter_value(x::String31) = parameter_value(String(x))
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
SpineInterface.parse_db_value(value_and_type::Tuple) = parse_db_value(value_and_type...)


## Miscellaneous functions

"""
    merge_data!(rsd1::RawSpineData, rsds::RawSpineData ...)

Helper function for merging [`FinnishBuildingStockData.RawSpineData`](@ref).
"""
function merge_data!(rsd1::RawSpineData, rsds::RawSpineData...)
    # Define which indices are used to deduce unique entries.
    unique_inds_mapping = Dict(
        :object_classes => 1:1,
        :objects => 1:2,
        :object_parameters => 1:2,
        :object_parameter_values => 1:3,
        :relationship_classes => 1:1,
        :relationships => 1:2,
        :relationship_parameters => 1:2,
        :relationship_parameter_values => 1:3,
        :alternatives => 1:1,
        :parameter_value_lists => 1:2
    )
    # Loop over the fields of the datasets, combine, and remove duplicates.
    for rsd in rsds
        for fn in fieldnames(RawSpineData)
            inds = unique_inds_mapping[fn]
            data = sort!(append!(getfield(rsd1, fn), getfield(rsd, fn)), by=r -> r[inds])
            inds_to_pop = []
            for (i, (row1, row2)) in Iterators.reverse(enumerate(zip(data[2:end], data[1:end-1])))
                row1[inds] == row2[inds] ? push!(inds_to_pop, i) : nothing
            end
            if !isempty(inds_to_pop)
                for i in inds_to_pop
                    popat!(data, i)
                end
            end
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
    m._spine_relationship_classes[rc.name] = rc
end


"""
    _get_spine_parameter(m::Module, name::Symbol, classes::Vector{T})

Helper function to fetch existing Parameter or create one if missing.
"""
function _get_spine_parameter(m::Module, name::Symbol, classes::Vector{T}) where {T<:Union{ObjectClass,RelationshipClass}}
    get(m._spine_parameters, name, Parameter(name, classes))
end


"""
    _get_spine_relclass(m::Module, name::Symbol, objclss::Vector{Symbol})

Helper function to fetch existing RelationshipClass or create one if missing.
"""
function _get_spine_relclass(m::Module, name::Symbol, objclss::Vector{Symbol})
    get(
        m._spine_relationship_classes,
        name,
        RelationshipClass(name, objclss, Vector{RelationshipLike}())
    )
end


"""
    _parse_db_values!(raw::Dict)

Parse exported database values into something manageable.
"""
function _parse_db_values!(raw::Dict)
    to_parse = Dict(
        "object_parameters" => 3,
        "relationship_parameters" => 3,
        "relationship_parameter_values" => 4,
        "object_parameter_values" => 4,
        "parameter_value_lists" => 2
    )
    for (key, ind) in to_parse
        data = get(raw, key, nothing)
        if !isnothing(data)
            map(r -> setindex!(r, parse_db_value(r[ind]), ind), data)
        end
    end
    return raw
end


"""
    to_dict()
"""
function to_dict(obj_cls::ObjectClass)
    Dict(
        "object_classes" => [[String(obj_cls.name)]],
        "object_parameters" => [
            [String(obj_cls.name), String(parameter_name), unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in obj_cls.parameter_defaults
        ],
        "objects" => [String.([obj_cls.name, object.name]) for object in obj_cls.objects],
        "object_parameter_values" => [
            [String(obj_cls.name), String(object.name), String(parameter_name), unparse_db_value(parameter_value)]
            for (object, parameter_values) in obj_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
function to_dict(rel_cls::RelationshipClass)
    Dict(
        "object_classes" => [[String(oc)] for oc in unique(rel_cls.intact_object_class_names)],
        "objects" => unique(
            String.([obj_cls_name, obj.name])
            for relationship in rel_cls.relationships
            for (obj_cls_name, obj) in zip(rel_cls.intact_object_class_names, relationship)
        ),
        "relationship_classes" => [[String(rel_cls.name), String.(rel_cls.intact_object_class_names)]],
        "relationship_parameters" => [
            [String(rel_cls.name), String(parameter_name), unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in rel_cls.parameter_defaults
        ],
        "relationships" => [
            [String(rel_cls.name), [String(obj.name) for obj in relationship]] for relationship in rel_cls.relationships
        ],
        "relationship_parameter_values" => [
            [String(rel_cls.name), [String(obj.name) for obj in relationship], String(parameter_name), unparse_db_value(parameter_value)]
            for (relationship, parameter_values) in rel_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end