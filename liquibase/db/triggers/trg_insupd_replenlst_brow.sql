/* 23-OCT-2001 prpksn:initial version */
/* This trigger will use the LOC_REFERENCE table and convert  the front */
/* location to the back location */

------------------------------------------------------------------------------
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    02/03/02 prpbcb   rs239a DN NA
--                      rs239b DN 11062
--                      RDC non-dependent changes.
--                      Added assignment to upd_date and upd_user when updating.
--                      Added exception handler.
--                      Changed
--            BEFORE INSERT OR UPDATE of dest_loc ON replenlst for each row
--                      to
--            BEFORE INSERT OR UPDATE  ON replenlst for each row
--                      so the trigger executes each time.  The dest_loc logic
--                      was moved to an if statement.
--
--    04-JUN-2021 pkab6563 - Jira 3492 - Do not switch to back loc for SWAP.
------------------------------------------------------------------------------

create or replace trigger swms.trg_insupd_replenlst_brow
 BEFORE INSERT OR UPDATE ON swms.replenlst for each row
 declare
   l_object_name     VARCHAR2(30) := 'trg_insupd_replenlst_brow';

   l_bck_logi_loc    loc.logi_loc%type;
   --

begin

   IF (  (INSERTING AND :NEW.dest_loc IS NOT NULL)
       OR (UPDATING AND
           NVL(:old.dest_loc, 'x') != NVL(:new.dest_loc, 'x'))) THEN
      IF pl_pflow.g_palletflow_enable IS NULL THEN
         pl_pflow.g_palletflow_enable :=
	         pl_common.f_get_syspar('ENABLE_PALLET_FLOW','N');
      END IF;
      IF pl_pflow.g_palletflow_enable = 'Y' THEN
         l_bck_logi_loc := pl_pflow.f_get_back_loc(:new.dest_loc);
         IF (    (l_bck_logi_loc != 'NONE')
            AND (:new.dest_loc != l_bck_logi_loc)) THEN 
            /* Set the inventory location to inv_dest_loc column */
            /* then change the dest_loc to the back location */
            :new.inv_dest_loc := :new.dest_loc;
            IF :new.type != 'SWP' THEN
               :new.dest_loc := l_bck_logi_loc;
            END IF;
         END IF;
      END IF;
   END IF;

   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

end;
/

