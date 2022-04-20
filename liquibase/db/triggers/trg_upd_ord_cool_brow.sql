/******************************************************************************
  @(#) trg_upd_ord_cool_brow
  @(#) src/schema/triggers/trg_upd_ord_cool_brow.sql, swms, swms.9, 10.1.1 10/9/08 1.1
******************************************************************************/

/******************************************************************************
  Modification History
  Date      User   Defect  Comment
  10/07/08  prpakp  12426  Initial creation
******************************************************************************/

CREATE OR REPLACE TRIGGER swms.trg_upd_ord_cool_brow
BEFORE UPDATE ON swms.ord_cool
FOR EACH ROW 
WHEN (new.wild_farm is null and new.country_of_origin is not null)
DECLARE
  l_wf ord_cool.wild_farm%type;
  CURSOR c_get_wf IS
    SELECT wild_farm
    FROM cool_item
    WHERE prod_id = :new.prod_id
    AND   cust_pref_vendor = :new.cust_pref_vendor
    AND   country_of_origin = :new.country_of_origin
    AND   wild_farm ='N';
BEGIN
  OPEN c_get_wf;
  FETCH c_get_wf INTO l_wf;
  IF c_get_wf%FOUND THEN
    BEGIN
	:new.wild_farm := 'N';
    END;
  END IF;
  CLOSE c_get_wf;
END;
/

