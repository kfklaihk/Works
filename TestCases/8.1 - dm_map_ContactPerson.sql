/*
15/02/2024  Paul Pang      Remove logic to assign client_uuid for the "same" person
16/02/2024	Paul Pang	   Remove logic of update eff_date - 1 for records with seq_no>1
16/02/2024	Paul Pang	   Remove logic of update client_uuid by id
29/02/2024	Paul Pang	   Reactivate the logic to update eff_date 
18/03/2024	Paul Pang	   Update DIRECTOR refer to EMPLOYER_ACCT records instead of EMPLOYER records; 
19/03/2024	Paul Pang	   Fix trustee_entty_cd of withdrawal case (need further enhancement)
13/05/2024  Zach Wong      Fix ORO and Claimant contacts.
17/05/2024	Paul Pang	   Update nationality to null when it is "NOTED"
03/06/2024  Don Leung      DL20240603 Skip AP type in cmn_client_contact_person table, only keep in history table
07/06/2024	Winnie Lau	   WL-070624 contact person fix
12/06/2024	Winnie Lau	   WL-120624 contact person fix using NATIONALITY_3 = OTHER
15/06/2024	Winnie Lau	   WL-150624 contact person fix client_uuid
27/06/2024	Winnie Lau	   WL-270624 keep cmn_client_contact_person_hst for AP but remove in later step
03/07/2024	Winnie Lau	   WL-030724 fix cmn_client_contact_person_hst.id, not to use cmn_client_contact_person.id
04/07/2024	Winnie Lau	   WL-040724 rolback WL-030724 change id
06/07/2024	Winnie Lau	   WL-060724 add step to insert primary and secondary contact using dm table
09/07/2024	Paul Pang	   Fix av_client_type logic
11/07/2024	Winnie Lau	   WL-110724 copy primary contact person but not secondary person
25/08/2024	Winnie Lau	   WL-250824 handle THIRD_PAYOR
26/08/2024	Winnie Lau	   WL-260824 handle THIRD_PAYOR copy to payroll group
27/08/2024	Winnie Lau	   WL-270824 handle THIRD_PAYOR for SEP
09/09/2024	Winnie Lau	   WL-090924 fix payroll group value for primary contact 
17/09/2024	Winnie Lau	   WL-170924 handle THIRD_PAYOR for TVC SVC
03/10/2024	Winnie Lau	   WL-031024 use upper for payroll grouop
11/11/2024	Winnie Lau	   WL-111124 handle THIRD_PAYOR for er_acct and pg level separately
21/11/2024	Winnie Lau	   WL-211124 fix THIRD_PAYOR nation_3
21/11/2024	Winnie Lau	   WL-221124 fix THIRD_PAYOR er_acct level
--17/12/2024 Glenn Yi      GY-171242 save nation_code3 = 'OTHER' records 
13/02/2025  Glenn Yi	   GY20250213 fix UPPER() issue
21/02/2025	Winnie Lau	   WL-210225 fix AP status
25/02/2025  Glenn Yi       GY20250225  change del table to truncate table
28/02/2025  George Ngai		Fix cycle_change_date
03/03/2025  George Ngai		Add parallel
20/03/2025 Glenn Yi        GY20250320 fix AP av_client_type for MT 
07/04/2025 Glenn Yi        GY20250407 change controlling person from EMPLOYER TO EMPLOYER_ACCT
16/05/2025 Justin Leung    JL20250516 Add logic to include company as DIRECTOR/BENE_OWNER records
06/06/2025 Justin Leung    JL20250606 Fix director/bene_owner insert
21/07/2025	Winnie Lau	   WL-210725 not to copy primary contact from PG to ER_ACCT if gov plan
29/07/2025	Winnie Lau	   WL-290725 primary contact copy to er_acct from earliest active pg only
21/08/2025	Winnie Lau	   WL20250821 fix wording ACTIVE
03/09/2025	Frank He	   FH-030925 add DATE_OF_BIRTH field, and data migrate from dm table to cas table
10/09/2025  Justin Leung   JL20250910 
						       1. Add date_of_birth mapping. For 'DIRECTOR','BENE_OWNER','PARTNER', map the value from correlated person file. For 'SOL' and 'CTP', map the value from crs file
							   2. Add company_flag mapping. Map company_nm and company_chinese_nm to last_name and lastname_zhhk
21/10/2025  Justin Leung   JL20251021 Fix date format issue
04/11/2025  Justin Leung   JL20251104 Fix missing company_flag in cmn_client_contact_person_hst
16/12/2025  Justin Leung   JL20251216 Set date_of_birth to NULL for type_com_related_person not in ('DIRECTOR','BENE_OWNER','PARTNER','SOL','CTP')
*/
SET SERVEROUT ON SIZE 1000000;
declare

    v_scheme_uuid cmn_scheme.id%TYPE; 
    v_cp_uuid cmn_client_contact_person.id%TYPE;
    v_acct_uuid cmn_client_contact_person.client_uuid%TYPE;
    v_client_type cmn_client_contact_person.av_client_type%TYPE;
    v_cycle_change_date date;
    V_COUNT NUMBER(10);
    v_user  cmn_client_contact_person.created_by%TYPE;
    v_xcpt_msg   char(2);
    --alter table CMN_CLIENT_CONTACT_PERSON disable constraint CMN_CLIENT_CONTACT_PERSON_UK1

begin
    dbms_output.put_line ('Start time:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));

    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
    END;

	--WL20250821 begin
    --v_user := '00000000000000000000000000000000|' || user;
	-- JL20251021 begin
	-- v_user := 'DM &&1 WL20250821';
	v_user := 'DM &&1 JL20251021';
	-- JL20251021 end
	--WL20250821 end
    -- select to_char(SYSDATE,'DD-MON-YYYY') into v_cycle_change_date from cmn_scheme_cycle where scheme_code = '&&1' and cycle_date_step_code = '0';
	select cycle_date into v_cycle_change_date from cmn_scheme_cycle where scheme_code = '&&1' AND cycle_date_step_code = 0;
    select id into v_scheme_uuid from cmn_scheme where scheme_code = '&&1';

    dbms_output.put_line ('START:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));  
	
	--GY20250225  begin
	EXECUTE IMMEDIATE 'TRUNCATE TABLE cccp_ini_temp';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE cccp_temp';
	EXECUTE IMMEDIATE 'TRUNCATE TABLE cmn_client_contact_person';
	EXECUTE IMMEDIATE 'TRUNCATE TABLE cmn_client_contact_person_hst';
    delete /*+ PARALLEL(16) */ from cmn_client where scheme_code = '&&1' and created_by like '&&1' || '_XCP%' ;   
	EXECUTE IMMEDIATE 'TRUNCATE TABLE tmp_cmn_client_contact_person_clone';
	
	--GY20250225  end

	commit;
	
    dbms_output.put_line ('START INSERT:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));  
    insert /*+ PARALLEL(16) */ into cccp_ini_temp
        (scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
        client_uuid, av_client_type, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth)
		--FH-030925 end
    select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd, emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
        null, null, null, null as eff_date
		--FH-030925 begin
		, to_date(date_of_birth,'YYYY-MM-DD') as date_of_birth
		--FH-030925 end
    from dm_correlated_person 
    --WL-070624 begin
	--where scheme_code = '&&1'  and type_com_related_person not in ('ORO', 'TIB')
	--WL-111124 begin
	--where scheme_code = '&&1'  and type_com_related_person not in ('ORO', 'TIB', 'PRIMARY_CONTACT', 'SECOND_CONTACT')
	where scheme_code = '&&1'  and type_com_related_person not in ('ORO', 'TIB', 'PRIMARY_CONTACT', 'SECOND_CONTACT', 'THIRD_PAYOR')
	--WL-111124 end
	--WL-070624 end
    --and rownum <=5
    ;
	commit;
    
	--WL-060724 begin
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date
			--FH-030925 begin
			, date_of_birth)
			--FH-030925 end
	select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd
			--WL-090924 begin
			--, null as emplr_payroll_group
			, dmc.emplr_payroll_group as emplr_payroll_group
			--WL-090924 end
			, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			CASE
                WHEN dmc.EMPLR_PAYROLL_GROUP IS NULL THEN 
					(select eracct.id from enr_er_acct eracct 
					where dmc.trustee_entty_cd = eracct.tr_employer_code 
					and eracct.scheme_code = '&&1')
                ELSE 
					(select b.id from enr_er_acct a, enr_payroll_group b 
					where a.scheme_code = '&&1'
					and a.tr_employer_code = dmc.trustee_entty_cd
					and a.id = b.er_acct_uuid
					--WL-031024 begin
					--and b.payroll_group_short_name = dmc.emplr_payroll_group 
					and b.payroll_group_short_name = upper(dmc.emplr_payroll_group)
					--WL-031024 end
					and b.scheme_code = '&&1')
            END				
			, decode(EMPLR_PAYROLL_GROUP, NULL, 'EMPLOYER_ACCT', 'PAYROLL_GROUP'), null, null as eff_date
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end			
	from DM_CORRELATED_PERSON dmc
	where scheme_code = '&&1'
	and type_com_related_person in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	;
	--WL-060724 end
	commit;
	
	--WL-070624 begin
	--WL-110724 remove begin
	/*
	--1. er acct: pg is null	
	insert into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date)
	select	'&&1', trustee_entty_cd, null as emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			--WL-150624 begin
			--null
			(select eracct.id from enr_er_acct eracct where dmc.trustee_entty_cd = eracct.tr_employer_code and eracct.scheme_code = '&&1') as client_uuid
			--WL-150624 end
			, 'EMPLOYER_ACCT', null, null as eff_date			
	from DM_CORRELATED_PERSON dmc
	where scheme_code = '&&1'
	and type_com_related_person in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	and EMPLR_PAYROLL_GROUP is null
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		--and tmpc.av_contact_person_type = dmc.type_com_related_person
		and tmpc.av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
		and tmpc.av_client_type = 'EMPLOYER_ACCT'
		)
	;
	*/
	--WL-110724 remove end
	
	--2 er acct: pg is not null
	--WL-120624 change
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date
			--FH-030925 begin
			, date_of_birth)
			--FH-030925 end
	select /*+ PARALLEL(16) */ distinct 
			'&&1', trustee_entty_cd, null as emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, 'OTHER' as nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			--WL-150624 begin
			--null
			(select eracct.id from enr_er_acct eracct where dmc.trustee_entty_cd = eracct.tr_employer_code and eracct.scheme_code = '&&1') as client_uuid
			--WL-150624 end
			, 'EMPLOYER_ACCT', null, null as eff_date
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end	
	from DM_CORRELATED_PERSON dmc
	where scheme_code = '&&1'
	--WL-110724 only PRIMARY_CONTACT
	--and type_com_related_person in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	and type_com_related_person in ('PRIMARY_CONTACT')
	and EMPLR_PAYROLL_GROUP is not null
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		--and tmpc.av_contact_person_type = dmc.type_com_related_person
		--WL-110724 only PRIMARY_CONTACT
		--and tmpc.av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
		and tmpc.av_contact_person_type in ('PRIMARY_CONTACT')
		and tmpc.av_client_type = 'EMPLOYER_ACCT'
		)
	--WL-210725 begin
	and not exists (select 'x'		
		from dm_employer er 
		where er.scheme_code = '&&1' 
		and er.trustee_emplr_cd = dmc.trustee_entty_cd
		and upper(er.company_nm) = 'THE GOVERNMENT OF THE HONG KONG SPECIAL ADMINISTRATIVE REGION'		
		)
	--WL-210725 end
	--WL-290725 begin
	and nvl(upper(dmc.emplr_payroll_group),'@') = 
		(select nvl(upper(pg2.payroll_group_short_name),'@')
		from (select pg1.*
			from enr_payroll_group pg1
			--WL20250821 begin
			--where pg1.av_status_code = 'ACTVIE'
			where pg1.av_status_code = 'ACTIVE'
			--WL20250821 end
			and pg1.er_acct_uuid = (select eracct2.id from enr_er_acct eracct2 
				where dmc.trustee_entty_cd = eracct2.tr_employer_code and eracct2.scheme_code = '&&1')
			order by pg1.eff_date asc
			) pg2
		where rownum = 1)
	--WL-290725 end
	;
	commit;
	
	--WL-110724 remove begin
	/*
	--3 payroll group: pg is not null
	insert into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date)
	select '&&1', trustee_entty_cd, emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			(select b.id from enr_er_acct a, enr_payroll_group b 
				where a.scheme_code = '&&1'
				and a.tr_employer_code = dmc.trustee_entty_cd
				and a.id = b.er_acct_uuid
				and b.payroll_group_short_name = dmc.emplr_payroll_group 
				and b.scheme_code = '&&1') as client_uuid, 
			'PAYROLL_GROUP', null, null as eff_date			
	from DM_CORRELATED_PERSON dmc
	where scheme_code = '&&1'
	and type_com_related_person in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	and EMPLR_PAYROLL_GROUP is not null
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		--and tmpc.av_contact_person_type = dmc.type_com_related_person
		and tmpc.av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
		and tmpc.av_client_type = 'PAYROLL_GROUP'
		and tmpc.emplr_payroll_group = dmc.emplr_payroll_group
		)
	;
	*/
	--WL-110724 remove end
	
	--4 payroll group: pg is null	
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date
			--FH-030925 begin
			, date_of_birth)
			--FH-030925 end
	select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd, payroll_group_short_name as emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, 'OTHER' as nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			pg.id, 'PAYROLL_GROUP', null, null as eff_date
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end	
	from DM_CORRELATED_PERSON dmc, enr_er_acct eracct, enr_payroll_group pg
	where dmc.scheme_code = '&&1'
	--WL-110724 only PRIMARY_CONTACT
	--and dmc.type_com_related_person in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	and dmc.type_com_related_person in ('PRIMARY_CONTACT')
	and dmc.EMPLR_PAYROLL_GROUP is null
	and eracct.tr_employer_code = dmc.TRUSTEE_ENTTY_CD
	and eracct.id = pg.er_acct_uuid
	and pg.AV_STATUS_CODE = 'ACTIVE'
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		--and tmpc.av_contact_person_type = dmc.type_com_related_person
		--WL-110724 only PRIMARY_CONTACT
		--and tmpc.av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
		and tmpc.av_contact_person_type in ('PRIMARY_CONTACT')		
		and tmpc.av_client_type = 'PAYROLL_GROUP'
		--WL-110724 handle null
		--GY20250213  begin
		--and nvl(tmpc.emplr_payroll_group,'@') = nvl(pg.payroll_group_short_name,'@')
		and nvl(upper(tmpc.emplr_payroll_group),'@') = nvl(upper(pg.payroll_group_short_name),'@')
		--GY20250213  end
		)
	;
	--WL-070624 end
	commit;
	
	--WL-111124 begin
	--tihrd payor er_acct or pg level
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
        (scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
        client_uuid, av_client_type, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth)
		--FH-030925 end
	select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd
			, dmc.emplr_payroll_group as emplr_payroll_group
			, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			CASE
                WHEN dmc.EMPLR_PAYROLL_GROUP IS NULL THEN 
					(select eracct.id from enr_er_acct eracct 
					where dmc.trustee_entty_cd = eracct.tr_employer_code 
					and eracct.scheme_code = '&&1')
                ELSE 
					(select b.id from enr_er_acct a, enr_payroll_group b 
					where a.scheme_code = '&&1'
					and a.tr_employer_code = dmc.trustee_entty_cd
					and a.id = b.er_acct_uuid
					and b.payroll_group_short_name = upper(dmc.emplr_payroll_group)
					and b.scheme_code = '&&1')
            END				
			, decode(EMPLR_PAYROLL_GROUP, NULL, 'EMPLOYER_ACCT', 'PAYROLL_GROUP'), null, null as eff_date	
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end				
	from DM_CORRELATED_PERSON dmc
	where scheme_code = '&&1'
	and type_com_related_person = 'THIRD_PAYOR'	
	and exists (select 'x' 
	--WL-221124 begin
		from dm_employer dmer
		where dmer.trustee_emplr_cd = dmc.trustee_entty_cd
		and dmer.scheme_code = '&&1'
		)
		-- from enr_er_acct eracct 
		-- where eracct.scheme_code = '&&1' 
		-- and eracct.tr_employer_code = dmc.TRUSTEE_ENTTY_CD)		
	--WL-221124 end
    ;	
	--WL-111124 end
	commit;
	
	--WL-260824 begin
	--third payor copy from er_acct to pg if dm pg is null	
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date
			--FH-030925 begin
			, date_of_birth)
			--FH-030925 end
	select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd, payroll_group_short_name as emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2, 'OTHER' as nationality_3, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			pg.id, 'PAYROLL_GROUP', null, null as eff_date
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end	
	from DM_CORRELATED_PERSON dmc, enr_er_acct eracct, enr_payroll_group pg
	where dmc.scheme_code = '&&1'
	and dmc.type_com_related_person in ('THIRD_PAYOR')
	and dmc.EMPLR_PAYROLL_GROUP is null
	and eracct.tr_employer_code = dmc.TRUSTEE_ENTTY_CD
	and eracct.id = pg.er_acct_uuid
	and pg.AV_STATUS_CODE = 'ACTIVE'
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		and tmpc.av_contact_person_type in ('THIRD_PAYOR')		
		and tmpc.av_client_type = 'PAYROLL_GROUP'
		
		--GY20250213  begin
		--and nvl(tmpc.emplr_payroll_group,'@') = nvl(pg.payroll_group_short_name,'@')
		and nvl(upper(tmpc.emplr_payroll_group),'@') = nvl(upper(pg.payroll_group_short_name),'@')
		--GY20250213  begin
		)
	;	
	--WL-260824 end
	commit;
	
	--WL-270824 begin
	--third payfor for SEP, TVC, SVC
	insert /*+ PARALLEL(16) */ into cccp_ini_temp
			(scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
			mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
			client_uuid, av_client_type, client_type_seq_no, eff_date
			--FH-030925 begin
			, date_of_birth)
			--FH-030925 end
	select /*+ PARALLEL(16) */ '&&1', trustee_entty_cd, null as emplr_payroll_group, type_com_related_person, first_nm, last_nm, chinese_first_nm, chinese_last_nm, job_position,own_percentage,
			mbr_communication_type, nationality_1, nationality_2
			--WL-211124 begin
			--, 'OTHER' as nationality_3
			, nationality_3
			--WL-211124 end
			, related_person_id, (case when occupation = 'Not Provided' then null else occupation end), 
			pg.PAYROLL_GROUP_UUID, 'PAYROLL_GROUP', null, pg.eff_date as eff_date
			--FH-030925 begin
			, to_date(dmc.date_of_birth,'YYYY-MM-DD') as date_of_birth
			--FH-030925 end	
	from DM_CORRELATED_PERSON dmc, enr_mem_acct memacct, ENR_MEM_ACCT_PAYROLL_GROUP pg, cmn_mem_acct_type accttype
	where dmc.scheme_code = '&&1'
	and dmc.type_com_related_person in ('THIRD_PAYOR')
	and dmc.EMPLR_PAYROLL_GROUP is null
	and accttype.id = memacct.mem_acct_type_uuid
	--WL-170924 begin
	--and accttype.short_code = 'SEP'
	and accttype.short_code in ('SEP', 'TVC', 'SVC')
	--WL-170924 end
	and memacct.orig_tr_mem_no = dmc.TRUSTEE_ENTTY_CD
	and memacct.id = pg.MEM_ACCT_UUID		
	and not exists (select 'x'
		from cccp_ini_temp tmpc
		where tmpc.scheme_code = '&&1'
		and tmpc.trustee_entty_cd = dmc.trustee_entty_cd
		and tmpc.av_contact_person_type in ('THIRD_PAYOR')		
		and tmpc.av_client_type = 'PAYROLL_GROUP'		
		)
	;
	--WL-270824 end
	commit;
	
    insert /*+ PARALLEL(16) */ into cccp_ini_temp
        (scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
        client_uuid, av_client_type, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth)
		--FH-030925 end
    select /*+ PARALLEL(16) */ '&&1', dcp.trustee_entty_cd, dcp.emplr_payroll_group, dcp.type_com_related_person, dcp.first_nm, dcp.last_nm, dcp.chinese_first_nm, dcp.chinese_last_nm, dcp.job_position, dcp.own_percentage,
        dcp.mbr_communication_type, dcp.nationality_1, dcp.nationality_2, dcp.nationality_3, dcp.related_person_id, (case when dcp.occupation = 'Not Provided' then null else dcp.occupation end), 
        ema.member_uuid, null, null, null as eff_date
		--FH-030925 begin
		, to_date(dcp.date_of_birth,'YYYY-MM-DD') as date_of_birth
		--FH-030925 end	
    from dm_correlated_person dcp
    inner join dm_member dm on dm.related_person_cd = dcp.related_person_id and dcp.scheme_code = dm.scheme_code
    inner join enr_mem_acct ema on ema.orig_tr_mem_no = dm.trustee_mbr_id and ema.scheme_code = dm.scheme_code
    where dcp.scheme_code = '&&1'  and dcp.type_com_related_person in ('ORO', 'TIB')
    --and rownum <=5
    ;
	commit;

    insert /*+ PARALLEL(16) */ into cccp_ini_temp
        (scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, 
        client_uuid, av_client_type, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth)
		--FH-030925 end
    select /*+ PARALLEL(16) */ '&&1', dcp.trustee_entty_cd, dcp.emplr_payroll_group, dcp.type_com_related_person, dcp.first_nm, dcp.last_nm, dcp.chinese_first_nm, dcp.chinese_last_nm, dcp.job_position,dcp.own_percentage,
        dcp.mbr_communication_type, dcp.nationality_1, dcp.nationality_2, dcp.nationality_3, dcp.related_person_id, (case when dcp.occupation = 'Not Provided' then null else dcp.occupation end), 
        ema.member_uuid, null, null, null as eff_date
		--FH-030925 begin
		, to_date(dcp.date_of_birth,'YYYY-MM-DD') as date_of_birth
		--FH-030925 end	
    from dm_correlated_person dcp
    inner join dm_sep dm on dm.related_person_cd_oro = dcp.related_person_id and dcp.scheme_code = dm.scheme_code
    inner join enr_mem_acct ema on ema.orig_tr_mem_no = dm.trustee_sep_cd and ema.scheme_code = dm.scheme_code
    where dcp.scheme_code = '&&1'  and dcp.type_com_related_person in ('ORO', 'TIB')
    --and rownum <=10000
    ;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set client_type_seq_no = '&&1' || '_XCP' || LPAD(ROWNUM, 8, 0);
	commit;
	
	UPDATE /*+ PARALLEL(16) */ cccp_ini_temp
    SET   NATIONALITY_1 = NULL WHERE NATIONALITY_1 IS NOT NULL AND UPPER(NATIONALITY_1) = 'NOTED';
	commit;
	
	UPDATE /*+ PARALLEL(16) */ cccp_ini_temp
    SET   NATIONALITY_2 = NULL WHERE NATIONALITY_2 IS NOT NULL AND UPPER(NATIONALITY_2) = 'NOTED';
	commit;
	
	UPDATE /*+ PARALLEL(16) */ cccp_ini_temp
    SET   NATIONALITY_3 = NULL WHERE NATIONALITY_3 IS NOT NULL AND UPPER(NATIONALITY_3) = 'NOTED';
	
    commit;

	--WL080224 temp added
	dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'CCCP_INI_TEMP');
	
    dbms_output.put_line ('START UPDATE INDIVIDUAL:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    update /*+ PARALLEL(16) */ cccp_ini_temp 
    set av_client_type = 'MEMBER_ACCT' 
    where trustee_entty_cd is null
    and scheme_code = '&&1';
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set av_client_type = 'ORO',av_contact_person_type = 'PRIMARY_ORO'
    where av_contact_person_type in ('ORO',  'TIB')
    and scheme_code = '&&1';
 	commit;
   
    dbms_output.put_line ('START UPDATE CLAIMANT:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    update /*+ PARALLEL(16) */ cccp_ini_temp 
    set av_client_type = 'CLAIMANT' 
    -- ,trustee_entty_cd =  NVL((select min(dw.trustee_entty_cd)
                        -- from dm_withdrawal dw 
                        -- where dw.scheme_code = '&&1' 
                        -- and dw.related_person_cd_1 = related_person_id
 --                      and rownum = 1
						-- ),
                        -- (select min(dw.trustee_entty_cd)
                        -- from dm_withdrawal dw 
                        -- where dw.scheme_code = '&&1' 
                        -- and dw.related_person_cd_2 = related_person_id 
 --                      and rownum = 1
						-- ))
    where av_contact_person_type = 'CLAIMANT'
    and scheme_code = '&&1'
    ;
	commit;
    
    dbms_output.put_line ('START UPDATE EMPLOYER_ACCT:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    update /*+ index(CCCP_INI_TEMP CCCP_INI_TEMP_IND1) */ cccp_ini_temp 
    set av_client_type = 'EMPLOYER_ACCT', 
        client_uuid = (select id from enr_er_acct where scheme_code = '&&1' and tr_employer_code = trustee_entty_cd) 
    --WL-250824 begin
	where exists (select 'x' from enr_er_acct where scheme_code = '&&1' and tr_employer_code = trustee_entty_cd)
	--where trustee_entty_cd in (select tr_employer_code from enr_er_acct where scheme_code = '&&1')
	--WL-250824 end
    --WL-070624 begin
	--and av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT', 'AP', 'PARTNER', 'BENE_OWNER', 'SOLE_PROPRIETORSHIP', 'DIRECTOR')
	and av_contact_person_type in ('AP', 'PARTNER', 'BENE_OWNER', 'SOLE_PROPRIETORSHIP', 'DIRECTOR'
	--WL-250824 begin
	,'THIRD_PAYOR'
	--WL-250824 end
	--GY20250407 begin
	,'CONTROLLING_PERSON'
	--GY20250407 end
	)
	--WL-070624 end
    and av_client_type is null
    and scheme_code = '&&1'
    ;
	commit;

    dbms_output.put_line ('START UPDATE PAYROLL_GROUP:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));       
    update /*+ PARALLEL(16) */ cccp_ini_temp 
    set av_client_type = 'PAYROLL_GROUP', 
        client_uuid = (select id from enr_payroll_group where er_acct_uuid = client_uuid and payroll_group_short_name = emplr_payroll_group and scheme_code = '&&1') 
    where av_client_type = 'EMPLOYER_ACCT'
    and emplr_payroll_group is not null
    and client_uuid is not null
    and scheme_code = '&&1'
	--WL-070624 begin
	and av_contact_person_type not in ('PRIMARY_CONTACT', 'SECOND_CONTACT')
	--WL-070624 end
    and exists (select 1 from enr_payroll_group where er_acct_uuid = client_uuid and payroll_group_short_name = emplr_payroll_group and scheme_code = '&&1')
    ;
	commit;
	
	--GY20250407  begin
    --dbms_output.put_line ('START UPDATE EMPLOYER:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    --update /*+ PARALLEL(16) */ cccp_ini_temp 
    --set av_client_type = 'EMPLOYER', 
    --    client_uuid = (select er.id from enr_er_acct ea inner join reg_employer er on ea.employer_uuid = er.id where ea.scheme_code = er.scheme_code and ea.scheme_code = '&&1' and ea.tr_employer_code = trustee_entty_cd) 
    --where trustee_entty_cd in (select tr_employer_code from enr_er_acct where scheme_code = '&&1')
    --and av_contact_person_type in ('CONTROLLING_PERSON')
    --and av_client_type is null
    --and scheme_code = '&&1'
    --;
	--commit;
	--GY20250407  end
	
    dbms_output.put_line ('START UPDATE MEMBER_ACCT:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    update /*+ PARALLEL(16) */ cccp_ini_temp 
    set av_client_type = 'MEMBER_ACCT',
        client_uuid = (select id from enr_mem_acct where orig_tr_mem_no = trustee_entty_cd and scheme_code = '&&1')
    where trustee_entty_cd is not null
    and scheme_code = '&&1'
    and av_client_type is null
 --   and trustee_entty_cd in (select orig_tr_mem_no from enr_mem_acct where scheme_code = '&&1')
    ;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set eff_date = (select eff_date from enr_mem_acct where id = client_uuid and scheme_code = '&&1')
    where av_client_type = 'MEMBER_ACCT'
    and scheme_code = '&&1'
    and client_uuid is not null;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set eff_date = (select eff_date from enr_er_acct where id = client_uuid and scheme_code = '&&1')
    where av_client_type = 'EMPLOYER_ACCT'
    and scheme_code = '&&1'    
    and client_uuid is not null;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set eff_date = (select eff_date from enr_payroll_group where id = client_uuid and scheme_code = '&&1')
    where av_client_type = 'PAYROLL_GROUP'
    and scheme_code = '&&1'
	--WL-270824 begin
	and not (av_contact_person_type = 'THIRD_PAYOR' and emplr_payroll_group is null)
	--WL-270824 end
    and client_uuid is not null;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set eff_date = (select er.eff_date from enr_er_acct ea inner join reg_employer er on ea.employer_uuid = er.id where ea.scheme_code = er.scheme_code and ea.scheme_code = '&&1' and ea.tr_employer_code = trustee_entty_cd)
    where av_client_type = 'EMPLOYER'
    and scheme_code = '&&1'    
    and client_uuid is not null;
	commit;

    update /*+ PARALLEL(16) */ cccp_ini_temp
    set eff_date = v_cycle_change_date
    where eff_date is null
    and scheme_code = '&&1';
	commit;

    dbms_output.put_line ('START INSERT cccp_temp:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));  
    insert /*+ PARALLEL(16) */ into cccp_temp
        (scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, client_uuid, av_client_type, seq_no, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth)
		--FH-030925 end
    select /*+ PARALLEL(16) */ scheme_code, trustee_entty_cd, emplr_payroll_group, av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, own_percentage,
        mbr_communication_type, nationality_1, nationality_2, nationality_3, related_person_id, av_org_occup, client_uuid, av_client_type, 
        row_number() over (partition by av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, job_position, scheme_code, client_uuid
        order by related_person_id desc) as seq_no, client_type_seq_no, eff_date
		--FH-030925 begin
		, date_of_birth
		--FH-030925 end
    from cccp_ini_temp 
    where scheme_code = '&&1' 
    ;
	commit;

	--WL080224 temp added
	dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'cccp_temp');
	
    update /*+ PARALLEL(16) */ cccp_temp
    set eff_date = eff_date - seq_no + 1
    where scheme_code = '&&1' 
	and client_uuid is not null
    and seq_no > 1;
	commit;

    dbms_output.put_line ('START INSERT CMN_CLIENT:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));       
    insert /*+ PARALLEL(16) */ into cmn_client (ID, SYSTEM_CLIENT_TYPE, ARCHIVE_FLAG, SCHEME_ONBOARD_SEQ, CREATED_BY, CREATION_DATE, 
    LAST_UPDATED_BY, LAST_UPDATE_DATE, SCHEME_CODE)
    select /*+ PARALLEL(16) */ generate_guid('&&1'), 
	--WL-120624 begin
	--cccpt.av_client_type,	
--	decode(cccpt.av_contact_person_type, 'PRIMARY_CONTACT', 'EMPLOYER_CONTACT', 'SECOND_CONTACT', 'EMPLOYER_CONTACT', cccpt.av_client_type), 
	--WL-120624 end
	(case when cccpt.av_contact_person_type in ('PRIMARY_CONTACT', 'SECOND_CONTACT', 'PARTNER', 'BENE_OWNER', 'SOLE_PROPRIETORSHIP', 'DIRECTOR') then 'EMPLOYER_CONTACT' 
	 when cccpt.av_contact_person_type in ('CONTROLLING_PERSON') then 'CONTROL_PERSON'
	 --GY20250320  begin
	 --when cccpt.av_contact_person_type in ('OTHER') then 'AP'
	 when cccpt.av_contact_person_type in ('OTHER','AP') then 'AP'
	 --GY20250320  end
	else cccpt.av_client_type end), 
	'N',  NULL, client_type_seq_no, systimestamp,
    v_user, systimestamp, '&&1'
    from    cccp_temp cccpt
    where   cccpt.scheme_code = '&&1'  
	and 	cccpt.av_client_type is not null
---    and     cccpt.seq_no = 1
    -- JL20250606 Begin
    -- -- JL20250516 Begin
    -- and not exists (
    --     select 1
    --     from dm_correlated_person dcp
    --     where scheme_code = '&&1'
    --         and dcp.related_person_id = cccpt.related_person_id
    --         and dcp.type_com_related_person in ('DIRECTOR','BENE_OWNER')
    --         and dcp.hkid_nmbr is null and dcp.passport_nmbr is null
    --         and (dcp.company_nm is not null or dcp.company_chinese_nm is not null)
    -- )
    -- -- JL20250516 End
    -- JL20250606 End
    ;
    commit;
    
    -- JL20250606 Begin
    -- -- JL20250516 Begin
    -- update /*+ PARALLEL(16) index(c CMN_CLIENT_PK) */ cmn_client c
    -- set last_updated_by = v_user, created_by = (
    --     select /*+ index(cccpt cccp_temp_2_IND1) */ cccpt.client_type_seq_no
    --     from cccp_temp cccpt
    --     join enr_er_acct eea
    --         on eea.id = cccpt.client_uuid
    --     where cccpt.av_client_type = 'EMPLOYER_ACCT'
    --         and eea.av_er_acct_type_code = 'ER'
    --         and eea.tr_employer_code = c.last_updated_by
    --         and cccpt.related_person_id = c.created_by
    --         and cccpt.av_contact_person_type in ('BENE_OWNER','DIRECTOR')
    --         and cccpt.scheme_code = '&&1'
    -- )
    -- where system_client_type = 'EMPLOYER_CONTACT'
    -- and exists (
    --     select 1
    --     from enr_er_acct er
    --     where c.id = er.id
    -- );
    -- commit;
    -- -- JL20250516 End
    -- JL20250606 End
    

	--WL080224 temp added
	dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'cmn_client');
	
    dbms_output.put_line ('START INSERT CMN_CLIENT_CONTACT_PERSON:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));      
    insert /*+ PARALLEL(16) */ into cmn_client_contact_person(ID,AV_CONTACT_PERSON_TYPE,CLIENT_UUID,AV_CLIENT_TYPE,AV_NAME_TITLE_CODE,FIRST_NAME,LAST_NAME,FIRSTNAME_ZHHK,LASTNAME_ZHHK,DATE_OF_BIRTH,
                        JOB_POS,TR_SCHEME_UUID,AV_STATUS_CODE,AV_ORG_PERSON_TYPE_CODE,OWNER_PCT_COUNT,KEY_ROLE_CODE,EFF_DATE,CYCLE_CHANGE_DATE,AV_EKYC_STATUS_CODE,AV_NOTIFY_MEDIUM_CODE,
                        NOTIFY_PAPER_FLAG,RECEIVE_PAPER_FLAG_EFF_DATE,ARCHIVE_FLAG,EKYC_STATUS_CHANGE_DATE,HOTLINE_SERVICE_HOUR,NATION_CODE1,BIRTH_COUNTRY_CODE,NATION_CODE2,NATION_CODE3,REMARK,
                        AV_ORIG_OCCUP, DW_CONTACT_PERSON_KEY
                        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
                        ,SCHEME_CODE
                        )
    select /*+ PARALLEL(16) */ c.id, cccpt.av_contact_person_type, nvl(cccpt.client_uuid, c.id), cccpt.av_client_type, null, cccpt.first_name, cccpt.last_name, cccpt.firstname_zhhk, cccpt.lastname_zhhk, 
						--FH-030925 begin
						--null,
						cccpt.date_of_birth,
						--FH-030925 end
						--WL-210225 begin
                        --cccpt.job_position,v_scheme_uuid,'ACTIVE',NULL,cccpt.own_percentage,null,cccpt.eff_date,v_cycle_change_date,null,cccpt.mbr_communication_type,																
						cccpt.job_position,v_scheme_uuid,decode(AV_CONTACT_PERSON_TYPE,'AP','PEND_ACTV','ACTIVE'),NULL,cccpt.own_percentage,null,cccpt.eff_date,v_cycle_change_date,null,cccpt.mbr_communication_type,																
						--WL-210225 end
                        null,null,'N',null,null,cccpt.nationality_1,null,cccpt.nationality_2,cccpt.nationality_3,cccpt.related_person_id,
                        cccpt.av_org_occup,null
                        ,v_user, systimestamp, v_user, systimestamp
                        ,'&&1'
    from    cccp_temp cccpt
            inner join cmn_client c on c.created_by = cccpt.client_type_seq_no and c.scheme_code = cccpt.scheme_code
    where   cccpt.scheme_code = '&&1'  
	and 	cccpt.av_client_type is not null		
--    and     cccpt.seq_no = 1
    ;
   	commit;
	
	--JL20250910 begin
	update /*+ PARALLEL(16) */ cmn_client_contact_person cccp
	set date_of_birth = (
		-- JL20251021 begin
		-- select date_of_birth
		select to_date(date_of_birth,'YYYY-MM-DD')
		-- JL20251021 end
		from dm_correlated_person dcp
		where scheme_code = '&&1'
			and dcp.related_person_id = cccp.remark
			and dcp.type_com_related_person = cccp.av_contact_person_type
			and dcp.type_com_related_person in ('CONTROLLING_PERSON', 'SOLE_PROPRIETORSHIP', 'DIRECTOR','BENE_OWNER','PARTNER')
	)
	where exists (
		select 1
		from dm_correlated_person dcp
		where scheme_code = '&&1'
			and dcp.related_person_id = cccp.remark
			and dcp.type_com_related_person = cccp.av_contact_person_type
			and dcp.type_com_related_person in ('CONTROLLING_PERSON', 'SOLE_PROPRIETORSHIP', 'DIRECTOR','BENE_OWNER','PARTNER')
	);
	commit;
	
	update /*+ PARALLEL(16) */ cmn_client_contact_person cccp
	set date_of_birth = (
		select to_date(date_of_birth,'YYYY-MM-DD')
		from dm_cmn_reporting_standard crs
		where scheme_code = '&&1'
			and crs.related_person_cd_cp_sp = cccp.remark
			and decode(crs.sub_entity_type, 'CTP', 'CONTROLLING_PERSON', 'SOL', 'SOLE_PROPRIETORSHIP') = cccp.av_contact_person_type
			and crs.sub_entity_type in ('CTP', 'SOL')
	)
	where exists (
		select 1
		from dm_cmn_reporting_standard crs
		where scheme_code = '&&1'
			and crs.related_person_cd_cp_sp = cccp.remark
			and decode(crs.sub_entity_type, 'CTP', 'CONTROLLING_PERSON', 'SOL', 'SOLE_PROPRIETORSHIP') = cccp.av_contact_person_type
			and crs.sub_entity_type in ('CTP', 'SOL')
	)
	and date_of_birth is null;
	commit;

	update /*+ PARALLEL(16) */ cmn_client_contact_person cccp
	set company_flag = 'Y', last_name = (
		select company_nm
		from dm_correlated_person dcp
		where scheme_code = '&&1' 
			and dcp.related_person_id = cccp.remark
			and dcp.scheme_code = cccp.scheme_code
			and dcp.type_com_related_person in ('CLAIMANT','THIRD_PAYOR','DIRECTOR','PARTNER','TIB')
			and dcp.type_com_related_person = cccp.av_contact_person_type
			AND dcp.hkid_nmbr is null
			AND upper(nvl(dcp.passport_nmbr, 'NOT PROVIDED')) like '%NOT%PROVIDED%'
			and company_nm is not null
	)
	where exists (
		select 1
		from dm_correlated_person dcp
		where scheme_code = '&&1' 
			and dcp.related_person_id = cccp.remark
			and dcp.scheme_code = cccp.scheme_code
			and dcp.type_com_related_person in ('CLAIMANT','THIRD_PAYOR','DIRECTOR','PARTNER','TIB')
			and dcp.type_com_related_person = cccp.av_contact_person_type
			AND dcp.hkid_nmbr is null
			AND upper(nvl(dcp.passport_nmbr, 'NOT PROVIDED')) like '%NOT%PROVIDED%'
			and company_nm is not null
	);
	commit;
	
	update /*+ PARALLEL(16) */ cmn_client_contact_person cccp
	set company_flag = 'Y', lastname_zhhk = (
		select company_chinese_nm
		from dm_correlated_person dcp
		where scheme_code = '&&1' 
			and dcp.related_person_id = cccp.remark
			and dcp.scheme_code = cccp.scheme_code
			and dcp.type_com_related_person in ('CLAIMANT','THIRD_PAYOR','DIRECTOR','PARTNER','TIB')
			and dcp.type_com_related_person = cccp.av_contact_person_type
			AND dcp.hkid_nmbr is null
			AND upper(nvl(dcp.passport_nmbr, 'NOT PROVIDED')) like '%NOT%PROVIDED%'
			and company_chinese_nm is not null
	)
	where exists (
		select 1
		from dm_correlated_person dcp
		where scheme_code = '&&1' 
			and dcp.related_person_id = cccp.remark
			and dcp.scheme_code = cccp.scheme_code
			and dcp.type_com_related_person in ('CLAIMANT','THIRD_PAYOR','DIRECTOR','PARTNER','TIB')
			and dcp.type_com_related_person = cccp.av_contact_person_type
			AND dcp.hkid_nmbr is null
			AND UPPER(NVL(dcp.passport_nmbr, 'NOT PROVIDED')) LIKE '%NOT%PROVIDED%'
			and company_chinese_nm is not null
	);
	commit;
	--JL20250910 end
	
	-- JL20251216 begin
	update /*+ PARALLEL(16) */ cmn_client_contact_person
	set date_of_birth = null
	where scheme_code = '&&1' 
	and date_of_birth is not null
	and av_contact_person_type not in ('CONTROLLING_PERSON', 'SOLE_PROPRIETORSHIP', 'DIRECTOR','BENE_OWNER','PARTNER');
	commit;
	-- JL20251216 end
	
	--17/12/2024  GY-171242 begin
	insert /*+ PARALLEL(16) */ into tmp_cmn_client_contact_person_clone(
	id,
	scheme_code,
	av_client_type,
	client_uuid,
	REMARK,
	created_by,
	creation_date,
	last_updated_by,
	last_update_date)
	select /*+ PARALLEL(16) */ cccp.ID,
	'&&1',
	cccp.av_client_type,
	cccp.client_uuid,
	cccp.REMARK, 
	cccp.created_by, 
	cccp.creation_date,
	cccp.last_updated_by,
	last_update_date
	from cmn_client_contact_person cccp 
	where scheme_code = '&&1' and NATION_CODE3 = 'OTHER';
	commit;

	update /*+ PARALLEL(16) */ cmn_client_contact_person a set a.NATION_CODE3 = NULL where a.id in (select /*+ PARALLEL(16) */ b.id from tmp_cmn_client_contact_person_clone b);
	commit;
	--17/12/2024  GY-171242 end
	
	
-- DL20240603 start 
--------------------- insert cmn_client_contact_person_hst step 1
   INSERT /*+ PARALLEL(16) */ INTO cmn_client_contact_person_hst
            (ID,AV_CONTACT_PERSON_TYPE,CLIENT_UUID,AV_CLIENT_TYPE,AV_NAME_TITLE_CODE,FIRST_NAME,LAST_NAME,FIRSTNAME_ZHHK,LASTNAME_ZHHK,
				DATE_OF_BIRTH,JOB_POS,TR_SCHEME_UUID,AV_STATUS_CODE,AV_ORG_PERSON_TYPE_CODE,OWNER_PCT_COUNT,KEY_ROLE_CODE,EFF_DATE,
				CYCLE_CHANGE_DATE,AV_EKYC_STATUS_CODE,AV_NOTIFY_MEDIUM_CODE,NOTIFY_PAPER_FLAG,RECEIVE_PAPER_FLAG_EFF_DATE,
				ARCHIVE_FLAG,EKYC_STATUS_CHANGE_DATE,HOTLINE_SERVICE_HOUR,NATION_CODE1,
				BIRTH_COUNTRY_CODE,NATION_CODE2,NATION_CODE3,REMARK,
				-- JL20251104 begin
				-- CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE,AV_ORIG_OCCUP,DW_CONTACT_PERSON_KEY,SCHEME_CODE)
				CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE,AV_ORIG_OCCUP,DW_CONTACT_PERSON_KEY,SCHEME_CODE,COMPANY_FLAG)
				-- JL20251104 end
            select /*+ PARALLEL(16) */
			--WL-030724 
			--WL-040624
				id, AV_CONTACT_PERSON_TYPE,CLIENT_UUID,AV_CLIENT_TYPE,AV_NAME_TITLE_CODE,FIRST_NAME,LAST_NAME,FIRSTNAME_ZHHK,LASTNAME_ZHHK,
				DATE_OF_BIRTH,JOB_POS,TR_SCHEME_UUID,AV_STATUS_CODE,AV_ORG_PERSON_TYPE_CODE,OWNER_PCT_COUNT,KEY_ROLE_CODE,EFF_DATE,
				CYCLE_CHANGE_DATE,AV_EKYC_STATUS_CODE,AV_NOTIFY_MEDIUM_CODE,NOTIFY_PAPER_FLAG,RECEIVE_PAPER_FLAG_EFF_DATE,
				ARCHIVE_FLAG,EKYC_STATUS_CHANGE_DATE,HOTLINE_SERVICE_HOUR,NATION_CODE1,
				BIRTH_COUNTRY_CODE,NATION_CODE2,NATION_CODE3,REMARK,
				-- JL20251104 begin
				-- CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE,AV_ORIG_OCCUP,DW_CONTACT_PERSON_KEY,SCHEME_CODE
				CREATED_BY,CREATION_DATE,LAST_UPDATED_BY,LAST_UPDATE_DATE,AV_ORIG_OCCUP,DW_CONTACT_PERSON_KEY,SCHEME_CODE,COMPANY_FLAG
				-- JL20251104 end
            from cmn_client_contact_person
			WHERE scheme_code = '&&1'; 
commit;
	--WL-270624 remove
	--delete cmn_client_contact_person p where p.av_contact_person_type = 'AP' and scheme_code = '&&1';
--commit;

	-- DL20240603 end 
    -- dbms_output.put_line ('START UPDATE CLIENT_UUID:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));     
    -- update cmn_client_contact_person 
    -- set client_uuid = id 
    -- where client_uuid is null 
 --   and remark in (select cccpt.related_person_id from cccp_temp cccpt where cccpt.seq_no = 1 and scheme_code = '&&1') 
    -- and scheme_code = '&&1';
    -- commit;
/*
    update cmn_client_contact_person cp
    set cp.client_uuid = ( select cccp.client_uuid from cmn_client_contact_person cccp 
                        where nvl(cccp.av_contact_person_type, 'N/A') = nvl(cp.av_contact_person_type, 'N/A')
                        and nvl(cccp.first_name, 'N/A') = nvl(cp.first_name, 'N/A')
                        and nvl(cccp.last_name, 'N/A') = nvl(cp.last_name, 'N/A')
                        and nvl(cccp.firstname_zhhk, 'N/A') = nvl(cp.firstname_zhhk, 'N/A')
                        and nvl(cccp.lastname_zhhk, 'N/A') = nvl(cp.lastname_zhhk, 'N/A')
                        and nvl(cccp.job_pos, 'N/A') = nvl(cp.job_pos, 'N/A')
                        and (cccp.av_contact_person_type is not null or cccp.first_name is not null or cccp.last_name is not null or cccp.last_name is not null 
                        or cccp.firstname_zhhk is not null or cccp.lastname_zhhk is not null or cccp.job_pos is not null)
                        and cccp.remark in (select t.related_person_id from cccp_temp t where t.seq_no = 1 and scheme_code = '&&1') 
                        and cccp.scheme_code = scheme_code
                        ) 
    where cp.client_uuid is null 
    and cp.remark in (select cccpt.related_person_id from cccp_temp cccpt where cccpt.seq_no > 1 and scheme_code = '&&1') 
    and cp.scheme_code = '&&1';

    --	commit;
    MERGE INTO cmn_client_contact_person cp
    USING (
    	select  cvl.client_uuid, cvl.scheme_code, cvl.av_contact_person_type, cvl.first_name, cvl.last_name, cvl.firstname_zhhk, cvl.lastname_zhhk, cvl.job_pos
        from    cmn_client_contact_person cvl
            inner join cccp_temp cccpt 
            on cccpt.seq_no = 1 
            and cccpt.scheme_code = cvl.scheme_code
            and cccpt.related_person_id = cvl.remark
            and cccpt.client_uuid is null         
        where  (cvl.av_contact_person_type is not null or cvl.first_name is not null or cvl.last_name is not null or cvl.last_name is not null 
                or cvl.firstname_zhhk is not null or cvl.lastname_zhhk is not null or cvl.job_pos is not null)	
            --and cv1.scheme_code = cp.scheme_code
        and cvl.client_uuid is not null
        and cvl.scheme_code = '&&1'
          )
    src ON (nvl(src.av_contact_person_type, 'N/A') = nvl(cp.av_contact_person_type, 'N/A')
            and nvl(src.first_name, 'N/A') = nvl(cp.first_name, 'N/A')
            and nvl(src.last_name, 'N/A') = nvl(cp.last_name, 'N/A')
            and nvl(src.firstname_zhhk, 'N/A') = nvl(cp.firstname_zhhk, 'N/A')
            and nvl(src.lastname_zhhk, 'N/A') = nvl(cp.lastname_zhhk, 'N/A')
            and nvl(src.job_pos, 'N/A') = nvl(cp.job_pos, 'N/A')
            and src.scheme_code = cp.scheme_code)
    WHEN MATCHED THEN UPDATE
    SET cp.client_uuid = src.client_uuid   
    where cp.client_uuid is null
    AND cp.scheme_code = '&&1';		
    commit;
*/
    dbms_output.put_line ('End time:'|| to_char(systimestamp, 'DD-MON-RR hh:mi:ssxff PM'));
end;
/

/*
drop INDEX CMN_CLIENT_CONTACT_PERSON_I7;
create INDEX CMN_CLIENT_CONTACT_PERSON_I7 ON CMN_CLIENT_CONTACT_PERSON (SCHEME_CODE, REMARK) local parallel 8;
alter INDEX CMN_CLIENT_CONTACT_PERSON_I7 NOPARALLEL;

drop INDEX CMN_CLIENT_I1;
create INDEX CMN_CLIENT_I1 ON CMN_CLIENT (SCHEME_CODE, CREATED_BY) local parallel 8;
alter INDEX CMN_CLIENT_I1 NOPARALLEL;

select * from cmn_client
select * from cccp_temp
select count(*) from cmn_client_contact_person
select count(*) from cmn_client_contact_person

select count(*)
from
(
select AV_CONTACT_PERSON_TYPE,AV_CLIENT_TYPE,AV_NAME_TITLE_CODE,FIRST_NAME,LAST_NAME,FIRSTNAME_ZHHK,LASTNAME_ZHHK,DATE_OF_BIRTH,
                        JOB_POS,TR_SCHEME_UUID,AV_STATUS_CODE,AV_ORG_PERSON_TYPE_CODE,OWNER_PCT_COUNT,KEY_ROLE_CODE,AV_EKYC_STATUS_CODE,AV_NOTIFY_MEDIUM_CODE,
                        NOTIFY_PAPER_FLAG,RECEIVE_PAPER_FLAG_EFF_DATE,ARCHIVE_FLAG,EKYC_STATUS_CHANGE_DATE,HOTLINE_SERVICE_HOUR,NATION_CODE1,
                        BIRTH_COUNTRY_CODE,NATION_CODE2,NATION_CODE3,REMARK, AV_ORIG_OCCUP 
from cmn_client_contact_person
minus
select AV_CONTACT_PERSON_TYPE,AV_CLIENT_TYPE,AV_NAME_TITLE_CODE,FIRST_NAME,LAST_NAME,FIRSTNAME_ZHHK,LASTNAME_ZHHK,DATE_OF_BIRTH,
                        JOB_POS,TR_SCHEME_UUID,AV_STATUS_CODE,AV_ORG_PERSON_TYPE_CODE,OWNER_PCT_COUNT,KEY_ROLE_CODE,AV_EKYC_STATUS_CODE,AV_NOTIFY_MEDIUM_CODE,
                        NOTIFY_PAPER_FLAG,RECEIVE_PAPER_FLAG_EFF_DATE,ARCHIVE_FLAG,EKYC_STATUS_CHANGE_DATE,HOTLINE_SERVICE_HOUR,NATION_CODE1,
                        BIRTH_COUNTRY_CODE,NATION_CODE2,NATION_CODE3,REMARK, AV_ORIG_OCCUP
from cccp_test
)


select scheme_code, av_client_type, count(*) from cccp_temp group by scheme_code, av_client_type
select scheme_code, type_com_related_person, count(*) from dm_correlated_person group by scheme_code, type_com_related_person

select * from dm_correlated_person  where type_com_related_person in ('DIRECTOR')

select scheme_code, count(*) from dm_member group by scheme_code
select * from cmn_client_contact_person
delete from cmn_client_contact_person
drop table cccp_temp
create table cccp_temp
(
scheme_code                 varchar2(15)
,trustee_entty_cd           varchar2(255)
,emplr_payroll_group        varchar2(255)
,av_contact_person_type     varchar2(20)
,first_name                 varchar2(100)
,last_name                  varchar2(100)
,firstname_zhhk             varchar2(50)
,lastname_zhhk              varchar2(50)
,job_position               varchar2(200)
,own_percentage             number(5,2)
,mbr_communication_type     varchar2(20)
,nationality_1              varchar2(10)
,nationality_2              varchar2(10)
,nationality_3              varchar2(10)
,related_person_id          varchar2(200)
,av_org_occup               varchar2(20)
,client_uuid                raw(16)
,av_client_type             varchar2(20)
,seq_no                    number(8,0)
)
alter table cccp_temp add constraint  cccp_temp_fk1 foreign key (client_uuid) references cmn_client(id);

create index cccp_temp_ind1 on cccp_temp (av_contact_person_type, first_name, last_name, firstname_zhhk, lastname_zhhk, av_org_occup, scheme_code)
create index cccp_temp_ind2 on cccp_temp (scheme_code, related_person_id)

select * from dm_correlated_person    where scheme_Code = '&&1'     
                    
                                        
delete cmn_client_phone  where scheme_code = '&&1';
DELETE FROM cmn_client_id_doc  where scheme_code = '&&1';
delete from cmn_client_email where scheme_code = '&&1';
delete from cmn_client_addr where scheme_code = '&&1';
delete from CMN_CLIENT_COMM_PREF where scheme_code = '&&1';
--Withdrawal 15.1
delete txn_instr_dtl_wdr_pay WHERE scheme_code = '&&1';
delete txn_instr_dtl_wdr WHERE scheme_code = '&&1';
delete txn_wdr_claimant WHERE scheme_code = '&&1';
delete txn_wdr_stand_instr WHERE scheme_code = '&&1';
delete txn_instr_consent_wdr WHERE scheme_code = '&&1';
*/