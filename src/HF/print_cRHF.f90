
! ---

subroutine print_cRHF(nBas, nOrb, nO, eHF, cHF, ENuc, ET, EV, EJ, EK, ERHF, dipole)

! Print one-electron energies and other stuff for G0W0

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)                 :: nBas, nOrb
  integer,intent(in)                 :: nO
  complex*16,intent(in)              :: eHF(nOrb)
  complex*16,intent(in)              :: cHF(nBas,nOrb)
  double precision,intent(in)        :: ENuc
  complex*16,intent(in)              :: ET
  complex*16,intent(in)              :: EJ
  complex*16,intent(in)              :: EK
  complex*16,intent(in)              :: EV
  complex*16,intent(in)              :: ERHF
  double precision,intent(in)        :: dipole(ncart)

! Local variables

  integer                            :: ixyz
  integer                            :: HOMO
  integer                            :: LUMO
  complex*16                         :: Gap
  double precision                   :: S,S2

  logical                            :: dump_orb = .false.

! HOMO and LUMO

  HOMO = nO
  LUMO = HOMO + 1
  Gap = eHF(LUMO)-eHF(HOMO)

  S2 = 0d0
  S  = 0d0

! Dump results

  write(*,*)
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A33)')           ' Summary               '
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' One-electron energy = ',real(ET + EV),'+',aimag(ET+EV),' au'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Kinetic      energy = ',real(ET),'+',aimag(ET),' au'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Potential    energy = ',real(EV),'+',aimag(Ev),'i',' au'
  write(*,'(A50)')           '------------------------------------------------------'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Two-electron energy = ',real(EJ + EK),'+',aimag(EJ+EK),'i',' au'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Hartree      energy = ',real(EJ),'+',aimag(EJ),'i',' au'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Exchange     energy = ',real(EK),'+',aimag(EK),'i',' au'
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' Electronic   energy = ',real(ERHF),'+',aimag(ERHF),'i',' au'
  write(*,'(A33,1X,F16.10,A3)') ' Nuclear   repulsion = ',ENuc,' au'
  write(*,'(A33,1X,F16.10,A1,F16.10,A1,A3)') ' cRHF          energy = ',real(ERHF + ENuc),'+',aimag(ERHF+ENuc),'i',' au'
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A33,1X,F16.6,A3)')  ' HF HOMO      energy = ',real(eHF(HOMO))*HaToeV,' eV'
  write(*,'(A33,1X,F16.6,A3)')  ' HF LUMO      energy = ',real(eHF(LUMO))*HaToeV,' eV'
  write(*,'(A33,1X,F16.6,A3)')  ' HF HOMO-LUMO gap    = ',real(Gap)*HaToeV,' eV'
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A33,1X,F16.6)')     ' <Sz>                = ',S
  write(*,'(A33,1X,F16.6)')     ' <S^2>               = ',S2
  write(*,'(A50)')           '------------------------------------------------------------'
  write(*,'(A36)')           ' Dipole moment (Debye)    '
  write(*,'(10X,4A10)')      'X','Y','Z','Tot.'
  write(*,'(10X,4F10.4)')    (real(dipole(ixyz))*auToD,ixyz=1,ncart),norm2(real(dipole))*auToD
  write(*,'(A50)')           '---------------------------------------------'
  write(*,*)

! Print results

  if(dump_orb) then 
    write(*,'(A50)') '---------------------------------------'
    write(*,'(A50)') ' cRHF orbital coefficients '
    write(*,'(A50)') '---------------------------------------'
    call complex_matout(nBas, nOrb, cHF)
    write(*,*)
  end if
  write(*,'(A50)') '---------------------------------------'
  write(*,'(A50)') ' cRHF orbital energies (au) '
  write(*,'(A50)') '---------------------------------------'
  call complex_vecout(nOrb, eHF)
  write(*,*)

end subroutine 
