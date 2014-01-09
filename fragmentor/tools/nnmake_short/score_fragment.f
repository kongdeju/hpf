c -*- mode: fortran; -*-
c  CVS information:
c  $Revision: 1.10 $
c  $Date: 2002/06/18 04:41:53 $
c  $Author: rohl $

c     this section of scoring functions has been separated into
c     distinct functions for clarity however many of these very short
c     and are called in tight loops so this is not the best way of doing
c     this.  Thus it is advisable to take advantage of inlining and
c     unrolling by including routines that call these functions in this
c     same physical file.


      subroutine  all_score(i,j,isize,seq_score,ss_scores,
     #     proline_phi_score,bad)
      implicit none
c---------------------------------------------------------
c     MATCH SEGMENTS TO PROFILE
c---------------------------------------------------------
      include 'structure.h'

c parameters
c$$$      integer pCHSFT,pNOE,pDIPOLAR
c$$$      parameter (pCHSFT=1,pNOE=2,pDIPOLAR=3)

car input
      integer i                 !starting position in query
      integer j                 !starting frag residue from vall
      integer isize              !size of window or fragment

car internal
      real seq_score
      real proline_phi_score
      logical bad,chain_break,cis
      real ss_scores(max_ss_type)

car function calls
      real score_proline_phi
      real score_seq

car from cems nnmake_noe_chsft

car chsft_weight
car weight=0.05 in setup, *3*3=.45 in main,
car in find_nn its *3*3*3 for size=2 (5mers)  (ie weight=12.15)
car seq_weight:car  set to 1 in setup, left there
cems: 5/23/2002 added template proline cis test and query proline phi score.

c---------------------------------------------------------

      bad = .true.
      
      call score_chain_break(isize,phi_list(j),chain_break)
      if (chain_break) then
c     write(0,*) 'chain break',i,j,phi_list(j),isize
         return
      endif

      if (i+isize-1.eq.total_residue) then !cis frags allowed in final position
	                                   !this might be bad for loop mode...
         call score_cis_omega(isize-1,omega_list(j),seq(i),cis)
      else
         call score_cis_omega(isize,omega_list(j),seq(i),cis)
      endif
      if (cis) then
c     write(0,*) 'bad cis',j,omega_list(j)
         return
      endif

      bad = .false.
      
      proline_phi_score = score_proline_phi(isize,phi_list(j),seq(i))

      seq_score= score_seq(isize,vall_pro(0,j),profile(0,i))

      call score_ss(i,j,isize,ss_scores) ! ss_scores is an array
             ! sort of dumb: we score all but only use one of them

c     write(0,*) "all_score",i,j,isize
c     write(0,*) seq_score,ss_scores,proline_phi_score
      
      return
      end
c-----------------------------------------------------------------------

      real function score_fragment(i,j,size,ss_type)
cems legacy function; still used by makeoutput and zscore_dme to calc
cems scores to write in fragment files
      implicit none
c---------------------------------------------------------
c     MATCH SEGMENTS TO PROFILE
c---------------------------------------------------------
      include 'structure.h'
c      include 'nmr_pred.h'

car input
      integer i                 !starting position in query
      integer j                 !starting frag residue from vall
      integer size              !size of window or fragment
      integer ss_type           !code indicating scoring method, see below

car internal

      real seq_score,ss_score
      real proline_phi_score
      logical bad,chain_break,cis
      integer isize
      real ss_scores(max_ss_type)


car function calls
      real score_proline_phi
      real score_seq

      isize = size+1            ! remove stooopid size-1
      score_fragment=99999.9E10 ! flag for abnormal loop end
      seq_score=0.0
                                ! solv_score=0.0
      ss_score = 0.0
      
      proline_phi_score = 0.0
      bad = .true.
      
      call score_chain_break(isize,phi_list(j),chain_break)
      if (chain_break) return
        
      if (i+size.eq.total_residue) then !cis frags allowed in final position
                                ! this might be bad for loop mode...
         call score_cis_omega(size,omega_list(j),seq(i),cis)
      else
         call score_cis_omega(isize,omega_list(j),seq(i),cis)
      endif
      if (cis) return

      bad = .false.
      score_fragment =0.0
      proline_phi_score = score_proline_phi(isize,phi_list(j),seq(i))
      
      seq_score=score_seq(isize,vall_pro(0,j),profile(0,i))
      
      call score_ss(i,j,isize,ss_scores) ! ss_scores is an array
           ! sort of dumb: we score all but only use one of them
c phd
      if (ss_type.eq.phd_type) then
         ss_score = ss_scores(phd_type)
c jones
      elseif (ss_type.eq.jones_type) then
         ss_score = ss_scores(jones_type)
c rdb
      elseif (ss_type.eq.rdb_type) then
         ss_score = ss_scores(rdb_type)
c jufo
      elseif (ss_type.eq.jufo_type) then
         ss_score = ss_scores(jufo_type)
c helix
      elseif (ss_type.eq.helix_type) then
         ss_score = ss_scores(helix_type)
c sheet
      elseif (ss_type.eq.sheet_type) then
         ss_score = ss_scores(sheet_type)
c loop
      elseif (ss_type.eq.loop_type) then
         ss_score = ss_scores(loop_type)
c nmr
      elseif (ss_type.eq.nmr_type) then
         ss_score = ss_scores(nmr_type)
      endif

      score_fragment=score_fragment+seq_score*seq_weight
      score_fragment=score_fragment+ss_score*ss_weight
      score_fragment=score_fragment+proline_phi_score*weight_proline_phi 
      return
      end
c-----------------------------------------------------------------

      subroutine score_chain_break(isize,phi,chain_break)
      implicit none
                                ! input
      integer isize		! real size
      real phi(isize)		! list of phi's starting with insert position in vall
                                ! ouput
      logical chain_break
                                ! local
      integer k

      if (isize.eq.3) then	! allows unroll_loops in compiler to detect common case
         do k = 1,3
            if (phi(k).eq.0.0) then
               
               chain_break =.true.
               return		! chain break detected
            endif
         enddo
      else
         do k = 1,isize
            if (phi(k).eq.0.0) then
               
               chain_break =.true.
               return		! chain break detected
            endif
         enddo
      endif
      chain_break = .false.
      return
      end
      
c-----------------------------------------------------------------

      function score_seq(isize,vall,prof)
      implicit none
c     sequence alignment (seq_score)

c output
      real score_seq
c  input
      integer isize	!actual size of the fragment not the bullshit size-1
      real vall(0:20,isize),prof(0:21,isize)

c local
      integer k,aa
      score_seq=0.0
      do k=1,isize
         do aa=1,20
            score_seq = score_seq +abs(vall(aa,k)-prof(aa,k))
         enddo
        
      enddo
      
      return
      end
      
c-----------------------------------------------------------------
      
      subroutine score_ss(i,j,isize,ss_scores)
      implicit none
      include 'structure.h'
c input
      integer i                 ! insert position in query
      integer j                 ! insert position is template vall
      integer isize		! real size of fragment (not bullshit size-1)

c output
      real ss_scores(max_ss_type)
c local
      integer k
      real pure_score
      
      ss_scores(jones_type) = 0.0
      ss_scores(phd_type) = 0.0
      ss_scores(rdb_type) = 0.0
      pure_score =0.0
      ss_scores(jufo_type) = 0.0
      ss_scores(helix_type) = 10000.
      ss_scores(sheet_type) = 10000.
      ss_scores(loop_type)  = 10000.
        
      if (isize.eq.3) then	! allows unroll-loops to work for common case.
         do k = 0,2
            if (ss(j+k).eq.'H') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdH(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonH(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbH(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufoH(i+k)
               pure_score = pure_score  -rel_aveH(i+k)
               
            elseif(ss(j+k).eq.'E') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdE(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonE(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbE(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufoE(i+k)
               pure_score = pure_score  -rel_aveE(i+k)
               
            elseif (ss(j+k).eq.'L') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdL(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonL(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbL(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufol(i+k)
               pure_score = pure_score  -rel_aveL(i+k)
               
            endif
	 enddo
      else
         do k = 0,isize-1
            
            if (ss(j+k).eq.'H') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdH(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonH(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbH(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufoH(i+k)
               pure_score = pure_score  -rel_aveH(i+k)
            elseif(ss(j+k).eq.'E') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdE(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonE(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbE(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufoE(i+k)
               pure_score = pure_score  -rel_aveE(i+k)
            elseif (ss(j+k).eq.'L') then
               ss_scores(phd_type) = ss_scores(phd_type) -rel_phdL(i+k)
               ss_scores(jones_type) = ss_scores(jones_type) -rel_jonL(i+k)
               ss_scores(rdb_type) = ss_scores(rdb_type) -rel_rdbL(i+k)
               ss_scores(jufo_type) = ss_scores(jufo_type) -rel_jufol(i+k)
               pure_score = pure_score  -rel_aveL(i+k)
            endif
         enddo
      endif
      
      if (ss(j+(isize-1)/2).eq.'H') then
         ss_scores(helix_type) = pure_score
      elseif (ss(j+(isize-1)/2).eq.'E') then
         ss_scores(sheet_type) = pure_score
      elseif (ss(j+(isize-1)/2).eq.'L') then
         ss_scores(loop_type) = pure_score
      endif

      call score_nmr(i,j,isize,ss_scores(nmr_type))
      
      return
      
      end
c---------------------------------------------------------------------------

      subroutine score_cis_omega(isize,omega,seq,cis)
      implicit none

c     warning this routine reads expects seq(isize+1) to be a valid
c    1ubq_.dpl  array position thus you should call this subroutine in a fashion
c     to make sure this is true.  for example: score_cis_omega(
c     min(9,total_residue-i+1),omega_list(j),seq(i),cis) returns true if
c     bad cis bond detected.

c     cis proline in template test (cems)

c input
      integer isize		! real size of fragnemt

      real omega(isize)         ! list of angles starting at insert position
      character*1 seq(isize+1)  ! list of residues starting at insert position
c output
      logical cis

c local 
      integer k
      
      if (isize.eq.3) then	! allows unroll-loops to work in compiler
         do k=1,3
            if (abs(omega(k)).lt.90.0 ) then ! template has a cis-omega Pro
               if (seq(k+1).ne.'P')  then ! query not a proline in next residue
                  cis =.true.
                  return	! bad cis detected                  
               endif
            endif
         enddo
      else
         do k=1,isize
            if (abs(omega(k)).lt.90.0 ) then 
               if (seq(k+1).ne.'P')  then 
                  cis =.true.
                  return	
               endif
            endif
         enddo
      endif
C  have to do k=size by hand due to end-of-array issue
      
      cis =.false.
      return
      end
c---------------------------------------------------------------------------
      
      function score_proline_phi(isize,phi,seq)
      implicit none
c tests angle of prolines
c prolines have a restricted range of probable phi values
	
c input
      integer isize		! real size of fragnemt
      real phi(isize)
      character*1 seq(isize)
c output
      real score_proline_phi
                                ! function call
      real proline_log_prob
c local
      integer k
      score_proline_phi=0.0
      if (isize.eq.3) then	! test for compiler unroll loops in common case
         do k=1,3
            if (seq(k).eq.'P') then ! query has a proline
               score_proline_phi= score_proline_phi+proline_log_prob(phi(k))
            endif
         enddo
      else
         do k=1,isize
            if (seq(k).eq.'P') then ! query has a proline
               score_proline_phi= score_proline_phi+proline_log_prob(phi(k))
            endif
         enddo
      endif
      
      return
      end
	
c---------------------------------------------------------------------------
      subroutine score_nmr(i,j,isize,nmr_score)
      implicit none
      include 'structure.h'
      include 'nmr_pred.h'
c score noe and dipolar coupling and chsft
car note that this routine doesnt do anything if there is no nmr data
car there are however, null functions calls that return zero

c input
      integer i                 ! query insert position
      integer j                 ! template vall insert position
      integer isize
c output
      real nmr_score

c local
      integer k
      real dummy1,dummy2
      real noe_score,dipolar_score,chsft_score
c function      
      real test_frag_noe
      real retrieve_frag_dipolar_score

      nmr_score=0.0

c     chemical shift-derived score (chsft_score) zero if no info    
      chsft_score=0
      if (chsft_exist) then
         if (isize.eq.3) then	! optimize compile for unroll_loops
            do k =0,2  
               if (phivarprd(i+k).ne.0.0) then   
                  dummy1 = abs(averphi(k+i)-phi_list(k+j))
                  dummy2 = abs(averpsi(k+i)-psi_list(k+j))
                  if (dummy1.gt.180.0) dummy1 = 360.0-dummy1 !keep ang in range
                  if (dummy2.gt.180.0) dummy2 = 360.0-dummy2
                  chsft_score = chsft_score+log_mean_phi_err(i+k) 
     $                 +dummy1*phivarprd(i+k)
                  chsft_score = chsft_score+log_mean_psi_err(i+k) 
     $                 +dummy2*psivarprd(i+k)      
               endif		! phivard ok 
            enddo   
         else
            do k =0,isize-1  
               if (phivarprd(i+k).ne.0.0) then   
                  dummy1 = abs(averphi(k+i)-phi_list(k+j))
                  dummy2 = abs(averpsi(k+i)-psi_list(k+j))
                  if (dummy1.gt.180.0) dummy1 = 360.0-dummy1 !keep ang in range
                  if (dummy2.gt.180.0) dummy2 = 360.0-dummy2
                  chsft_score = chsft_score+log_mean_phi_err(i+k) 
     $              +dummy1*phivarprd(i+k)
                  chsft_score = chsft_score+log_mean_psi_err(i+k) 
     $                 +dummy2*psivarprd(i+k)      
               endif		! phivard ok 
            enddo   
         endif
      endif

	
      noe_score = 10*(test_frag_noe(j))
      if (noe_score.gt.2.0) noe_score=5000.0+10*test_frag_noe(j) 
      dipolar_score=retrieve_frag_dipolar_score(j)

      nmr_score= chsft_score*chsft_weight +noe_score+dipolar_score

car nmr_score is in the ss_score array, so ss_weight will be applied
car here we divide by ss_weight to remove this effect
      nmr_score = nmr_score/ss_weight 
      
      return
      end
      
c-----------------------------------------------------------------
      function proline_log_prob(phi)
      real proline_log_prob,phi
cems  phi frequency distribution fitted piecewise by Bill Wedemeyer
      
cems called when comparing a query proline residue to any template entry 
cems in the vall which is not also a proline.
	
cems pass in the phi angle of the residues you want to compare
cems returns the negaitve log prob of this match
cems thus more positive == worse
cems note log is log base E not log base 10

cems modification: shifted by 1.636 log units to make peak score equal to zero
cems     Zero level has subtle effect and peak should always be set to zero 
cems     because score_frag automatically gives a score of zero if the query 
cems     and template both have prolines.
	
      if (phi.le. -120 .or. phi.ge.-10) then 
         proline_log_prob = 20.0 ! not possible!  give it a very bad score
         return
      endif
      if (phi .lt.-59.0) then
         proline_log_prob= 1.61559 + 0.00197753 * (phi + 55.7777)**2
      else
         proline_log_prob= 7.71788 
     #        -0.282087*phi 
     #        -0.0133411*phi**2 
     #        -0.000115456*phi**3
      endif
      proline_log_prob = proline_log_prob-1.636
      return
      end