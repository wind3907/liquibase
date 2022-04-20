update ml_values
  set text = 'Res:'
where id_language=3
and fk_ml_modules=14213
and id_functionality=15;

commit;
