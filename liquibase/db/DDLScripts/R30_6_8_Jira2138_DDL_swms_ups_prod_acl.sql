/*************************************************************************
** Date:       25-JUL-2019
** File:       SWMS_STS_UPS_DML.sql
**
** Script to create ACL for UPS interface
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    25-JUL-2019 mcha1213
This script has to be run to set up the Host and port for the UPS PROD Interface Program
for each box its running from. 
****************************************************************************/
DECLARE
	acl_count Number;

Begin

	BEGIN
		SELECT count(*)
		INTO acl_count
        FROM dba_network_acls
        WHERE acl = '/sys/acls/ast.iship.xml';
	Exception when others
	then 	acl_count := 0;	
	
	End;

	If acl_count = 0 then

		BEGIN
			DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 'ast.iship.xml', description => 'Permission for SWMS to send data to UPS PROD server ', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
			--COMMIT;
		END;

		BEGIN
			DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 'ast.iship.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
			--COMMIT;
		END;

		begin
			--dbms_network_acl_admin.assign_acl(acl => 'shipexec.iship.xml',
			--	host => 'www.shipexec.iship.com', lower_port => 8000,upper_port => 8000);
                
			dbms_network_acl_admin.assign_acl(acl => 'ast.iship.xml',
				host => 'ast.iship.com', lower_port => null,upper_port => null);                
		end;

		commit; 
	End If;


End;
/
