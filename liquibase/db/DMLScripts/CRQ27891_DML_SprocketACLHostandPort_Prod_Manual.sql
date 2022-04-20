/*************************************************************************
** Date:       15-Aug-2017
** File:       SWMSSprocketACLHostandPort_prod.sql
**
** Script to insert Initial Alert Notification
**
**
** Modification History:
**    Date        Designer           Comments
**    -------- -------- ---------------------------------------------------
**    15-Aug-2017 Vishnupriya K.
This script has to be run to set up the Host and port for the Sproket Program
for prod box. 
Code sample to unassign a port is also given below to be used when necessary.
****************************************************************************/
DECLARE

begin
dbms_network_acl_admin.unassign_acl(acl => 'sprocket_webservice.xml',
host => 'rs242iib', lower_port => 7800, upper_port=> 7800);
end;
/
show errors;
commit;
begin
dbms_network_acl_admin.assign_acl(acl => 'sprocket_webservice.xml',
  host => 'ps247eai01', lower_port => 7080,upper_port => 7080);
end;
/
show errors;

commit;

