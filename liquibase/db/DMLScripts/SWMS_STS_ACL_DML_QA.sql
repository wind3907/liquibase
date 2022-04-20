/*************************************************************************
** Date:       28-OCT-2018
** File:       SWMS_STS_ACL_DML.sql
**
** Script to create ACL for STS_SAE_APICentral
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    28-OCT-2018 Vishnupriya K.
This script has to be run to set up the Host and port for the STS Out Program
for each box its running from. 
****************************************************************************/
DECLARE
  acl_count Number;
  acl_count2 Number;
Begin

  BEGIN
    SELECT count(*)
        INTO acl_count
      FROM dba_network_acls
        WHERE acl = '/sys/acls/swms_sts_server_a.xml';
  Exception 
    when others then 	
      acl_count := 0;	
  End;

  If acl_count = 0 then

    BEGIN
      DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 'swms_sts_server_a.xml', description => 'Permission for SWMS to send data to STS server a', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;

    BEGIN
      DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 'swms_sts_server_a.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;

    $if swms.platform.SWMS_REMOTE_DB $then
      BEGIN
        dbms_network_acl_admin.assign_acl(acl => 'swms_sts_server_a.xml', host => 'ms240stsswms01q.na.sysco.net', lower_port => 8000,upper_port => 8000);
      END;
    $else
      BEGIN
        dbms_network_acl_admin.assign_acl(acl => 'swms_sts_server_a.xml', host => 'ms240stsswms01q', lower_port => 8000,upper_port => 8000);
      END;
    $end

    commit; 
  End If;


  BEGIN
    SELECT count(*)
        INTO acl_count2
      FROM dba_network_acls
        WHERE acl = '/sys/acls/swms_sts_server_b.xml';
  Exception when others then 
    acl_count2 := 0;	
	End;

  If acl_count2 = 0 then

    BEGIN
      DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 'swms_sts_server_b.xml', description => 'Permission for SWMS to send data to STS server b', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;

    BEGIN
      DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 'swms_sts_server_b.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
      COMMIT;
    END;

    $if swms.platform.SWMS_REMOTE_DB $then
      BEGIN
        dbms_network_acl_admin.assign_acl(acl => 'swms_sts_server_b.xml', host => 'ms240stsswms02q.na.sysco.net', lower_port => 8000,upper_port => 8000);
      END;
    $else
      BEGIN
        dbms_network_acl_admin.assign_acl(acl => 'swms_sts_server_b.xml', host => 'ms240stsswms02q', lower_port => 8000,upper_port => 8000);
      END;
    $end
    commit; 
  End If;

End;
/
