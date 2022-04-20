SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** File:       R47_DML_OPCO3885_ins_purge.sql
**
** Purpose:    Add Enable_Yard_Location_Override SysPar
**
** Modification History:
**   Date         Designer  Comments
**   -----------  --------- ------------------------------------------------------
**   12/05/2021   pdas8114  S4R - OPCOF-3385 Interface from SWMS (site1) to SWMS (site2) for X-dock Product Attributes 
**********************************************************************************
*/
-- Create the SysPar entry 

Insert into SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
SELECT 'XDOCK_PM_OUT', 20, 'Interface records for cross dock site1', 'SWMS', SYSDATE FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM SAP_INTERFACE_PURGE WHERE TABLE_NAME = 'XDOCK_PM_OUT');
 
Insert into SAP_INTERFACE_PURGE
   (TABLE_NAME, RETENTION_DAYS, DESCRIPTION, UPD_USER, UPD_DATE)
SELECT 'XDOCK_PM_IN', 7, 'Interface records for cross dock site2', 'SWMS', SYSDATE FROM DUAL
  WHERE NOT EXISTS (SELECT 1 FROM SAP_INTERFACE_PURGE WHERE TABLE_NAME = 'XDOCK_PM_IN');
 commit;
