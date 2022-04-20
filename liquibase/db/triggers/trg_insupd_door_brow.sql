CREATE OR REPLACE TRIGGER swms.trg_insupd_door_brow
------------------------------------------------------------------------------
-- sccs_id=@(#) src/schema/triggers/trg_insupd_door_brow.sql, swms, swms.9, 10.1.1 9/8/06 1.3
--
-- Table:
--    door
--
-- Description:
--    This trigger assigns the derived columns, assigns the upd_user and
--    upd_date and validates the length of the door number which must
--    be 4.
--
--    The format of the door number is <dock number><physical door number>.
--    The length of the door number needs to be 4.
--    Examples: D101, C120.
--
--    Two columns are derived from the door number and are used to enforce
--    integrity constraints.  The columns are:
--       - dock_no             The first two characters of door_no.
--       - physical_door_no    The last two characters of door_no.
--    They are always assigned a value from the door_no.
--
--    Before making some of the validation checks the old value and the new
--    value could have been compared first but if you are going to look at
--    the old and new values you may as well just do the check.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--    -20002  - Door number not 4 characters.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    07/20/04 prpbcb   Oracle 8 rs239b swms8 DN None
--                      Oracle 8 rs239b swms9 DN 11741
------------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.door
FOR EACH ROW
DECLARE
   l_object_name        VARCHAR2(30) := 'trg_insupd_door_brow';

   e_invalid_door_no_length EXCEPTION; -- Door # not 4 characters.
BEGIN
   -- The format of the door_no is <dock number><physical door number>.

   -- The door number must be 4 characters in length.
   IF (LENGTH(:new.door_no) != 4) THEN
      RAISE e_invalid_door_no_length;
   END IF;

   -- Populate the columns derived from the door_no.  These derived columns
   -- are used to enforce integrity constraints.
   -- Always assign the derived columns.
   :new.dock_no := SUBSTR(:new.door_no, 1, 2);
   :new.physical_door_no := SUBSTR(:new.door_no, 3, 2);

   IF UPDATING THEN
      :new.upd_user := REPLACE(USER, 'OPS$');
      :new.upd_date := SYSDATE;
   END IF;

EXCEPTION
   WHEN e_invalid_door_no_length THEN
      RAISE_APPLICATION_ERROR(-20002, l_object_name || ': Door number [' ||
             :new.door_no || '] must by 4 characters.');
   WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20001, l_object_name || ': '|| SQLERRM);

END trg_insupd_door_brow;
/

