# Candidate-owned full spatial revision; additive operator registries only.
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

function spatial_mechanism_v4(parent,physical,engineering)
    pa=(1,-1,-2,0,0,0,0); tesla=(1,0,-2,-1,0,0,0)
    p=_rcv_type(:scalar_field,0,3,pa)
    b=_rcv_type(:vector_field,1,3,tesla)
    stress=_rcv_type(:tensor_field,2,3,pa)
    registry=register_operator(default_operator_registry(),
        _rcv_manifest("STATIC_MHD_CAUCHY_STRESS_V4",(p,b),stress))
    local_b=_rcv_type(:vector_field,1,3,(0,-2,0,1,0,0,0))
    flux=_rcv_type(:scalar_field,0,0,(1,2,-2,-1,0,0,0))
    current=_rcv_type(:scalar_field,0,0,(0,0,0,1,0,0,0))
    voltage=_rcv_type(:scalar_field,0,0,(1,2,-3,-1,0,0,0))
    for m in (_rcv_manifest("SPATIAL_CURL_CURRENT_V4",(b,),local_b),
              _rcv_manifest("SPATIAL_CURRENT_FINITE_APERTURE_LINKAGE_V4",(local_b,),flux),
              _rcv_manifest("SPATIAL_EXACT_RL_CURRENT_V4",(flux,),current),
              _rcv_manifest("SPATIAL_EXACT_PROTECTION_V4",(current,),voltage;role=:control),
              _rcv_manifest("PICKUP_SERIES_CURRENT_CONTINUITY_V4",(current,),current))
        registry=register_operator(registry,m)
    end
    edge=_rcv_edge("revised-static-mhd-stress","STATIC_MHD_CAUCHY_STRESS_V4",
        (1,2),3,(p,b),registry,physical)
    ledger=ConservationLedgerIdentityV1(QualifiedRefV1("pickup-series-junction-current","v1"),
        digest256_text("Kirchhoff current continuity at ideal zero-charge-storage readout junction"),current.units)
    inflow=PortAccountEffectV1(ConservationAccountRefV1(ledger,:input,1,:inflow),1//1)
    outflow=PortAccountEffectV1(ConservationAccountRefV1(ledger,:output,1,:outflow),-1//1)
    eng_edges=(_rcv_edge("mechanism-current-from-curl","SPATIAL_CURL_CURRENT_V4",(2,),4,(b,),registry,physical),
        _rcv_edge("mechanism-pickup-flux","SPATIAL_CURRENT_FINITE_APERTURE_LINKAGE_V4",(4,),5,(local_b,),registry,engineering),
        _rcv_edge("mechanism-pickup-rl","SPATIAL_EXACT_RL_CURRENT_V4",(5,),6,(flux,),registry,engineering),
        _rcv_edge("mechanism-pickup-protection","SPATIAL_EXACT_PROTECTION_V4",(8,),7,(current,),registry,engineering;role=control),
        _rcv_edge("mechanism-series-junction","PICKUP_SERIES_CURRENT_CONTINUITY_V4",(6,),8,(current,),registry,engineering;account_effects=(inflow,outflow)))
    graph=TypedOperatorHypergraphV1((node(:state,p;id="revised-pressure"),
        node(:state,b;id="revised-magnetic-field"),
        node(:stress,stress;id="revised-cauchy-stress"),
        node(:state,local_b;id="mechanism-spatial-current-density"),
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
        QuantityIntervalV1(ExactFiniteIntervalV1(-1000000000000,1000000000000,false),t.units),
        (),(),(),state_derived) for (id,t) in (("mechanism-spatial-current-density",local_b),
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
        QualifiedRefV1("spatial-static-flux-and-separate-conditional-ramp","v1"),sampling,
        QuantityIntervalV1(ExactFiniteIntervalV1(-1000000000000,1000000000000,false),voltage.units),
        QualifiedRefV1("ideal-deterministic-noiseless-model-not-instrument-data","v1"),
        NonnegativeQuantityV1(0,voltage.units),NonnegativeQuantityV1(0,voltage.units),
        NonnegativeQuantityV1(1//1000000,voltage.units),(QualifiedRefV1("zero-excitation-control","v1"),))
    payload=MechanismGenomePayloadV1((states...,engineering_states...),(invariant,),graph,(),(),(observable,),())
    MechanismGenomeV4(2026091205,parent.mechanism_genome_ref.contract_ref,payload)
end

function spatial_field_graph_v4(base,physical)
    b=_rcv_type(:vector_field,1,3,(1,0,-2,-1,0,0,0))
    p=_rcv_type(:scalar_field,0,3,(1,-1,-2,0,0,0,0))
    force=_rcv_type(:vector_field,1,0,(1,1,-2,0,0,0,0))
    wb=_rcv_type(:vector_field,1,0,(1,2,-2,-1,0,0,0))
    registry=first(base.hyperedges).registry
    for (id,t) in (("SPATIAL_MHD_MOMENTUM_TRACTION_V4",force),("SPATIAL_SOLENOIDAL_FLUX_V4",wb))
        registry=register_operator(registry,_rcv_manifest(id,(b,p),t))
    end
    n=length(base.nodes)
    nodes=(base.nodes...,node(:state,b;id="spatial-Q1-B"),node(:state,p;id="spatial-Q1-pressure"),
        node(:residual,force;id="spatial-momentum-traction-N"),node(:residual,wb;id="spatial-divergence-normal-total-flux-Wb"),
        node(:region,b;id="spatial-plasma-core"),node(:region,b;id="spatial-plasma-edge"),
        node(:interface,b;id="spatial-shared-rho-half-trace"),node(:boundary,b;id="spatial-exact-exterior-trace"))
    edges=(_rcv_edge("spatial-momentum-assembly","SPATIAL_MHD_MOMENTUM_TRACTION_V4",(n+1,n+2),n+3,(b,p),registry,physical),
        _rcv_edge("spatial-flux-assembly","SPATIAL_SOLENOIDAL_FLUX_V4",(n+1,n+2),n+4,(b,p),registry,physical))
    TypedOperatorHypergraphV1(nodes,(base.hyperedges...,edges...);registry=registry)
end

function spatial_engineering_graphs_v4(d)
    j=_rcv_type(:vector_field,1,3,(0,-2,0,1,0,0,0))
    b=_rcv_type(:vector_field,1,3,(1,0,-2,-1,0,0,0))
    flux=_rcv_type(:scalar_field,0,0,(1,2,-2,-1,0,0,0))
    current=_rcv_type(:scalar_field,0,0,(0,0,0,1,0,0,0))
    voltage=_rcv_type(:scalar_field,0,0,(1,2,-3,-1,0,0,0))
    registry=default_operator_registry()
    for (id,ins,out,role) in (("SPATIAL_CURRENT_BIOT_SAVART_V4",(j,),b,:governing),
        ("FINITE_APERTURE_FLUX_V4",(b,),flux,:governing),
        ("EXACT_PICKUP_RL_PROTECTION_V4",(flux,),current,:governing),
        ("SPATIAL_EXACT_PROTECTION_V4",(current,),voltage,:control))
        registry=register_operator(registry,_rcv_manifest(id,ins,out;role=role))
    end
    rg=TypedOperatorHypergraphV1((node(:field_input,j;id="spatial-current-input"),
        node(:field,b;id="spatial-exterior-plasma-B-contribution"),node(:flux,flux;id="spatial-finite-aperture-linkage"),
        node(:current,current;id="spatial-conditional-RL-current")),
        (_rcv_edge("spatial-source-transfer","SPATIAL_CURRENT_BIOT_SAVART_V4",(1,),2,(j,),registry,d),
         _rcv_edge("spatial-aperture-integral","FINITE_APERTURE_FLUX_V4",(2,),3,(b,),registry,d),
         _rcv_edge("spatial-exact-circuit","EXACT_PICKUP_RL_PROTECTION_V4",(3,),4,(flux,),registry,d));registry=registry)
    cg=TypedOperatorHypergraphV1((node(:current,current;id="spatial-detected-current"),
        node(:voltage,voltage;id="spatial-relay-readout")),
        (_rcv_edge("spatial-sampled-protection","SPATIAL_EXACT_PROTECTION_V4",(1,),2,(current,),registry,d;role=control),);registry=registry)
    rg,cg
end

function spatial_candidate_geometry_bound_v4(context)
    input=only(filter(x->x isa ThreeDPhysicalProviderInputV4,context.candidate.field_geometry_genome_ref.fields))
    boundary=input.fourier_boundary
    # |rho^k trig| <= 1 for the declared nonnegative-power radial extension.
    exact=setprecision(BigFloat,256) do
        setrounding(BigFloat,RoundUp) do
            sum(abs(BigFloat(c.coefficient_m)) for c in boundary.radial_coefficients)
        end
    end
    upper=Float64(exact);BigFloat(upper)<exact && (upper=nextfloat(upper))
    (R_upper_m=upper,unit="m",method=:absolute_Fourier_coefficients_directed_rounding,
        declaration_hash=canonical_hash(input),scope=:declared_boundary_and_radial_extension,
        solved_DESC_interior=:requires_separate_spectral_enclosure_comparison,
        source="Inherited exploratory candidate SI Fourier coefficients; not measured geometry")
end

function build_spatial_candidate_v4(parent_context,physical_input)
    parent=parent_context.candidate;registry=parent_context.registry
    inherited=only(filter(x->x isa ThreeDPhysicalProviderInputV4,parent.field_geometry_genome_ref.fields))
    canonical_hash(inherited)==canonical_hash(physical_input) || error("spatial revision retains exact parent geometry/initialization input")
    physical=spatial_multiregion_declaration_v4(;flux_Wb=physical_input.profiles_flux.toroidal_flux_wb)
    engineering=spatial_engineering_declaration_v4();verification=spatial_verification_declaration_v4()
    provenance=(revision="spatial-coupled-candidate-v1",parent_candidate_hash=parent_context.candidate_hash,
        parent_package_hash=canonical_hash(parent),parent_context_hash=parent_context.context_hash,
        geometry="Inherited exploratory SI Fourier geometry, not measurements; execute fresh DESC for this revision",
        profiles="Inherited p/iota are DESC initialization data only, not hard spatial constraints or validation evidence",
        state_scope="Independent full-torus local Q1 B_R/B_phi/B_Z/p in two continuous same-material regions",
        state_envelopes="G1 broad computational envelopes are not admissibility; implemented pressure lower bound is owned by G2",
        engineering="Plasma-current contribution at a finite exterior disk; static flux plus separate prescribed-ramp exact RL scenarios",
        geometry_enclosure="Declared-map analytic radius and separate actual DESC spectral enclosure must be compared",
        authority=:screen_only,physical_validation=:unsupported)
    g1=spatial_mechanism_v4(parent,physical,engineering)
    old=parent.field_geometry_genome_ref
    base=TypedOperatorHypergraphV1(old.graph.nodes[1:5],old.graph.hyperedges[1:2];registry=first(old.graph.hyperedges).registry)
    # Discard the parent's reduced-system declarations; retain geometry-owned inputs only.
    fields=Tuple(x for x in old.fields if !(x isa CompleteMultiRegionDeclarationV4) && !(x isa NamedTuple))
    g2=FieldGeometryGenomeV4(2026091206,old.contract_ref,spatial_field_graph_v4(base,physical);
        fields=(fields...,physical,provenance))
    rg,cg=spatial_engineering_graphs_v4(engineering)
    g3=RealizationControlGenomeV4(2026091207,2026091208,parent.realization_control_genome_ref.contract_ref,
        rg,cg;realization=(engineering,),control=(verification,provenance))
    changes=(g1=:current_from_full_spatial_curl_and_actual_source_to_aperture,
        g2=:replace_four_amplitudes_with_full_torus_Q1_fields_and_all_local_residuals,
        g3=:external_finite_aperture_plasma_current_transfer_exact_RL_protection,
        physical_hash=canonical_hash(physical),engineering_hash=canonical_hash(engineering),verification_hash=canonical_hash(verification))
    proposal=ProposalEnvelopeV4("spatial-coupled-20260912-r1","spatial-coupled-20260912-r1",
        (parent.identity_ref,),:explicit_user_revision,(changes,),"execution_attempt",
        (outcome=:unknown,),(kind=:exploratory_design_intervals_no_distribution,),0.0,
        canonical_hash(provenance),:coupled_execution)
    candidate=CandidateStatePackageV4("spatial-coupled-20260912-r1",parent.mission_contract_ref,g1,g2,g3,registry;proposal_lineage=(proposal,))
    canonical_hash(candidate)!=canonical_hash(parent) || error("spatial revision identity unchanged")
    mission=(mission="full-spatial-multiregion-current-engineering-execution",contract=candidate.mission_contract_ref,scope=:exploratory_physical_model)
    bounds=(declaration_hash=canonical_hash(physical_input),physical_hash=canonical_hash(physical),engineering_hash=canonical_hash(engineering),
        verification_hash=canonical_hash(verification),scope=:full_declared_Q1_system_not_continuum_validation)
    comparison=("spatial-mhd-current-to-exterior-pickup",)
    scenario=(name="spatial-static-and-conditional-design-ramp",source=:candidate_design,measured=false,
        engineering_hash=canonical_hash(engineering))
    scenarios=(scenario.name,)
    compiled=compile_candidate(candidate,registry;mission_payload=mission,bounds_payload=bounds,comparison_scope=comparison,scenario_scope=scenarios)
    binding=make_three_d_physical_provider_input_binding(compiled,registry,mission,bounds,comparison,scenarios,scenario,physical_input)
    subject=ExecutablePhysicalSubjectV4(compiled.prefix_hash,candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,compiled.minimality_scope.bounds_hash,(binding,),(scenario,),
        (revision="spatial-coupled-candidate-v1",changes=changes,provenance=provenance),derive_capability_obligations(compiled))
    context=make_forward_chain_context(candidate,compiled,registry,mission,bounds,comparison,scenarios,subject,scenario)
    (context=context,parent_hash=canonical_hash(parent),changes=changes,provenance=provenance)
end

function validate_spatial_candidate_v4(context)
    validate_forward_chain_context(context)
    c=context.candidate
    p=only(filter(x->x isa SpatialMultiRegionDeclarationV4,c.field_geometry_genome_ref.fields))
    input=only(filter(x->x isa ThreeDPhysicalProviderInputV4,c.field_geometry_genome_ref.fields))
    e=only(filter(x->x isa SpatialPickupEngineeringDeclarationV4,c.realization_control_genome_ref.realization))
    v=only(filter(x->x isa SpatialVerificationDeclarationV4,c.realization_control_genome_ref.control))
    canonical_hash(p)==canonical_hash(spatial_multiregion_declaration_v4(;flux_Wb=input.profiles_flux.toroidal_flux_wb)) || error("spatial physical declaration differs")
    canonical_hash(e)==canonical_hash(spatial_engineering_declaration_v4()) || error("spatial engineering declaration differs")
    canonical_hash(v)==canonical_hash(spatial_verification_declaration_v4()) || error("spatial verification declaration differs")
    canonical_hash(c.mechanism_genome_ref)==canonical_hash(spatial_mechanism_v4(c,p,e)) || error("spatial G1 equations differ")
    fg=c.field_geometry_genome_ref.graph
    length(fg.nodes)==13 && length(fg.hyperedges)==4 || error("spatial G2 coverage differs")
    base=TypedOperatorHypergraphV1(fg.nodes[1:5],fg.hyperedges[1:2];registry=first(fg.hyperedges).registry)
    canonical_hash(fg)==canonical_hash(spatial_field_graph_v4(base,p)) || error("spatial G2 wiring differs")
    rg,cg=spatial_engineering_graphs_v4(e)
    canonical_hash(rg)==canonical_hash(c.realization_control_genome_ref.realization_graph) || error("spatial G3 realization differs")
    canonical_hash(cg)==canonical_hash(c.realization_control_genome_ref.control_graph) || error("spatial G3 control differs")
    true
end
