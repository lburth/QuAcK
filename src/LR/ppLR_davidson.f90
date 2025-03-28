
! ---

subroutine ppLR_davidson(ispin, TDA, nC, nO, nR, nOrb, nOO, nVV, lambda, e, eF, ERI, &
                         supp_data_int, supp_data_int_size,                          &
                         supp_data_dbl, supp_data_dbl_size,                          &
                         Om, R, n_states, n_states_diag, kernel, mode_dav)

  ! 
  ! Extract the low n_states 
  ! Om(i) (eigenvalues) and 
  ! R(:,i) (right-eigenvectors) 
  ! of the pp-RPA matrix
  !
  ! TODO
  !   (+C    +B) 
  !   (        )  
  !   (-B.T  -D)
  !

  implicit none

  logical,          intent(in)  :: TDA
  integer,          intent(in)  :: ispin
  integer,          intent(in)  :: nC, nO, nR, nOrb, nOO, nVV
  integer,          intent(in)  :: n_states      ! nb of physical states
  integer,          intent(in)  :: n_states_diag ! nb of states used to get n_states
  integer,          intent(in)  :: supp_data_int_size
  integer,          intent(in)  :: supp_data_dbl_size
  integer,          intent(in)  :: mode_dav
  character(len=*), intent(in)  :: kernel
  double precision, intent(in)  :: lambda, eF
  double precision, intent(in)  :: e(nOrb)
  double precision, intent(in)  :: ERI(nOrb,nOrb,nOrb,nOrb)
  integer,          intent(in)  :: supp_data_int(supp_data_int_size)
  double precision, intent(in)  :: supp_data_dbl(supp_data_dbl_size)
  double precision, intent(out) :: Om(n_states)
  double precision, intent(out) :: R(nOO+nVV,n_states_diag)

  if(mode_dav .eq. 1) then

    call ppLR_davidson_1(ispin, TDA, nC, nO, nR, nOrb, nOO, nVV, lambda, e(1), eF, ERI(1,1,1,1),     &
                         supp_data_int(1), supp_data_int_size, supp_data_dbl(1), supp_data_dbl_size, &
                         Om(1), R(1,1), n_states, n_states_diag, kernel)

  elseif(mode_dav .eq. 2) then

    call ppLR_davidson_2(ispin, TDA, nC, nO, nR, nOrb, nOO, nVV, lambda, e(1), eF, ERI(1,1,1,1),     &
                         supp_data_int(1), supp_data_int_size, supp_data_dbl(1), supp_data_dbl_size, &
                         Om(1), R(1,1), n_states, n_states_diag, kernel)

  else

    print*, " unknown Davidson's variant"
    stop

  endif

  return
end

! ---

subroutine ppLR_davidson_1(ispin, TDA, nC, nO, nR, nOrb, nOO, nVV, lambda, e, eF, ERI, &
                           supp_data_int, supp_data_int_size,                          &
                           supp_data_dbl, supp_data_dbl_size,                          &
                           Om, R, n_states, n_states_diag, kernel)

  use omp_lib

  implicit none

  logical,          intent(in)  :: TDA
  integer,          intent(in)  :: ispin
  integer,          intent(in)  :: nC, nO, nR, nOrb, nOO, nVV
  integer,          intent(in)  :: n_states      ! nb of physical states
  integer,          intent(in)  :: n_states_diag ! nb of states used to get n_states
  integer,          intent(in)  :: supp_data_int_size
  integer,          intent(in)  :: supp_data_dbl_size
  character(len=*), intent(in)  :: kernel
  double precision, intent(in)  :: lambda, eF
  double precision, intent(in)  :: e(nOrb)
  double precision, intent(in)  :: ERI(nOrb,nOrb,nOrb,nOrb)
  integer,          intent(in)  :: supp_data_int(supp_data_int_size)
  double precision, intent(in)  :: supp_data_dbl(supp_data_dbl_size)
  double precision, intent(out) :: Om(n_states)
  double precision, intent(out) :: R(nOO+nVV,n_states_diag)
  
  integer                       :: N, M, num_threads
  integer                       :: iter, itermax, itertot
  integer                       :: shift1, shift2
  integer                       :: i, j, k, l, ab
  integer                       :: p, q, mm, i_data, nS
  logical                       :: converged
  character(len=6+41*n_states)  :: write_buffer
  double precision              :: r1, r2, dtwo_pi
  double precision              :: lambda_tmp
  double precision              :: mem
  double precision              :: eta
  double precision              :: t1, t2, tt1, tt2
  character(len=len(kernel))    :: kernel_name
  integer,          allocatable :: i_omax(:)
  double precision, allocatable :: H_diag(:)
  double precision, allocatable :: W(:,:)
  double precision, allocatable :: U(:,:)
  double precision, allocatable :: h(:,:), h_vec(:,:), h_val(:)
  double precision, allocatable :: residual_norm(:)
  double precision, allocatable :: overlap(:)
  double precision, allocatable :: S_check(:,:)
  double precision, allocatable :: rho_tmp(:,:,:), Om_tmp(:)
  double precision, allocatable :: to_print(:,:)
                                
  double precision, external    :: u_dot_u

  call wall_time(t1)

  dtwo_pi = 6.283185307179586d0

  N = nOO + nVV
  itermax = 8
  M = n_states_diag * itermax

  call lower_case(trim(kernel), kernel_name)

  if(M .ge. N) then
    print*, 'N = ', N
    print*, 'M = ', M
    print*, ' use Lapack or decrease n_states and/or itermax '
    stop
  endif

  write(6,'(A)') ''
  write(6,'(A)') 'Davidson Diagonalization'
  write(6,'(A)') '------------------------'
  write(6,'(A)') ''

  write(*,'(A40, I12)') 'Number of states = ', n_states
  write(*,'(A40, I12)') 'Number of states in diagonalization = ', n_states_diag
  write(*,'(A40, I12)') 'Number of basis functions = ', N
  write(*,'(A40, A12)') 'Kernel: ', kernel_name


  allocate(i_omax(n_states))
  allocate(to_print(2,n_states))
  allocate(H_diag(N))
  allocate(U(N,M))
  allocate(W(N,M))
  allocate(h(M,M), h_vec(M,M), h_val(M))
  allocate(overlap(n_states_diag))
  allocate(residual_norm(n_states_diag))

  mem = 8.d0 * dble(nOrb + nOrb**4 + N*n_states) &
      + 8.d0 * dble(2*supp_data_dbl_size) + 4.d0 * dble(2*supp_data_int_size)

  write(*,'(A40, F12.4)') 'I/O mem (GB) = ', mem / (1024.d0*1024.d0*1024.d0)

  mem = 8.d0 * dble(N + N*M + N*M + M*M + M*M + M + n_states_diag + n_states_diag)

  write(*,'(A40, F12.4)') 'tmp mem (GB) = ', mem / (1024.d0*1024.d0*1024.d0)

  num_threads = omp_get_max_threads()
  write(*,'(A40, I12)') 'Number of threads = ', num_threads


  if(kernel_name .eq. "rpa") then

    call ppLR_RPA_H_diag(ispin, nOrb, nC, nO, nR, nOO, nVV, lambda, e(1), eF, &
                         ERI(1,1,1,1), H_diag(1))

    ! to avoid compiler warnings
    allocate(rho_tmp(0,0,0))
    allocate(Om_tmp(0))

  elseif(kernel_name .eq. "gw") then

    nS = supp_data_int(1)

    allocate(rho_tmp(nS,nOrb,nOrb))
    allocate(Om_tmp(nS))

    eta = supp_data_dbl(1)
    i_data = 1
    do q = 1, nOrb
      do p = 1, nOrb
        do mm = 1, nS
          i_data = i_data + 1
          rho_tmp(mm,p,q) = supp_data_dbl(i_data)
        enddo
      enddo
    enddo
    do mm = 1, nS
      i_data = i_data + 1
      Om_tmp(mm) = supp_data_dbl(i_data)
    enddo

    call ppLR_GW_H_diag(ispin, nOrb, nC, nO, nR, nOO, nVV, nS, lambda, e(1), eF, &
                        ERI(1,1,1,1), eta, rho_tmp(1,1,1), Om_tmp(1), H_diag(1))

  !! TODO
  !elseif(kernel_name .eq. "gf2") then

  else

    print*, ' kernel not supported', kernel
    stop

  endif

  !print*, "H_diag:"
  !do ab = 1, N
  !  print*, ab, H_diag(ab)
  !enddo

  ! TODO: improve guess
  ! initialize guess
  R = 0.d0
  do k = 1, n_states
    R(k,k) = 1.d0
  enddo
  do k = n_states+1, n_states_diag
    do i = 1, N
      call random_number(r1)
      call random_number(r2)
      r1 = dsqrt(-2.d0*dlog(r1))
      r2 = dtwo_pi*r2
      R(i,k) = r1*dcos(r2)
    enddo
    R(k,k) = R(k,k) + 10.d0
  enddo

  do k = 1, n_states_diag
    call normalize(R(1,k), N)
  enddo

  !print*, 'guess'
  !do k = 1, N
  !  write(*,'(100(F15.7,2X))') (R(k,i), i = 1, n_states_diag)
  !enddo

  ! working vectors
  do k = 1, n_states_diag
    do i = 1, N
      U(i,k) = R(i,k)
    enddo
  enddo

  !print*, 'working vectors'
  !do k = 1, N
  !  write(*,'(100(F15.7,2X))') (U(k,i), i = 1, n_states_diag)
  !enddo

  write(6,'(A)') ''
  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)
  write_buffer = 'Iter'
  do i = 1, n_states
    write_buffer = trim(write_buffer)//'       Energy         Residual '
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)
  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)


  W = 0.d0
  converged = .False.
  itertot = 0

  do while (.not.converged)

    itertot = itertot + 1
    if(itertot == itermax) then
      print*, 'exit before convergence !'
      print*, 'itertot == itermax', itertot
      exit
    endif

    do iter = 1, itermax-1

      shift1 = n_states_diag * (iter - 1)
      shift2 = shift1 + n_states_diag
      !print*, iter, shift1, shift2

      if((iter > 1) .or. (itertot == 1)) then

        !call wall_time(tt1)

        call ortho_qr(U(1,1), size(U, 1), N, shift2)
        !call ortho_qr(U(1,1), size(U, 1), N, shift2)

        !print*, 'working vectors after qr'
        !do k = 1, N
        !  write(*,'(100(F15.7,2X))') (U(k,i), i = 1, n_states_diag)
        !enddo
        !allocate(S_check(shift2,shift2))
        !call dgemm("T", "N", shift2, shift2, N, 1.d0,      &
        !           U(1,1), size(U, 1), U(1,1), size(U, 1), &
        !           0.d0, S_check(1,1), size(S_check, 1))
        !do k = 1, shift2
        !  write(*,'(100(F15.7,2X))') (S_check(k,i), i = 1, shift2)
        !enddo
        !deallocate(S_check)

        if(kernel_name .eq. "rpa") then
      
          call ppLR_RPA_HR_calc(ispin, nOrb, nC, nO, nR, nOO, nVV, lambda, e(1), eF, n_states_diag, &
                                ERI(1,1,1,1),                                                       &
                                U(1,shift1+1), W(1,shift1+1))
      
        elseif(kernel_name .eq. "gw") then
      
          call ppLR_GW_HR_calc(ispin, nOrb, nC, nO, nR, nOO, nVV, nS, lambda, e(1), eF, n_states_diag, &
                               ERI(1,1,1,1), eta, rho_tmp(1,1,1), Om_tmp(1),                           &
                               U(1,shift1+1), W(1,shift1+1))
      
        !! TODO
        !elseif(kernel_name .eq. "gf2") then
      
        endif

      else

        ! computed below
        continue
      endif

      ! h = U.T H U
      call dgemm('T', 'N', shift2, shift2, N, 1.d0,      &
                 U(1,1), size(U, 1), W(1,1), size(W, 1), &
                 0.d0, h(1,1), size(h, 1))

      ! h h_vec = h_val h_vec
      call diag_nonsym_right(shift2, h(1,1), size(h, 1), h_vec(1,1), size(h_vec, 1), h_val(1), size(h_val, 1))
      !print*, 'h_val', h_val(1:shift2)

      ! U1 = U0 h_vec
      call dgemm('N', 'N', N, n_states_diag, shift2, 1.d0,       &
                 U(1,1), size(U, 1), h_vec(1,1), size(h_vec, 1), &
                 0.d0, U(1,shift2+1), size(U, 1))

      do k = 1, n_states_diag
        call normalize(U(1,shift2+k), N)
      enddo

      !do l = 1, n_states
      !  do k = 1, n_states_diag
      !    overlap(k) = 0.d0
      !    do i = 1, N
      !      overlap(k) = overlap(k) + U(i,shift2+k) * R(i,l)
      !    enddo
      !    overlap(k) = dabs(overlap(k))
      !    !print *, ' overlap =', k, overlap(k)
      !  enddo
      !  lambda_tmp = 0.d0
      !  do k = 1, n_states_diag
      !    if(overlap(k) .gt. lambda_tmp) then
      !      i_omax(l) = k
      !      lambda_tmp = overlap(k)
      !    endif
      !  enddo
      !  if(lambda_tmp .lt. 0.7d0) then
      !    print *, ' small overlap ...', l, i_omax(l)
      !    print *, ' max overlap =', lambda_tmp
      !    !stop
      !  endif
      !  if(i_omax(l) .ne. l) then
      !    print *, ' !!! WARNING !!!'
      !    print *, ' index of state', l, i_omax(l)
      !  endif
      !enddo

      ! W1 = W0 h_vec
      call dgemm('N', 'N', N, n_states_diag, shift2, 1.d0,       &
                 W(1,1), size(W, 1), h_vec(1,1), size(h_vec, 1), &
                 0.d0, W(1,shift2+1), size(W, 1))

      !$OMP PARALLEL DEFAULT(NONE) &
      !$OMP          PRIVATE(i, k) &
      !$OMP          SHARED(n_states, n_states_diag, N, shift2, U, h_val, W, H_diag, residual_norm, to_print)
      !$OMP DO 
      do k = 1, n_states_diag
        do i = 1, N
          U(i,shift2+k) = (h_val(k) * U(i,shift2+k) - W(i,shift2+k)) / max(H_diag(i) - h_val(k), 1.d-2)
        enddo
        if(k <= n_states) then
          residual_norm(k) = u_dot_u(U(1,shift2+k), N)
          to_print(1,k) = h_val(k)
          to_print(2,k) = residual_norm(k)
        endif
      enddo
      !$OMP END DO
      !$OMP END PARALLEL

      if((itertot > 1) .and. (iter == 1)) then
        continue
      else
        write(*,'(1X, I3, 1X, 10000(1X, F16.10, 1X, F12.6))') iter-1, to_print(1:2,1:n_states)
      endif

      !call wall_time(tt2)
      !write(*,'(A50, F12.4)') 'wall time for one Davidson iteration (sec): ', tt2-tt1
      !stop

      !print*, 'iter = ', iter
      if(iter > 1) then
        converged = dabs(maxval(residual_norm(1:n_states))) < 1d-15
      endif

      do k = 1, n_states
        if(residual_norm(k) > 1.d10) then
          print *, 'Davidson failed'
          stop -1
        endif
      enddo

      if(converged) exit

    enddo ! loop over iter


    ! Re-contract U and update W
    ! --------------------------------

    call dgemm('N', 'N', N, n_states_diag, shift2, 1.d0,       &
               W(1,1), size(W, 1), h_vec(1,1), size(h_vec, 1), &
               0.d0, R(1,1), size(R, 1))

    do k = 1, n_states_diag
      do i = 1, N
        W(i,k) = R(i,k)
      enddo
    enddo

    call dgemm('N', 'N', N, n_states_diag, shift2, 1.d0,       &
               U(1,1), size(U, 1), h_vec(1,1), size(h_vec, 1), &
               0.d0, R(1,1), size(R, 1))

    do k = 1, n_states_diag
      do i = 1, N
        U(i,k) = R(i,k)
      enddo
    enddo

    call ortho_qr(U(1,1), size(U, 1), N, n_states_diag)
    !call ortho_qr(U(1,1), size(U, 1), N, n_states_diag)

    do j = 1, n_states_diag
      k = 1
      do while((k < N) .and. (U(k,j) == 0.d0))
        k = k+1
      enddo
      if(U(k,j) * R(k,j) < 0.d0) then
        do i = 1, N
          W(i,j) = -W(i,j)
        enddo
      endif
    enddo

  enddo ! loop over while

  ! ---

  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') trim(write_buffer)
  write(6,'(A)') ''


  print*, " Davidson eigenvalues"
  do k = 1, n_states
    Om(k) = h_val(k)
    print*, k, Om(k)
  enddo

  deallocate(i_omax)
  deallocate(to_print)
  deallocate(H_diag)
  deallocate(U)
  deallocate(W)
  deallocate(h)
  deallocate(h_vec)
  deallocate(h_val)
  deallocate(overlap)
  deallocate(residual_norm)

  if(kernel_name .eq. "gw") then
    deallocate(rho_tmp)
    deallocate(Om_tmp)
  endif

  call wall_time(t2)
  write(*,'(A50, F12.4)') 'total wall time for Davidson (sec): ', t2-t1

  return
end

! ---

subroutine ppLR_davidson_2(ispin, TDA, nC, nO, nR, nOrb, nOO, nVV, lambda, e, eF, ERI, &
                           supp_data_int, supp_data_int_size,                          &
                           supp_data_dbl, supp_data_dbl_size,                          &
                           Om, R, n_states, n_states_diag, kernel)

  use omp_lib

  implicit none

  logical,          intent(in)  :: TDA
  integer,          intent(in)  :: ispin
  integer,          intent(in)  :: nC, nO, nR, nOrb, nOO, nVV
  integer,          intent(in)  :: n_states      ! nb of physical states
  integer,          intent(in)  :: n_states_diag ! nb of states used to get n_states
  integer,          intent(in)  :: supp_data_int_size
  integer,          intent(in)  :: supp_data_dbl_size
  character(len=*), intent(in)  :: kernel
  double precision, intent(in)  :: lambda, eF
  double precision, intent(in)  :: e(nOrb)
  double precision, intent(in)  :: ERI(nOrb,nOrb,nOrb,nOrb)
  integer,          intent(in)  :: supp_data_int(supp_data_int_size)
  double precision, intent(in)  :: supp_data_dbl(supp_data_dbl_size)
  double precision, intent(out) :: Om(n_states)
  double precision, intent(out) :: R(nOO+nVV,n_states_diag)
  
  integer                       :: N, M, num_threads, n_states_delta
  integer                       :: it_start, it_delta, it_size
  integer                       :: iter, itermax, itertot
  integer                       :: i, j, k, l, ab
  integer                       :: p, q, mm, i_data, nS
  logical                       :: converged
  double precision              :: r1, r2, dtwo_pi
  double precision              :: mem
  double precision              :: eta
  double precision              :: t1, t2, tt1, tt2
  character(len=len(kernel))    :: kernel_name
  integer,          allocatable :: i_omax(:)
  character(len=:), allocatable :: write_buffer
  double precision, allocatable :: to_print(:,:)
  double precision, allocatable :: H_diag(:)
  double precision, allocatable :: W0(:,:), W1(:,:)
  double precision, allocatable :: U0(:,:), U1(:,:)
  double precision, allocatable :: h(:,:), h_vec(:,:), h_val(:)
  double precision, allocatable :: residual_norm(:)
  double precision, allocatable :: rho_tmp(:,:,:), Om_tmp(:)
                                
  double precision, external    :: u_dot_u

  call wall_time(t1)

  dtwo_pi = 6.283185307179586d0

  N = nOO + nVV

  n_states_delta = min(max(25, n_states_diag/2), n_states_diag)
  itermax = 8
  M = n_states_diag + itermax * n_states_delta

  call lower_case(trim(kernel), kernel_name)

  if(M .ge. N) then
    print*, 'N = ', N
    print*, 'M = ', M
    print*, ' use Lapack or decrease n_states and/or itermax '
    stop
  endif

  write(6,'(A)') ''
  write(6,'(A)') 'Davidson Diagonalization'
  write(6,'(A)') '------------------------'
  write(6,'(A)') ''

  write(*,'(A40, I12)') 'Number of states = ', n_states
  write(*,'(A40, I12)') 'Number of states in diag = ', n_states_diag
  write(*,'(A40, I12)') 'Number of states to add = ', n_states_delta
  write(*,'(A40, I12)') 'Number of basis functions = ', N
  write(*,'(A40, A12)') 'Kernel: ', kernel_name



  allocate(character(len=50*n_states) :: write_buffer)
  allocate(i_omax(n_states))
  allocate(to_print(2,n_states))
  allocate(H_diag(N))
  allocate(U0(N,M), U1(N,n_states_diag))
  allocate(W0(N,M), W1(N,n_states_diag))
  allocate(h(M,M), h_vec(M,M), h_val(M))
  allocate(residual_norm(n_states_diag))

  mem = 8.d0 * dble(nOrb) + 8.d0 * dble(nOrb)**4 + 8.d0 * dble(N*n_states) &
      + 8.d0 * dble(2*supp_data_dbl_size) + 4.d0 * dble(2*supp_data_int_size)

  write(*,'(A40, F12.4)') 'I/O mem (GB) = ', mem / (1024.d0*1024.d0*1024.d0)

  mem = 8.d0 * dble(N)               &
      + 8.d0 * dble(N*M)             &
      + 8.d0 * dble(N*M)             &
      + 8.d0 * dble(N*n_states_diag) &
      + 8.d0 * dble(N*n_states_diag) &
      + 8.d0 * dble(M*M)             &
      + 8.d0 * dble(M*M)             &
      + 8.d0 * dble(M)               &
      + 8.d0 * dble(n_states_diag)   &
      + 1.d0 * dble(50*n_states)

  write(*,'(A40, F12.4)') 'tmp mem (GB) = ', mem / (1024.d0*1024.d0*1024.d0)

  num_threads = omp_get_max_threads()
  write(*,'(A40, I12)') 'Number of threads = ', num_threads


  if(kernel_name .eq. "rpa") then

    allocate(rho_tmp(0,0,0))
    allocate(Om_tmp(0))

    call ppLR_RPA_H_diag(ispin, nOrb, nC, nO, nR, nOO, nVV, lambda, e(1), eF, &
                         ERI(1,1,1,1), H_diag(1))

  elseif(kernel_name .eq. "gw") then

    nS = supp_data_int(1)

    allocate(rho_tmp(nS,nOrb,nOrb))
    allocate(Om_tmp(nS))

    eta = supp_data_dbl(1)
    i_data = 1
    do q = 1, nOrb
      do p = 1, nOrb
        do mm = 1, nS
          i_data = i_data + 1
          rho_tmp(mm,p,q) = supp_data_dbl(i_data)
        enddo
      enddo
    enddo
    do mm = 1, nS
      i_data = i_data + 1
      Om_tmp(mm) = supp_data_dbl(i_data)
    enddo

    call ppLR_GW_H_diag(ispin, nOrb, nC, nO, nR, nOO, nVV, nS, lambda, e(1), eF, &
                        ERI(1,1,1,1), eta, rho_tmp(1,1,1), Om_tmp(1), H_diag(1))

  !! TODO
  !elseif(kernel_name .eq. "gf2") then

  else

    print*, ' kernel not supported', kernel
    stop

  endif

  U0 = 0.d0
  W0 = 0.d0
  U1 = 0.d0
  W1 = 0.d0

  ! TODO: improve guess
  ! initialize guess
  R = 0.d0
  do k = 1, n_states
    R(k,k) = 1.d0
  enddo
  do k = n_states+1, n_states_diag
    do i = 1, N
      call random_number(r1)
      call random_number(r2)
      r1 = dsqrt(-2.d0*dlog(r1))
      r2 = dtwo_pi*r2
      R(i,k) = r1*dcos(r2)
    enddo
    R(k,k) = R(k,k) + 10.d0
    call normalize(R(1,k), N)
  enddo

  do k = 1, n_states_diag
    U0(:,k) = R(:,k)
  enddo


  write(6,'(A)') ''
  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)
  write_buffer = 'Iter'
  do i = 1, n_states
    write_buffer = trim(write_buffer)//'       Energy         Residual '
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)
  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') write_buffer(1:6+41*n_states)


  converged = .False.
  itertot = 0

  do while (.not.converged)

    itertot = itertot + 1
    if(itertot == itermax) then
      print*, 'exit before convergence !'
      print*, 'itertot == itermax', itertot
      exit
    endif

    do iter = 1, itermax-1

      if(iter .eq. 1) then
        it_start = 0
        it_delta = n_states_diag
      else
        it_start = n_states_diag + n_states_delta * (iter - 2)
        it_delta = n_states_delta
      endif

      it_size = it_start + it_delta

      if((iter > 1) .or. (itertot == 1)) then

        !call wall_time(tt1)

        call ortho_qr(U0(1,1), size(U0, 1), N, it_size)

        if(kernel_name .eq. "rpa") then
      
          call ppLR_RPA_HR_calc(ispin, nOrb, nC, nO, nR, nOO, nVV, lambda, e(1), eF, it_delta, &
                                ERI(1,1,1,1),                                                  &
                                U0(1,it_start+1), W0(1,it_start+1))
      
        elseif(kernel_name .eq. "gw") then
      
          call ppLR_GW_HR_calc(ispin, nOrb, nC, nO, nR, nOO, nVV, nS, lambda, e(1), eF, it_delta, &
                               ERI(1,1,1,1), eta, rho_tmp(1,1,1), Om_tmp(1),                      &
                               U0(1,it_start+1), W0(1,it_start+1))
      
        !! TODO
        !elseif(kernel_name .eq. "gf2") then
      
        endif

      else

        ! computed below
        continue
      endif

      ! h = U0.T H U0
      call dgemm('T', 'N', it_size, it_size, N, 1.d0,        &
                 U0(1,1), size(U0, 1), W0(1,1), size(W0, 1), &
                 0.d0, h(1,1), size(h, 1))

      ! h h_vec = h_val h_vec
      call diag_nonsym_right(it_size, h(1,1), size(h, 1), h_vec(1,1), size(h_vec, 1), h_val(1), size(h_val, 1))

      ! U1(:,1:it_delta) = U0 h_vec(:,1:it_delta)
      call dgemm('N', 'N', N, it_delta, it_size, 1.d0,             &
                 U0(1,1), size(U0, 1), h_vec(1,1), size(h_vec, 1), &
                 0.d0, U1(1,1), size(U1, 1))

      do k = 1, it_delta
        call normalize(U1(1,k), N)
      enddo

      ! W1(:,1:it_delta) = W0 h_vec(:,1:it_delta)
      call dgemm('N', 'N', N, it_delta, it_size, 1.d0,             &
                 W0(1,1), size(W0, 1), h_vec(1,1), size(h_vec, 1), &
                 0.d0, W1(1,1), size(W1, 1))

      !$OMP PARALLEL      &
      !$OMP DEFAULT(NONE) &
      !$OMP PRIVATE(i, k) &
      !$OMP SHARED(n_states, it_size, it_delta, N, U0, U1, &
      !$OMP        h_val, W1, H_diag, residual_norm, to_print)
      !$OMP DO 
      do k = 1, it_delta
        do i = 1, N
          U1(i,k) = (h_val(k) * U1(i,k) - W1(i,k)) / max(dabs(H_diag(i) - h_val(k)), 1.d-2)
          U0(i,it_size+k) = U1(i,k)
        enddo
        if(k <= n_states) then
          residual_norm(k) = u_dot_u(U1(1,k), N)
          to_print(1,k) = h_val(k)
          to_print(2,k) = residual_norm(k)
        endif
      enddo
      !$OMP END DO
      !$OMP END PARALLEL


      if((itertot > 1) .and. (iter == 1)) then
        continue
      else
        write(*,'(1X, I3, 1X, 10000(1X, F16.10, 1X, F12.6))') iter-1, to_print(1:2,1:n_states)
      endif

      !call wall_time(tt2)
      !write(*,'(A50, F12.4)') 'wall time for one Davidson iteration (sec): ', tt2-tt1
      !stop

      if(iter > 1) then
        converged = dabs(maxval(residual_norm(1:n_states))) < 1d-15
      endif

      do k = 1, n_states
        if(residual_norm(k) > 1.d10) then
          print *, 'Davidson failed'
          stop -1
        endif
      enddo

      if(converged) exit

    enddo ! loop over iter


    ! Re-contract U0 and update W0
    ! --------------------------------

    call dgemm('N', 'N', N, n_states_diag, it_size, 1.d0,        &
               W0(1,1), size(W0, 1), h_vec(1,1), size(h_vec, 1), &
               0.d0, R(1,1), size(R, 1))

    do k = 1, n_states_diag
      do i = 1, N
        W0(i,k) = R(i,k)
      enddo
    enddo

    call dgemm('N', 'N', N, n_states_diag, it_size, 1.d0,        &
               U0(1,1), size(U0, 1), h_vec(1,1), size(h_vec, 1), &
               0.d0, R(1,1), size(R, 1))

    do k = 1, n_states_diag
      do i = 1, N
        U0(i,k) = R(i,k)
      enddo
    enddo

    call ortho_qr(U0(1,1), size(U0, 1), N, n_states_diag)

    do j = 1, n_states_diag
      k = 1
      do while((k < N) .and. (U0(k,j) == 0.d0))
        k = k+1
      enddo
      if(U0(k,j) * R(k,j) < 0.d0) then
        do i = 1, N
          W0(i,j) = -W0(i,j)
        enddo
      endif
    enddo

  enddo ! loop over while

  ! ---

  write_buffer = '====='
  do i = 1, n_states
    write_buffer = trim(write_buffer)//' ================  ==========='
  enddo
  write(6,'(A)') trim(write_buffer)
  write(6,'(A)') ''


  print*, " Davidson eigenvalues"
  do k = 1, n_states
    Om(k) = h_val(k)
    print*, k, Om(k)
  enddo

  deallocate(write_buffer)
  deallocate(i_omax)
  deallocate(to_print)
  deallocate(H_diag)
  deallocate(U0, U1)
  deallocate(W0, W1)
  deallocate(h)
  deallocate(h_vec)
  deallocate(h_val)
  deallocate(residual_norm)

  if(kernel_name .eq. "gw") then
    deallocate(rho_tmp)
    deallocate(Om_tmp)
  endif

  call wall_time(t2)
  write(*,'(A50, F12.4)') 'total wall time for Davidson (sec): ', t2-t1

  return
end

! ---

