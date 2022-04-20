/*************************************************************************
** Date:       27-10-21 
**
** Script to add network ACLs needed for R1
**
****************************************************************************/
DECLARE
	acl_count Number;
	https_enabled  VARCHAR2(20);
	msg_hub_host VARCHAR2(200);
BEGIN    
        SELECT config_flag_val INTO msg_hub_host FROM system_xdock_config where config_flag_name = 'S2S_HTTP_URL';
		SELECT config_flag_val INTO https_enabled FROM system_xdock_config where config_flag_name = 'S2S_HTTPS_ENABLED';
	
		SELECT count(*) INTO acl_count FROM DBA_NETWORK_ACLS
			WHERE acl = '/sys/acls/s2s_hub.xml';

		IF acl_count > 0 THEN
			IF https_enabled = 'Y' THEN
				DBMS_NETWORK_ACL_ADMIN.UNASSIGN_ACL(acl => 's2s_hub.xml', host => msg_hub_host, lower_port => 443, upper_port => 443);
			ELSE
                DBMS_NETWORK_ACL_ADMIN.UNASSIGN_ACL(acl => 's2s_hub.xml', host => msg_hub_host, lower_port => 80, upper_port => 80);
            END IF;
            
            DBMS_NETWORK_ACL_ADMIN.DELETE_PRIVILEGE ( acl => 's2s_hub.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
            DBMS_NETWORK_ACL_ADMIN.DROP_ACL ( acl => 's2s_hub.xml');
            COMMIT;
		END IF;
		
		BEGIN
			DBMS_NETWORK_ACL_ADMIN.CREATE_ACL ( acl => 's2s_hub.xml', description => 'Permission for SWMS to invoke s2s hub API', principal => 'PUBLIC', is_grant => TRUE, privilege => 'connect' );
			COMMIT;
		END;
		BEGIN
			DBMS_NETWORK_ACL_ADMIN.add_privilege ( acl => 's2s_hub.xml', principal => 'SWMS', is_grant => TRUE, privilege => 'connect' );
			COMMIT;
		END;
		BEGIN
			IF https_enabled = 'Y' THEN
      			DBMS_NETWORK_ACL_ADMIN.assign_acl(acl => 's2s_hub.xml', host => msg_hub_host, lower_port => 443, upper_port => 443);
            ELSE
                DBMS_NETWORK_ACL_ADMIN.assign_acl(acl => 's2s_hub.xml', host => msg_hub_host, lower_port => 80, upper_port => 80);
            END IF;
		END;
		COMMIT;
END;
/

