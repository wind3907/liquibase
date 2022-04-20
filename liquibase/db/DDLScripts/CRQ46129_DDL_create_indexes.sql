/****************************************************************************
** Date:       30-OCT-2013
** File:       CRQ46129_indexes.sql
**
**             Script for creating indexes for backup tables
**             for Order Processing and SOS/SLS tables.
**
**    - SCRIPT
**
**    Modification History:
**    Date      	Designer Comments
**    --------  	-------- --------------------------------------------------- **    
**    30-OCT-2013 	sgup4114 CRQ46129
**                  	Project: CRQ46129_DDL_indexes.sql 
**  		        Need indexes on Order Processing/SOS/SLS tables 
****************************************************************************/
spool /tmp/swms/log/CRQ46129_DDL_indexes.lis
CREATE INDEX FLOATS_BCKUP_IND1
ON SWMS.FLOATS_BCKUP (float_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ROUTE_BCKUP_IND1
ON SWMS.ROUTE_BCKUP (route_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDM_BCKUP_IND1
ON SWMS.ORDM_BCKUP  (order_id, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDD_BCKUP_IND1
ON SWMS.ORDD_BCKUP (order_id, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORD_COOL_BCKUP_IND1
ON SWMS.ORD_COOL_BCKUP (order_id, order_line_id, seq_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDCB_BCKUP_IND1
ON SWMS.ORDCB_BCKUP (order_id, order_line_id, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDCW_BCKUP_IND1
ON SWMS.ORDCW_BCKUP (order_id, order_line_id, seq_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDMC_BCKUP_IND1
ON SWMS.ORDMC_BCKUP (order_id, cmt_line_id, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX ORDDC_BCKUP_IND1
ON SWMS.ORDDC_BCKUP (order_id, order_line_id, cmt_line_id, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LABEL_MASTER_BCKUP_IND1
ON SWMS.LABEL_MASTER_BCKUP (batch_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LABEL_HEADER_BCKUP_IND1
ON SWMS.LABEL_HEADER_BCKUP (batch_no, label_seq, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX FLOAT_DETAIL_BCKUP_IND1
ON SWMS.FLOAT_DETAIL_BCKUP (float_no, seq_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LAS_TRUCK_BCKUP_IND1
ON SWMS.LAS_TRUCK_BCKUP (truck, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LAS_PALLET_BCKUP_IND1
ON SWMS.LAS_PALLET_BCKUP (truck, palletno, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX SOS_SHORT_BCKUP_IND1
ON SWMS.SOS_SHORT_BCKUP (orderseq, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX SOS_BATCH_BCKUP_IND1
ON SWMS.SOS_BATCH_BCKUP (batch_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LAS_TRUCK_IND1
ON SWMS.LAS_TRUCK_EQUIPMENT_BCKUP (truck, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LAS_TRUCK_SEAL_BCKUP_IND1
ON SWMS.LAS_TRUCK_SEAL_BCKUP (truck, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX LAS_CASE_BCKUP_IND1
ON SWMS.LAS_CASE_BCKUP (truck, order_seq, label_seq, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX SLS_USER_TRUCK_IND1
ON SWMS.SLS_USER_TRUCK_ACCESSORY_BCKUP (truck_no, bkup_date)
TABLESPACE SWMS_BACKUP;

CREATE INDEX SLS_LOAD_MAP_BCKUP_IND1
ON SWMS.SLS_LOAD_MAP_BCKUP (truck_no, bkup_date)
TABLESPACE SWMS_BACKUP;
spool off;
