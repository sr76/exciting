!
subroutine dielmat
    
    use modmain
    use modinput
    use modmpi
    use modxs, only: symt2
    implicit none
! local variables
    integer :: l, a, b, ncomp, epscomp(2,9)
    integer :: ik, jk, isym
    integer :: ist, jst, iw
    integer :: recl, iostat
    logical :: exist, intraband
    real(8) :: wplas, swidth, eta0, eta1, eji, t1
    real(8) :: v1 (3), v2 (3), sc(3,3)
    complex(8) :: zt1, zt2
    character(256) :: fname
! allocatable arrays
    real(8), allocatable :: w(:)
    real(8), allocatable :: evalsvt(:), occsvt(:)
    complex (8), allocatable :: pmat(:,:,:)
    complex (8), allocatable :: sigma(:)
    complex (8), allocatable :: eta(:)
    integer :: wgrid
    real(8) :: wmax, scissor
    integer :: COMM_LEVEL2
    integer :: kpari, kparf
! external functions
    real(8) sdelta

! initialise universal variables
    call init0
    call init1

! read Fermi energy from file
    call readfermi

! working arrays
    wgrid = input%properties%dielmat%wgrid
    allocate(w(wgrid))
    allocate(sigma(wgrid))

! generate energy grid
    wmax = input%properties%dielmat%wmax
    t1 = wmax/dble(wgrid)
    Do iw = 1, wgrid
        w(iw) = t1*dble(iw-1)
    End Do

! input%properties%dielmat%scissor   
    scissor = input%properties%dielmat%scissor

! smearing factor
    swidth = input%properties%dielmat%swidth

! finite lifetime broadening to mimic the experimental resolution
    allocate(eta(wgrid))
    eta0 = 0.3/h2ev
    eta1 = 0.03/h2ev
    do iw = 1, wgrid
        eta(iw) = cmplx(0.d0,eta0+eta1*w(iw))
    end do

! check for presence of the calculated momentum matrix elements
    inquire(file='PMAT.OUT', exist=exist)
    if (exist) then
        if (rank==0) then
            write(*,*)
            write(*,'("WARNING(dielmat): The momentum matrix elements are read from PMAT.OUT")')
            write(*,*)
        end if
    else
        if (rank==0) then
            write(*,*)
            write(*,'("WARNING(dielmat): Calculate the momentum matrix elements")')
            write(*,*)
        end if
        if (.not.associated(input%properties%momentummatrix)) &
       &  input%properties%momentummatrix => getstructmomentummatrix(emptynode)
        call writepmat
    end if

! the momentum matrix elements
    allocate(pmat(3,nstsv,nstsv))
    inquire(iolength=recl) pmat
    deallocate(pmat)
    open(50,File='PMAT.OUT',Action='READ',Form='UNFORMATTED', &
   &  Access='DIRECT',Recl=recl,IOstat=iostat)

    kpari = firstofset(rank,nkptnr)
    kparf = lastofset(rank,nkptnr)

#ifdef MPI
    ! create communicator object
    call MPI_COMM_SPLIT(MPI_COMM_WORLD,kpari,rank/nkptnr,COMM_LEVEL2,ierr)
#endif

!-------------------------------------------------------------------------------
!   Loop over optical components
!-------------------------------------------------------------------------------

    ncomp = size(input%properties%dielmat%epscomp,2)
    if (ncomp>0) then
        do l = 1, ncomp
            epscomp(1,l) = input%properties%dielmat%epscomp(1,l)
            epscomp(2,l) = input%properties%dielmat%epscomp(2,l)
        end do
    else
!
! calculate \eps_{ij}} for all symmetry inequivalent components,
! by analysing the symmetrization matrices
! 
        ncomp = 0
        do a = 1, 3
            do b = 1, 3
                write(*,*) a, b, sum(abs(symt2(a,b,:,:)))
                if (sum(abs(symt2(a,b,:,:)))>1.0d-8) then
                    ncomp = ncomp+1
                    epscomp(1,ncomp) = a
                    epscomp(2,ncomp) = b
                end if
            end do
        end do
    end if

    do l = 1, ncomp
        
        a = epscomp(1,l)
        b = epscomp(2,l)
        
        ! intraband contribution (for metallic cases)
        intraband = (input%properties%dielmat%intraband .and. (a==b))

        sigma(:) = zzero
        wplas = 0.0d0

! sum over non-reduced k-points
        do ik = kpari, kparf

! equivalent reduced k-point
            call findkpt(vklnr(:,ik),isym,jk)
        
! read momentum matrix elements from direct-access file
            allocate(pmat(3,nstsv,nstsv))
            read(50,Rec=jk) pmat

! rotate the matrix elements from the reduced to non-reduced k-point
            if (isym > 1) then
                do ist = 1, nstsv
                    do jst = 1, nstsv
                        sc(:,:)=symlatc(:,:,lsplsymc(isym))
                        call r3mv(sc,dble(pmat(:,ist,jst)),v1)
                        call r3mv(sc,aimag(pmat(:,ist,jst)),v2)
                        pmat(:,ist,jst) = cmplx(v1(:),v2(:),8)
                    end do
                end do
            end if
        
! read eigenvalues and occupancies from files
            allocate(evalsvt(nstsv),occsvt(nstsv))
            call getevalsv(vkl(:,jk),evalsvt)
            call getoccsv(vkl(:,jk),occsvt)

!--------------------------
! PLASMA FREQUENCY
!--------------------------
            if (intraband) then
                do ist = 1, nstsv
                    zt1 = occsvt(ist)*pmat(a,ist,ist)*conjg(pmat(b,ist,ist))
                    t1 = (evalsvt(ist)-efermi)/swidth
                    wplas = wplas+dble(zt1)*sdelta(0,t1)/swidth
                end do
            end if

!--------------------------
! INTERBAND CONTRIBUTION
!--------------------------       
            do ist = 1, nstsv
            if (evalsvt(ist)<=efermi) then
            
                do jst = 1, nstsv
                if (evalsvt(jst)>efermi) then
            
                    zt1 = pmat(a,ist,jst)*conjg(pmat(b,ist,jst))
                    eji = evalsvt(jst)-evalsvt(ist)
                
                    ! scissor operator
                    if (dabs(scissor)>1.0d-8) then
                        if (dabs(eji)>1.0d-8) then
                            t1 = (eji+scissor)/eji
                            zt1 = zt1*t1*t1
                            eji = eji+scissor
                        end if
                    end if
                
                    if (dabs(eji)>1.0d-8) then
                        t1=occsvt(ist)*(1.0d0-occsvt(jst)/occmax)/eji
                        do iw = 1, wgrid
                            sigma(iw) = sigma(iw)+ &
                           &  t1*(zt1/(w(iw)-eji+eta(iw)) + &
                           &  conjg(zt1)/(w(iw)+eji+eta(iw)))
                        end do ! iw
                    end if

                end if
                end do ! jst
        
            end if
            end do ! ist
            
            deallocate(pmat)
            deallocate(evalsvt,occsvt)
            
        end do ! ik

#ifdef MPI
    call MPI_ALLREDUCE(MPI_IN_PLACE, sigma, wgrid, &
    &   MPI_DOUBLE_COMPLEX, MPI_SUM, MPI_COMM_WORLD, ierr)
    call MPI_ALLREDUCE(MPI_IN_PLACE, wplas, 1, &
    &   MPI_DOUBLE_COMPLEX, MPI_SUM, MPI_COMM_WORLD, ierr)
#endif

        zt1 = zi/(omega*dble(nkptnr))
        sigma(:) = zt1*sigma(:)

        call barrier    

        if (intraband) then
            zt1 = fourpi/(omega*dble(nkptnr))
            wplas = zt1*dabs(wplas)
! write the plasma frequency to file
            if (rank==0) then
                write(fname, '("PLASMA_", 2I1, ".OUT")') a, b
                write(*, '("  Plasma frequency written to ", a)') trim(adjustl(fname))
                open(60, File=trim(fname), Action='WRITE', Form='FORMATTED')
                write(60, '(G18.10, " : plasma frequency")') sqrt(wplas)
                close(60)
            end if
! add the intraband term (Drude-like)
            zt1 = zi/fourpi
            do iw = 1, wgrid
                sigma(iw) = sigma(iw)+zt1*wplas/(w(iw)+zi*swidth)
            end do
        end if
     
        if (rank==0) then
! write the optical conductivity
            write(fname, '("SIGMA_", 2I1, ".OUT")') a, b
            write(*, '("  The optical conductivity tensor written to ", a)') trim(adjustl(fname))
            open(60, file=trim(fname), action='WRITE', form='FORMATTED')
            do iw = 1, wgrid
                write(60, '(2G18.10)') w(iw), dble(sigma(iw))
            end do
            write(60, '("     ")')
            do iw = 1, wgrid
                write(60, '(2G18.10)') w(iw), aimag(sigma(iw))
            end do
            close(60)
! write the dielectric function to file
            write(fname, '("EPSILON_", 2I1, ".OUT")') a, b
            write(*, '("  The total dielectric tensor written to ", a)') trim(adjustl(fname))
            open(60, file=trim(fname), action='WRITE', form='FORMATTED')
            zt1 = zi*fourpi
            t1 = 0.0d0; if (a==b) t1 = 1.0d0
            do iw = 1, wgrid
                zt2 = t1+zt1*sigma(iw)/(w(iw)+eta(iw))
                write(60, '(2G18.10)') w(iw), dble(zt2)
            end do
            write(60, '("     ")')
            do iw = 1, wgrid
                zt2 = zt1*sigma(iw)/(w(iw)+eta(iw))
                write(60, '(2G18.10)') w(iw), aimag(zt2)
            end do
            close(60)
            write(*,*)        
        end if
    
    end do ! optical components
     
    deallocate(w,sigma)
    
end subroutine