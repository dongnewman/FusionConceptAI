# Validate resume identity before any existing run artifact is written.
function verify_revised_checkpoint_identity_v4(path::AbstractString, expected::AbstractString)
    isfile(path) || throw(ArgumentError("resume requires the original candidate identity artifact"))
    read(path,String)==expected || throw(ArgumentError("resume candidate identity differs; original run preserved"))
    true
end
