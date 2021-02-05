#cython: language_level=3, boundscheck=False, cdivision=True, wraparound=False
from libc.math cimport sqrt, log, asin, pow, exp
from .general_halo cimport m_calc, potential_core, integrand_core, vcirc_core
from scipy.integrate import quad
from scipy._lib._ccallback import LowLevelCallable
import numpy as np
cimport numpy as np
ctypedef double * double_ptr
ctypedef void * void_ptr
from cython_gsl cimport *

cdef double PI=3.14159265358979323846



cdef double dens_truncated_alfabeta(double m, void * params) nogil:

    cdef:
        double d0 = (<double_ptr> params)[0]
        double rs = (<double_ptr> params)[1]
        double alfa = (<double_ptr> params)[2]
        double beta = (<double_ptr> params)[3]
        double rcut = (<double_ptr> params)[4]
        double x=m/rs
    return 2.*m*d0*pow(x,-alfa)*pow(1+x,alfa-beta)#*exp(-pow(m/rcut,2.))

cdef double psi_truncated_alfabeta(double d0, double rs, double alfa, double beta, double rcut, double m,  double toll) nogil:

    cdef:
        double result, error
        gsl_integration_workspace * w
        gsl_function F
        double params[5]

    params[0] = d0
    params[1] = rs
    params[2] = alfa
    params[3] = beta
    params[4] = rcut

    W = gsl_integration_workspace_alloc (1000)


    F.function = &dens_truncated_alfabeta
    F.params = params


    gsl_integration_qag(&F, 0, m, toll, toll, 1000, GSL_INTEG_GAUSS15, W, &result, &error)
    gsl_integration_workspace_free(W)

    return result

cdef double integrand_truncated_alfabeta(int nn, double *data) nogil:


    cdef:
        double m = data[0]

    if m==0.: return 0 #Xi diverge to infinity when m tends to 0, but the integrand tends to 0

    cdef:
        double R = data[1]
        double Z = data[2]
        double mcut = data[3]
        double d0 = data[4]
        double rs = data[5]
        double alfa = data[6]
        double beta = data[7]
        double rcut = data[8]
        double e = data[9]
        double toll = data[10]
        double psi, result #, num, den

    if (m<=mcut): psi=psi_truncated_alfabeta(d0, rs, alfa, beta, rcut, m, toll)
    else: psi=psi_truncated_alfabeta(d0, rs, alfa, beta, rcut, mcut, toll)

    result=integrand_core(m, R, Z, e, psi)
    #num=xi(m,R,Z,e)*(xi(m,R,Z,e)-e*e)*sqrt(xi(m,R,Z,e)-e*e)*m*psi
    #den=((xi(m,R,Z,e)-e*e)*(xi(m,R,Z,e)-e*e)*R*R)+(xi(m,R,Z,e)*xi(m,R,Z,e)*Z*Z)

    return result

cdef double  _potential_truncated_alfabeta(double R, double Z, double mcut, double d0, double rs, double alfa, double beta, double rcut, double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double intpot
        double result

    m0=m_calc(R,Z,e)

    #Integ
    import galpynamics.src.pot_halo.pot_c_ext.truncated_alfabeta_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_truncated_alfabeta')


    intpot=quad(fintegrand,0.,m0,args=(R,Z,mcut,d0,rs,alfa,beta,rcut,e,toll),epsabs=toll,epsrel=toll)[0]


    psi=psi_truncated_alfabeta(d0,rs,alfa,beta,rcut,mcut,toll)

    result=potential_core(e, intpot, psi)

    return result



cdef double[:,:]  _potential_truncated_alfabeta_array(double[:] R, double[:] Z, int nlen, double mcut, double d0, double rs, double alfa, double beta, double rcut, double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double[:,:] ret=np.empty((nlen,3), dtype=np.dtype("d"))
        double intpot
        int i



    #Integ
    import galpynamics.src.pot_halo.pot_c_ext.truncated_alfabeta_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_truncated_alfabeta')


    for  i in range(nlen):


        ret[i,0]=R[i]
        ret[i,1]=Z[i]

        m0=m_calc(R[i],Z[i],e)

        intpot=quad(fintegrand,0.,m0,args=(R[i],Z[i],mcut,d0,rs,alfa,beta,rcut,e,toll),epsabs=toll,epsrel=toll)[0]

        psi=psi_truncated_alfabeta(d0,rs,alfa,beta,rcut,mcut,toll)

        ret[i,2]=potential_core(e, intpot, psi)


    return ret



cdef double[:,:]  _potential_truncated_alfabeta_grid(double[:] R, double[:] Z, int nlenR, int nlenZ, double mcut, double d0, double rs, double alfa, double beta, double rcut,  double e, double toll):


    cdef:
        double G=4.498658966346282e-12 #G constant in  kpc^3/(msol Myr^2 )
        double cost=2*PI*G
        double m0
        double psi
        double[:,:] ret=np.empty((nlenR*nlenZ,3), dtype=np.dtype("d"))
        double intpot
        int i, j, c



    #Integ
    import galpynamics.src.pot_halo.pot_c_ext.truncated_alfabeta_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'integrand_truncated_alfabeta')

    c=0
    for  i in range(nlenR):
        for j in range(nlenZ):

            ret[c,0]=R[i]
            ret[c,1]=Z[j]

            m0=m_calc(R[i],Z[j],e)

            intpot=quad(fintegrand,0.,m0,args=(R[i],Z[j],mcut,d0,rs,alfa,beta,rcut,e,toll),epsabs=toll,epsrel=toll)[0]

            psi=psi_truncated_alfabeta(d0,rs,alfa,beta,rcut,mcut,toll)

            ret[c,2]=potential_core(e, intpot, psi)
            #if (e<=0.0001):
            #    ret[c,2] = -cost*(psi-intpot)
            #else:
            #    ret[c,2] = -cost*(sqrt(1-e*e)/e)*(psi*asin(e)-e*intpot)

            c+=1

    return ret


cpdef potential_truncated_alfabeta(R, Z, d0, rs, alfa, beta, rcut, e, mcut, toll=1e-4, grid=False):

    if isinstance(R, float) or isinstance(R, int):
        if isinstance(Z, float) or isinstance(Z, int):
            return np.array(_potential_truncated_alfabeta(R=R,Z=Z,mcut=mcut,d0=d0, rs=rs, alfa=alfa, beta=beta, rcut=rcut, e=e,toll=toll))
        else:
            raise ValueError('R and Z have different dimension')
    else:
        if grid:
            R=np.array(R,dtype=np.dtype("d"))
            Z=np.array(Z,dtype=np.dtype("d"))
            return np.array(_potential_truncated_alfabeta_grid( R=R, Z=Z, nlenR=len(R), nlenZ=len(Z), mcut=mcut, d0=d0, rs=rs, alfa=alfa, beta=beta, rcut=rcut, e=e,toll=toll))
        elif len(R)==len(Z):
            nlen=len(R)
            R=np.array(R,dtype=np.dtype("d"))
            Z=np.array(Z,dtype=np.dtype("d"))
            return np.array(_potential_truncated_alfabeta_array( R=R, Z=Z, nlen=len(R), mcut=mcut, d0=d0, rs=rs, alfa=alfa, beta=beta, rcut=rcut, e=e,toll=toll))
        else:
            raise ValueError('R and Z have different dimension')

#####################################################################
#Vcirc
cdef double vcirc_integrand_truncated_alfabeta(int n, double *data) nogil:
    """
    Integrand function for vcirc  on the plane (Eq. 2.132 in BT2)
    """


    cdef:
        double m      = data[0]
        double R      = data[1]
        double rs     = data[2]
        double alfa   = data[3]
        double beta   = data[4]
        double rcut   = data[5]
        double e      = data[6]
        double x      = m/rs
        double dens
        double core


    core = vcirc_core(m, R, e)
    dens = pow(x,-alfa) * pow(1+x,alfa-beta) * exp(- (m/rcut)**2 )

    return core*dens



cdef double _vcirc_truncated_alfabeta(double R, double d0, double rs, double alfa, double beta, double rcut, double e, double toll):
    """
    Calculate Vcirc on a single point on the plane
    :param R: radii array (kpc)
    :param d0: Central density (Msol/kpc^3)
    :param rs: scale radius (kpc)
    :param alfa: alfa exponent
    :param beta: beta exponent
    :param rcut: radius of the exponential truncation
    :param e: ellipticity
    :return:
    """

    cdef:
        double G=4.302113488372941e-06 #G constant in  kpc km2/(msol s^2)
        double cost=4*PI*G
        double norm=cost*sqrt(1-e*e)*d0
        double intvcirc
        double result

    #Integ
    import galpynamics.src.pot_halo.pot_c_ext.truncated_alfabeta_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'vcirc_integrand_truncated_alfabeta')

    intvcirc=quad(fintegrand,0.,R,args=(R,rs,alfa,beta,rcut,e),epsabs=toll,epsrel=toll)[0]

    result=sqrt(norm*intvcirc)

    return result


cdef double[:,:] _vcirc_truncated_alfabeta_array(double[:] R, int nlen, double d0, double rs, double alfa, double beta, double rcut, double e, double toll):
    """
    Calculate Vcirc on a single point on the plane
    :param R: radii array (kpc)
    :param d0: Central density (Msol/kpc^3)
    :param rs: scale radius (kpc)
    :param alfa: alfa exponent
    :param beta: beta exponent
    :param rcut: radius of the exponential truncation
    :param e: ellipticity
    :return:
    """

    cdef:
        double G=4.302113488372941e-06 #G constant in  kpc km2/(msol s^2)
        double cost=4*PI*G
        double norm=cost*sqrt(1-e*e)*d0
        double intvcirc
        int i
        double[:,:] ret=np.empty((nlen,2), dtype=np.dtype("d"))




    #Integ
    import galpynamics.src.pot_halo.pot_c_ext.truncated_alfabeta_halo as mod
    fintegrand=LowLevelCallable.from_cython(mod,'vcirc_integrand_truncated_alfabeta')

    for  i in range(nlen):

        ret[i,0]=R[i]
        intvcirc=quad(fintegrand,0.,R[i],args=(R[i],rs,alfa,beta,rcut,e),epsabs=toll,epsrel=toll)[0]
        ret[i,1]=sqrt(norm*intvcirc)

    return ret


cpdef vcirc_truncated_alfabeta(R, d0, rs, alfa, beta, rcut, e, toll=1e-4):
    """Calculate the Vcirc on the plane of a truncated alfabeta halo halo.

    :param R: Cylindrical radius (memview object)
    :param d0: Central density at (R,Z)=(0,0) [Msol/kpc^3]
    :param rs: scale radius
    :param alfa:
    :param beta:
    :param rcut: exponential cut scale radius
    :param e: ellipticity
    :param toll: Tollerance for nquad
    :return: 2-col array:
        0-R
        1-Vcirc(R)
    """

    if isinstance(R, float) or isinstance(R, int):

        if R==0: ret=0
        else: ret= _vcirc_truncated_alfabeta(R, d0, rs, alfa, beta, rcut,  e,  toll)

    else:

        ret=_vcirc_truncated_alfabeta_array(R, len(R), d0, rs, alfa, beta, rcut, e, toll)
        ret[:,1]=np.where(R==0, 0, ret[:,1])

    return ret