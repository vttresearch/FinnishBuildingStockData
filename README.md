# FinnishBuildingStockData.jl

A Julia module for processing Finnish building stock data.
Takes building stock structural data in
[*Finnish building stock default structural data*](http://urn.fi/urn:nbn:fi:att:6c6697fc-c601-40b7-a1c9-ad85b0423d38),
as well as the optional detailed data in
[*Finnish building stock detailed RT-card structural data*](http://urn.fi/urn:nbn:fi:att:61b72dc7-2e51-4598-bd65-95b099fabd0c),
along with the building stock statistical data in
[*Finnish building stock forecasts for 2020, 2030, 2040, and 2050*](http://urn.fi/urn:nbn:fi:att:a567a84b-fea4-4ca8-84a1-fe97f52caff4),
and processes them into something usable by the [ArchetypeBuildingModel.jl](https://vttgit.vtt.fi/flexib/archetypebuildingmodel).


## Key contents

1. `process_datastore.jl`, the main program file.
2. `process_datastore.json`, the [Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox) tool definition for the main program above.
3. `src/FinnishBuildingStockData.jl`, the main module file.
4. `scripts/` contains a few example scripts for using this module.


## Installation

Similar to other Julia modules, this module is installed via the Julia `Pkg` package manager.
However, since this module is not included in the *Julia General Registry*,
it cannot be installed using the standard `add` command.
Instead, the module needs to be downloaded manually and installed using the `develop` command:

1. Download the contents of this repository onto your computer, e.g. by cloning the repository.
2. Start Julia and enter the package manager by pressing `]`.
3. `activate` the desired Julia environment, or not if you want to work in the main environment.
4. Install the module using the `develop` command with a path to the folder housing the `Project.toml` file of this module.


## Usage

This module is intended to be used as a part of a [Spine Toolbox](https://github.com/Spine-project/Spine-Toolbox) workflow,
with the following rough steps:

1. Create a Spine Data Connection referring to the `datapackage.json` in [`finnish_building_stock_forecasts`](https://vttgit.vtt.fi/flexib/finnish_building_stock_forecasts).
2. Create a Spine Importer with the `import_finnish_building_stock_forecasts.json` specification from [`finnish_building_stock_forecasts`](https://vttgit.vtt.fi/flexib/finnish_building_stock_forecasts).
3. Create a Spine Data Conenction referring to **AT LEAST** the `datapackage.json` in [`finnish_default_structural_data`](https://vttgit.vtt.fi/flexib/finnish_default_structural_data), and optionally to the corresponding file in [`finnish_RT_structural_data`](https://vttgit.vtt.fi/flexib/finnish_RT_structural_data) as well.
4. Create a Spine Importer with the `import_finnish_structural_data.json` specification from [`finnish_default_structural_data`](https://vttgit.vtt.fi/flexib/finnish_default_structural_data).
5. Create a new Spine Datastore, and connect the above Importers to it.
6. Create a Spine Tool with the `process_datastore.json` tool specification.
7. Create a new Spine Datastore as the output for the `process_datastore` tool.
8. Define the input and output database urls as keyword arguments for the `process_datastore` tool.

Naturally, as a Julia module, one can also access the functionality of this module from Julia by
```julia
julia> using FinnishBuildingStockData
```
However, this is only necessary for more advanced usage.


## Documentation

The source for the documentation is included in the repository under the `docs` folder,
but is not hosted online at the moment.
In order to build and read the documentation locally,
start a Julia REPL from the root folder of this module and perform the following steps:

1. Activate the `docs` environment from the Julia Package manager
```julia
julia> ]
(FinnishBuildingStockData) pkg> Activate docs
(docs) pkg> ]
julia>
```

2. Run the `docs/make.jl` script.
```julia
julia> include("docs/make.jl")
```

3. Open the newly built `docs/build/index.html` to start browsing the documentation.


## License

All rights reserved, for now.


## Acknowledgements

<center>
<table width=500px frame="none">
<tr>
<td valign="middle" width=100px>
<img src=https://www.aka.fi/globalassets/vanhat/y_kuvat/aka_logo_en.svg alt="AKA emblem" width=100%></td>
<td valign="middle">
This module was built for the [Academy of Finland](https://www.aka.fi/en) project
[*"Integration of building flexibility into future energy systems (FlexiB)"*](https://cris.vtt.fi/en/projects/integration-of-building-flexibility-into-future-energy-systems)
under grant agreement No 332421.
</td>
</table>
</center>

<center>
<table width=500px frame="none">
<tr>
<td valign="middle" width=100px>
<img src=https://european-union.europa.eu/themes/contrib/oe_theme/dist/eu/images/logo/standard-version/positive/logo-eu--en.svg alt="EU emblem" width=100%></td>
<td valign="middle">
This project has received funding from the European Union’s Horizon 2020 research and innovation programme under grant agreement No 774629.
</td>
</table>
</center>
