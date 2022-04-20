/****************************************************************************
** File:       R30_6_6_Jira790_DDL_create_meat_cl_out_table.sql
*
** Desc: Script creates  column,  to table MEAT_CL_OUT related to meat project
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    04/01/19     xzhe5043     added records to MEAT_CL_OUT        
****************************************************************************/
DECLARE
    v_table_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE owner = 'SWMS'
    and table_name = 'MEAT_CL_OUT';

    IF (v_table_exists = 0)
    THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE "SWMS"."MEAT_CL_OUT" 
           (
		    SEQUENCE_NUMBER	NUMBER(10,0),
			CUST_ID	VARCHAR2(10 BYTE) NOT NULL,
			RACK_CUT_LOC	VARCHAR2(10 BYTE),
			STAGING_LOC	VARCHAR2(10 BYTE),
			WILLCALL_LOC	VARCHAR2(10 BYTE),
			RECORD_STATUS	VARCHAR2(1 CHAR),
	        FUNC_CODE       VARCHAR2(1 CHAR),
			ADD_USER	VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') ,
			ADD_DATE	DATE DEFAULT SYSDATE,
			UPD_USER	VARCHAR2(30 CHAR),
			UPD_DATE	DATE DEFAULT SYSDATE,
			ERROR_MSG	VARCHAR2(100 CHAR)
			)
            SEGMENT CREATION DEFERRED 
                PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
                TABLESPACE "SWMS_DTS2"';
        EXECUTE IMMEDIATE 'create sequence meat_cl_out_seq increment by 1 ';
        EXECUTE IMMEDIATE 'GRANT ALL ON SWMS.MEAT_CL_OUT to SWMS_USER';
        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.MEAT_CL_OUT to SWMS_VIEWER';
        EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM MEAT_CL_OUT for swms.MEAT_CL_OUT';
    END IF;
END;
/  