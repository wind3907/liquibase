CREATE OR REPLACE VIEW "SWMS"."V_RF_CLIENT_VERSION" AS 
SELECT DISTINCT rf.device,
       (select client_version from rf_client_version
         where device = rf.device and application = 'SWMS_RF') swms_host_ver,
       (select format_rf_version(client_version) from rf_client_version
         where device = rf.device and application = 'SWMS_RF') swms_rf_ver,
       (select client_version from rf_client_version
         where device = rf.device and application = 'SOS') sos_host_ver,
       (select format_rf_version(client_version) from rf_client_version
         where device = rf.device and application = 'SOS') sos_rf_ver,
       (select client_version from rf_client_version
         where device = rf.device and application = 'SLS') sls_host_ver,
       (select format_rf_version(client_version) from rf_client_version
         where device = rf.device and application = 'SLS') sls_rf_ver,
       (select client_version from rf_client_version
         where device = rf.device and application = 'STS') sts_host_ver,
       (select client_version from rf_client_version
         where device = rf.device and application = 'STS') sts_rf_ver
  FROM rf_client_version rf
 ORDER BY device;

CREATE OR REPLACE PUBLIC SYNONYM V_RF_CLIENT_VERSION FOR SWMS.V_RF_CLIENT_VERSION;

GRANT SELECT, INSERT, UPDATE, DELETE ON V_RF_CLIENT_VERSION TO SWMS_USER;
GRANT SELECT ON V_RF_CLIENT_VERSION TO SWMS_VIEWER;
