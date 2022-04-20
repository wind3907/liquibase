DELETE FROM swms.scripts
 WHERE script_name IN ( 's2s_ck_manifests_opn.sh',
                        's2s_ck_route_opn.sh',
                        's2s_ck_replenlst.sh',
                        's2s_ck_cc.sh',
                        's2s_ck_erm_opn.sh',
                        's2s_ck_putawaylst.sh'
                        );
COMMIT;

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_manifests_opn.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-p12',
           '  Used while converting SAP to SUS, verifies all open manifests.' );

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_route_opn.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-p12',
           '  Used while converting SAP to SUS, verifies that all routes are closed.' );

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_replenlst.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-z1 -p12',
           '  Used while converting SAP to SUS, verifies that there are no pending replenishments.' );

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_cc.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-z1 -p12',
           '  Used while converting SAP to SUS, verifies all remaining cycle counts.' );

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_erm_opn.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-p12',
           '  Used while converting SAP to SUS, verifies that no purchase orders are open.' );

INSERT INTO swms.scripts ( script_name, application_func, restartable, run_count,
                           last_run_date, last_run_user, update_function, print_options,
                           display_help )
  VALUES ( 's2s_ck_putawaylst.sh', 'CONVERSION', 'Y', 0,
           NULL, NULL, 'N', '-z1 -p12',
           '  Used while converting SAP to SUS, verifies all pending putaways.' );


COMMIT;

