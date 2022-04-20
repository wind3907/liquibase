
/****************************************************************************
**
** Description:
**    Project:
**       R30.6--WIE#669--CRQ000000008118_Live_receiving_story_276_lock_records_when_finding_putaway_dest_loc
**       
**    Create table PROCESS_LOCK to use in process locking.
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


--------------------------------------------------------------------------
-- Create the PROCESS_LOCK table but only if it does not exist.
--------------------------------------------------------------------------
DECLARE
   l_count NUMBER;
BEGIN
   SELECT count(*) INTO l_count
     FROM DBA_TABLES
    WHERE owner = 'SWMS'
      AND table_name = 'PROCESS_LOCK';

   IF (l_count = 0) THEN
     EXECUTE IMMEDIATE
    'CREATE TABLE swms.process_lock
     (
        process_name    VARCHAR2(50)                                  NOT NULL,
        add_date        DATE         DEFAULT SYSDATE                  NOT NULL,
        add_user        VARCHAR2(30) DEFAULT REPLACE(USER, ''OPS$'')  NOT NULL,
        CONSTRAINT process_lock_pk PRIMARY KEY (process_name)
            USING INDEX TABLESPACE swms_its1
            STORAGE (INITIAL 16K NEXT 16K PCTINCREASE 0)
            PCTFREE 5
     )
        TABLESPACE swms_dts1
        STORAGE (INITIAL 16K NEXT 16K PCTINCREASE 0)
        PCTFREE 5';
   END IF;
END;
/

GRANT ALL    ON swms.process_lock to swms_user;
GRANT SELECT ON swms.process_lock to swms_viewer;

GRANT ALL ON swms.process_lock TO swms_user;

CREATE OR REPLACE PUBLIC SYNONYM process_lock FOR swms.process_lock;

