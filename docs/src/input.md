# Required input data format

This module uses a *Spine Datastore* for storing and accessing the input data.
See the [Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox) repository
for more information on the subject.
In a *Spine Datastore*, the data is organized into *object classes* storing data for individual *objects*, and
*relationship classes* storing data for relationships between multiple *objects*.

Essentially, the first step of actually using this module is to import the input data into a *Spine Datastore*, explained in the *README.md* files of the input data repositories.
Below, you'll find lists of all the [Input object classes](@ref) and
[Input relationship classes](@ref) required by the `FinnishBuildingStockData.jl` module,
as well as brief explanations of their purpose, use, and contained parameters.


## Input object classes

>`building_period`: Represents a period in time, during which a building was built. Used to connect structures, fenestration, and ventilation properties to building statistics.
- `period_start`: The year when the `building_period` starts.
- `period_end`: The year when the `building_period` ends.

>`building_stock`: Represents a snapshot of a building stock, e.g. Finnish building stock in the year 2030. Used to separate e.g. different countries and years of building stock data.
- TODO: Currently needs to be named `<NAME>_<YEAR>`, as the year the `building_stock` represents is later parsed from the name.

>`building_type`: Represents a certain category of buildings, e.g. detached house, apartment block, office building, etc. Used to distinguish between different buildings found in the building stock statistics.

>`frame_material`: Represents a load-bearing material used in building frames. Used to weight different structures depending on the frame material share data when calculating the aggregated structural properties.

>`heat_source`: Represents a source of heat energy for a building, e.g. coal or electricity. Used to distinguish between different heating solutions in the building stock statistics.

>`layer_id`: A unique identifier for a structural layer in the raw structural data.

>`location_id`: A unique identifier for a geographical location, e.g. a national municipality code.
- `location_name`: The name of the location in question, e.g. the name of the municipality.

>`source`: Represents a source of structural, fenestration, or ventilation data in the raw input. Mainly used to deduce when the structural/fenestration/ventilation properties are relevant.
- `source_description`: Briefly describes the `source`, e.g. which document the raw input data is obtained from, or what that document is.
- `source_year`: Tells which year the `source` is supposed to represent, e.g. 1960 for parameters assumed valid from 1960s onwards.

>`structure`: Represents a building structure. Unfortunately, due to non-unique structural identifiers in the Finnish raw data, actual unique structures are represented as `(source,structure)` pairs.

>`structure_material`: Represents a certain construction material, e.g. wood or mineral wool. Used to store the properties of the construction materials for the structural proerty calculations.
- `material_nodes`: Freeform notes about the material data.
- `maximum_density_kg_m3`: Maximum density of the material found in literature in [kg/m3].
- `maximum_specific_heat_capacity_J_kgK`: Maximum specific heat capacity of the material found in literature in [J/kgK].
- `maximum_thermal_conductivity_W_mK`: Maximum thermal conductivity of the material found in literature in [W/mK].
- `minimum_density_kg_m3`: Minimum density of the material found in literature in [kg/m3].
- `minimum_specific_heat_capacity_J_kgK`: Minimum specific heat capacity of the material found in literature in [J/kgK].
- `minimum_thermal_conductivity_W_mK`: Minimum thermal conductivity of the material found in literature in [W/mK].

>`structure_type`: Represents a category of building structures, e.g. exterior walls, base floors, roofs, etc. Used for storing common properties, like surface resistances and thermal bridges.
- `exterior_resistance_m2K_W`: Exterior surface resistance for this `structure_type` in [m2K/W].
- `interior_resistance_m2K_W`: Interior surface resistance for this `structure_type` in [m2K/W].
- `is_internal`: A boolean flag for whether a structure is an internal structure, meaning not part of the building envelope. Set to `true` for partition walls and separating floors.
- `linear_thermal_bridge_W_mK`: Assumed linear thermal bridge properties for this `structure_type`.
- `structure_type_notes`: Freeform notes about the structure type, or its assumed parameters.

>`ventilation_space_heat_flow_direction`: Represents different assumed heat flow directions in air gaps within structures, e.g. upwards, downwards, and horizontal. Used for creating an interpolated thermal resistance for air gaps of different widths, depending on the assumed heat flow direction.
- `thermal_resistance_m2K_W`: A SpineInterface `Map` linking the air gap width and assumed heat flow direction to a corresponding thermal resistance in [m2K/W].


## Input relationship classes

>`building_stock__building_type__building_period__location_id__heat_source`: Number of existing buildings data for each `(building_stock, building_type, building_period, location_id, heat_source)`.
- `number_of_buildings`: The number of buildings of `building_type`, built during `building_period` in `location_id`, heated using `heat_source` of the `building_stock` dataset.

>`building_type__location_id__building_period`: Average gross-floor area data for each `(building_type, location_id, building_period)`.
- `average_floor_area_m2`: The average gross-floor area in [m2] of `building_type` in `location_id` built during `building_period`.

>`building_type__location_id__frame_material`: Frame material shares for each `(building_type, location_id, frame_material)`.
- `share`: The share of load-bearing frames of `building_type`s in `location_id` made primarily out of `frame_material`.

>`fenestration_source__building_type`: Fenestration properties for `(source, building_type)`.
- `U_value_W_m2K`: The U-value of windows in [W/m2K] of `building_type` according to `source`.
- `frame_area_fraction`: The assumed frame area fraction *(share of opaque surface area)* of `building_type` windows according to `source`. 
- `notes`: Freeform notes regarding assumptions and sources relevant to the fenestration data.
- `solar_energy_transmittance`: The solar energy transmittance of the glazing of `building_type` windows according to `source`.

>`source__structure`: Overall properties and descriptions of `(source, structure)`.
- `design_U_W_m2K`: The design U-value of the structure in [W/m2K]. Replaced with the minimum requirement in the building code at the time if not specified in the raw data sources.
- `structure_description`: A freeform description of the structure.
- `structure_nodes`: Freeform notes regarding assumptions concerning the structure.

>`source__structure__building_type`: Weights/frequencies of different structures for `(source, structure, building_type)`.
- `building_type_weight`: The assumed weight/frequency of a `(source, structure)` in `building_type`. Typically assumed as either 1 or 0 due to lack of more accurate data.

>`source__structure__layer_id__structure_material`: Properties of structural layers for `(source, structure, layer_id, structure_material)`.
- `layer_load_bearing_thickness_mm`: The minimum thickness of the `layer_id` when the `structure` is load-bearing in [mm].
- `layer_minimum_thickness_mm`: The minimum thickness of the `layer_id` when the `structure` isn't load-bearing in [mm].
- `layer_notes`: Freeform notes regarding any assumptions made concerning the `layer_id`.
- `layer_number`: A number indicating the position of the `layer_id` within the `structure`. Zero indicates the primary thermal insulation layer, positive values indicate layers towards the exterior surface, and negative values indicate layers towards the interior surface. For internal structures, zeroth layer indicates the potentially load-bearing layer.
- `layer_tag`: A brief tag indicating the primary purpose of the layer, e.g. thermal insulation, load-bearing, interior finish, etc.
- `layer_weight`: A weight parameter used for describing heterogeneous structural layers, e.g. alternating wood furring and thermal insulation.

>`structure__structure_type`: Links different `structure`s to a single `structure_type`.

>`structure_material__frame_material`: Maps each `structure_material` to a single `frame_material`.

>`structure_type__ventilation_space_heat_flow_direction`: Maps a `ventilation_space_heat_flow_direction` for each `structure_type`.

>`ventilation_source__building_type`: Ventilation properties for `(source, building_type)`:
- `max_HRU_efficiency`: The maximum ventilation heat recovery unit (HRU) efficiency for `building_type` found in literature according to `source`.
- `max_infiltration_factor`: The maximum infiltration rate shape correction factor for `building_type` according to the Finnish building code and `source`.
- `max_n50_infiltration_rate_1_h`: The maximum n50 infiltration rate for `building_type` in [1/h] found in literature according to `source`.
- `max_ventilation_rate_1_h`: The maximum ventilation rate for `building_type` in [1/h] found in literature according to `source`.
- `min_HRU_efficiency`: The minimum ventilation heat recovery unit (HRU) efficiency for `building_type` found in literature according to `source`.
- `min_infiltration_factor`: The minimum infiltration rate shape correction factor for `building_type` according to the Finnish building code and `source`.
- `min_n50_infiltration_rate_1_h`: The minimum n50 infiltration rate for `building_type` in [1/h] found in literature according to `source`.
- `min_ventilation_rate_1_h`: The minimum ventilation rate for `building_type` in [1/h] found in literature according to `source`.
- `notes`: Freeform notes about any assumptions regarding the fenestration properties for `building_type` according to `source`.