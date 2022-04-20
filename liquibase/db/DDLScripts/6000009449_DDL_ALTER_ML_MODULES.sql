/***  Disabling the Constraint in ML_MODULES Table  ***/ 

ALTER TABLE swms.ml_modules
  MODIFY (OBJECT_TYPE  NUMBER NULL
          );