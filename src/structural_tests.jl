#=
    structural_tests.jl

This file contains functions used for testing the structural input in the database.
=#

"""
    test_structural_building_type(;limit::Number=Inf, mod::Module = @__MODULE__)

Run structural data tests for the `building_type` objects in Module `mod`.
"""
function test_structural_building_type(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :building_type) for
        relationship in [mod.source__structure__building_type]
    ]
    @testset "Testing structural `building_type`" begin
        for (index, type) in enumerate(mod.building_type())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(type in entries, "`$(type)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
     test_structural_frame_material(; limit::Number = Inf, mod::Module = @__MODULE__)

Run structural data tests for the `frame_material` objects in Module `mod`.
"""
function test_structural_frame_material(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :frame_material) for
        relationship in [mod.structure_material__frame_material]
    ]
    @testset "Testing structural `frame_material`" begin
        for (index, type) in enumerate(mod.frame_material())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(type in entries, "`$(type)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_layer_id(;limit::Number=Inf, mod::Module = @__MODULE__)

Run tests for the `layer_id` objects in Module `mod`.
"""
function test_layer_id(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :layer_id) for
        relationship in [mod.source__structure__layer_id__structure_material]
    ]
    @testset "Testing `layer_id`" begin
        for (index, id) in enumerate(mod.layer_id())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(id in entries, "`$(id)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_source(; limit::Number=Inf, mod::Module = @__MODULE__)

Run tests for the `source` objects in Module `mod`.
"""
function test_source(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = []
    #= Cannot be tested like this after including fenestration and ventilation sources...
    _relationship_and_unique_entries(relationship, :source)
    for relationship in [
        source__structure,
        source__structure__building_type,
        source__structure__layer_id__structure_material,
    ] =#
    test_parameters = [mod.source_year => Real, mod.source_description => Symbol]
    @testset "Testing `source`" begin
        for (index, src) in enumerate(mod.source())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(src in entries, "`$(src)` not used in `$(name)`!")
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(source=src) isa type,
                        "Invalid `$(string(param))` for `$(src)`! `$(string(type))` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_structure(; limit::Number = Inf, mod::Module = @__MODULE__)

Tun tests for the `structure` objects in Module `mod`.
"""
function test_structure(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :structure) for relationship in [
            mod.source__structure,
            mod.source__structure__building_type,
            #source__structure__layer_id__structure_material, # Cannot be tested, as some cold/basement structures aren't included.
            #structure__structure_type # Cannot be tested, as some cold/basement structures aren't included.
        ]
    ]
    @testset "Testing `structure`" begin
        for (index, str) in enumerate(mod.structure())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(str in entries, "`$(str)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_structure_material(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `structure_material` objects in Module `mod`.
"""
function test_structure_material(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :structure_material) for
        relationship in [
            mod.source__structure__layer_id__structure_material
            mod.structure_material__frame_material
        ]
    ]
    @testset "Testing `structure_material`" begin
        for (index, mat) in enumerate(mod.structure_material())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(mat in entries, "`$(mat)` not used in `$(name)`!")
                end
                # Test that each `structure_material` is mapped to exactly one `frame_material`
                @test _check(
                    length(
                        mod.structure_material__frame_material(structure_material=mat),
                    ) == 1,
                    "$(mat) must be mapped to exactly one `frame_material` via `structure_material__frame_material`!",
                )
                # Check that density parameters are valid.
                @test _check(
                    mod.minimum_density_kg_m3(structure_material=mat)::Real <=
                    density(mat; mod=mod)::Real &&
                    density(mat; mod=mod) <=
                    mod.maximum_density_kg_m3(structure_material=mat)::Real,
                    "Invalid `minimum_density_kg_m3` or `maximum_density_kg_m3` for $(mat)!",
                )
                # Check that specific heat capacity parameters are valid.
                @test _check(
                    mod.minimum_specific_heat_capacity_J_kgK(
                        structure_material=mat,
                    )::Real <= specific_heat_capacity(mat; mod=mod)::Real &&
                    specific_heat_capacity(mat; mod=mod) <=
                    mod.maximum_specific_heat_capacity_J_kgK(
                        structure_material=mat,
                    )::Real,
                    "Invalid `minimum_specific_heat_capacity_J_kgK` or `maximum_specific_heat_capacity_J_kgK` for $(mat)!",
                )
                # Check that thermal conductivity parameters are valid.
                @test _check(
                    mod.minimum_thermal_conductivity_W_mK(structure_material=mat)::Real <=
                    thermal_conductivity(mat; mod=mod)::Real &&
                    thermal_conductivity(mat; mod=mod) <=
                    mod.maximum_thermal_conductivity_W_mK(structure_material=mat)::Real,
                    "Invalid `minimum_thermal_conductivity_W_mK` or `maximum_thermal_conductivity_W_mK` for $(mat)!",
                )
            else
                break
            end
        end
    end
end


"""
    test_structure_type(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `structure_type` objects in Module `mod`.
"""
function test_structure_type(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_relationships = [
        _relationship_and_unique_entries(relationship, :structure_type) for
        relationship in [
            mod.structure__structure_type,
            mod.structure_type__ventilation_space_heat_flow_direction,
        ]
    ]
    test_parameters = [
        mod.exterior_resistance_m2K_W => Real,
        mod.interior_resistance_m2K_W => Real,
        mod.is_internal => Bool,
        mod.linear_thermal_bridge_W_mK => Real,
        mod.structure_type_notes => Symbol,
    ]
    @testset "Testing `structure_type`" begin
        for (index, typ) in enumerate(mod.structure_type())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(typ in entries, "`$(typ)` not used in `$(name)`!")
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(structure_type=typ) isa type,
                        "Invalid `$(string(param))` for `$(typ)`! `$(string(type))` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_ventilation_space_heat_flow_direction(;
        limit::Number = Inf,
        mod::Module = @__MODULE__
    )

Run tests for the `ventilation_space_heat_flow_direction` objects in `mod`.
"""
function test_ventilation_space_heat_flow_direction(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_relationships = [
        _relationship_and_unique_entries(
            relationship,
            :ventilation_space_heat_flow_direction,
        ) for
        relationship in [mod.structure_type__ventilation_space_heat_flow_direction]
    ]
    test_parameters = [mod.thermal_resistance_m2K_W => SpineInterface.Map]
    @testset "Testing `ventilation_space_heat_flow_direction`" begin
        for (index, dir) in enumerate(mod.ventilation_space_heat_flow_direction())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(dir in entries, "`$(dir)` not used in `$(name)`!")
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(ventilation_space_heat_flow_direction=dir) isa type,
                        "Invalid `$(string(param))` for `$(dir)`! `$(string(type))` required.",
                    )
                    @test _check(
                        !isempty(param(ventilation_space_heat_flow_direction=dir)),
                        "Empty `$(string(param))` for `$(dir)` not permitted!"
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_fenestration_source__building_type(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `fenestration_source__building_type` relationships in Module `mod`.
"""
function test_fenestration_source__building_type(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.source, mod.building_type]
    test_parameters = [
        mod.U_value_W_m2K => Real,
        mod.frame_area_fraction => Real,
        mod.notes => Symbol,
        mod.solar_energy_transmittance => Real,
    ]
    @testset "Testing `fenestration_source__building_type`" begin
        for (index, inds) in enumerate(mod.fenestration_source__building_type())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(; inds...) isa type,
                        "Invalid `$(param)` for `$(inds_str)`! `$(type)` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_source__structure(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `source__structure` relationships in Module `mod`.
"""
function test_source__structure(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_objects = [mod.source, mod.structure]
    test_relationships = []
    #= # These cannot be included due to some structures being cold/basement.
    _relationship_and_unique_entries(
        source__structure__building_type,
        (:source, :structure)
    ),
    _relationship_and_unique_entries(
        source__structure__layer_id__structure_material,
        (:source, :structure)
    ) =#
    @testset "Testing `source__structure`" begin
        for (index, inds) in enumerate(mod.source__structure())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
                # Test connected relationships
                for (name, (fields, entries)) in test_relationships
                    reduced_inds = Tuple((getfield(inds, field) for field in fields))
                    @test _check(
                        reduced_inds in entries,
                        "`$(join(reduced_inds, ":"))` of `$(inds_str)` not found in `$(name)`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_source__structure__building_type(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `source__structure__building_type` relationships in Module `mod`.
"""
function test_source__structure__building_type(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.source, mod.structure, mod.building_type]
    test_relationships = [
        _relationship_and_unique_entries(mod.source__structure, (:source, :structure)),
        #=_relationship_and_unique_entries( # Cannot be included due to basement/cold structure data missing
            source__structure__layer_id__structure_material,
            (:source, :structure)
        )=#
    ]
    @testset "Testing `source__structure__building_type`" begin
        for (index, inds) in enumerate(mod.source__structure__building_type())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
                # Test connected relationships
                for (name, (fields, entries)) in test_relationships
                    reduced_inds = Tuple((getfield(inds, field) for field in fields))
                    @test _check(
                        reduced_inds in entries,
                        "`$(join(reduced_inds, ":"))` of `$(inds_str)` not found in `$(name)`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_source__structure__layer_id__structure_material(;
        limit::Number = Inf,
        mod::Module = @__MODULE__
    )

Run tests for the `source__structure__layer_id__structure_material` relationship in Module `mod`.
"""
function test_source__structure__layer_id__structure_material(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.source, mod.structure, mod.layer_id, mod.structure_material]
    test_relationships = [
        _relationship_and_unique_entries(mod.source__structure, (:source, :structure)),
        _relationship_and_unique_entries(
            mod.source__structure__building_type,
            (:source, :structure),
        ),
    ]
    test_parameters = [
        mod.layer_tag => Symbol,
        #layer_notes => Symbol # This cannot be tested, as there are layers without notes!
    ]
    @testset "Testing `source__structure__layer_id__structure_material`" begin
        for (index, inds) in
            enumerate(mod.source__structure__layer_id__structure_material())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
                # Test connected relationships
                for (name, (fields, entries)) in test_relationships
                    reduced_inds = Tuple((getfield(inds, field) for field in fields))
                    @test _check(
                        reduced_inds in entries,
                        "`$(join(reduced_inds, ":"))` of `$(inds_str)` not found in `$(name)`!",
                    )
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(; inds...) isa type,
                        "Invalid `$(param)` for `$(inds_str)`! `$(type)` required.",
                    )
                end
                # Check that layer numbers are convertable to integers.
                @test _check(
                    Int(mod.layer_number(; inds...)) isa Int64,
                    "`layer_number` of $(inds) must be convertable to `Int64`!",
                )
                # Check that layer weights are between [0,1].
                @test _check(
                    0 <= mod.layer_weight(; inds...)::Real <= 1,
                    "`layer_weight` of $(inds) must be between [0,1]!",
                )
                # Check that layers have non-negative minimum thicknesses.
                lmt = mod.layer_minimum_thickness_mm(; inds...)::Real
                @test _check(
                    lmt >= 0,
                    "`layer_minimum_thickness_mm` of $(inds) must be larger than or equal to zero!",
                )
                # Check that layer load bearing thickness is greater than or equal to minimum thickness, when defined.
                lbt = mod.layer_load_bearing_thickness_mm(; inds...)
                if !isnothing(lbt)
                    @test _check(
                        lbt::Real >= lmt,
                        "`layer_load_bearing_thickness_mm` of $(inds) must be larger or equal than `layer_minimum_thickness_mm`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_structure__structure_type(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `structure__structure_type` relationships in Module `mod`.
"""
function test_structure__structure_type(; limit::Number=Inf, mod::Module=@__MODULE__)
    test_objects = [mod.structure, mod.structure_type]
    @testset "Testing `structure__structure_type`" begin
        for (index, inds) in enumerate(mod.structure__structure_type())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_structure_material__frame_material(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `structure_material__frame_material` relationships in Module `mod`.
"""
function test_structure_material__frame_material(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.structure_material, mod.frame_material]
    @testset "Testing `structure_material__frame_material`" begin
        for (index, inds) in enumerate(mod.structure_material__frame_material())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_structure_type__ventilation_space_heat_flow_direction(;
        limit::Number = Inf,
        mod::Module = @__MODULE__,
    )

Run tests for the `structure_type__ventilation_space_heat_flow_direction`
relationship in Module `mod`.
"""
function test_structure_type__ventilation_space_heat_flow_direction(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.structure_type, mod.ventilation_space_heat_flow_direction]
    @testset "Testing `structure_type__ventilation_space_heat_flow_direction`" begin
        for (index, inds) in
            enumerate(mod.structure_type__ventilation_space_heat_flow_direction())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_ventilation_source__building_type(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests for the `ventilation_source__building_type` relationships in Module `mod`.
"""
function test_ventilation_source__building_type(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.source, mod.building_type]
    test_parameters = [
        mod.max_HRU_efficiency => Real,
        mod.min_HRU_efficiency => Real,
        mod.max_infiltration_factor => Real,
        mod.min_infiltration_factor => Real,
        mod.max_n50_infiltration_rate_1_h => Real,
        mod.min_n50_infiltration_rate_1_h => Real,
        mod.max_ventilation_rate_1_h => Real,
        mod.min_ventilation_rate_1_h => Real,
        mod.notes => Symbol,
    ]
    @testset "Testing `ventilation_source__building_type`" begin
        for (index, inds) in enumerate(mod.ventilation_source__building_type())
            if index <= limit
                inds_str = join(inds, ":")
                # Test that indexing objects exist
                for (i, ind) in enumerate(inds)
                    @test _check(
                        ind in test_objects[i](),
                        "`$(ind)` of `$(inds_str)` not found in `$(test_objects[i])`!",
                    )
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(; inds...) isa type,
                        "Invalid `$(param)` for `$(inds_str)`! `$(type)` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_structural_layers(; limit::Number = Inf, mod::Module = @__MODULE__)

Run tests in Module `mod` to ensure the structural layers are sensible.

Essentially, this means checking that the `layer_number` are continuous, the zeroth `layer_tag` is either
`load-bering structure` or `thermal insulation`, and that the `layer_weight`s sum to ≈ 1 for potentially
overlapping layers (meaning those with identical `layer_number`).
"""
function test_structural_layers(; limit::Number=Inf, mod::Module=@__MODULE__)
    zero_tags = [Symbol("load-bearing structure"), Symbol("thermal insulation")]
    inner_tags = [Symbol("interior finish")]
    outer_tags = [Symbol("exterior finish"), Symbol("ground")]
    @testset "Testing structural layer properties" begin
        for (index, (src, str)) in enumerate(mod.source__structure())
            if index <= limit
                inds = join([src, str], ":")
                layers, layer_numbers = order_layers(src, str; mod=mod)
                total_weight = total_building_type_weight(src, str; mod=mod)
                # Check that layer numbers are continuous integer values with no gaps.
                @test _check(
                    all(0 .<= diff(layer_numbers) .<= 1),
                    "`layer_number`s of $(inds) must be continuous!",
                )
                if total_weight > 0
                    # Check that each structure is connected to exactly one type.
                    @test _check(
                        length(mod.structure__structure_type(structure=str)) == 1,
                        "$(str) must be connected to exactly one `structure_type`!",
                    )
                    # Check that layer weights of overlapping layers total ≈ 1 (tolerance ≈ 1e-8).
                    @test _check(
                        all(
                            isapprox(
                                sum(
                                    mod.layer_weight(
                                        source=src,
                                        structure=str,
                                        layer_id=l.id,
                                        structure_material=l.material,
                                    ) for l in filter(l -> l.number == lnum, layers)
                                ),
                                1,
                            ) for lnum in layer_numbers
                        ),
                        "`layer_weight`s of $(inds) must sum up to ≈ 1 for all `layer_id`s with the same `layer_number`!",
                    )
                    # Check that overlapping layers have identical minimum thicknesses
                    @test _check(
                        all(
                            length(
                                unique(
                                    mod.layer_minimum_thickness_mm(
                                        source=src,
                                        structure=str,
                                        layer_id=l.id,
                                        structure_material=l.material,
                                    ) for l in filter(l -> l.number == lnum, layers)
                                ),
                            ) == 1 for lnum in layer_numbers
                        ),
                        "`layer_minimum_thickness_mm` of overlapping layers of $(inds) must be identical!",
                    )
                    # Check that overlapping layers have identical load-bearing thicknesses, if any.
                    @test _check(
                        all(
                            length(
                                unique(
                                    mod.layer_load_bearing_thickness_mm(
                                        source=src,
                                        structure=str,
                                        layer_id=l.id,
                                        structure_material=l.material,
                                    ) for l in filter(l -> l.number == lnum, layers)
                                ),
                            ) == 1 for lnum in layer_numbers
                        ),
                        "`layer_load_bearing_thickness_mm` of overlapping layers of $(inds) must be identical!",
                    )
                    # Check that the zeroth layer includes a load-bearing structure or thermal insulation.
                    @test _check(
                        any(
                            in(l.tag, zero_tags) for l in filter(l -> l.number == 0, layers)
                        ),
                        "The `layer_tag`s of the zeroth `layer_number`s of $(inds) must include `$(join(zero_tags, "`, `", "` or `"))`!",
                    )
                    # Check that there exists at least one load-bearing layer.
                    @test _check(
                        Symbol("load-bearing structure") in getfield.(layers, :tag),
                        "`load-bearing structure` not found for `$(inds)`!",
                    )
                    # Check that the innermost layer is interior finish.
                    @test _check(
                        in(first(layers).tag, inner_tags),
                        "The `layer_tag` with the lowest `layer_number` of $(inds) must include `$(join(inner_tags, "`, `", "` or `"))`!",
                    )
                    # Check that there's only one interior finish layer
                    @test _check(
                        count(in(l.tag, inner_tags) for l in layers) == 1,
                        "$(inds) must include exactly one `$(join(inner_tags, "`, `", "` or `"))` `layer_tag`!",
                    )
                    # Check that the outermost layer is either exterior finish or ground.
                    @test _check(
                        in(last(layers).tag, outer_tags),
                        "The `layer_tag` with the highest `layer_number` of $(inds) must include `$(join(outer_tags, "`, `", "` or `"))`!",
                    )
                    # Check that there's at most one outer tag.
                    @test _check(
                        count(in(l.tag, outer_tags) for l in layers) <= 1,
                        "$(inds) must include at most one `$(join(outer_tags, "`, `", "` or `"))` `layer_tag`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    run_structural_tests(; limit::Number = Inf, mod::Module = @__MODULE__)

Run all structural data tests for Module `mod`.

Note that you must first open a database via `using_spinedb(db_url, mod)`!

Essentially, this function scans through the structural input data and ensures
that there are no missing values or values of the incorrect type.
For some parameters, the tests also check whether the given values are *reasonable*,
in an attempt to avoid blatant input data mistakes.
"""
function run_structural_tests(; limit::Number=Inf, mod::Module=@__MODULE__)
    println("Testing structural data")
    @testset "Structural data tests" begin
        println("Testing structural `building_type`")
        @time test_structural_building_type(limit=limit, mod=mod)
        println("Testing structural `frame_material`")
        @time test_structural_frame_material(limit=limit, mod=mod)
        println("Testing `layer_id`")
        @time test_layer_id(limit=limit, mod=mod)
        println("Testing `source`")
        @time test_source(limit=limit, mod=mod)
        println("Testing `structure`")
        @time test_structure(limit=limit, mod=mod)
        println("Testing `structure_material`")
        @time test_structure_material(limit=limit, mod=mod)
        println("Testing `structure_type`")
        @time test_structure_type(limit=limit, mod=mod)
        println("Testing `ventilation_space_heat_flow_direction`")
        @time test_ventilation_space_heat_flow_direction(limit=limit, mod=mod)
        println("Testing `fenestration_source__building_type`")
        @time test_fenestration_source__building_type(limit=limit, mod=mod)
        println("Testing `source__structure`")
        @time test_source__structure(limit=limit, mod=mod)
        println("Testing `source__structure__building_type`")
        @time test_source__structure__building_type(limit=limit, mod=mod)
        println("Testing `source__structure__layer_id__structure_material`")
        @time test_source__structure__layer_id__structure_material(limit=limit, mod=mod)
        println("Testing `structure__structure_type`")
        @time test_structure__structure_type(limit=limit, mod=mod)
        println("Testing `structure_material__frame_material`")
        @time test_structure_material__frame_material(limit=limit, mod=mod)
        println("Testing `structure_type__ventilation_space_heat_flow_direction`")
        @time test_structure_type__ventilation_space_heat_flow_direction(
            limit=limit,
            mod=mod,
        )
        println("Testing `ventilation_source__building_type`")
        @time test_ventilation_source__building_type(limit=limit, mod=mod)
        println("Testing structural layer properties")
        @time test_structural_layers(limit=limit, mod=mod)
    end
end
