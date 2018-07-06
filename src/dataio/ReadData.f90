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

! --------------------------------------------------------------------------*
!     Routines to read ngh files. 
! --------------------------------------------------------------------------*

      SUBROUTINE OpenGridFile( Quit )

! Purpose: Prompts user for the input grid file.
! Givens : None
! Returns: None
! Effects: User is repeatedly prompted for a grid file until a valid
!          filename is entered.  Grid file is opened, points are read,
!          and grid file is closed.

      use mainarrays, only: x0off, y0off, scaleX, scaleY, igridtype

      implicit none

      LOGICAL Quit
!      integer NREC

      INCLUDE '../includes/defaults.inc'

      CHARACTER*256 fle
      LOGICAL newfile, newformat
      integer  nunit, fnlen, istat,linenum
      logical PigOpenFileCD,lexist
      character(80) Firstline
!------------------BEGIN------------------

      newfile = Quit
      if(newfile) then !initialize
        x0off = 0.
        y0off = 0.
        scaleX = 1.
        scaleY = 1.
        igridtype = 3
      endif
      Quit = .FALSE.
      nunit = 8
      fle = 'NONE'

      if(.not.PigOpenFileCD(nunit,'Open Grid File', fle,&
     &     'Grid Files (*.[ng][cgr]*),*.ngh;All Files (*.*),*.*;')) then  !bail out
        Quit = .TRUE.
        GridRName =  'NONE'
        return
      else
        inquire(nunit,name=fle,exist=lexist)
        if(.not.lexist) then ! no file
          Quit = .TRUE.
          GridRName =  'NONE'
          return
        else
          istat = index( fle, char(0) )
          if(istat.gt.0) then ! c string
            fnlen = istat -1
          else ! f string
            fnlen = len_trim( fle )
          endif
          call PigPutMessage('Reading file '//fle(:fnlen))
          GridRName =  fle
!          write(*,*) fnlen-2,fnlen
!          write(*,*) fle(fnlen-2:fnlen)
!          istat = index( fle, '.nc' )
          if(fle(fnlen-2:fnlen).eq.'.nc') then !netCDF file
            close(nunit,status='keep')
            call ReadnetCDFData(fle,Quit)
          elseif(fle(fnlen-3:fnlen).eq.'.ngh') then !ngh file
!            open(nunit,file=fle,status='old')
            READ(nunit,'(a)',IOSTAT=istat) Firstline
            linenum = 1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadGrid' )
              Quit = .TRUE.
              close( nunit )
              return
            endif
            
            if(firstline(1:4).eq."#NOD") then  !node file, new format
              call PigMessageOK( 'Node file.. Wrong format for grid.','ReadGrid' )
              Quit = .true.
            elseif(firstline(1:4).eq."#GRD") then  !xyz and element grid file, new format
              call PigMessageOK( 'GRD file.. Wrong format for ngh file.','ReadGrid' )
              Quit = .true.
            elseif(firstline(1:4).eq."#NGH") then  !neigh grid file, new format
              newformat = .true.
              call PigStatusMessage( 'Reading Grid file.. [NGH] format' )
              call ReadNGHData (nunit,newfile,newformat)
              Quit = newfile
              if(.not.quit) call DoCheckEdges()
              call PigStatusMessage( 'Done' )
            else ! guess format
              newformat = .false.
              call PigStatusMessage( 'Reading Grid file.. old [NGH] format' )
              call ReadNGHData (nunit,newfile,newformat)
              Quit = newfile
              if(.not.quit) then
                call DoCheckEdges()
              endif
              call PigStatusMessage( 'Done' )
            endif
          elseif(fle(fnlen-3:fnlen).eq.'.grd') then !grd file
!            open(nunit,file=fle,status='old')
            READ(nunit,'(a)',IOSTAT=istat) Firstline
            linenum = 1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadGrid' )
              Quit = .TRUE.
              close( nunit )
              return
            endif
            
            if(firstline(1:4).eq."#NOD") then  !node file, new format
              call PigMessageOK( 'Node file.. Wrong format for grd file.','ReadGrid' )
              Quit = .true.
            elseif(firstline(1:4).eq."#GRD") then  !xyz and element grid file, new format
              call PigStatusMessage( 'Reading Grid file.. [GRD] format' )
              call ReadGRDData (nunit,Quit)
              call PigStatusMessage( 'Done' )
            elseif(firstline(1:4).eq."#NGH") then  !neigh grid file, new format
              call PigMessageOK( 'ngh file.. Wrong format for grd file.','ReadGrid' )
              Quit = .true.
            else ! guess format
              Quit = .true.
              call PigStatusMessage( 'Reading Grid file.. basic grd format' )
              rewind(nunit)
              call ReadGRDData (nunit,Quit)
              call PigStatusMessage( 'Done' )
            endif
          elseif(fle(fnlen-3:fnlen).eq.'.nod') then !node file
              call PigMessageOK( 'Node file.. Wrong format for grid.','ReadGrid' )
              Quit = .true.            
          else
            call PigMessageOK(  'ERROR: Unknown file format','ReadGrid' )
            Quit = .true.            
          endif
        endif
     
      endif

      close( nunit )
      
      if(.not.Quit) call VerifyGridType(Quit)

      END

! --------------------------------------------------------------------------*

      SUBROUTINE VerifyGridType (Quit)
   
! Purpose : Verify igridtype for backward compatibility with old file formats.

      use MainArrays

      implicit none

      INCLUDE '../includes/defaults.inc'
      
      integer ierr
      logical Quit
      character(80) :: cstr, ans
      character(256),save :: cstrgrid 
      
      quit = .false.
      cstrgrid = 'Enter grid type:'//newline//&
                   ' 0 = latitude/longitude (degrees)'//newline//&
                   ' 1 = UTM coordinates (meters)'//newline//&
                   ' 2 = Cartesian coordinates (meters)'//newline//&
                   ' 3 = unspecified units'//newline//char(0)
      
      if(igridtype.eq.-9999) then !ask for grid type
        UTMzone = 'nul'
        do
          call PigPrompt(cstrgrid, ans )
          if(ans(1:1).eq.char(0)) then !cancel
            Quit = .TRUE.
            exit
          endif                 
          READ( ans, *, iostat=ierr ) igridtype
          if(ierr.eq.0) then
            if(igridtype.eq.1) then  !get UTM zone
              iUTMzone = 0
              call VerifyUTMzone(ierr, Quit)
              exit
            elseif(igridtype.ge.0.and.igridtype.le.3) then
              exit
            endif
          endif
        enddo
      else  !verify grid type
        write(cstr,'(I2)') igridtype
        call PigMessageYesNo( 'Gridtype is '//cstr(1:2)//' OK?', ans)
        if(ans(1:1).eq.'N') then
          UTMzone = 'nul'
          do
            call PigPrompt(cstrgrid, ans )
            if(ans(1:1).eq.char(0)) then !cancel
              Quit = .TRUE.
              exit
            endif                 
            READ( ans, *, iostat=ierr ) igridtype
            if(ierr.eq.0) then
              if(igridtype.eq.1) then  !get UTM zone
                iUTMzone = 0
                call VerifyUTMzone(ierr, Quit)
                exit
              elseif(igridtype.ge.0.and.igridtype.le.3) then
                exit
              endif
            endif
          enddo
        elseif(igridtype.eq.1) then !verify UTM zone
          read(UTMzone(1:2),*,iostat=ierr ) iUTMzone
          call VerifyUTMzone(ierr, Quit)
        endif
      endif

      END

! --------------------------------------------------------------------------*

      SUBROUTINE VerifyUTMzone(istat,Quit)
   
! Purpose : To determine UTM zone for igridtype=1

      use MainArrays

      implicit none
      
      INCLUDE '../includes/defaults.inc'
      
      integer :: j,istat
      character(80) message,ans
      LOGICAL Quit
      
      Quit = .false.
      do
        If(istat.ne.0.or.iUTMzone.lt.1.or.iUTMzone.gt.60.or.&
                         iachar(UTMzone(3:3)).eq.iachar('I').or.&
                         iachar(UTMzone(3:3)).eq.iachar('O').or.&
                         iachar(UTMzone(3:3)).lt.iachar('C').or.&
                         iachar(UTMzone(3:3)).gt.iachar('X')) then !bad zone id
          !ask for zone
          write(message,'(a)') 'Invalid UTM zone: '//UTMzone(1:3)//newline//&
                             'Enter UTM zone: 1C to 60X'
          call PigPrompt(message,ans )
          if(ans(1:1).eq.char(0)) then !cancel
            Quit = .TRUE.
            return
          endif                 
          UTMzone(1:3) = ans(1:3)
          j = len_trim(UTMzone)
          !write(message,'(a)') 'UTM zone: '//UTMzone(1:3)
          !call PigMessageOK(message,'ReadGrid' )
          if(j.eq.2) then
            UTMzone(3:3) = UTMzone(2:2)
            UTMzone(2:2) = UTMzone(1:1)
            UTMzone(1:1) = ' '
          endif
          read( UTMzone(1:2),*,IOSTAT=istat ) iUTMzone
!          If(istat.ne.0) iUTMzone = 0
          !write(message,'(a)') 'UTM zone: '//UTMzone(1:3)
          !call PigMessageOK(message,'ReadGrid' )
!          istat = 0
        else
          exit
        endif
      enddo

      RETURN
      END

! --------------------------------------------------------------------------*

      SUBROUTINE ReadNGHData (nunit,quit,newformat)
   
! Purpose : To read grid data into memory

      use MainArrays

      implicit none

      INCLUDE '../includes/defaults.inc'
!      INCLUDE '../includes/cntcfg.inc'

!     - PASSED VARIABLES
      INTEGER :: nunit
      LOGICAL :: Quit

      REAL :: XMAX, YMAX, XMIN, YMIN

!     - LOCAL VARIABLES
      INTEGER :: i , j , i0, n_offset, nbtot_max
      INTEGER :: irec, nrec, istat
      INTEGER :: numrec, numrecmax, linenum
      real :: zsf
      character(80) :: message
      LOGICAL :: NewFile,newformat
      character(120) :: Firstline

!------------------BEGIN-------------------------------

      NewFile = Quit

      QUIT = .FALSE.
      
!     - initialize 
      TotTr = 0
      i0 = 0
      if(NewFile) then !start from scratch
        do j=1,MAXTRI
          TCode(j) = 1
        enddo
        do i=1,mrec
          do j=1,nbtot
            NL(j,i) = 0
          enddo
        enddo
        nrec = 1
        nbtot_max = 0
        GridSIndex = 9999999
      else  ! add to existing grid
        nrec = itot + 1
        nbtot_max = nbtotr
        GridSIndex = nrec
      endif

      if(newformat) then

        linenum=1
        do              !remove comment lines
          READ(nunit,'(a)', IOSTAT=istat) Firstline
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadGrid' )
            Quit = .TRUE.
            return
          endif
          if(firstline(1:1).ne."#") then
            READ( firstline, *, IOSTAT=istat ) x0off, y0off, scaleX, scaleY, igridtype
            if(istat.ne.0) then
              write(message,'(a,i8,a)') 'ERROR reading line ',linenum
              call PigMessageOK(message,'ReadGrid' )
              Quit = .TRUE.
              return
            endif
            if(igridtype.eq.1) then ! UTM coordinates, get zone id
              j = len_trim(firstline)
              READ( firstline(j-2:j), '(a)', IOSTAT=istat ) UTMzone(1:3)
              if(istat.eq.0) read( UTMzone(1:2),*,IOSTAT=istat ) iUTMzone
              call VerifyUTMzone(istat,Quit)
              if(Quit) return 
            endif
            exit
          endif
        enddo

! - read max number of nodes in this grid
        read(nunit,*, IOSTAT=istat  ) numrec
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadGrid' )
          Quit = .TRUE.
          return
        endif
                  
! - read max num  ber of neighbours required for this grid
        READ(nunit,*, IOSTAT=istat ) NBTOTR
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadGrid' )
          Quit = .TRUE.
          return
        endif
      
      else

        linenum = 0
        rewind(nunit)
! - read max number of nodes in this grid
        read(nunit,*,IOSTAT=istat) numrec
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadGrid' )
          Quit = .TRUE.
          return
        endif

! - read max number of neighbours required for this grid
        READ( nunit, *, IOSTAT=istat ) NBTOTR
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadGrid' )
          Quit = .TRUE.
          return
        endif

! *** test if this is really old format without offsets and scales
        READ(nunit,'(a)', IOSTAT=istat) Firstline
        i = 1
        READ(firstline,*,IOSTAT=istat) IREC,DXRAY(i),DYRAY(i),CODE(i),DEPTH(i),( NL(j,i),j = 1, NBTOTR )
        if(istat.eq.0) then
          i0 = 1
        else
! - read offsets, scale factors for old format
          READ(firstline, *, IOSTAT=istat ) x0off, y0off, scaleX, scaleY
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadGrid' )
            Quit = .TRUE.
            return
          endif
          i0 = 0
        endif
        igridtype = -9999
     
      endif
                  
      numrecmax   = NUMREC+nrec-1
      if ( NUMRECmax .gt. MREC ) then
        call PigMessageOK('WARNING: Grid file has too many points-setting to maximum','ReadGrid')
        NUMRECmax = MREC
        NUMREC = MREC -nrec +1
      endif

      if ( NBTOTR .gt. NBTOT ) then
        call PigMessageOK('WARNING: Grid file has too many neighbors-setting to maximum','ReadGrid')
        NBTOTR = NBTOT
      endif
      write(message,'(a,i6,a,i8,a)') 'Reading Grid File with ',NUMREC,' nodes, ',NBTOTR,' neighbours'
      call PigPutMessage(message)

!  Adjust for offsets
      n_offset = nrec - 1
      zsf = abs(scaleY)
   
      do i=nrec+i0,nrec+numrec-1 
        READ(nunit,*,IOSTAT=istat) IREC,DXRAY(i),DYRAY(i),CODE(i),DEPTH(i),( NL(j,i),j = 1, NBTOTR )
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadGrid' )
          Quit = .TRUE.
          return
        endif
        
        DXRAY(i) = DXRAY(i)*scaleX
        DYRAY(i) = DYRAY(i)*scaleX
        DEPTH(i) = DEPTH(i)*zsf

        do j=1,NBTOTR
          if(NL(j,i).gt.0) then
            NL(j,i) = NL(j,i) + n_offset
          endif
        enddo

        do j=1,NBTOTR
          if( (NL(j,i) .lt. 0).OR.(NL(j,i) .gt. NUMRECmax)) then
!              set illegal number to zero - that should 
!              delete any lines to points out of grid
!            write(message,'(a,i8,a,i8)')'Eliminated connection from node ',i,' to node ',NL(j,i)
!            call PigPutMessage(message)
            NL(j,i) = 0
          endif
        end do
        ITOT = i
       
      enddo
      
      scaleX = 1.
      if(scaleY.gt.0.) then
        scaleY = 1.
      else
        scaleY = -1.
      endif

      nbtotr = nbtot !expand to max !max(nbtotr,nbtot_max)
      DispNodes = .false.

!      if(int(ScaleY).eq.-999) then
!        xlongmin = minval(dxray(1:itot))
!        xlongmax = maxval(dxray(1:itot))
!        xlongsum=ScaleX
!      endif

      xmin = minval(dxray(1:itot))
      xmax = maxval(dxray(1:itot))
      ymin = minval(dyray(1:itot))
      ymax = maxval(dyray(1:itot))
      call fullsize(xmin,ymin,xmax,ymax)

      RETURN
      END

! --------------------------------------------------------------------------*

      SUBROUTINE ReadGRDData (nunit,quit)
   
! Purpose : To read grid data into memory

      use MainArrays

      implicit none

      INCLUDE '../includes/defaults.inc'
!      INCLUDE '../includes/cntcfg.inc'

!     - PASSED VARIABLES
      LOGICAL Quit

      REAL    XMAX, YMAX, XMIN, YMIN

!     - LOCAL VARIABLES
      INTEGER i , j 
!        - counters
      INTEGER  nunit, istat
!        - the number of records that is to be in the data file
      INTEGER numrec, numele, linenum
      real :: zsf
      logical basicformat
      character(100) Firstline
      character(80) message

!------------------BEGIN-------------------------------

      basicformat = Quit
      QUIT = .FALSE.

      linenum=1
      if(basicformat) then
        igridtype = -9999
      else
        do              !remove comment lines
          READ(nunit,'(a)', IOSTAT=istat) Firstline
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'Read_GRD' )
            Quit = .TRUE.
            return
          endif
          if(firstline(1:1).ne."#") then
            READ( firstline, *, IOSTAT=istat ) x0off, y0off, scaleX, scaleY, igridtype
            if(istat.ne.0) then
              write(message,'(a,i8,a)') 'ERROR reading line ',linenum
              call PigMessageOK(message,'Read_GRD' )
              Quit = .TRUE.
              return
            endif
            if(igridtype.eq.1) then ! UTM coordinates, get zone id
              j = len_trim(firstline)
              READ( firstline(j-2:j), '(a)', IOSTAT=istat ) UTMzone(1:3)
              if(istat.eq.0) read( UTMzone(1:2),*,IOSTAT=istat ) iUTMzone
              call VerifyUTMzone(istat,Quit)
              if(Quit) return 
            endif
            exit
          endif
        enddo
      endif
      
! - read max number of nodes and elements in this grid
      read(nunit,*,IOSTAT=istat) numrec, numele
!      linenum = 2
      if(istat.ne.0) then
        call StatusError(istat,linenum,'Read_GRD' )
        Quit = .TRUE.
        return
      endif

      write(message,'(a,i6,a,i8,a)') 'Reading Grd File with ',NUMREC,' nodes, ',numele,' elements'
      call PigPutMessage(message)

!  parse first line to find format for nodal data      
      READ(nunit,'(a)',IOSTAT=istat ) Firstline
      linenum=linenum+1
      if(istat.ne.0) then
        call StatusError(istat,linenum,'Read_GRD' )
        Quit = .TRUE.
        return
      endif

      read(Firstline,*,IOSTAT=istat) dxray(1),dyray(1),depth(1),code(1) 
      if(istat.eq.0) then
        do i=2,numrec
          read(nunit,*,IOSTAT=istat) dxray(i),dyray(i),depth(i),code(i)
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'Read_GRD' )
            Quit = .TRUE.
            return
          endif
        enddo
      else
        read(Firstline,*,IOSTAT=istat)  dxray(1),dyray(1),depth(1)
        if(istat.ne.0) then
          call StatusError(istat,linenum,'Read_GRD' )
          Quit = .TRUE.
          return
        endif
        code(1) = 0
        do i=2,numrec
          read(nunit,*,IOSTAT=istat) dxray(i),dyray(i),depth(i)
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'Read_GRD' )
            Quit = .TRUE.
            return
          endif
          code(i) = 0
        enddo
      endif

      itot = numrec
      zsf = abs(scaleY)
      do i=1,itot                
        DXRAY(i) = DXRAY(i)*scaleX
        DYRAY(i) = DYRAY(i)*scaleX
        DEPTH(i) = DEPTH(i)*zsf
      enddo
      
      scaleX = 1.
      if(scaleY.gt.0.) then
        scaleY = 1.
      else
        scaleY = -1.
      endif

!      igridtype = -9999

!  parse first line to find format for element list      
      READ(nunit,'(a)',IOSTAT=istat ) Firstline
      linenum=linenum+1
      if(istat.ne.0) then
        call StatusError(istat,linenum,'Read_GRD' )
        Quit = .TRUE.
        return
      endif

      read(Firstline,*,IOSTAT=istat)  (ListTr(j,1),j=1,4),TCode(1)
      if(istat.eq.0) then
        do i=2,numele
          read(8,*,IOSTAT=istat) (ListTr(j,i),j=1,4),TCode(i)
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'Read_GRD' )
            Quit = .TRUE.
            return
          endif
        enddo
      else
        read(Firstline,*,IOSTAT=istat)  (ListTr(j,1),j=1,3)
        if(istat.ne.0) then
          call StatusError(istat,linenum,'Read_GRD' )
          Quit = .TRUE.
          return
        endif
        ListTr(4,1) = 0
        TCode(1) = 1
        do i=2,numele
          read(8,*,IOSTAT=istat) (ListTr(j,i),j=1,3)
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'Read_GRD' )
            Quit = .TRUE.
            return
          endif
          ListTr(4,i) = 0
          TCode(i) = 1
        enddo
      endif

      TotTr = numele

! *** generate neighbor list

      CALL GenerateNL(itot,nbtot,nbtotr,NL,TotTr,ListTr)

      nbtotr = nbtot !expand to max !max(nbtotr,nbtot_max)
      DispNodes = .false.

!      if(int(ScaleY).eq.-999) then
!        xlongmin = minval(dxray(1:itot))
!        xlongmax = maxval(dxray(1:itot))
!        xlongsum=ScaleX
!      endif

      xmin = minval(dxray(1:itot))
      xmax = maxval(dxray(1:itot))
      ymin = minval(dyray(1:itot))
      ymax = maxval(dyray(1:itot))
      call fullsize(xmin,ymin,xmax,ymax)

      return
      END

! --------------------------------------------------------------------------*

      SUBROUTINE DoCheckEdges()

!  Purpose:
!  1.  To check that all edges defined by and node's neighbour list are
!      also defined by the neighbouring node's neighbour list. This check
!      is necessary because the definition of each edge is defined in two
!      places: once in each nodes neighbour list. This means it is easy
!      for one of the lists to be modified and the other not modified.
!      For any edges defined only at one end, we add the other end's 
!      definition.
!  2.  To check that the neighbours in any node's neighbour list are
!      not listed more than once. Duplicates are deleted.
!  3.  To check that the neighbours exist. If they do not exist, they are
!      deleted from the neighbour list.
!  4.  To ensure that a node is not connected to itself. If it is, this
!      connection is deleted.
!  Method:
!      For each node in turn, check 2 is implemented first, and duplicates
!      removed without confirming with the user, but with information.
!      Then for each neighbour, the neighbours neighbour list is checked
!      to ensure that it contains this node. If not, it is added, subject
!      to user confirmation.

! dummy arguments
!      integer Nrec
! include files

      use MainArrays

! local variables
      integer i, j, k, nei, last
!      character*80 cstr
! code
      do i=1,itot !Nrec-1
!          if(exist(i).or.code(i).ge.0)then
          if(code(i).ge.0)then
! test 3: remove non-existent neighbours
              do j=1,nbtot
                  if(NL(j,i).gt.0)then
!                      if(.not.exist(NL(j,i)).or.code(i).lt.0) then
                      if(code(i).lt.0) then
!                         pointing to a non-existent node
!                          NL(j,i) = 0
!                          write(cstr,'(a,i7,a,i7)')'Removing connection from node ',i,' to non-existent (deleted) node',NL(j,i)
!                          call PigPutMessage(cstr)
                          NL(j,i) = 0
                      else if(NL(j,i).gt.itot) then
!                         pointing to a node > last node
!                          write(cstr,'(a,i7,a,i7)')'Removing connection from node ',i,' to non-existent ( >Nrec) node',NL(j,i)
!                          call PigPutMessage(cstr)
                          NL(j,i) = 0
                      else if(NL(j,i).eq.i) then
! test 4: cannot be joined to self
!                          write(cstr,'(a,i7,a)')'Removing connection from node ',i,' to itself!'
!                          call PigPutMessage(cstr)
                          NL(j,i) = 0
                      endif
                  endif
              enddo
! test 2: compress neighbour list
!             step 1: replace duplicates with zeros
              do j=1,nbtot
                  if(NL(j,i).gt.0) then
                    do k=j+1,nbtot
                      if(NL(j,i).eq.NL(k,i)) then
!                         duplicate found
!                          write(cstr,'(a,i6,a,i6,a,i6)')'Removing duplicated neighbour ',k,'(',NL(k,i),') from node',i
!                          call PigPutMessage(cstr)
                          NL(k,i) = 0
                      endif
                    enddo
                  endif
              enddo
!             step 2: remove zero neighbours, move others to left in list
              last = nbtot
              do while  ((NL(last,i).eq.0).and.(last.gt.1))
                  last = last - 1
              enddo
              do j=1,last
                  if(NL(j,i).eq.0) then
                      do k=j,last
                          NL(k,i) = NL(k+1,i)
                      enddo
                  endif
              enddo
! test 1: check neighbour list of all neighbours includes this node
              do j=1,nbtot
                  nei = NL(j,i)
                  if(nei.ne.0) then
                      k=1
                      do while(    (NL(k,nei).ne.i).and.(k.lt.nbtot))
                          k = k+1
                      enddo
                      if(NL(k,nei).ne.i) then
!                         this node not found in neighbour's neighbour list
!                          write (cstr,'(a,i7,a,i7)') 'Adding node ',i,' to neighbour list of node ',nei
!                          call PigPutMessage(cstr)
                          k = 1
                          do while(    (NL(k,nei).ne.0).and.(k.lt.nbtot))
                              k = k + 1
                          enddo
                          if(k.le.nbtot)then
                              NL(k,nei) = i
                          else
                              call PigPutMessage('Too many neighbours already to add new one.')
                          endif
                      endif
                  endif
              enddo
          endif
      enddo

      end

! -------------------------------------------------------------------

      SUBROUTINE GenerateNL(np,maxngh,numngh,nbrs,ne,nen)

! ***********************************************************************
! This routine converts from triangle list (TRIANG 
! format) and node file (NODE format) to NEIGH format
! ******************************************************

      IMPLICIT NONE

! *** passed VARIABLES ***
!      integer nindx
      integer np,maxngh,numngh,nbrs(maxngh,np)
      integer ne,nen(4,ne)

! *** LOCAL VARIABLES ***
      integer ncn2, nonbrs(np)
!   CUVX - current vertex being considered
      INTEGER CUVX
!   CUNBR - current neighbour being considered
      INTEGER CUNBR
      INTEGER II,JJ,KK,LL,MM
      LOGICAL pass1, NEWNBR
      character cstr*80

!   Starting neighbor list

!   Set count of nbrs to zero for all nodes

      DO KK = 1, np
        NONBRS(KK) = 0
        DO JJ = 1, maxngh
          nbrs(JJ,KK) = 0
        enddo
      enddo

! *** Check each triangle and check that each vertex is in each of 
! *** the other two vertices' neighbour lists

      pass1 = .true.
      DO JJ = 1, ne
        ncn2 = 3 + min0(1,nen(4,JJ))
! *** Check each vertex in current triangle
        DO II = 1, ncn2
! *** Choose current vertex
          CUVX = nen(II,JJ)
! *** Take other two vertices in turn
          DO LL = 1,ncn2
            IF(LL.eq.II) cycle
!            Choose current neighbour of chosen vertex 
            CUNBR = nen(LL,JJ)
!            Check if CUNBR is already in neighbour list of CUVX
            NEWNBR = .TRUE.
            IF(NONBRS(CUVX).ne.0) then
              DO MM = 1, NONBRS(CUVX)
                IF(CUNBR.eq.nbrs(MM,CUVX)) NEWNBR = .FALSE.
              enddo
            endif
!            If CUNBR is new neighbour of CUVX, add to list
            IF(NEWNBR) THEN     
              if(nonbrs(cuvx).ge.maxngh) then
                if(pass1) then
                  cstr =' Too many neighbor points - truncating:'
                    call PigMessageOK(cstr, 'Error')
                  pass1 = .false.
                endif
              else
                NONBRS(CUVX) = NONBRS(CUVX) + 1
                nbrs(NONBRS(CUVX),CUVX) = CUNBR
              endif
            ENDIF
          enddo
        enddo
      enddo

!       Find max number of neighbours
      numngh = maxval(nonbrs)

      RETURN
      END

! -------------------------------------------------------------------

      SUBROUTINE MERGE_GRID()

      use MainArrays

      IMPLICIT NONE

      INCLUDE '../includes/defaults.inc'

! *** Local variables ***
      character PigCursYesNo*1
      CHARACTER*80 ans, cstr
      INTEGER JJ, KK, LL
      REAL DIST, DISTMIN

      cstr= 'Merge coincident nodes ?:'
      ans = PigCursYesNo (cstr)
      if (ANS(1:1) .ne. 'Y') then
        return
      endif

      DO JJ = GridSIndex, itot !nrec   !1, NREC
        IF(CODE(JJ).ge.0) then
! *** Find suitable minimum radius around node JJ; for present,
! *** use one fifth of distance to nearest existing neighbour.
          DISTMIN = 1.E+20
          DO 203 LL = 1, NBTOT
            if(NL(LL,JJ).ne.0) then
              DIST = ABS(DXRAY(JJ)-DXRAY(NL(LL,JJ))) + ABS(DYRAY(JJ)-DYRAY(NL(LL,JJ)))
              IF (DIST.le.DISTMIN) DISTMIN = DIST
            endif
203       CONTINUE
          DISTMIN = DISTMIN/5
          DO KK = 1, GridSIndex-1 !NREC
            IF((KK.NE.JJ).and.(CODE(KK).ge.0)) then
! *** Check if KK close enough to JJ to merge
              DIST = ABS(DXRAY(JJ)-DXRAY(KK)) + ABS(DYRAY(JJ)-DYRAY(KK))
              IF (DIST.le.DISTMIN) THEN
! *** Merge nodes KK and JJ, treating result as JJ
                call Transparent( JJ, KK)
! *** Set computational code of node JJ to required value
                if(code(jj).eq.6.or.code(kk).eq.6) then
                  code(kk) = 1
                elseif(code(jj).eq.91.and.code(kk).eq.91) then
                  CODE(kk) = 0
                endif
                code(jj) = -9
              ENDIF
            ENDIF
          enddo
        ENDIF
      enddo

      return
      END

!*----------------------------------------------------------------------*
!       Routines for reading node data from file.                       *
!       ROUTINES: OpenNodeFile, ReadNodeFile                            *
!                 AddNodeFile, ReadAddNodeFile.                         *
!*----------------------------------------------------------------------*

      SUBROUTINE OpenNodeFile ( Quit )

!  PURPOSE:  To prompt user to enter a filename or "QUIT".
!    GIVEN:  NodeRName = 'NONE' if no current Node file.
!            User will input a filename.
!  RETURNS:  Quit - True if user choses to exit without opening file.
!  EFFECTS:  If specified file exists, ReadNodeFile is called to open
!            file on UNIT 3, else Quit will be true.
!*----------------------------------------------------------------------*

      implicit none      

      logical quit
!      integer nrec

!  - "INCLUDES"
      include '../includes/defaults.inc'

!  - LOCAL VARIABLES
      CHARACTER*256 FName
!      , ans
      CHARACTER*80 firstline
      integer Fnlen, nunit, istat,linenum
      logical PigOpenFileCD

! ----------------START ROUTINE------------------------------------------

      nunit = 3

      if(.not.PigOpenFileCD(nunit,'Open Node File', FName,&
             'Node Files (*.nod),*.nod;All Files (*.*),*.*;')) then
        quit = .true.
        NodeRName = 'NONE'
      else
        NodeRName = FName
        fnlen = len_trim( FName )
        call PigPutMessage('Reading file '//fName(:fnlen))

        READ(nunit,'(a)',IOSTAT=istat) Firstline
        linenum = 1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          close( nunit )
          return
        endif
        
        if(firstline(1:4).eq."#NOD") then  !node file, new format
          quit = .true.  !new format
          call ReadNodeFile ( Quit )
        elseif(firstline(1:4).eq."#GRD".or.firstline(1:4).eq."#NGH") then
          call PigMessageOK('ERROR: Grid file-wrong format','ReadNode' )
          quit = .true.
        else ! guess format
          Quit = .false.  !old format
          call ReadNodeFile ( Quit )
          if(quit) then
            rewind(nunit)
            call ReadXYZData(quit)
            if(quit) then
              close(nunit)
              return
            endif
          endif
        endif
        
        close(nunit)
        DispNodes = .true.

      ENDIF
      
      if(.not.Quit) call VerifyGridType(Quit)

      return
      END

!*-------------------------------------------------------------------------*

      SUBROUTINE ReadNodeFile ( Quit )

!  PURPOSE: To read NODE file data into memory arrays.
!    GIVEN: OpenNodeFile has specified an existing file, Fname, to open
!           and read.
!  RETURNS: dxray(),dyray() = arrays of coordinates of boundary and interior
!                             nodes with boundaries first,
!           depth() = array of depths at each node,
!           minx,miny = lower left NDC coordinate,
!           maxx,maxy = upper right NDC coordinate,
!  EFFECTS: Data from NODE file is in memory arrays in Common NODES
!           in NODESTOR.INC.
!  BUG: can read in and initialize arrays incorrectly if the external data
!       file is too large. It should truncate the read, setting all variables
!       appropriately.
!-----------------------------------------------------------------------*

      use MainArrays

! - "INCLUDES"
!      INCLUDE '../includes/cntcfg.inc'

! -  Only boundaries are displayed when OUTLINEONLY is .TRUE.
      LOGICAL OUTLINEONLY
      COMMON /OUTLINE/ OUTLINEONLY

! - LOCAL VARIABLES
      INTEGER start, end, ii, jj, idiff, jjmax, bcode
      integer linenum
      CHARACTER*80 cstr
      character(100)  firstline
      LOGICAL Quit
      REAL    XMAX, YMAX, XMIN, YMIN
      real xd, yd, dep, zsf
!       start,end - to mark indices of a set of boundary nodes or
!                   the set of interior nodes while reading
!       ii,jj - indices to increment from start to end
!       idiff - # nodes (if any) that have been excluded due to exceeding max
!               allowable nodes.

! -------------------START ROUTINE-----------------------------------

      x0off = 0.
      y0off = 0.
      scaleX = 1.
      scaleY = 1.
      start = 1
      end = 1
      outlineonly = .false.
      TotCoords = 0
      TotBndys = 0
      TotIntBndys = 0
      TotIntPts = 0
!      Quit = .TRUE.

!      READ(3,'(a)', err=990) Firstline

      if(Quit) then  !new node format
        linenum = 1
        do
          READ(3,'(a)',IOSTAT=istat) Firstline
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadNode' )
            Quit = .TRUE.
            return
          endif
          if(firstline(1:1).ne."#") then    !comment lines
            read(firstline,*,IOSTAT=istat)x0off,y0off,scaleX,scaleY,igridtype
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadNode' )
              Quit = .TRUE.
              return
            endif
            zsf = abs(scaleY)
            if(igridtype.eq.1) then ! UTM coordinates, get zone id
              j = len_trim(firstline)
              READ( firstline(j-2:j), '(a)', IOSTAT=istat ) UTMzone(1:3)
              if(istat.eq.0) read( UTMzone(1:2),*,IOSTAT=istat ) iUTMzone
              call VerifyUTMzone(istat,Quit)
              if(Quit) return 
            endif
            exit
          endif
        enddo
!       - read # of nodes total ( TotCoords )
        READ(3,*,IOSTAT=istat) TotCoords
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!       - read # of boundaries total ( TotBndys ) and number of internal lines
        READ(3,*,IOSTAT=istat) TotBndys, TotIntBndys
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
      else
        linenum = 1
        rewind(3)
!       - read # of nodes total ( TotCoords )
        READ(3,*,IOSTAT=istat) TotCoords
        if(istat.ne.0) then
!          write(message,'(a,i8,a)') 'ERROR reading line ',linenum
!          call PigMessageOK(message,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!       - read # of boundaries total ( TotBndys )
        READ(3,*,IOSTAT=istat) TotBndys
        linenum = linenum + 1
        if(istat.ne.0) then
!          write(message,'(a,i8,a)') 'ERROR reading line ',linenum
!          call PigMessageOK(message,'ReadNode' )
          Quit = .TRUE.
          return
        endif
        igridtype = -9999
      endif

      IF ( TotBndys .gt. Maxnnb ) THEN
        call PigMessageOK ( 'INPUT HAS TOO MANY BOUNDARIES','ReadNode' )
        TotBndys = Maxnnb
      ENDIF
      write(cstr,'(a,i7,a,i4,a)') 'Reading ',TotCoords,' nodes from ',TotBndys,' boundaries'
      call PigPutMessage(cstr)

!       - loop thru boundaries
      DO ii = 1, TotBndys
!         - read # nodes in each boundary ( ii )
        READ(3,*,IOSTAT=istat) PtsThisBnd(ii)
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!         - end = end of nodes on boundary ( ii )
        end = ( start - 1 ) + PtsThisBnd(ii)
!         - loop thru node coordinates for boundary ( ii )
!        write(cstr,'(a,i7,a,i4)') 'Reading ',PtsThisBnd(ii),' from boundary', ii
!        call PigPutMessage(cstr)
        if(ii.eq.1) then
          bcode = 1
        else
          bcode = 2
        endif

        DO jj = start, end
          read(3,*,IOSTAT=istat) xd,yd,dep
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadNode' )
            Quit = .TRUE.
            return
          endif
          jjmax = jj
          if(jj.le.MaxPts) then
            dxray(jj) = xd*scaleX
            dyray(jj) = yd*scaleX
            Depth(jj) = dep*zsf
            code(jj) = bcode    
          endif
        END DO
        IF ( end .gt. MaxPts ) THEN
          cstr = 'MODEL HAS TOO MANY NODES - Reading start of file'
          call PigMessageOK ( cstr,'ReadNode' )
          PtsThisBnd(ii) = MaxPts - start + 1
          end = start - 1 + PtsThisBnd(ii)
!          write(cstr,'(a,i7,a,i4)') 'PtsThisBnd reduced to ',PtsThisBnd(ii),' for boundary', ii
!          call PigMessageOK ( cstr,'ReadNode' )

        ENDIF
!         - start = beginning of next set of boundary nodes
        start = end + 1
      END DO
!       - if no boundaries were read, start = 1
      IF ( TotBndys .eq. 0 )  start = 1
!       - read interior points, if there are any
      IF ( TotCoords .gt. end ) THEN
!            - read # of non-boundary points ( TotIntPts )

        READ(3,*,IOSTAT=istat) TotIntPts
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!            - end = end of interior points
        end = start - 1 + TotIntPts
        IF ( end .gt. MaxPts ) THEN
          idiff = end - MaxPts
          call PigEraseMessage
          cstr = 'MODEL HAS TOO MANY POINTS'
          call PigMessageOK ( cstr,'ReadNode' )
          end = MaxPts
          TotIntPts = TotIntPts - idiff
        ENDIF
!            - loop thru interior nodes
        DO jj = start,end

!               - read interior nodes into arrays
          read(3,*,IOSTAT=istat) xd,yd,dep
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadNode' )
            Quit = .TRUE.
            return
          endif
          jjmax = jj
          if(jj.le.MaxPts) then
            dxray(jj) = xd*scaleX
            dyray(jj) = yd*scaleX
            Depth(jj) = dep*zsf
            !Exist(jj) = .true.
            Code(jj) = 0
          endif
        END DO
      ENDIF
!          - ( TotCoords .gt. end )
      
      scaleX = 1.
      if(scaleY.gt.0.) then
        scaleY = 1.
      else
        scaleY = -1.
      endif

      TotCoords = jjmax
      do ii=1,TotBndys
!        write(cstr,'(a,i7,a,i4)') 'PtsThisBnd is ',PtsThisBnd(ii),' for boundary', ii
!        call PigPutMessage(cstr)
      end do
      IF ( end .gt. MaxPts ) THEN
        cstr = 'TOO MANY DATA POINTS, DATAFILE TRUNCATED'
        call PigMessageOK ( cstr,'ReadNode' )
      ENDIF

!      ENDIF
      IF ( TotCoords .gt. MaxPts ) THEN
        cstr = 'INPUT HAS TOO MANY NODES'
        call PigMessageOK ( cstr,'ReadNode' )
        TotCoords = MaxPts
      ENDIF

!     - first condition is arbitrary lower bound here...
      if((TotCoords.lt.2000).or.(TotCoords.le.MaxPts/10 )) then
        outlineonly = .false.
      else
        outlineonly = .true.
      endif

      Quit = .false.
      itot = TotCoords
!      nrec = itot + 1
      nbtotr = 0

      ii = itot
      xmin = minval(dxray(1:itot))
      xmax = maxval(dxray(1:itot))
      ymin = minval(dyray(1:itot))
      ymax = maxval(dyray(1:itot))
      call fullsize(xmin,ymin,xmax,ymax)

      return

      END

!-----------------------------------------------------------------------*                                    *
!       This module contains routines for adding nodes from boundaries  *
!       and internal points.                                            *
!-----------------------------------------------------------------------*

      SUBROUTINE AddNodeFile( Quit)

! PURPOSE: To add together outer boundaries, internal boundaries,  
!          and internal points into a single file.
!   GIVEN: Initial data, if any;
! RETURNS: Added nodes in file
! EFFECTS: boundary and interior points from several node files are added 
!          together.
!----------------------------------------------------------------------*

      implicit none

! - PASSED VARIABLES
!        INTEGER nrec
        LOGICAL Quit

! - LOCAL VARIABLES
      integer readtype
      CHARACTER*256 nodfile
      CHARACTER*1 PigCursYesNo
      logical PigOpenFileCD
!------------------START ROUTINE---------------------------------------

!       - initialize defaults
      quit = .true.

!       - assign defaults
      nodfile = ' '

!      IF (PigCursYesNo ('Replace OUTER boundary?').EQ.'Y') THEN
!        if(.not.PigOpenFileCD(3,'Open NODE File', nodfile, &
!     &          'Node Files (*.nod),*.nod;All Files (*.*),*.*;')) then
!          close(unit=3, status='keep')
!        ELSE
!             -  file specified
!          Quit = .false.
!          readtype = 1
!          call ReadAddNodeFile ( readtype, nodfile, Quit )
!        ENDIF
!      endif

      IF (PigCursYesNo ('Add ISLAND boundary?').EQ.'Y') THEN
        if(.not.PigOpenFileCD(3,'Open NODE File', nodfile, &
     &          'Node Files (*.nod),*.nod;All Files (*.*),*.*;')) then
          close(unit=3, status='keep')
        ELSE
!             -  file specified
          Quit = .false.
          readtype = 2
          call ReadAddNodeFile ( readtype, nodfile, Quit )
        ENDIF
      endif

      IF (PigCursYesNo ('Add LINE CONSTRAINT?').EQ.'Y') THEN
        if(.not.PigOpenFileCD(3,'Open NODE File', nodfile, &
     &          'Node Files (*.nod),*.nod;All Files (*.*),*.*;')) then
          close(unit=3, status='keep')
        ELSE
!             -  file specified
          Quit = .false.
          readtype = 3
          call ReadAddNodeFile ( readtype, nodfile, Quit )
        ENDIF
      endif

      IF (PigCursYesNo ('Add INTERIOR nodes?').EQ.'Y') THEN
        if(.not.PigOpenFileCD(3,'Open NODE File', nodfile, &
     &          'Node Files (*.nod),*.nod;All Files (*.*),*.*;')) then
          close(unit=3, status='keep')
        ELSE
!             -  file specified
          Quit = .false.
          readtype = 4
          call ReadAddNodeFile ( readtype, nodfile, Quit )
        ENDIF
      endif

      return
      end

!*----------------------------------------------------------------------*

      SUBROUTINE ReadAddNodeFile ( readtype, FName, Quit )

!  PURPOSE: To read NODE file data into memory arrays.
!    GIVEN: OpenNodeFile has specified an existing file, Fname, to open
!           and read.
!  RETURNS: dxray(),dyray() = arrays of coordinates of boundary and interior
!                             nodes with boundaries first,
!           depth() = array of depths at each node,
!           minx,miny = lower left NDC coordinate,
!           maxx,maxy = upper right NDC coordinate,
!           coinrng = range for coincident nodes.
!  EFFECTS: Data from NODE file is in memory arrays in Common NODES
!           in NODESTOR.INC.
!-----------------------------------------------------------------------*

      use MainArrays

      implicit none

! - "INCLUDES"
      include '../includes/defaults.inc'

! - COMMON BLOCKS

! -  Only boundaries are displayed when OUTLINEONLY is .TRUE.
      LOGICAL OUTLINEONLY
      COMMON /OUTLINE/ OUTLINEONLY

! - LOCAL VARIABLES
      INTEGER start, end, start1,start2, linenum
      integer i, readtype, ii, jj, bcode, istat,nunit ! , nrec
      INTEGER TotCoords2, TotBndys2,  TotIntBndys2, PtsThisBnd2, TotIntpts2
      integer TotCoordsNew,bndindex
      integer StartIntPts
      CHARACTER*256 FName, cstr*80, message*80,Firstline*100
      character*1 ans, PigCursYesNo
      LOGICAL Quit
      real x2, y2, dep
! -------------------START ROUTINE-----------------------------------

      nunit = 3
      start = 1
      end = 1
      outlineonly = .false.
 
      if(TotCoords.le.0) then
        dispnodes = .true.
        x0off = 0.
        y0off = 0.
        scaleX = 1.
        scaleY = 1.
      endif

      Quit = .TRUE.

      OPEN ( nunit,  FILE = FName, STATUS = 'OLD' )

      READ(nunit,'(a)', IOSTAT=istat) Firstline
        linenum = 1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          close( nunit )
          return
        endif

      if(firstline(1:4).eq."#NOD") then  !new node format
        do
          READ(nunit,'(a)', IOSTAT=istat) Firstline
          linenum=linenum+1
          if(istat.ne.0) then
            call StatusError(istat,linenum,'ReadNode' )
            Quit = .TRUE.
            return
          endif
          if(firstline(1:1).ne."#") then    !comment lines
            read(firstline,*,IOSTAT=istat)x0off,y0off,scaleX,scaleY,igridtype
            if(istat.ne.0) then
              write(message,'(a,i8,a)') 'ERROR reading line ',linenum
              call PigMessageOK(message,'ReadGrid' )
              Quit = .TRUE.
              return
            endif
!XXX     !NOTE check if grid is of the same type
            exit
          endif
        enddo
!       - read # of nodes total ( TotCoords )
        READ(nunit,*,IOSTAT=istat) TotCoords2
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!       - read # of boundaries total ( TotBndys ) and number of internal lines
        READ(nunit,*,IOSTAT=istat) TotBndys2, TotIntBndys2
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif

      elseif(firstline(1:1).eq."#") then  !wrong format
        call PigMessageOK( 'Wrong format for node file.','ReadNode' )
        Quit = .true.
        Return

      else
!       - read # of nodes total ( TotCoords )
        READ(firstline,*,IOSTAT=istat) TotCoords2
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!       - read # of boundaries total ( TotBndys )
        READ(nunit,*,IOSTAT=istat) TotBndys2
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
        TotIntBndys2 = 0
      endif
      
!       - calculate index to start adding
      if(readtype.eq.2) then
        bndindex = sum(PtsThisBnd((TotBndys-TotIntBndys+1):TotBndys))
      endif

!       - loop thru boundaries
      DO ii = 1, TotBndys2
!       - read # nodes in each boundary ( ii )
        READ(nunit,*,IOSTAT=istat) PtsThisBnd2
        linenum=linenum+1
        if(istat.ne.0) then
          call StatusError(istat,linenum,'ReadNode' )
          Quit = .TRUE.
          return
        endif
!       - end = end of nodes on boundary ( ii )
        end = ( start - 1 ) + PtsThisBnd2
!       - loop thru node coordinates for boundary ( ii )
        bcode = 2

        IF ( TotCoords+PtsThisBnd2 .ge. MaxPts ) THEN
          cstr = 'TOO MANY NODES TO ADD - aborting'
          call PigMessageOK ( cstr,'addnode' )
          return
        ENDIF

        if(readtype.eq.2.or.(readtype.eq.3.and.ii.gt.(TotBndys2-TotIntBndys2))) then  !(bndtest).or.(islon)) then
          TotCoordsNew = TotCoords
          DO jj = start, end
            read(nunit,*,IOSTAT=istat) x2,y2,dep
            linenum=linenum+1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadNode' )
              Quit = .TRUE.
              return
            endif
            call PigDrawModifySymbol(x2, y2)
            TotCoordsNew = TotCoordsNew + 1    
            if(jj.le.MaxPts) then
              dxray(TotCoordsNew) = x2
              dyray(TotCoordsNew) = y2
              Depth(TotCoordsNew) = dep
              !Exist(TotCoordsNew) = .true.
              code(TotCoordsNew) = bcode
            endif
          END DO

!         - Ask if they are to be kept
!          if(readtype.eq.2.or.(readtype.eq.3.and.ii.gt.(TotBndys2-TotIntBndys2))) then  !(bndtest).or.(islon)) then
            if(readtype.eq.2) then
              cstr = 'Are new island nodes OK?:'
              ans = PigCursYesNo (cstr)
            elseif(readtype.eq.3) then
              cstr = 'Are line constraint nodes OK?:'
              ans = PigCursYesNo (cstr)
            endif

            IF ( ans(1:1) .eq. 'Y' ) THEN
!           - save new nodes
!           - redraw nodes in boundary color
              start2 = TotCoords + 1
              DO jj = start2, TotCoordsNew
                x2 = dxray(jj)
                y2 = dyray(jj)
                call PigDrawBndSymbol(x2, y2)
              END DO

              if(readtype.eq.2) then
                start1 = TotCoords - bndindex - TotIntPts + 1
                TotCoords = start1 + PtsThisBnd2 -1
                dxray(start1:TotCoords) = dxray(start2:TotCoordsNew)
                dyray(start1:TotCoords) = dyray(start2:TotCoordsNew)
                Depth(start1:TotCoords) = Depth(start2:TotCoordsNew)
                code(start1:TotCoords)  = code(start2:TotCoordsNew)
                TotBndys = TotBndys - TotIntBndys + 1
                PtsThisBnd(TotBndys) =  PtsThisBnd2
                bndindex = 0
                TotIntBndys = 0
                TotIntPts = 0
              elseif(readtype.eq.3) then
                start1 = TotCoords - TotIntPts + 1
                TotCoords = TotCoords - TotIntPts + PtsThisBnd2
                dxray(start1:TotCoords) = dxray(start2:TotCoordsNew)
                dyray(start1:TotCoords) = dyray(start2:TotCoordsNew)
                Depth(start1:TotCoords) = Depth(start2:TotCoordsNew)
                code(start1:TotCoords)  = code(start2:TotCoordsNew)
                TotBndys = TotBndys + 1
                PtsThisBnd(TotBndys) =  PtsThisBnd2
                TotIntBndys = TotIntBndys + 1
                TotIntPts = 0
              endif
            ELSE
!           - do not save new nodes, leave as is
!           - redraw nodes in background color
              start2 = TotCoords + 1
              DO i = start2, TotCoordsNew
                x2 = dxray(i)
                y2 = dyray(i)
                call PigEraseModifySymbol(x2, y2)
              END DO
            ENDIF
!           - ( ans = Y )
          !endif
        else  !skip nodes
          DO jj = start, end
            read(nunit,*,IOSTAT=istat)
            linenum=linenum+1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadNode' )
              Quit = .TRUE.
              return
            endif
          enddo
        endif
!         - start = beginning of next set of boundary nodes
        start = end + 1
      END DO

! - load existing internal nodes
      IF ( TotBndys2 .eq. 0 )  start = 1
      if(readtype.eq.4) then
!       - read interior points, if there are any
        IF ( TotCoords2 .gt. end ) THEN
          StartIntPts = TotCoords+1
          READ(nunit,*,IOSTAT=istat) TotIntPts2
            linenum=linenum+1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadNode' )
              Quit = .TRUE.
              return
            endif
          end = start - 1 + TotIntPts2
          IF ( end .gt. MaxPts ) THEN
            cstr = 'TOO MANY INTERNAL NODES TO ADD - aborting'
            call PigMessageOK ( cstr,'addnode' )
            close(nunit)
            return
          ENDIF

          do jj = start,end
!               - read interior nodes into arrays
            read(nunit,*,IOSTAT=istat) x2,y2,dep
            linenum=linenum+1
            if(istat.ne.0) then
              call StatusError(istat,linenum,'ReadNode' )
              Quit = .TRUE.
              return
            endif

            TotCoords = TotCoords + 1
            TotIntPts = TotIntPts + 1
            if(jj.le.MaxPts) then
              dxray(TotCoords) = x2
              dyray(TotCoords) = y2
              Depth(TotCoords) = dep
              !Exist(TotCoords) = .true.
              Code(TotCoords) = 0
              call PigDrawModifySymbol(x2, y2)
            endif
          END DO
! - prompt
!         - Ask if they are to be kept
          cstr = 'Are new nodes OK?:'
          ans = PigCursYesNo (cstr)
          call PigEraseMessage
          IF ( ans(1:1) .eq. 'Y' ) THEN
!           - save new nodes
!           - redraw nodes in interior color
            DO i = 1, StartIntPts, TotCoords
              x2 = dxray(i)
              y2 = dyray(i)
              call PigDrawIntSymbol(x2, y2)
            END DO
          ELSE
!           - do not save new nodes
!           - redraw nodes in background color
            DO i = StartIntPts, TotCoords
              x2 = dxray(i)
              y2 = dyray(i)
              call PigEraseModifySymbol(x2, y2)
            END DO
              TotCoords = StartIntPts - 1
              TotIntPts = TotIntPts - TotIntPts2
          ENDIF
!           - ( ans = Y )
          call PigEraseMessage
        endif
!          - ( TotCoords .gt. end )
      ENDIF
!            - (  inton  )

!     - first condition is arbitrary lower bound here...
      if(TotCoords.lt.2000) then
        outlineonly = .false.
      else
        outlineonly = .true.
      endif

      close(nunit)
      Quit = .false.
      itot = TotCoords
!      nrec = itot + 1
      nbtotr = 0
      return

      END subroutine

!--------------------END ADDNODE ---------------------------------------*
! --------------------------------------------------------------------------*

      SUBROUTINE ReadXYZData (quit)
   
! Purpose : To read grid data into memory

      use MainArrays

      INCLUDE '../includes/defaults.inc'
!      INCLUDE '../includes/cntcfg.inc'

!     - PASSED VARIABLES
      LOGICAL Quit

      REAL    XMAX, YMAX, XMIN, YMIN

!     - LOCAL VARIABLES
      INTEGER i, linenum 
!        - counters
      INTEGER   istat
!        - the number of records that is to be in the data file
      INTEGER numrec

!------------------BEGIN-------------------------------

      QUIT = .FALSE.
      
      numrec = 0
      i = 1
      linenum = 1
      read(3,*,IOSTAT=istat) dxray(i),dyray(i),depth(i)
      if(istat.ne.0) then
        call StatusError(istat,linenum,'Read_XYZ' )
        Quit = .TRUE.
        close( 3 )
        return
      endif
      
      i = 2

      do 
        read(3,*,IOSTAT=istat) dxray(i),dyray(i),depth(i)
        if(istat.lt.0) then
!          call PigMessageOK('ERROR premature end of file','ReadXYZ' )
          Quit = .false.
          exit
        elseif(istat.gt.0) then
          call PigMessageOK('ERROR reading XYZ file: Most likely a format error','ReadXYZ' )
          Quit = .TRUE.
          return
        endif
        i = i + 1
        numrec = numrec + 1
      enddo

      code(1:numrec) = 1   
      itot = numrec
      TotTr = 0

      TotCoords = numrec
      TotBndys = 0
      TotIntBndys = 0
      PtsThisBnd = 0
      TotIntPts = TotCoords
      DispNodes = .true.
      igridtype = -9999

!      if(int(ScaleY).eq.-999) then
!        xlongmin = minval(dxray(1:itot))
!        xlongmax = maxval(dxray(1:itot))
!        xlongsum=ScaleX
!      endif

      xmin = minval(dxray(1:itot))
      xmax = maxval(dxray(1:itot))
      ymin = minval(dyray(1:itot))
      ymax = maxval(dyray(1:itot))
      call fullsize(xmin,ymin,xmax,ymax)

      return
      END


!-----------------------------------------------------------------------*
!-----------------------------------------------------------------------*

      SUBROUTINE StatusError( istat,linenum,cfile )

! Purpose: Display errors from reading files.

      implicit none
      
!  Passed variables
      integer istat,linenum,ilen
      character*8 cfile
      character*80 message
      
      ilen = len_trim(cfile)
      
      if(istat.lt.0) then
        write(message,'(a,i8,a)') 'ERROR: end of file at line ',linenum
        call PigMessageOK(message,cfile(:ilen) )
      elseif(istat.gt.0) then
        write(message,'(a,i8,a)') 'ERROR: reading line ',linenum
        call PigMessageOK(message,cfile(:ilen) )
      endif

      end subroutine
!-----------------------------------------------------------------------*
