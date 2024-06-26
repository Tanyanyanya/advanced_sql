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

/* Filter our patients table to take a look at patients who have had surgeries */
select *
from general_hospital.patients 
where master_patient_id in (
	select distinct master_patient_id from general_hospital.surgical_encounters
)
order by master_patient_id;

/* To look at patients who have not had surgery just add "not" before in */
select *
from general_hospital.patients 
where master_patient_id not in (
	select distinct master_patient_id from general_hospital.surgical_encounters
)
order by master_patient_id;

/* Another way to wright this with inner join */
select distinct p.master_patient_id
from general_hospital.patients p
inner join general_hospital.surgical_encounters s
	on p.master_patient_id = s.master_patient_id
order by p.master_patient_id;

/* Surgical procedures whose total profit is greater than the 
average cost for all diagnoses */ 
select *
from general_hospital.surgical_encounters
where total_profit > all(
	select avg(total_cost)
	from general_hospital.surgical_encounters
	group by diagnosis_description
	);

/* Diagnoses whose average length of stay is less than or equal to
the length of stay for all encounters by department */
select 
	diagnosis_description, 
	avg(surgical_discharge_date - surgical_admission_date)
		as length_of_stay
from general_hospital.surgical_encounters
group by diagnosis_description
having avg(surgical_discharge_date - surgical_admission_date) <=
	all(
		select 
			avg(extract(day from patient_discharge_datetime - patient_admission_datetime))
		from general_hospital.encounters
		group by department_id
	);


/* Units who saw all tipes of surgical cases or all types of surgical types, as the column is called */ 
select 
	unit_name,
	string_agg(distinct surgical_type, ',') as case_types
from general_hospital.surgical_encounters
group by unit_name
having string_agg (distinct surgical_type, ',') like all (
	select string_agg (distinct surgical_type, ',')
	from general_hospital.surgical_encounters
);

/* get all encounters with an order or all encounters with at least one order */ 
select e.*
from general_hospital.encounters e
where exists(
	select 1
	from general_hospital.orders_procedures o 
	where e.patient_encounter_id = o.patient_encounter_id
);


/* All patient who have not had surgery */
select p.*
from general_hospital.patients p
where not exists(
	select 1
	from general_hospital.surgical_encounters s
	where s.master_patient_id = p.master_patient_id
);


/* Recursive, Fibonacci sequence */
with recursive fibonacci as (
	select 1 as a, 1 as b
	union all 
	select b, a+b
	from fibonacci
)
select a, b
from fibonacci 
limit 15;

/* ---- */ 
with recursive orders as (
	select 
		order_procedure_id,
		order_parent_order_id,
		0 as level
	from general_hospital.orders_procedures
	where order_parent_order_id is null
	union all
	select
		op.order_procedure_id,
		op.order_parent_order_id,
		o.level + 1 as level 
	from general_hospital.orders_procedures op 
	inner join orders o on op.order_parent_order_id = o.order_procedure_id	
)
select *
from orders;

/* The average number of orders per encounter by provider/physician */
with provider_encounters as(
	select
		ordering_provider_id, 
		patient_encounter_id,
		count(order_procedure_id) as num_procedures
	from general_hospital.orders_procedures
	group by ordering_provider_id, patient_encounter_id
	),
	provider_orders as (
	select
		ordering_provider_id,
		avg(num_procedures) as avg_num_procedures
	from provider_encounters
	group by ordering_provider_id
	)
select 
	p.full_name,
	o.avg_num_procedures
from general_hospital.physicians p 
left outer join provider_orders o
	on p.id = o.ordering_provider_id
where o.avg_num_procedures is not null
order by o.avg_num_procedures desc;

/* Encounters with any of the top 10 most common order codes */
select distinct patient_encounter_id
from general_hospital.orders_procedures
where order_cd in (
	select order_cd
	from general_hospital.orders_procedures
	group by order_cd
	order by count(*) desc
	limit 10
);

/*Accounts with a total account balance over 10.000 and at least one ICU encounter */
select a.account_id, a.total_account_balance
from general_hospital.accounts a
where 
	total_account_balance > 10000
	and exists(
		select 1
		from general_hospital.encounters e
		where e.hospital_account_id = a.account_id
			and patient_in_icu_flag = 'Yes'
	);

/*Encouters for patients bor on or after 1995-01-01 whose lengh og stay is greater than or equea to the
average surgical length of stay for patients 65 or alder */
with old_los as(
	select
		extract(year from age(now(), p.date_of_birth)) as age,
		avg(s.surgical_discharge_date - s.surgical_admission_date) as avg_los
	from general_hospital.patients p 
	inner join general_hospital.surgical_encounters s
		on p.master_patient_id = s.master_patient_id
	where
		p.date_of_birth is not null 
		and extract (year from age(now(), p.date_of_birth)) >= 65
	group by extract (year from age (now(), p.date_of_birth))
	)
select e.*
from general_hospital.encounters e
inner join general_hospital.patients p 
	on e.master_patient_id = p.master_patient_id
	and p.date_of_birth >= '1995-01-01'
where 
	extract (days from (e.patient_discharge_datetime - e.patient_admission_datetime))
	>= all(
	select avg_los
	from old_los
	);
