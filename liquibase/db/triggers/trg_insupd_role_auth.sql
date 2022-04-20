
CREATE OR REPLACE TRIGGER swms.trg_insupd_role_auth
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_role_auth.sql, swms, swms.9, 10.1.1 5/28/08 1.2
--
-- Table:
--    ROLE_AUTH
--
-- Description:
--    Perform necessary actions when a ROLE_AUTH record is inserted
--    or updated.
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
--    10/24/07 prpbcb   DN 12297
--                      Ticket: 484515
--                      Project: 484515-Menu Access Security
--
--    05/22/08 prpbcb   DN 12387
--                      Project: 606022-Cannot Run Labor Report
--                      Change the privilege for auth id 20 from 0 (Lookup)
--                      to 2 (Update).  Labor reporting requires Update
--                      privilege.
--
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.role_auth
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_role_auth';
BEGIN
   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

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
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_role_auth;
/

