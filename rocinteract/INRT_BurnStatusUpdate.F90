!*********************************************************************
!* Illinois Open Source License                                      *
!*                                                                   *
!* University of Illinois/NCSA                                       * 
!* Open Source License                                               *
!*                                                                   *
!* Copyright@2008, University of Illinois.  All rights reserved.     *
!*                                                                   *
!*  Developed by:                                                    *
!*                                                                   *
!*     Center for Simulation of Advanced Rockets                     *
!*                                                                   *
!*     University of Illinois                                        *
!*                                                                   *
!*     www.csar.uiuc.edu                                             *
!*                                                                   *
!* Permission is hereby granted, free of charge, to any person       *
!* obtaining a copy of this software and associated documentation    *
!* files (the "Software"), to deal with the Software without         *
!* restriction, including without limitation the rights to use,      *
!* copy, modify, merge, publish, distribute, sublicense, and/or      *
!* sell copies of the Software, and to permit persons to whom the    *
!* Software is furnished to do so, subject to the following          *
!* conditions:                                                       *
!*                                                                   *
!*                                                                   *
!* @ Redistributions of source code must retain the above copyright  * 
!*   notice, this list of conditions and the following disclaimers.  *
!*                                                                   * 
!* @ Redistributions in binary form must reproduce the above         *
!*   copyright notice, this list of conditions and the following     *
!*   disclaimers in the documentation and/or other materials         *
!*   provided with the distribution.                                 *
!*                                                                   *
!* @ Neither the names of the Center for Simulation of Advanced      *
!*   Rockets, the University of Illinois, nor the names of its       *
!*   contributors may be used to endorse or promote products derived * 
!*   from this Software without specific prior written permission.   *
!*                                                                   *
!* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,   *
!* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES   *
!* OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND          *
!* NONINFRINGEMENT.  IN NO EVENT SHALL THE CONTRIBUTORS OR           *
!* COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       * 
!* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   *
!* ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE    *
!* USE OR OTHER DEALINGS WITH THE SOFTWARE.                          *
!*********************************************************************
!* Please acknowledge The University of Illinois Center for          *
!* Simulation of Advanced Rockets in works and publications          *
!* resulting from this software or its derivatives.                  *
!*********************************************************************
!******************************************************************************
!
! Purpose: update Burning Status of Lagrangian particles
!
! Description: none.
!
! Input: region  = current region.
!
! Output: region%levels(iLev)%plag%aiv
!
! Notes: none.
!
!******************************************************************************
!
! $Id: INRT_BurnStatusUpdate.F90,v 1.1.1.1 2015/01/23 22:57:50 tbanerjee Exp $
!
! Copyright: (c) 2004 by the University of Illinois
!
!******************************************************************************

SUBROUTINE INRT_BurnStatusUpdate( region )

  USE ModDataTypes
  USE ModDataStruct, ONLY : t_region
  USE ModGlobal,     ONLY : t_global
  USE ModPartLag,    ONLY : t_plag
  USE ModInteract,   ONLY : t_inrt_interact
  USE ModError
  USE INRT_ModParameters

#ifdef PLAG
  USE PLAG_ModParameters
#endif
  IMPLICIT NONE

! ... parameters
  TYPE(t_region), INTENT(INOUT), TARGET :: region

! ... loop variables
  INTEGER :: iPcls

! ... local variables
  REAL(RFREAL), PARAMETER :: DIAMALCUTOFF = 5.E-7_RFREAL ! 0.5-micron

  CHARACTER(CHRLEN) :: RCSIdentString

  INTEGER :: nPcls, nCont, iContAl, iCvAlMass
  INTEGER, POINTER, DIMENSION(:,:) :: pAiv

  LOGICAL :: vaporNotUsed

  REAL(RFREAL) :: densAl, massAlCutoff, massAl

  REAL(RFREAL), POINTER, DIMENSION(:,:) :: pCv

  TYPE(t_inrt_interact), POINTER :: pInrtBurn
  TYPE(t_plag),          POINTER :: pPlag
  TYPE(t_global),        POINTER :: global

!******************************************************************************

  RCSIdentString = '$RCSfile: INRT_BurnStatusUpdate.F90,v $ $Revision: 1.1.1.1 $'

  global => region%global

  CALL RegisterFunction( global,'INRT_BurnStatusUpdate',__FILE__ )

#ifdef PLAG
! begin -----------------------------------------------------------------------

  pPlag => region%plag

! Check if there are any particles --------------------------------------------

  nPcls = 0
  IF (global%plagUsed) nPcls = pPlag%nPcls

  IF (nPcls < 1) GO TO 9

! Set pointers and values -----------------------------------------------------

  pAiv => pPlag%aiv
  pCv  => pPlag%cv

  pInrtBurn => region%inrtInput%inrts(INRT_TYPE_BURNING)

  nCont = region%plagInput%nCont

! Of 1:nCont types of particle constituents, iContAl is the index of Al

  iContAl = pInrtBurn%edges(INRT_BURNING_L_MASS_X)%iNode(1) &
          - region%inrtInput%indPlag0

  IF (iContAl < 1 .OR. iContAl > nCont) THEN
    CALL ErrorStop( global,ERR_INRT_INDEXRANGE,__LINE__ )
  END IF ! iContAl

! Of 1:nCv conserved variables, iCvAlMass is the index of Al mass

  iCvAlMass = pPlag%cvPlagMass(iContAl)

  densAl = region%plagInput%dens(iContAl)

! set cutoff for amount of Aluminum mass considered negligible, based on the
! diameter that a particle would have if it consisted only of that Al mass.

  massAlCutoff = (global%pi / 6._RFREAL) * DIAMALCUTOFF**3 * densAl

! vaporNotUsed is used to flag errors, so it is set .true. whenever
! the vapor energy method is something other than "used".

  vaporNotUsed = pInrtBurn%switches(INRT_SWI_BURNING_VAPOR_METH) /= &
                 INRT_BURNING_VAPOR_METH_USED

! Loop over all the particles -------------------------------------------------

  DO iPcls = 1,nPcls

    SELECT CASE (pAiv(AIV_PLAG_BURNSTAT,iPcls))

    CASE (INRT_BURNSTAT_OFF)

! --- Re-light model

! --- Nothing yet implemented:  particles not burning remain not burning

    CASE (INRT_BURNSTAT_ON)

! --- If vapor energy is present, the particle is always considered burning

      IF (pCv(CV_PLAG_ENERVAPOR,iPcls) > 0._RFREAL) THEN

! ----- Flag error if vapor is not used, and yet, somehow, present

        IF (vaporNotUsed) THEN
          CALL ErrorStop( global,ERR_INRT_ENERVAPOR,__LINE__ )
        END IF ! vaporNotUsed

      ELSE

! ----- Quench model

! ----- Currently this is hardwired to the condition that the Aluminum mass
! ----- is less than some small, positive amount.

        massAl = pCv(iCvAlMass,iPcls)

        IF (massAl < massAlCutoff) THEN

          pAiv(AIV_PLAG_BURNSTAT,iPcls) = INRT_BURNSTAT_OFF

        END IF ! massAl

      END IF ! pCv(CV_PLAG_ENERVAPOR,iPcls)

    CASE DEFAULT

      CALL ErrorStop( global,ERR_REACHED_DEFAULT,__LINE__ )

    END SELECT ! pAiv(AIV_PLAG_BURNSTAT,iPcls)

  END DO ! iPcls

! finalize --------------------------------------------------------------------

9 CONTINUE
#endif
  CALL DeregisterFunction( global )

END SUBROUTINE INRT_BurnStatusUpdate

!******************************************************************************
!
! RCS Revision history:
!
! $Log: INRT_BurnStatusUpdate.F90,v $
! Revision 1.1.1.1  2015/01/23 22:57:50  tbanerjee
! merged rocflu micro and macro
!
! Revision 1.1.1.1  2014/07/15 14:31:38  brollin
! New Stable version
!
! Revision 1.3  2008/12/06 08:43:49  mtcampbe
! Updated license.
!
! Revision 1.2  2008/11/19 22:17:01  mtcampbe
! Added Illinois Open Source License/Copyright
!
! Revision 1.1  2007/04/09 18:50:11  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.1  2007/04/09 18:01:14  haselbac
! Initial revision after split from RocfloMP
!
! Revision 1.1  2004/12/01 21:56:12  fnajjar
! Initial revision after changing case
!
! Revision 1.2  2004/03/05 22:09:03  jferry
! created global variables for peul, plag, and inrt use
!
! Revision 1.1  2004/03/02 21:47:29  jferry
! Added After Update interactions
!
!******************************************************************************

