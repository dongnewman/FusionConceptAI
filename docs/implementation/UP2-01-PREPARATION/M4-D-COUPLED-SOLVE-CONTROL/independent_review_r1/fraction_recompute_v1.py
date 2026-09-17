"""Independent reviewer recomputation for the frozen M4-D algebra."""

from fractions import Fraction
from itertools import product
import json


def main():
    a, b, c, d = map(Fraction, (2, -1, -1, 2))
    r0, r1 = map(Fraction, (1, 0))
    det = a * d - b * c
    x = (r0 * d - b * r1) / det
    y = (a * r1 - c * r0) / det
    cells = list(product(range(1, 3), repeat=3))
    residuals = [(a * x + b * y - r0, c * x + d * y - r1) for _ in cells]
    assert det == Fraction(3)
    assert (x, y) == (Fraction(2, 3), Fraction(1, 3))
    assert len(cells) == 8 and all(r == (Fraction(0), Fraction(0)) for r in residuals)
    print(json.dumps({
        "determinant": str(det),
        "solution": [str(x), str(y)],
        "cell_count": len(cells),
        "residuals": [[str(v) for v in r] for r in residuals],
        "status": "pass",
    }, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
