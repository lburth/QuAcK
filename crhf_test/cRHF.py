#!/usr/bin/env python3
import numpy as np
import pandas as pd
import os


def print_matrix(matrix):
    df = pd.DataFrame(matrix)
    print(df)


def read_nO(working_dir):
    file_path = os.path.join(working_dir, "input/molecule")

    with open(file_path, "r") as f:
        next(f)  # Skip the first line
        line = f.readline().split()
        nO = max(int(line[1]), int(line[2]))
    return nO


def read_ENuc(file_path):
    # Path to the ENuc.dat file
    with open(file_path, 'r') as f:
        # Read the nuclear repulsion energy from the first line
        ENuc = float(f.readline().strip())
    return ENuc


def read_matrix(filename):
    # Read the data and determine matrix size
    entries = []
    max_index = 0

    with open(filename, 'r') as f:
        for line in f:
            i, j, value = line.split()
            i, j = int(i) - 1, int(j) - 1  # Convert to zero-based index
            entries.append((i, j, float(value)))
            # Find max index to determine size
            max_index = max(max_index, i, j)

    # Initialize square matrix with zeros
    matrix = np.zeros((max_index + 1, max_index + 1))

    # Fill the matrix
    for i, j, value in entries:
        matrix[i, j] = value
        if i != j:  # Assuming the matrix is symmetric, fill the transpose element
            matrix[j, i] = value

    return matrix


def read_CAP_integrals(filename, size):
    """
    Reads the file and constructs the symmetric matrix W.
    """
    W = np.zeros((size, size))
    with open(filename, 'r') as f:
        for line in f:
            mu, nu, wx, wy, wz = line.split()
            mu, nu = int(mu) - 1, int(nu) - 1  # Convert to zero-based index
            value = float(wx) + float(wy) + float(wz)
            W[mu, nu] = value
            W[nu, mu] = value  # Enforce symmetry
    return W


def read_2e_integrals(file_path, nBas):
    # Read the binary file and reshape the data into a 4D array
    try:
        G = np.fromfile(file_path, dtype=np.float64).reshape(
            (nBas, nBas, nBas, nBas))
    except FileNotFoundError:
        print(f"Error opening file: {file_path}")
        raise
    return G


def get_X(S):
    """
       Computes matrix X for orthogonalization. Attention O has to be hermitian.
    """
    vals, U = np.linalg.eigh(S)
    # Sort the eigenvalues and eigenvectors
    vals = 1/np.sqrt(vals)
    return U@np.diag(vals)


def sort_eigenpairs(eigenvalues, eigenvectors):
    # Get the sorting order based on the real part of the eigenvalues
    order = np.argsort(eigenvalues.real)

    # Sort eigenvalues and eigenvectors
    sorted_eigenvalues = eigenvalues[order]
    sorted_eigenvectors = eigenvectors[:, order]
    return sorted_eigenvalues, sorted_eigenvectors


def diagonalize(M):
    # Diagonalize the matrix
    vals, vecs = np.linalg.eig(M)
    # Sort the eigenvalues and eigenvectors
    vals, vecs = sort_eigenpairs(vals, vecs)
    # Orthonormalize them wrt cTc inner product
    vecs = gram_schmidt(vecs)
    return vals, vecs


def Hartree_matrix_AO_basis(P, ERI):
    # Initialize Hartree matrix with zeros (complex type)
    J = np.zeros((nBas, nBas), dtype=np.complex128)

    # Compute Hartree matrix
    for si in range(nBas):
        for nu in range(nBas):
            for la in range(nBas):
                for mu in range(nBas):
                    J[mu, nu] += P[la, si] * ERI[mu, la, nu, si]

    return J


def exchange_matrix_AO_basis(P, ERI):
    # Initialize exchange matrix with zeros
    K = np.zeros((nBas, nBas), dtype=np.complex128)

    # Compute exchange matrix
    for nu in range(nBas):
        for si in range(nBas):
            for la in range(nBas):
                for mu in range(nBas):
                    K[mu, nu] -= P[la, si] * ERI[mu, la, si, nu]
    return K


def gram_schmidt(vectors):
    """
    Orthonormalize a set of vectors with respect to the scalar product c^T c.
    """
    orthonormal_basis = []
    for v in vectors.T:  # Iterate over column vectors
        for u in orthonormal_basis:
            v -= (u.T @ v) * u  # Projection with respect to c^T c
        norm = np.sqrt(v.T @ v)  # Norm with respect to c^T c
        if norm > 1e-10:
            orthonormal_basis.append(v / norm)
        else:
            raise Exception("Norm of eigenvector < 1e-10")
    return np.column_stack(orthonormal_basis)


if __name__ == "__main__":
    # Constants
    workdir = "../"
    eta = 0.01
    thresh = 0.00001
    maxSCF = 256
    nO = read_nO(workdir)

    # Read integrals
    T = read_matrix("../int/Kin.dat")
    S = read_matrix("../int/Ov.dat")
    V = read_matrix("../int/Nuc.dat")
    ENuc = read_ENuc("../int/ENuc.dat")
    nBas = np.shape(T)[0]
    W = read_CAP_integrals("../int/CAP.dat", nBas)
    ERI = read_2e_integrals("../int/ERI.bin", nBas)
    X = get_X(S)
    W = -eta*W
    Hc = T + V + W*1j

    # core guess
    _, c = diagonalize(X.T @ Hc @ X)
    c = X @ c
    P = 2*c[:, :nO]@c[:, :nO].T

    print('-' * 98)
    print(
        f"| {'#':<1} | {'E(RHF)':<36} | {'EJ(RHF)':<16} | {'EK(RHF)':<16} | {'Conv':<10} |")
    print('-' * 98)

    nSCF = 0
    Conv = 1
    while(Conv > thresh and nSCF < maxSCF):
        nSCF += 1
        J = Hartree_matrix_AO_basis(P, ERI)
        K = exchange_matrix_AO_basis(P, ERI)
        F = Hc + J + 0.5*K
        err = F@P@S - S@P@F
        if nSCF > 1:
            Conv = np.max(np.abs(err))
        ET = np.trace(P@T)
        EV = np.trace(P@V)
        EJ = 0.5*np.trace(P@J)
        EK = 0.25*np.trace(P@K)
        ERHF = ET + EV + EJ + EK

        Fp = X.T @ F @ X
        eHF, c = diagonalize(Fp)
        c = X @ c
        P = 2*c[:, :nO]@c[:, :nO].T
        print(
            f"| {nSCF:3d} | {ERHF.real+ENuc:5.6f} + {ERHF.imag:5.6f}i | {EJ:5.6f} | {EK:5.6f} | {Conv:5.6f} |")
        print('-' * 98)
    print()
    print("RHF orbitals")
    print_matrix(eHF)
