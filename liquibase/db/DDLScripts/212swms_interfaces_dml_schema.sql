INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date) 
VALUES ('SAP_IM_IN', 5, 'Material Master', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date) 
VALUES ('SAP_CU_IN', 5, 'Customer Master', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_SN_IN', 5, 'RDC SN and Vendor ASN', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_MF_IN', 5, 'Manifest details', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_ML_IN', 5, 'Current and Historical Orders for Miniload', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_PO_IN', 5, 'Purchase Order,Inbound Scheduling,PO Close', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_OR_IN', 5, 'Routes processing details', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SYNTELIC_LOADMAPPING_IN', 5, 'Syntelic SLS load mapping details', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('CUBITRON_MEASUREMENT_IN',5,'Case dimensions from Cubitron', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_LM_OUT', 5, 'Material master update', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_WH_OUT', 5, 'Item Reconciliation', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_CR_OUT', 5, 'Cash/Check upload', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_RT_OUT', 5, 'Manifest Close', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_IA_OUT', 5, 'PO/SN receipt/close and Inventory Adjustments', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_OW_OUT', 5, 'Pick adjustment/Route close', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_EQUIP_OUT', 5, 'Warehouse equipment work order', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SAP_CONTAINER_OUT', 5, 'Container info', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SYNTELIC_MATERIAL_OUT', 5, 'Syntelic Material Master', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('SYNTELIC_ROUTE_ORDER_OUT', 5, 'Synteli Route/Order info', replace(USER,'OPS$',NULL), SYSDATE);

INSERT INTO SAP_INTERFACE_PURGE(table_name, retention_days, description, upd_user, upd_date)
VALUES ('CUBITRON_ITEMMASTER_OUT', 5, 'Cubitron Material master', replace(USER,'OPS$',NULL), SYSDATE);

COMMIT;
