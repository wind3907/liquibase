/* Replace original message: Inbound accessory tracking might be needed.		        Collect information now */
/* New message: Inbound accessory tracking is needed. Yes requires accessory collection in another screen and manifest will not be closed. */
update message_table
  set v_message = 'Inbound accessory tracking is needed. Yes requires accessory collection and manifest will NOT be closed. No option will continue closing manifest without inbound collection.'
where id_language=3
and   id_message=11417;

update ml_values
  set text='No'
where fk_ml_modules=12236
and id_language=3
and id_functionality=4;
