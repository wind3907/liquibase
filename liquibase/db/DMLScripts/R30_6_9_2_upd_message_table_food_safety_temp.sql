update message_table
  set v_message = 'Food Safety Temperature is not collected yet, manifest cannot be closed'
where id_message = 120166
and   ID_LANGUAGE = 3;

update message_table
  set v_message = 'Food Safety Temperature is not collected for items, Click OK to proceed to temperature collection screen'
where id_message = 120165
and   ID_LANGUAGE = 3;
