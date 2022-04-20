Update ml_values set text='For Cur. ' || chr(38) || 'Route' where FK_ML_MODULES=15793 and ID_LANGUAGE=3 and ID_FUNCTIONALITY=14;
Update ml_values set text= chr(38) || 'Rte courante' where FK_ML_MODULES=15793 and ID_LANGUAGE=12 and ID_FUNCTIONALITY=14;
Update ml_values set text='For Cur. ' || chr(38) || 'Wave'where FK_ML_MODULES=15794 and ID_LANGUAGE=3 and ID_FUNCTIONALITY=14;
Update ml_values set text= chr(38) || 'Lot courante' where FK_ML_MODULES=15794 and ID_LANGUAGE=12 and ID_FUNCTIONALITY=14;
COMMIT;