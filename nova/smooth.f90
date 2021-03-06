!------------------------------------------------------------------------------
!==============================================================================
!------------------------------------------------------------------------------
! These subroutines smooth the model
!
! The arguments are
! - s_length     : in    : smoothing length
! - model_smooth : in    : name of file to print smoothed data to

! Generic smoothing; calls the appropriate smoother

subroutine smooth_model(s_type, s_length, outfile)

   use init_1d_variables
   use init_1d_grids
   use bl_types
   use bl_error_module

   implicit none

   !===========================================================================
   ! Declare variables

   ! Arguments ................................................................
   integer,                      intent(in   ) :: s_type
   real(kind=dp_t),              intent(in   ) :: s_length
   character(len=256),           intent(in   ) :: outfile
   
   ! Temporaries ..............................................................
   integer :: i, j ! loop index

   !===========================================================================
   ! Call the appropriate smoothing routine

   select case(s_type)
   case(SMOOTH_KRNL)
      call smooth_model_krnl(s_length)
   case(SMOOTH_TNH0)
      call smooth_model_tnh0(s_length)
   case default
      if (s_type == SMOOTH_TANH .or. s_type == SMOOTH_TNH2 &
          .or. s_type == SMOOTH_GSSN .or. s_type == SMOOTH_EXPN) then
         call smooth_model_below(s_type, s_length)
      else if (s_type /= SMOOTH_NONE) then
         call bl_error("ERROR: invalid smoothing method chosen.")
      end if
   end select

   !===========================================================================
   ! Print

   open(99, file=outfile)
   write(99,*) "# initial model just after smoothing across uniform grid"
   do i = 1, NrU
      write(99,'(1x,30(g17.10,1x))') Uradius(i), (Ustate(i,j), j = 1, Nvars)
   end do
   close(unit=99)

end subroutine smooth_model

!------------------------------------------------------------------------------
!==============================================================================
!------------------------------------------------------------------------------
! Delete the transition region across the H1 base and replace it with a tanh

subroutine smooth_model_tnh0(s_length)

   use init_1d_variables
   use init_1d_grids
   use bl_types
   use bl_constants_module

   implicit none

   !===========================================================================
   ! Declare variables

   ! Arguments ................................................................
   real(kind=dp_t),              intent(in   ) :: s_length

   ! Local ....................................................................
   real(kind=dp_t), allocatable :: smoothed(:,:)

   ! Temporaries ..............................................................
   integer :: i, n            ! loop indices
   integer :: j               ! cut point
   real(kind=dp_t) :: shift   ! drop the upper region before re-adding tanh
   real(kind=dp_t) :: x, y    ! for computing tanh profile
   
   !===========================================================================
   ! Allocate
   allocate(smoothed(NrU, Nvars))

   !===========================================================================
   ! Smooth model

   do n = 1, Nvars   ! loop over variables

      ! Only smooth composition, temperature, and entropy; the HSE integration
      ! will correct the density and pressure
      if ((n == idens) .or. (n == ipres)) cycle

      do i = 1, NrU
         ! must go from low x to high x or 'if' statements must be restructured

         if (Uradius(i) < Uradius(ibase) - HALF*s_length) then
            ! if well below the transition, copy the input data
            smoothed(i,n) = Ustate(i,n)
            j = i  ! mark last point in this segment
            shift = Ustate(ibase,n) - Ustate(j,n)
         else if (Uradius(i) < Uradius(ibase)) then
            ! if near the transition, erase and impose a flat line
            smoothed(i,n) = Ustate(j,n)
         else
            ! if above the transition, lower to erase transition
            smoothed(i,n) = Ustate(i,n) - shift
         end if

      enddo

      ! Need to split these loops to avoid cross-talk
      do i = 1, NrU

         ! Add in tanh to replace the (previously-removed) sharp transition
         ! with a smooth transition
         x = (Uradius(i) - Uradius(ibase)) / s_length
         y = shift * HALF * (ONE + tanh(x))
         Ustate(i,n) = smoothed(i,n) + y

      enddo
   enddo

   !===========================================================================
   ! De-allocate
   deallocate(smoothed)

end subroutine smooth_model_tnh0

!------------------------------------------------------------------------------
!==============================================================================
!------------------------------------------------------------------------------
! Gaussian kernel smoothing over the entire model

subroutine smooth_model_krnl(s_length)

   use init_1d_variables
   use init_1d_grids
   use bl_types
   use bl_constants_module

   implicit none

   !===========================================================================
   ! Declare variables

   ! Arguments ................................................................
   real(kind=dp_t),              intent(in   ) :: s_length

   ! Local ....................................................................
   real(kind=dp_t), allocatable :: smoothed(:,:)

   ! Temporaries ..............................................................
   integer :: i, j, n               ! loop indices
   real(kind=dp_t) :: w             ! weight of each point
   real(kind=dp_t) :: sum_w, sum_wx ! accumulators
   
   !===========================================================================
   ! Allocate
   allocate(smoothed(NrU, Nvars))

   !===========================================================================
   ! Smooth model

   ! Loop over quantities y
   do n = 1, Nvars

      ! Only smooth composition; HSE integration will smooth others as needed
      if ((n == idens) .or. (n == ipres)) then
         smoothed(:,n) = Ustate(:,n)
         cycle
      end if

      ! Loop over y_new,j
      do j = 1, NrU

         ! Clear sums
         sum_wx = ZERO
         sum_w = ZERO

         ! Loop over all points to compute weighted average
         do i = 1, NrU

            ! Compute weight
            w = (Uradius(i) - Uradius(j)) / s_length
            w = dexp(-1.0 * w**2)

            ! Accumulate sums
            sum_wx = sum_wx + w*Ustate(i,n)
            sum_w = sum_w + w
         enddo

         ! Normalize weighted average
         smoothed(j,n) = sum_wx / sum_w

      enddo
   enddo

   !===========================================================================
   ! Copy smoothed model back to original array
   do i = 1, NrU
      do n = 1, Nvars
         Ustate(i,n) = smoothed(i,n)
      end do
   end do

   !===========================================================================
   ! De-allocate
   deallocate(smoothed)

end subroutine smooth_model_krnl

!------------------------------------------------------------------------------
!==============================================================================
!------------------------------------------------------------------------------
! Delete the transition region below the H1 base and replace it with the
! appropriate profile

subroutine smooth_model_below(s_type, s_length)

   use init_1d_variables
   use init_1d_grids
   use bl_types
   use bl_constants_module
   use bl_error_module

   implicit none

   !===========================================================================
   ! Declare variables

   ! Arguments ................................................................
   integer,         intent(in   ) :: s_type
   real(kind=dp_t), intent(in   ) :: s_length

   ! Local ....................................................................
   real(kind=dp_t), allocatable :: smoothed(:,:)

   ! Temporaries ..............................................................
   integer :: i, n            ! loop indices
   integer :: j               ! cut point
   real(kind=dp_t) :: shift   ! drop the upper region before re-adding tanh
   real(kind=dp_t) :: x, y    ! for computing tanh profile
   
   !===========================================================================
   ! Allocate
   allocate(smoothed(NrU, Nvars))

   !===========================================================================
   ! Smooth model

   do n = 1, Nvars   ! loop over variables

      ! Only smooth composition and temperature; the HSE integration will
      ! correct the density and pressure
      if ((n == idens) .or. (n == ipres)) cycle

      do i = 1, NrU
         ! must go from low x to high x or 'if' statements must be restructured

         if (Uradius(i) < Uradius(ibase) - s_length) then
            ! if well below the transition, copy the input data
            smoothed(i,n) = Ustate(i,n)
            j = i  ! mark last point in this segment
            shift = Ustate(ibase,n) - Ustate(j,n)
         else if (Uradius(i) < Uradius(ibase)) then
            ! if near the transition, erase and impose a flat line
            smoothed(i,n) = Ustate(j,n)
         else
            ! if above the transition, lower to erase transition
            smoothed(i,n) = Ustate(i,n) - shift
         end if

      enddo

      ! Need to split these loops to avoid cross-talk

      ! Points above the base are left alone (no copying back to Ustate from
      ! smoothed, so the original data remains in place)
      do i = 1, ibase-1

         ! Add in tanh to replace the (previously-removed) sharp transition
         ! with a smooth transition
         x = (Uradius(i) - Uradius(ibase)) / s_length
         select case(s_type)
         case(SMOOTH_TANH)
            y = (ONE + tanh(x+0.5d0)) / (ONE + tanh(0.5d0))
         case(SMOOTH_TNH2)
            y = (ONE + tanh(x+2.0d0)) / (ONE + tanh(2.0d0))
         case(SMOOTH_GSSN)
            y = dexp(-1.0d0 * x**2)
         case(SMOOTH_EXPN)
            y = dexp(x)
         case default
            call bl_error("ERROR: invalid smoothing type in &
                               &smooth_model_below")
         end select
         Ustate(i,n) = smoothed(i,n) + shift * y

      enddo
   enddo

   !===========================================================================
   ! De-allocate
   deallocate(smoothed)

end subroutine smooth_model_below

