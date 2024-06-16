/* Average length of stay for all surgeries, compare that to the length of stay
for individual surgeries */
with surgical_los as (
	select 
		surgery_id,
		(surgical_discharge_date - surgical_admission_date) as los,
		avg(surgical_discharge_date - surgical_admission_date)
			over () avg_los
	from general_hospital.surgical_encounters
	)
select 
	*,
	round(los - avg_los, 2) as over_under
from surgical_los;

/* Account balance ranking by diagnosis code (ICD) */
select
	account_id,
	primary_icd,
	total_account_balance,
	rank()
		over (partition by primary_icd
			order by total_account_balance desc)
	as account_rank_by_icd
from general_hospital.accounts;

/* Total profit and the sum total cost of all surgeries */
select 
	s.surgery_id,
	p.full_name,
	s.total_profit,
	avg(total_profit) over w as avg_total_profit,
	s.total_cost,
	sum(total_cost) over w as total_surgeon_cost
from general_hospital.surgical_encounters s
left outer join general_hospital.physicians p
	on s.surgeon_id = p.id
window w as (partition by s.surgeon_id);

