# Data processing overview

In this section, we'll go over the main idea behind the data processing workflow
as implemented in the main program file `process_datastore.jl`.
After the input data described in the above [Required input data format](@ref)
section has been successfully imported into a *Spine Datastore*,
the main program can be run to process the data into
the format described by the following [Output data format](@ref) section.


## Using the main program

The `process_datastore.jl` main program is controlled using a number of
command line arguments, the first two of which are required:

1. `<input_datastore_url>`: The url pointing to the *Spine Datastore* containing the input data in the [Required input data format](@ref).
2. `<output_datastore_url>`: The url pointing to the *Spine Datastore* into which the output will be saved according to the [Output data format](@ref).

Furthermore, the following keyword arguments can be used to tweak how the data is processed.

3. `scramble=<false>`: If set to `true`, will scramble all data in the Datastore.
4. `num_lids=<Inf>`: Can be used to set a maximum number of `location_id`s when processing the data for testing purposes.
5. `thermal_conductivity_weight=<1/2>`: Can be used to tweak hot the thermal conductivity data is sampled for the `structure_material`s. The default value corresponds to the average of the minimum and maximum values in the input data.
6. `interior_node_depth=<1/3>`: Assumption regarding how deep the temperature node is located into the structures. The value indicates the depth as a fraction of the total thermal resistance between the interior surface of the structure, and the middle of the primary thermal insulation layer.
7. `variation_period=<432000>`: *Period of variations* as defined in EN ISO 13786:2017 Annex C. 5 days in second by default, based on EUReCA and IDA ESBO calibrations.


## Main program workflow

The steps performed by the main program can be summarized in the following steps:

1. Process the given command line arguments.
2. Open the input *Spine Datastore* using *Spine Interface*, and run input data tests using [`run_structural_tests`](@ref) and [`run_statistical_tests`](@ref), in order to ensure the input data makes sense.
3. Limit the set of `location_id`s based on the given `num_lids` keyword argument.
4. Create the `building_stock_year` parameter based on parsing the names of the `building_stock` *objects* in the input data using [`add_building_stock_year!`](@ref).
5. Create the `building_stock_statistics` output *relationship class* using the [`create_building_stock_statistics`](@ref) function.
6. Create the `structure_statistics` output *relationship class* using the [`create_structure_statistics`](@ref) function with the desired `thermal_conductivity_weight`, `interior_node_depth`, and `variation_period` keyword arguments.
7. Create the `ventilation_and_fenestration_statistics` output *relationship class* using the [`create_ventilation_and_fenestration_statistics`](@ref) function.
8. Import the newly created output *relationship classes* into the output *Spine Datastore*, scrambling them if the `scramble=true` keyword has been set.