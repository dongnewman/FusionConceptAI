# G-I0 bounded diff

The dispatch supplied the protected before hashes for the two dirty source files:

| file | before SHA256 | after SHA256 | change |
|---|---|---|---|
| `src/FusionConceptAI.jl` | `aada5bca0ce68c605826ee57fe357a552336869503b5dcd21383112649a1d4d8` | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` | one UP2 entry include and additive UP2 API exports |
| `src/GenomeV5/Integration/GenomeV5Integration.jl` | `243b272df7e481b2578c1f95c49bcd2582fa7468eade81eebea86ce2d079fb78` | `391a7f32ce22c73244ac41f0d6e5c321e98931649491d3fd3a52f907ffaf44c4` | one additive `genome_v5_component_layer_order()` registration |

The first file already contained pre-existing V5 include/export changes at the before boundary. The G-I0 additions are the UP2 include and the three UP2 loader/status exports. The second file is an existing dirty V5 integration file; G-I0 adds only the documented order accessor. Exact current bytes, sizes, mtime, and protected dirty status are in `after_snapshot.json`. Core-document before bytes were not supplied and are therefore not presented as recoverable historical hashes; their current after hashes are recorded there.

New owned files are `src/GenomeV5/UP2/UP2ModuleEntryV1.jl`, `test/GenomeV5/UP2/up2_module_entry_tests.jl`, `test/GenomeV5/UP2/run_up2_module_entry.jl`, and this archive. No existing V4 source, default operator registry, E1/E2 source/test/archive, or unrelated dirty path was edited.
