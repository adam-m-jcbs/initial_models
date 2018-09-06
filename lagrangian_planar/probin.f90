! DO NOT EDIT THIS FILE!!!
!
! This file is automatically generated by write_probin.py at
! compile-time.
!
! To add a runtime parameter, do so by editting the appropriate _parameters
! file.

! This module stores the runtime parameters.  The probin_init() routine is
! used to initialize the runtime parameters

! this version is a stub -- useful for when we only need a container for 
! parameters, but not for MAESTRO use.

module probin_module

  use bl_types

  implicit none

  private

  integer, save, public :: a_dummy_var = 0


end module probin_module


module extern_probin_module

  use bl_types

  implicit none

  private

  logical, save, public :: use_eos_coulomb = .true.
  !$acc declare create(use_eos_coulomb)
  logical, save, public :: eos_input_is_constant = .false.
  !$acc declare create(eos_input_is_constant)
  real (kind=dp_t), save, public :: conductivity_constant = 1.0d0
  !$acc declare create(conductivity_constant)
  real (kind=dp_t), save, public :: small_x = 0.0
  !$acc declare create(small_x)

end module extern_probin_module


module runtime_init_module

  use bl_types
  use probin_module
  use extern_probin_module

  implicit none

  namelist /probin/ use_eos_coulomb
  namelist /probin/ eos_input_is_constant
  namelist /probin/ conductivity_constant
  namelist /probin/ small_x

  private

  public :: probin

  public :: runtime_init, runtime_close

contains

  subroutine runtime_init()

    
  end subroutine runtime_init

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine runtime_close()

    use probin_module

  end subroutine runtime_close

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module runtime_init_module