# Output data format

The goal of the `FinnishBuildingStockData.jl` module is to combine data about
building structures, fenestration, and ventilation with building stock statistics,
resulting in building stock statistics containing aggregate structural properties.
The previous [Data processing overview](@ref) explains the steps done to the
input data described in the [Required input data format](@ref)
in order to arrive at the desired output.

This module uses a *Spine Datastore* for recording the output.
See the [Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox) repository
for more information on the subject.
In a *Spine Datastore*, the data is organized into *object classes* storing data for individual *objects*,
and *relationship classes* storing data for relationships between multiple *objects*.
Below, you'll find lists of all the [Output object classes](@ref) and
[Output relationship classes](@ref) produced by the `FinnishBuildingStockData.jl` module,
as well as brief explanations of their purpose, use, and contained parameters.


## Output object classes

Note that there is a lot of overlap between these and the [Input object classes](@ref).

>`building_period`: Represents a period in time, during which a building was built.
- `period_start`: The year when the `building_period` starts.
- `period_end`: The year when the `building_period` ends.

>`building_stock`: Represents a snapshot of a building stock, e.g. Finnish building stock in the year 2030. Used to separate e.g. different countries and years of building stock data.
- `building_stock_year`: Indicates the year this `building_stock` represents, e.g. 2020, 2030, etc.
- `raster_weight_path`: An optional filepath to a geographical raster data file containing weighting information for the weather data, e.g. population density or the like.
- `shapefile_path`: A Filepath to a shapefile containing the geographical information about the building stock.

>`building_type`: Represents a certain category of buildings, e.g. detached house, apartment block, office building, etc. Used to distinguish between different buildings found in the building stock statistics.

>`heat_source`: Represents a source of heat energy for a building, e.g. coal or electricity. Used to distinguish between different heating solutions in the building stock statistics.

>`location_id`: A unique identifier for a geographical location, e.g. a national municipality code.
- `location_name`: The name of the location in question, e.g. the name of the municipality.

>`structure_type`: Represents a category of building structures, e.g. exterior walls, base floors, roofs, etc. Used for storing common properties, like surface resistances and thermal bridges.
- `exterior_resistance_m2K_W`: Exterior surface resistance for this `structure_type` in [m2K/W].
- `interior_resistance_m2K_W`: Interior surface resistance for this `structure_type` in [m2K/W].
- `is_internal`: A boolean flag for whether a structure is an internal structure, meaning not part of the building envelope. Set to `true` for partition walls and separating floors.
- `linear_thermal_bridge_W_mK`: Assumed linear thermal bridge properties for this `structure_type`.
- `structure_type_notes`: Freeform notes about the structure type, or its assumed parameters.


## Output relationship classes

>`building_stock_statistics`: The final building stock statistics containing the number of buildings and average gross-floor area per building for each `(building_stock, building_type, building_period, location_id, heat_source)`, created using the [`create_building_stock_statistics`](@ref) function.
- `average_gross_floor_area_m2_per_building`: The average gross-floor area in [m2] of buildings of `building_type`, built during `building_period` in `location_id`, heated using `heat_source` of the `building_stock` dataset.
- `number_of_buildings`: The number of buildings of `building_type`, built during `building_period` in `location_id`, heated using `heat_source` of the `building_stock` dataset.

>`structure_statistics`: The processed average structural properties for each `(building_type, building_period, location_id, structure_type)`, created using the [`create_structure_statistics`](@ref) function.
- `design_U_W_m2K`: The average design U-value of the aggregated structures in [W/m2K].
- `effective_thermal_mass_J_m2K`: Mean calculated effective thermal mass [J/m2K] of the structures corresponding to the statistics, per area of the structure.
- `external_U_value_to_ambient_air_W_m2K`: Mean calculated U-value [W/m2K] from the structure into the ambient air.
- `external_U_value_to_ground_W_m2K`: Mean calculated effective U-value [W/m2K] from the structure into the ground, according to *Kissock, Kelly, Abinesh Selvacanabady, and Narendran Raghavan. "Simplified Model for Ground Heat Transfer from Slab-on-Grade Buildings." ASHRAE Transactions 119.2 (2013)*.
- `internal_U_value_to_structure_W_m2K`: Mean calculated U-value [W/m2K] from the structure into the interior air.
- `linear_thermal_bridges_W_mK`: Mean linear thermal bridges [W/mK] of the seams between structures.
- `total_U_value_W_m2K`: Mean total effective U-value [W/m2K] of the structure, from the interior air into the ambient air/ground.

>`ventilation_and_fenestration_statistics`: The processed averate ventilation and fenestration properties for each `(building_type, building_period, location_id)`.
- `HRU_efficiency`: Mean heat-recovery efficiency of ventilation heat-recovery units.
- `infiltration_rate_1_h`: Mean infiltration air change rate [1/h].
- `total_normal_solar_energy_transmittance`: Mean total normal solar energy transmittance of windows accounting for the effect of the frame-area fraction.
- `ventilation_rate_1_h`: Mean ventilation air change rate [1/h].
- `window_U_value_W_m2K`: Mean window U-value [W/m2K].