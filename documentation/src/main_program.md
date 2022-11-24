# Data processing overview

In this section, we'll go over the main idea behind the data processing workflow
as implemented in the main program file `process_datastore.jl`.
After the input data described in the above [Required input data format](@ref)
section has been successfully imported into a *Spine Datastore*,
the main program can be run to process the data into
the format described by the following [Output data format](@ref) section.

This section is organized as follows:
First, [Using the main program](@ref) is explained,
with the overall [Main program workflow](@ref) described afterwards.
Lastly, the individual [Data processing steps](@ref) are discussed in more detail
in hopes of giving interested readers some further information and guidance into
how the data is being processed.


## Using the main program

The `process_datastore.jl` main program is controlled using a number of
command line arguments, the first two of which are required:

1. `<input_datastore_url>`: The url pointing to the *Spine Datastore* containing the input data in the [Required input data format](@ref).
2. `<output_datastore_url>`: The url pointing to the *Spine Datastore* into which the output will be saved according to the [Output data format](@ref).

Furthermore, the following keyword arguments can be used to tweak how the data is processed.

3. `scramble=<false>`: If set to `true`, will scramble all data in the Datastore.
4. `num_lids=<Inf>`: Can be used to set a maximum number of `location_id`s when processing the data for testing purposes.
5. `thermal_conductivity_weight=<0.5>`: Can be used to tweak how the thermal conductivity data is sampled for the `structure_material`s. The default value corresponds to the average of the minimum and maximum values in the input data.
6. `interior_node_depth=<0.1>`: Assumption regarding how deep the temperature node is located into the structures. The value indicates the depth as a fraction of the total thermal resistance between the interior surface of the structure, and the middle of the primary thermal insulation layer. The default value is based on the IDA ESBO calibrations performed in the [manuscript](https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model).
7. `variation_period=<2225140>`: *Period of variations* as defined in EN ISO 13786:2017 Annex C. Default equals to roughly 26 days in seconds, and is based on the IDA ESBO calibrations performed in the [manuscript](https://cris.vtt.fi/en/publications/sensitivity-of-a-simple-lumped-capacitance-building-thermal-model).


## Main program workflow

The steps performed by the main program can be summarized in the following steps:

1. Process the given command line arguments.
2. Open the input *Spine Datastore* using *Spine Interface*, and run input data tests using [`run_structural_tests`](@ref) and [`run_statistical_tests`](@ref), in order to ensure the input data is complete and reasonable.
3. Create the processed [Output data format](@ref) *relationship classes* using the [`create_processed_statistics!`](@ref) function. This is the part that does most of the computational heavy lifting.
4. Import the newly created output *relationship classes* into the output *Spine Datastore*, scrambling them if the `scramble=true` keyword has been set.


## Data processing steps

This sections delves slightly deeper into the [`create_processed_statistics!`](@ref)
function in hopes of giving a better understanding of what goes on *under the hood*.
Please note that this sections is still just a higher-level overview,
and readers interested in further details are encouraged to refer to the
docstrings of the mentioned functions.

Essentially, [`create_processed_statistics!`](@ref) performs the following steps:

1. Limit `location_id`s by only including them until the given `num_lids`.
2. Call [`add_building_stock_year!`](@ref) to add the `building_stock_year` parameter for the `building_stock` objects, parsed based on their names.
3. Call [`create_building_stock_statistics!`](@ref) to create processed building stock statistics.
4. Call [`create_structure_statistics!`](@ref) to create processed structural statistics.
5. Call [`create_ventilation_and_fenestration_statistics!`](@ref) to create processed ventilation and fenestration statistics.

The first two steps quite are straightforward, and not explained in detail here.
However, the rest of the steps merit some further discussion,
with the [`create_structure_statistics!`](@ref) being by far the most complicated.


### Creating the output `building_stock_statistics` `RelationshipClass`

Handled by the [`create_building_stock_statistics!`](@ref) function,
the output `building_stock_statistics` `RelationshipClass` contains the
`number_of_buildings` and `average_gross_floor_area_m2_per_building` data for
each `(building_stock, building_type, building_period, location_id, heat_source)`.

Essentially, the `building_stock_statistics` is just collected
from the filtered underlying raw input data in the
`building_stock__building_type__building_period__location_id__heat_source`
and `building_type__location_id__building_period` `RelationshipClass`es.

> **NOTE!** The underlying raw input data for the `average_gross_floor_area_per_building` lacks the `building_stock` and `heat_source` dimensions, so when creating the output `building_stock_statistics` the gross floor area is assumed independent of the `building_stock` and `heat_source`. In reality, this is likely not the case.


### Creating the output `structure_statistics` `RelationshipClass`

Handled by the [`create_structure_statistics!`](@ref) function,
the output `structure_statistics` `RelationshipClass` contains the processed
average structural properties for each `(building_type, building_period, location_id, structure_type)`.

> **NOTE!** Due to input data limitations, the structural properties of the buildings are assumed to be independent of `building_stock` and `heat_source`, which is not the case in reality.

The overall process for calculating the average structural properties goes
something like this:

1. The `is_load_bearing` parameter and light exterior and partition wall
`structure_type` objects are created via the [`_add_light_wall_types_and_is_load_bearing!`](@ref) function, as light and load-bearing variants of structures aren't explicitly divided in the raw input data.
2. The properties of all structures in the raw input data are calculated using the [`_form_building_structures`](@ref) function, making use of the assumed `interior_node_depth` and `variation_period` command line arguments and the [`BuildingStructure`](@ref) constructor. At this point, we're still dealing with all the structures defined in the raw input data, and not considering their frequency in the building stock.
3. Finally, the `structure_statistics` `RelationshipClass` is created by looping over the `(building_type, building_period, location_id, structure_type)` in the raw statistical input data, and weighting the relevant structures appropriately via the [`_structure_type_parameter_values`](@ref) function. Essentially, only structures for the appropriate `(building_type, building_period)` are sampled, and weighted according to the frame material shares for each `(building_type, location_id)`.

> **NOTE!** By default, if no appropriate structures are found for a `(building_type, building_period)`, the processing will try to relax the `building_period` by including structures from the previous 10 years as well. If still no appropriate structures are found, it will extend the period by another 10 years, and repeat this process up to 200 years into the past until at least some applicable structures are found.

> **NOTE!** Frame material shares have a default value assumption of `1e-6`, meaning that in case of missing data, all frame materials are weighted equally. However, this also means that all structures are always technically involved in processing the average structural properties regardless of their frame material, albeit with a negligible share in case real frame material share data exists for at least some `(building_type, location_id)`.

> Note that the frame material share data unfortunately only covers `(building_type, location_id)`, even though in reality it is likely dependent on `building_stock`, `building_period`, and maybe even `heat_source` as well.

The calculation of the structural properties are handled by the
[`calculate_structure_properties`](@ref) function,
which in turn heavily relies on the [`layers_with_properties`](@ref) function to
calculate the properties of the individual structural layers in the raw input data.
In brief, calculation of the thermal resistances and U-values is based on the
ISO 6946:2017, and calculation of the effective thermal masses are based on
the ISO 13786:2017 standards.
However, the related functions are quite complicated and beyond this high-level
overview. Interested readers are referred to the docstrings linked above.

### Creating the output `ventilation_and_fenestration_statistics` `RelationshipClass`

Handled by the [`create_ventilation_and_fenestration_statistics!`](@ref) function,
the output `ventilation_and_fenestration_statistics` `RelationshipClass` contains
the processed average ventilation and fenestration properties for each
`(building_type, building_period, location_id)`.

> **NOTE!** Due to input data limitations, the ventilation and fenestration properties are assumed to be independent of `building_stock` and `heat_source`, which is likely not the case in reality.

Essentially, the ventilation and fenestration properties are simply sampled
from the raw input data based on the given weights.
By default, the average of the given mininum and maximum values in the input data
are sampled.

> **NOTE!** By default, if no appropriate ventilation and fenestration properties are found for a `(building_type, building_period)`, the processing will try to relax the `building_period` by including data from the previous 10 years as well. If still no appropriate data is found, it will extend the period by another 10 years, and repeat this process up to 200 years into the past until at least some applicable data found.
