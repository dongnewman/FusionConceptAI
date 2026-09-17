"""Small, dependency-free evidence primitives for UP1 external closure.

The package is intentionally independent from the FusionConceptAI runtime and
from all network, clock, trust-store, and credential facilities.  It provides
only deterministic serialization, identity, bounded file inspection, and
receipt construction; callers remain responsible for external attestations.
"""

from .canonical import (
    CANONICALIZATION_VERSION,
    DuplicateKeyError,
    NonCanonicalJSONError,
    InvalidUTF8Error,
    SyntaxJSONError,
    NonFiniteNumberError,
    NonCanonicalNumberError,
    CyclicValueError,
    UnsupportedValueError,
    canonical_json,
    canonical_json_bytes,
    canonical_bytes,
    parse_json,
    parse_canonical_json,
)
from .identity import (
    ContentIdentity,
    Fingerprint,
    content_identity,
    digest_bytes,
    digest_json,
    canonical_digest,
    sha256_json,
    sha256_hex,
)
from .taxonomy import (
    ErrorCode,
    EvidenceError,
    Status,
    TypedError,
)
from .files import (
    MAX_FILE_BYTES,
    SafeFileError,
    read_bytes_limited,
    read_json_file,
    safe_relative_path,
)
from .manifest import (
    ManifestCheck,
    ManifestError,
    verify_exact_set,
    verify_manifest,
    check_exact_set,
)
from .fingerprint import (
    candidate_fingerprint,
    source_fingerprint,
    typed_fingerprint,
)
from .receipt import (
    RECEIPT_SCHEMA_VERSION,
    build_receipt,
    build_deterministic_receipt,
    receipt_digest,
)

__all__ = [
    "CANONICALIZATION_VERSION", "DuplicateKeyError", "NonCanonicalJSONError",
    "InvalidUTF8Error", "SyntaxJSONError", "NonFiniteNumberError",
    "NonCanonicalNumberError", "CyclicValueError", "UnsupportedValueError",
    "canonical_json", "canonical_json_bytes", "canonical_bytes", "parse_json", "parse_canonical_json",
    "ContentIdentity", "Fingerprint", "content_identity", "digest_bytes",
    "digest_json", "canonical_digest", "sha256_json", "sha256_hex", "ErrorCode", "EvidenceError", "Status",
    "TypedError", "MAX_FILE_BYTES", "SafeFileError", "read_bytes_limited",
    "read_json_file", "safe_relative_path", "ManifestCheck", "ManifestError",
    "verify_exact_set", "verify_manifest", "check_exact_set", "candidate_fingerprint",
    "source_fingerprint", "typed_fingerprint", "RECEIPT_SCHEMA_VERSION",
    "build_receipt", "build_deterministic_receipt", "receipt_digest",
]
