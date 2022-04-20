REM INSERTING into SAP_INTERFACE_PURGE
SET DEFINE OFF;

SET ECHO OFF
SET SCAN OFF
SET LINESIZE 300
SET PAGESIZE 60
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE

  K_This_Script             CONSTANT  VARCHAR2(50 CHAR) := 'R47_R1_DML_3720_add_purge_tabs.sql';

  PROCEDURE ins_purge (p_table_name varchar2, 
                       p_retention binary_integer,
                       p_descr varchar2) IS 
  BEGIN
  
    Insert into SAP_INTERFACE_PURGE (TABLE_NAME,
                                     RETENTION_DAYS,
                                     DESCRIPTION,
                                     UPD_USER,
                                     UPD_DATE)
    SELECT p_table_name,
           p_retention,
           p_descr,
           user,
           sysdate
    FROM dual
    WHERE NOT EXISTS (SELECT 'Checking if the purge table exists'
                      FROM SAP_INTERFACE_PURGE 
                      WHERE TABLE_NAME = p_table_name);

    IF sql%found THEN 
        DBMS_OUTPUT.PUT_LINE('Added TABLE '||p_table_name||' TO PURGE list');
    END IF;

  END;

BEGIN

  DBMS_OUTPUT.PUT_LINE('Starting script '||K_This_Script);  

  ins_purge('XDOCK_FLOATS_IN', 5, 'Cross Dock Inbound Float table ');
  ins_purge('XDOCK_FLOATS_OUT', 5, 'Cross Dock Outbound Float table ');
  ins_purge('XDOCK_FLOAT_DETAIL_IN', 5, 'Cross Dock Inbound Float Detail table ');
  ins_purge('XDOCK_FLOAT_DETAIL_OUT', 5, 'Cross Dock Outbound Float Detail ');
  ins_purge('XDOCK_MANIFEST_DTLS_IN', 10, 'Cross Dock Inbound  Manifest Details Table');
  ins_purge('XDOCK_MANIFEST_DTLS_OUT', 10, 'Cross Dock Outbound  Manifest Details Table');
  ins_purge('XDOCK_META_HEADER', 10, 'Cross Dock Meta Header ');
  ins_purge('XDOCK_ORDCW_IN', 5, 'Cross Dock Inbound  Order CW table');
  ins_purge('XDOCK_ORDCW_OUT', 5, 'Cross Dock Outbound  Order CW table');
  ins_purge('XDOCK_ORDD_IN', 5, 'Cross Dock Inbound  Order Detail');
  ins_purge('XDOCK_ORDD_OUT', 5, 'Cross Dock Outbound  Order Detail');
  ins_purge('XDOCK_ORDER_XREF', 10, 'Cross Dock Order Crossferent table  ');
  ins_purge('XDOCK_ORDM_IN', 5,'Cross Dock Inbound  Order Header Table');
  ins_purge('XDOCK_ORDM_OUT', 5, 'Cross Dock Outbound  Order Header Table');
  ins_purge('XDOCK_ORDM_ROUTING_IN', 10, 'Cross Dock Inbound  Order Header Routing Table');
  ins_purge('XDOCK_ORDM_ROUTING_OUT', 10, 'Cross Dock Outbound  Order Header Routing Table');
  ins_purge('XDOCK_PM_IN', 10, 'Cross Dock Inbound  Item table ');
  ins_purge('XDOCK_PM_OUT', 10, 'Cross Dock Outbound  Item Table ');
  ins_purge('XDOCK_RETURNS_IN', 10, 'Cross Dock Inbound  Returns Table ');
  ins_purge('XDOCK_RETURNS_OUT', 10, 'Cross Dock Outbound Returns Table ');



END;
/

commit;