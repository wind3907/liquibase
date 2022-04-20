/****************************************************************************
** File: Jira729_create_table_inboud_cust_setup.sql
**
** Desc: Script create new table:getmeat_cust_setup and added index and primary key
**                                   
****************************************************************************/
 DECLARE
  v_column_exists NUMBER := 0;
 BEGIN 
 
              SELECT COUNT(*)
              INTO v_column_exists
              FROM all_tables
              WHERE  table_name = 'GETMEAT_CUST_SETUP'
              AND  owner='SWMS';
              
             IF (v_column_exists = 0) THEN  
                                 
                EXECUTE IMMEDIATE 'CREATE TABLE SWMS.GETMEAT_CUST_SETUP
            (
              Cust_Id       Varchar2(10 )         Not Null,
              Door_No       Number(3)            Not Null,
              Method_Id     Varchar2(10)         Not Null 
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
            EXECUTE IMMEDIATE '
            CREATE OR REPLACE PUBLIC SYNONYM getmeat_cust_setup FOR SWMS.getmeat_cust_setup';
            EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.getmeat_cust_setup ADD 
            CONSTRAINT getmeat_cust_setup_PK
             PRIMARY KEY (CUST_ID)
             ENABLE
             VALIDATE';
            EXECUTE IMMEDIATE '
            ALTER TABLE SWMS.getmeat_cust_setup ADD
            CONSTRAINT DOOR_NO_UNIQUE
             UNIQUE (DOOR_NO)
             ENABLE';
            EXECUTE IMMEDIATE '
            GRANT DELETE, INSERT, SELECT, UPDATE ON SWMS.getmeat_cust_setup TO SWMS_USER';
            EXECUTE IMMEDIATE '
            GRANT SELECT ON SWMS.getmeat_cust_setup TO SWMS_VIEWER';   
            END IF;      
END;
/