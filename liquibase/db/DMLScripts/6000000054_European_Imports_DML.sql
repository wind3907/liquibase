/****************************************************************************
** Date:       05-MAY-2014
** File:       6000000054_European_Imports_DML.sql
**
** Script to insert purge information for tables created as part of 
**		European Imports integration
**
** Create purge entries for below table
** 		1.CROSS_DOCK_DATA_COLLECT_IN
** 		2.CROSS_DOCK_DATA_COLLECT
** 		3.CROSS_DOCK_XREF
**
** Modification History:
**    Date     Designer Comments
**    -------- -------- ---------------------------------------------------
**    05/05/14 Infosys  Purge entries done for above mentioned tables
**
****************************************************************************/

Insert into SWMS.SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
Values
   ('CROSS_DOCK_DATA_COLLECT', 55, 'Cross Dock Data Collect details', 'SWMS', sysdate);
Insert into SWMS.SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
Values
   ('CROSS_DOCK_DATA_COLLECT_IN', 55, 'Cross Dock Data Collect details Inbound', 'SWMS', sysdate);
Insert into SWMS.SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
Values
   ('CROSS_DOCK_XREF', 55, 'Cross Dock reference details', 'SWMS', sysdate);
Insert into SWMS.SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
Values
   ('CROSS_DOCK_PALLET_XREF', 55, 'Cross Dock reference details', 'SWMS', sysdate);
Insert into SWMS.RULES(RULE_ID, RULE_TYPE, RULE_DESC,DEF)
Values
   (4,'PUT','CROSS DOCK','N');
Insert into SWMS.TRANS_TYPE
   (TRANS_TYPE, DESCRIP, RETENTION_DAYS, INV_AFFECTING)
 Values
   ('ERR', 'Quantity mismatch between ORDD and INV', 55, 'N');
Insert into SWMS.INV_STAT
   (STATUS, DESCRIP)
Values
   ('CDK', 'Cross Dock');

Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('INC', 'Incomplete Data', 1);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('NEW', 'PO Ready to be received', 2);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('OPN', 'Putaway in progress', 3);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('PUT', 'Putaway Completed', 4);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('PAT', 'Shipped and Closed', 7);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('CLO', 'PO Closed', 5);
Insert into SWMS.CROSS_DOCK_STATUS
   (STATUS, DESCRIPTION, SEQ)
 Values
   ('RTG', 'Routes Generated', 6);

COMMIT;
