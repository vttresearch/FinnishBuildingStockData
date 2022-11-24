# FinnishBuildingStockData.jl

A Julia module for processing Finnish building stock data for
[ArchetypeBuildingModel.jl](https://github.com/vttresearch/ArchetypeBuildingModel).
Essentially, this module takes building stock statistics describing the number and
floor area in a given building stock, as well as data describing structures,
fenestration, and ventilation systems, and combines them into a single dataset with
aggregated structural, fenestration, and ventilation properties matching the
underlying building stock statistics.

This module was originally made for processing the following datasets:

- [*Finnish building stock default structural data*](http://urn.fi/urn:nbn:fi:att:6c6697fc-c601-40b7-a1c9-ad85b0423d38)
- [*Finnish building stock detailed RT-card structural data*](http://urn.fi/urn:nbn:fi:att:61b72dc7-2e51-4598-bd65-95b099fabd0c) (optional)
- [*Finnish building stock forecasts for 2020, 2030, 2040, and 2050*](http://urn.fi/urn:nbn:fi:att:a567a84b-fea4-4ca8-84a1-fe97f52caff4)

but it can, in principle, be used to process any building stock data using a similar format.
Note that this module requires
[Spine Interface](https://github.com/Spine-project/SpineInterface.jl),
and has beed designed to be used via
[Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox),
so familiarizing oneself with them comes highly recommended.

This documentation is organized as follows:
The [Required input data format](@ref) section explains the format
of the input data inside the input *Spine Datastore* used by the processing code.
Next, the [Data processing overview](@ref) section aims to explain the overall flow
of the data processing, in order to give you a rough idea what is actually
being done with the input data.
Essentially, this section explains the `process_datastore.jl` main program,
step by step.
Finally, the [Output data format](@ref) section explains the final format
the data is processed into,
ready to be used by [ArchetypeBuildingModel.jl](https://github.com/vttresearch/ArchetypeBuildingModel).
The [Library](@ref) contains the full documentation of all the functions
contained in this module, automatically generated based on the docstrings
in the codebase.


## Contents

```@contents
```