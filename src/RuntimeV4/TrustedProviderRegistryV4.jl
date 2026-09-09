"""Content-addressed trust root, provider registration, and operational receipts.

This isolated layer authorizes dispatch to repository-owned executors.  It is
not a scientific evidence, validation, closure, promotion, or terminal layer.
"""

using SHA

const _TPR_SCHEMA = "fusionconceptai:runtime-v4-trusted-provider-registry"
const _TPR_REVISION = "trusted-provider-registry-v1"
const _TPR_BUILTIN_PROVIDER = "runtime-v4-repository-fixture"
const _TPR_BUILTIN_SOURCE = "src/RuntimeV4/TrustedProviderRegistryV4.jl"
const _TPR_FREEGS_PROVIDER = "runtime-v4-freegs-axisymmetric"
const _TPR_FREEGS_SOURCE = "src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl"
const _TPR_FREEGS_ATTESTED_SOURCES = (
    _TPR_FREEGS_SOURCE,
    "src/RuntimeV4/FreeGSAxisymmetricExecution.jl",
    "scripts/runtime_v4_freegs_axisymmetric_runner.py")
const _TPR_FREEGS_MODEL_CLASS = "physical_model_screen"
const _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER =
    "runtime-v4-engineering-control-fault-manufactured"
const _TPR_ENGINEERING_CONTROL_FAULT_SOURCE =
    "src/RuntimeV4/TrustedEngineeringControlFaultProviderV4.jl"
const _TPR_ENGINEERING_CONTROL_FAULT_ATTESTED_SOURCES = (
    _TPR_ENGINEERING_CONTROL_FAULT_SOURCE,
    "src/RuntimeV4/EngineeringControlFaultGraphObligationV4.jl")
const _TPR_ENGINEERING_CONTROL_FAULT_MODEL_CLASS =
    "manufactured_control_fault_operational_screen"

struct _TrustedProviderRegistryToken end
const _TPR_TOKEN = _TrustedProviderRegistryToken()

_tpr_text(value::AbstractString, field::AbstractString) =
    !isempty(strip(String(value))) && isvalid(String(value)) ? String(value) :
    throw(ArgumentError("$field must be non-empty valid text"))

_tpr_file_hash(path::AbstractString) =
    Digest256(bytes2hex(SHA.sha256(read(String(path)))))

function _tpr_normalize_root(path::AbstractString)
    root = normpath(abspath(String(path)))
    while length(root) > 3 && (endswith(root, "\\") || endswith(root, "/"))
        root = chop(root)
    end
    String(root)
end

function _tpr_inside_root(root::String, relative::String)
    isabspath(relative) && throw(ArgumentError("provider source path must be repository-relative"))
    normalized_root = _tpr_normalize_root(root)
    target = normpath(abspath(joinpath(normalized_root, relative)))
    rel = relpath(target, normalized_root)
    (rel == ".." || startswith(rel, "..$(Base.Filesystem.path_separator)")) &&
        throw(ArgumentError("provider source escapes repository root"))
    isfile(target) || throw(ArgumentError("provider source file does not exist"))
    target
end

"""A deliberately harmless repository-owned executor used by the isolated example."""
function _trusted_repository_fixture_executor(input)
    is_canonical_value(input) || throw(ArgumentError("trusted fixture input must be canonicalizable"))
    (execution_kind=:repository_fixture, input_hash=canonical_hash(input))
end

function _tpr_runtime_hash(executor::Function, repository_root::AbstractString)
    root = _tpr_normalize_root(repository_root)
    snapshots = NamedTuple[]
    for method in methods(executor)
        file = String(method.file)
        normalized_file = isempty(file) ? "unknown" :
            replace(normpath(abspath(file)), '\\' => '/')
        relative_file = try
            replace(relpath(normalized_file, root), '\\' => '/')
        catch
            normalized_file
        end
        push!(snapshots, (module_name=string(method.module),
            signature=string(method.sig), source_file=relative_file,
            source_line=Int(method.line)))
    end
    sort!(snapshots, by=item ->
        (item.module_name, item.signature, item.source_file, item.source_line))
    canonical_hash((revision=_TPR_REVISION, method_table=Tuple(snapshots)))
end

struct RepositoryProviderDescriptorV4
    provider_id::String
    source_relative_path::String
    entrypoint::Symbol
    allowed_capability_kinds::Tuple{Vararg{Symbol}}
    allowed_model_classes::Tuple{Vararg{String}}
    source_hash::Digest256
    attested_source_paths::Tuple{Vararg{String}}
    attested_source_hashes::Tuple{Vararg{Digest256}}
    runtime_hash::Digest256
    executor::Function
    descriptor_hash::Digest256
    function RepositoryProviderDescriptorV4(token::_TrustedProviderRegistryToken,
            provider_id::String, source_relative_path::String, entrypoint::Symbol,
            allowed_capability_kinds::Tuple{Vararg{Symbol}},
            allowed_model_classes::Tuple{Vararg{String}}, source_hash::Digest256,
            attested_source_paths::Tuple{Vararg{String}},
            attested_source_hashes::Tuple{Vararg{Digest256}},
            runtime_hash::Digest256, executor::Function, descriptor_hash::Digest256)
        token === _TPR_TOKEN || throw(ArgumentError("private constructor"))
        new(provider_id, source_relative_path, entrypoint, allowed_capability_kinds,
            allowed_model_classes, source_hash, attested_source_paths,
            attested_source_hashes, runtime_hash, executor, descriptor_hash)
    end
end

function _tpr_descriptor_body(provider_id::String, source_relative_path::String,
        entrypoint::Symbol, kinds::Tuple{Vararg{Symbol}},
        model_classes::Tuple{Vararg{String}}, source_hash::Digest256,
        attested_source_paths::Tuple{Vararg{String}},
        attested_source_hashes::Tuple{Vararg{Digest256}},
        runtime_hash::Digest256)
    (revision=_TPR_REVISION, provider_id=provider_id,
     source_relative_path=replace(source_relative_path, '\\' => '/'),
     entrypoint=entrypoint, allowed_capability_kinds=kinds,
     allowed_model_classes=model_classes, source_hash=source_hash,
     attested_source_paths=attested_source_paths,
     attested_source_hashes=attested_source_hashes,
     runtime_hash=runtime_hash)
end

function _tpr_attested_source_hashes(repository_root::String, paths)
    normalized = Tuple(replace(String(path), '\\' => '/') for path in paths)
    length(unique(normalized)) == length(normalized) ||
        throw(ArgumentError("provider attested source paths must be unique"))
    hashes = Tuple(_tpr_file_hash(_tpr_inside_root(repository_root, path))
        for path in normalized)
    normalized, hashes
end

function _tpr_builtin_descriptor(repository_root::String)
    source = _tpr_inside_root(repository_root, _TPR_BUILTIN_SOURCE)
    normpath(source) == normpath(abspath(@__FILE__)) ||
        throw(ArgumentError("trusted bootstrap source is not this loaded repository source"))
    kinds = (:structural_screen,)
    model_classes = ("test_only",)
    source_hash = _tpr_file_hash(source)
    attested_paths, attested_hashes = _tpr_attested_source_hashes(repository_root,
        (_TPR_BUILTIN_SOURCE,))
    runtime_hash = _tpr_runtime_hash(_trusted_repository_fixture_executor,
        repository_root)
    body = _tpr_descriptor_body(_TPR_BUILTIN_PROVIDER, _TPR_BUILTIN_SOURCE,
        :_trusted_repository_fixture_executor, kinds, model_classes,
        source_hash, attested_paths, attested_hashes, runtime_hash)
    RepositoryProviderDescriptorV4(_TPR_TOKEN, _TPR_BUILTIN_PROVIDER,
        _TPR_BUILTIN_SOURCE, :_trusted_repository_fixture_executor, kinds,
        model_classes, source_hash, attested_paths, attested_hashes, runtime_hash,
        _trusted_repository_fixture_executor, canonical_hash(body))
end

function _tpr_freegs_descriptor(repository_root::String)
    source = _tpr_inside_root(repository_root, _TPR_FREEGS_SOURCE)
    executor_method_files = Tuple(replace(normpath(abspath(String(method.file))),
        '\\' => '/') for method in methods(_trusted_freegs_axisymmetric_executor))
    replace(normpath(source), '\\' => '/') in executor_method_files ||
        throw(ArgumentError("trusted FreeGS entrypoint is not loaded from its fixed repository source"))
    kinds = (:axisymmetric_equilibrium_screen,)
    model_classes = (_TPR_FREEGS_MODEL_CLASS,)
    source_hash = _tpr_file_hash(source)
    attested_paths, attested_hashes = _tpr_attested_source_hashes(repository_root,
        _TPR_FREEGS_ATTESTED_SOURCES)
    runtime_hash = _tpr_runtime_hash(_trusted_freegs_axisymmetric_executor,
        repository_root)
    body = _tpr_descriptor_body(_TPR_FREEGS_PROVIDER,
        _TPR_FREEGS_SOURCE, :_trusted_freegs_axisymmetric_executor, kinds,
        model_classes, source_hash, attested_paths, attested_hashes, runtime_hash)
    RepositoryProviderDescriptorV4(_TPR_TOKEN, _TPR_FREEGS_PROVIDER,
        _TPR_FREEGS_SOURCE, :_trusted_freegs_axisymmetric_executor, kinds,
        model_classes, source_hash, attested_paths, attested_hashes,
        runtime_hash, _trusted_freegs_axisymmetric_executor,
        canonical_hash(body))
end

function _tpr_engineering_control_fault_descriptor(repository_root::String)
    source = _tpr_inside_root(repository_root,
        _TPR_ENGINEERING_CONTROL_FAULT_SOURCE)
    executor_method_files = Tuple(replace(normpath(abspath(String(method.file))),
        '\\' => '/') for method in methods(_trusted_engineering_control_fault_executor))
    replace(normpath(source), '\\' => '/') in executor_method_files ||
        throw(ArgumentError("trusted engineering control/fault entrypoint is not loaded from its fixed repository source"))
    kinds = (:engineering_control_fault_operational_screen,)
    model_classes = (_TPR_ENGINEERING_CONTROL_FAULT_MODEL_CLASS,)
    source_hash = _tpr_file_hash(source)
    attested_paths, attested_hashes = _tpr_attested_source_hashes(repository_root,
        _TPR_ENGINEERING_CONTROL_FAULT_ATTESTED_SOURCES)
    runtime_hash = _tpr_runtime_hash(_trusted_engineering_control_fault_executor,
        repository_root)
    body = _tpr_descriptor_body(_TPR_ENGINEERING_CONTROL_FAULT_PROVIDER,
        _TPR_ENGINEERING_CONTROL_FAULT_SOURCE,
        :_trusted_engineering_control_fault_executor, kinds, model_classes,
        source_hash, attested_paths, attested_hashes, runtime_hash)
    RepositoryProviderDescriptorV4(_TPR_TOKEN,
        _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER,
        _TPR_ENGINEERING_CONTROL_FAULT_SOURCE,
        :_trusted_engineering_control_fault_executor, kinds, model_classes,
        source_hash, attested_paths, attested_hashes, runtime_hash,
        _trusted_engineering_control_fault_executor, canonical_hash(body))
end

_tpr_builtin_descriptors(repository_root::String) =
    (_tpr_builtin_descriptor(repository_root),
     _tpr_freegs_descriptor(repository_root))

function _tpr_expected_descriptor(provider_id::String, repository_root::String)
    provider_id == _TPR_BUILTIN_PROVIDER &&
        return _tpr_builtin_descriptor(repository_root)
    provider_id == _TPR_FREEGS_PROVIDER &&
        return _tpr_freegs_descriptor(repository_root)
    provider_id == _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER &&
        return _tpr_engineering_control_fault_descriptor(repository_root)
    throw(ArgumentError("untrusted provider id"))
end

function validate_repository_provider_descriptor(
        descriptor::RepositoryProviderDescriptorV4,
        repository_root::AbstractString)
    root = _tpr_normalize_root(repository_root)
    expected = _tpr_expected_descriptor(descriptor.provider_id, root)
    descriptor.provider_id == expected.provider_id || throw(ArgumentError("untrusted provider id"))
    descriptor.source_relative_path == expected.source_relative_path || throw(ArgumentError("provider source path mismatch"))
    descriptor.entrypoint == expected.entrypoint || throw(ArgumentError("provider entrypoint mismatch"))
    descriptor.allowed_capability_kinds == expected.allowed_capability_kinds || throw(ArgumentError("provider capability policy mismatch"))
    descriptor.allowed_model_classes == expected.allowed_model_classes || throw(ArgumentError("provider model-class policy mismatch"))
    descriptor.source_hash == expected.source_hash || throw(ArgumentError("provider source hash mismatch"))
    descriptor.attested_source_paths == expected.attested_source_paths || throw(ArgumentError("provider attested source paths mismatch"))
    descriptor.attested_source_hashes == expected.attested_source_hashes || throw(ArgumentError("provider attested source hashes mismatch"))
    descriptor.runtime_hash == expected.runtime_hash || throw(ArgumentError("provider runtime hash mismatch"))
    descriptor.executor === expected.executor || throw(ArgumentError("provider executor identity mismatch"))
    descriptor.descriptor_hash == expected.descriptor_hash || throw(ArgumentError("provider descriptor hash mismatch"))
    descriptor.descriptor_hash
end

canonical_hash(x::RepositoryProviderDescriptorV4) =
    throw(ArgumentError("descriptor hash requires repository-root revalidation"))

semantic_view(x::RepositoryProviderDescriptorV4) = _tpr_descriptor_body(
    x.provider_id, x.source_relative_path, x.entrypoint,
    x.allowed_capability_kinds, x.allowed_model_classes,
    x.source_hash, x.attested_source_paths, x.attested_source_hashes,
    x.runtime_hash)

struct TrustedProviderRegistrationV4
    descriptor_hash::Digest256
    context::ForwardChainContextV4
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    capability::CapabilitySignatureV4
    manifest::ProviderManifestV4
    registration_hash::Digest256
    function TrustedProviderRegistrationV4(token::_TrustedProviderRegistryToken,
            descriptor_hash::Digest256, context::ForwardChainContextV4,
            context_hash::Digest256, subject_hash::Digest256,
            scenario_hash::Digest256, capability::CapabilitySignatureV4,
            manifest::ProviderManifestV4, registration_hash::Digest256)
        token === _TPR_TOKEN || throw(ArgumentError("private constructor"))
        new(descriptor_hash, context, context_hash, subject_hash, scenario_hash,
            capability, manifest, registration_hash)
    end
end

function _tpr_registration_body(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4,
        manifest::ProviderManifestV4)
    (revision=_TPR_REVISION, descriptor_hash=descriptor.descriptor_hash,
     context_hash=context.context_hash,
     subject_hash=context.subject.physical_subject_hash,
     scenario_hash=context.scenario_hash,
     capability_hash=canonical_hash(capability),
     manifest_hash=manifest.manifest_hash,
     source_hash=descriptor.source_hash, runtime_hash=descriptor.runtime_hash)
end

semantic_view(x::TrustedProviderRegistrationV4) = (
    descriptor_hash=x.descriptor_hash, context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    capability_hash=canonical_hash(x.capability),
    manifest_hash=x.manifest.manifest_hash,
    registration_hash=x.registration_hash)

struct TrustedProviderRegistryV4
    repository_root::String
    repository_identity_hash::Digest256
    descriptors::Tuple{Vararg{RepositoryProviderDescriptorV4}}
    registrations::Tuple{Vararg{TrustedProviderRegistrationV4}}
    registry_hash::Digest256
    function TrustedProviderRegistryV4(token::_TrustedProviderRegistryToken,
            repository_root::String, repository_identity_hash::Digest256,
            descriptors::Tuple{Vararg{RepositoryProviderDescriptorV4}},
            registrations::Tuple{Vararg{TrustedProviderRegistrationV4}},
            registry_hash::Digest256)
        token === _TPR_TOKEN || throw(ArgumentError("private constructor"))
        new(repository_root, repository_identity_hash, descriptors,
            registrations, registry_hash)
    end
end

function _tpr_repository_identity(repository_root::String,
        descriptors::Tuple{Vararg{RepositoryProviderDescriptorV4}})
    project = _tpr_inside_root(repository_root, "Project.toml")
    entry = _tpr_inside_root(repository_root, "src/FusionConceptAI.jl")
    canonical_hash((revision=_TPR_REVISION,
        project_hash=_tpr_file_hash(project), package_entry_hash=_tpr_file_hash(entry),
        descriptor_hashes=Tuple(item.descriptor_hash for item in descriptors)))
end

function _tpr_registry_body(repository_identity_hash::Digest256,
        descriptors::Tuple{Vararg{RepositoryProviderDescriptorV4}},
        registrations::Tuple{Vararg{TrustedProviderRegistrationV4}})
    (revision=_TPR_REVISION, repository_identity_hash=repository_identity_hash,
     descriptor_hashes=Tuple(item.descriptor_hash for item in descriptors),
     registration_hashes=Tuple(item.registration_hash for item in registrations))
end

"""Explicitly establish the repository source and loaded method table as trust root."""
function bootstrap_trusted_provider_registry(::Val{:trusted_repository_bootstrap},
        repository_root::AbstractString)
    root = _tpr_normalize_root(repository_root)
    descriptors = (_tpr_builtin_descriptor(root),)
    identity = _tpr_repository_identity(root, descriptors)
    body = _tpr_registry_body(identity, descriptors, ())
    TrustedProviderRegistryV4(_TPR_TOKEN, root, identity, descriptors, (),
        canonical_hash(body))
end


"""Bootstrap the fixed base catalog plus the repository-owned FreeGS adapter."""
function bootstrap_trusted_provider_registry(
        ::Val{:trusted_repository_with_freegs_bootstrap},
        repository_root::AbstractString)
    root = _tpr_normalize_root(repository_root)
    descriptors = _tpr_builtin_descriptors(root)
    identity = _tpr_repository_identity(root, descriptors)
    body = _tpr_registry_body(identity, descriptors, ())
    TrustedProviderRegistryV4(_TPR_TOKEN, root, identity, descriptors, (),
        canonical_hash(body))
end

"""Bootstrap the base catalog plus the fixed engineering control/fault adapter."""
function bootstrap_trusted_provider_registry(
        ::Val{:trusted_repository_with_engineering_control_fault_bootstrap},
        repository_root::AbstractString)
    root = _tpr_normalize_root(repository_root)
    descriptors = (_tpr_builtin_descriptor(root),
        _tpr_engineering_control_fault_descriptor(root))
    identity = _tpr_repository_identity(root, descriptors)
    body = _tpr_registry_body(identity, descriptors, ())
    TrustedProviderRegistryV4(_TPR_TOKEN, root, identity, descriptors, (),
        canonical_hash(body))
end

function _tpr_domain(context::ForwardChainContextV4,
        descriptor::RepositoryProviderDescriptorV4, capability::CapabilitySignatureV4,
        model_class::String)
    base = (bounds_hash=capability.applicability_bounds,
     context_hash=context.context_hash,
     subject_hash=context.subject.physical_subject_hash,
     scenario_hash=context.scenario_hash,
     descriptor_hash=descriptor.descriptor_hash,
     model_class=model_class)
    if descriptor.provider_id == _TPR_FREEGS_PROVIDER
        binding = _freegs_context_binding(context)
        return merge(base, (binding_hash=binding.binding_hash,
            declaration_hash=canonical_hash(binding.declaration),
            field_geometry_genome_hash=binding.field_geometry_genome_hash,
            field_geometry_graph_hash=binding.field_geometry_graph_hash,
            field_geometry_graph_binding_hash=binding.field_geometry_graph_binding_hash))
    end
    base
end

function _tpr_context_capability(context::ForwardChainContextV4,
        descriptor::RepositoryProviderDescriptorV4,
        capability::CapabilitySignatureV4)
    if descriptor.provider_id == _TPR_FREEGS_PROVIDER
        return validate_trusted_freegs_axisymmetric_capability(capability, context)
    end
    hashes = Tuple(canonical_hash(item) for item in context.obligations)
    target = canonical_hash(capability)
    count(==(target), hashes) == 1 ||
        throw(ArgumentError("capability is absent from or ambiguous in forward context"))
    capability.applicability_bounds == context.compiled.minimality_scope.bounds_hash ||
        throw(ArgumentError("capability applicability bounds mismatch"))
    target
end

function _tpr_descriptor_for_capability(registry::TrustedProviderRegistryV4,
        capability::CapabilitySignatureV4)
    matches = Tuple(item for item in registry.descriptors
        if capability.kind in item.allowed_capability_kinds)
    length(matches) == 1 ||
        throw(ArgumentError("trusted descriptor for capability is missing or ambiguous"))
    only(matches)
end

function _tpr_validate_dispatch_input(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4, input)
    is_canonical_value(input) ||
        throw(ArgumentError("dispatch input must be immutable and canonicalizable"))
    if descriptor.provider_id == _TPR_FREEGS_PROVIDER
        input isa TrustedFreeGSAxisymmetricInputV4 ||
            throw(ArgumentError("trusted FreeGS dispatch requires typed canonical input"))
        validate_trusted_freegs_axisymmetric_input(input, context, capability)
    end
    canonical_hash(input)
end

function _tpr_find_descriptor(registry::TrustedProviderRegistryV4,
        provider_id::AbstractString)
    id = _tpr_text(provider_id, "provider id")
    hits = Tuple(item for item in registry.descriptors if item.provider_id == id)
    length(hits) == 1 || throw(ArgumentError("trusted provider descriptor is missing or ambiguous"))
    only(hits)
end

function _tpr_model_class(manifest::ProviderManifestV4)
    domain = manifest.domain
    domain isa NamedTuple && :model_class in keys(domain) ||
        throw(ArgumentError("provider model class is not declared"))
    _tpr_text(String(getfield(domain, :model_class)), "provider model class")
end

function _tpr_validate_manifest(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4,
        manifest::ProviderManifestV4, repository_root::AbstractString)
    validate_forward_chain_context(context)
    _tpr_context_capability(context, descriptor, capability)
    capability.kind in descriptor.allowed_capability_kinds ||
        throw(ArgumentError("capability kind is outside provider descriptor policy"))
    model_class = _tpr_model_class(manifest)
    model_class in descriptor.allowed_model_classes ||
        throw(ArgumentError("provider model class is outside descriptor policy"))
    manifest.domain == _tpr_domain(context, descriptor, capability, model_class) ||
        throw(ArgumentError("provider context/subject/scenario domain mismatch"))
    manifest.backend == descriptor.provider_id || throw(ArgumentError("provider backend mismatch"))
    manifest.backend_revision == _TPR_REVISION || throw(ArgumentError("provider revision mismatch"))
    manifest.independence_group == "trusted-repository:$(descriptor.provider_id)" ||
        throw(ArgumentError("provider independence group mismatch"))
    manifest.code_hash == descriptor.source_hash || throw(ArgumentError("provider code hash mismatch"))
    manifest.executor === descriptor.executor || throw(ArgumentError("provider executor is not repository-owned"))
    root = _tpr_normalize_root(repository_root)
    _tpr_runtime_hash(descriptor.executor, root) == descriptor.runtime_hash ||
        throw(ArgumentError("provider executor runtime hash mismatch"))
    match_provider(capability, (manifest,)).status == unique_match ||
        throw(ArgumentError("provider does not exactly match capability"))
    manifest.manifest_hash
end

function validate_trusted_provider_registration(registration::TrustedProviderRegistrationV4,
        descriptor::RepositoryProviderDescriptorV4, repository_root::AbstractString)
    validate_repository_provider_descriptor(descriptor, repository_root)
    validate_forward_chain_context(registration.context)
    registration.descriptor_hash == descriptor.descriptor_hash || throw(ArgumentError("registration descriptor mismatch"))
    registration.context_hash == registration.context.context_hash || throw(ArgumentError("registration context mismatch"))
    registration.subject_hash == registration.context.subject.physical_subject_hash || throw(ArgumentError("registration subject mismatch"))
    registration.scenario_hash == registration.context.scenario_hash || throw(ArgumentError("registration scenario mismatch"))
    _tpr_validate_manifest(descriptor, registration.context,
        registration.capability, registration.manifest, repository_root)
    expected = canonical_hash(_tpr_registration_body(descriptor,
        registration.context, registration.capability, registration.manifest))
    registration.registration_hash == expected || throw(ArgumentError("registration hash mismatch"))
    expected
end


function validate_trusted_provider_registry(registry::TrustedProviderRegistryV4)
    root = _tpr_normalize_root(registry.repository_root)
    registry.repository_root == root || throw(ArgumentError("registry repository root is not normalized"))
    provider_ids = Tuple(item.provider_id for item in registry.descriptors)
    provider_ids in ((_TPR_BUILTIN_PROVIDER,),
                     (_TPR_BUILTIN_PROVIDER, _TPR_FREEGS_PROVIDER),
                     (_TPR_BUILTIN_PROVIDER,
                      _TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)) ||
        throw(ArgumentError("registry descriptor set mismatch"))
    expected_descriptors = Tuple(_tpr_expected_descriptor(item.provider_id, root)
        for item in registry.descriptors)
    all(validate_repository_provider_descriptor(item, root) == item.descriptor_hash
        for item in registry.descriptors) ||
        throw(ArgumentError("registry descriptor validation failed"))
    Tuple(item.descriptor_hash for item in registry.descriptors) ==
        Tuple(item.descriptor_hash for item in expected_descriptors) ||
        throw(ArgumentError("registry descriptor identity mismatch"))
    identity = _tpr_repository_identity(root, registry.descriptors)
    registry.repository_identity_hash == identity || throw(ArgumentError("repository identity changed after bootstrap"))
    for registration in registry.registrations
        descriptor = _tpr_find_descriptor(registry, registration.manifest.backend)
        validate_trusted_provider_registration(registration, descriptor, root)
    end
    keys = Tuple((item.context_hash, canonical_hash(item.capability))
        for item in registry.registrations)
    length(unique(keys)) == length(keys) || throw(ArgumentError("duplicate trusted provider registration"))
    expected = canonical_hash(_tpr_registry_body(identity, registry.descriptors,
        registry.registrations))
    registry.registry_hash == expected || throw(ArgumentError("trusted registry hash mismatch"))
    expected
end

canonical_hash(x::TrustedProviderRegistryV4) = validate_trusted_provider_registry(x)
semantic_view(x::TrustedProviderRegistryV4) = (
    repository_identity_hash=x.repository_identity_hash,
    descriptor_hashes=Tuple(item.descriptor_hash for item in x.descriptors),
    registration_hashes=Tuple(item.registration_hash for item in x.registrations),
    registry_hash=x.registry_hash)

function make_repository_owned_provider_manifest(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4, provider_id::AbstractString,
        capability::CapabilitySignatureV4; model_class::AbstractString="test_only")
    validate_trusted_provider_registry(registry)
    validate_forward_chain_context(context)
    descriptor = _tpr_find_descriptor(registry, provider_id)
    _tpr_context_capability(context, descriptor, capability)
    class = _tpr_text(model_class, "provider model class")
    class in descriptor.allowed_model_classes || throw(ArgumentError("provider model class is outside descriptor policy"))
    capability.kind in descriptor.allowed_capability_kinds || throw(ArgumentError("capability kind is outside descriptor policy"))
    ProviderManifestV4(capability.schema, capability.revision, capability.kind,
        capability, _tpr_domain(context, descriptor, capability, class),
        descriptor.provider_id, _TPR_REVISION, descriptor.source_hash,
        "trusted-repository:$(descriptor.provider_id)", screen_only;
        input_schema_hash=capability.input_schema_hash,
        executor=descriptor.executor)
end

function register_trusted_provider(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4, provider_id::AbstractString,
        capability::CapabilitySignatureV4, manifest::ProviderManifestV4)
    validate_trusted_provider_registry(registry)
    descriptor = _tpr_find_descriptor(registry, provider_id)
    _tpr_validate_manifest(descriptor, context, capability, manifest,
        registry.repository_root)
    body = _tpr_registration_body(descriptor, context, capability, manifest)
    registration = TrustedProviderRegistrationV4(_TPR_TOKEN,
        descriptor.descriptor_hash, context, context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        capability, manifest, canonical_hash(body))
    key = (registration.context_hash, canonical_hash(registration.capability))
    any(item -> (item.context_hash, canonical_hash(item.capability)) == key,
        registry.registrations) && throw(ArgumentError("provider capability is already registered for context"))
    registrations = (registry.registrations..., registration)
    registry_body = _tpr_registry_body(registry.repository_identity_hash,
        registry.descriptors, registrations)
    TrustedProviderRegistryV4(_TPR_TOKEN, registry.repository_root,
        registry.repository_identity_hash, registry.descriptors, registrations,
        canonical_hash(registry_body))
end

struct TrustedProviderDispatchRequestV4
    registry_hash::Digest256
    context::ForwardChainContextV4
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    capability::CapabilitySignatureV4
    input::Any
    input_hash::Digest256
    registration::Union{Nothing,TrustedProviderRegistrationV4}
    status::Symbol
    recoverable_gaps::Tuple{Vararg{String}}
    request_hash::Digest256
    function TrustedProviderDispatchRequestV4(token::_TrustedProviderRegistryToken,
            registry_hash::Digest256, context::ForwardChainContextV4,
            context_hash::Digest256, subject_hash::Digest256,
            scenario_hash::Digest256, capability::CapabilitySignatureV4,
            input, input_hash::Digest256,
            registration::Union{Nothing,TrustedProviderRegistrationV4},
            status::Symbol, recoverable_gaps::Tuple{Vararg{String}},
            request_hash::Digest256)
        token === _TPR_TOKEN || throw(ArgumentError("private constructor"))
        new(registry_hash, context, context_hash, subject_hash, scenario_hash,
            capability, input, input_hash, registration, status,
            recoverable_gaps, request_hash)
    end
end

function _tpr_request_components(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4, input)
    validate_trusted_provider_registry(registry)
    validate_forward_chain_context(context)
    descriptor = _tpr_descriptor_for_capability(registry, capability)
    capability_hash = _tpr_context_capability(context, descriptor, capability)
    input_hash = _tpr_validate_dispatch_input(descriptor, context, capability, input)
    matches = Tuple(item for item in registry.registrations
        if item.context_hash == context.context_hash &&
           canonical_hash(item.capability) == capability_hash)
    gaps = String[]
    registration = nothing
    if length(matches) == 1
        registration = only(matches)
    elseif isempty(matches)
        push!(gaps, "trusted_provider_registration_missing")
    else
        push!(gaps, "trusted_provider_registration_ambiguous")
    end
    status = isempty(gaps) ? :ready_for_dispatch : :recoverable_gap
    body = (revision=_TPR_REVISION, registry_hash=registry.registry_hash,
        context_hash=context.context_hash,
        subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash, capability_hash=capability_hash,
        input_hash=input_hash,
        registration_hash=registration === nothing ? nothing : registration.registration_hash,
        status=status, recoverable_gaps=Tuple(gaps))
    (input_hash=input_hash, registration=registration, status=status,
     gaps=Tuple(gaps), request_hash=canonical_hash(body))
end

function build_trusted_provider_dispatch_request(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4, input)
    c = _tpr_request_components(registry, context, capability, input)
    TrustedProviderDispatchRequestV4(_TPR_TOKEN, registry.registry_hash,
        context, context.context_hash, context.subject.physical_subject_hash,
        context.scenario_hash, capability, input, c.input_hash,
        c.registration, c.status, c.gaps, c.request_hash)
end

validate_trusted_provider_dispatch_request(::TrustedProviderDispatchRequestV4) = false

function validate_trusted_provider_dispatch_request(
        request::TrustedProviderDispatchRequestV4,
        registry::TrustedProviderRegistryV4, context::ForwardChainContextV4,
        capability::CapabilitySignatureV4, input)
    try
        expected = build_trusted_provider_dispatch_request(registry, context,
            capability, input)
        request.registry_hash == expected.registry_hash &&
        request.context_hash == expected.context_hash &&
        request.subject_hash == expected.subject_hash &&
        request.scenario_hash == expected.scenario_hash &&
        canonical_hash(request.capability) == canonical_hash(expected.capability) &&
        request.input_hash == expected.input_hash &&
        (request.registration === nothing ? nothing : request.registration.registration_hash) ==
            (expected.registration === nothing ? nothing : expected.registration.registration_hash) &&
        request.status == expected.status &&
        request.recoverable_gaps == expected.recoverable_gaps &&
        request.request_hash == expected.request_hash
    catch
        false
    end
end

canonical_hash(::TrustedProviderDispatchRequestV4) =
    throw(ArgumentError("request hash requires external registry revalidation"))

semantic_view(x::TrustedProviderDispatchRequestV4) = (
    registry_hash=x.registry_hash, context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    capability_hash=canonical_hash(x.capability), input_hash=x.input_hash,
    registration_hash=x.registration === nothing ? nothing : x.registration.registration_hash,
    status=x.status, recoverable_gaps=x.recoverable_gaps,
    request_hash=x.request_hash)

struct TrustedProviderExecutionReceiptV4
    registry_hash::Digest256
    request_hash::Digest256
    registration_hash::Digest256
    provider_manifest_hash::Digest256
    input_hash::Digest256
    output::Any
    output_hash::Digest256
    exit_code::Int
    status::Symbol
    message::String
    receipt_hash::Digest256
    function TrustedProviderExecutionReceiptV4(token::_TrustedProviderRegistryToken,
            registry_hash::Digest256, request_hash::Digest256,
            registration_hash::Digest256, provider_manifest_hash::Digest256,
            input_hash::Digest256, output, output_hash::Digest256,
            exit_code::Int, status::Symbol, message::String,
            receipt_hash::Digest256)
        token === _TPR_TOKEN || throw(ArgumentError("private constructor"))
        new(registry_hash, request_hash, registration_hash,
            provider_manifest_hash, input_hash, output, output_hash,
            exit_code, status, message, receipt_hash)
    end
end

function _tpr_receipt_body(request::TrustedProviderDispatchRequestV4,
        registration::TrustedProviderRegistrationV4, output, output_hash::Digest256,
        exit_code::Int, status::Symbol, message::String)
    (revision=_TPR_REVISION, registry_hash=request.registry_hash,
     request_hash=request.request_hash,
     registration_hash=registration.registration_hash,
     provider_manifest_hash=registration.manifest.manifest_hash,
     input_hash=request.input_hash, output=output, output_hash=output_hash,
     exit_code=exit_code, status=status, message=message)
end

function _tpr_invoke_executor(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4, input)
    if descriptor.provider_id == _TPR_FREEGS_PROVIDER
        return Base.invokelatest(descriptor.executor, context, input)
    end
    Base.invokelatest(descriptor.executor, input)
end

function _tpr_success_tuple(descriptor::RepositoryProviderDescriptorV4,
        context::ForwardChainContextV4, capability::CapabilitySignatureV4,
        input, value)
    is_canonical_value(value) ||
        throw(ArgumentError("executor output is not canonicalizable"))
    if descriptor.provider_id == _TPR_FREEGS_PROVIDER
        value isa TrustedFreeGSAxisymmetricOutputV4 ||
            throw(ArgumentError("trusted FreeGS executor returned the wrong output type"))
        validate_trusted_freegs_axisymmetric_output(value, context, input,
            capability)
        return (value, value.freegs_receipt.exit_code,
            value.freegs_receipt.status,
            "repository FreeGS executor returned a revalidated operational result")
    end
    (value, 0, :completed, "repository executor returned canonical output")
end

function execute_trusted_provider(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4, request::TrustedProviderDispatchRequestV4)
    validate_trusted_provider_dispatch_request(request, registry, context,
        request.capability, request.input) || throw(ArgumentError("invalid dispatch request"))
    request.status === :ready_for_dispatch || throw(ArgumentError("dispatch request is not ready"))
    registration = request.registration::TrustedProviderRegistrationV4
    descriptor = _tpr_find_descriptor(registry, registration.manifest.backend)
    validate_trusted_provider_registration(registration, descriptor,
        registry.repository_root)
    output, exit_code, status, message = try
        value = _tpr_invoke_executor(descriptor, context, request.input)
        _tpr_success_tuple(descriptor, context, request.capability,
            request.input, value)
    catch error
        failure = (error_type=string(typeof(error)), message=sprint(showerror, error))
        (failure, 1, :executor_error, "repository executor raised an error")
    end
    output_hash = canonical_hash(output)
    body = _tpr_receipt_body(request, registration, output, output_hash,
        exit_code, status, message)
    TrustedProviderExecutionReceiptV4(_TPR_TOKEN, request.registry_hash,
        request.request_hash, registration.registration_hash,
        registration.manifest.manifest_hash, request.input_hash, output,
        output_hash, exit_code, status, message, canonical_hash(body))
end

validate_trusted_provider_execution_receipt(::TrustedProviderExecutionReceiptV4) = false

function validate_trusted_provider_execution_receipt(
        receipt::TrustedProviderExecutionReceiptV4,
        request::TrustedProviderDispatchRequestV4,
        registry::TrustedProviderRegistryV4, context::ForwardChainContextV4)
    try
        validate_trusted_provider_dispatch_request(request, registry, context,
            request.capability, request.input) || return false
        request.status === :ready_for_dispatch || return false
        registration = request.registration::TrustedProviderRegistrationV4
        receipt.registry_hash == registry.registry_hash || return false
        receipt.request_hash == request.request_hash || return false
        receipt.registration_hash == registration.registration_hash || return false
        receipt.provider_manifest_hash == registration.manifest.manifest_hash || return false
        receipt.input_hash == request.input_hash || return false
        is_canonical_value(receipt.output) || return false
        canonical_hash(receipt.output) == receipt.output_hash || return false
        descriptor = _tpr_find_descriptor(registry, registration.manifest.backend)
        if receipt.status === :executor_error
            receipt.exit_code != 0 || return false
        elseif descriptor.provider_id == _TPR_FREEGS_PROVIDER
            receipt.output isa TrustedFreeGSAxisymmetricOutputV4 || return false
            validate_trusted_freegs_axisymmetric_output(receipt.output, context,
                request.input, request.capability)
            receipt.status == receipt.output.freegs_receipt.status || return false
            receipt.exit_code == receipt.output.freegs_receipt.exit_code || return false
        else
            receipt.status === :completed && receipt.exit_code == 0 || return false
        end
        expected = canonical_hash(_tpr_receipt_body(request, registration,
            receipt.output, receipt.output_hash, receipt.exit_code,
            receipt.status, receipt.message))
        receipt.receipt_hash == expected
    catch
        false
    end
end

semantic_view(x::TrustedProviderExecutionReceiptV4) = (
    registry_hash=x.registry_hash, request_hash=x.request_hash,
    registration_hash=x.registration_hash,
    provider_manifest_hash=x.provider_manifest_hash,
    input_hash=x.input_hash, output_hash=x.output_hash,
    exit_code=x.exit_code, status=x.status, message=x.message,
    receipt_hash=x.receipt_hash)

trusted_provider_registry_manifest() = (
    schema=_TPR_SCHEMA, revision=_TPR_REVISION,
    purpose=:repository_executor_trust_and_operational_receipts,
    request_statuses=(:ready_for_dispatch, :recoverable_gap),
    receipt_statuses=(:completed, :physical_model_screen,
        :recoverable_gap_unknown, :executor_error),
    accepts_caller_provider_descriptors=false,
    accepts_caller_executors=false, emits_evidence=false,
    physical_validation_credit=0, closure_authority=false,
    promotion_authority=false, terminal_authority=false,
    credible_physical_candidate_count=0, p5_ready=false)
