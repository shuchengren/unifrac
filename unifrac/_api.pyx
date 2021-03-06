import skbio
import numpy as np
cimport numpy as np

def ssu(str biom_filename, str tree_filename, 
        str unifrac_method, bool variance_adjust, double alpha,
        bool bypass_tips, unsigned int threads):
    """Execute a call to Strided State UniFrac via the direct API

    Parameters
    ----------
    biom_filename : str
        A filepath to a BIOM 2.1 formatted table (HDF5)
    tree_filename : str
        A filepath to a Newick formatted tree
    unifrac_method : str
        The requested UniFrac method, one of {unweighted,
        weighted_normalized, weighted_unnormalized, generalized}
    variance_adjust : bool
        Whether to perform Variance Adjusted UniFrac
    alpha : float
        The value of alpha for Generalized UniFrac; only applies to
        Generalized UniFraca
    bypass_tips : bool
        Bypass the tips of the tree in the computation. This reduces compute
        by about 50%, but is an approximation.
    threads : int
        The number of threads to use.

    Returns
    -------
    skbio.DistanceMatrix
        The resulting distance matrix

    Raises
    ------
    IOError
        If the tree file is not found
        If the table is not found
    ValueError
        If an unknown method is requested.
    """
    cdef:
        mat *result;
        compute_status status;
        np.ndarray[np.double_t, ndim=1] numpy_arr
        double *cf
        int i
        bytes biom_py_bytes
        bytes tree_py_bytes
        bytes met_py_bytes
        char* biom_c_string 
        char* tree_c_string 
        char* met_c_string 
        list ids

    biom_py_bytes = biom_filename.encode()
    tree_py_bytes = tree_filename.encode()
    met_py_bytes = unifrac_method.encode()
    biom_c_string = biom_py_bytes
    tree_c_string = tree_py_bytes
    met_c_string = met_py_bytes

    status = one_off(biom_c_string, 
                     tree_c_string, 
                     met_c_string, 
                     variance_adjust, 
                     alpha,
                     bypass_tips,
                     threads, 
                     &result)

    if status != okay:
        if status == tree_missing:
            raise IOError("Tree file not found.")
        if status == table_missing:
            raise IOError("Table file not found.")
        if status == unknown_method:
            raise ValueError("Unknown method.")

    ids = []
    numpy_arr = np.zeros(result.cf_size, dtype=np.double)
    numpy_arr[:] = <np.double_t[:result.cf_size]> result.condensed_form
    
    for i in range(result.n_samples):
        ids.append(result.sample_ids[i].decode('utf-8'))

    destroy_mat(&result)

    return skbio.DistanceMatrix(numpy_arr, ids)
