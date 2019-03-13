subroutine read_geometry(nAt,ZNuc,rA,ENuc)

! Read molecular geometry

  implicit none

  include 'parameters.h'

! Ouput variables

  integer,intent(in)            :: nAt

! Local variables

  integer                       :: i,j
  double precision              :: RAB
  character(len=2)              :: El
  integer,external              :: element_number

! Ouput variables

  double precision,intent(out)  :: ZNuc(NAt),rA(nAt,ncart),ENuc

! Open file with geometry specification

  open(unit=1,file='input/molecule')

! Read geometry

  read(1,*) 
  read(1,*) 
  read(1,*) 

  do i=1,nAt
    read(1,*) El,rA(i,1),rA(i,2),rA(i,3)
    ZNuc(i) = element_number(El)
  enddo

! Compute nuclear repulsion energy

  ENuc = 0

  do i=1,nAt-1
    do j=i+1,nAt
      RAB = (rA(i,1)-rA(j,1))**2 + (rA(i,2)-rA(j,2))**2 + (rA(i,3)-rA(j,3))**2
      ENuc = ENuc + ZNuc(i)*ZNuc(j)/sqrt(RAB)
    enddo
  enddo

! Close file with geometry specification
  close(unit=1)

! Print geometry
  write(*,'(A28)') '------------------'
  write(*,'(A28)') 'Molecular geometry'
  write(*,'(A28)') '------------------'
  do i=1,NAt
    write(*,'(A28,1X,I16)') 'Atom n. ',i
    write(*,'(A28,1X,F16.10)') 'Z = ',ZNuc(i)
    write(*,'(A28,1X,F16.10,F16.10,F16.10)') 'Atom coordinates:',(rA(i,j),j=1,ncart)
  enddo
  write(*,*)
  write(*,'(A28)') '------------------'
  write(*,'(A28,1X,F16.10)') 'Nuclear repulsion energy = ',ENuc
  write(*,'(A28)') '------------------'
  write(*,*)

end subroutine read_geometry
