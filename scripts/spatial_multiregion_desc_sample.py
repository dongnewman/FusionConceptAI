"""Fresh DESC geometry/initialization for a full-torus spatial field solve.

The sampler does not supply currents or derivatives of the solved field. Axis
nodes are sampled exactly but their singular metric is never inverted. All
non-axis unique faces are sampled exactly, with positive-coordinate normals.
"""
import csv
import hashlib
import importlib.metadata
import json
import os
import platform
import sys
import math
from fractions import Fraction
from pathlib import Path

import numpy as np
import desc
import jax
from desc.compute import data_index
from desc.grid import Grid
from desc.io import load

HEADER = ("entity_id,qp_id,rho,theta,zeta,x_m,y_m,z_m,R_m,phi_rad,weight,detE,"
          "nx,ny,nz," + ",".join(f"E{i}{j}" for i in range(1, 4) for j in range(1, 4)) + "," +
          ",".join(f"I{i}{j}" for i in range(1, 4) for j in range(1, 4)) + ",BR_T,Bphi_T,BZ_T,p_Pa")


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def tree_digest(root):
    root = Path(root)
    return hashlib.sha256("".join(f"{p.relative_to(root).as_posix()}\t{digest(p)}\n"
        for p in sorted(root.rglob("*.py"))).encode()).hexdigest()


def distribution_records(module_name):
    names = importlib.metadata.packages_distributions().get(module_name, ())
    if not names:
        raise RuntimeError(f"No installed distribution owns module {module_name}")
    matches = []
    for name in names:
        dist = importlib.metadata.distribution(name)
        files = tuple(dist.files or ())
        metadata = [dist.locate_file(p).resolve() for p in files if p.name == "METADATA" and ".dist-info" in p.as_posix()]
        record = [dist.locate_file(p).resolve() for p in files if p.name == "RECORD" and ".dist-info" in p.as_posix()]
        if len(metadata) == 1 and len(record) == 1:
            matches.append((name, dist.version, metadata[0], record[0]))
    if len(matches) != 1:
        raise RuntimeError(f"Expected one complete installed distribution record for {module_name}, found {len(matches)}")
    return matches[0]


def write_continuous_R_bound(eq, path):
    """Triangle bound over every rho/theta/zeta, with exact stored-float arithmetic.

    DESC FourierZernikeBasis.evaluate is radial * poloidal * toroidal;
    the angular factors have modulus <=1. The radial coefficient formula is
    independently implemented with exact integers, not inferred from samples.
    """
    if type(eq.R_basis).__name__ != "FourierZernikeBasis":
        raise ValueError("Continuous R enclosure requires the audited FourierZernikeBasis")
    total=Fraction(0);rows=[]
    for mode,coefficient in zip(np.asarray(eq.R_basis.modes),np.asarray(eq.R_lmn)):
        l,m,n=map(int,mode);a=abs(m);c=float(coefficient)
        if not math.isfinite(c) or l<a or (l-a)%2: raise ValueError("Invalid radial geometry mode")
        radial=0
        for s in range((l-a)//2+1):
            numerator=math.factorial(l-s)
            denominator=math.factorial(s)*math.factorial((l+a)//2-s)*math.factorial((l-a)//2-s)
            term,remainder=divmod(numerator,denominator)
            if remainder: raise ValueError("Nonintegral Zernike coefficient")
            radial+=term
        total+=abs(Fraction.from_float(c))*radial
        rows.append((l,m,n,c,radial))
    bound=math.nextafter(float(total),math.inf)
    if Fraction.from_float(bound)<total: raise ValueError("R bound rounded downward")
    with open(path,"w",encoding="utf-8",newline="") as out:
        w=csv.writer(out,lineterminator="\n");w.writerow(("l","m","n","R_lmn_m","radial_abs_coefficient_sum"));w.writerows(rows)
    return bound,len(rows)


def build_mesh(rhos, nt, nz):
    nodes, ids, cells, faces = [], {}, [], []
    nr = len(rhos) - 1
    for iz in range(nz):
        for ir, rho in enumerate(rhos):
            for it in range(1 if ir == 0 else nt):
                ids[ir, it, iz] = len(nodes) + 1
                nodes.append((rho, it * 2*np.pi/nt, iz * 2*np.pi/nz))
    cid = {}
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                cid[ir, it, iz] = len(cells) + 1
                cells.append(((rhos[ir], rhos[ir+1]), (it*2*np.pi/nt, (it+1)*2*np.pi/nt),
                              (iz*2*np.pi/nz, (iz+1)*2*np.pi/nz)))
    # All normals point along increasing chart coordinate; left cell owns +n.
    for iz in range(nz):
        for ir in range(1, nr+1):
            for it in range(nt):
                faces.append((1, rhos[ir], cid[ir-1,it,iz], cid[ir,it,iz] if ir<nr else 0,
                    (it*2*np.pi/nt,(it+1)*2*np.pi/nt), (iz*2*np.pi/nz,(iz+1)*2*np.pi/nz)))
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                faces.append((2,it*2*np.pi/nt,cid[ir,(it-1)%nt,iz],cid[ir,it,iz],
                              (rhos[ir],rhos[ir+1]),(iz*2*np.pi/nz,(iz+1)*2*np.pi/nz)))
    for iz in range(nz):
        for ir in range(nr):
            for it in range(nt):
                faces.append((3,iz*2*np.pi/nz,cid[ir,it,(iz-1)%nz],cid[ir,it,iz],
                              (rhos[ir],rhos[ir+1]),(it*2*np.pi/nt,(it+1)*2*np.pi/nt)))
    return nodes, cells, faces


def sample_sets(rhos, nt, nz, order):
    nodes, cells, faces = build_mesh(rhos, nt, nz)
    roots, weights = np.polynomial.legendre.leggauss(order)
    sets = {"nodes": [(i+1, 1, q, 0., 0) for i,q in enumerate(nodes)], "volume": [], "faces": []}
    for cid, bounds in enumerate(cells, 1):
        qp = 0
        for iz in range(order):
            for it in range(order):
                for ir in range(order):
                    ix = (ir,it,iz); qp += 1
                    q = tuple((lo+hi)/2+roots[j]*(hi-lo)/2 for j,(lo,hi) in zip(ix,bounds))
                    w = float(np.prod([weights[j]*(hi-lo)/2 for j,(lo,hi) in zip(ix,bounds)]))
                    sets["volume"].append((cid,qp,q,w,0))
    for fid,(axis,fixed,left,right,b1,b2) in enumerate(faces, 1):
        qp = 0
        for j in range(order):
            for i in range(order):
                v1=(sum(b1)+roots[i]*(b1[1]-b1[0]))/2
                v2=(sum(b2)+roots[j]*(b2[1]-b2[0]))/2
                q = (fixed,v1,v2) if axis==1 else ((v1,fixed,v2) if axis==2 else (v1,v2,fixed))
                w=weights[i]*weights[j]*(b1[1]-b1[0])*(b2[1]-b2[0])/4
                qp += 1; sets["faces"].append((fid,qp,q,float(w),axis))
    return sets


def write_set(eq, rows, kind, path):
    keys=["R","phi","Z","B","p"]
    if kind != "nodes": keys += ["e_rho","e_theta","e_zeta"]
    grid=Grid(np.asarray([r[2] for r in rows]),coordinates="rtz",NFP=int(eq.NFP),sort=False)
    result=eq.compute(keys,grid=grid)
    data={k:np.asarray(result[k],dtype=float) for k in keys}
    if any(len(v)!=len(rows) or not np.isfinite(v).all() for v in data.values()):
        raise ValueError("Nonfinite/missing real DESC samples")
    with open(path,"w",encoding="utf-8",newline="") as out:
        writer=csv.writer(out,lineterminator="\n");writer.writerow(HEADER.split(","))
        for i,(entity,qp,q,qweight,axis) in enumerate(rows):
            R,phi,Z=map(float,(data["R"][i],data["phi"][i],data["Z"][i]))
            if R<=0: raise ValueError("Cylindrical chart R must be positive")
            rot=np.array([[np.cos(phi),-np.sin(phi),0],[np.sin(phi),np.cos(phi),0],[0,0,1.]])
            E=np.zeros((3,3)); inverse=E.copy();det=0.;weight=0.;normal=np.zeros(3)
            if kind!="nodes":
                E=np.column_stack([data[k][i] for k in ("e_rho","e_theta","e_zeta")])
                det=float(np.linalg.det(E))
                if abs(det)<1e-14: raise ValueError("Singular non-axis quadrature metric")
                inverse=np.linalg.inv(E)
                if kind=="volume": weight=qweight*abs(det)
                else:
                    dual=inverse[axis-1,:];normal=rot@(dual/np.linalg.norm(dual))
                    others=[j for j in range(3) if j!=axis-1]
                    weight=qweight*np.linalg.norm(np.cross(E[:,others[0]],E[:,others[1]]))
            writer.writerow([entity,qp,*q,R*np.cos(phi),R*np.sin(phi),Z,R,phi,weight,det,
                             *normal,*E.flatten(),*inverse.flatten(),*data["B"][i],float(data["p"][i])])


def main():
    h5,request_path,output_dir,expected_module=sys.argv[1:]
    req=dict(line.rstrip("\n").split("\t",1) for line in open(request_path,encoding="utf-8"))
    if digest(h5)!=req["hdf5_sha256"]: raise ValueError("HDF5 identity mismatch")
    if Path(desc.__file__).resolve()!=Path(expected_module).resolve(): raise ValueError("DESC module mismatch")
    metadata=data_index["desc.equilibrium.equilibrium.Equilibrium"]
    for key,unit,dim in (("B","T",3),("p","Pa",1),("e_rho","m",3),("e_theta","m",3),("e_zeta","m",3)):
        if (metadata[key]["units"],metadata[key]["dim"])!=(unit,dim): raise ValueError("DESC units mismatch")
    eq=load(h5);nfp=int(eq.NFP)
    if nfp!=int(req["nfp"]): raise ValueError("Candidate NFP mismatch")
    directory=Path(output_dir);directory.mkdir(parents=True,exist_ok=True)
    bound_path=directory/"continuous_R_bound.csv"
    R_upper,bound_count=write_continuous_R_bound(eq,bound_path)
    dist_name,dist_version,dist_metadata,dist_record=distribution_records("desc")
    thread_environment={key:os.environ.get(key) for key in
        ("JULIA_NUM_THREADS","OMP_NUM_THREADS","OPENBLAS_NUM_THREADS","MKL_NUM_THREADS","NUMEXPR_NUM_THREADS",
         "JAX_NUM_THREADS","JAX_PLATFORMS","XLA_FLAGS")}
    devices=[dict(platform=d.platform,device_kind=d.device_kind,id=d.id,process_index=d.process_index)
             for d in jax.devices()]
    meta=dict(req,schema="spatial-desc-geometry-v1",python_executable=str(Path(sys.executable).resolve()),
              python_implementation=platform.python_implementation(),python_version=sys.version.split()[0],
              platform=platform.platform(),machine=platform.machine(),processor=platform.processor() or "unknown",
              logical_cpu_count=str(os.cpu_count() or 0),thread_environment_json=json.dumps(thread_environment,sort_keys=True,separators=(",",":")),
              numpy_version=np.__version__,
              desc_version=desc.__version__,jax_version=importlib.metadata.version("jax"),
              jaxlib_version=importlib.metadata.version("jaxlib"),jax_backend=jax.default_backend(),
              jax_enable_x64=str(bool(jax.config.x64_enabled)).lower(),jax_devices_json=json.dumps(devices,sort_keys=True,separators=(",",":")),
              desc_distribution_name=dist_name,desc_distribution_version=dist_version,
              desc_distribution_metadata_path=str(dist_metadata),desc_distribution_metadata_sha256=digest(dist_metadata),
              desc_distribution_record_path=str(dist_record),desc_distribution_record_sha256=digest(dist_record),
              desc_source_tree_sha256=tree_digest(Path(desc.__file__).parent),
              actual_axis="exact_nodes_no_metric_inverse",actual_faces="exact_no_offsets",solved_current_provider="none",
              continuous_R_upper_m=repr(R_upper),continuous_R_bound_method="exact_stored_float_Zernike_monomial_triangle",
              continuous_R_bound_basis="FourierZernikeBasis")
    for level,rhos,nt,nz in (("coarse",(0.,.5,1.),4,2*nfp),("fine",(0.,.25,.5,.75,1.),8,4*nfp)):
        meta[f"{level}_radial_bound_sha256"]=digest(bound_path);meta[f"{level}_radial_bound_count"]=str(bound_count)
        for kind,rows in sample_sets(rhos,nt,nz,int(req["quadrature_order"])).items():
            path=directory/f"{level}_{kind}.csv"
            write_set(eq,rows,kind,path)
            meta[f"{level}_{kind}_sha256"]=digest(path);meta[f"{level}_{kind}_count"]=str(len(rows))
            print(f"{level} {kind} rows={len(rows)} sha256={digest(path)}",flush=True)
    with open(directory/"metadata.tsv","w",encoding="utf-8",newline="\n") as out:
        out.write("".join(f"{k}\t{v}\n" for k,v in meta.items()))
    print("sampler_exit_code=0",flush=True)


if __name__=="__main__":
    main()
