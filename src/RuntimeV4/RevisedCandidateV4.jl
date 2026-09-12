# Exploratory candidate revision with owned laws, domains and engineering.
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _RCV_REVISION = "revised-coupled-candidate-v1"
_rcv_type(kind,rank,dimension,unit) = PhysicalType(kind,rank,dimension,:static,UnitSignature(unit))
_rcv_payload_type() = _rcv_type(:declaration_payload,0,0,(0,0,0,0,0,0,0))

function _rcv_manifest(id,inputs,output; role=:governing)
    types=(inputs...,_rcv_payload_type())
    rule=ExactTypeRuleV1(types,(output,))
    OperatorManifestV1(OperatorRefV1(id,"v1"),length(types),1,rule,rule;
        allowed_roles=(role,),allowed_conservation_effects=id=="PICKUP_SERIES_CURRENT_CONTINUITY_V4" ? (:redistribution,) : ())
end

function _rcv_edge(id,operator,inputs,output,types,registry,declaration; role=governing,account_effects=())
    n=length(inputs)
    leaves=ntuple(i->ASTInputV1(i,types[i]),n)
    payload=ASTConstantV1(:declaration,QualifiedRefV1(canonical_hash(declaration).value,"v1"),_rcv_payload_type())
    root=ASTApplyV1(OperatorRefV1(operator,"v1"),Tuple(1:n+1),(;);
        registry=registry,input_types=(types...,_rcv_payload_type()))
    program=TypedASTProgramV1((leaves...,payload,root),(n+2,),Tuple(1:n);registry=registry)
    AtomicMIMOHyperedgeV1(id,Tuple(MIMOInputBindingV1(i,inputs[i]) for i in 1:n),
        (MIMOOutputBindingV1(1,output),),program,role;registry=registry,account_effects=account_effects)
end

function revised_mechanism_v4(parent,physical,engineering)
    pa=(1,-1,-2,0,0,0,0); tesla=(1,0,-2,-1,0,0,0)
    p=_rcv_type(:scalar_field,0,3,pa)
    b=_rcv_type(:vector_field,1,3,tesla)
    stress=_rcv_type(:tensor_field,2,3,pa)
    registry=register_operator(default_operator_registry(),
        _rcv_manifest("STATIC_MHD_CAUCHY_STRESS_V4",(p,b),stress))
    local_b=_rcv_type(:scalar_field,0,0,tesla)
    flux=_rcv_type(:scalar_field,0,0,(1,2,-2,-1,0,0,0))
    current=_rcv_type(:scalar_field,0,0,(0,0,0,1,0,0,0))
    voltage=_rcv_type(:scalar_field,0,0,(1,2,-3,-1,0,0,0))
    for m in (_rcv_manifest("MAGNETIC_PICKUP_FLUX_V4",(local_b,),flux),
              _rcv_manifest("FARADAY_RL_CIRCUIT_V4",(flux,),current),
              _rcv_manifest("PICKUP_INTEGRATOR_PROTECTION_V4",(current,),voltage;role=:control),
              _rcv_manifest("PICKUP_SERIES_CURRENT_CONTINUITY_V4",(current,),current))
        registry=register_operator(registry,m)
    end
    edge=_rcv_edge("revised-static-mhd-stress","STATIC_MHD_CAUCHY_STRESS_V4",
        (1,2),3,(p,b),registry,physical)
    ledger=ConservationLedgerIdentityV1(QualifiedRefV1("pickup-series-junction-current","v1"),
        digest256_text("Kirchhoff current continuity at ideal zero-charge-storage readout junction"),current.units)
    inflow=PortAccountEffectV1(ConservationAccountRefV1(ledger,:input,1,:inflow),1//1)
    outflow=PortAccountEffectV1(ConservationAccountRefV1(ledger,:output,1,:outflow),-1//1)
    eng_edges=(_rcv_edge("mechanism-pickup-flux","MAGNETIC_PICKUP_FLUX_V4",(4,),5,(local_b,),registry,engineering),
        _rcv_edge("mechanism-pickup-rl","FARADAY_RL_CIRCUIT_V4",(5,),6,(flux,),registry,engineering),
        _rcv_edge("mechanism-pickup-protection","PICKUP_INTEGRATOR_PROTECTION_V4",(8,),7,(current,),registry,engineering;role=control),
        _rcv_edge("mechanism-series-junction","PICKUP_SERIES_CURRENT_CONTINUITY_V4",(6,),8,(current,),registry,engineering;account_effects=(inflow,outflow)))
    graph=TypedOperatorHypergraphV1((node(:state,p;id="revised-pressure"),
        node(:state,b;id="revised-magnetic-field"),
        node(:stress,stress;id="revised-cauchy-stress"),
        node(:state,local_b;id="mechanism-pickup-B"),
        node(:state,flux;id="mechanism-pickup-flux"),
        node(:state,current;id="mechanism-pickup-current"),
        node(:state,voltage;id="mechanism-pickup-branch-voltage"),
        node(:state,current;id="mechanism-active-branch-current")),(edge,eng_edges...);registry=registry)
    states=(StateGeneV1(StateGeneRefV1("revised-pressure"),p,
        QuantityIntervalV1(ExactFiniteIntervalV1(0,1000000000,false),p.units),
        (),(),(),state_derived),
        StateGeneV1(StateGeneRefV1("revised-magnetic-field"),b,
        QuantityIntervalV1(ExactFiniteIntervalV1(-100,100,false),b.units),
        (),(),(),state_derived))
    engineering_states=Tuple(StateGeneV1(StateGeneRefV1(id),t,
        QuantityIntervalV1(ExactFiniteIntervalV1(-10000,10000,false),t.units),
        (),(),(),state_derived) for (id,t) in (("mechanism-pickup-B",local_b),
        ("mechanism-pickup-flux",flux),("mechanism-pickup-current",current),("mechanism-pickup-branch-voltage",voltage),("mechanism-active-branch-current",current)))
    occurrences=(ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("mechanism-series-junction"),:input,1,:inflow,occurrence_internal_effect,ledger),
        ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("mechanism-series-junction"),:output,1,:outflow,occurrence_internal_effect,ledger))
    invariant=InvariantV1(InvariantRefV1("pickup-junction-current-continuity"),ledger,GlobalConservationScopeV1(),
        (InvariantTermV1(StateGeneRefV1("mechanism-pickup-current"),1),
         InvariantTermV1(StateGeneRefV1("mechanism-active-branch-current"),-1)),occurrences,0,entropy_conserved)
    identity=ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(1,),(;);registry=registry,input_types=(voltage,))
    sampling=TypedASTProgramV1((ASTInputV1(1,voltage),identity),(2,),(1,);registry=registry)
    observable=ObservableGeneV1(ObservableRefV1("ideal-pickup-readout-while-connected"),
        ProgramRootRefV1(OperatorSiteRefV1("mechanism-pickup-protection"),1,voltage),
        QualifiedRefV1("declared-exploratory-ramp","v1"),sampling,
        QuantityIntervalV1(ExactFiniteIntervalV1(-10000,10000,false),voltage.units),
        QualifiedRefV1("ideal-deterministic-noiseless-model-not-instrument-data","v1"),
        NonnegativeQuantityV1(0,voltage.units),NonnegativeQuantityV1(0,voltage.units),
        NonnegativeQuantityV1(1//1000000,voltage.units),(QualifiedRefV1("zero-excitation-control","v1"),))
    payload=MechanismGenomePayloadV1((states...,engineering_states...),(invariant,),graph,(),(),(observable,),())
    MechanismGenomeV4(2026091201,parent.mechanism_genome_ref.contract_ref,payload)
end

function revised_field_graph_v4(parent_graph,physical)
    coeff=_rcv_type(:vector_field,1,0,(0,0,0,0,0,0,0))
    force=_rcv_type(:vector_field,1,0,(1,1,-2,0,0,0,0))
    # Preserve the exact geometry edges and roots. Extend its local registry only.
    registry=first(parent_graph.hyperedges).registry
    registry=register_operator(registry,
        _rcv_manifest("COMPLETE_REGIONAL_STATIC_MHD_V4",(coeff,),force))
    n=length(parent_graph.nodes)
    nodes=(parent_graph.nodes...,
        node(:state,coeff;id="revised-regional-coefficients"),
        node(:residual,force;id="revised-complete-weak-residual"),
        node(:region,coeff;id="revised-inner-region"),
        node(:region,coeff;id="revised-outer-region"),
        node(:interface,coeff;id="revised-rho-half-interface"),
        node(:boundary,coeff;id="revised-rho-one-boundary"))
    edge=_rcv_edge("revised-complete-region-operator","COMPLETE_REGIONAL_STATIC_MHD_V4",
        (n+1,),n+2,(coeff,),registry,physical)
    TypedOperatorHypergraphV1(nodes,(parent_graph.hyperedges...,edge);registry=registry)
end

function revised_engineering_graphs_v4(engineering)
    b=_rcv_type(:scalar_field,0,0,(1,0,-2,-1,0,0,0))
    flux=_rcv_type(:scalar_field,0,0,(1,2,-2,-1,0,0,0))
    current=_rcv_type(:scalar_field,0,0,(0,0,0,1,0,0,0))
    voltage=_rcv_type(:scalar_field,0,0,(1,2,-3,-1,0,0,0))
    registry=default_operator_registry()
    for m in (_rcv_manifest("MAGNETIC_PICKUP_FLUX_V4",(b,),flux),
              _rcv_manifest("FARADAY_RL_CIRCUIT_V4",(flux,),current),
              _rcv_manifest("PICKUP_INTEGRATOR_PROTECTION_V4",(current,),voltage;role=:control))
        registry=register_operator(registry,m)
    end
    realization=TypedOperatorHypergraphV1((node(:field_input,b;id="pickup-boundary-field"),
        node(:flux,flux;id="pickup-flux"),node(:current,current;id="pickup-current")),
        (_rcv_edge("pickup-flux-law","MAGNETIC_PICKUP_FLUX_V4",(1,),2,(b,),registry,engineering),
         _rcv_edge("pickup-circuit-law","FARADAY_RL_CIRCUIT_V4",(2,),3,(flux,),registry,engineering));registry=registry)
    control_graph=TypedOperatorHypergraphV1((node(:current,current;id="pickup-current-input"),
        node(:voltage,voltage;id="pickup-branch-voltage")),
        (_rcv_edge("pickup-protection-law","PICKUP_INTEGRATOR_PROTECTION_V4",(1,),2,
            (current,),registry,engineering;role=control),);registry=registry)
    realization,control_graph
end

function build_revised_candidate_v4(parent_context,physical_input)
    parent=parent_context.candidate; registry=parent_context.registry
    physical=multiregion_declaration_v4()
    engineering=engineering_declaration_v4(); verification=validation_declaration_v4()
    provenance=(kind=:exploratory_design_revision,revision=_RCV_REVISION,
        parent_candidate_hash=canonical_hash(parent),
        parent_identity=parent.identity_ref,
        retained_geometry="parent Fourier boundary and profiles retained as exploratory design values; not measurements",
        state_envelope="G1 p in [0,1e9] Pa and B components in [-100,100] T are exploratory computational bounds, not admissibility or validation",
        ideal_observable="G1 readout [-1e4,1e4] V envelope and 1e-6 V minimum effect are exploratory design values; zero noise/numerical floors describe an ideal deterministic observation, not measured noise or estimated solver error; readout applies only while connected, and after trip the current-continuity state refers to the active dump branch",
        added_laws="static ideal MHD stress; complete declared regional weak system; Faraday/RL pickup and protection",
        authority=:screen_only)
    mechanism=revised_mechanism_v4(parent,physical,engineering)
    fg=parent.field_geometry_genome_ref
    field=FieldGeometryGenomeV4(2026091202,fg.contract_ref,
        revised_field_graph_v4(fg.graph,physical);fields=(fg.fields...,physical,provenance))
    rg,cg=revised_engineering_graphs_v4(engineering)
    g3=RealizationControlGenomeV4(2026091203,2026091204,
        parent.realization_control_genome_ref.contract_ref,rg,cg;
        realization=(engineering,),control=(verification,provenance))
    changes=(g1=:replace_structural_identity_fixture_with_static_mhd_law,
        g2=:own_two_regions_full_declared_weak_system,g3=:own_magnetic_pickup_and_protection,
        physical_hash=canonical_hash(physical),engineering_hash=canonical_hash(engineering),
        verification_hash=canonical_hash(verification))
    proposal=ProposalEnvelopeV4("revised-coupled-20260912-r1","revised-coupled-20260912-r1",
        (parent.identity_ref,),:explicit_user_revision,(changes,),"execution_attempt",
        (outcome=:unknown,),(kind=:exploratory_design_ranges,),0.0,
        canonical_hash(provenance),:coupled_execution)
    candidate=CandidateStatePackageV4("revised-coupled-20260912-r1",parent.mission_contract_ref,
        mechanism,field,g3,registry;proposal_lineage=(proposal,))
    canonical_hash(candidate)!=canonical_hash(parent) || error("revision failed to change identity")
    mission=(mission="complete-declared-multiregion-and-magnetic-engineering-attempt",
        contract=candidate.mission_contract_ref,scope=:exploratory_physical_model)
    bounds=(declaration_hash=canonical_hash(physical_input),physical_hash=canonical_hash(physical),
        engineering_hash=canonical_hash(engineering),verification_hash=canonical_hash(verification),
        scope="complete declared finite-dimensional system; not full-function-space MHD")
    comparison=("revised-static-mhd-and-magnetic-circuit",)
    scenario=(name="revised-exploratory-magnetic-ramp",source=:candidate_design_scenario,
        measured=false,engineering_hash=canonical_hash(engineering))
    scenarios=(scenario.name,)
    compiled=compile_candidate(candidate,registry;mission_payload=mission,bounds_payload=bounds,
        comparison_scope=comparison,scenario_scope=scenarios)
    binding=make_three_d_physical_provider_input_binding(compiled,registry,mission,bounds,
        comparison,scenarios,scenario,physical_input)
    subject=ExecutablePhysicalSubjectV4(compiled.prefix_hash,candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,compiled.minimality_scope.bounds_hash,
        (binding,),(scenario,),(revision=_RCV_REVISION,changes=changes,provenance=provenance),
        derive_capability_obligations(compiled))
    context=make_forward_chain_context(candidate,compiled,registry,mission,bounds,comparison,
        scenarios,subject,scenario)
    (context=context,parent_hash=canonical_hash(parent),changes=changes,provenance=provenance)
end

"Rebuild exact owned model graphs; declaration labels alone cannot select these kernels."
function validate_revised_declarations_v4(context)
    validate_forward_chain_context(context)
    _validate_revised_graphs_v4(context.candidate)
end

function _validate_revised_graphs_v4(candidate)
    physical=only(filter(x->x isa CompleteMultiRegionDeclarationV4,candidate.field_geometry_genome_ref.fields))
    engineering=only(filter(x->x isa MagneticEngineeringDeclarationV4,candidate.realization_control_genome_ref.realization))
    verification=only(filter(x->x isa ExecutedValidationDeclarationV4,candidate.realization_control_genome_ref.control))
    canonical_hash(physical)==canonical_hash(multiregion_declaration_v4()) || error("unimplemented physics declaration")
    canonical_hash(engineering)==canonical_hash(engineering_declaration_v4()) || error("unimplemented engineering declaration")
    canonical_hash(verification)==canonical_hash(validation_declaration_v4()) || error("unimplemented verification declaration")
    expected_mechanism=revised_mechanism_v4(candidate,physical,engineering)
    canonical_hash(candidate.mechanism_genome_ref)==canonical_hash(expected_mechanism) ||
        throw(ArgumentError("G1 law/state graph does not match implemented equations"))
    fg=candidate.field_geometry_genome_ref.graph
    length(fg.nodes)==11 && length(fg.hyperedges)==3 || throw(ArgumentError("G2 model graph coverage differs"))
    base=TypedOperatorHypergraphV1(fg.nodes[1:5],fg.hyperedges[1:2];registry=first(fg.hyperedges).registry)
    expected_field=revised_field_graph_v4(base,physical)
    canonical_hash(fg)==canonical_hash(expected_field) || throw(ArgumentError("G2 law wiring differs"))
    rg,cg=revised_engineering_graphs_v4(engineering)
    g3=candidate.realization_control_genome_ref
    canonical_hash(g3.realization_graph)==canonical_hash(rg) &&
        canonical_hash(g3.control_graph)==canonical_hash(cg) || throw(ArgumentError("G3 law wiring differs"))
    true
end
