"""SHA-256 content hashes over canonical semantic representations."""

function canonical_hash(x)
    bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical_json(x)))))
end

mechanism_hash(x::MechanismGenomeV4) = canonical_hash(x)
field_geometry_hash(x::FieldGeometryGenomeV4) = canonical_hash(x)
realization_control_hash(x::RealizationControlGenomeV4) = canonical_hash(x)
realization_hash(x::RealizationControlGenomeV4) = canonical_hash((contract_ref=x.contract_ref, graph=x.realization_graph, payload=x.realization))
control_hash(x::RealizationControlGenomeV4) = canonical_hash((contract_ref=x.contract_ref, graph=x.control_graph, payload=x.control))
coupled_realization_control_hash(x::RealizationControlGenomeV4) = canonical_hash((realization_hash=realization_hash(x), control_hash=control_hash(x)))

function genome_bundle_hash(m::MechanismGenomeV4, f::FieldGeometryGenomeV4, r::RealizationControlGenomeV4; mission_contract=nothing, bounds=nothing)
    canonical_hash((mechanism=m, field_geometry=f, realization_control=r, mission_contract=mission_contract, bounds=bounds))
end
