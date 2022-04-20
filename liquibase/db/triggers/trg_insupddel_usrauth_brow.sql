CREATE OR REPLACE TRIGGER swms.trg_insupddel_usrauth_brow
------------------------------------------------------------------------------
-- @(#) src/schema/triggers/trg_insupddel_usrauth_brow.sql, swms, swms.9, 10.1.1 5/28/08 1.1
--
-- Table:
--    USR
--
-- Description:
--    This trigger performs the necessary actions when a USRAUTH record is
--    inserted, updated or deleted.
--
--    On INSERT, UPDATE
--       -  For auth id 20 (Labor Reporting) change the privilege
--          to 2 (Update) if it is 0 (Lookup).  Labor reports will not
--          print if the privilege is 0.  Lookup and Update are
--          equivalent as far as Labor Reporting security goes but the
--          privilege needs to be Update to get the labor reports to print.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/22/08 prpbcb   DN 12387
--                      Project: 606022-Cannot Run Labor Report
--                      Created.
--                      Change the privilege for auth id 20 from 0 (Lookup)
--                      to 2 (Update).  Labor reporting requires Update
--                      privilege.
--
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE OR DELETE ON swms.usrauth
FOR EACH ROW
DECLARE
BEGIN
   IF INSERTING OR UPDATING THEN
      --
      -- Switch privilege from 0 (Lookup) to 2 (Update) for auth id 20
      -- (Labor Reporting).  Lookup and Update are equivalent as far as
      -- Labor Reporting security goes but the privilege needs to be Update
      -- to get the labor reports to print.
      --
      IF (:NEW.auth_id = 20 AND :NEW.priv = 0) THEN
         :NEW.priv := 2;
      END IF;
   END IF;  -- end if inserting or deleting
EXCEPTION
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, 'trg_insupddel_usrauth_brow: '|| SQLERRM);
END trg_insupddel_usrauth_brow;
/

