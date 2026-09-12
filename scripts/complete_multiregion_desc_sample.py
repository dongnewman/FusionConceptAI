"""Read the freshly bound DESC equilibrium; emit exact-surface and volume data.

No nonlinear solve occurs here. Cartesian tensors/vectors are explicitly rotated
through every field period. Surface measures use e_theta cross e_zeta AT rho=.5/1,
never finite radial offsets. TSV rows are the independent oracle's raw inputs.
"""
import csv
import hashlib
import importlib.metadata
import sys
from pathlib import Path

import numpy as np
import desc
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_tree_digest(root):
    """Bind the actual DESC Python algorithms, not only its __init__ file."""
    root = Path(root)
    manifest = "".join(f"{p.relative_to(root).as_posix()}\t{digest(p)}\n" for p in sorted(root.rglob("*.py")))
    return hashlib.sha256(manifest.encode("utf-8")).hexdigest()


def main():
    h5, request_path, output_path, metadata_path, expected_module = sys.argv[1:]
    request = dict(line.rstrip("\n").split("\t") for line in open(request_path, encoding="utf-8"))
    # Julia Digest256 displays as its hex value in this repository.
    if request["hdf5_sha256"] != digest(h5):
        raise ValueError("fresh upstream HDF5 hash mismatch")
    if Path(desc.__file__).resolve() != Path(expected_module).resolve():
        raise ValueError("DESC module path changed")
    eq = load(h5)
    nfp = int(eq.NFP)
    nr, nt, nz = (int(request[k]) for k in ("radial_order", "theta_count", "zeta_count"))
    roots, weights = np.polynomial.legendre.leggauss(nr)
    theta = np.arange(nt) * 2 * np.pi / nt
    zeta = np.arange(nz) * 2 * np.pi / (nfp * nz)
    nodes, tags = [], []
    for region, (lo, hi) in enumerate(((0.0, 0.5), (0.5, 1.0)), 1):
        for r, w in zip((lo + hi) / 2 + roots * (hi - lo) / 2, weights * (hi - lo) / 2):
            for t in theta:
                for z in zeta:
                    nodes.append((r, t, z)); tags.append(("volume", region, w * 2*np.pi/nt * 2*np.pi/(nfp*nz)))
    for kind, r in (("interface", 0.5), ("exterior", 1.0)):
        for t in theta:
            for z in zeta:
                nodes.append((r, t, z)); tags.append((kind, 1 if kind == "interface" else 2, 2*np.pi/nt * 2*np.pi/(nfp*nz)))
    keys = ["R", "phi", "Z", "B", "p", "J", "grad(p)", "sqrt(g)", "e_rho", "e_theta", "e_zeta"]
    expected = {"B": ("T", 3), "p": ("Pa", 1), "J": (r"A \cdot m^{-2}", 3),
                "grad(p)": (r"N \cdot m^{-3}", 3), "sqrt(g)": ("m^{3}", 1),
                "e_rho": ("m", 3), "e_theta": ("m", 3), "e_zeta": ("m", 3)}
    metadata = data_index["desc.equilibrium.equilibrium.Equilibrium"]
    for key, signature in expected.items():
        if (metadata[key]["units"], metadata[key]["dim"]) != signature:
            raise ValueError("DESC units/dimensions mismatch for " + key)
    grid = Grid(np.asarray(nodes), coordinates="rtz", NFP=nfp, sort=False)
    data = {k: np.asarray(v, dtype=float) for k, v in eq.compute(keys, grid=grid).items() if k in keys}
    for key in keys:
        if len(data[key]) != len(nodes) or not np.all(np.isfinite(data[key])):
            raise ValueError("invalid computed data " + key)
    headers = "kind region rho theta zeta x y z Bx By Bz p Jx Jy Jz gradpx gradpy gradpz nx ny nz measure".split()
    count = 0
    with open(output_path, "w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(headers)
        for i, ((rho, t, z), (kind, region, qweight)) in enumerate(zip(nodes, tags)):
            phi = float(data["phi"][i]); R = float(data["R"][i]); Z = float(data["Z"][i])
            area = np.cross(data["e_theta"][i], data["e_zeta"][i])
            if np.dot(area, data["e_rho"][i]) < 0: area = -area
            area_norm = np.linalg.norm(area)
            if area_norm <= 0 or abs(float(data["sqrt(g)"][i])) <= 0:
                raise ValueError("singular chart in non-axis quadrature")
            normal = area / area_norm if kind != "volume" else np.zeros(3)
            measure = qweight * (abs(float(data["sqrt(g)"][i])) if kind == "volume" else area_norm)
            for period in range(nfp):
                angle = phi + 2*np.pi*period/nfp
                rot = np.array([[np.cos(angle), -np.sin(angle), 0], [np.sin(angle), np.cos(angle), 0], [0, 0, 1]])
                xyz = np.array([R*np.cos(angle), R*np.sin(angle), Z])
                writer.writerow([kind, region, rho, t, z+2*np.pi*period/nfp,
                    *xyz, *(rot@data["B"][i]), float(data["p"][i]), *(rot@data["J"][i]),
                    *(rot@data["grad(p)"][i]), *(rot@normal), measure])
                count += 1
    outmeta = dict(request, schema="complete-multiregion-sample-v1", desc_version=desc.__version__,
        python_version=sys.version.split()[0], nfp=str(nfp), sample_count=str(count),
        numpy_version=np.__version__, jax_version=importlib.metadata.version("jax"),
        jaxlib_version=importlib.metadata.version("jaxlib"),
        desc_source_tree_sha256=source_tree_digest(Path(desc.__file__).parent),
        output_sha256=digest(output_path), hdf5_path=str(Path(h5).resolve()),
        surface_evaluation="exact_rho_0.5_and_1.0", basis="Cartesian_SI", finite_offsets="false")
    with open(metadata_path, "w", encoding="utf-8", newline="\n") as stream:
        stream.write("".join(f"{k}\t{v}\n" for k,v in outmeta.items()))
    print(f"sample_count={count} nfp={nfp} exact_surfaces=true exit_code=0", flush=True)


if __name__ == "__main__":
    main()
