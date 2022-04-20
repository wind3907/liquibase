/********************************************************************
**
** Script to create new rpt_inv_stgng_out table
**
** Modification History:
** 
**    Date     Designer       Comments
**    -------- -------------- --------------------------------------
**    4-1-2020 D. Betancourt  Created for Jira card 2714.
*********************************************************************/
 DECLARE
    v_table_exists NUMBER := 0;
 BEGIN
    SELECT COUNT(*)
    INTO v_table_exists
    FROM   all_tables
    WHERE  table_name = 'RPT_INV_STGNG_OUT'
      AND  owner = 'SWMS';
              
    IF (v_table_exists = 0) THEN
                                 
        EXECUTE IMMEDIATE 'CREATE TABLE SWMS.RPT_INV_STGNG_OUT
        (
		batch_id				NUMBER,			-- Generated for internal use only
		po_no				VARCHAR2(10),		-- ERD_LPN
		po_line_id			NUMBER,			-- ERD_LPN
		prod_id				VARCHAR2(7),		-- INV
		uom					VARCHAR2(2),		-- ERD
		qoh					NUMBER,			-- INV
		trans_date			DATE,			-- INV
		pallet_id				VARCHAR2(18),		-- ERD_LPN
		trans_type			VARCHAR2(3),		-- Hardcoded, NEW or PUT
		sn_no				VARCHAR2(20),		-- ERD_LPN
		record_status			VARCHAR2(1),		-- Generated for internal use only
		record_status_message	VARCHAR2(100),		-- Generated for internal use only
		track_id				VARCHAR2(100),		-- Generated for internal use only
		add_date				DATE,			-- Generated for internal use only
		upd_date				DATE,			-- Generated for internal use only
		add_user				VARCHAR2(20),		-- Generated for internal use only
		upd_user				VARCHAR2(20)		-- Generated for internal use only
        )
        TABLESPACE SWMS_DTS2
    	RESULT_CACHE (MODE DEFAULT)
        PCTUSED    0
        PCTFREE    10
        INITRANS   1
        MAXTRANS   255
        STORAGE    (
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
            FLASH_CACHE      DEFAULT
            CELL_FLASH_CACHE DEFAULT
        )
        LOGGING 
        NOCOMPRESS 
        NOCACHE
        NOPARALLEL
        MONITORING';
	   
	EXECUTE IMMEDIATE 'CREATE INDEX rpt_inv_stgng_out_idx ON rpt_inv_stgng_out (batch_id)';
        
	EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM RPT_INV_STGNG_OUT FOR SWMS.RPT_INV_STGNG_OUT';

	EXECUTE IMMEDIATE 'GRANT ALL ON SWMS.RPT_INV_STGNG_OUT TO SWMS_USER';
        
	EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.RPT_INV_STGNG_OUT TO SWMS_VIEWER';
    END IF;
END;
/
