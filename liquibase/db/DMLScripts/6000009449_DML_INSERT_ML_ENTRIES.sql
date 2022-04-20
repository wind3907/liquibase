--Changes for R_30_3 for Charm 6000009449 French Conversion data new form built

--Insertions into the ml_modules and ml_values for menu name --


COL maxseq_no NOPRINT NEW_VALUE maxseq;

/* Get the max PK_ML_MODULES used in ML_MODULES table. */


SELECT MAX(PK_ML_MODULES) maxseq_no FROM ML_MODULES;

Insert into ML_MODULES (PK_ML_MODULES, NAME_FORM, OBJECT_TYPE, NAME_OBJECT, AUX_INFO1, AUX_INFO2, TYPE_FORM) Values (&maxseq + 1, 'ML_MOD_VAL', 18, 'EDIT', 'ML_MOD_VAL', NULL, 19);
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 1, 3, 14, 'Edit');
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 1, 12, 14, 'Editer');


Insert into ML_MODULES (PK_ML_MODULES, NAME_FORM, OBJECT_TYPE, NAME_OBJECT, AUX_INFO1, AUX_INFO2, TYPE_FORM) Values (&maxseq + 2, 'ML_MOD_VAL', 18, 'EXIT', 'ML_MOD_VAL', NULL, 19);
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 2, 3, 14, 'Exit');
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 2, 12, 14, 'E-Sortie');


Insert into ML_MODULES (PK_ML_MODULES, NAME_FORM, OBJECT_TYPE, NAME_OBJECT, AUX_INFO1, AUX_INFO2, TYPE_FORM) Values (&maxseq + 3, 'ML_MOD_VAL', 18, 'NEW', 'ML_MOD_VAL',  NULL, 19);
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 3, 3, 14, 'New');
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 3, 12, 14, 'Nouveau');


Insert into ML_MODULES (PK_ML_MODULES, NAME_FORM, OBJECT_TYPE, NAME_OBJECT, AUX_INFO1, AUX_INFO2, TYPE_FORM) Values (&maxseq + 4, 'ML_MOD_VAL', 18, 'CLEAR', 'ML_MOD_VAL', NULL, 19);
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 4, 3, 14, 'clear');
Insert into ML_VALUES (FK_ML_MODULES, ID_LANGUAGE, ID_FUNCTIONALITY, TEXT) Values (&maxseq + 4, 12, 14, 'Clair');

commit;


