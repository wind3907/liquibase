/****************************************************************************
** Date:       17-May-2016
** File:       6000009429_DCL_grant_sts_perm.sql
**
**             Script to provide required grants  
**             for STS_ROUTE_OUT,STS_ROUTE_IN.
**
**    - SCRIPTS
**
**    Modification History:
**    Date      Designer Comments
**    --------  -------- --------------------------------------------------- **    
**    17-May-16 SKAM7588 Charm#6000009429
**              SPOT3255 Removed STS_ROUTE_IN,STS_ROUTE_IN_OBJECT.         
**
****************************************************************************/
GRANT ALL on STS_ROUTE_IN to SWMS_SAP;
GRANT ALL on STS_ROUTE_IN_SEQ to SWMS_SAP;
GRANT ALL on STS_ROUTE_OUT to SWMS_SAP;
GRANT ALL on STS_ROUTE_OUT_OBJECT to SWMS_SAP;
GRANT ALL on STS_ROUTE_OUT_SEQ to SWMS_SAP;
GRANT ALTER, DELETE, INSERT, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON SWMS.STS_ROUTE_OUT TO SWMS_USER; 
GRANT ALTER, DELETE, INSERT, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, DEBUG, FLASHBACK ON SWMS.STS_ROUTE_IN TO SWMS_USER;
GRANT EXECUTE, DEBUG ON SWMS.STS_ROUTE_OUT_OBJECT_TABLE TO SWMS_JDBC;
GRANT EXECUTE, DEBUG ON SWMS.STS_ROUTE_OUT_OBJECT_TABLE TO SWMS_SAP;
GRANT EXECUTE, DEBUG ON STS_ROUTE_OUT_OBJECT TO SWMS_JDBC;

/
