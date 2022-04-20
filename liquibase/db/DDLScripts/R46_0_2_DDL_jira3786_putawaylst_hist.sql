/*---------------------------------------------------------------------------

  File:
    putawaylst_hist.sql
	
 Modification History:
    Date     Designer Comments
 -------- -------- ---------------------------------------------------
 11/5/2021 pdas8114	Jira-3786  Initial Creation, putawaylst_hist table to be populated 
                                  from deletion trigger on putawaylst table
 11/16/2021 pkab6563    Jira 3786 Changed primary key to be pallet_id;
                                  added indexes from putawaylst table.
 12/13/2021 pkab6563    Jira 3900 Removed column demand_flag1.
 
-----------------------------------------------------------------------------*/

DECLARE
    v_table_exists NUMBER := 0;
BEGIN

    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE table_name = 'PUTAWAYLST_HIST'
      AND owner = 'SWMS';

    IF(v_table_exists = 0) THEN

        EXECUTE IMMEDIATE '
        CREATE TABLE SWMS.PUTAWAYLST_HIST
        (
            PALLET_ID                      VARCHAR2(18 CHAR) NOT NULL,
			REC_ID                         VARCHAR2(12 CHAR) NOT NULL,
			PROD_ID                        VARCHAR2(9 CHAR) NOT NULL,
			DEST_LOC                       VARCHAR2(10 CHAR),
			QTY                            NUMBER(8)      NOT NULL,
			UOM                            NUMBER(2)      NOT NULL,
			STATUS                         VARCHAR2(3 CHAR) NOT NULL,
			INV_STATUS                     VARCHAR2(3 CHAR) NOT NULL,
			EQUIP_ID                       VARCHAR2(10 CHAR) NOT NULL,
			PUTPATH                        NUMBER(9),
			REC_LANE_ID                    VARCHAR2(30 CHAR) NOT NULL,
			ZONE_ID                        VARCHAR2(5 CHAR),
			LOT_ID                         VARCHAR2(30 CHAR),
			EXP_DATE                       DATE,
			WEIGHT                         NUMBER(9,3),
			TEMP                           NUMBER(6,1),
			MFG_DATE                       DATE,
			QTY_EXPECTED                   NUMBER(8)      NOT NULL,
			QTY_RECEIVED                   NUMBER(8)      NOT NULL,
			DATE_CODE                      VARCHAR2(1 CHAR),
			EXP_DATE_TRK                   VARCHAR2(1 CHAR),
			LOT_TRK                        VARCHAR2(1 CHAR),
			CATCH_WT                       VARCHAR2(1 CHAR),
			TEMP_TRK                       VARCHAR2(1 CHAR),
			PUTAWAY_PUT                    VARCHAR2(1 CHAR),
			SEQ_NO                         NUMBER(4)      NOT NULL,
			MISPICK                        VARCHAR2(1 CHAR),
			CUST_PREF_VENDOR               VARCHAR2(10 CHAR) NOT NULL,
			ERM_LINE_ID                    NUMBER(4),
			PRINT_STATUS                   VARCHAR2(3 CHAR),
			REASON_CODE                    VARCHAR2(3 CHAR),
			ORIG_INVOICE                   VARCHAR2(16 CHAR),
			PALLET_BATCH_NO                VARCHAR2(13 CHAR),
			OUT_SRC_LOC                    VARCHAR2(10 CHAR),
			OUT_INV_DATE                   DATE,
			RTN_LABEL_PRINTED              VARCHAR2(1 CHAR),
			CLAM_BED_TRK                   VARCHAR2(1 CHAR),
			INV_DEST_LOC                   VARCHAR2(10 CHAR),
			TTI_TRK                        VARCHAR2(1 CHAR),
			TTI                            VARCHAR2(1 CHAR),
			CRYOVAC                        VARCHAR2(1 CHAR),
			PARENT_PALLET_ID               VARCHAR2(18 CHAR),
			QTY_DMG                        NUMBER(3),
			PO_LINE_ID                     NUMBER(3),
			SN_NO                          VARCHAR2(12 CHAR),
			PO_NO                          VARCHAR2(12 CHAR),
			PRINTED_DATE                   DATE,
			COOL_TRK                       VARCHAR2(1 CHAR),
			FROM_SPLITTING_SN_PALLET_FLAG  VARCHAR2(1 CHAR),
			DEMAND_FLAG                    VARCHAR2(1 CHAR),
			QTY_PRODUCED                   NUMBER(7),
			MASTER_ORDER_ID                VARCHAR2(25 CHAR),
			TASK_ID                        NUMBER(10),
			LM_RCV_BATCH_NO                VARCHAR2(13 CHAR),
			DOOR_NO                        VARCHAR2(4 CHAR),
			PUTAWAY_ADD_USER        	   VARCHAR2(10 CHAR),
			PUTAWAY_ADD_DATE        	   DATE,
			PUTAWAY_DEL_USER        	   VARCHAR2(10 CHAR)         DEFAULT REPLACE (USER, ''OPS$''),
			PUTAWAY_DEL_DATE        	   DATE                      DEFAULT SYSDATE
        ) ';

        EXECUTE IMMEDIATE 'ALTER TABLE SWMS.PUTAWAYLST_HIST
            ADD CONSTRAINT PUTAWAYLST_HIST_PK PRIMARY KEY (PALLET_ID)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.PUTAWAYLST_HIST_FK1
            ON SWMS.PUTAWAYLST_HIST (REC_ID)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.PUTAWAYLST_HIST_FK2
            ON SWMS.PUTAWAYLST_HIST (PALLET_BATCH_NO)';

        EXECUTE IMMEDIATE 'CREATE UNIQUE INDEX SWMS.PUTAWAYLST_HIST_UK1
            ON SWMS.PUTAWAYLST_HIST (TASK_ID)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.PUTAWAYLST_HIST_IDX1
            ON SWMS.PUTAWAYLST_HIST (LOT_ID)';

        EXECUTE IMMEDIATE 'CREATE INDEX SWMS.PUTAWAYLST_HIST_IDX2
            ON SWMS.PUTAWAYLST_HIST (PARENT_PALLET_ID)';

        EXECUTE IMMEDIATE 'CREATE
        OR REPLACE PUBLIC SYNONYM PUTAWAYLST_HIST FOR SWMS.PUTAWAYLST_HIST';

        EXECUTE IMMEDIATE 'GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.PUTAWAYLST_HIST TO SWMS_USER';

        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.PUTAWAYLST_HIST TO SWMS_VIEWER';
    END IF;
END;
/
