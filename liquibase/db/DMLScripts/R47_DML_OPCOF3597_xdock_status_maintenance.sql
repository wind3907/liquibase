REM INSERTING into XDOCK_STATUS_MAINTENANCE
/****************************************************************************
**  Added new data
**
**
** Modification History:
**    Date       Designer Comments
**    --------   -------- ---------------------------------------------------
**    09/9/2021 kchi7065 Created.
**
**
****************************************************************************/
SET DEFINE OFF;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  1,'NEW','FULLFILLMENT','Lastmile Site not routed','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'NEW' and  STATUS_TYPE = 'FULLFILLMENT') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  2,'ROUTED','FULLFILLMENT','Lastmile Site completed routing (Truck#/Stop#)','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'ROUTED' and  STATUS_TYPE = 'FULLFILLMENT') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  2,'INTRANSIT','LASTMILE','Fullfillment Site Route Closed (Data merged at Site 2)','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'INTRANSIT' and  STATUS_TYPE = 'LASTMILE') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  3,'ARRIVED','LASTMILE','Lastmile Site Xdock Arrived (XSN Open)','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'ARRIVED' and  STATUS_TYPE = 'LASTMILE') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  4,'CONFIRMED','LASTMILE','Lastmile Site Pallets Confirmed to Shipping Door','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'CONFIRMED' and  STATUS_TYPE = 'LASTMILE') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  3,'MANIFEST','FULLFILLMENT','Lastmile Site Closed Manifest','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'MANIFEST' and  STATUS_TYPE = 'FULLFILLMENT') ;
Insert into XDOCK_STATUS_MAINTENANCE (sort_by,XDOCK_STATUS,STATUS_TYPE,STATUS_DESC,ADD_USER,ADD_DATE,UPD_USER,UPD_DATE) select  1,'NEW','LASTMILE','Lastmile','SWMS',sysdate,'SWMS',sysdate from dual where not exists (select 'x' from XDOCK_STATUS_MAINTENANCE where XDOCK_STATUS = 'NEW' and  STATUS_TYPE = 'LASTMILE') ;
