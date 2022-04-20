/*************************************************************************
** Date:       08-Jan-2018
** File:       SWMSSprocketACLHostandPort_prod.sql
**
** 
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    08-Jan-2018 Vishnupriya K.
This script has to be run to set up the Host and port for the Sproket Program
for prod box. 
Code to unassign a port is also given below to be used when necessary.
****************************************************************************/
DECLARE

begin
dbms_network_acl_admin.unassign_acl(acl => 'sprocket_webservice.xml',
host => 'ps247eai01', lower_port => 7080, upper_port=> 7080);
end;
/
show errors;
commit;
begin
dbms_network_acl_admin.assign_acl(acl => 'sprocket_webservice.xml',
  host => 'iib.aws.na.sysco.net', lower_port => 7080,upper_port => 7080);
end;
/
show errors;

commit;

