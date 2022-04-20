/****************************************************************************
** File:       CRQ34059_DML_INSERT_ml_modules_values.sql
**
** Modification History:
**    Date        Designer           Comments
**    -------- 	  -------- 		---------------------------------------------------
**	  06/10/17    chyd9155		CRQ34059-POD project iteration 2
**	  06/12/17	  CHYD9155          DDL and DML standardization for merge  
****************************************************************************/


Insert into SWMS.ML_MODULES (PK_ML_MODULES,NAME_FORM,OBJECT_TYPE,NAME_OBJECT,AUX_INFO1,AUX_INFO2,TYPE_FORM)
Select 102205,'rtnsdtl',13,'POD_FLAG','DETAIL',NULL,10 from dual
Where not exists (select 1 from ml_modules m2 where m2.pk_ml_modules = 102205);


Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)
select 102205,3,15,'POD 
Flag' from dual
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102205 and m2.id_language=3 and m2.id_functionality=15);

Insert into SWMS.ML_VALUES (FK_ML_MODULES,ID_LANGUAGE,ID_FUNCTIONALITY,TEXT)
select 102205,12,15,'POD
drapeau' from dual
where not exists (select 1 from ml_values m2 where m2.fk_ml_modules=102205 and m2.id_language=12 and m2.id_functionality=15);

COMMIT;

