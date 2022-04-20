delete message_table where id_message in (119980, 119981);
insert into message_table (id_message, id_language, v_message)
  values (119980, 3, 'Unable to add location %s1');
insert into message_table (id_message, id_language, v_message)
  values (119980, 12, 'Impossible d''ajouter l''emplacement %s1');
insert into message_table (id_message, id_language, v_message)
  values (119981, 3, 'Unable to add location %s1 for zone %s2');
insert into message_table (id_message, id_language, v_message)
  values (119981, 12,
  'Impossible d''ajouter l''emplacement %s1 pour la zone %s2');
commit;
