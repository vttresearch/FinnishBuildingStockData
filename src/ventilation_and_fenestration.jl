#=
    ventilation_and_fenestration.jl

This file contains functions for calculating ventilation and fenestration properties.
=#

"""
    _filter_relevant_sources(
        building_period::Object,
        relationship_class::SpineInterface.RelationshipClass;
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20;
        mod::Module = @__MODULE__
    )

Finds the `source`s matching the provided `building_period` for the desired `relationship_class`.

If nothing is found, relaxes the `building_period` start by `lookback_if_empty`,
and tries again until `max_lookbacks` is reached.
The `mod` keyword defines the Module from which the data is accessed.
"""
function _filter_relevant_sources(
    building_period::Object,
    relationship_class::SpineInterface.RelationshipClass;
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    unique_sources = unique(getfield.(relationship_class(), :source))
    relevant_sources = Array{Object,1}()
    n = 0
    while isempty(relevant_sources) && n < max_lookbacks
        relevant_sources = filter(
            src ->
                mod.period_start(building_period=building_period) -
                n * lookback_if_empty <= mod.source_year(source=src) &&
                    mod.source_year(source=src) <=
                    mod.period_end(building_period=building_period),
            unique_sources,
        )
        n += 1
    end
    if isempty(relevant_sources)
        @error "No relevant sources can be found for `$(building_period)` and `$(relationship_class)`."
    else
        return relevant_sources
    end
end


"""
    mean_ventilation_rate(
        building_period::Object,
        building_type::Object;
        weight::Float64=0.5,
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = @__MODULE__
    )

Calculate the mean ventilation rate [1/h] for a `(building_period, building_type)` based on relevant raw data.

The `weight` keyword can be used to tweak how the ventilation rate is sampled:
0 uses the `min_ventilation_rate_1_h`, and 1 uses the `max_ventilation_rate_1_h`.
The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.
The `mod` keyword defines the Module from which the data is accessed.

Essentially, this function performs the following steps:
1. Filter out irrelevant `source`s using [`_filter_relevant_sources`](@ref).
2. Calculate the mean ventilation rate [1/h] across the relevant sources as:

```math
r_{\\text{ven,mean}} = \\frac{\\sum_{s \\in \\text{relevant sources}} w r_{\\text{ven,max,s}} + (1-w) r_{\\text{ven,min,s}}}{\\sum_{s \\in \\text{relevant sources}} 1} 
```
"""
function mean_ventilation_rate(
    building_period::Object,
    building_type::Object;
    weight::Float64=0.5,
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    0 <= weight <= 1 ? nothing : @error "`weight` must be between 0 and 1!"
    relevant_sources = _filter_relevant_sources(
        building_period,
        mod.ventilation_source__building_type;
        lookback_if_empty=lookback_if_empty,
        max_lookbacks=max_lookbacks,
        mod=mod
    )
    rels = mod.ventilation_source__building_type(
        source=relevant_sources,
        building_type=building_type;
        _compact=false
    )
    return sum(
        weight * mod.max_ventilation_rate_1_h(source=src, building_type=bt) +
        (1 - weight) * mod.min_ventilation_rate_1_h(source=src, building_type=bt) for
        (src, bt) in rels
    ) / length(rels)
end


"""
    mean_infiltration_rate(
        building_period::Object,
        building_type::Object;
        n50_weight::Float64=0.5,
        factor_weight::Float64=0.5,
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = @__MODULE__,
    )

Calculate the mean infiltration rate [1/h] for a `(building_period, building_type)` based on relevant raw data.

The `weight` keywords can be used to tweak how the infiltration rate and infiltration factor are sampled:
0 uses the minimum, and 1 uses the maximum parameter values.
The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.
The `mod` keyword defines the Module from which the data is accessed.

**NOTE!** The calculation of the infiltration factor is based on the convention
in the Finnish building code. The convention uses a *n50* infiltration rate
corrected using an *infiltration factor* accounting for the typical number of
storeys in the building type in question.

Essentially, this function performs the following steps:
1. Filter out irrelevant `source`s using [`_filter_relevant_sources`](@ref).
2. Calculate the mean infiltration rate [1/h] across the relevant sources as:

```math
r_{\\text{inf,mean}} = \\frac{\\sum_{s \\in \\text{relevant sources}} w_{\\text{n50}} r_{\\text{inf,max,s}} + (1-w_{\\text{n50}}) r_{\\text{inf,min,s}}}{\\sum_{s \\in \\text{relevant sources}} \\left[ w_{\\text{factor}} F_{\\text{max}} + (1-w_{\\text{factor}}) F_{\\text{min}} \\right] \\sum_{s \\in \\text{relevant sources}} 1} 
```
"""
function mean_infiltration_rate(
    building_period::Object,
    building_type::Object;
    n50_weight::Float64=0.5,
    factor_weight::Float64=0.5,
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    0 <= n50_weight <= 1 ? nothing : @error "`n50_weight` must be between 0 and 1!"
    0 <= factor_weight <= 1 ? nothing : @error "`factor_weight` must be between 0 and 1!"
    relevant_sources = _filter_relevant_sources(
        building_period,
        mod.ventilation_source__building_type;
        lookback_if_empty=lookback_if_empty,
        max_lookbacks=max_lookbacks,
        mod=mod
    )
    rels = mod.ventilation_source__building_type(
        source=relevant_sources,
        building_type=building_type;
        _compact=false
    )
    return sum(
        (
            n50_weight *
            mod.max_n50_infiltration_rate_1_h(source=src, building_type=bt) +
            (1 - n50_weight) *
            mod.min_n50_infiltration_rate_1_h(source=src, building_type=bt)
        ) / (
            factor_weight * mod.max_infiltration_factor(source=src, building_type=bt) +
            (1 - factor_weight) *
            mod.min_infiltration_factor(source=src, building_type=bt)
        ) for (src, bt) in rels
    ) / length(rels)
end


"""
    mean_hru_efficiency(
        building_period::Object,
        building_type::Object;
        weight::Float64=0.5,
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = @__MODULE__,
    )

Calculate the mean Heat Recovery Unit (HRU) efficiency for a `(building_period, building_type)` based on relevant raw data.

The `weight` keyword can be used to tweak how the HRU efficiency is sampled:
0 uses the `min_HRU_efficiency`, and 1 uses the `max_HRU_efficiency`.
The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.
The `mod` keyword defines the Module from which the data is accessed.

Essentially, this function performs the following steps:
1. Filter out irrelevant `source`s using [`_filter_relevant_sources`](@ref).
2. Calculate the mean HRU efficiency across the relevant sources as:

```math
\\eta_{\\text{mean}} = \\frac{\\sum_{s \\in \\text{relevant sources}} w \\eta_{\\text{max,s}} + (1-w) \\eta_{\\text{min,s}}}{\\sum_{s \\in \\text{relevant sources}} 1} 
```
"""
function mean_hru_efficiency(
    building_period::Object,
    building_type::Object;
    weight::Float64=0.5,
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    0 <= weight <= 1 ? nothing : @error "`weight` must be between 0 and 1!"
    relevant_sources = _filter_relevant_sources(
        building_period,
        mod.ventilation_source__building_type;
        lookback_if_empty=lookback_if_empty,
        max_lookbacks=max_lookbacks,
        mod=mod
    )
    rels = mod.ventilation_source__building_type(
        source=relevant_sources,
        building_type=building_type;
        _compact=false
    )
    return sum(
        weight * mod.max_HRU_efficiency(source=src, building_type=bt) +
        (1 - weight) * mod.min_HRU_efficiency(source=src, building_type=bt) for
        (src, bt) in rels
    ) / length(rels)
end


"""
    mean_window_U_value(
        building_period::Object,
        building_type::Object;
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = @__MODULE__,
    )

Calculate the mean window U-value [W/m2K] for a `(building_period, building_type)` based on relevant raw data.

The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.
The `mod` keyword defines the Module from which the data is accessed.

Essentially, this function performs the following steps:
1. Filter out irrelevant `source`s using [`_filter_relevant_sources`](@ref).
2. Calculate the mean window U-value [W/m2K] across the relevant sources as:

```math
U_{\\text{mean}} = \\frac{\\sum_{s \\in \\text{relevant sources}} U_{\\text{max,s}} + U_{\\text{min,s}}}{2 \\sum_{s \\in \\text{relevant sources}} 1} 
```
"""
function mean_window_U_value(
    building_period::Object,
    building_type::Object;
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    relevant_sources = _filter_relevant_sources(
        building_period,
        mod.fenestration_source__building_type;
        lookback_if_empty=lookback_if_empty,
        max_lookbacks=max_lookbacks,
        mod=mod
    )
    rels = mod.fenestration_source__building_type(
        source=relevant_sources,
        building_type=building_type;
        _compact=false
    )
    return sum(mod.U_value_W_m2K(source=src, building_type=bt) for (src, bt) in rels) /
           length(rels)
end


"""
    mean_total_normal_solar_energy_transmittance(
        building_period::Object,
        building_type::Object;
        lookback_if_empty::Int64 = 10,
        max_lookbacks::Int64 = 20,
        mod::Module = @__MODULE__,
    )

Calculate the mean total normal solar energy transmittance for a `(building_period, building_type)` based on raw data.
In this case, "total" means that both the properties of glazing and window frames are accounted for,
while "normal" means that this value is strictly applicable only to solar radiation directly perpendicular to the window.

The `lookback` keywords control how historical data is backtracked if no data is found for a `building_period`.
The `mod` keyword defines the Module from which the data is accessed.

Essentially, this function performs the following steps:
1. Filter out irrelevant `source`s using [`_filter_relevant_sources`](@ref).
2. Calculate the mean total normal solar energy transmittance of the windows across the relevant sources accounting for the frame area fraction as:

```math
g_{\\text{mean}} = \\frac{\\sum_{s \\in \\text{relevant sources}} (1-f) g}{\\sum_{s \\in \\text{relevant sources}} 1} 
```
"""
function mean_total_normal_solar_energy_transmittance(
    building_period::Object,
    building_type::Object;
    lookback_if_empty::Int64=10,
    max_lookbacks::Int64=20,
    mod::Module=@__MODULE__
)
    relevant_sources = _filter_relevant_sources(
        building_period,
        mod.fenestration_source__building_type;
        lookback_if_empty=lookback_if_empty,
        max_lookbacks=max_lookbacks,
        mod=mod
    )
    rels = mod.fenestration_source__building_type(
        source=relevant_sources,
        building_type=building_type;
        _compact=false
    )
    return sum(
        (1 - mod.frame_area_fraction(source=src, building_type=bt)) *
        mod.solar_energy_transmittance(source=src, building_type=bt) for
        (src, bt) in rels
    ) / length(rels)
end
