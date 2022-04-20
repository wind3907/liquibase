/********************************************************************
**
** DDL to drop primary key SYS_CONFIG_DETAILS_PK from table
** SYS_CONFIG_DETAILS. Just for reference, before being dropped 
** by this DDL script, the primary key was made from columns 
** SCD_SEQ_NO and SCD_UPD_DATE. 
**
** Also adding new index SYS_CONFIG_DETAILS_IDX1 that is SCD_SEQ_NO.
**
** Modification History:
** 
**    Date     Designer       Comments
**    -------- -------------- --------------------------------------
**    7/22/19  pkab6563       Created.
**
*********************************************************************/
DECLARE
    v_index_exists NUMBER := 0;
BEGIN 
    SELECT COUNT(*)
    INTO   v_index_exists
    FROM   dba_indexes
    WHERE  table_name = 'SYS_CONFIG_DETAILS'
      AND  index_name = 'SYS_CONFIG_DETAILS_PK';
              
    IF (v_index_exists > 0) THEN  
        EXECUTE IMMEDIATE 'DROP INDEX SWMS.SYS_CONFIG_DETAILS_PK';
    END IF;      
END;
/

DECLARE
    v_index_exists NUMBER := 0;
BEGIN 
    SELECT COUNT(*)
    INTO   v_index_exists
    FROM   dba_indexes
    WHERE  table_name = 'SYS_CONFIG_DETAILS'
      AND  index_name = 'SYS_CONFIG_DETAILS_IDX1';
              
    IF (v_index_exists = 0) THEN  
        EXECUTE IMMEDIATE '
            CREATE INDEX SYS_CONFIG_DETAILS_IDX1 ON SWMS.SYS_CONFIG_DETAILS (SCD_SEQ_NO)
            TABLESPACE SWMS_ITS2';
    END IF;      
END;
/
