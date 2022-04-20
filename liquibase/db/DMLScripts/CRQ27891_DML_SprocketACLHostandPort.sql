/*************************************************************************
** Date:       05-May-2017
** File:       SWMSSprocketACLHostandPort.sql
**
** Script to insert Initial Alert Notification
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    05-May-2017 Vishnupriya K.
This script has to be run to set up the Host and port for the Sproket Program
for each box its running from. When run this program prompts for
Host, LowerPort, UpperPort
For host enter the value in quotes (example 'rs242iib' )
Code sample to unassign a port is also given below to be used when necessary.
****************************************************************************/
DECLARE
acl_count Number;
Begin

BEGIN
 SELECT count(*)
       INTO acl_count
        FROM dba_network_acls
        WHERE acl = '/sys/acls/sprocket_webservice.xml';
Exception when others
then 	acl_count := 0;	
	
End;

If acl_count = 0 then

BEGIN
  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 'sprocket_webservice.xml', description => 'Permissions to invoke Sprocket web services', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
  COMMIT;
END;

BEGIN
  DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 'sprocket_webservice.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
  COMMIT;
END;

begin
dbms_network_acl_admin.assign_acl(acl => 'sprocket_webservice.xml',
  host => 'rs242iib', lower_port => 7800,upper_port => 7800);
end;

commit;
End If;

End;
/
