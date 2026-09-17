# UP4 inverse request contract R4

Bounded contract-only repair for the external conversion boundary. R4 routes
`AbstractString -> String` through the typed checked-conversion seam, adds a
real failing `AbstractString` conversion vector, and uses an exact
`typeof(error) === InverseExternalInputError` admission guard.

No Julia/DESC/provider/solver execution was performed. This slice does not
promote UP4 or any R01–R10 gate.
