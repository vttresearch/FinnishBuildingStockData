#=
    statistical_tests.jl

This file contains functions used for testing the statistical inputs in the database.
=#

"""
    test_building_period(;limit::Number=Inf, mod::Module = @__MODULE__)

Run tests for the `building_period` objects in Module `mod`.
"""
function test_building_period(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing `building_period`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :building_period) for
            relationship in [
                mod.building_stock__building_type__building_period__location_id__heat_source,
                mod.building_type__location_id__building_period,
            ]
        ]
        test_parameters = [mod.period_start => Real, mod.period_end => Real]
        for (index, bp) in enumerate(mod.building_period())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(bp in entries, "`$(bp)` not used in `$(name)`!")
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(building_period=bp) isa type,
                        "Invalid `$(string(param))` for `$(bp)`! `$(string(type))` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_building_stock(;limit::Number=Inf, mod::Module = @__MODULE__)

Run tests for the `building_stock` objects in Module `mod`.
"""
function test_building_stock(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing `building_stock`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :building_stock) for
            relationship in [
                mod.building_stock__building_type__building_period__location_id__heat_source,
            ]
        ]
        for (index, bsy) in enumerate(mod.building_stock())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(bsy in entries, "`$(bsy)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_statistical_building_type(;limit::Number=Inf, mod::Module = @__MODULE__)

Runs statistical data tests for the `building_type` objects in Module `mod`.
"""
function test_statistical_building_type(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing statistical `building_type`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :building_type) for
            relationship in [
                mod.building_stock__building_type__building_period__location_id__heat_source,
                mod.building_type__location_id__building_period,
                mod.building_type__location_id__frame_material,
            ]
        ]
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
    test_frame_material(;limit::Number=Inf, mod::Module = @__MODULE__)

Runs tests for the `frame_material` objects in Module `mod`.
"""
function test_frame_material(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing `frame_material`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :frame_material) for
            relationship in [mod.building_type__location_id__frame_material]
        ]
        for (index, mat) in enumerate(mod.frame_material())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(mat in entries, "`$(mat)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_heat_source(;limit::Number=Inf, mod::Module = @__MODULE__)

Runs tests for the `heat_source` objects in Module `mod`.
"""
function test_heat_source(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing `heat_source`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :heat_source) for
            relationship in [
                mod.building_stock__building_type__building_period__location_id__heat_source,
            ]
        ]
        for (index, hs) in enumerate(mod.heat_source())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(hs in entries, "`$(hs)` not used in `$(name)`!")
                end
            else
                break
            end
        end
    end
end


"""
    test_location_id(;limit::Number=Inf, mod::Module = @__MODULE__)

Runs tests for the `location_id` objects in Module `mod`.
"""
function test_location_id(; limit::Number=Inf, mod::Module=@__MODULE__)
    @testset "Testing `location_id`" begin
        test_relationships = [
            _relationship_and_unique_entries(relationship, :location_id) for
            relationship in [
                mod.building_stock__building_type__building_period__location_id__heat_source,
                mod.building_type__location_id__building_period,
                mod.building_type__location_id__frame_material,
            ]
        ]
        test_parameters = [mod.location_name => Symbol]
        for (index, mid) in enumerate(mod.location_id())
            if index <= limit
                # Test relationships
                for (name, (fields, entries)) in test_relationships
                    @test _check(mid in entries, "`$(mid)` not used in `$(name)`!")
                end
                # Test parameters
                for (param, type) in test_parameters
                    @test _check(
                        param(location_id=mid) isa type,
                        "Invalid `$(string(param))` for `$(mid)`! `$(string(type))` required.",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_building_stock__building_type__building_period__location_id__heat_source(;
        limit::Number=Inf,
        mod::Module = @__MODULE__
    )

Run tests for the `building_stock__building_type__building_period__location_id__heat_source` relationhip.
"""
function test_building_stock__building_type__building_period__location_id__heat_source(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [
        mod.building_stock,
        mod.building_type,
        mod.building_period,
        mod.location_id,
        mod.heat_source,
    ]
    test_relationships = [
        _relationship_and_unique_entries(
            mod.building_type__location_id__building_period,
            (:building_type, :location_id, :building_period),
        ),
        _relationship_and_unique_entries(
            mod.building_type__location_id__frame_material,
            (:building_type, :location_id),
        ),
    ]
    test_parameters = [mod.number_of_buildings => Real]
    @testset "Testing `test_building_stock__building_type__building_period__location_id__heat_source`" begin
        for (index, inds) in enumerate(
            mod.building_stock__building_type__building_period__location_id__heat_source(),
        )
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
            else
                break
            end
        end
    end
end


"""
    test_building_type__location_id__building_period(;
        limit::Number=Inf,
        mod::Module = @__MODULE__
    )

Run tests for the `building_type__location_id__building_period` relationship.
"""
function test_building_type__location_id__building_period(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.building_type, mod.location_id, mod.building_period]
    test_relationships = [
        _relationship_and_unique_entries(
            mod.building_stock__building_type__building_period__location_id__heat_source,
            (:building_type, :location_id, :building_period),
        ),
        _relationship_and_unique_entries(
            mod.building_type__location_id__building_period,
            (:building_type, :location_id),
        ),
    ]
    test_parameters = [mod.average_floor_area_m2 => Real]
    @testset "Testing `building_type__location_id__building_period`" begin
        for (index, inds) in enumerate(mod.building_type__location_id__building_period())
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
            else
                break
            end
        end
    end
end


"""
    test_building_type__location_id__frame_material(;
        limit::Number=Inf,
        mod::Module = @__MODULE__
    )

Run tests for the `building_type__location_id__frame_material` relationship.
"""
function test_building_type__location_id__frame_material(;
    limit::Number=Inf,
    mod::Module=@__MODULE__
)
    test_objects = [mod.building_type, mod.location_id, mod.frame_material]
    test_relationships = [
        _relationship_and_unique_entries(
            mod.building_stock__building_type__building_period__location_id__heat_source,
            (:building_type, :location_id),
        ),
        _relationship_and_unique_entries(
            mod.building_type__location_id__building_period,
            (:building_type, :location_id),
        ),
    ]
    @testset "Testing `building_type__location_id__frame_material`" begin
        for (index, inds) in enumerate(mod.building_type__location_id__frame_material())
            (bt, lid, fm) = inds
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
                # Test that share is a 0 <= `Real` <= 1
                @test _check(
                    mod.share(; inds...) isa Real && 0 <= mod.share(; inds...) <= 1,
                    "Invalid `share` for `$(inds_str)`! 0 <= `Real` <= 1 required.",
                )
                # Test that frame material shares sum to approximately one
                @test _check(
                    isapprox(
                        sum(
                            mod.share(
                                building_type=bt,
                                location_id=lid,
                                frame_material=mat,
                            ) for mat in mod.frame_material()
                        ),
                        1,
                    ),
                    "Frame material shares don't sum to one for `$(inds_str)`",
                )
            else
                break
            end
        end
    end
end


"""
    run_statistical_tests(;limit::Number=Inf, mod::Module = @__MODULE__)

Run all statistical data tests for Module `mod`.

Note that you must first open a database via `using_spinedb(db_url, mod)`.

Essentially, this function scans through the statistical input data and ensures
that there are no missing values or values of the incorrect type.
For some parameters, the tests also check whether the given values are *reasonable*,
in an attempt to avoid blatant input data mistakes.
"""
function run_statistical_tests(; limit::Number=Inf, mod::Module=@__MODULE__)
    println("Testing statistical data")
    @testset "Statistical data tests" begin
        println("Testing `building_period`")
        @time test_building_period(; limit=limit, mod=mod)
        println("Testing `building_stock`")
        @time test_building_stock(; limit=limit, mod=mod)
        println("Testing statistical `building_type`")
        @time test_statistical_building_type(; limit=limit, mod=mod)
        println("Testing `frame_material`")
        @time test_frame_material(; limit=limit, mod=mod)
        println("Testing `heat_source`")
        @time test_heat_source(; limit=limit, mod=mod)
        println("Testing `location_id`")
        @time test_location_id(; limit=limit, mod=mod)
        println(
            "Testing `building_stock__building_type__building_period__location_id__heat_source`",
        )
        @time test_building_stock__building_type__building_period__location_id__heat_source(;
            limit=limit,
            mod=mod
        )
        println("Testing `building_type__location_id__building_period`")
        @time test_building_type__location_id__building_period(; limit=limit, mod=mod)
        println("Testing `building_type__location_id__frame_material`")
        @time test_building_type__location_id__frame_material(; limit=limit, mod=mod)
    end
end
