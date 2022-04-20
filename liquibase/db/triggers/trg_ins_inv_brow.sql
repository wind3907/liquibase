CREATE OR REPLACE TRIGGER swms.trg_ins_inv_brow
-- /******************************************************************************
--   (#) TRG_INS_replenlst_ROW.sql
--   sccs_id=@(#) src/schema/triggers/trg_ins_inv_brow.sql, swms, swms.9, 10.1.1 11/8/06 1.3
-- ******************************************************************************/
--
-- Table:
--    INV(Inventory table)
--
-- Description:
--    This trigger populates the inv.inv_uom if it is null.
--    One occurance was found where this column was not populated
--    by the calling program and hence got the default value of 0.
--    This can cause unexpected behavior of the software due to 
--    all the complications associated with the miniload processing
--    This trigger would try to catch this error before it gets
--    propagated to all other parts of the application.
--
-- Exceptions raised:
--    -20001  - Oracle error occurred.
--
-- Modification History:
--    Date     Designer Comments
--    -------- -------- ---------------------------------------------------
--    04/20/06 prpnxk   Initial Version
--    08/15/06 prpakp   Removed the when clause since the default is 0 
--                      for inv_uom.
--    11/08/06 prpakp   Added check for inv_uom.
-----------------------------------------------------------------------------
BEFORE INSERT ON swms.inv
FOR EACH ROW
DECLARE
	sccs_id		VARCHAR2 (128) := '@(#) src/schema/triggers/trg_ins_inv_brow.sql, swms, swms.9, 10.1.1 11/8/06 1.3';

	l_object_name	VARCHAR2(30) := 'trg_ins_inv_brow';
	lv_msg_text	VARCHAR2(100);
   
	l_miniload_storage_ind	pm.miniload_storage_ind%TYPE;
	l_spc			NUMBER;
	l_rule_id		NUMBER;
	l_ship_date	DATE;

	cursor get_ship_date (c_erm_id varchar2) is
	select ship_date
	from erm
	where erm_id = c_erm_id
	and   erm_type in ('PO','FG');

BEGIN

    /* Only finsh good or meat opcos should have ship_date that need for inventory  */
    if pl_common.f_get_syspar('ENABLE_FINISH_GOODS','N') = 'Y' and :new.rec_id is not null then
       open get_ship_date (:new.rec_id);
       fetch get_ship_date into l_ship_date;
       if get_ship_date%FOUND then
	  :new.ship_date := l_ship_date;
       end if;
       close get_ship_date;
    end if;
    BEGIN
	SELECT	nvl(miniload_storage_ind,'N'),
		spc
	  INTO	l_miniload_storage_ind,
		l_spc
	  FROM	pm
	 WHERE	prod_id = :NEW.prod_id
	   AND	cust_pref_vendor = :NEW.cust_pref_vendor;
         EXCEPTION 
               WHEN OTHERS then
                  l_miniload_storage_ind := 'N';
   END;
   BEGIN            
	SELECT	rule_id
	  INTO	l_rule_id
	  FROM	zone z, lzone l
	 WHERE	logi_loc = :NEW.plogi_loc
	   AND	z.zone_id = l.zone_id
	   AND	z.zone_type = 'PUT';
        EXCEPTION
               WHEN OTHERS THEN
                  l_rule_id := 0;
   END;
   IF (l_miniload_storage_ind = 'S') THEN
	BEGIN
		IF (MOD (:NEW.qoh, l_spc) = 0)		-- The quantity is in cases
		THEN
			IF (NVL (l_rule_id, 0) != 3)	-- The item is put into main warehouse
			THEN
				:NEW.inv_uom := 2;	-- Set the UOM to cases
			ELSE
				:NEW.inv_uom := 1;	-- Even though the qty looks to be in cases
							-- because it is going to miniload location
							-- consider the quantity as splits
			END IF;
		ELSE					-- The quantity is in splits.
			IF (NVL (l_rule_id, 0) != 3)	-- Trying to put splits into main warehouse
			THEN
				RAISE_APPLICATION_ERROR (-20001,
					'Cannot Put Splits in main warehouse for this item');
			ELSE
				:NEW.inv_uom := 1;	-- Adding splits to miniload
			END IF;
		END IF;
				
			
	END;
    ELSIF (l_miniload_storage_ind = 'N' and l_rule_id  = 1) THEN  /* Set the uom to 0 if a regular floating item */
       BEGIN
              :NEW.inv_uom := 0; 
       END;
    END IF;
END trg_ins_inv_brow;
/

