from fractions import Fraction


def verify_grid(shape):
    nx, ny, nz = shape
    h = (Fraction(1, nx), Fraction(1, ny), Fraction(1, nz))
    area = (h[1] * h[2], h[0] * h[2], h[0] * h[1])
    cells = 0
    faces = 0
    for k in range(1, nz + 1):
        for j in range(1, ny + 1):
            for i in range(1, nx + 1):
                coords = ((Fraction(i - 1, nx), Fraction(i, nx)),
                          (Fraction(j - 1, ny), Fraction(j, ny)),
                          (Fraction(k - 1, nz), Fraction(k, nz)))
                components = ((Fraction(2) + coords[0][0] / 10,
                               Fraction(2) + coords[0][1] / 10),
                              (Fraction(3) + coords[1][0] / 20,
                               Fraction(3) + coords[1][1] / 20),
                              (Fraction(4) + coords[2][0] / 30,
                               Fraction(4) + coords[2][1] / 30))
                directional = []
                for axis in range(3):
                    minus = -components[axis][0] * area[axis] / (h[axis] * area[axis])
                    plus = components[axis][1] * area[axis] / (h[axis] * area[axis])
                    directional.append(minus + plus)
                    faces += 2
                assert tuple(directional) == (Fraction(1, 10), Fraction(1, 20), Fraction(1, 30))
                divergence = sum(directional, Fraction(0))
                assert divergence == Fraction(11, 60)
                assert -divergence - Fraction(-11, 60) == 0
                cells += 1
    assert cells == nx * ny * nz
    assert faces == 6 * cells
    return cells, faces


def main():
    results = {"2x2x2": verify_grid((2, 2, 2)), "3x4x5": verify_grid((3, 4, 5))}
    print("INDEPENDENT_FRACTION_RECOMPUTE PASS", results,
          "terms=1/10,1/20,1/30 total=11/60 source=-11/60 residual=0")


if __name__ == "__main__":
    main()
