subroutine cRGW_QP_graph(doSRG,eta,flow,nBas,nC,nO,nV,nR,nS,eHF,e_cap,Om,rho,Re_eGWlin,Im_eGWlin, &
        Re_eOld,Im_eOld,Re_eGW,Im_eGW,Re_Z,Im_Z)

! Compute the graphical solution of the QP equation

  implicit none
  include 'parameters.h'

! Input variables

  integer,intent(in)            :: nBas
  integer,intent(in)            :: nC
  integer,intent(in)            :: nO
  integer,intent(in)            :: nV
  integer,intent(in)            :: nR
  integer,intent(in)            :: nS

  logical,intent(in)            :: doSRG
  double precision,intent(in)   :: eta
  double precision,intent(in)   :: flow
  double precision,intent(in)   :: eHF(nBas)
  double precision,intent(in)   :: e_cap(nBas)
  double precision,intent(in)   :: Om(nS)
  double precision,intent(in)   :: rho(nBas,nBas,nS)

  double precision,intent(in)   :: Re_eGWlin(nBas)
  double precision,intent(in)   :: Im_eGWlin(nBas)
  double precision,external     :: cRGW_Re_SigC,cRGW_Re_dSigC
  double precision,external     :: cRGW_Im_SigC,cRGW_Im_dSigC
  double precision,intent(in)   :: Re_eOld(nBas)
  double precision,intent(in)   :: Im_eOld(nBas)

! Local variables

  integer                       :: p
  integer                       :: nIt
  integer,parameter             :: maxIt = 64
  double precision,parameter    :: thresh = 1d-6
  double precision              :: Re_SigC,Re_dSigC
  double precision              :: Im_SigC,Im_dSigC
  double precision              :: Re_f,Im_f,Re_df,Im_df
  double precision              :: Re_w
  double precision              :: Im_w

! Output variables

  double precision,intent(out)  :: Re_eGW(nBas),Im_eGW(nBas)
  double precision,intent(out)  :: Re_Z(nBas),Im_Z(nBas)

! Run Newton's algorithm to find the root

  write(*,*)'-----------------------------------------------------'
  write(*,'(A5,1X,A3,1X,A16,1X,A16,1X,A10)') 'Orb.','It.','Re(e_GWlin) (eV)','Re(e_GW (eV))','Re(Z)'
  write(*,'(A5,1X,A3,1X,A16,1X,A16,1X,A10)') 'Orb.','It.','Im(e_GWlin) (eV)','Im(e_GW (eV))','Im(Z)'
  write(*,*)'-----------------------------------------------------'

  do p=nC+1,nBas-nR

    Re_w = Re_eGWlin(p)
    Im_w = Im_eGWlin(p)
    nIt = 0
    Re_f = 1d0
    Im_f = 1d0
    
    do while (sqrt(Re_f**2+Im_f**2) > thresh .and. nIt < maxIt)
    
      nIt = nIt + 1


      Re_SigC  = cRGW_Re_SigC(p,Re_w,Im_w,eta,nBas,nC,nO,nV,nR,nS,Re_eOld,Im_eold,Om,rho)
      Im_SigC  = cRGW_Im_SigC(p,Re_w,Im_w,eta,nBas,nC,nO,nV,nR,nS,Re_eOld,Im_eold,Om,rho)
      Re_dSigC = cRGW_Re_dSigC(p,Re_w,Im_w,eta,nBas,nC,nO,nV,nR,nS,Re_eOld,Im_eold,Om,rho)
      Im_dSigC = cRGW_Im_dSigC(p,Re_w,Im_w,eta,nBas,nC,nO,nV,nR,nS,Re_eOld,Im_eold,Om,rho)


      Re_f  = Re_w - eHF(p) - Re_SigC
      Im_f  = Im_w - e_cap(p) - Im_SigC
      Re_df = (1d0 - Re_dSigC)/((1d0 - Re_dSigC)**2 + Im_dSigC**2)
      Im_df = Im_dSigC/((1d0 - Re_dSigC)**2 + Im_dSigC**2)
      Re_w = Re_w - Re_df*Re_f + Im_df*Im_f
      Im_w = Im_w - Re_f*Im_df - Re_df*Im_f
    
    end do
 
    if(nIt == maxIt) then 

      Re_eGW(p) = Re_eGWlin(p)
      write(*,'(I5,1X,I3,1X,F15.9,1X,F15.9,1X,F10.6,1X,A12)') p,nIt,Re_eGWlin(p)*HaToeV,Re_eGW(p)*HaToeV,Re_Z(p),'Cvg Failed!'

    else

      Re_eGW(p) = Re_w
      Im_eGW(p) = Im_w
      Re_Z(p)   = Re_df
      Im_Z(p)   = Im_df

      write(*,'(I5,1X,I3,1X,F15.9,1X,F15.9,1X,F10.6)') p,nIt,Re_eGWlin(p)*HaToeV,Re_eGW(p)*HaToeV,Re_Z(p)
      write(*,'(I5,1X,I3,1X,F15.9,1X,F15.9,1X,F10.6)') p,nIt,Im_eGWlin(p)*HaToeV,Im_eGW(p)*HaToeV,Im_Z(p)

    end if
          
  write(*,*)'-----------------------------------------------------'
  end do
  write(*,*)

end subroutine 
