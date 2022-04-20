-- Similar to the existing ISUIT
INSERT INTO swms.job_code (
	jbcd_job_code, jbcl_job_class, lfun_lbr_func, whar_area,
	engr_std_flag, mask_lvl, descrip, corp_code)
VALUES (
	'ICHJOB', 'IN', 'IN', 'D',
	'N', 4, 'LOGOUT OUT JOB CODE CHANGE', 'N')
/
COMMIT
/
