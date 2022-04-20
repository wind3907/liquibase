
/*
** 04/21/03
** Ticket:  378448
** This script creates a package and two database trigger to temporarily
** resolve an issue at opco 45 with DOR transactions.
**
** Opco 45 is having issues with the DOR transactions created in the wrong
** place and created multiple times for a multi-pallet putaway.
** What is needed is one DOR transaction created when the first
** putaway pallet is confirmed to the destination slot.  The best way to do
** this is to modify the RF.  In the mean time package PL_DOR_TRANS and
** triggers TRG_INSUPD_TRANS_DOR_BROW and TRG_INS_TRANS_DOR_ASTMT are used to
** fix the problem until the RF is changed.
**
** The initial design of the DOR transaction processing had a DOR transaction
** being created by putaway.pc at putaway confirmation time if the user had
** pressed F4 and entered a door number after scanning a putaway pallet at the
** dock.  The RF sent putaway.pc a flag designating to create a DOR transaction
** and the door number to use.  For a single pallet putaway there was no
** problem.  The problems happen with a mullti-pallet putaway.  The user can
** press F4 after each pallet scanned at the dock for a multi-pallet putaway.
** There was a problem with when the RF was setting the flag to create the
** DOR transaction.  Sometimes it would only set it when the first pallet
** scanned at the dock was putaway and sometimes it would set it for some of
** the pallets but not all.  The RF is in the process of being redesigned so
** that the flag is set only for the first pallet putaway.  If the users press
** F4 and enters a door number for each pallet of a mutli-pallet putaway the
** last door number entered will be used.
**
** When this package and the two triggers are installed a DOR transaction will
** be created if a current DOR transaction does not exist meaning that if a
** user does not press F4 on the RF after picking up a putaway pallet a DOR
** transaction will still be created for the first pallet confirmed to the
** destination slot.  The DOR transaction source location will be the the
** PUT transaction's source location which is the door number of the PO.
**
** Package PL_DOR_TRANS is used to declare global variables that are populated
** by trigger TRG_INSUPD_TRANS_DOR_BROW.  Trigger TRG_INS_TRANS_DOR_ASTMT
** which is an after statement trigger on the trans table checks the global
** packabge variables and will create or update the current DOR transaction.
** This after statement trigger will do one of the following:
**    - If the transaction on the trans table inserted statement inserted more
**      than one PUT or TRP record then do nothing.  The trigger is based on
**      the RF inserting only one PUT or TRP record at a time.
**      PUT or TRP at a time so the trigger is based on this.
**    - If the transaction on the trans table inserted statement inserted more
**      than one DOR record then do nothing.  The trigger is based on the RF
**      inserting only one DOR record at a time.
**    - If the update statement updated more than one PUT or TRP transaction
**      then do nothing.  The trigger is based on the RF updating only one PUT
**      or TRP record at a time.
**    - If one PUT/TRP record was inserted by the RF and no current DOR
**      transaction exists then a DOR transaction is created one second before
**      the PUT/TRP.  The PUT/TRP src_loc is used for the DOR src_loc.
**    - If one PUT/TRP record was inserted by the RF and a current DOR
**      transaction exists then do nothing.
**    - If one DOR record was inserted by the RF then the following is done.
**      If there already was a DOR transaction (will call in the previous DOR)
**      check if the previous DOR src_loc is different from the DOR src_loc just
**      inserted.  If they are different and the DOR src_loc just inserted is
**      not the same as the erm door number updated the previous DOR src_loc to
**      the src_loc of the DOR just inserted.  Always delete the DOR just
**      inserted because it as an extra DOR.
**      If there was no previous DOR transaction then do nothing.
**      This is an example of what the RF could set and what the final result
**      will be:
**         PO door number: D111
**         Multi-pallet putaway of 3 pallets.
**         LP         F4 Door Entered  LP Destination Location
**         --------   ---------------  -----------------------
**          12451     F4 not entered.  DA03A3
**          12452     F4 not entered.  DA05A2
**          12453     D120             DA06B4
**         Putaway pallet 12451.  RF set flag to create DOR transaction with
**            door D111.
**            Trans Type  LP         Src Loc  Dest Loc
**            ----------  ---------  -------  --------
**            DOR                    D111
**            PUT         12451      D111     DA03A3
**        
**         Putaway pallet 12452.  RF does not flag to create DOR transaction.
**            Trans Type  LP         Src Loc  Dest Loc
**            ----------  ---------  -------  --------
**            DOR                    D111
**            PUT         12451      D111     DA03A3
**            PUT         12452      D111     DA05A2
**
**         Putaway pallet 12453.  RF set flag to create DOR transaction with
**            door D120.
**            Trans Type  LP         Src Loc  Dest Loc
**            ----------  ---------  -------  --------
**            DOR                    D111                (D111 will be updated)
**            PUT         12451      D111     DA03A3
**            PUT         12452      D111     DA05A2
**            DOR                    D120                (Will be deleted)
**            PUT         12453      D111     DA06B4
**            The after statement trigger will fire updating D111 to D120
**            for the first DOR transaction then delete the second DOR
**            transaction.  The end result will be:
**            Trans Type  LP         Src Loc  Dest Loc
**            ----------  ---------  -------  --------
**            DOR                    D120
**            PUT         12451      D111     DA03A3
**            PUT         12452      D111     DA05A2
**            PUT         12453      D111     DA06B4
**         
**
** As a reference the order of processing in putaway.pc is
** Putaway When PO Is Open
** -------------------------
** Create DOR transaction if the RF has set the flag.
** Create PUT transaction.
** Delete PPU transaction.
**
** Putaway When PO Is Closed
** -------------------------
** Create DOR transaction if the RF has set the flag.
** Update PUT transaction.
** Delete PPU transaction.
**
*/


SET SCAN OFF

PROMPT Creating package specification pl_dor_trans

/**************************************************************************/
-- Package Specification
/**************************************************************************/
CREATE OR REPLACE PACKAGE swms.pl_dor_trans
AS
   -- sccs_id=@(#) src/schema/plsql/pl_trg_dor_trans.sql, swms, swms.9, 10.1.1 9/7/06 1.2

   ---------------------------------------------------------------------------
   -- Package Name:
   --    pl_dor_trans
   --
   -- File:
   --    pl_trg_dor_trans.sql
   --
   --
   -- Description:
   --    This package defines global variables used to process DOR
   --    transactions.  Opco 45 is having issues with the DOR transactions
   --    created in the wrong place and created multiple times for a
   --    multi-pallet putaway.  What is needed is one DOR transaction created
   --    when the first putaway pallet is confirmed to the destination slot.
   --    The best way to do this is to modify the RF.  In the mean time this
   --    package along with triggers TRG_INSUPD_TRANS_DOR_BROW and
   --    TRG_INS_TRANS_DOR_ASTMT are used to fix the problem until the RF is
   --    changed.
   --
   --    There is no package body.
   --
   --    This package should only be installed at opco 45.
   --
      --
   -- Modification History:
   --    Date     Designer Comments
   --    -------- -------- ---------------------------------------------------
   --    04/21/03 prpbcb   rs239a DN _____  rs239b DN _____  Created.  
   --                      Ticket:  378448
   --                      There probably is a way to use less global
   --                      variables.  I am leaving things as they are.
   --
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Type Declarations
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- Global Variables
   ---------------------------------------------------------------------------

   g_dor_rows_affected   BINARY_INTEGER := 0;  -- Number of DOR transactions
                                   -- created by a RF insert statement.

   g_put_rows_affected   BINARY_INTEGER := 0;  -- Number of PUT or TRP
                                    -- transactions affected by a RF insert or
                                    -- update statement.

   g_dor_special_processing_bln BOOLEAN := FALSE;  -- Indicates if doing
                               -- special processing.  This special processing 
                               -- is when the after statement trigger is
                               -- inserting or updating a DOR transaction
                               -- We do not want the before row trigger to set
                               -- any global variables.

   g_trans_id           trans.trans_id%TYPE := 0;  -- The trans id
                                                   -- inserted/updated by
                                                   -- the RF.

   g_trans_type         trans.trans_type%TYPE := NULL;  -- The trans type
                                        -- being inserted/updated by the RF.
                                        -- It will be set to PUT if a TRP is
                                        -- being inserted/updated.
                                    
   g_dor_src_loc        trans.src_loc%TYPE := NULL;  -- The DOR transaction
                                                     -- src_loc.

   g_erm_id             erm.erm_id%TYPE := NULL;  -- The erm id of the
                                                  -- DOR/PUT/TRP transaction.
END pl_dor_trans;
/

show errors

CREATE OR REPLACE PUBLIC SYNONYM pl_dor_trans FOR swms.pl_dor_trans;




PROMPT Creating trigger trg_insupd_trans_dor_brow

CREATE OR REPLACE TRIGGER swms.trg_insupd_trans_dor_brow
BEFORE INSERT OR UPDATE ON trans
FOR EACH ROW
-- Only for RF (batch_no = 99) PUT, TRP or DOR transactions.
WHEN (NEW.trans_type  IN ('PUT', 'TRP', 'DOR') AND NEW.batch_no = 99)
DECLARE
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/plsql/pl_trg_dor_trans.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- Trigger Name:
--    trg_insupd_trans_dor_brow
--
-- File:
--    pl_trg_dor_trans.sql
--
-- Table:
--    trans
--
-- Description:
--    This trigger assigns values to the global package variables used to
--    process DOR transactions.  Opco 45 is having issues with the DOR
--    transaction created in the wrong place and created multiple times for
--    a multi-pallet putaway.  What is needed is one DOR transaction created
--    when the first putaway pallet is confirmed to the destination slot.
--    The best way to do this is to modify the RF.  In the mean time this
--    trigger along with package pl_dor_trans and trigger
--    TRG_INS_TRANS_DOR_ASTMT are used to fix the problem until the RF is
--    changed.
--
--    This trigger should only be installed at opco 45.
--
-- Exceptions raised:
--    None.  The exception handler writes a swms_log message.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/21/03 prpbcb   rs239a DN _____  rs239b DN _____  Created.  
--                      Ticket:  378448
--    April 03          Modified to only run for user OPS$USSDJG so opco
--                      45 can check things out.
--    07/08/03 prpbcb   Removed running only for user OPS$USSDJG after
--                      talking to Ed Taylor at opco 45.
------------------------------------------------------------------------------
   l_object_name  VARCHAR2(30) := 'trg_insupd_trans_dor_brow';
   l_message      VARCHAR2(120);
BEGIN

   -- Debug statements.
   /*
   pl_log.ins_msg('DEBUG', l_object_name, 'starting trigger,  trans_type [' || :new.trans_type || '] src_loc [' || :new.src_loc || ']', NULL, NULL);
   IF (pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
      pl_log.ins_msg('DEBUG', l_object_name, 'spec proc FALSE', NULL, NULL);
   ELSE
      pl_log.ins_msg('DEBUG', l_object_name, 'spec proc TRUE', NULL, NULL);
   END IF;
   */

   IF (INSERTING) THEN
      -- Debug statememt.
      -- pl_log.ins_msg('DEBUG', l_object_name, 'AA ins ' || :new.trans_type, NULL, NULL);

      IF (    :NEW.trans_type IN ('PUT', 'TRP')
          AND pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
         pl_dor_trans.g_put_rows_affected :=
                                    pl_dor_trans.g_put_rows_affected + 1;

         pl_dor_trans.g_trans_id := :NEW.trans_id;
         pl_dor_trans.g_erm_id := :NEW.rec_id;
         pl_dor_trans.g_trans_type := 'PUT';  -- Put used for both PUT and TRP.

         -- Debug statememt.
         --pl_log.ins_msg('DEBUG', l_object_name, 'BB ins put', NULL, NULL);

      ELSIF (    :NEW.trans_type = 'DOR'
             AND pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
         pl_dor_trans.g_dor_rows_affected :=
                                    pl_dor_trans.g_dor_rows_affected + 1;

         pl_dor_trans.g_trans_id := :NEW.trans_id;
         pl_dor_trans.g_erm_id := :NEW.rec_id;
         pl_dor_trans.g_trans_type := 'DOR';
         pl_dor_trans.g_dor_src_loc := :NEW.src_loc;

         -- Debug statememt.
         -- pl_log.ins_msg('DEBUG', l_object_name, 'ins dor', NULL, NULL);

      END IF;
   ELSIF (UPDATING) THEN
      -- We want to catch when a PUT is done after the PO was closed.  
      -- This will be done by checking if the batch no is set to 99 and
      -- the old trans date < new trans date.  No other operation should be
      -- performing these actions.
      IF (    :NEW.trans_type IN ('PUT', 'TRP')) THEN
         IF (pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
            pl_dor_trans.g_put_rows_affected :=
                                      pl_dor_trans.g_put_rows_affected + 1;
            IF (    :NEW.batch_no = 99
                AND :OLD.trans_date < :NEW.trans_date) THEN
               pl_dor_trans.g_trans_id := :NEW.trans_id;
               pl_dor_trans.g_erm_id := :NEW.rec_id;
               pl_dor_trans.g_trans_type := 'PUT';
            END IF;
         END IF;
      END IF;
   END IF;

   -- Debug statememt.
   -- pl_log.ins_msg('DEBUG', l_object_name, 'ending trigger', NULL, NULL);

EXCEPTION
   WHEN OTHERS THEN
      -- Do not stop processing since this is not a critical error.  Just
      -- write a log message.
      l_message :=
          'Got an error in the trigger.  This does not stop processing';
      pl_log.ins_msg('WARN', l_object_name, l_message, NULL, SQLERRM);
      --RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END;
/

show errors



PROMPT Creating trigger trg_ins_trans_dor_astmt

CREATE OR REPLACE TRIGGER swms.trg_ins_trans_dor_astmt
AFTER INSERT OR UPDATE ON trans
DECLARE
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/plsql/pl_trg_dor_trans.sql, swms, swms.9, 10.1.1 9/7/06 1.2
--
-- Trigger Name:
--    trg_ins_trans_dor_astmt
--
-- File:
--    pl_trg_dor_trans.sql
--
-- Table:
--    trans
--
-- Description:
--    This trigger will create or update the DOR transaction for a user
--    depending on the values of the global variables in package pl_dor_trans.
--
--    Opco 45 is having issues with the DOR transaction created in the wrong
--    place and created multiple times for a multi-pallet putaway.  What is
--    needed is one DOR transaction created when the first putaway pallet is
--    confirmed to the destination slot.  The best way to do this is to modify
--    the RF.  In the mean time this trigger along with package PL_DOR_TRANS
--    and trigger TRG_INSUPD_TRANS_DOR_BROW are used to fix the problem until
--    the RF is changed.
--
--    This trigger should only be installed at opco 45.
--
--    This after statement trigger will do one of the following:
--    - If the transaction on the trans table inserted statement inserted more
--      than one PUT or TRP record then do nothing.  The trigger is based on
--      the RF inserting only one PUT or TRP record at a time.
--      PUT or TRP at a time so the trigger is based on this.
--    - If the transaction on the trans table inserted statement inserted more
--      than one DOR record then do nothing.  The trigger is based on the RF
--      inserting only one DOR record at a time.
--    - If the update statement updated more than one PUT or TRP transaction
--      then do nothing.  The trigger is based on the RF updating only one PUT
--      or TRP record at a time.
--    - If one PUT/TRP record was inserted by the RF and no current DOR
--      transaction exists then a DOR transaction is created one second before
--      the PUT/TRP.  The PUT/TRP src_loc is used for the DOR src_loc.
--    - If one PUT/TRP record was inserted by the RF and a current DOR
--      transaction exists then do nothing.
--    - If one DOR record was inserted by the RF then the following is done.
--      If there already was a DOR transaction (will call in the previous DOR)
--      check if the previous DOR src_loc is different from the DOR src_loc just
--      inserted.  If they are different and the DOR src_loc just inserted is
--      not the same as the erm door number updated the previous DOR src_loc to
--      the src_loc of the DOR just inserted.  Always delete the DOR just
--      inserted because it as an extra DOR.
--      If there was no previous DOR transaction then do nothing.
--
-- Exceptions raised:
--    None.  The exception handler writes a swms_log message.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/21/03 prpbcb   rs239a DN _____  rs239b DN _____  Created.  
--                      Ticket:  378448
------------------------------------------------------------------------------
   l_object_name  VARCHAR2(30) := 'trg_ins_trans_dor_astmt';
   l_message      VARCHAR2(120);

   l_src_loc      trans.src_loc%TYPE;
   l_trans_id     trans.trans_id%TYPE;

   -- This cursor checks if a current DOR transaction exists for the user.
   -- It checks back 1.3 hours.  This is a somewhat arbitrary value in an 
   -- attempt to handle the situation when the transactions for a user get
   -- out of sync due to a RF reboot or RF error.
   CURSOR c_find_dor IS
      SELECT t.trans_id, t.src_loc
        FROM trans t
       WHERE t.user_id = USER
         AND t.trans_type = 'DOR'
         AND t.trans_date >= (SYSDATE - (1.3 / 24)) -- Only check back 1.3 hours
         AND t.trans_date =
                  (SELECT MAX(trans_date)
                     FROM trans t2
                    WHERE t2.user_id = USER
                      AND t2.trans_type = t.trans_type)
        AND NOT EXISTS
               (SELECT 'x'
                  FROM trans t3
                 WHERE t3.user_id = t.user_id
                   AND t3.trans_type = 'PPU'
                   AND t3.trans_date > t.trans_date);

   -- Debug statememt.
   -- cursor c_temp is
   -- select trans_id from trans where user_id = USER and trans_type = 'PPU';

   -- This cursor checks if a current DOR transaction exists for the user that
   -- is not the DOR just inserted.
   CURSOR c_find_previous_dor IS
      SELECT t.trans_id, t.src_loc
        FROM trans t
       WHERE t.user_id = USER
         AND t.trans_id != pl_dor_trans.g_trans_id
         AND t.trans_type = 'DOR'
         AND t.trans_date >= (SYSDATE - (1.3 / 24)) -- Only check back 1.3 hours
         AND t.trans_date =
                  (SELECT MAX(trans_date)
                     FROM trans t2
                    WHERE t2.user_id = USER
                      AND t2.trans_type = t.trans_type
                      AND t2.trans_id != pl_dor_trans.g_trans_id)
        AND NOT EXISTS
               (SELECT 'x'
                  FROM trans t3
                 WHERE t3.user_id = t.user_id
                   AND t3.trans_type = 'PPU'
                   AND t3.trans_date > t.trans_date);

BEGIN

   -- If a single PUT or TRP transaction was just inserted check for a current
   -- DOR transaction and if not found create a DOR transaction one second
   -- before the PUT.

   -- Debug statements.
   /*
   pl_log.ins_msg('DEBUG', l_object_name, 'starting trigger', NULL, NULL);
   IF (pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
      pl_log.ins_msg('DEBUG', l_object_name, 'spec proc FALSE', NULL, NULL);
   ELSE
      pl_log.ins_msg('DEBUG', l_object_name, 'spec proc TRUE', NULL, NULL);
   END IF;
   pl_log.ins_msg('DEBUG', l_object_name,
        'g_trans_type [' || pl_dor_trans.g_trans_type || ']', NULL, NULL);
   */

   IF ((INSERTING OR UPDATING) AND pl_dor_trans.g_trans_type = 'PUT') THEN

      -- Debug statement.
      -- pl_log.ins_msg('DEBUG', l_object_name, 'just ins or upd a PUT', NULL, NULL);

      -- Check for a single PUT.
      IF (    pl_dor_trans.g_put_rows_affected = 1
          AND pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN

         -- Debug statement.
         -- pl_log.ins_msg('DEBUG', l_object_name, 'was a single PUT', NULL, NULL);

         -- Debug statements.
         /*
         open c_temp;
         fetch c_temp into l_trans_id;
         if (c_temp%FOUND) then
            pl_log.ins_msg('DEBUG', l_object_name, 'found PPU transid:' || to_char(l_trans_id), NULL, NULL);
         else
            pl_log.ins_msg('DEBUG', l_object_name, 'found no PPU', NULL, NULL);
         end if;
         */

         OPEN c_find_dor;
         FETCH c_find_dor INTO l_trans_id, l_src_loc;

         IF (c_find_dor%NOTFOUND) THEN

            -- Debug statememt.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'found no current DOR', NULL, NULL);

            -- Found no current DOR transaction.  Insert one using the PUT
            -- transaction.  The before row trigger will have populated the
            -- required global package variables.  The DOR transaction will be
            -- 1 second before the PUT.  This is needed so that the DOR always
            -- comes before the PUT.
 
            -- The insert will fire the triggers again so set a flag so that
            -- the triggers take a different logic path to avoid an infinite
            -- loop.
            pl_dor_trans.g_dor_special_processing_bln := TRUE;

            -- Debug statement.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'No DOR trans found.  Create one using PUT trans id:' || to_char(pl_dor_trans.g_trans_id), NULL, NULL);

            -- pl_dor_trans.g_trans_id is the trans id of the PUT/TRP record.
            INSERT INTO trans (trans_id, trans_type, rec_id, src_loc,
                              trans_date, user_id, batch_no)
            SELECT trans_id_seq.NEXTVAL, 'DOR', rec_id, src_loc,
                            SYSDATE - (1 / (24 * 60 * 60)), USER, 99
              FROM trans
             WHERE trans_id = pl_dor_trans.g_trans_id;

            IF (SQL%NOTFOUND) THEN
               -- Insert failed.  Log it then continue.
               l_message := 'Failed to insert DOR transaction using' ||
                   ' PUT trans id ' || TO_CHAR(pl_dor_trans.g_trans_id);
               pl_log.ins_msg('WARN', l_object_name, l_message, NULL, SQLERRM);
            END IF;

            pl_dor_trans.g_dor_special_processing_bln := FALSE;

         ELSE
            -- Found a current DOR which is OK.
            NULL;

            -- Debug statement.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'found a current DOR transid:' || to_char(l_trans_id) || ' src_loc [' || l_src_loc || '] do nothing',
            --                 NULL, NULL);
         END IF;

         CLOSE c_find_dor;

      END IF;
   ELSIF ((INSERTING) AND pl_dor_trans.g_trans_type = 'DOR') THEN

      -- Debug statement.
      -- pl_log.ins_msg('DEBUG', l_object_name, 'a DOR was inserted', NULL, NULL);

      -- Check for a single DOR transaction inserted.
      IF (    pl_dor_trans.g_dor_rows_affected = 1
          AND pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN

         -- Debug statements.
         /*
         pl_log.ins_msg('DEBUG', l_object_name,
                'A single DOR was inserted, spec proc FALSE', NULL, NULL);
         pl_log.ins_msg('DEBUG', l_object_name, 'looking for previous DOR',
                         NULL, NULL);
         */

         -- Look for a previous current DOR transaction for the user.
         OPEN c_find_previous_dor;
         FETCH c_find_previous_dor INTO l_trans_id, l_src_loc;
         IF (c_find_previous_dor%FOUND) THEN
            -- Found a previous DOR transaction for the user.

            -- Debug statements.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'found a previous DOR transid:' || to_char(l_trans_id) || ' src_loc [' || l_src_loc || ']', NULL, NULL);
            -- pl_log.ins_msg('DEBUG', l_object_name, 'possibly update src_loc of ' || to_char(l_trans_id) || ' to [' || pl_dor_trans.g_dor_src_loc || ']', NULL, NULL);

            -- The insert will fire the triggers again so set a flag so that
            -- the triggers take a different logic path to avoid an infinite
            -- May not need to do this because there is no trigger doing any
            -- special processing when updating a DOR transaction but will
            -- leave it as is.
            pl_dor_trans.g_dor_special_processing_bln := TRUE;

            -- If the previous DOR transaction src loc and the src loc of
            -- the DOR just inserted are different then update the previous
            -- DOR src loc that of the src loc just inserted but only when
            -- the src loc of the DOR just inserted is not the same as the
            -- erm door number.  After doing this delete the DOR just inserted.
            -- because it is an extra DOR.
            IF (l_src_loc != pl_dor_trans.g_dor_src_loc) THEN
               UPDATE trans t
                  SET t.src_loc = pl_dor_trans.g_dor_src_loc
                WHERE t.trans_id = l_trans_id
                  AND EXISTS
                         (SELECT 'x'
                            FROM erm
                           WHERE erm_id = pl_dor_trans.g_erm_id
                             AND NVL(erm.door_no, 'x') != pl_dor_trans.g_dor_src_loc);
                          
            END IF;

            -- Debug statement.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'delete DOR trans id [' ||
            --      to_char(pl_dor_trans.g_trans_id) || ']', NULL, NULL);

            -- Delete the DOR transaction just inserted.
            DELETE FROM trans WHERE trans_id = pl_dor_trans.g_trans_id;

            pl_dor_trans.g_dor_special_processing_bln := FALSE;

         ELSE
            -- Found no previous DOR transaction for the user which is OK.
            NULL;

            -- Debug statement.
            -- pl_log.ins_msg('DEBUG', l_object_name, 'found no previous DOR', NULL, NULL);
         END IF;

         CLOSE c_find_previous_dor;
      END IF;
   END IF;

   -- Reset variables so next operation uses new data.
   IF (pl_dor_trans.g_dor_special_processing_bln = FALSE) THEN
      pl_dor_trans.g_dor_rows_affected := 0;
      pl_dor_trans.g_put_rows_affected := 0;
      pl_dor_trans.g_trans_id := 0;
      pl_dor_trans.g_erm_id := NULL;
      pl_dor_trans.g_trans_type := NULL;
      pl_dor_trans.g_dor_src_loc := NULL;
   END IF;

   -- Debug statement.
   -- pl_log.ins_msg('DEBUG', l_object_name, 'ending trigger', NULL, NULL);
EXCEPTION
   WHEN OTHERS THEN
      -- Do not stop processing since this is not a critical error.  Just
      -- write a log message.
      l_message :=
          'Got an error in the trigger.  This does not stop processing';
      pl_log.ins_msg('WARN', l_object_name, l_message, NULL, SQLERRM);
      --RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);
END;
/

show errors

SET SCAN ON

/*
ALTER TRIGGER swms.trg_insupd_trans_dor_brow DISABLE;
ALTER TRIGGER swms.trg_ins_trans_dor_astmt DISABLE;
*/


/*
DROP TRIGGER swms.trg_insupd_trans_dor_brow ;
DROP TRIGGER swms.trg_ins_trans_dor_astmt ;
*/

