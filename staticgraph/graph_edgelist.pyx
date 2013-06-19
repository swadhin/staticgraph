
"""
Routines for fast edgelist manipulation.
"""

import numpy as np
from numpy cimport uint64_t, uint32_t, ndarray

def make_deg(size_t n_nodes, object edges):
    """
    Create the degree distribution of nodes.
    """

    cdef:
        uint32_t u, v
        ndarray[uint32_t] deg

    deg = np.zeros(n_nodes, "u4")

    for u, v in edges:
        if u == v:
            continue
        i, j = u, v
        deg[i] += 1
        deg[j] += 1
    
    return deg

def make_comp(size_t n_nodes, size_t n_edges, object edges, ndarray deg):
    """
    Create the compressed arrays for edgelist.
    """

    cdef:
        uint32_t u, v
        uint64_t start, stop
        size_t i, j, n, del_ctr, e
        ndarray[uint64_t] indptr
        ndarray[uint32_t] indices
        ndarray[uint64_t] idxs

    indptr = np.empty(n_nodes + 1, "u8")
    indices = np.empty(2 * n_edges, "u4")

    indptr[0]  = 0
    #indptr[1:] = np.cumsum(deg)
    for i in xrange(1, n_nodes + 1):
        indptr[i] = deg[i - 1] + indptr[i - 1]
    #idxs = np.array(indptr[:-1], "u8")
    idxs = np.empty(n_nodes, "u8")
    for i in xrange(n_nodes):
        idxs[i] = indptr[i]
    
    #Creating the edgelist
    e = 0
    for u, v in edges:
        if e == n_edges:
            raise ValueError("More edges found than allocated for")
        if not u < n_nodes:
            raise ValueError("Invalid source node found in edges")
        if not v < n_nodes:
            raise ValueError("Invalid destination node found in edges")

        #self loop check
        if u == v:
            continue
        i, j = u, v

        indices[idxs[i]] = v
        idxs[i] += 1
        
        indices[idxs[j]] = u
        idxs[j] += 1

        e += 1
    
    #Sorting the edgelist
    for i in xrange(n_nodes):
        start = indptr[i]
        stop  = indptr[i + 1]
        indices[start:stop].sort()

     # Eliminating parallel edges

    i, j, del_ctr = 0, 1, 0  
    for n in xrange(n_nodes):
        if(indptr[n] == indptr[n + 1]):
            continue
        indices[i] = indices[i + del_ctr]
        stop  = indptr[n + 1]
        while j < stop:
            if indices[i] == indices[j]:
                j += 1
                del_ctr += 1
            else:
                indices[i + 1] = indices[j]
                i += 1
                j += 1
                
        indptr[n + 1] = i + 1
        i += 1
        j += 1
    indices = np.resize(indices, (2 * e) - del_ctr)
    return indptr, indices
