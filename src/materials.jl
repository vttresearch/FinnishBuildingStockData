#=
    materials.jl

This file contains functions related to processing the materials data.
Mostly auxiliary stuff used in `structural.jl`.
=#

"""
    density(material::Object; mod::Module = @__MODULE__)

Return the average density of the material in [kg/m3].

Calculated as a simple average based on the `minimum_density_kg_m3` and
`maximum_density_kg_m3` parameters in the input data as
```math
\\rho_{\\text{mean}} = \\frac{\\rho_{\\text{min}} + \\rho_{\\text{max}}}{2}
```
The `mod` keyword is used to tweak the Module from which the parameters are read.
"""
function density(material::Object; mod::Module=@__MODULE__)
    Float64(
        mod.maximum_density_kg_m3(structure_material=material) +
        mod.minimum_density_kg_m3(structure_material=material),
    ) / 2.0
end


"""
    specific_heat_capacity(material::Object; mod::Module = @__MODULE__)

Return the average specific heat capacity of the material in [J/kgK].

Calculated as a simple average based on the `minimum_specific_heat_capacity_J_kgK`
and `maximum_specific_heat_capacity_J_kgK` parameters in the input data as
```math
c_{\\text{mean}} = \\frac{c_{\\text{min}} + c_{\\text{max}}}{2}
```
The `mod` keyword is used to tweak the Module from which the parameters are read.
"""
function specific_heat_capacity(material::Object; mod::Module=@__MODULE__)
    Float64(
        mod.maximum_specific_heat_capacity_J_kgK(structure_material=material) +
        mod.minimum_specific_heat_capacity_J_kgK(structure_material=material),
    ) / 2.0
end


"""
    thermal_conductivity(
        material::Object;
        weight::Float64 = 0.5,
        mod::Module = @__MODULE__
    )

Return the average thermal conductivity of the material in [W/mK].

Calculated as a weighted average based on the `minimum_thermal_conductivity_W_mK`
and `maximum_thermal_conductivity_W_mK` parameters in the input data,
where the `0 <= weight <= 1` can be used to tweak the calculation.
```math
\\lambda_{\\text{weighted}} = w \\lambda_{\\text{max}} + (1-w) \\lambda_{\\text{min}}
```
The `mod` keyword is used to tweak the Module from which the parameters are read.
"""
function thermal_conductivity(
    material::Object;
    weight::Float64=0.5,
    mod::Module=@__MODULE__
)
    0 <= weight <= 1 ? nothing : @error "`weight` must be between 0 and 1!"
    Float64(
        weight * mod.maximum_thermal_conductivity_W_mK(structure_material=material) +
        (1 - weight) * mod.minimum_thermal_conductivity_W_mK(structure_material=material),
    )
end
