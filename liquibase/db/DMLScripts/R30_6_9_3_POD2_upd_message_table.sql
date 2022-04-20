update message_table
 set v_message = 'Item is not configured as Food Safety hazardous code for temperature collection'
where id_message=6600
and id_language=3;

update message_table
 set v_message = 'Manifest does not have any item with hazardous code that requires Food Safety Temp Collection'
where id_message=6595
and id_language=3;
