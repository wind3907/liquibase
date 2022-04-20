/****************************************************************************
** File: R30_6_9_SMOD1123_DDL_create_sap_ir_out_table.sql
*
** Desc: Script makes changes to table SAP_IR_OUT related to Migrating
**  Reader & Writer programs for Linux
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    06/11/19    nsel0716     Created for SMOD-1123 swmsirwriter
**                                  Linux Migration.
****************************************************************************/

 DECLARE
    v_table_exists NUMBER := 0;
    v_sequence_exists NUMBER := 0;
 BEGIN
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'SAP_IR_OUT'
      AND  owner = 'SWMS';

    IF (v_table_exists = 0) THEN

        --------------------------------------------------------
        --  DDL for Table SAP_IR_OUT
        --------------------------------------------------------
        EXECUTE IMMEDIATE 'CREATE TABLE "SWMS"."SAP_IR_OUT" 
            (   "BATCH_ID" NUMBER(8,0), 
                "SEQUENCE_NUMBER" NUMBER(10,0), 
                "INTERFACE_TYPE" VARCHAR2(5 CHAR), 
                "RECORD_STATUS" VARCHAR2(1 CHAR), 
                "DATETIME" VARCHAR2(16 CHAR),
                "TRANS_TYPE" VARCHAR2(1 CHAR), 
                "ITEM" VARCHAR2(9 CHAR), 
                "CPV" VARCHAR2(10 CHAR), 
                "SLOT_TYPE" VARCHAR2(1 CHAR), 
                "LOC_ID" VARCHAR2(10 CHAR), 
                "PALLET_ID" VARCHAR2(12 CHAR), 
                "RECEIVED_DATE" VARCHAR2(8 CHAR), 
                "QTY_ON_HAND" VARCHAR2(7 CHAR), 
                "EXP_DATE" VARCHAR2(8 CHAR), 
                "WAREHOUSE_ID" VARCHAR2(3 CHAR), 
                "NEW_PALLET_ID" VARCHAR2(18 CHAR), 
                "PO_NO" VARCHAR2(16 CHAR), 
                "EXP_DATE_TRK" VARCHAR2(1 CHAR),
                "ADD_USER" VARCHAR2(30 CHAR) DEFAULT USER, 
                "ADD_DATE" DATE DEFAULT SYSDATE, 
                "UPD_USER" VARCHAR2(30 CHAR), 
                "UPD_DATE" DATE,
                "ERROR_MSG" VARCHAR2(100 CHAR)
            ) SEGMENT CREATION IMMEDIATE 
            PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 
            NOCOMPRESS LOGGING
            STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
            PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
            BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
            TABLESPACE "SWMS_SAP_DTS"';

        --------------------------------------------------------
        --  DDL for Index SAP_IR_OUT_IDX1
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                CREATE INDEX "SWMS"."SAP_IR_OUT_IDX1" ON "SWMS"."SAP_IR_OUT" ("RECORD_STATUS")
                PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS
                STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
                PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
                BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
                TABLESPACE "SWMS_SAP_ITS"';

        --------------------------------------------------------
        --  DDL for Index SAP_IR_OUT_PK
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                CREATE UNIQUE INDEX "SWMS"."SAP_IR_OUT_PK" ON "SWMS"."SAP_IR_OUT" ("SEQUENCE_NUMBER", "INTERFACE_TYPE", "RECORD_STATUS", "DATETIME")
                PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS
                STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
                PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
                BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
                TABLESPACE "SWMS_SAP_ITS" ';

        --------------------------------------------------------
        --  Constraints for Table SAP_IR_OUT
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                ALTER TABLE "SWMS"."SAP_IR_OUT" ADD CONSTRAINT "SAP_IR_OUT_PK" PRIMARY KEY ("SEQUENCE_NUMBER", "INTERFACE_TYPE", "RECORD_STATUS", "DATETIME")
                USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS
                STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
                PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
                BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
                TABLESPACE "SWMS_SAP_ITS"  ENABLE';

        EXECUTE IMMEDIATE '
                CREATE OR REPLACE PUBLIC SYNONYM SAP_IR_OUT FOR SWMS.SAP_IR_OUT';

        EXECUTE IMMEDIATE '
                GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.SAP_IR_OUT TO SWMS_USER';

        EXECUTE IMMEDIATE '
                GRANT SELECT ON SWMS.SAP_IR_OUT TO SWMS_VIEWER';
    END IF;

    SELECT COUNT(*)
    INTO   v_sequence_exists
    FROM   all_sequences
    WHERE  sequence_name = 'SAP_IR_SEQ'
      AND  sequence_owner = 'SWMS';

    IF (v_sequence_exists = 0) THEN
        --------------------------------------------------------
        --  SEQUENCE for Table SAP_IR_OUT
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                CREATE SEQUENCE  "SWMS"."SAP_IR_SEQ" START WITH 1 INCREMENT BY 1';

        EXECUTE IMMEDIATE '
                CREATE OR REPLACE PUBLIC SYNONYM SAP_IR_SEQ FOR SWMS.SAP_IR_SEQ';
    END IF;
END;
/
