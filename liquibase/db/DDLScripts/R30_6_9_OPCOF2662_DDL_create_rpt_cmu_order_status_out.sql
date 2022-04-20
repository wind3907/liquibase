/****************************************************************************
** File:       R30_6_9_Jira2662_DDL_create_rpt_order_status_out.sql
**
** Desc: Script creates staging table RPT_ORDER_STATUS_OUT to update order status for other teams 
**		 to access at enterprise level
**
** Modification History:
**    Date        Designer           Comments
**    ----------- --------     ------------------------------------------
**    12/09/19     sban3548     Initial Version
**
****************************************************************************/

DECLARE
    v_table_exists NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_table_exists
    FROM all_tables
    WHERE owner = 'SWMS'
    and table_name = 'RPT_ORDER_STATUS_OUT';

    IF (v_table_exists = 0)
    THEN
      EXECUTE IMMEDIATE '
		CREATE TABLE SWMS.RPT_ORDER_STATUS_OUT ( 
			SEQUENCE_NUMBER  	NUMBER(10) NOT NULL ENABLE,
            BATCH_ID            NUMBER(8),
            RECORD_STATUS       VARCHAR2(1 CHAR), --DEFAULT ''N'',      
			ROUTE_NO 			VARCHAR2(10 CHAR) NOT NULL ENABLE, 
			TRUCK_NO            VARCHAR2(10 CHAR),
			ROUTE_STATUS        VARCHAR2(3 CHAR),   					--NEW, OPN,SHT, CLS
			SHIP_DATE           DATE,
			MASTER_ORDER_ID     VARCHAR2(25),
			REMOTE_LOCAL_FLG    VARCHAR2(1),
			REMOTE_QTY          NUMBER(7),
			RDC_PO_NO           VARCHAR2(16),
			CUST_ID             VARCHAR2(10 CHAR) NOT NULL ENABLE,
			ORDER_TYPE          VARCHAR2(3 CHAR),
            CROSS_DOCK_TYPE     VARCHAR2(2 CHAR),
			STOP_NO     		NUMBER(7,2),
			ORDER_ID 			VARCHAR2(14 CHAR), 
			ORDER_STATUS		VARCHAR2(3 CHAR) NOT NULL  ENABLE,		--NEW, OPN, SHT
			ORDER_LINE_ID       NUMBER(4),
			SYS_ORDER_ID        NUMBER(10),
			SYS_ORDER_LINE_ID   NUMBER(5),	
			ORDER_LINE_STATUS	VARCHAR2(3 CHAR),						--NEW, OPN, SHT, PAL, PAD
			PROD_ID 			VARCHAR2(9 CHAR) NOT NULL ENABLE, 
			CUST_PREF_VENDOR    VARCHAR2(10 CHAR) NOT NULL ENABLE,
			SPC					NUMBER(4),
			CW_TYPE             VARCHAR2(1 CHAR),
			QTY_ORDERED         NUMBER(7) NOT NULL ENABLE,
			QTY_ALLOC           NUMBER(7),
            QTY_SHIPPED         NUMBER(7),									
			UOM 				NUMBER(2,0),
			QTY_SHT             NUMBER(7),
			QTY_WH_OUT			NUMBER(7),
            QTY_PAW             NUMBER(7),
            QTY_PAD             NUMBER(7),
			REASON_CODE         VARCHAR2(3 CHAR),
			PALLET_PULL         VARCHAR2(1 CHAR),
			CMT 				VARCHAR2(100 CHAR), 
			ADD_USER			VARCHAR2(30 CHAR) DEFAULT REPLACE(USER,''OPS$'') ,
			ADD_DATE			DATE DEFAULT SYSDATE,
			UPD_USER			VARCHAR2(30 CHAR),
			UPD_DATE			DATE DEFAULT SYSDATE,
			HEADER_TRACK_ID 	VARCHAR2(100),
			DETAIL_TRACK_ID 	VARCHAR2(100),
			ERROR_MSG 	VARCHAR2(100), 
			CONSTRAINT RPT_ORDER_STATUS_OUT_PK PRIMARY KEY (SEQUENCE_NUMBER)
			)
            SEGMENT CREATION DEFERRED 
                PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
                TABLESPACE "SWMS_DTS2"';
		EXECUTE IMMEDIATE 'CREATE SEQUENCE  SWMS.RPT_ORDER_STATUS_SEQ  MINVALUE 1 MAXVALUE 99999999999999999999999999999999999 
				INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER  NOCYCLE ';
		-- Re-use existing sequence MX_BATCH_NO_SEQ for BATCH_ID
		EXECUTE IMMEDIATE 'CREATE INDEX SWMS.RPT_ORDER_STATUS_OUT_IDX1 ON SWMS.RPT_ORDER_STATUS_OUT(ORDER_ID, ORDER_LINE_ID)';
        EXECUTE IMMEDIATE 'GRANT ALL ON SWMS.RPT_ORDER_STATUS_OUT TO SWMS_USER';
        EXECUTE IMMEDIATE 'GRANT SELECT ON SWMS.RPT_ORDER_STATUS_OUT TO SWMS_VIEWER';
        EXECUTE IMMEDIATE 'CREATE OR REPLACE PUBLIC SYNONYM RPT_ORDER_STATUS_OUT FOR SWMS.RPT_ORDER_STATUS_OUT';
    END IF;
END;
/  
