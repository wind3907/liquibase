CREATE OR REPLACE TRIGGER swms.trg_insupd_inv_xdock_brow
-- /******************************************************************************
--   (#) trg_insupd_inv_xdock_brow.sql
-- ******************************************************************************/
--
-- Table:
--    INV(Inventory table)
--
-- Description:
--    This trigger prevents creating inv if read_only_flag is set to Y.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    05/10/21 pdas8114  OPCOF - 3401 LP- Block Item Master from Updates From Forms (at site2)
---------------------------------------------------------------------------
BEFORE INSERT OR UPDATE ON swms.inv
FOR EACH ROW
DECLARE
  l_read_only_flag VARCHAR2(1);
BEGIN
    BEGIN
	SELECT read_only_flag
	 INTO l_read_only_flag
	FROM	pm
	WHERE prod_id = :NEW.prod_id
	AND cust_pref_vendor = :NEW.cust_pref_vendor;
    EXCEPTION 
	 WHEN NO_DATA_FOUND THEN
	   l_read_only_flag := NULL;
     WHEN OTHERS then
       l_read_only_flag := NULL;
    END;
	IF l_read_only_flag = 'Y'	-- do not create inv for cross dock items
	 THEN
	 RAISE_APPLICATION_ERROR (-20001, 'Cannot create inventory for view only products');
	END IF;
END trg_insupd_inv_xdock_brow;
/

