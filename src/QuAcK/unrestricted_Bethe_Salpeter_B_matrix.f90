subroutine unrestricted_Bethe_Salpeter_B_matrix(eta,nBas,nC,nO,nV,nR,nSa,nSb,nSt,lambda, & 
                                                ERI_aaaa,ERI_aabb,ERI_bbbb,ERI_abab,     & 
                                                Omega,rho,B_lr)

! Compute the extra term for Bethe-Salpeter equation for linear response 

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC(nspin)
  integer,intent(in)            :: nO(nspin)
  integer,intent(in)            :: nV(nspin)
  integer,intent(in)            :: nR(nspin)
  integer,intent(in)            :: nSa
  integer,intent(in)            :: nSb
  integer,intent(in)            :: nSt
  double precision,intent(in)   :: eta
  double precision,intent(in)   :: lambda
  double precision,intent(in)   :: ERI_aaaa(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_aabb(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_bbbb(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: ERI_abab(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: Omega(nSt)
  double precision,intent(in)   :: rho(nBas,nBas,nSt,nspin)
  
! Local variables

  double precision              :: chi
  double precision              :: eps
  integer                       :: i,j,a,b,ia,jb,kc

! Output variables

  double precision,intent(out)  :: B_lr(nSt,nSt)

  ! alpha-alpha block

  ia = 0
  do i=nC(1)+1,nO(1)
    do a=nO(1)+1,nBas-nR(1)
      ia = ia + 1
      jb = 0
      do j=nC(1)+1,nO(1)
        do b=nO(1)+1,nBas-nR(1)
          jb = jb + 1
 
          chi = 0d0
          do kc=1,nSt
            eps = Omega(kc)**2 + eta**2
            chi = chi + rho(i,b,kc,1)*rho(a,j,kc,1)*Omega(kc)/eps & 
                      + rho(i,b,kc,1)*rho(a,j,kc,1)*Omega(kc)/eps
          enddo

          B_lr(ia,jb) = B_lr(ia,jb) - lambda*ERI_aaaa(i,j,b,a) + 2d0*lambda*chi

        enddo
      enddo
    enddo
  enddo

  ! alpha-beta block

  ia = 0
  do i=nC(1)+1,nO(1)
    do a=nO(1)+1,nBas-nR(1)
      ia = ia + 1
      jb = 0
      do j=nC(2)+1,nO(2)
        do b=nO(2)+1,nBas-nR(2)
          jb = jb + 1
 
          chi = 0d0
          do kc=1,nSt
            eps = Omega(kc)**2 + eta**2
            chi = chi + rho(i,b,kc,1)*rho(a,j,kc,1)*Omega(kc)/eps & 
                      + rho(i,b,kc,2)*rho(a,j,kc,2)*Omega(kc)/eps
          enddo

          B_lr(ia,nSa+jb) = B_lr(ia,nSa+jb) - lambda*ERI_aabb(i,j,b,a) + 2d0*lambda*chi

        enddo
      enddo
    enddo
  enddo

  ! beta-alpha block

  ia = 0
  do i=nC(2)+1,nO(2)
    do a=nO(2)+1,nBas-nR(2)
      ia = ia + 1
      jb = 0
      do j=nC(1)+1,nO(1)
        do b=nO(1)+1,nBas-nR(1)
          jb = jb + 1
 
          chi = 0d0
          do kc=1,nSt
            eps = Omega(kc)**2 + eta**2
            chi = chi + rho(i,b,kc,2)*rho(a,j,kc,2)*Omega(kc)/eps & 
                      + rho(i,b,kc,1)*rho(a,j,kc,1)*Omega(kc)/eps
          enddo

          B_lr(nSa+ia,jb) = B_lr(nSa+ia,jb) - lambda*ERI_aabb(j,i,a,b) + 2d0*lambda*chi

        enddo
      enddo
    enddo
  enddo

  ! beta-beta block

  ia = 0
  do i=nC(2)+1,nO(2)
    do a=nO(2)+1,nBas-nR(2)
      ia = ia + 1
      jb = 0
      do j=nC(2)+1,nO(2)
        do b=nO(2)+1,nBas-nR(2)
          jb = jb + 1
 
          chi = 0d0
          do kc=1,nSt
            eps = Omega(kc)**2 + eta**2
            chi = chi + rho(i,b,kc,2)*rho(a,j,kc,2)*Omega(kc)/eps & 
                      + rho(i,b,kc,2)*rho(a,j,kc,2)*Omega(kc)/eps
          enddo

          B_lr(nSa+ia,nSa+jb) = B_lr(nSa+ia,nSa+jb) - lambda*ERI_bbbb(i,j,b,a) + 2d0*lambda*chi

        enddo
      enddo
    enddo
  enddo

end subroutine unrestricted_Bethe_Salpeter_B_matrix
