"""Independent Q1/curved-coordinate weak and strong residual oracle.

Reads content-bound raw geometry, never imports the Julia implementation or DESC.
Manufactured states are software benchmarks and never accepted candidate states.
Run: python spatial_verification_oracle_v4.py oracle_input.json output_directory
"""
from __future__ import annotations
import csv
import hashlib
import json
import math
import pathlib
import platform
import sys
import numpy as np


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def geometry(artifact):
    path = artifact["path"]
    digest = artifact["sha256"]
    if isinstance(digest, dict):
        digest = digest["value"]
    if sha(path) != digest:
        raise ValueError("Raw geometry content binding mismatch: " + path)
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))
    if len(rows) != artifact["row_count"]:
        raise ValueError("Raw geometry row count mismatch")
    out = []
    for r in rows:
        v = {k: float(z) for k, z in r.items()}
        s = dict(cell=int(v["entity_id"])-1, qp=int(v["qp_id"]),
                 q=np.array([v[k] for k in ("rho", "theta", "zeta")]),
                 xyz=np.array([v[k] for k in ("x_m", "y_m", "z_m")]),
                 R=v["R_m"], phi=v["phi_rad"], w=v["weight"],
                 normal=np.array([v[k] for k in ("nx", "ny", "nz")]),
                 E=np.array([[v[f"E{i}{j}"] for j in range(1,4)] for i in range(1,4)]),
                 inverse=np.array([[v[f"I{i}{j}"] for j in range(1,4)] for i in range(1,4)]),
                 B=np.array([v[k] for k in ("BR_T", "Bphi_T", "BZ_T")]), p=v["p_Pa"])
        c, z = math.cos(s["phi"]), math.sin(s["phi"])
        s["rot"] = np.array([[c,-z,0.],[z,c,0.],[0.,0.,1.]])
        if not all(math.isfinite(z) for z in v.values()):
            raise ValueError("Non-finite raw geometry")
        out.append(s)
    return out


class Oracle:
    def __init__(self, req):
        self.req = req
        self.mesh = req["mesh"]
        self.cells = [np.array(x, dtype=int)-1 for x in self.mesh["cell_nodes"]]
        self.maps = [np.array(x, dtype=int)-1 for x in self.mesh["corner_to_local"]]
        self.bounds = np.asarray(self.mesh["cell_bounds"])
        self.starts = np.array(self.mesh["cell_row_start"], dtype=int)-1
        self.ext = {int(x["face"])-1: int(x["row"])-1 for x in self.mesh["exterior_row_start"]}
        self.faces = self.mesh["faces"]
        self.nodes = geometry(req["raw_artifacts"]["nodes"])
        self.vol = geometry(req["raw_artifacts"]["volume"])
        self.faceq = geometry(req["raw_artifacts"]["faces"])
        self.mu = req["mu0"]
        self.blocks = req["row_blocks"]
        self.scales = np.asarray(req["row_scales"])
        self.nrows = len(self.blocks)
        self.nstate = 4*len(self.nodes)
        self.B0 = np.array(req["manufactured"]["B0_T"])
        self.slopes = np.array(req["manufactured"]["cross_slopes_T_m"])
        self.kp = np.array(req["manufactured"]["pressure_gradient_Pa_m"])
        self.p0 = req["manufactured"]["pressure_offset_Pa"]
        self.basis_cache = {}

    def basis(self, cell, s):
        key = (cell, tuple(s["q"]))
        if key in self.basis_cache:
            return self.basis_cache[key]
        box = self.bounds[cell]
        h = box[:,1]-box[:,0]
        local = s["q"]-box[:,0]
        for a in (1,2):
            if local[a] < -1e-10:
                local[a] += 2*math.pi
        u = local/h
        u[np.abs(u)<1e-12] = 0.
        u[np.abs(u-1)<1e-12] = 1.
        if np.min(u) < -1e-8 or np.max(u) > 1+1e-8:
            raise ValueError("Independent basis point outside cell")
        N = np.zeros(len(self.cells[cell]))
        D = np.zeros((len(N),3))
        for corner in range(8):
            bits = [(corner >> a)&1 for a in range(3)]
            factors = [u[a] if bits[a] else 1-u[a] for a in range(3)]
            slot = self.maps[cell][corner]
            N[slot] += math.prod(factors)
            for a in range(3):
                D[slot,a] += (1 if bits[a] else -1)/h[a]*math.prod(factors[b] for b in range(3) if b != a)
        grad = D @ s["inverse"] @ s["rot"].T
        value = N, D, grad
        self.basis_cache[key] = value
        return value

    def stress(self, B, p):
        return np.outer(B,B)/self.mu - (B@B/(2*self.mu)+p)*np.eye(3)

    def analytic(self, xyz):
        alpha,beta,gamma = self.slopes
        B = self.B0 + np.array([alpha*xyz[1], beta*xyz[2], gamma*xyz[0]])
        p = self.p0 + self.kp@xyz
        J = np.array([-beta,-gamma,-alpha])/self.mu
        source = np.cross(J,B)-self.kp
        return dict(B=B,p=p,J=J,div=0.,gradp=self.kp,T=self.stress(B,p),source=source)

    def field(self, cell, s, state, exact=False):
        if exact:
            return self.analytic(s["xyz"])
        N,D,_ = self.basis(cell,s)
        values = state.reshape(-1,4)[self.cells[cell]]
        value = N@values
        gradient_q = values[:,:3].T@D
        # Differentiate the moving cylindrical basis before Cartesian rotation.
        dphi = s["E"][1,:]/s["R"]
        gradient_cyl = (gradient_q + np.outer([-value[1],value[0],0.],dphi))@s["inverse"]
        curl = np.array([gradient_cyl[2,1]-gradient_cyl[1,2],
                         gradient_cyl[0,2]-gradient_cyl[2,0],
                         gradient_cyl[1,0]-gradient_cyl[0,1]])
        B = s["rot"]@value[:3]
        return dict(B=B,p=value[3],J=s["rot"]@curl/self.mu,
                    div=float(np.trace(gradient_cyl)),
                    gradp=(values[:,3]@D)@s["inverse"]@s["rot"].T,
                    T=self.stress(B,value[3]))

    def mms_state(self):
        values = []
        for s in self.nodes:
            f = self.analytic(s["xyz"])
            values.extend(s["rot"].T@f["B"])
            values.append(f["p"])
        return np.array(values)

    def mms_flux(self):
        return math.fsum(s["w"]*(self.analytic(s["xyz"])["B"]@s["normal"])
                         for s in self.faceq if self.faces[s["cell"]]["axis"] == 3 and self.faces[s["cell"]]["fixed"] == 0.)

    def assemble(self, state, target_flux, manufactured=False, exact=False):
        weak = np.zeros(self.nrows)
        strong = np.zeros(self.nrows)
        omitted_div_term = np.zeros(self.nrows)
        flux_jac = np.zeros(self.nstate)
        field_errors = np.zeros(4)
        source_squared_norm = 0.
        total_volume = 0.
        trace_max = 0.
        for s in self.vol:
            c = s["cell"]
            N,_,grad = self.basis(c,s)
            f = self.field(c,s,state,exact)
            rhs = self.analytic(s["xyz"])["source"] if manufactured else np.zeros(3)
            force_without_div = np.cross(f["J"],f["B"])-f["gradp"]-rhs
            divterm = f["B"]*f["div"]/self.mu
            force = force_without_div+divterm
            for a in range(len(N)):
                row = self.starts[c]+4*a
                weak[row:row+3] -= s["w"]*(f["T"]@grad[a]+N[a]*rhs)
                weak[row+3] -= s["w"]*(grad[a]@f["B"])
                strong[row:row+3] += s["w"]*N[a]*force
                strong[row+3] += s["w"]*N[a]*f["div"]
                omitted_div_term[row:row+3] += s["w"]*N[a]*divterm
            if manufactured:
                analytical = self.analytic(s["xyz"])
                field_errors += s["w"]*np.array([np.sum((f["B"]-analytical["B"])**2),
                    (f["p"]-analytical["p"])**2,np.sum((f["J"]-analytical["J"])**2), f["div"]**2])
                source_squared_norm += s["w"]*(rhs@rhs)
            total_volume += s["w"]
        for s in self.faceq:
            face = self.faces[s["cell"]]
            left,right = face["left_cell"]-1,face["right_cell"]-1
            fl = self.field(left,s,state,exact)
            n = s["normal"]
            exterior = face["role"] == "exterior"
            if exterior:
                ref = self.analytic(s["xyz"]) if manufactured else dict(T=self.stress(s["rot"]@s["B"],s["p"]))
                traction = ref["T"]@n
                bn = ref["B"]@n if manufactured else 0.
            else:
                traction,bn = fl["T"]@n,fl["B"]@n
            for c,sign in ((left,1.),(right,-1.)):
                if c < 0:
                    continue
                N,_,_ = self.basis(c,s)
                f = fl if c == left else self.field(c,s,state,exact)
                trace_max = max(trace_max,float(np.linalg.norm(f["B"]-fl["B"])))
                for a in range(len(N)):
                    row = self.starts[c]+4*a
                    w = s["w"]*sign*N[a]
                    weak[row:row+3] += w*traction
                    weak[row+3] += w*bn
                    # Strong form boundary correction uses numerical minus own flux.
                    strong[row:row+3] += w*(traction-f["T"]@n)
                    strong[row+3] += w*(bn-f["B"]@n)
            if exterior:
                N,_,_ = self.basis(left,s)
                trace = [a for a,node in enumerate(self.cells[left]) if self.nodes[node]["q"][0] == 1.]
                for a,j in enumerate(trace):
                    row = self.ext[s["cell"]]+4*a
                    w = s["w"]*N[j]
                    weak[row:row+3] += w*(fl["T"]@n-traction)
                    weak[row+3] += w*(fl["B"]@n-bn)
                    strong[row:row+4] = weak[row:row+4]
            if face["axis"] == 3 and face["fixed"] == 0.:
                weak[-1] += s["w"]*(fl["B"]@n)
                N,_,_ = self.basis(left,s)
                for j,node in enumerate(self.cells[left]):
                    flux_jac[4*node:4*node+3] += s["w"]*N[j]*(n@s["rot"])
        weak[-1] -= target_flux
        strong[-1] = weak[-1]
        report = dict(blocks={},maximum_shared_trace_difference_T=trace_max,
                      B_divB_term_momentum_norm_N=float(np.linalg.norm(omitted_div_term)),
                      source_weighted_l2_N_per_m3_sqrt_m3=float(math.sqrt(max(source_squared_norm,0.))),
                      field_rms_errors=dict(zip(("B_T","p_Pa","J_A_m2","divB_T_m"),np.sqrt(field_errors/total_volume).tolist())))
        for block in dict.fromkeys(self.blocks):
            ids = np.array([k for k,b in enumerate(self.blocks) if b == block])
            report["blocks"][block] = dict(weak_norm=float(np.linalg.norm(weak[ids])),
                strong_norm=float(np.linalg.norm(strong[ids])),
                identity_difference_norm=float(np.linalg.norm((weak-strong)[ids])),
                identity_difference_scaled_norm=float(np.linalg.norm(((weak-strong)/self.scales)[ids])))
        return weak,strong,flux_jac,report


def write_csv(path, header, rows):
    with path.open("w",newline="",encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)


def run(input_path, out):
    req = json.loads(input_path.read_text(encoding="utf-8-sig"))
    oracle = Oracle(req)
    out.mkdir(parents=True,exist_ok=True)
    actual = np.array(req["state"])
    weak,strong,flux_jac,actual_report = oracle.assemble(actual,req["flux_Wb"])
    write_csv(out/"actual_residual.csv",["row","block","independent_weak","independent_strong"],
              ((i+1,oracle.blocks[i],weak[i],strong[i]) for i in range(len(weak))))
    write_csv(out/"flux_jacobian.csv",["column","derivative_Wb_per_state_unit"],enumerate(flux_jac,start=1))
    summary = dict(schema="spatial_independent_oracle_v1",executed=True,exit_code=0,
                   case_id=req["case_id"],candidate_hash=req["candidate_hash"],state_hash=req["state_hash"],
                   source_sha256=sha(__file__),input_sha256=sha(input_path),
                   python_version=platform.python_version(),numpy_version=np.__version__,
                   actual=actual_report,physical_validation_credit=0)
    metrics = {}
    for block,record in actual_report["blocks"].items():
        for k,v in record.items():
            metrics[f"actual.{block}.{k}"] = v
    metrics["actual.B_divB_term_momentum_norm_N"] = actual_report["B_divB_term_momentum_norm_N"]
    metrics["actual.maximum_shared_trace_difference_T"] = actual_report["maximum_shared_trace_difference_T"]
    if req["execute_manufactured"]:
        state = oracle.mms_state()
        flux = oracle.mms_flux()
        mw,ms,_,mr = oracle.assemble(state,flux,manufactured=True)
        ew,es,_,er = oracle.assemble(state,flux,manufactured=True,exact=True)
        write_csv(out/"manufactured_state.csv",["column","value"],enumerate(state,start=1))
        write_csv(out/"manufactured_residual.csv",["row","block","interpolated_weak","interpolated_strong","analytic_weak","analytic_strong"],
                  ((i+1,oracle.blocks[i],mw[i],ms[i],ew[i],es[i]) for i in range(len(mw))))
        metrics["manufactured.flux_Wb"] = flux
        for mode,report in (("interpolant",mr),("analytic",er)):
            for block,record in report["blocks"].items():
                for k,v in record.items():
                    metrics[f"manufactured.{mode}.{block}.{k}"] = v
            for k,v in report["field_rms_errors"].items():
                metrics[f"manufactured.{mode}.field_rms.{k}"] = v
            metrics[f"manufactured.{mode}.source_weighted_l2_N_per_m3_sqrt_m3"] = report["source_weighted_l2_N_per_m3_sqrt_m3"]
        summary["manufactured"] = dict(flux_Wb=flux,interpolant=mr,analytic=er,
            interpretation="Analytic weak/strong discrepancy is a quadrature diagnostic on supplied geometry; interpolant error also contains approximation. No physical validation or established solution convergence order.")
    write_csv(out/"metrics.csv",["name","value"],sorted(metrics.items()))
    summary["artifacts"] = {p.name:sha(p) for p in sorted(out.glob("*.csv"))}
    (out/"summary.json").write_text(json.dumps(summary,indent=2,allow_nan=False)+"\n",encoding="utf-8")
    (out/"oracle.exitcode").write_text("0\n",encoding="ascii")
    print(json.dumps(dict(case_id=req["case_id"],executed=True,exit_code=0,rows=len(weak),columns=len(actual),manufactured=req["execute_manufactured"])))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: spatial_verification_oracle_v4.py oracle_input.json output_directory")
    try:
        run(pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]))
    except Exception:
        target = pathlib.Path(sys.argv[2]);target.mkdir(parents=True,exist_ok=True)
        (target/"oracle.exitcode").write_text("1\n",encoding="ascii")
        raise
