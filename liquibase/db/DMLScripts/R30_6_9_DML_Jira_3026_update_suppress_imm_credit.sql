update reason_cds
set suppress_imm_credit = 'Y'
where reason_cd_type = 'RTN'
and reason_cd in ('N01', 'N50', 'R40');

commit;