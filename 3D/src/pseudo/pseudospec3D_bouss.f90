!=================================================================
! PSEUDOSPECTRAL subroutines
!
! Extra subroutines to compute diagnostic quantities
! for the Boussinesq solvers. You should use the FFTPLANS 
! and MPIVARS modules (see the file 'fftp_mod.f90') in each 
! program that calls any of the subroutines in this file. 
!
! NOTATION: index 'i' is 'x' 
!           index 'j' is 'y'
!           index 'k' is 'z'
!
! 2011 D. Rosenberg
!      NCAR
!
!=================================================================

!*****************************************************************
      SUBROUTINE havgshear(u, v, nmb)
!-----------------------------------------------------------------
!
! Computes the horizontal-averaged shear (as a function of z), and
! outputs it.
!
! Parameters
!     u  : input x-velocity, Fourier coeffs
!     v  : input y-velocity, Fourier coeffs
!     nmb: the extension used when writting the file

      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
      USE fft
!$    USE threads
      IMPLICIT NONE

      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: u,v
      COMPLEX(KIND=GP), DIMENSION(n,n,ista:iend) :: c1
      REAL(KIND=GP), DIMENSION(n,n,ksta:kend)    :: r1,r2
      REAL(KIND=GP), DIMENSION(n)                :: sh, gsh
      REAL(KIND=GP)                              :: tmp
      INTEGER                                    :: i,j,k
      CHARACTER(len=*), INTENT(IN) :: nmb

!
! Find z-derivative of u, v:
      CALL derivk3(u,c1,3)
      CALL fftp3d_complex_to_real(plancr,c1,r1,MPI_COMM_WORLD)

      CALL derivk3(v,c1,3)
      CALL fftp3d_complex_to_real(plancr,c1,r2,MPI_COMM_WORLD)

!
! Do volume average of total shear:
      sh = 0.0
      tmp = 1.0_GP/real(n,kind=GP)**6
!$omp parallel do if (kend-ksta.ge.nth) private (j,i)
      DO k = ksta,kend
!$omp parallel do if (kend-ksta.lt.nth) private (i)
         DO j = 1,n
            DO i = 1,n
               sh(k) = sh(k)+( r1(i,j,k)**2 + r2(i,j,k)**2 ) * tmp
            END DO
         END DO
      END DO

! Output shear as a fcn of z:
!
      CALL MPI_ALLREDUCE(sh,gsh,n,GC_REAL,MPI_SUM,MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='shear.' // nmb // '.txt')
         WRITE(1,10) gsh
   10    FORMAT( E23.15 )
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE havgshear

!*****************************************************************
      SUBROUTINE havghvel(u, v, nmb)
!-----------------------------------------------------------------
!
! Computes the horizontal-averaged square horizontal velocity 
! (as a function of z), and ! outputs it.
!
! Parameters
!     u  : input x-velocity, Fourier coeffs
!     v  : input y-velocity, Fourier coeffs
!     nmb: the extension used when writting the file

      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
      USE fft
!$    USE threads
      IMPLICIT NONE

      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: u,v
      REAL(KIND=GP), DIMENSION(n,n,ksta:kend)    :: r1,r2
      REAL(KIND=GP), DIMENSION(n)                :: havg,ghavg
      REAL(KIND=GP)                              :: tmp
      INTEGER                                    :: i,j,k
      CHARACTER(len=*), INTENT(IN)               :: nmb

!
! Find spatial u, v:
      CALL fftp3d_complex_to_real(plancr,u,r1,MPI_COMM_WORLD)
      CALL fftp3d_complex_to_real(plancr,v,r2,MPI_COMM_WORLD)

!
! Do volume average of total shear:
      havg = 0.0
      tmp = 1.0_GP/real(n,kind=GP)**6
!$omp parallel do if (kend-ksta.ge.nth) private (j,i)
      DO k = ksta,kend
!$omp parallel do if (kend-ksta.lt.nth) private (i)
         DO j = 1,n
            DO i = 1,n
               havg(k) = havg(k)+( r1(i,j,k)**2 + r2(i,j,k)**2 ) * tmp
            END DO
         END DO
      END DO

! Output shear as a fcn of z:
!
      CALL MPI_ALLREDUCE(havg,ghavg,n,GC_REAL,MPI_SUM,MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='havgv.' // nmb // '.txt')
         WRITE(1,10) ghavg
   10    FORMAT( E23.15 )
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE havghvel

!*****************************************************************
      SUBROUTINE tbouss(u, v, w, t, dt)
!-----------------------------------------------------------------
!
! Computes the volume-average and max of horizontal & vertical kinetic energy, and
! of the shear, and outputs them as a function of time. 
!
! Parameters
!     u  : input x-velocity, Fourier coeffs
!     v  : input y-velocity, Fourier coeffs
!     w  : input z-velocity, Fourier coeffs
!     t  : number of time steps made
!     dt : time step

      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
      USE fft
!$    USE threads
      IMPLICIT NONE

      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: u,v,w
      COMPLEX(KIND=GP), DIMENSION(n,n,ista:iend) :: c1
      REAL(KIND=GP), INTENT(IN)                  :: t, dt
      REAL(KIND=GP), DIMENSION(n,n,ksta:kend)    :: r1,r2
      REAL(KIND=GP)                              :: del,xavg(3),gxavg(3),xmax(3),gxmax(3),tmp
      INTEGER                                    :: i,j,k

!
! Find max and vol avg of shear:
      CALL derivk3(u,c1,3)
      CALL fftp3d_complex_to_real(plancr,c1,r1,MPI_COMM_WORLD)

      CALL derivk3(v,c1,3)
      CALL fftp3d_complex_to_real(plancr,c1,r2,MPI_COMM_WORLD)

      xavg = 0.0
      xmax = 0.0
      tmp  = 1.0_GP/real(n,kind=GP)**3
!$omp parallel do if (kend-ksta.ge.nth) private (j,i)
      DO k = ksta,kend
!$omp parallel do if (kend-ksta.lt.nth) private (i)
         DO j = 1,n
            DO i = 1,n
               del     = (r1(i,j,k)**2 + r2(i,j,k)**2 )*tmp 
               xmax(1) = MAX(xmax(1),del)
               xavg(1) = xavg(1) + del*tmp
            END DO
         END DO
      END DO

!
! Find spatial u, v, vol average of square of horizontal velocity:
      CALL fftp3d_complex_to_real(plancr,u,r1,MPI_COMM_WORLD)
      CALL fftp3d_complex_to_real(plancr,v,r2,MPI_COMM_WORLD)
!$omp parallel do if (kend-ksta.ge.nth) private (j,i)
      DO k = ksta,kend
!$omp parallel do if (kend-ksta.lt.nth) private (i)
         DO j = 1,n
            DO i = 1,n
               del     = sqrt(r1(i,j,k)**2 + r2(i,j,k)**2 ) * tmp
               xmax(2) = MAX(xmax(2),del)
               xavg(2) = xavg(2) + del*tmp
            END DO
         END DO
      END DO

!
! Find spatial w, vol average of square of, and max of vertical velocity:
      CALL fftp3d_complex_to_real(plancr,w,r1,MPI_COMM_WORLD)
!$omp parallel do if (kend-ksta.ge.nth) private (j,i)
      DO k = ksta,kend
!$omp parallel do if (kend-ksta.lt.nth) private (i)
         DO j = 1,n
            DO i = 1,n
               del     = (r1(i,j,k)**2) * tmp
               xmax(3) = MAX(xmax(3),del)
               xavg(3) = xavg(3) + del*tmp
            END DO
         END DO
      END DO

!
! Do reductions to find global vol avg and global max:
      CALL MPI_REDUCE(xavg,gxavg,3,GC_REAL,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
      CALL MPI_REDUCE(xmax,gxmax,3,GC_REAL,MPI_MAX,0, &
                      MPI_COMM_WORLD,ierr)
! NOTE: xavg_1 == vol average of shear
!       xavg_2 == vol average of horiz. kinetic energy
!       xavg_3 == vol average of vert. kinetic energy
!
!       xmax_1 == max of shear
!       xmax_2 == max of horiz. kinetic energy
!       xmax_3 == max of vert. kinetic energy
!
! Output quantities as a fcn of t:
      IF (myrank.eq.0) THEN
         OPEN(1,file='tbouss.txt',position='append')
         WRITE(1,10) (t-1)*dt,gxavg(1),gxavg(2),gxavg(3),gxmax(1),gxmax(2),gxmax(3)
   10    FORMAT( E13.6,1x,6(E26.18,1x) )
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE tbouss


!*****************************************************************
      SUBROUTINE spectpv(u,v,w,s,nmb)
!-----------------------------------------------------------------
!
! Computes the potential vorticity power spectrum. 
! The pot'l vorticity is computed as:
!  PV = curl(v) . Grad(theta)
! output is written to a file by the first node.
!
! Parameters
!     u,v,w  : input matrix with the 1,2,3 velocity components;
!     s      : input matrix with the scalar density/temperature
!     nmb    : the extension used when writting the file
!
      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(n/2+1)            :: Ek,Ektot
      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: u,v,w,s
      COMPLEX(KIND=GP), DIMENSION(n,n,ista:iend)             :: c1,c2,c3,a
      REAL(KIND=GP)    :: tmp
      INTEGER :: i,j,k
      INTEGER :: kmn
      CHARACTER(len=*), INTENT(IN) :: nmb
!
! Compute vorticity:
      CALL rotor3(v,w,c1,1)
      CALL rotor3(u,w,c2,2)
      CALL rotor3(u,v,c3,3)
!
! Compute curl a = v . Grad(s):
      CALL advect3(c1,c2,c3,s,a)
!
! Sets Ek to zero
!
      DO i = 1,n/2+1
         Ek(i) = 0.
      END DO
!
! Computes the power spectrum
!
      tmp = 1./real(n,kind=GP)**6
      IF (ista.eq.1) THEN
         DO j = 1,n
            DO k = 1,n
               kmn = int(abs(ka(k))+1)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                  Ek(kmn) = Ek(kmn)+tmp*abs(a(k,j,1))**2
               ENDIF
            END DO
         END DO
         DO i = 2,iend
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                     Ek(kmn) = Ek(kmn)+2*tmp*abs(a(k,j,i))**2
                  ENDIF
               END DO
            END DO
         END DO
      ELSE
         DO i = ista,iend
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                     Ek(kmn) = Ek(kmn)+2*tmp*abs(a(k,j,i))**2
                  ENDIF
               END DO
            END DO
         END DO
      ENDIF
!
! Computes the reduction between nodes
!
      CALL MPI_REDUCE(Ek,Ektot,n/2+1,MPI_DOUBLE_PRECISION,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
!
! Exports the spectrum to a file
!
      IF (myrank.eq.0) THEN
         OPEN(1,file='pvspectrum.' // nmb // '.txt')
         WRITE(1,20) Ektot
   20    FORMAT( E23.15 ) 
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE spectpv
