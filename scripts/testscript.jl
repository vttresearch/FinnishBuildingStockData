#=
    testscript.jl

A sript for running input database tests and other diagnostics on the data.
=#

cd(@__DIR__)
using Pkg
Pkg.activate("testscript")
using Plots
using Statistics

@info "Precompiling"
@time using FinnishBuildingStockData

# Set properties for testing script
m = Module()
number_of_included_municipalities = Inf
scramble_data = false
thermal_conductivity_weight = 0.5
interior_node_depth = 0.1
variation_period = 26.0 * 24 * 60 * 60


## Open database

@info "Opening database"
db_url = "sqlite:///<REDACTED>"
db_out_url = "sqlite:///<REDACTED>"
@time using_spinedb(db_url, m; upgrade = true)


## Run input database tests for structural data

@info "Running structural tests"
@time run_structural_tests(; limit = Inf, mod = m)


## Run input data tests for statistical data

@info "Running statistical tests"
@time run_statistical_tests(; limit = Inf, mod = m)


## Form the `Structure` objects and statistical data

@info "Forming `BuildingStructure` objects"
@time building_structures = FinnishBuildingStockData._form_building_structures(;
    thermal_conductivity_weight = thermal_conductivity_weight,
    interior_node_depth = interior_node_depth,
    variation_period = variation_period,
    mod = m,
);


## Diagnostics of the structure data

if scramble_data
    @warn "`scramble_data` has been set to `true`! Figures are likely to make no sense!"
end

tolerance = 0.1

comparable_building_structures =
    filter(bs -> bs.design_U_value.min > 0, building_structures)
problematic_building_structures = filter(
    bs ->
        (bs.U_value_dict[:total].min - bs.design_U_value.min) / bs.design_U_value.min >=
        tolerance,
    comparable_building_structures,
)
println("\nProblematic structures: $(length(problematic_building_structures))\n")
if !isempty(problematic_building_structures)
    for i = 1:min(length(problematic_building_structures), 3)
        println("$(problematic_building_structures[i])\n")
    end
end

# U-value progression
plt = plot()
for typ in m.structure_type()
    if typ.name in [Symbol("exterior_wall"), Symbol("roof"), Symbol("base_floor")]
        plotarray = map(
            s -> (s.year, s.U_value_dict[:total].min),
            sort!(filter(b -> b.type == typ, building_structures); by = b -> b.year),
        )
        if !isempty(plotarray)
            plot!(map(e -> e[2], plotarray), label = string(typ.name))
        end
    end
end
display(plt)

# Effective thermal mass progression

plt = plot()
for typ in m.structure_type()
    plotarray = map(
        s -> (s.year, s.effective_thermal_mass.min),
        sort!(filter(b -> b.type == typ, building_structures); by = b -> b.year),
    )
    if !isempty(plotarray)
        plot!(map(e -> e[2], plotarray), label = string(typ.name))
    end
end
display(plt)

# Design U-value comparison.
plt3 = plot()
for typ in m.structure_type()
    plotarray = map(
        s -> (
            s.year,
            (s.U_value_dict[:total].min - s.design_U_value.min) / s.design_U_value.min,
        ),
        sort!(filter(b -> b.type == typ, comparable_building_structures); by = b -> b.year),
    )
    if !isempty(plotarray)
        plot!(map(e -> e[2], plotarray), label = string(typ.name))
        plot!(
            fill(mean(getindex.(plotarray, 2)), size(plotarray)),
            label = "$(typ.name) average",
            linestyle = :dash,
        )
    end
end
display(plt3)


## Diagnostics for internal U-values

internal_U_values = hcat(
    [bstr.U_value_dict[:interior].min for bstr in building_structures],
    [bstr.U_value_dict[:interior].loadbearing for bstr in building_structures],
)
sort!(internal_U_values; dims = 1)
display(plot(internal_U_values))


## Create the statistical tables

number_of_included_municipalities =
    Int64(min(number_of_included_municipalities, length(m.location_id.objects)))
@info "Number of included municipalities: $(number_of_included_municipalities)"
lids = m.location_id()[1:number_of_included_municipalities]

@info "Add `building_stock_year` parameter"
@time add_building_stock_year!(m)

@info "Creating building stock statistics"
@time create_building_stock_statistics!(m; location_id = lids)
@info "Creating structural statistics"
@time structure_statistics = create_structure_statistics!(
    m;
    location_id = lids,
    thermal_conductivity_weight = thermal_conductivity_weight,
    interior_node_depth = interior_node_depth,
    variation_period = variation_period,
)
@info "Creating ventilation and fenestration statistics"
@time create_ventilation_and_fenestration_statistics!(m; location_id = lids)


## Filter out unused location_ids

@info "Filtering out unused `location_id`s"
@time filter_entity_class!(m.location_id; location_id = lids)


## Scramble the statistical tables

if scramble_data
    @info "Scrambling statistical tables"
    @time scramble_parameter_data!(building_stock_statistics)
    @time scramble_parameter_data!(structure_statistics)
    @time scramble_parameter_data!(ventilation_and_fenestration_statistics)
end


## Try writing into the output db_url

#=
@info "Writing output into the final DB"
@time import_data(db_out_url, building_stock_statistics, "Import `building_stock_statistics`")
@time import_data(db_out_url, structure_statistics, "Import `structure_statistics`")
@time import_data(
    db_out_url, ventilation_and_fenestration_statistics, "Import `ventilation_and_fenestration_statistics`"
)
=#


## Plot detailed structures vs statistical data diagnostics

for bt in m.building_type()
    for st in m.structure_type()
        if m.structure_type.parameter_values[st][:is_load_bearing].value
            property = :loadbearing
        else
            property = :min
        end
        structure_parameters = sort!([
            (
                year = structure.year,
                design_U_value = getfield(structure.design_U_value, property),
                total_U_value = getfield(structure.U_value_dict[:total], property),
            ) for structure in
            filter(s -> st == s.type && bt in s.building_types, building_structures)
        ])
        data_parameters = sort!([
            (
                year = m.period_end(building_period = bp),
                design_U_value = m.structure_statistics.parameter_values[(
                    bt,
                    bp,
                    lid,
                    st,
                )][:design_U_value_W_m2K].value,
                total_U_value = m.structure_statistics.parameter_values[(
                    bt,
                    bp,
                    lid,
                    st,
                )][:total_U_value_W_m2K].value,
            ) for bp in m.building_period() for lid in m.location_id()
        ])
        plt = scatter(
            getfield.(structure_parameters, :year),
            getfield.(structure_parameters, :design_U_value),
            title = "$(bt), $(st)",
            label = "Structure desing U-value W/m2K",
            legend = :topleft,
            markersize = 8,
            markerstrokewidth = 0,
        )
        plt = scatter!(
            getfield.(structure_parameters, :year),
            getfield.(structure_parameters, :total_U_value),
            label = "Structure total U-value W/m2K",
            markerstrokewidth = 0,
        )
        plt = scatter!(
            getfield.(data_parameters, :year),
            getfield.(data_parameters, :design_U_value),
            label = "Statistical design U-value W/m2K",
            markersize = 8,
            markerstrokewidth = 0,
        )
        plt = scatter!(
            getfield.(data_parameters, :year),
            getfield.(data_parameters, :total_U_value),
            label = "Statistical total U-value W/m2K",
            markerstrokewidth = 0,
        )
        display(plt)
    end
end


## Diagnostics for the fenestration and ventilation data

sorted_rels = [
    tuple(rel...) for rel in sort(
        m.ventilation_and_fenestration_statistics.relationships;
        by = x -> x.building_period,
    )
]
data_parameters = [
    (
        year = m.period_end(building_period = rel[2]),
        window_U_value = m.ventilation_and_fenestration_statistics.parameter_values[rel][:window_U_value_W_m2K].value,
        infiltration_rate = m.ventilation_and_fenestration_statistics.parameter_values[rel][:infiltration_rate_1_h].value,
        ventilation_rate = m.ventilation_and_fenestration_statistics.parameter_values[rel][:ventilation_rate_1_h].value,
        HRU_efficiency = m.ventilation_and_fenestration_statistics.parameter_values[rel][:HRU_efficiency].value,
        solar_transmittance = m.ventilation_and_fenestration_statistics.parameter_values[rel][:total_normal_solar_energy_transmittance].value,
    ) for rel in sorted_rels
]
plt = scatter(; title = "Ventilation and fenestration properties")
plot_settings = [
    (field = :window_U_value, legend = "Window U-value W/m2K"),
    (field = :solar_transmittance, legend = "Total normal solar energy transmittance"),
    (field = :infiltration_rate, legend = "Infiltration rate 1/h"),
    (field = :ventilation_rate, legend = "Ventilation rate 1/h"),
    (field = :HRU_efficiency, legend = "Heat recovery unit efficiency"),
]
for (field, legend) in plot_settings
    plt = scatter!(
        getfield.(data_parameters, :year),
        getfield.(data_parameters, field),
        label = legend,
        legend = :topleft,
        markersize = 4,
        markerstrokewidth = 0,
    )
end
display(plt)
