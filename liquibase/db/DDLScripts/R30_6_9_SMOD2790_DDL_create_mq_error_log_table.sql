/****************************************************************************
** File: R30_6_9_SMOD2790_DDL_create_mq_error_log_table.sql
*
** Desc: Script makes changes to table MQ_ERROR_LOG related to SWMS
**  MuleSoft Inegration
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    05/12/20    igoo9289     Created for SMOD-2790 MuleSoft MQ integration
**                                  Error Log.
****************************************************************************/

 DECLARE
    v_table_exists NUMBER := 0;
    v_sequence_exists NUMBER := 0;
 BEGIN
    SELECT COUNT(*)
    INTO   v_table_exists
    FROM   all_tables
    WHERE  table_name = 'MQ_ERROR_LOG'
      AND  owner = 'SWMS';

    IF (v_table_exists = 0) THEN

        --------------------------------------------------------
        --  DDL for Table MQ_ERROR_LOG
        --------------------------------------------------------
        EXECUTE IMMEDIATE 'CREATE TABLE "SWMS"."MQ_ERROR_LOG"
            (   "SEQUENCE_NUMBER" NUMBER(10,0),
                "QUEUE_NAME" VARCHAR2(50 CHAR),
                "QUEUE_DATA" CLOB,
                "MULE_PAYLOAD" CLOB,
                "ERROR_MSG" CLOB,
                "ADD_USER" VARCHAR2(30 CHAR) DEFAULT USER,
                "ADD_DATE" DATE DEFAULT SYSDATE
            ) SEGMENT CREATION IMMEDIATE
            PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255
            NOCOMPRESS LOGGING
            STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
            PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
            BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
            TABLESPACE "SWMS_SAP_DTS"';

        --------------------------------------------------------
        --  Constraints for Table MQ_ERROR_LOG
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                ALTER TABLE "SWMS"."MQ_ERROR_LOG" ADD CONSTRAINT "MQ_ERROR_LOG_PK" PRIMARY KEY ("SEQUENCE_NUMBER")
                USING INDEX PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS
                STORAGE(INITIAL 65536 NEXT 1048576 MINEXTENTS 1 MAXEXTENTS 2147483645
                PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
                BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
                TABLESPACE "SWMS_SAP_ITS"  ENABLE';

        EXECUTE IMMEDIATE '
                CREATE OR REPLACE PUBLIC SYNONYM MQ_ERROR_LOG FOR SWMS.MQ_ERROR_LOG';

        EXECUTE IMMEDIATE '
                GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.MQ_ERROR_LOG TO SWMS_USER';

        EXECUTE IMMEDIATE '
                GRANT SELECT ON SWMS.MQ_ERROR_LOG TO SWMS_VIEWER';
    END IF;

    SELECT COUNT(*)
    INTO   v_sequence_exists
    FROM   all_sequences
    WHERE  sequence_name = 'MQ_ERROR_LOG_SEQ'
      AND  sequence_owner = 'SWMS';

    IF (v_sequence_exists = 0) THEN
        --------------------------------------------------------
        --  SEQUENCE for Table MQ_ERROR_LOG
        --------------------------------------------------------
        EXECUTE IMMEDIATE '
                CREATE SEQUENCE  "SWMS"."MQ_ERROR_LOG_SEQ" START WITH 1 INCREMENT BY 1';

        EXECUTE IMMEDIATE '
                CREATE OR REPLACE PUBLIC SYNONYM MQ_ERROR_LOG_SEQ FOR SWMS.MQ_ERROR_LOG_SEQ';
    END IF;
END;
/
