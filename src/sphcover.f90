
! Copyright (C) 2002-2005 J. K. Dewhurst, S. Sharma and C. Ambrosch-Draxl.
! This file is distributed under the terms of the GNU Lesser General Public
! License. See the file COPYING for license details.

!BOP
! !ROUTINE: sphcover
! !INTERFACE:
subroutine sphcover(ntp,tp)
! !INPUT/OUTPUT PARAMETERS:
!   ntp : number of required points (in,integer)
!   tp  : (theta, phi) coordinates (out,real(2,ntp))
! !DESCRIPTION:
!   Produces a set of $(\theta,\phi)$ points which cover the sphere nearly
!   optimally and have no point group symmetries. The set is generated by
!   successively adding points, each of which maximises the minimum distance
!   between it and the existing points. This ensures that any subset consisting
!   of the first $m$ points from the original set is also optimal.
!
! !REVISION HISTORY:
!   Created May 2003 (JKD)
!   Testing and improvement, April 2007 (F. Cricchio)
!EOP
!BOC
implicit none
! arguments
integer, intent(in) :: ntp
real(8), intent(out) :: tp(2,ntp)
! local variables
integer, parameter :: nth=151 ! number of polar divisions
integer, parameter :: nph=307 ! number of azimuthal divisions
integer ith,iph,i,n
real(8), parameter :: pi=3.1415926535897932385d0
real(8), parameter :: twopi=6.2831853071795864769d0
real(8) dmxmn,dmn,d,th,ph,v(3),vm(3),r
! allocatable arrays
real(8), allocatable :: va(:,:)
if (ntp.le.0) then
  write(*,*)
  write(*,'("Error(sphcover): ntp <= 0 : ",I8)') ntp
  write(*,*)
  stop
end if
if (ntp.gt.nth*nph) then
  write(*,*)
  write(*,'("Error(sphcover): ntp out of range : ",I8)') ntp
  write(*,*)
  stop
end if
allocate(va(3,ntp))
n=0
10 continue
dmxmn=0.d0
do ith=0,nth
  th=pi*dble(ith)/dble(nth)
  do iph=0,nph-1
    ph=twopi*dble(iph)/dble(nph)
    v(1)=sin(th)*cos(ph)
    v(2)=sin(th)*sin(ph)
    v(3)=cos(th)
! find the minimum distance
    dmn=1.d8
    do i=1,n
      d=(va(1,i)-v(1))**2+(va(2,i)-v(2))**2+(va(3,i)-v(3))**2
      if (d.lt.dmn) dmn=d
    end do
    if (dmn.gt.dmxmn+1.d-8) then
      dmxmn=dmn
      vm(:)=v(:)
    end if
  end do
end do
n=n+1
va(:,n)=vm(:)
! compute the spherical coordinates of the vector
call sphcrd(vm,r,tp(1,n))
if (n.lt.ntp) goto 10



do n=1,ntp
write(700,*) n,va(:,n)
write(701,*) n,tp(:,n)
end do

do ith=0,nth
  th=pi*dble(ith)/dble(nth)
  do iph=0,nph-1
    ph=twopi*dble(iph)/dble(nph)
    v(1)=sin(th)*cos(ph)
    v(2)=sin(th)*sin(ph)
    v(3)=cos(th)
    write(800,*) v
  end do
end do



deallocate(va)
return
end subroutine
!EOC
