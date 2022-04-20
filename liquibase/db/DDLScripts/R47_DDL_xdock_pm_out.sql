DECLARE
  n_count          PLS_INTEGER;
  SQL_stmt         VARCHAR2(8000 CHAR);
BEGIN
  -- Create table XDOCK_PM_OUT
  n_count := 0;
  SELECT COUNT(*)
    INTO n_count
    FROM all_objects
   WHERE object_type = 'TABLE'
     AND owner       = 'SWMS'
     AND object_name = 'XDOCK_PM_OUT';
     
  IF N_COUNT > 0 THEN
    Dbms_Output.Put_Line( 'Table SWMS.XDOCK_PM_OUT found, skipping recreation...' );
  ELSE
    Dbms_Output.Put_Line( 'Table SWMS.XDOCK_PM_OUT not found, creating now...' );
       EXECUTE IMMEDIATE  'CREATE TABLE XDOCK_PM_OUT
				(
				SEQUENCE_NUMBER             NUMBER ,  
				BATCH_ID                    VARCHAR2(14 CHAR) NOT NULL,  
				RECORD_STATUS               VARCHAR2(1 CHAR)  DEFAULT ''N'',
				ORDER_ID                    VARCHAR2(14 CHAR),
				ROUTE_BATCH_NO              NUMBER,
				ROUTE_NO                    VARCHAR2(10 CHAR),
				SITE_FROM                   VARCHAR2(5 CHAR),
				SITE_TO                     VARCHAR2(5 CHAR),
				DELIVERY_DOCUMENT_ID        VARCHAR2(30 CHAR), 
				PROD_ID                     VARCHAR2(9 CHAR)  NOT NULL,
				CUST_PREF_VENDOR            VARCHAR2(10 CHAR) NOT NULL,
				TYPE                        VARCHAR2(1 CHAR),
				CONTAINER                   VARCHAR2(4 CHAR),
				VENDOR_ID                   VARCHAR2(10 CHAR),
				MFG_SKU                     VARCHAR2(14 CHAR),
				DESCRIP                     VARCHAR2(30 CHAR),
				LOT_TRK                     VARCHAR2(1 CHAR),
				WEIGHT                      NUMBER(8,4),
				G_WEIGHT                    NUMBER(8,4),
				STATUS                      VARCHAR2(3 CHAR)  NOT NULL,
				HAZARDOUS                   VARCHAR2(6 CHAR),
				ABC                         VARCHAR2(1 CHAR),
				MASTER_CASE                 NUMBER(4),
				CATEGORY                    VARCHAR2(11 CHAR),
				REPLACE                     VARCHAR2(9 CHAR),
				REPLACE_IND                 VARCHAR2(1 CHAR),
				BUYER                       VARCHAR2(3 CHAR),
				PACK                        VARCHAR2(4 CHAR),
				PROD_SIZE                   VARCHAR2(6 CHAR),
				BRAND                       VARCHAR2(7 CHAR),
				CATCH_WT_TRK                VARCHAR2(1 CHAR),
				SPLIT_TRK                   VARCHAR2(1 CHAR),
				EXP_DATE_TRK                VARCHAR2(1 CHAR),
				TEMP_TRK                    VARCHAR2(1 CHAR),
				REPACK_TRK                  VARCHAR2(1 CHAR),
				MFG_DATE_TRK                VARCHAR2(1 CHAR),
				STACKABLE                   NUMBER(1),
				MASTER_SKU                  VARCHAR2(9 CHAR),
				MASTER_QTY                  NUMBER(9),
				REPACK_DAY                  VARCHAR2(1 CHAR),
				REPACK_LEN                  NUMBER(9),
				REPACK_IND                  VARCHAR2(1 CHAR),
				REPACK_QTY                  NUMBER(4),
				REPACK_SEC                  VARCHAR2(7 CHAR),
				SPC                         NUMBER(4),
				TI                          NUMBER(4),
				MF_TI                       NUMBER(4),
				HI                          NUMBER(4) NOT NULL,
				MF_HI                       NUMBER(4),
				PALLET_TYPE                 VARCHAR2(2 CHAR),
				AREA                        VARCHAR2(2 CHAR),
				STAGE                       VARCHAR2(1 CHAR),
				CASE_CUBE                   NUMBER(12,4),
				SPLIT_CUBE                  NUMBER(12,4),
				ZONE_ID                     VARCHAR2(5 CHAR),
				AVG_WT                      NUMBER(8,4),
				CASE_PALLET                 NUMBER(4),
				AWM                         NUMBER(6),
				MAX_TEMP                    NUMBER(6,1),
				MIN_TEMP                    NUMBER(6,1),
				PICK_FREQ                   NUMBER(6),
				LAST_REC_DATE               DATE,
				LAST_SHP_DATE               DATE,
				PALLET_STACK                NUMBER(2),
				MAX_SLOT                    NUMBER(3),
				MAX_SLOT_PER                VARCHAR2(1 CHAR),
				FIFO_TRK                    VARCHAR2(1 CHAR)  DEFAULT ''N'',
				LAST_SHIP_SLOT              VARCHAR2(10 CHAR),
				INSTRUCTION                 VARCHAR2(30 CHAR),
				MIN_QTY                     NUMBER(4),
				ITEM_COST                   NUMBER(10,3),
				MFR_SHELF_LIFE              NUMBER(4),
				SYSCO_SHELF_LIFE            NUMBER(4),
				CUST_SHELF_LIFE             NUMBER(4),
				MAINT_FLAG                  VARCHAR2(1 CHAR),
				PERM_ITEM                   VARCHAR2(9 CHAR),
				INTERNAL_UPC                VARCHAR2(14 CHAR),
				EXTERNAL_UPC                VARCHAR2(14 CHAR),
				CUBITRON                    VARCHAR2(1 CHAR),
				DMD_STATUS                  VARCHAR2(1 CHAR),
				AUTO_SHIP_FLAG              VARCHAR2(1 CHAR),
				CASE_TYPE                   VARCHAR2(2 CHAR),
				STOCK_TYPE                  VARCHAR2(1 CHAR),
				CASE_HEIGHT                 NUMBER,
				CASE_LENGTH                 NUMBER,
				CASE_WIDTH                  NUMBER,
				IMS_STATUS                  VARCHAR2(1 CHAR),
				SPLIT_LENGTH                NUMBER,
				SPLIT_WIDTH                 NUMBER,
				SPLIT_HEIGHT                NUMBER,
				MAX_QTY                     NUMBER(4)         DEFAULT 1,
				RDC_VENDOR_ID               VARCHAR2(10 CHAR),
				RDC_EFFECTIVE_DATE          DATE,
				MF_SW_TI                    NUMBER(4),
				SPLIT_TYPE                  VARCHAR2(2 CHAR),
				MINILOAD_STORAGE_IND        VARCHAR2(1 CHAR)  DEFAULT ''N'',
				CASE_QTY_PER_CARRIER        NUMBER(4)         DEFAULT 0,
				CASE_QTY_FOR_SPLIT_RPL      NUMBER(4)         DEFAULT 1,
				SPLIT_ZONE_ID               VARCHAR2(5 CHAR),
				HIGH_RISK_FLAG              VARCHAR2(1 CHAR),
				MAX_MINILOAD_CASE_CARRIERS  NUMBER(3),
				PROD_SIZE_UNIT              VARCHAR2(3 CHAR),
				BUYING_MULTIPLE             NUMBER(5),
				MAX_DSO                     NUMBER(4),
				MX_MAX_CASE                 NUMBER(4),
				MX_MIN_CASE                 NUMBER(4),
				MX_ELIGIBLE                 VARCHAR2(1 BYTE),
				MX_ITEM_ASSIGN_FLAG         VARCHAR2(1 BYTE),
				MX_STABILITY_CALC           NUMBER(7,3),
				MX_STABILITY_FLAG           VARCHAR2(3 BYTE),
				MX_FOOD_TYPE                VARCHAR2(8 BYTE),
				MX_UPC_PRESENT_FLAG         VARCHAR2(1 BYTE),
				MX_MASTER_CASE_FLAG         VARCHAR2(1 BYTE),
				MX_PACKAGE_TYPE             VARCHAR2(10 BYTE),
				MX_WHY_NOT_ELIGIBLE         VARCHAR2(2000 BYTE),
				MX_HAZARDOUS_TYPE           VARCHAR2(20 BYTE),
				MX_STABILITY_RECALC         NUMBER(7,3),
				MX_MULTI_UPC_PROBLEM        VARCHAR2(1 BYTE),
				MX_DESIGNATE_SLOT           VARCHAR2(15 BYTE),
				WSH_BEGIN_DATE              DATE,
				WSH_AVG_INVS                NUMBER,
				WSH_SHIP_MOVEMENTS          NUMBER,
				WSH_HITS                    NUMBER,
				EXPECTED_CASE_ON_PO         NUMBER,
				DIAGONAL_MEASUREMENT        NUMBER,
				RECALC_LENGTH               NUMBER,
				RECALC_WIDTH                NUMBER,
				RECALC_HEIGHT               NUMBER,
				DEFAULT_WEIGHT_UNIT         VARCHAR2(2 BYTE)  DEFAULT ''LB''                  NOT NULL,
				WSH_BEGIN_DATE_RANGE        VARCHAR2(40 BYTE),
				MX_ROTATION_RULES           VARCHAR2(4 BYTE),
				MX_THROTTLE_FLAG            VARCHAR2(1 CHAR),
				HIST_CASE_ORDER             NUMBER,
				HIST_CASE_DATE              DATE,
				HIST_SPLIT_ORDER            NUMBER,
				HIST_SPLIT_DATE             DATE,
				GS1_BARCODE_FLAG            VARCHAR2(10 CHAR),
				FINISH_GOOD_IND             VARCHAR2(1 CHAR),
				READ_ONLY_FLAG              VARCHAR2(1 CHAR),
				ERROR_CODE                  VARCHAR2(100 CHAR),
				ERROR_MSG        			VARCHAR2(500 CHAR),
				ADD_DATE                    DATE              DEFAULT SYSDATE,
				ADD_USER                    VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$''),
				UPD_DATE                    DATE,
				UPD_USER                    VARCHAR2(30 CHAR)
				)
				TABLESPACE SWMS_DTS2';

EXECUTE IMMEDIATE 'COMMENT ON TABLE SWMS.XDOCK_PM_OUT IS ''XDOCK_PM_OUT output staging table for cross dock site 1'' ';

EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.XDOCK_PM_OUT_PK ON SWMS.XDOCK_PM_OUT
				   (SEQUENCE_NUMBER)
				   LOGGING
				   TABLESPACE SWMS_ITS2';

EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM XDOCK_PM_OUT FOR SWMS.XDOCK_PM_OUT';

EXECUTE IMMEDIATE 'ALTER TABLE SWMS.XDOCK_PM_OUT ADD (
  CONSTRAINT XDOCK_PM_OUT_PK
  PRIMARY KEY
  (SEQUENCE_NUMBER)
  USING INDEX SWMS.XDOCK_PM_OUT_PK
  ENABLE VALIDATE)';

EXECUTE IMMEDIATE 'CREATE INDEX SWMS.XDOCK_PM_OUT_IDX1 ON SWMS.XDOCK_PM_OUT
					(BATCH_ID)
					LOGGING
					TABLESPACE SWMS_ITS2';

EXECUTE IMMEDIATE  'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.XDOCK_PM_OUT TO SWMS_USER';

EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.XDOCK_PM_OUT TO SWMS_VIEWER';

END IF;
END;
/
