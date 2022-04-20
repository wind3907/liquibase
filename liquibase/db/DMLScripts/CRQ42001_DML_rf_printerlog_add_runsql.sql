merge into swms.scripts using dual on (option_no = 208)
when matched then update set
	script_name = 'rf_printerlog_rpt.sh',
	application_func= 'RF',
	restartable ='N',
	run_count = 0,
	update_function = 'N',
--	option_no = 208,
	display_help = 'This script generates a report of RF printer connections and exceptions.'
when not matched then insert(
	script_name,
	application_func,
	restartable,
	run_count,
	update_function,
	option_no,
	display_help)
values(
	'rf_printerlog_rpt.sh',
	'RF',
	'N',
	0,
	'N',
	208,
	'This script generates a report of RF printer connections and exceptions.');
