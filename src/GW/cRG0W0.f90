subroutine cRG0W0(dotest,doACFDT,exchange_kernel,doXBS,dophBSE,dophBSE2,TDA_W,TDA,dBSE,dTDA,doppBSE,singlet,triplet, & 
                 linearize,eta,doSRG,nBas,nOrb,nC,nO,nV,nR,nS,ENuc,ERHF,ERI,CAP,dipole_int,eHF)

! Perform G0W0 calculation

  implicit none
  include 'parameters.h'
  include 'quadrature.h'

! Input variables

  logical,intent(in)            :: dotest

  logical,intent(in)            :: doACFDT
  logical,intent(in)            :: exchange_kernel
  logical,intent(in)            :: doXBS
  logical,intent(in)            :: dophBSE
  logical,intent(in)            :: dophBSE2
  logical,intent(in)            :: doppBSE
  logical,intent(in)            :: TDA_W
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  logical,intent(in)            :: singlet
  logical,intent(in)            :: triplet
  logical,intent(in)            :: linearize
  double precision,intent(in)   :: eta
  logical,intent(in)            :: doSRG

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nOrb
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: ERHF
  double precision,intent(in)   :: ERI(nOrb,nOrb,nOrb,nOrb)
  double precision,intent(in)   :: CAP(nOrb,nOrb)
  double precision,intent(in)   :: dipole_int(nOrb,nOrb,ncart)
  double precision,intent(in)   :: eHF(nOrb)

! Local variables

  logical                       :: print_W   = .false.
  logical                       :: plot_self = .false.
  logical                       :: dRPA_W
  integer                       :: isp_W
  integer                       :: p
  double precision              :: flow
  double precision              :: EcRPA
  double precision              :: EcBSE(nspin)
  double precision              :: EcGM
  double precision,allocatable  :: Aph(:,:)
  double precision,allocatable  :: Bph(:,:)
  double precision,allocatable  :: Re_SigC(:)
  double precision,allocatable  :: Im_SigC(:)
  double precision,allocatable  :: Re_Z(:)
  double precision,allocatable  :: Im_Z(:)
  double precision,allocatable  :: Om(:)
  double precision,allocatable  :: XpY(:,:)
  double precision,allocatable  :: XmY(:,:)
  double precision,allocatable  :: rho(:,:,:)


  double precision,allocatable  :: Re_eGWlin(:)
  double precision, allocatable :: Im_eGWlin(:)
  double precision,allocatable  :: Re_eGW(:)
  double precision,allocatable  :: Im_eGW(:)
  double precision, allocatable :: e_cap(:)

! Hello world

  write(*,*)
  write(*,*)'***************************************'
  write(*,*)'* Restricted complex G0W0 Calculation *'
  write(*,*)'***************************************'
  write(*,*)

! Spin manifold and TDA for dynamical screening

  isp_W = 1
  dRPA_W = .true.

  if(TDA_W) then 
    write(*,*) 'Tamm-Dancoff approximation for dynamical screening!'
    write(*,*)
  end if

! SRG regularization

  flow = 500d0

  if(doSRG) then
    ! Not implemented
    write(*,*) '*** SRG regularized G0W0 scheme ***'
    write(*,*) '!!! No SRG with cRG0W0 !!!'
    write(*,*)

  end if

! Memory allocation

  allocate(Aph(nS,nS),Bph(nS,nS),Re_SigC(nOrb),Im_SigC(nOrb),Re_Z(nOrb),Im_Z(nOrb),Om(nS),XpY(nS,nS),XmY(nS,nS),rho(nOrb,nOrb,nS), & 
           Re_eGW(nOrb),Im_eGW(nOrb),Re_eGWlin(nOrb),Im_eGWlin(nOrb),e_cap(nOrb))
  do p = 1, nOrb
        e_cap(p) = CAP(p,p)  
  end do
!-------------------!
! Compute screening !
!-------------------!

                 call phRLR_A(isp_W,dRPA_W,nOrb,nC,nO,nV,nR,nS,1d0,eHF,ERI,Aph)
  if(.not.TDA_W) call phRLR_B(isp_W,dRPA_W,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

  call phRLR(TDA_W,nS,Aph,Bph,EcRPA,Om,XpY,XmY)

  if(print_W) call print_excitation_energies('phRPA@RHF','singlet',nS,Om)

!--------------------------!
! Compute spectral weights !
!--------------------------!

  call RGW_excitation_density(nOrb,nC,nO,nR,nS,ERI,XpY,rho)

!------------------------!
! Compute GW self-energy !
!------------------------!
  call cRGW_self_energy_diag(eta,nBas,nOrb,nC,nO,nV,nR,nS,eHF,Om,rho,EcGM,Re_SigC,Im_SigC,Re_Z,Im_Z,e_cap)

!-----------------------------------!
! Solve the quasi-particle equation !
!-----------------------------------!

  ! Linearized or graphical solution?
  Re_eGWlin(:) = eHF(:) + Re_Z(:)*Re_SigC(:) - Im_Z(:)*Im_SigC(:)
  Im_eGWlin(:) = e_cap(:) + Re_Z(:)*Im_SigC(:) + Im_Z(:)*Re_SigC(:)

  if(linearize) then 
 
    write(*,*) ' *** Quasiparticle energies obtained by linearization *** '
    write(*,*)

    Re_eGW(:) = Re_eGWlin(:)
    Im_eGW(:) = Im_eGWlin(:)

  else 

    write(*,*) ' *** Quasiparticle energies obtained by root search *** '
    write(*,*)
  
    call cRGW_QP_graph(doSRG,eta,flow,nOrb,nC,nO,nV,nR,nS,eHF,e_cap,Om,rho,Re_eGWlin,Im_eGWlin,eHF,e_cap,Re_eGW,Im_eGW,Re_Z,Im_Z)
  end if

! Plot self-energy, renormalization factor, and spectral function

  if(plot_self) call RGW_plot_self_energy(nOrb,eta,nC,nO,nV,nR,nS,eHF,eHF,Om,rho)

! Cumulant expansion 

! call RGWC(dotest,eta,nOrb,nC,nO,nV,nR,nS,Om,rho,eHF,eHF,eGW,Z)

! Compute the RPA correlation energy

                 call phRLR_A(isp_W,dRPA_W,nOrb,nC,nO,nV,nR,nS,1d0,Re_eGW,ERI,Aph)
  if(.not.TDA_W) call phRLR_B(isp_W,dRPA_W,nOrb,nC,nO,nV,nR,nS,1d0,ERI,Bph)

  call phRLR(TDA_W,nS,Aph,Bph,EcRPA,Om,XpY,XmY)

!--------------!
! Dump results !
!--------------!

  call print_cRG0W0(nOrb,nO,eHF,ENuc,ERHF,Re_SigC,Im_SigC,Re_Z,Im_Z,Re_eGW,Im_eGW,EcRPA,EcGM,CAP)
!---------------------------!
! Perform phBSE calculation !
!---------------------------!
!
!  if(dophBSE) then
!
!    call RGW_phBSE(dophBSE2,exchange_kernel,TDA_W,TDA,dBSE,dTDA,singlet,triplet,eta, & 
!                   nOrb,nC,nO,nV,nR,nS,ERI,dipole_int,eHF,Re_eGW,EcBSE)
!
!    write(*,*)
!    write(*,*)'-------------------------------------------------------------------------------'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@BSE@G0W0@RHF correlation energy (singlet) = ',EcBSE(1),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@BSE@G0W0@RHF correlation energy (triplet) = ',EcBSE(2),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@BSE@G0W0@RHF correlation energy           = ',sum(EcBSE),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@BSE@G0W0@RHF total       energy           = ',ENuc + ERHF + sum(EcBSE),' au'
!    write(*,*)'-------------------------------------------------------------------------------'
!    write(*,*)
!
!    ! Compute the BSE correlation energy via the adiabatic connection fluctuation dissipation theorem
!
!    if(doACFDT) then
!
!      call RGW_phACFDT(exchange_kernel,doXBS,TDA_W,TDA,singlet,triplet,eta,nOrb,nC,nO,nV,nR,nS,ERI,eHF,Re_eGW,EcBSE)
!
!      write(*,*)
!      write(*,*)'-------------------------------------------------------------------------------'
!      write(*,'(2X,A50,F20.10,A3)') 'AC@phBSE@G0W0@RHF correlation energy (singlet) = ',EcBSE(1),' au'
!      write(*,'(2X,A50,F20.10,A3)') 'AC@phBSE@G0W0@RHF correlation energy (triplet) = ',EcBSE(2),' au'
!      write(*,'(2X,A50,F20.10,A3)') 'AC@phBSE@G0W0@RHF correlation energy           = ',sum(EcBSE),' au'
!      write(*,'(2X,A50,F20.10,A3)') 'AC@phBSE@G0W0@RHF total       energy           = ',ENuc + ERHF + sum(EcBSE),' au'
!      write(*,*)'-------------------------------------------------------------------------------'
!      write(*,*)
!
!    end if
!
!  end if
!
!!---------------------------!
!! Perform ppBSE calculation !
!!---------------------------!
!
!  if(doppBSE) then
!
!    call RGW_ppBSE(TDA_W,TDA,dBSE,dTDA,singlet,triplet,eta,nOrb,nC,nO,nV,nR,nS,ERI,dipole_int,eHF,Re_eGW,EcBSE)
!
!    write(*,*)
!    write(*,*)'-------------------------------------------------------------------------------'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0W0@RHF correlation energy (singlet) = ',EcBSE(1),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0W0@RHF correlation energy (triplet) = ',EcBSE(2),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0W0@RHF correlation energy           = ',sum(EcBSE),' au'
!    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0W0@RHF total       energy           = ',ENuc + ERHF + sum(EcBSE),' au'
!    write(*,*)'-------------------------------------------------------------------------------'
!    write(*,*)
!
!  end if
!  
!! Testing zone
!
!  if(dotest) then
!
!    call dump_test_value('R','G0W0 correlation energy',EcRPA)
!    call dump_test_value('R','G0W0 HOMO energy',Re_eGW(nO))
!    call dump_test_value('R','G0W0 LUMO energy',Re_eGW(nO+1))
!
!  end if
!
end subroutine 
