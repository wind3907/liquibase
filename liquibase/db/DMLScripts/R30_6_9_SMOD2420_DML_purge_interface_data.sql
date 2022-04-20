/****************************************************************************************
** Description: Script to insert purge information for Interfaces Tables

** Create purge entries for below tables
** 		1.SAP_CU_IN
** 		2.SAP_IM_IN
** 		3.SAP_MF_IN
** 		4.SAP_OR_IN
** 		5.SAP_PO_IN
** 		6.SAP_ML_IN
** 		7.SAP_CS_IN
** 		8.SAP_IA_OUT
** 		9.SAP_OW_OUT
** 		10.SAP_PW_OUT
** 		11.SAP_RT_OUT
** 		12.SAP_WH_OUT
** 		13.SAP_LM_OUT
** 		14.SAP_IR_OUT
** 		15.SAP_CR_OUT
** 		16.SAP_TRACE_STAGING_TBL
**
** Modification History:
**    Date          Designer           Comments
**    -----------  --------     ---------------------------------------------------------
**    04/01/2019    igoo9289    SMOD-2420: Added Interface tables to SAP_INTERFACE_PURGE table
**
*****************************************************************************************/

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_CU_IN', 10, 'Customer Master', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_CU_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_IM_IN', 10, 'Material Master', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_IM_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_MF_IN', 10, 'Manifest details', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_MF_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_OR_IN', 10, 'Routes processing details', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_OR_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_PO_IN', 10, 'Purchase Order,Inbound Scheduling,PO Close', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_PO_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_ML_IN', 10, 'Current and Historical Orders for Miniload', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_ML_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_CS_IN', 15, 'Product Cost', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_CS_IN');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_IA_OUT', 14, 'PO/SN receipt/close and Inventory Adjustments', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_IA_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_OW_OUT', 10, 'Pick adjustment/Route close', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_OW_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_PW_OUT', 30, 'Purchase Order Status Changes', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_PW_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_RT_OUT', 14, 'Manifest Close', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_RT_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_WH_OUT', 5, 'Item Reconciliation', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_WH_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_LM_OUT', 10, 'Material master update', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_LM_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_IR_OUT', 5, 'Item location update', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_IR_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_CR_OUT', 10, 'Cash/Check upload', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_CR_OUT');

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
SELECT 'SAP_TRACE_STAGING_TBL', 7, 'Interface records tracing', replace(USER,'OPS$',NULL), SYSDATE FROM dual
WHERE NOT EXISTS (select 1 from SAP_INTERFACE_PURGE where table_name = 'SAP_TRACE_STAGING_TBL');

COMMIT;
