subroutine RG0F2(dotest,dophBSE,doppBSE,TDA,dBSE,dTDA,singlet,triplet,linearize,eta,regularize, &
                 nBas,nC,nO,nV,nR,nS,ENuc,ERHF,ERI,dipole_int,eHF)

! Perform a one-shot second-order Green function calculation

  implicit none
  include 'parameters.h'

! Input variables

  logical,intent(in)            :: dotest

  logical,intent(in)            :: dophBSE
  logical,intent(in)            :: doppBSE
  logical,intent(in)            :: TDA
  logical,intent(in)            :: dBSE
  logical,intent(in)            :: dTDA
  logical,intent(in)            :: singlet
  logical,intent(in)            :: triplet
  logical,intent(in)            :: linearize
  double precision,intent(in)   :: eta
  logical,intent(in)            :: regularize
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nO
  integer,intent(in)            :: nC
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS
  double precision,intent(in)   :: ENuc
  double precision,intent(in)   :: ERHF
  double precision,intent(in)   :: eHF(nBas)
  double precision,intent(in)   :: ERI(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: dipole_int(nBas,nBas,ncart)

! Local variables

  double precision              :: Ec
  double precision              :: EcBSE(nspin)
  double precision,allocatable  :: eGFlin(:)
  double precision,allocatable  :: eGF(:)
  double precision,allocatable  :: SigC(:)
  double precision,allocatable  :: Z(:)

! Hello world

  write(*,*)
  write(*,*)'*******************************'
  write(*,*)'* Restricted G0F2 Calculation *'
  write(*,*)'*******************************'
  write(*,*)

! Memory allocation

  allocate(SigC(nBas), Z(nBas), eGFlin(nBas), eGF(nBas))

! Frequency-dependent second-order contribution

  if(regularize) then 

    call RGF2_reg_self_energy_diag(eta,nBas,nC,nO,nV,nR,eHF,ERI,SigC,Z)

  else

    call RGF2_self_energy_diag(eta,nBas,nC,nO,nV,nR,eHF,ERI,SigC,Z)

  end if
  
  eGFlin(:) = eHF(:) + Z(:)*SigC(:)

  if(linearize) then

    write(*,*) '*** Quasiparticle energies obtained by linearization ***'

    eGF(:) = eGFlin(:)

  else

    write(*,*) ' *** Quasiparticle energies obtained by root search *** '
    write(*,*)

    call RGF2_QP_graph(eta,nBas,nC,nO,nV,nR,eHF,ERI,eGFlin,eHF,eGF,Z)

  end if

  ! Print results

  call RMP2(.false.,regularize,nBas,nC,nO,nV,nR,ERI,ENuc,ERHF,eGF,Ec)
  call print_RG0F2(nBas,nO,eHF,SigC,eGF,Z,ENuc,ERHF,Ec)

! Perform BSE2 calculation

  if(dophBSE) then 
  
    call RGF2_phBSE2(TDA,dBSE,dTDA,singlet,triplet,eta,nBas,nC,nO,nV,nR,nS,ERI,dipole_int,eGF,EcBSE)

    write(*,*)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@G0F2  correlation energy (singlet) =',EcBSE(1)
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@G0F2  correlation energy (triplet) =',EcBSE(2)
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@G0F2  correlation energy           =',sum(EcBSE)
    write(*,'(2X,A50,F20.10)') 'Tr@phBSE@G0F2  total energy                 =',ENuc + ERHF + sum(EcBSE)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,*)

  end if

! Perform ppBSE2 calculation

  if(doppBSE) then 
   
    call RGF2_ppBSE2(TDA,dBSE,dTDA,singlet,triplet,eta,nBas,nC,nO,nV,nR,ERI,dipole_int,eGF,EcBSE)

    EcBSE(2) = 3d0*EcBSE(2)

    write(*,*)
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0F2 correlation energy (singlet) =',EcBSE(1),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0F2 correlation energy (triplet) =',EcBSE(2),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0F2 correlation energy           =',sum(EcBSE),' au'
    write(*,'(2X,A50,F20.10,A3)') 'Tr@ppBSE@G0F2 total energy                 =',ENuc + ERHF + sum(EcBSE),' au'
    write(*,*)'-------------------------------------------------------------------------------'
    write(*,*)

  end if

! Testing zone

  if(dotest) then

    call dump_test_value('R','G0F2 correlation energy',Ec)
    call dump_test_value('R','G0F2 HOMO energy',eGF(nO))
    call dump_test_value('R','G0F2 LUMO energy',eGF(nO+1))

  end if

  deallocate(SigC, Z, eGFlin, eGF)

end subroutine 
