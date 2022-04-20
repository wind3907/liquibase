/****************************************************************************
  File:
    R47_DDL_xdock_grants_msghb_usr.sql

  Desc:
    R1 - This script is used to Grant read, write privileges to MSGHB_USR on 
    XDOCK tables.

****************************************************************************/

GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_meta_header TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_tracer TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_returns_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_returns_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_pm_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_pm_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordm_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordm_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordd_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordd_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_floats_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_floats_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_float_detail_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_float_detail_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordcw_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordcw_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_order_xref TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordm_routing_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_ordm_routing_in TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_manifest_dtls_out TO MSGHB_USR;
GRANT SELECT, INSERT, UPDATE, DELETE ON swms.xdock_manifest_dtls_in TO MSGHB_USR;
