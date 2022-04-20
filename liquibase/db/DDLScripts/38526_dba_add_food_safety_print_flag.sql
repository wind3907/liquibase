/****************************************************************************
** Date:       22-JAN-2013
** Programmer: Bhageshri Gulvady
** File:       38526_dba_add_food_safety_print_flag.sql
** CRQ#:       38526	 
** 
** This script adds a field called 'FOOD_SAFETY_PRINT_FLAG' in erm table
******************************************************************************/
ALTER TABLE SWMS.ERM 
ADD FOOD_SAFETY_PRINT_FLAG varchar2(1);
