
/****************************************************************************
**
** Description:
**    Project:
**       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
**
**    Create new index on ERM table.  Column LOAD_NO
**    Average number of records about 10,000
**
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    07/18/16 bben0556 Brian Bent
**                      Project:
**          R30.6--WIE#669--CRQ000000008118_Live_receiving_story_11_rcv_load_worksheet
**
**                      Created.
**
**
****************************************************************************/

CREATE INDEX swms.i_erm_load_no ON swms.erm(load_no)
   TABLESPACE SWMS_ITS1
   STORAGE (INITIAL 128K NEXT 64K PCTINCREASE 0)
   PCTFREE 1
/


