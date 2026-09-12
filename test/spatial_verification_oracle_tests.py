"""Manufactured software tests only; these files are not candidate outputs."""
import importlib.util
import math
import pathlib
import unittest
import numpy as np

SOURCE = pathlib.Path(__file__).resolve().parents[1]/"scripts"/"spatial_verification_oracle_v4.py"
SPEC = importlib.util.spec_from_file_location("spatial_independent_oracle",SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def isolated_oracle():
    o = object.__new__(MODULE.Oracle)
    o.mu = 1.25663706127e-6
    o.cells = [np.arange(8)]
    o.maps = [np.arange(8)]
    o.bounds = np.array([[[2.,3.],[0.,.2],[0.,.3]]])
    o.basis_cache = {}
    o.B0 = np.array([.2,-.1,.3])
    o.slopes = np.array([.02,-.015,.01])
    o.kp = np.array([4.,-3.,2.]);o.p0 = 500.
    return o


def cylindrical_sample(q):
    R,phi,z = q;c,s = math.cos(phi),math.sin(phi)
    return dict(q=np.array(q),R=R,phi=phi,xyz=np.array([R*c,R*s,z]),
                E=np.diag([1.,R,1.]),inverse=np.diag([1.,1/R,1.]),
                rot=np.array([[c,-s,0.],[s,c,0.],[0.,0.,1.]]))


class IndependentOracleTests(unittest.TestCase):
    def test_q1_partition_and_merged_axis(self):
        o = isolated_oracle();s = cylindrical_sample([2.3,.07,.11])
        N,D,grad = o.basis(0,s)
        np.testing.assert_allclose(sum(N),1.,atol=1e-15)
        np.testing.assert_allclose(D.sum(axis=0),0.,atol=1e-14)
        np.testing.assert_allclose(grad.sum(axis=0),0.,atol=1e-14)
        o.cells = [np.arange(6)];o.maps = [np.array([0,1,0,2,3,4,3,5])];o.basis_cache = {}
        N,D,_ = o.basis(0,s)
        self.assertEqual(len(N),6)
        self.assertAlmostEqual(sum(N),1.)
        np.testing.assert_allclose(D.sum(axis=0),0.,atol=1e-14)

    def test_cylindrical_basis_derivative_requires_B_divB(self):
        o = isolated_oracle();s = cylindrical_sample([2.3,.07,.11])
        state = np.array([[2.+(k&1),0.,0.,0.] for k in range(8)]).ravel()
        f = o.field(0,s,state)
        np.testing.assert_allclose(f["J"],0.,atol=1e-8)
        self.assertAlmostEqual(f["div"],2.,places=13)
        # curl(B) cross B is zero here, while div(T) is nonzero.
        expected = 2*np.array([s["xyz"][0],s["xyz"][1],0.])/o.mu
        np.testing.assert_allclose(np.cross(f["J"],f["B"])+f["B"]*f["div"]/o.mu-f["gradp"],expected,rtol=1e-13,atol=1e-8)
        self.assertGreater(np.linalg.norm(expected),1e6)

    def test_independent_nonzero_source_is_stress_divergence(self):
        o = isolated_oracle();x = np.array([1.2,-.7,.3]);h=1e-5
        force=np.zeros(3)
        for j in range(3):
            plus=x.copy();minus=x.copy();plus[j]+=h;minus[j]-=h
            force += (o.analytic(plus)["T"][:,j]-o.analytic(minus)["T"][:,j])/(2*h)
        np.testing.assert_allclose(force,o.analytic(x)["source"],rtol=1e-8)
        self.assertEqual(o.analytic(x)["div"],0.)


if __name__ == "__main__":
    unittest.main()
