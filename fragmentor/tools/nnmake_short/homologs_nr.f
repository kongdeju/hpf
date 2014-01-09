c -*- mode: fortran; -*-
c  CVS information:
c  $Revision: 1.4 $
c  $Date: 2002/07/25 00:47:08 $
c  $Author: rohl $

      subroutine homologs_nr
      implicit none 
      include 'path_defs.h'
c---------------------------------------------------------------------
      include 'structure.h' 
      character ch1*1,ch2*1,prot1*4,prot2*4  

      integer i,j,new,damn   
c---------------------------------------------------------------------
c look in two places then die if cant find it
      if (chain_letter.eq.' ') chain_letter='_' 
      num_homologs=1 
      homolog_id(num_homologs)=lower_name 
      homolog_ch(num_homologs)=chain_letter 
      write(0,*) "read homolog 18 ",homolog_path(1:homolog_l)//
     # lower_name//chain_letter//'.'//'homolog_nr'
       open(18,file= homolog_path(1:homolog_l)//
     # lower_name//chain_letter//'.'//'homolog_nr',
     # status='old',iostat=damn)

  
        if (damn.ne.0) then
 
	write(0,*) " DAMN",damn,"************** cant find homolog-nr double check file (PAUSED) "
        return
       endif

      do while(num_homologs.lt.max_homologs)
         read(18,'(2(a4,a1,1x))',end=51)prot1,ch1,prot2,ch2 

car 0 _ and space  all indicate no chain
car convert all to _ which is used in the vall
         if (ch1.eq.'0') ch1='_'
         if (ch1.eq.' ') ch1='_'
         if (ch2.eq.'0') ch2='_'
         if (ch2.eq.' ') ch2='_'

         if ((prot1.eq.lower_name.and.ch1.eq.chain_letter).or.      
     #        (prot2.eq.lower_name.and.ch2.eq.chain_letter)) then 
            new=1 
            do j=1,num_homologs 
               if (homolog_id(j).eq.prot1.and.
     #             homolog_ch(j).eq.ch1) new=0    
            enddo 
            if (new.eq.1) then 
               num_homologs=num_homologs+1 
               homolog_id(num_homologs)=prot1 
               homolog_ch(num_homologs)=ch1 
            endif 
            new=1 
            do j=1,num_homologs 
               if (homolog_id(j).eq.prot2.and.
     #             homolog_ch(j).eq.ch2) new=0    
            enddo 
            if (new.eq.1) then 
               num_homologs=num_homologs+1 
               homolog_id(num_homologs)=prot2 
               homolog_ch(num_homologs)=ch2 
            endif 
         endif 
      enddo
 51   continue
      close(18)
      if (num_homologs.eq.max_homologs) then 
         write(60,*)'not enough homologs space' 
         stop 
      endif 

      if (num_homologs.eq.0) return 
      write(60,*)'      nr -- removing ',num_homologs,' proteins' 
      do i=1,num_homologs   
         write(60,*)'nr -- should remove: ',homolog_id(i),homolog_ch(i)  
c         if (homolog_ch(i).eq.'_') homolog_ch(i)=' ' 
         new=0 
         do j=1,vall_size 
  
            if (frag_name(j).eq.homolog_id(i).and. 
     #          chain(j).eq.homolog_ch(i)) then 
               new=1 
               phi_list(j)=0.0 
               psi_list(j)=0.0 
            endif 
 

         enddo 
         if (new.eq.1) then  
            write(60,*)'nr -- does remove: ',homolog_id(i),homolog_ch(i)    
         endif 
      enddo 

 100  format(a8)
 200  format(3x,a4,a1,1x,a4,a1)  
      return 
      end 
