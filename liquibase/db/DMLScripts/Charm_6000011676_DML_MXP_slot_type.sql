/****************************************************************************
** Date:       20-JAN-2016
** Programmer: Brian Bent
** File:       xxxx
** Defect#:    xxx
** Ticket:     xxx
** Project:    R30.4--WIE#615--Charm6000011676_Symbotic_Throttling_enhancement
** 
** This script insert a new slot type called MXP.
**
** The MXP slots are slots in the main warehouse with slot type MXP where
** matrix items are put because the case(s) could not be inducted onto the
** matrix because of tolerance issues.  The rule is these get allocated
** to orders first.  There will be no replenishments from MXP slots to the
** matrix for matrix items.  If for whatever reason non matrix items have
** inventory in MXP slots then the MXP slots are treated like normal
** slots.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    01/20/15 bben0556 Brian Bent
**                      Created.
**
****************************************************************************/


INSERT INTO slot_type
(
   slot_type,
   descrip,
   deep_ind,
   deep_positions,
   calculate_loc_heights_flag
)
SELECT 'MXP',
       'MATRIX--OP ALLOCATE FIRST',
       'N',
       1,
       'Y'
  FROM DUAL
 WHERE 'MXP' NOT IN
          (SELECT st2.slot_type FROM slot_type st2)
/
   

