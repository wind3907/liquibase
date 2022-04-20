/****************************************************************************
** File:       SWMS_STS_INSTALL_DML.sql
**
** Desc: Script to install all SWMS_STS scripts
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ----------------------------------------------------
**    19-Nov-2018 Vishnupriya K.     setup SWMS STS scripts
**    
****************************************************************************/
--PROMPT Creating table STS_TEMPLATES 
@/swms/curr/schemas/STS_TEMPLATES_DDL.sql
--PROMPT Creating table STS_OPCO_DCID
@/swms/curr/schemas/STS_OPCO_DCID_DDL.sql
--PROMPT Creating table STS_RTOUT_FAIL_XML
@/swms/curr/schemas/STS_RTOUT_FAIL_XML_DDL.sql
--PROMPT Creating data for STS_TEMPLATE
@/swms/curr/schemas/STS_TEMPLATES_DML.sql
--PROMPT Creating data for STS_OPCO_DCID
@/swms/curr/schemas/STS_OPCO_DCID_DML.sql
--PROMPT Creating Maintenance table configs
@/swms/curr/schemas/SWMS_STS_MAINT_DML.sql
--PROMPT Creating Alert table config
@/swms/curr/schemas/SWMS_STS_ALERTS_DML.sql
--PROMPT Creating SWMS_STS_SYSPAR config
@/swms/curr/schemas/SWMS_STS_SYSPAR_DML.sql
--PROMPT Creating SSWMS_STS_SERVER_SYSPAR config
@/swms/curr/schemas/SWMS_STS_SERVER_SYSPAR_DML.sql
--PROMPT Creating package pl_swms_sts_routeout
@/swms/curr/schemas/pl_swms_sts_routeout.sql
--PROMPT Creating  sts_route_view commented
--@/swms/curr/schemas/sts_route_view.sql