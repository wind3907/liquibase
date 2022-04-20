
/****************************************************************************
**
** Description:
**    Project:
**       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
**
**    Insert record into PROCESS_LOCK table.
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    02/17/17 bben0556 Brian Bent
**                      Created for Live Receiving.
**                      Package pl_rcv_open_po_find_slot modified to lock the
**                      "find slot" processing when starting the process of
**                      finding slots for a PO/SN or LP.  This locking needed
**                      for Live Receiving since different Receivers can be
**                      find putaway slots at the same time for different LP's.
**
****************************************************************************/

--
-- Insert record used in the the locking of putaway find slot processing
-- but only if the record does not exist.
--
INSERT INTO process_lock(process_name)
SELECT 'FIND_PUTAWAY_SLOT'
  FROM DUAL
 WHERE NOT EXISTS
       (SELECT 1 FROM process_lock WHERE process_name = 'FIND_PUTAWAY_SLOT')
/

COMMIT;


