  !***********************************************************************
  !    Copyright (C) 1995-
  !        Roy A. Walters, R. Falconer Henry
  !
  !        TQGridGen@gmail.com
  !
  !    This file is part of TQGG, Triangle-Quadrilateral Grid Generation,
  !    a grid generation and editing program.
  !
  !    TQGG is free software; you can redistribute it and/or
  !    modify it under the terms of the GNU General Public
  !    License as published by the Free Software Foundation; either
  !    version 3 of the License, or (at your option) any later version.
  !
  !    This program is distributed in the hope that it will be useful,
  !    but WITHOUT ANY WARRANTY; without even the implied warranty of
  !    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  !    General Public License for more details.
  !
  !    You should have received a copy of the GNU General Public
  !    License along with this program; if not, write to the Free Software
  !    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307
  !    USA, or see <http://www.gnu.org/licenses/>.
  !***********************************************************************

! *************************************************************************

      Subroutine SAMPLE(quit)

!       Purpose: Permits selection of boundary nodes from the digitized
!                boundary data file in DIGIT format and selection of
!                internal nodes for the depth grid from the digitized
!                contour data file (DIGIT format) and/or from a file
!                of depth soundings in NODE format.
!
!       All boundaries should have have been digitized in the counter-
!       clockwise direction. An optional test is included to permit the
!       user to check if each boundary has been digitized in the coun-
!       terclockwise direction. The nodes selected from the outer boun-
!       dary are output in counter-clockwise order, but island boundary
!       nodes are output in clockwise order, as required for NODE
!       format files. The program permits the user to select every
!       Nth point from data strings in the boundary and contour files.
!       Different values of N can be used for land or sea portions of
!       the boundary. The outer boundary is assumed to consist of
!       alternate stretches of land and sea boundary, the first block
!       being land boundary. Each island boundary is assumed to be a
!       single stretch of land boundary. All points in the soundings
!       file are added to the list of internal nodes.

!       UNITS:
!       x,y coordinates in the DIGIT and NODE format files are assumed
!       to be in problem length units.
! *************************************************************************

      use MainArrays

      implicit none

      INCLUDE '../includes/defaults.inc'

!     - passed variable
      logical quit,change

!     - local variables
      integer gridcode
!      character PigCursYesNo*1
!      CHARACTER*80 ans, cstr

! *** start

! *** open, parse, and read data file
      call Sample_Input (gridcode,quit)
      if(quit) return

      If(TotCoords.gt.0) then
        dispnodes = .true.
        change = .false.
        call DrwFig(change)
      else
        return
      endif
      
! *** define resolution
!      call Set_Resolution ()  !initialize points 

      END subroutine

! ********************************************************************

      subroutine Sample_Input (gridcode,quit)

      use MainArrays

      implicit none

      INCLUDE '../includes/defaults.inc'

!     - local variables
      integer j,Fnlen,nunit,stat,ierr
      integer segcode,seglast,gridcode,isave,TotCoordslast
      logical PigOpenFileCD
      real xtest,ytest,ztest,segtest,xmin,xmax,ymin,ymax,dsmin
      real xlast,ylast,dx,dy,ds2,dl2
      CHARACTER*256 fle
      character(80) Firstline,ans
      character(256) cstrgrid
      logical Quit
      CHARACTER*80 cstr, retstring

! *** start
      nunit = 3

      if(.not.PigOpenFileCD(nunit,'Open Sample File', fle, &
          'XYZ Files (*.xy*),*.xy*;All Files (*.*),*.*;')) then
        fnlen = len_trim(fle)
        call PigMessageOK('Error opening file '//fle(:fnlen),'OpenGrid')
        GridRName =  'NONE'
        quit = .true.
        return
      endif

      GridRName =  fle
      fnlen = len_trim( Fle )
        
      scaleX = 1.
      scaleY = 1.
      igridtype = 3

      call PigPutMessage('Reading file '//fle(:fnlen))
      TotCoords = 0
      gridcode = 0
      quit = .false.

! *** try to determine format
      READ(nunit,'(a)', iostat=stat) Firstline

      if(firstline(1:4).eq."#NGH") then  !ngh grid file
        call PigMessageOK('Cannot sample from ngh file ','Sample')
        quit = .true.
      elseif(firstline(1:4).eq."#NOD") then  !nod point file
        call PigMessageOK('Read nod file then use resample ','Sample')
        Quit = .true.
      elseif(firstline(1:4).eq."#GRD") then  !xyz and element grid file, new format
        call PigMessageOK('Cannot sample from grd file ','Sample')
        quit = .true.
      else  !then just parse the file for coordinates

!       Get igridtype from user
        igridtype = -9999
        cstrgrid = 'Enter grid type:'//newline//&
                 ' 0 = latitude/longitude (degrees)'//newline//&
                 ' 1 = UTM coordinates (meters)'//newline//&
                 ' 2 = Cartesian coordinates (meters)'//newline//&
                 ' 3 = unspecified units'//newline//char(0)

        do
          call PigPrompt(cstrgrid, ans )
          READ( ans, *, iostat=ierr ) igridtype
          if(ierr.eq.0) exit
        enddo

        read(firstline,*,iostat=stat) xlast,ylast,ztest,segtest  !xyz+segment file
        if(stat.eq.0) then ! ok format

! NOTE: Only sample from XYZ files with lines x,y,z,segment; x,y,z; or x,y
!       on each line.
        
        
20        cstr= 'Enter minimum subsample spacing [m] (0 = all data):'
          call PigPrompt( cstr, RetString )
          read(RetString,*,iostat=stat) dsmin
          if(stat.ne.0) then
            call PigMessageOK('Error reading real number:','Sample')
            go to 20
          endif

         
          seglast = nint(segtest)
          ds2 = dsmin*dsmin
          gridcode = 1
          dxray(1) = xlast
          dyray(1) = ylast
          depth(1) = ztest
          code(1) = seglast
          TotBndys = 1
          TotCoordslast = 0
          TotIntBndys = 0
          TotIntPts = 0
          isave = 1
          j=1
          do
            j = j+1
            read(nunit,*,iostat=stat) xtest,ytest,ztest,segtest
            segcode = nint(segtest)
!            write(*,*) 'j,seglast,segcode',j,seglast,segcode
            if(stat.ne.0) then
              TotCoords = isave
              PtsThisBnd(TotBndys) = TotCoords - TotCoordslast
              itot = TotCoords
              xmin = minval(dxray(1:itot))
              xmax = maxval(dxray(1:itot))
              ymin = minval(dyray(1:itot))
              ymax = maxval(dyray(1:itot))
              call fullsize(xmin,ymin,xmax,ymax)
              exit
            elseif(segcode.ne.seglast) then !new boundary segment
              TotCoords = isave
              PtsThisBnd(TotBndys) = TotCoords - TotCoordslast
              TotCoordslast = isave
              TotBndys = TotBndys + 1
              seglast = segcode
              isave = isave + 1
              dxray(isave) = xtest
              dyray(isave) = ytest
              depth(isave) = ztest
              code(isave) = 1
              xlast = xtest
              ylast = ytest
            else  !add to current boundary

!             Test for closeness
!             Calc dist based on grid type
              IF (igridtype.eq.0) THEN
                call haversine(ylast,xlast,ytest,xtest,dl2)
                dl2 = dl2*dl2
              ELSE
                dx = xtest - xlast
                dy = ytest - ylast
                dl2 = dx*dx + dy*dy
              END IF


              if(dl2.ge.ds2) then !save it
                isave = isave + 1
                dxray(isave) = xtest
                dyray(isave) = ytest
                depth(isave) = ztest
                code(isave) = 1
                xlast = xtest
                ylast = ytest
              endif
            endif
          enddo
        else
          read(firstline,*,iostat=stat) xlast,ylast,ztest  !xyz file, one boundary
          if(stat.eq.0) then

10          cstr= 'Enter minimum subsample spacing [m] (0 = all data):'
            call PigPrompt( cstr, RetString )
            read(RetString,*,iostat=stat) dsmin
            if(stat.ne.0) then
              call PigMessageOK('Error reading real number:','Sample')
              go to 10
            endif
            
            ds2 = dsmin*dsmin
            dxray(1) = xlast
            dyray(1) = ylast
            depth(1) = ztest
            code(1) = 1
            isave = 1
            j=1
            do
              j = j+1
              read(nunit,*,iostat=stat) xtest,ytest,ztest 
              if(stat.ne.0) then
                TotCoords = isave !j-1
                TotBndys = 1
                PtsThisBnd(1) = TotCoords
                TotIntBndys = 0
                TotIntPts = 0
                itot = TotCoords
                xmin = minval(dxray(1:itot))
                xmax = maxval(dxray(1:itot))
                ymin = minval(dyray(1:itot))
                ymax = maxval(dyray(1:itot))
                call fullsize(xmin,ymin,xmax,ymax)
                exit
              endif

!             Test for closeness
!             Calc dist based on grid type
              IF (igridtype.eq.0) THEN
                call haversine(ylast,xlast,ytest,xtest,dl2)
                dl2 = dl2*dl2
              ELSE
                dx = xtest - xlast
                dy = ytest - ylast
                dl2 = dx*dx + dy*dy
              END IF

              if(dl2.ge.ds2) then !save it
                isave = isave + 1
                dxray(isave) = xtest
                dyray(isave) = ytest
                depth(isave) = ztest
                code(isave) = 1
                xlast = xtest
                ylast = ytest
              endif
            enddo
          else
            call PigMessageOK('Unsupported file format ','Sample')
            quit = .true.
          endif
        endif          
      endif
      close(nunit)

      end subroutine

! ********************************************************************
