!=================================================================
! PSEUDOSPECTRAL subroutines
!
! Extra subroutines to compute the variance spectrum and 
! transfer functions for a passive scalar in 3D in the 
! anisotropic case (e.g. in the rotating frame or with an 
! imposed external magnetic field). Quantities parallel 
! and perpendicular to the z direction in Fourier space 
! can be computed. You should use the FFTPLANS and MPIVARS 
! modules (see the file 'fftp_mod.f90') in each program 
! that calls any of the subroutines in this file. 
!
! NOTATION: index 'i' is 'x' 
!           index 'j' is 'y'
!           index 'k' is 'z'
!
! 2009 Paola Rodriguez Imazio and Pablo D. Mininni.
!      Department of Physics, 
!      Facultad de Ciencias Exactas y Naturales.
!      Universidad de Buenos Aires.
!=================================================================

!*****************************************************************
      SUBROUTINE specscpa(a,nmb)
!-----------------------------------------------------------------
!
! Computes the power spectrum of the passive scalar in 
! the direction parallel to the preferred direction 
! (rotation or uniform magnetic field). As a result, the 
! k-shells are planes with normal (0,0,kz) (kz=0,...,n/2). 
! The output is written to a file by the first node.
!
! Parameters
!     a  : input matrix with the passive scalar
!     nmb: the extension used when writting the file

      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
!$    USE threads
      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(n/2+1) :: Ek,Ektot
      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: a
      REAL(KIND=GP) :: tmp
      INTEGER       :: i,j,k
      INTEGER       :: kmn
      CHARACTER(len=*), INTENT(IN) :: nmb

!
! Sets Ek to zero
!
      DO i = 1,n/2+1
         Ek(i) = 0.0D0
      END DO
!
! Computes the power spectrum
!
      tmp = 1.0_GP/real(n,kind=GP)**6
      IF (ista.eq.1) THEN
!$omp parallel do private (k,kmn)
         DO j = 1,n
            DO k = 1,n
               kmn = int(abs(ka(k))+1)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                  Ek(kmn) = Ek(kmn)+(abs(a(k,j,1))**2)*tmp
               ENDIF
            END DO
         END DO
!$omp parallel do if (iend-2.ge.nth) private (j,k,kmn)
         DO i = 2,iend
!$omp parallel do if (iend-2.lt.nth) private (k,kmn)
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*(abs(a(k,j,i))**2)*tmp
                  ENDIF
               END DO
            END DO
         END DO
      ELSE
!$omp parallel do if (iend-ista.ge.nth) private (j,k,kmn)
         DO i = ista,iend
!$omp parallel do if (iend-ista.lt.nth) private (k,kmn)
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*(abs(a(k,j,i))**2)*tmp
                  ENDIF
               END DO
            END DO
         END DO
      ENDIF
!
! Computes the reduction between nodes
! and exports the result to a file
!
      CALL MPI_REDUCE(Ek,Ektot,n/2+1,MPI_DOUBLE_PRECISION,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='sspecpara.' // nmb // '.txt')
         WRITE(1,10) Ektot
   10    FORMAT( E23.15 )
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE specscpa

!*****************************************************************
 SUBROUTINE specscpe(a,nmb)
!-----------------------------------------------------------------
!
! Computes the power spectrum of the passive scalar in 
! the direction perpendicular to the preferred direction 
! (rotation or uniform magnetic field). The k-shells are 
! cylindrical surfaces (kperp=1,...,n/2+1). The output is 
! written to a file by the first node.
!
! Parameters
!     a  : input matrix with the passive scalar
!     nmb: the extension used when writting the file
!
      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
!$    USE threads
      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(n/2+1) :: Ek,Ektot
      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: a
      REAL(KIND=GP) :: tmp
      INTEGER       :: i,j,k
      INTEGER       :: kmn
      CHARACTER(len=*), INTENT(IN) :: nmb

!
! Sets Ek to zero
!
      DO i = 1,n/2+1
         Ek(i) = 0.0D0
      END DO
!
! Computes the kinetic energy spectrum
!
      tmp = 1.0_GP/real(n,kind=GP)**6
      IF (ista.eq.1) THEN
!$omp parallel do private (k,kmn)
         DO j = 1,n
            kmn = int(sqrt(ka(1)**2+ka(j)**2)+.501)
            IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
               DO k = 1,n
!$omp atomic
                  Ek(kmn) = Ek(kmn)+(abs(a(k,j,1))**2)*tmp
               END DO
            ENDIF
         END DO
!$omp parallel do if (iend-2.ge.nth) private (j,k,kmn)
         DO i = 2,iend
!$omp parallel do if (iend-2.lt.nth) private (k,kmn)
            DO j = 1,n
               kmn = int(sqrt(ka(i)**2+ka(j)**2)+.501)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                  DO k = 1,n
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*(abs(a(k,j,i))**2)*tmp
                  END DO
               ENDIF
            END DO
         END DO
      ELSE
!$omp parallel do if (iend-ista.ge.nth) private (j,k,kmn)
         DO i = ista,iend
!$omp parallel do if (iend-ista.lt.nth) private (k,kmn)
            DO j = 1,n
               kmn = int(sqrt(ka(i)**2+ka(j)**2)+.501)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                  DO k = 1,n
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*(abs(a(k,j,i))**2)*tmp
                  END DO
               ENDIF
            END DO
         END DO
      ENDIF
!
! Computes the reduction between nodes
! and exports the result to a file
!
      CALL MPI_REDUCE(Ek,Ektot,n/2+1,MPI_DOUBLE_PRECISION,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='sspecperp.' // nmb // '.txt')
         WRITE(1,20) Ektot
   20    FORMAT( E23.15 )
         CLOSE(1)
      ENDIF
!
      RETURN
      END SUBROUTINE specscpe

!*****************************************************************
      SUBROUTINE sctpara(a,b,nmb)
!-----------------------------------------------------------------
!
! Computes the transfer function for the passive scalar in 
! the direction parallel to the preferred direction (rotation 
! or uniform magnetic field) in 3D Fourier space. The 
! k-shells are planes with normal (0,0,kz) (kz=0,...,n/2). 
! The output is written to a file by the first node.
!
! Parameters
!     a  : passive scalar
!     b  : nonlinear term
!     nmb: the extension used when writting the file
!
      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
!$    USE threads
      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(n/2+1) :: Ek,Ektot
      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: a,b
      REAL(KIND=GP) :: tmp
      INTEGER :: i,j,k
      INTEGER :: kmn
      CHARACTER(len=*), INTENT(IN) :: nmb

!
! Sets Ek to zero
!
      DO i = 1,n/2+1
         Ek(i) = 0.0D0
      END DO
!
! Computes the passive scalar transfer
!
      tmp = 1.0_GP/real(n,kind=GP)**6
      IF (ista.eq.1) THEN
!$omp parallel do private (k,kmn)
         DO j = 1,n
            DO k = 1,n
               kmn = int(abs(ka(k))+1)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                  Ek(kmn) = Ek(kmn)+tmp*real(a(k,j,1)*conjg(b(k,j,1)))
               ENDIF
            END DO
         END DO
!$omp parallel do if (iend-2.ge.nth) private (j,k,kmn)
         DO i = 2,iend
!$omp parallel do if (iend-2.lt.nth) private (k,kmn)
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*tmp*real(a(k,j,i)*conjg(b(k,j,i)))
                  ENDIF
               END DO
            END DO
         END DO
      ELSE
!$omp parallel do if (iend-ista.ge.nth) private (j,k,kmn)
         DO i = ista,iend
!$omp parallel do if (iend-ista.lt.nth) private (k,kmn)
            DO j = 1,n
               DO k = 1,n
                  kmn = int(abs(ka(k))+1)
                  IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*tmp*real(a(k,j,i)*conjg(b(k,j,i)))
                  ENDIF
               END DO
            END DO
         END DO
      ENDIF
!
! Computes the reduction between nodes
! and exports the result to a file
!
      CALL MPI_REDUCE(Ek,Ektot,n/2+1,MPI_DOUBLE_PRECISION,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='stranpara.' // nmb // '.txt')
         WRITE(1,30) Ektot
   30    FORMAT( E23.15 ) 
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE sctpara

!*****************************************************************
      SUBROUTINE sctperp(a,b,nmb)
!-----------------------------------------------------------------
!
! Computes the transfer function for the passive scalar in 
! the direction perpendicular to the preferred direction 
! (rotation or uniform magnetic field) in 3D Fourier space. 
! The k-shells are cylindrical surfaces (kperp=1,...,N/2+1). 
! The output is written to a file by the first node.
!
! Parameters
!     a  : passive scalar
!     b  : nonlinear term
!     nmb: the extension used when writting the file
!
      USE fprecision
      USE commtypes
      USE kes
      USE grid
      USE mpivars
      USE filefmt
!$    USE threads
      IMPLICIT NONE

      DOUBLE PRECISION, DIMENSION(n/2+1) :: Ek,Ektot
      COMPLEX(KIND=GP), INTENT(IN), DIMENSION(n,n,ista:iend) :: a,b
      REAL(KIND=GP) :: tmp
      INTEGER :: i,j,k
      INTEGER :: kmn
      CHARACTER(len=*), INTENT(IN) :: nmb

!
! Sets Ek to zero
!
      DO i = 1,n/2+1
         Ek(i) = 0.0D0
      END DO
!
! Computes the passive scalar transfer
!
      tmp = 1.0_GP/real(n,kind=GP)**6
      IF (ista.eq.1) THEN
!$omp parallel do private (k,kmn)
         DO j = 1,n
            kmn = int(sqrt(ka(1)**2+ka(j)**2)+.501)
            IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
               DO k = 1,n
!$omp atomic
                  Ek(kmn) = Ek(kmn)+tmp*real(a(k,j,1)*conjg(b(k,j,1)))
               END DO
            ENDIF
         END DO
!$omp parallel do if (iend-2.ge.nth) private (j,k,kmn)
         DO i = 2,iend
!$omp parallel do if (iend-2.lt.nth) private (k,kmn)
            DO j = 1,n
               kmn = int(sqrt(ka(i)**2+ka(j)**2)+.501)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                  DO k = 1,n
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*tmp*real(a(k,j,i)*conjg(b(k,j,i)))
                  END DO
               ENDIF
            END DO
         END DO
      ELSE
!$omp parallel do if (iend-ista.ge.nth) private (j,k,kmn)
         DO i = ista,iend
!$omp parallel do if (iend-ista.lt.nth) private (k,kmn)
            DO j = 1,n
               kmn = int(sqrt(ka(i)**2+ka(j)**2)+.501)
               IF ((kmn.gt.0).and.(kmn.le.n/2+1)) THEN
                  DO k = 1,n
!$omp atomic
                     Ek(kmn) = Ek(kmn)+2*tmp*real(a(k,j,i)*conjg(b(k,j,i)))
                  END DO
               ENDIF
            END DO
         END DO
      ENDIF
!
! Computes the reduction between nodes
! and exports the result to a file
!
      CALL MPI_REDUCE(Ek,Ektot,n/2+1,MPI_DOUBLE_PRECISION,MPI_SUM,0, &
                      MPI_COMM_WORLD,ierr)
      IF (myrank.eq.0) THEN
         OPEN(1,file='stranperp.' // nmb // '.txt')
         WRITE(1,40) Ektot
   40    FORMAT( E23.15 ) 
         CLOSE(1)
      ENDIF

      RETURN
      END SUBROUTINE sctperp