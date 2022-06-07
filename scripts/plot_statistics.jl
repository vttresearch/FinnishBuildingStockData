#=
    plot_statistics.jl

A script for calculating and plotting some Finland-wide statistics.
=#

cd(@__DIR__)
using Pkg
Pkg.activate("testscript")
using Plots

@info "Precompiling"
@time using FinnishBuildingStockData


## Define and open the Finnish building stock Datastore

db_url = "sqlite:///<REDACTED>"
@info "Opening datastore at `$(db_url)`"
@time using_spinedb(db_url, Main; upgrade = true)


## Calculate mappings and statistics

# Determine new relationships and map `building_periods` per `building_stock`
building_periods_for_building_stock = Dict(
    bs => unique(
        getfield.(building_stock_statistics(building_stock = bs), :building_period),
    ) for bs in building_stock()
)
new_rels = unique(
    (building_stock = bs, building_type = bt, heat_source = hs) for
    (bs, bt, bp, lid, hs) in building_stock_statistics()
)

# Calculate national gross-floor areas by summing over `location_id`
# Store an array in building period order.
national_gross_floor_areas_m2 = Dict(
    (building_stock = bs, building_type = bt, heat_source = hs) => [
        sum(
            average_gross_floor_area_m2_per_building(
                building_stock = bs,
                building_type = bt,
                building_period = bp,
                location_id = lid,
                heat_source = hs,
            ) * number_of_buildings(
                building_stock = bs,
                building_type = bt,
                building_period = bp,
                location_id = lid,
                heat_source = hs,
            ) for lid in location_id()
        ) for bp in building_periods_for_building_stock[bs]
    ] for (bs, bt, hs) in new_rels
)

# Totals over the building_periods
total_gross_floor_areas_m2 = Dict(
    keys(national_gross_floor_areas_m2) .=> sum.(values(national_gross_floor_areas_m2)),
)

# Remove uninteresting heat sources, as they have no data
filtered_heat_sources =
    [hs for hs in heat_source() if hs.name != :coal && hs.name != :heavy_oil]


## Plot the statistics in different ways

# Set color palettes and other plot settings
hs_palette = :Accent_8  # Color palette for heat source plots
bt_palette = :Dark2_6   # Color paletter for building type plots
xrot = 45               # Rotation angle of x-axis labels

# Start plotting, initialize dict
plot_dict = Dict()

# Plot total GFA per heat source for building stock years.
vals =
    1e-6 .* hcat(
        [
            [
                sum(
                    total_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for bt in building_type()
                ) for bs in building_stock()
            ] for hs in filtered_heat_sources
        ]...,
    )
plot_dict[:total_stock_heat_sources] = bar(
    string.(building_stock()),
    reverse(cumsum(vals; dims = 2); dims = 2);
    title = "Total GFA by building stock and heat source",
    xlabel = "Building stock",
    ylabel = "Total gross-floor area [Mm2]",
    label = reshape(
        reverse(string.(filtered_heat_sources)),
        1,
        length(filtered_heat_sources),
    ),
    legend = :topleft,
    foreground_color_legend = nothing,
    background_color_legend = nothing,
    palette = hs_palette,
)
display(plot_dict[:total_stock_heat_sources])

# Plot total GFA per building type for building stock years.
vals =
    1e-6 .* hcat(
        [
            [
                sum(
                    total_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for hs in filtered_heat_sources
                ) for bs in building_stock()
            ] for bt in building_type()
        ]...,
    )
plot_dict[:total_stock_building_types] = bar(
    string.(building_stock()),
    reverse(cumsum(vals; dims = 2); dims = 2);
    title = "Total GFA by building stock and building_type",
    xlabel = "Building stock",
    ylabel = "Total gross-floor area [Mm2]",
    label = reshape(reverse(string.(building_type())), 1, length(building_type())),
    legend = :topleft,
    foreground_color_legend = nothing,
    background_color_legend = nothing,
    palette = bt_palette,
)
display(plot_dict[:total_stock_building_types])

# Plot stuff for each building stock.
for bs in building_stock()
    plot_dict[bs] = Dict()
    filtered_gfa_m2 =
        filter(pair -> pair[1].building_stock == bs, national_gross_floor_areas_m2)
    # Plot total gross-floor area per heat source.
    local vals =
        1e-6 .* hcat(
            [
                sum(
                    national_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for bt in building_type()
                ) for hs in filtered_heat_sources
            ]...,
        )
    plot_dict[bs][:total_heat_sources] = bar(
        string.(building_periods_for_building_stock[bs]),
        reverse(cumsum(vals; dims = 2); dims = 2);
        title = "`$(bs)`: Total GFA by period and heat source",
        xlabel = "Building period",
        ylabel = "Total gross-floor area [Mm2]",
        label = reshape(
            reverse(string.(filtered_heat_sources)),
            1,
            length(filtered_heat_sources),
        ),
        xrotation = xrot,
        legend = :topleft,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
        palette = hs_palette,
    )
    display(plot_dict[bs][:total_heat_sources])
    # Plot total gross-floor area per building type.
    local vals =
        1e-6 .* hcat(
            [
                sum(
                    national_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for hs in filtered_heat_sources
                ) for bt in building_type()
            ]...,
        )
    plot_dict[bs][:total_building_types] = bar(
        string.(building_periods_for_building_stock[bs]),
        reverse(cumsum(vals; dims = 2); dims = 2);
        title = "`$(bs)`: Total GFA by period and building type",
        xlabel = "Building period",
        ylabel = "Total gross-floor area [Mm2]",
        label = reshape(reverse(string.(building_type())), 1, length(building_type())),
        xrotation = xrot,
        legend = :topleft,
        foreground_color_legend = nothing,
        background_color_legend = nothing,
        palette = bt_palette,
    )
    display(plot_dict[bs][:total_building_types])
    # Plot heat source distributions for each building type.
    for bt in building_type()
        local vals =
            1e-6 .* hcat(
                [
                    national_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for hs in filtered_heat_sources
                ]...,
            )
        plot_dict[bs][bt] = bar(
            string.(building_periods_for_building_stock[bs]),
            reverse(cumsum(vals; dims = 2); dims = 2);
            title = "`$(bs)`: GFA for `$(bt)`\nby period and heat source",
            xlabel = "Building period",
            ylabel = "Total gross-floor area Mm2",
            label = reshape(
                reverse(string.(filtered_heat_sources)),
                1,
                length(filtered_heat_sources),
            ),
            xrotation = xrot,
            legend = :topleft,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
            palette = hs_palette,
        )
        display(plot_dict[bs][bt])
    end
    # Plot building type distributions for each heat source.
    for hs in filtered_heat_sources
        local vals =
            1e-6 .* hcat(
                [
                    national_gross_floor_areas_m2[(
                        building_stock = bs,
                        building_type = bt,
                        heat_source = hs,
                    )] for bt in building_type()
                ]...,
            )
        plot_dict[bs][hs] = bar(
            string.(building_periods_for_building_stock[bs]),
            reverse(cumsum(vals; dims = 2); dims = 2);
            title = "`$(bs)`: GFA for `$(hs)`\nby period and building type",
            xlabel = "Building period",
            ylabel = "Total gross-floor area Mm2",
            label = reshape(reverse(string.(building_type())), 1, length(building_type())),
            xrotation = xrot,
            legend = :topleft,
            foreground_color_legend = nothing,
            background_color_legend = nothing,
            palette = bt_palette,
        )
        display(plot_dict[bs][hs])
    end
end


## Save plotted figures.

for (bs, plts) in plot_dict
    if plts isa Plots.Plot
        savefig(plts, "figs/$(string(bs)).png")
    else
        for (name, plt) in plts
            savefig(plt, "figs/$(string(bs))_$(string(name)).png")
        end
    end
end
