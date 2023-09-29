#=
    read_raw_data.jl

This file contains functions for reading the raw building stock
data directly from the Data Packages without the need to
swing it through Spine Datastores. Unfortunately, Spine Datastores
become prohibitively slow to read and write to at full-Finland-scales.
=#

"""
    RawBuildingStockData

A `struct` for holding the raw Spine Datastore contents.
"""
struct RawBuildingStockData
    building_period::ObjectClass
    building_stock::ObjectClass
    building_type::ObjectClass
    frame_material::ObjectClass
    heat_source::ObjectClass
    layer_id::ObjectClass
    location_id::ObjectClass
    source::ObjectClass
    structure::ObjectClass
    structure_material::ObjectClass
    structure_type::ObjectClass
    ventilation_space_heat_flow_direction::ObjectClass
    building_stock__building_type__building_period__location_id__heat_source::RelationshipClass
    building_type__location_id__building_period::RelationshipClass
    building_type__location_id__frame_material::RelationshipClass
    fenestration_source__building_type::RelationshipClass
    source__structure::RelationshipClass
    source__structure__building_type::RelationshipClass
    source__structure__layer_id__structure_material::RelationshipClass
    structure__structure_type::RelationshipClass
    structure_material__frame_material::RelationshipClass
    structure_type__ventilation_space_heat_flow_direction::RelationshipClass
    ventilation_source__building_type::RelationshipClass
    function RawBuildingStockData()
        last_oc_ind = 12
        new(
            [
                ObjectClass(oc, Array{ObjectLike,1}())
                for oc in collect(fieldnames(RawBuildingStockData)[1:last_oc_ind])
            ]...,
            [
                RelationshipClass(rc, Symbol.(split(string(rc), "__")), Array{RelationshipLike,1}())
                for rc in collect(fieldnames(RawBuildingStockData)[last_oc_ind+1:end])
            ]...
        )
    end
end


"""
    read_datapackage(datpack_path::String)

Read the resources of a Data Package into a dictionary of DataFrames.
"""
function read_datapackage(datpack_path::String)
    dp = JSON.parsefile(datpack_path * "datapackage.json")
    files = get.(dp["resources"], "path", nothing)
    names = first.(split.(getindex.(split.(files, '\\'), 2), '.'))
    return Dict(
        name => DataFrame(CSV.File(datpack_path * file))
        for (name, file) in zip(names, files)
    )
end