SET ECHO OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED
/*
**********************************************************************************
** File:       R47_DML_OPCO3376_xdock_type.sql.sql
**
** Purpose:    Add xdock types to cross_dock_type table
**
** Modification History:
**   Date         Designer  Comments
**   -----------  --------- ------------------------------------------------------
**   07/07/2021   pdas8114  S4R - OPCOF-3376 Don't Generate X-dock Order at SWMS1 w/o SWMS2 Stop/trk
**********************************************************************************
*/

Insert into cross_dock_type
   (CROSS_DOCK_TYPE, RECEIVE_WHOLE_PALLET, DESCRIPTION)
SELECT 'S', 'Y', 'Cross Dock for Fulfillment Site' FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM cross_dock_type WHERE cross_dock_type = 'S');
 
Insert into cross_dock_type
   (CROSS_DOCK_TYPE, RECEIVE_WHOLE_PALLET, DESCRIPTION)
SELECT 'X', 'Y', 'Cross Dock for Last Mile Site' FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM cross_dock_type WHERE cross_dock_type = 'X');
COMMIT;