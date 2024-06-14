/* Subquery simple example */
select * 
	from (
	select * 
	from general_hospital.patients
	where date_of_birth >= '2000.01.01'
	order by master_patient_id
	) p
where p.name ilike 'c%';


/* Subquery example with performing complex calculations */
select * 
from(
	select * 
	from general_hospital.surgical_encounters
	where surgical_admission_date 
		between '2016-11-01' and '2016-11-30';
) se
inner join (
	select master_patient_id
	from general_hospital.patients
	where date_of_birth <= '1999-01-01'
) p on se.master_patient_id = p.master_patient_id;

/* Rewriting a subquery from ^ */

with young_patients as (
	select *
	from general_hospital.patients 
	where date_of_birth >= '2000-01-01'
)
select * 
/* Instead of referring to a table in database, we'll
refer to this common table expression */ 
from young_patients
where name ilike 'm%';


/* The number of surgeries by county, for counties more than 5500 patients */ 
with  top_counties as (
	select
		county,
		count(*) as num_patients
	from general_hospital.patients
	group by county
	having count(*) > 1500
	),
	county_patients as (
		select
			p.master_patient_id,
			p.county
		from general_hospital.patients p
		/* Join the patients table, the common table expression
		that we just wrote above */
		inner join top_counties t on 
			p.county = t.county
	)
select 
	p.county,
	count(s.surgery_id) as num_surgeries
from general_hospital.surgical_encounters s 
inner join county_patients p on
	s.master_patient_id = p.master_patient_id
group by p.county;



/* Look at surgeries where the total cost is greater than the
average total cost */ 

with total_cost as (
	select 
		surgery_id,
		sum(resource_cost) as total_surgery_cost
	from general_hospital.surgical_costs
	group by surgery_id
	)
select *
from total_cost
where total_surgery_cost > (
	select avg(total_surgery_cost)
	from total_cost
);


select * 
from general_hospital.vitals
where 
	bp_diastolic > (select min(bp_diastolic) from general_hospital.vitals)
	and bp_systolic < (select max(bp_systolic) from general_hospital.vitals)
;
