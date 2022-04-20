/*************************************************************************
** Date:       18-OCT-2018
** File:       SWMS_STS_ACL_DML.sql
**
** Script to create ACL for STS_SAE_APICentral
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    28-Aug-2018 Vishnupriya K.
This script has to be run to set up the Host and port for the STS Out Program
for each box its running from. 
****************************************************************************/
DECLARE
  acl_count Number;
Begin
  BEGIN
    SELECT count(*)
        INTO acl_count
      FROM dba_network_acls
        WHERE acl = '/sys/acls/swms_sts_route.xml';
  Exception
    when others then
      acl_count := 0;	
  End;

  If acl_count = 0 then
    BEGIN
      DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 'swms_sts_route.xml', description => 'Permission for SWMS to invoke STSSAE web services', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;

    BEGIN
      DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 'swms_sts_route.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;
    --http://ms240stshh01t:8000/DriverPro/CommService?wsdl
    $if swms.platform.SWMS_REMOTE_DB $then
      BEGIN
        DBMS_NETWORK_ACL_ADMIN.assign_acl(acl => 'swms_sts_route.xml', host => 'ms240stshh01t.na.sysco.net', lower_port => 8000,upper_port => 8000);
      END;
    $else
      BEGIN
        DBMS_NETWORK_ACL_ADMIN.assign_acl(acl => 'swms_sts_route.xml', host => 'ms240stshh01t', lower_port => 8000,upper_port => 8000);
      END;
    $end

    COMMIT;
  End If;

End;
/
