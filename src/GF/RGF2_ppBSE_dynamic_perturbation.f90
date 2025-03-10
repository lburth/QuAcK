subroutine RGF2_ppBSE_dynamic_perturbation(ispin,dTDA,eta,nBas,nC,nO,nV,nR,nOO,nVV,eGF,ERI,dipole_int, & 
                                           Om1,X1,Y1,Om2,X2,Y2,KB_sta,KC_sta,KD_sta)

! Compute dynamical effects via perturbation theory for BSE

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: ispin
  logical,intent(in)            :: dTDA 
  double precision,intent(in)   :: eta
  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nOO
  integer,intent(in)            :: nVV

  double precision,intent(in)   :: ERI(nBas,nBas,nBas,nBas)
  double precision,intent(in)   :: eGF(nBas)
  double precision,intent(in)   :: dipole_int(nBas,nBas,ncart)
  double precision,intent(in)   :: Om1(nVV)
  double precision,intent(in)   :: X1(nVV,nVV)
  double precision,intent(in)   :: Y1(nOO,nVV)
  double precision,intent(in)   :: Om2(nOO)
  double precision,intent(in)   :: X2(nVV,nOO)
  double precision,intent(in)   :: Y2(nOO,nOO)
  double precision,intent(in)   :: KB_sta(nVV,nOO)
  double precision,intent(in)   :: KC_sta(nVV,nVV)
  double precision,intent(in)   :: KD_sta(nOO,nOO)

! Local variables

  integer                       :: ab,ij,kl

  integer                       :: maxOO = 10
  integer                       :: maxVV = 0

  double precision,allocatable  :: Om1_dyn(:)
  double precision,allocatable  :: Om2_dyn(:)
  double precision,allocatable  :: Z1_dyn(:)
  double precision,allocatable  :: Z2_dyn(:)

  double precision,allocatable  :: KB_dyn(:,:)
  double precision,allocatable  :: KC_dyn(:,:)
  double precision,allocatable  :: KD_dyn(:,:)
  double precision,allocatable  :: ZC_dyn(:,:)
  double precision,allocatable  :: ZD_dyn(:,:)

! Memory allocation

  allocate(Om1_dyn(maxVV),Om2_dyn(maxOO),Z1_dyn(maxVV),Z2_dyn(maxOO), & 
           KB_dyn(nVV,nOO),KC_dyn(nVV,nVV),KD_dyn(nOO,nOO),   & 
           ZC_dyn(nVV,nVV),ZD_dyn(nOO,nOO))

  if(dTDA) then 
    write(*,*)
    write(*,*) '*** dynamical TDA activated ***'
    write(*,*)
  end if

  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,*) ' First-order dynamical correction to static ppBSE@GF2 double electron attachment energies             '
  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,'(2X,A5,1X,A20,1X,A20,1X,A20,1X,A20)') '#','Static (eV)','Dynamic (eV)','Correction (eV)','Renorm. (eV)'
  write(*,*) '---------------------------------------------------------------------------------------------------'

  do ab=1,min(nVV,maxVV)

    if(dTDA) then

      call RGF2_ppBSE_dynamic_kernel_C(ispin,eta,nBas,nC,nO,nV,nR,nVV,1d0,ERI,eGF,Om1(ab),KC_dyn,ZC_dyn)
  
      Z1_dyn(ab)  = dot_product(X1(:,ab),matmul(ZC_dyn,X1(:,ab)))
      Om1_dyn(ab) = dot_product(X1(:,ab),matmul(KC_dyn - KC_sta,X1(:,ab)))

    else

      call RGF2_ppBSE_dynamic_kernel_B(ispin,eta,nBas,nC,nO,nV,nR,nOO,nVV,1d0,ERI,eGF,KB_dyn)
      call RGF2_ppBSE_dynamic_kernel_C(ispin,eta,nBas,nC,nO,nV,nR,nVV,1d0,ERI,eGF,Om1(ab),KC_dyn,ZC_dyn)
      call RGF2_ppBSE_dynamic_kernel_D(ispin,eta,nBas,nC,nO,nV,nR,nOO,1d0,ERI,eGF,Om1(ab),KD_dyn,ZD_dyn)

      Z1_dyn(ab)  = dot_product(X1(:,ab),matmul(ZC_dyn,X1(:,ab))) &
                  + dot_product(Y1(:,ab),matmul(ZD_dyn,Y1(:,ab)))

      Om1_dyn(ab) = dot_product(X1(:,ab),matmul(KC_dyn - KC_sta,X1(:,ab))) &
                  - dot_product(Y1(:,ab),matmul(KD_dyn - KD_sta,Y1(:,ab))) &
                  + dot_product(X1(:,ab),matmul(KB_dyn - KB_sta,Y1(:,ab))) &
                  - dot_product(Y1(:,ab),matmul(transpose(KB_dyn - KB_sta),X1(:,ab)))

    end if
  
    Z1_dyn(ab)  = 1d0/(1d0 - Z1_dyn(ab))
    Om1_dyn(ab) = Z1_dyn(ab)*Om1_dyn(ab)

    write(*,'(2X,I5,5X,F15.6,5X,F15.6,5X,F15.6,5X,F15.6)') & 
      ab,Om1(ab)*HaToeV,(Om1(ab)+Om1_dyn(ab))*HaToeV,Om1_dyn(ab)*HaToeV,Z1_dyn(ab)

  end do
  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,*) 

  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,*) ' First-order dynamical correction to static ppBSE@GF2 double electron detachment energies             '
  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,'(2X,A5,1X,A20,1X,A20,1X,A20,1X,A20)') '#','Static (eV)','Dynamic (eV)','Correction (eV)','Renorm. (eV)'
  write(*,*) '---------------------------------------------------------------------------------------------------'

  kl = 0
  do ij=max(1,nOO+1-maxOO),nOO
    kl = kl + 1

    if(dTDA) then

      call RGF2_ppBSE_dynamic_kernel_D(ispin,eta,nBas,nC,nO,nV,nR,nOO,1d0,ERI,eGF,-Om2(ij),KD_dyn,ZD_dyn)

      Z2_dyn(kl)  = dot_product(Y2(:,ij),matmul(ZD_dyn,Y2(:,ij)))
      Om2_dyn(kl) = dot_product(Y2(:,ij),matmul(KD_dyn - KD_sta,Y2(:,ij)))

    else

      call RGF2_ppBSE_dynamic_kernel_B(ispin,eta,nBas,nC,nO,nV,nR,nOO,nVV,1d0,ERI,eGF,KB_dyn)
      call RGF2_ppBSE_dynamic_kernel_C(ispin,eta,nBas,nC,nO,nV,nR,nVV,1d0,ERI,eGF,-Om2(ij),KC_dyn,ZC_dyn)
      call RGF2_ppBSE_dynamic_kernel_D(ispin,eta,nBas,nC,nO,nV,nR,nOO,1d0,ERI,eGF,-Om2(ij),KD_dyn,ZD_dyn)

      Z2_dyn(kl)  = dot_product(X2(:,ij),matmul(ZC_dyn,X2(:,ij))) &
                  + dot_product(Y2(:,ij),matmul(ZD_dyn,Y2(:,ij)))

      Om2_dyn(kl) = dot_product(X2(:,ij),matmul(KC_dyn - KC_sta,X2(:,ij))) &
                  - dot_product(Y2(:,ij),matmul(KD_dyn - KD_sta,Y2(:,ij))) &
                  + dot_product(X2(:,ij),matmul(KB_dyn - KB_sta,Y2(:,ij))) &
                  - dot_product(Y2(:,ij),matmul(transpose(KB_dyn - KB_sta),X2(:,ij)))

    end if

    Z2_dyn(kl)  = 1d0/(1d0 - Z2_dyn(kl))
    Om2_dyn(kl) = Z2_dyn(kl)*Om2_dyn(kl)

    write(*,'(2X,I5,5X,F15.6,5X,F15.6,5X,F15.6,5X,F15.6)') & 
      ij,Om2(ij)*HaToeV,(Om2(ij)+Om2_dyn(ij))*HaToeV,Om2_dyn(ij)*HaToeV,Z2_dyn(ij)

  end do
  write(*,*) '---------------------------------------------------------------------------------------------------'
  write(*,*) 

end subroutine 
