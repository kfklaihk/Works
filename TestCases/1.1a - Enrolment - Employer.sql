/*
06/12/2023	Joe Wong		Some handlings about payroll group
07/12/2023	Freeman Kam		Change P#1: Specify index for latest effective date sub-query on DM_INVESTMENT_MANDATE
12/12/2023	Joe Wong		Fix submit channel issue. Mapping incorrect.
15/12/2023	Joe Wong		Fix payroll group history record in old version.								
18/12/2023  Joe W & DL      Add scheme code for temp_acct_no_pool and NUMERIC error fix
30/01/2024  Paul Pang       Change AV_BIZ_NATURE_CODE = 'OTHR' when source data is NULL
07/02/2024  Don Leung       v1 Add cmn_source_of_fund table and update Source_of_fund uuid to enr_er_acct table, update "EMPLOYER_ACCOUNT" to "EMPLOYER_ACCT"
12/03/2024  Winnie Lau      add branch code
18/03/2024	Paul Pang		Update checking for lspsp_offset_seq to uppercase
12/06/2024	George Ngai		change sys_guid to generate_guid
19/06/2024	George Ngai		Fix DUMMMY records generation for CEE and add condition for creation
26/06/2024	Dipanshu Singh  Insert records in ENR_ER_SUBACCT_TYPE for ('SEP', 'SVC', 'TVC')
04/07/2024	George Ngai		Skip DUMMMY records generation
01/08/2024  Justin Leung    JL20240801 Add UCN mapping logic
04/10/2024  Justin Leung    JL20241004 Replace temp_acct_no_pool with dm_ud_acct_mapping
27/01/2025  Winnie Lau      WL20250127 assign fund class
07/03/2025  Justin Leung    JL20250307 Fix random branch_num mapping for SEP (1.2 dependencies). Assignment of account numbers to SEP ER accounts should follow ascending order.
11/03/2025  Justin Leung    JL20250311 Use date_joining_the_schm as the commencement_date if sep_acct_open_date is null
16/05/2025  George Lin      GL20250516 add ER of dm_correlated_person table into ER table in CAS
22/05/2025  Justin Leung    JL20250522 
                                1. Remove insert into cmn_source_of_fund for company as DIRECTOR/BENE_OWNER.
                                2. Add eff_date for reg_employer / enr_er_acct of DIRECTOR/BENE_OWNER company account
26/05/2025  Justin Leung    JL20250526 
                                1. Fix dm_ud_acct_mapping getting 'MB' trustee_entity_code issue
                                2. Fix dm_ud_acct_mapping getting duplicate account number for DIRECTOR/BENE_OWNER company account
05/06/2025  Justin Leung    JL20250605 Fix director/bene_owner insert
06/08/2025  Justin Leung    JL20250806 Add error handling to cater duplicated trustee_entity_code with different entity_type
01/09/2025	George Ngai		Change parallel 16 to parallel 32
*/
SET SERVEROUT ON SIZE 1000000;

ALTER SESSION ENABLE PARALLEL DML;

DECLARE
v_update_by             VARCHAR2(50) := '&&1 TR2 UAT 07/12/2023'; 
v_scheme_cycle_date     DATE;
V_ER_UUID               RAW(16);
V_EMPF_ID_UUID          RAW(16);
V_COUNTRY_CODE          VARCHAR2(10);
V_EMPF_ID               VARCHAR2(20);
V_STATUS_CODE           VARCHAR2(20);
V_AV_NATURE_CODE        VARCHAR2(20);
V_MASTER_CYCLE_DATE     DATE;
v_source_of_fund        VARCHAR2(20);
v_scheme_uuid           RAW(16);
v_er_acct_uuid          RAW(16);
v_er_acct_no_uuid       RAW(16);
V_SOURCE_FUND_DESC      VARCHAR2(100);
V_AV_LSPSP_OFFSET_SEQ   VARCHAR2(20);
V_AV_SUBMIT_CHANNEL     VARCHAR2(20);
V_ORIGIN_ONGOING_SOURCE VARCHAR2(100);
V_ER_ACCT_NO            VARCHAR2(20);
V_ORIGIN_INITIAL_SOURCE VARCHAR2(100);
V_DEFAULT_PG_FLAG       VARCHAR2(1);
V_PG_UUID               RAW(16);
V_MEM_ACCT_TYPE_UUID    RAW(16);
v_trustee_emplr_cd      VARCHAR2(100);
--V_AV_ER_ACCT_TYPE_CODE  VARCHAR2(20);
V_FORFEITURE_HNDL       VARCHAR2(20);
V_ALLOCATE_MTHD         VARCHAR2(20);
V_AV_FORFEIT_OPTION     VARCHAR2(20);
V_AV_FORFEIT_FORMULA    VARCHAR2(20);
V_EFF_DATE              DATE;  
V_ALLOCATE_DATE     VARCHAR2(20);
V_GRADE_UUID            RAW(16);
V_TERM_DATE             DATE;
V_SUSP_EFF_DATE         DATE;
v_er_grd_txt            VARCHAR2(50);
V_SUBACCT_GRADE_UUID    RAW(16);
v_vcr_susp_eff_date     DATE;
v_vest_join_date_basis  VARCHAR2(20);

V_DM_EMPLOYER_COUNT     NUMBER(10, 0);
V_REG_EMPLOYER_COUNT    NUMBER(10, 0);
V_ENR_ER_ACCT_COUNT     NUMBER(10, 0);
V_ENR_PAYROLL_GROUP_COUNT     NUMBER(10, 0);
V_ENR_ER_ACCT_GRADE_COUNT     NUMBER(10, 0);
V_ENR_ER_SUBACCT_GRADE_COUNT  NUMBER(10, 0);
V_ER_ACCT_RESERVE_COUNT       NUMBER(10, 0);
V_ER_ACCT_FORFEIT_COUNT       NUMBER(10, 0);
V_DM_VESTING_RULES_COUNT      NUMBER(10, 0);
v_dm_voluntary_contribution_rules_count NUMBER(10, 0);
V_FORF_UUID             RAW(16);
V_RESERVE_UUID          RAW(16);
V_MEM_ACCT_TYPE         VARCHAR2(20);
V_MEMBER_UUID           RAW(16);
V_DEATH_PROFF_RECEIVE_DATE      DATE;
V_AV_STATUS_CODE                VARCHAR2(20);
V_GENDER                VARCHAR2(20);
V_TITLE                 VARCHAR2(20);
v_dm_member_count       NUMBER(10, 0);
v_reg_member_count      NUMBER(10, 0);
v_enr_mem_acct_count    NUMBER(10, 0);
V_MEM_ACCT_UUID         RAW(16);
V_MEM_ACCT_NO_UUID      RAW(16);
V_MEM_ACCT_NO           NUMBER(15, 0);
V_DIS_CHANGE_BY_DEFAULT_FLAG    VARCHAR2(1);
v_er_eff_date           DATE;
v_pah_dummp_uuid        RAW(16);
v_sep_dummp_uuid        RAW(16);
v_tvc_dummp_uuid        RAW(16);
v_svc_dummp_uuid        RAW(16);
V_SUBACCT_TYPE_UUID     RAW(16);
v_count                 NUMBER(10, 0);
v_sep_er_uuid           RAW(16);
V_ID_COUNTRY_CODE       VARCHAR2(10);
V_AV_ID_TYPE_CODE       VARCHAR2(20);
V_ID_NO                 VARCHAR2(80);
V_FOUND_FLG             VARCHAR2(1);
V_POOL_SEQ_NO           NUMBER(15, 0);
--V_MEM_EMPID_POOL_SEQ_NO NUMBER(15, 0);
V_ER_ACCT_NO_DISPLAY    VARCHAR2(15);
v_mem_acct_no_display   VARCHAR2(15);
V_CONTR_APPR_FLAG       VARCHAR2(1);
V_AV_CONTR_DAY_OPT      VARCHAR2(20);
V_TRUSTEE_MBR_ID        VARCHAR2(100);
v_efctv_dt_txt          VARCHAR2(15);
-- DESC enr_er_acct
-- desc DM_EMPLOYER_SUPPLEMENT
v_scheme_no             VARCHAR2(20);
v_ref_no             VARCHAR2(20);
v_calc_cmplt_month_service  VARCHAR2(20);
v_pre_er_grd_txt             VARCHAR2(50);
v_pre_trustee_emplr_cd      VARCHAR2(100);
V_MEM_ACCT_EMP_DTL_UUID     RAW(16);
V_MEM_ACCT_PG_UUID          RAW(16);
v_term_reason               VARCHAR2(20);
V_DEPARTURE_DATE_FOR_THE_PERMANENT_DEPARTURE_CLAIM  DATE;
V_AV_DEPART_REASON          VARCHAR2(20);
V_EFCTV_DATE_OF_THE_CLAIM   DATE;
V_NOT_NTFCTN_DT             DATE;
V_CEE_DUMMP_UUID            RAW(16);

---v1 
v_source_of_fund_uuid       RAW(16);
v_upd_cnt       			INTEGER := 0;

--WL20250127 begin
v_mfund_class_flag          VARCHAR2(1) := 'N';			
--WL20250127 end
	
CURSOR er_cur IS
SELECT /*+ PARALLEL(32) */ *
FROM (
SELECT /*+ PARALLEL(32) */ 'ER' AS av_er_acct_type_code, er.trustee_emplr_cd, er.place_of_incorporation, 
		-- JL20250307 Begin
		0 as er_seq,
		-- JL20250307 End
        (CASE er.emplr_status
            WHEN 'TMD' THEN 'TERMD'
            WHEN 'TMG' THEN 'TERMG'
            WHEN 'RCD' THEN 'RECEIVE'
            WHEN 'PTR' THEN 'PEND'
            WHEN 'RJD' THEN 'REJECT'
            WHEN 'CNL' THEN 'CANCEL'
			WHEN 'UCN' THEN 'IN_PROGRESS' -- JL20240801
            ELSE 'ACTIVE'
        END) emplr_status    
        ,er.is_er_skill_typ, er.is_er_classification_cd, er.er_stts_lst_updtd_dt, er.commencement_date, er.term_date
        ,er.business_nature
        ,(CASE er.company_type
            WHEN 'GV_AGN' THEN 'GVN_AGN'
            ELSE UPPER(er.company_type)
            END) company_type
	, er.source_of_fund, er.other_source_of_fund, er.ongoing_source_of_fund, er.lspsp_offset_seq, er.enrl_sbmssn_chnnl, er.er_acct_open_date
        ,er.initial_source_of_fund, er.date_of_incorporation, er.incrprtn_crtfct_nmbr_txt, er.branch_num
        ,er.company_chinese_nm, er.is_er_licence_typ
--        ,(CASE 
--            WHEN er.company_nm IS NOT NULL THEN er.company_nm
--            ELSE er.company_chinese_nm
--        END) AS company_nm
        ,er.company_nm
        , er.schm_term_date
        ,er.company_group_cd, er.mpfa_ref_no, er.fund_clss_typ_id
        ,sp.bogus_acct, sp.additional_details
FROM    DM_EMPLOYER er
        LEFT JOIN DM_EMPLOYER_SUPPLEMENT sp
        ON  sp.trustee_emplr_cd = er.trustee_emplr_cd
        AND sp.scheme_code = er.scheme_code
WHERE   er.scheme_code = '&&1'
---- AND     ROWNUM < 100
-- AND     er.trustee_emplr_cd in ('00000003883')
--AND     er.trustee_emplr_cd >= '30127969833'

UNION ALL

SELECT /*+ PARALLEL(32) */ 'SEP', sep.trustee_sep_cd, sep.place_of_incorporation_1
		-- JL20250307 Begin
		,1 as er_seq
		-- JL20250307 End
        ,(CASE sep.sep_status
            WHEN 'TMD' THEN 'TERMD'
            WHEN 'TMG' THEN 'TERMG'
            WHEN 'RCD' THEN 'RECEIVE'
            WHEN 'PTR' THEN 'PEND'
            WHEN 'RJD' THEN 'REJECT'
            WHEN 'CNL' THEN 'CANCEL'
			WHEN 'UCN' THEN 'IN_PROGRESS' -- JL20240801
            ELSE 'ACTIVE'
        END) emplr_status    
        -- JL20250311 Begin
        -- ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, sep.sep_acct_open_date, sep.term_date
        ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, nvl(sep.sep_acct_open_date, sep.date_joining_the_schm), sep.term_date
        -- JL20250311 End
        ,sep.business_nature_1, sep.company_type_1, sep.source_of_fund, sep.other_source_of_fund, NULL, NULL, NULL, sep.sep_acct_open_date
        ,NULL, sep.date_of_incorporation_1, sep.incrprtn_crtfct_nmbr_txt_1, branch_num_1, sep.company_chinese_nm_1, sep.is_er_license_typ
--        ,(CASE 
--            WHEN sep.company_nm_1 IS NOT NULL THEN sep.company_nm_1
--            ELSE sep.company_chinese_nm_1
--        END)
        ,sep.company_nm_1
        ,sep.term_date
        ,NULL, sep.mpfa_ref_no, sep.fund_clss_typ_id
        ,sep.bogus_acct, sep.additional_details
FROM    DM_SEP sep
WHERE   sep.scheme_code = '&&1'
--AND     NOT EXISTS (    SELECT 1
--                        FROM    DM_EMPLOYER er
--                        WHERE   er.registration_nmbr = sep.REGISTRATION_NMBR_1
--                        AND     er.scheme_code = sep.scheme_code)
AND     sep.REGISTRATION_TYPE_1 IS NOT NULL
-- AND     ROWNUM < 1
--  AND     SEP.trustee_SEP_cd in ('00000003883')
--AND     sep.trustee_sep_cd >= '30127969833' --= '00000001293'
--AND     sep.trustee_sep_cd in ('30122487480-1', '30111164220-1', '30119843554-1')

UNION ALL

SELECT /*+ PARALLEL(32) */ 'SEP', sep.trustee_sep_cd, sep.place_of_incorporation_2
		-- JL20250307 Begin
		,2 as er_seq
		-- JL20250307 End
        ,(CASE sep.sep_status
            WHEN 'TMD' THEN 'TERMD'
            WHEN 'TMG' THEN 'TERMG'
            WHEN 'RCD' THEN 'RECEIVE'
            WHEN 'PTR' THEN 'PEND'
            WHEN 'RJD' THEN 'REJECT'
            WHEN 'CNL' THEN 'CANCEL'
			WHEN 'UCN' THEN 'IN_PROGRESS' -- JL20240801
            ELSE 'ACTIVE'
        END) emplr_status    
        -- JL20250311 Begin
        -- ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, sep.sep_acct_open_date, sep.term_date
        ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, nvl(sep.sep_acct_open_date, sep.date_joining_the_schm), sep.term_date
        -- JL20250311 End
        ,sep.business_nature_2, sep.company_type_2, sep.source_of_fund, sep.other_source_of_fund, NULL, NULL, NULL, sep.sep_acct_open_date
        ,NULL, sep.date_of_incorporation_2, sep.incrprtn_crtfct_nmbr_txt_2, branch_num_2, sep.company_chinese_nm_2, sep.is_er_license_typ
--        ,(CASE 
--            WHEN sep.company_nm_2 IS NOT NULL THEN sep.company_nm_2
--            ELSE sep.company_chinese_nm_2
--        END)
        ,sep.company_nm_2
        , sep.term_date
        ,NULL, sep.mpfa_ref_no, sep.fund_clss_typ_id
        ,sep.bogus_acct, sep.additional_details
FROM    DM_SEP sep
WHERE   sep.scheme_code = '&&1'
--AND     NOT EXISTS (    SELECT 1
--                        FROM    DM_EMPLOYER er
--                        WHERE   er.registration_nmbr = sep.REGISTRATION_NMBR_2                        
--                        AND     er.scheme_code = sep.scheme_code)
AND     sep.REGISTRATION_TYPE_2 IS NOT NULL
-- AND     ROWNUM < 1
--  AND     SEP.trustee_SEP_cd in ('00000003883')
--AND     sep.trustee_sep_cd >= '30127969833' --

UNION ALL

SELECT /*+ PARALLEL(32) */ 'SEP', sep.trustee_sep_cd, sep.place_of_incorporation_3
		-- JL20250307 Begin
		,3 as er_seq
		-- JL20250307 End
        ,(CASE sep.sep_status
            WHEN 'TMD' THEN 'TERMD'
            WHEN 'TMG' THEN 'TERMG'
            WHEN 'RCD' THEN 'RECEIVE'
            WHEN 'PTR' THEN 'PEND'
            WHEN 'RJD' THEN 'REJECT'
            WHEN 'CNL' THEN 'CANCEL'
			WHEN 'UCN' THEN 'IN_PROGRESS' -- JL20240801
            ELSE 'ACTIVE'
        END) emplr_status    
        -- JL20250311 Begin
        -- ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, sep.sep_acct_open_date, sep.term_date
        ,sep.is_er_skill_typ, sep.IS_CLASSIFICATION_CODES, sep.er_stts_lst_updtd_dt, nvl(sep.sep_acct_open_date, sep.date_joining_the_schm), sep.term_date
        -- JL20250311 End
        ,sep.business_nature_3, sep.company_type_3, sep.source_of_fund, sep.other_source_of_fund, NULL, NULL, NULL, sep.sep_acct_open_date
        ,NULL, sep.date_of_incorporation_3, sep.incrprtn_crtfct_nmbr_txt_3, branch_num_3, sep.company_chinese_nm_3, sep.is_er_license_typ
--        ,(CASE 
--            WHEN sep.company_nm_3 IS NOT NULL THEN sep.company_nm_3
--            ELSE sep.company_chinese_nm_3
--        END)
        ,sep.company_nm_3
        ,sep.term_date
        ,NULL, sep.mpfa_ref_no, sep.fund_clss_typ_id
        ,sep.bogus_acct, sep.additional_details
FROM    DM_SEP sep
WHERE   sep.scheme_code = '&&1'
--AND     NOT EXISTS (    SELECT 1
--                        FROM    DM_EMPLOYER er
--                        WHERE   er.registration_nmbr = sep.REGISTRATION_NMBR_3
--                        AND     er.scheme_code = sep.scheme_code)
AND     sep.REGISTRATION_TYPE_3 IS NOT NULL
-- AND     ROWNUM < 1
--  AND     SEP.trustee_SEP_cd in ('00000003883')
--AND     sep.trustee_sep_cd >= '30127969833' --
-- JL20250605 Begin
-- --GL20250516 Begin
-- UNION ALL
-- 
-- SELECT /*+ PARALLEL(32) */  
-- 		'ER' AS av_er_acct_type_code
-- 		,CR.trustee_entty_cd AS trustee_emplr_cd -- temp place holder for 8.1 mapping
-- 		,CR.related_person_id AS place_of_incorporation -- temp place holder for 8.1 mapping
-- 		,4 AS er_seq
--         ,'ACTIVE' AS emplr_status    
--         ,NULL AS is_er_skill_typ
-- 		,NULL AS is_er_classification_cd
-- 		,NULL AS er_stts_lst_updtd_dt
--         -- JL20250522 begin
-- 		-- ,NULL AS commencement_date
--         ,er.commencement_date
--         -- JL20250522 end
-- 		,NULL AS term_date
--         ,NULL AS business_nature
--         ,NULL AS company_type
-- 		,'Others' AS source_of_fund
-- 		,'Not Provided' AS other_source_of_fund
-- 		,'Not Provided' AS ongoing_source_of_fund
-- 		,NULL AS lspsp_offset_seq
-- 		,NULL AS enrl_sbmssn_chnnl
-- 		,NULL AS er_acct_open_date
--         ,NULL AS initial_source_of_fund
-- 		,NULL AS date_of_incorporation
-- 		,NULL AS incrprtn_crtfct_nmbr_txt
-- 		,CR.BRANCH_NUM
--         ,CR.COMPANY_CHINESE_NM
-- 		,NULL AS is_er_licence_typ
--         ,CR.COMPANY_NM
--         ,NULL AS schm_term_date
--         ,NULL AS company_group_cd
-- 		,NULL AS mpfa_ref_no
-- 		,NULL AS fund_clss_typ_id
--         ,NULL AS bogus_acct
-- 		,NULL AS additional_details
-- FROM  dm_correlated_person CR
-- -- JL20250522 begin
-- JOIN  dm_employer er
--     on CR.scheme_code = er.scheme_code
--     and CR.trustee_entty_cd = er.trustee_emplr_cd
-- -- JL20250522 end
-- WHERE CR.scheme_code = '&&1' 
-- AND (CR.company_nm is not null OR CR.COMPANY_CHINESE_NM IS NOT NULL)
-- AND CR.TYPE_COM_RELATED_PERSON IN ('DIRECTOR','BENE_OWNER')
-- AND CR.HKID_NMBR is null AND CR.passport_nmbr is null
-- --GL20250516 End
-- JL20250605 End
 )
-- JL20250307 Begin
ORDER BY er_seq, trustee_emplr_cd
-- JL20250307 End
;


er er_cur%ROWTYPE;

BEGIN
    dbms_output.put_line('START SCHEME ' || '&&1');
    --SELECT * FROM cmn_scheme
--    
--    SELECT  cycle_date
--    INTO    v_master_cycle_date
--    FROM    cmn_master_cycle
--    WHERE   cycle_date_step_code = 1;

    SELECT  sc.cycle_date, s.id, lpad(s.scheme_no, 2,'0')
    INTO    v_scheme_cycle_date, v_scheme_uuid, v_scheme_no
    FROM    cmn_scheme_cycle sc
            INNER JOIN cmn_scheme s
            ON  s.id = sc.tr_scheme_uuid
    WHERE   s.scheme_code = '&&1'
    AND     sc.cycle_date_step_code = '2';        

    v_pool_seq_no := 0;
    
    v_status_code := 'ACTIVE';
    
    BEGIN
        SELECT  (CASE 
                    WHEN LENGTH(scheme_attribute_value) < 32
                    THEN NULL
                    ELSE HEXTORAW(scheme_attribute_value)
                END)
        INTO    v_pah_dummp_uuid
        FROM    cmn_scheme_attr
        WHERE   scheme_code = '&&1' --'&&1'
        AND     scheme_attribute_name = 'DUMMY_ACCOUNT'
        AND     av_acct_type_code = 'PAH';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_pah_dummp_uuid := NULL;
    END;
    --
    --
    IF v_pah_dummp_uuid IS NOT NULL THEN 
          BEGIN
            SELECT  'Y'
            INTO    v_found_flg
            FROM    enr_er_acct er
            WHERE   er.id = HEXTORAW(v_pah_dummp_uuid)
            AND     er.scheme_code = '&&1';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_found_flg := 'N';
                  v_pah_dummp_uuid := NULL;
          END;      
    END IF;

-- GN-04072024 Begin
-- --    dbms_output.put_line('v_pah_dummp_uuid ' || v_pah_dummp_uuid); 
--     IF v_pah_dummp_uuid IS NULL AND '&&1' <> 'SK' THEN  
--           BEGIN
--             SELECT  id
--             INTO    v_er_uuid
--             FROM    reg_employer
--             WHERE   empf_id = '81111111111';
--             EXCEPTION
--                 WHEN NO_DATA_FOUND THEN
--                   v_er_uuid := NULL;
--           END;      
--         
-- --    dbms_output.put_line('v_er_uuid ' || v_er_uuid); 
--         IF v_er_uuid IS NULL THEN
--         
-- --            SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --            INTO    v_er_uuid
-- --            FROM   DUAL;                
--             
--             v_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--             
-- --                    
-- --            FOR empf IN empfid_cur LOOP  
-- --                UPDATE  reg_member
-- --                SET     empf_id = empf.empf_id
-- --                        ,indiv_code = empf_id
-- --                WHERE   empf_id IS NULL
-- --                AND     ROWNUM = 1;
-- --            END LOOP;    
-- --        
-- --            UPDATE reg_empf_id_pool
-- --            SET     av_status_code = 'USED'
-- --                    ,used_date = SYSDATE --v_master_cycle_date
-- --            WHERE   empf_id IN (    SELECT  rm.empf_id
-- --                                    FROM    reg_member rm
-- --                                    WHERE   rm.scheme_code = '&&1');
--     --                        
--     /*
--     SELECT * FROM temp_acct_no_pool ORDER BY SEQ_NO
--     */
--             INSERT INTO cmn_client
--             (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--              
--            
--             INSERT INTO reg_employer
--             (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--             ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--             ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--             ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--             ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--             ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, SCHEME_CODE)
--             VALUES
--             (v_er_uuid, '81111111111', 'HK', NULL, NULL
--             ,'Personal Account (DUMMY)', 'Personal Account (DUMMY)', 'ACTIVE', NULL, NULL
--             ,NULL, NULL, NULL, NULL, NULL
--             ,'OTHR', 'EMAIL', NULL, NULL
--             ,NULL, TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N'
--             ,v_scheme_cycle_date, NULL, NULL
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE, '&&1'); 
--         END IF;
-- 
-- --    dbms_output.put_line('v_er_uuid ' || v_er_uuid);
-- --        SELECT  id, acct_no
-- --        INTO    v_er_acct_no_uuid, v_er_acct_no
-- --        FROM    enr_acct_no_pool erp
-- --        WHERE   av_status_code = 'MIG'
-- --        AND     ROWNUM = 1;
-- --
-- --        UPDATE enr_acct_no_pool
-- --        SET     av_status_code = 'USED'
-- --                ,used_by = v_er_acct_uuid
-- --                ,used_date = v_scheme_cycle_date
-- --        WHERE   id = HEXTORAW(v_er_acct_no_uuid);
--         
--         v_pool_seq_no := v_pool_seq_no + 1;
--         --v_pool_seq_no        
-- 		
--                 dbms_output.put_line('v_pool_seq_no ' || v_pool_seq_no); 
--         SELECT  acct_no, acct_no_display
--         INTO    v_er_acct_no, v_er_acct_no_display
--         FROM    temp_acct_no_pool
--         WHERE   seq_no = v_pool_seq_no
--         AND     scheme_code = '&&1';
-- --            
-- --        SELECT  ROWNUM, acct_no, '&&1' || TO_CHAR(acct_no)
-- --        FROM    enr_acct_no_pool
-- --        WHERE   av_status_code = 'MIG'
-- --        AND     ROWNUM <= ((     SELECT  COUNT(1)
-- --                                FROM    DM_MEMBER) 
-- --                                + 
-- --                            (   SELECT  COUNT(1)
-- --                                FROM    DM_SEP) * 2
-- --                                + 
-- --                            (   SELECT  COUNT(1)
-- --                                FROM    DM_EMPLOYER)) * 2;
-- --                                
-- --        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --        INTO    v_pah_dummp_uuid
-- --        FROM   DUAL;    
--         
--         v_pah_dummp_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--             
--         --v_av_submit_channel
--         
--         INSERT INTO cmn_client
--         (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_pah_dummp_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         
--         v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
--         
--         INSERT INTO enr_er_acct
--         (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
--         ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
--         ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
--         ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
--         ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
--         
--         ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE
--         ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
--         ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
--         ,ER_GROUP_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_pah_dummp_uuid, v_er_uuid, v_scheme_uuid, v_er_acct_no, null
--         ,er.trustee_emplr_cd, v_status_code, NULL, NULL, NULL
--         ,NULL, NULL, v_ref_no, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N', NULL
--         ,NULL, NULL, 'N', NULL, NULL
--         
--         ,NULL, NULL, NULL, NULL, 'PA'
--         ,NULL, v_av_submit_channel, TO_DATE('20001201', 'YYYYMMDD'), v_er_acct_no_display, NULL
--         ,NULL, '&&1', NULL, TO_DATE('20001201', 'YYYYMMDD'), 'N'
--         ,NULL
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);          
--         
--         UPDATE cmn_scheme_attr
--         SET     scheme_attribute_value = v_pah_dummp_uuid
--         WHERE   scheme_attribute_name = 'DUMMY_ACCOUNT'
--         AND     av_acct_type_code = 'PAH'
--         AND     scheme_code = '&&1';
-- 
--         /*
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'FRMC';
--         
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3),v_pah_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'FRVC';
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3), v_pah_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         */
--     END IF;
-- GN-04072024 End

    BEGIN
        SELECT  (CASE 
                    WHEN LENGTH(scheme_attribute_value) < 32
                    THEN NULL
                    ELSE HEXTORAW(scheme_attribute_value)
                END)
        INTO    v_sep_dummp_uuid
        FROM    cmn_scheme_attr
        WHERE   scheme_code = '&&1' --'&&1'
        AND     scheme_attribute_name = 'DUMMY_ACCOUNT'
        AND     av_acct_type_code = 'SEP';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_sep_dummp_uuid := NULL;
    END;
    
    IF v_sep_dummp_uuid IS NOT NULL THEN 
        BEGIN
            SELECT  'Y'
            INTO    v_found_flg
            FROM    enr_er_acct er
            WHERE   er.id = HEXTORAW(v_sep_dummp_uuid)
            AND     er.scheme_code = '&&1';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_found_flg := 'N';
                    v_sep_dummp_uuid := NULL;
        END;
    END IF;
    
-- GN-04072024 Begin
--     IF v_sep_dummp_uuid IS NULL AND '&&1' <> 'SK' THEN   
--         BEGIN
--             SELECT  id
--             INTO    v_sep_er_uuid
--             FROM    reg_employer
--             WHERE   empf_id = '84444444444';
--             EXCEPTION
--                 WHEN NO_DATA_FOUND THEN
--                   v_sep_er_uuid := NULL;
--           END;      
--         
--         IF v_sep_er_uuid IS NULL THEN
-- --            SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --            INTO    v_sep_er_uuid
-- --            FROM   DUAL;    
--                 
--             v_sep_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--             INSERT INTO cmn_client
--             (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_sep_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--                     
--             INSERT INTO reg_employer
--             (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--             ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--             ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--             ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--             ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--             ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, SCHEME_CODE)
--             VALUES
--             (v_sep_er_uuid, '84444444444', 'HK', NULL, NULL
--             ,'Self-Employed Persons (DUMMY)', 'Self-Employed Persons (DUMMY)', 'ACTIVE', NULL, NULL
--             ,NULL, NULL, NULL, NULL, NULL
--             ,'OTHR', 'EMAIL', NULL, NULL
--             ,NULL, TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N'
--             ,v_scheme_cycle_date, NULL, NULL
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE, '&&1'); 
--         END IF;
--                     
-- --        SELECT  id, acct_no
-- --        INTO    v_er_acct_no_uuid, v_er_acct_no
-- --        FROM    enr_acct_no_pool erp
-- --        WHERE   av_status_code = 'MIG'
-- --        AND     ROWNUM = 1;
-- --
-- --        UPDATE enr_acct_no_pool
-- --        SET     av_status_code = 'USED'
-- --                ,used_by = v_er_acct_uuid
-- --                ,used_date = v_scheme_cycle_date
-- --        WHERE   id = HEXTORAW(v_er_acct_no_uuid);
--         
--         v_pool_seq_no := v_pool_seq_no + 1;
--         
--         SELECT  acct_no, acct_no_display
--         INTO    v_er_acct_no, v_er_acct_no_display
--         FROM    temp_acct_no_pool
--         WHERE   seq_no = v_pool_seq_no and scheme_code = '&&1';
--         
-- --        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --        INTO    v_sep_dummp_uuid
-- --        FROM   DUAL;    
--         
--         v_sep_dummp_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--         INSERT INTO cmn_client
--         (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_sep_dummp_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         
--         
--         v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
--         
--         INSERT INTO enr_er_acct
--         (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
--         ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
--         ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
--         ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
--         ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
--         ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE
--         ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
--         ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
--         ,ER_GROUP_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_sep_dummp_uuid, v_sep_er_uuid, v_scheme_uuid, v_er_acct_no, null
--         ,er.trustee_emplr_cd, v_status_code, NULL, NULL, NULL
--         ,NULL, NULL, v_ref_no, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N', NULL
--         ,NULL, NULL, 'N', NULL, NULL
--         ,NULL, NULL, NULL, NULL, 'SEP'
--         ,NULL, v_av_submit_channel, TO_DATE('20001201', 'YYYYMMDD'), v_er_acct_no_display, NULL
--         ,NULL, '&&1', NULL, TO_DATE('20001201', 'YYYYMMDD'), 'N'
--         ,NULL
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
-- --                
-- --    dbms_output.put_line('v_sep_er_uuid ' || v_sep_er_uuid);
-- --    dbms_output.put_line('v_sep_dummp_uuid ' || v_sep_dummp_uuid);
-- --    
--     
--         UPDATE cmn_scheme_attr
--         SET     scheme_attribute_value = v_sep_dummp_uuid
--         WHERE   scheme_attribute_name = 'DUMMY_ACCOUNT'
--         AND     av_acct_type_code = 'SEP'
--         AND     scheme_code = '&&1';
--         
--         /*
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'SEPMC';
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3), v_sep_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);     
--         
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'SEPVC';
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3), v_sep_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         */
--     END IF;
--     dbms_output.put_line('v_sep_dummp_uuid ' || v_sep_dummp_uuid);
-- GN-04072024 End
    
    BEGIN
        SELECT  (CASE 
                    WHEN LENGTH(scheme_attribute_value) < 32
                    THEN NULL
                    ELSE HEXTORAW(scheme_attribute_value)
                END)
        INTO    v_tvc_dummp_uuid
        FROM    cmn_scheme_attr
        WHERE   scheme_code = '&&1' --'&&1'
        AND     scheme_attribute_name = 'DUMMY_ACCOUNT'
        AND     av_acct_type_code = 'TVC';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_tvc_dummp_uuid := NULL;
    END;
    
    IF v_tvc_dummp_uuid IS NOT NULL THEN 
        BEGIN
            SELECT  'Y'
        INTO    v_found_flg
        FROM    enr_er_acct er
        WHERE   er.id = HEXTORAW(v_tvc_dummp_uuid)
        AND     er.scheme_code = '&&1';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_found_flg := 'N';
                v_tvc_dummp_uuid := NULL;
        END;
    END IF;
    
-- GN-04072024 Begin
--     IF v_tvc_dummp_uuid IS NULL AND '&&1' <> 'SK' THEN    
--           BEGIN
--             SELECT  id
--             INTO    v_er_uuid
--             FROM    reg_employer
--             WHERE   empf_id = '83333333333';
--             EXCEPTION
--                 WHEN NO_DATA_FOUND THEN
--                   v_er_uuid := NULL;
--           END;      
--         
--         IF v_er_uuid IS NULL THEN
-- --            SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --            INTO    v_er_uuid
-- --            FROM   DUAL;    
--                     
--             v_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--             INSERT INTO cmn_client
--             (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--              
--             INSERT INTO reg_employer
--             (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--             ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--             ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--             ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--             ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--             ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, SCHEME_CODE)
--             VALUES
--             (v_er_uuid, '83333333333', 'HK', NULL, NULL
--             ,'Taxable VC (DUMMY)', 'Taxable VC (DUMMY)', 'ACTIVE', NULL, NULL
--             ,NULL, NULL, NULL, NULL, NULL
--             ,'OTHR', 'EMAIL', NULL, NULL
--             ,NULL, TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N'
--             ,v_scheme_cycle_date, NULL, NULL
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE, '&&1'); 
--         END IF;
--         
-- --        SELECT  id, acct_no
-- --        INTO    v_er_acct_no_uuid, v_er_acct_no
-- --        FROM    enr_acct_no_pool erp
-- --        WHERE   av_status_code = 'MIG'
-- --        AND     ROWNUM = 1;
-- --
-- --        UPDATE enr_acct_no_pool
-- --        SET     av_status_code = 'USED'
-- --                ,used_by = v_er_acct_uuid
-- --                ,used_date = v_scheme_cycle_date
-- --        WHERE   id = HEXTORAW(v_er_acct_no_uuid);
--         
--         v_pool_seq_no := v_pool_seq_no + 1;
--         
--         SELECT  acct_no, acct_no_display
--         INTO    v_er_acct_no, v_er_acct_no_display
--         FROM    temp_acct_no_pool
--         WHERE   seq_no = v_pool_seq_no and scheme_code = '&&1';
--         
-- --        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --        INTO    v_tvc_dummp_uuid
-- --        FROM   DUAL;    
--         
--         v_tvc_dummp_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--             
--         INSERT INTO cmn_client
--         (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_tvc_dummp_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--                 
--         v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
--         
--         INSERT INTO enr_er_acct
--         (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
--         ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
--         ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
--         ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
--         ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
--         ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE
--         ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
--         ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
--         ,ER_GROUP_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_tvc_dummp_uuid, v_er_uuid, v_scheme_uuid, v_er_acct_no, null
--         ,er.trustee_emplr_cd, v_status_code, NULL, NULL, NULL
--         ,NULL, NULL, v_ref_no, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N', NULL
--         ,NULL, NULL, 'N', NULL, NULL
--         ,NULL, NULL, NULL, NULL, 'TVC'
--         ,NULL, v_av_submit_channel, TO_DATE('20001201', 'YYYYMMDD'), v_er_acct_no_display, NULL
--         ,NULL, '&&1', NULL, TO_DATE('20001201', 'YYYYMMDD'), 'N'
--         ,NULL
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         
--         UPDATE cmn_scheme_attr
--         SET     scheme_attribute_value = v_tvc_dummp_uuid
--         WHERE   scheme_attribute_name = 'DUMMY_ACCOUNT'
--         AND     av_acct_type_code = 'TVC'
--         AND     scheme_code = '&&1';
--         /*
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'TVC';
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3), v_tvc_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         */   
--     END IF;
--     
--     dbms_output.put_line('v_tvc_dummp_uuid ' || v_tvc_dummp_uuid);
-- GN-04072024 End

    BEGIN
        SELECT  (CASE 
                    WHEN LENGTH(scheme_attribute_value) < 32
                    THEN NULL
                    ELSE HEXTORAW(scheme_attribute_value)
                END)
        INTO    v_svc_dummp_uuid
        FROM    cmn_scheme_attr
        WHERE   scheme_code = '&&1' --'&&1'
        AND     scheme_attribute_name = 'DUMMY_ACCOUNT'
        AND     av_acct_type_code = 'SVC';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_svc_dummp_uuid := NULL;
    END;
    
    IF v_svc_dummp_uuid IS NOT NULL THEN 
        BEGIN
            SELECT  'Y'
            INTO    v_found_flg
            FROM    enr_er_acct er
            WHERE   er.id = HEXTORAW(v_svc_dummp_uuid)
            AND     er.scheme_code = '&&1';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_found_flg := 'N';
                v_svc_dummp_uuid := NULL;
        END;

    END IF;
    
-- GN-04072024 Begin
-- --    dbms_output.put_line('v_svc_dummp_uuid ' || v_svc_dummp_uuid);
--     IF v_svc_dummp_uuid IS NULL AND '&&1' <> 'SK' THEN   
--           BEGIN
--             SELECT  id
--             INTO    v_er_uuid
--             FROM    reg_employer
--             WHERE   empf_id = '82222222222';
--             EXCEPTION
--                 WHEN NO_DATA_FOUND THEN
--                   v_er_uuid := NULL;
--           END;      
--         
--         IF v_er_uuid IS NULL THEN
-- --            SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --            INTO    v_er_uuid
-- --            FROM   DUAL;    
--                     
--             v_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--             INSERT INTO cmn_client
--             (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--              
--             INSERT INTO reg_employer
--             (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--             ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--             ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--             ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--             ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--             ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE, SCHEME_CODE
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, '82222222222', 'HK', NULL, NULL
--             ,'Special VC (DUMMY)', 'Special VC (DUMMY)', 'ACTIVE', NULL, NULL
--             ,NULL, NULL, NULL, NULL, NULL
--             ,'OTHR', 'EMAIL', NULL, NULL
--             ,NULL, TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N'
--             ,v_scheme_cycle_date, NULL, NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         END IF;
--         
-- --        SELECT  id, acct_no
-- --        INTO    v_er_acct_no_uuid, v_er_acct_no
-- --        FROM    enr_acct_no_pool erp
-- --        WHERE   av_status_code = 'MIG'
-- --        AND     ROWNUM = 1;
-- --
-- --        UPDATE enr_acct_no_pool
-- --        SET     av_status_code = 'USED'
-- --                ,used_by = v_er_acct_uuid
-- --                ,used_date = v_scheme_cycle_date
-- --        WHERE   id = HEXTORAW(v_er_acct_no_uuid);
--         
--         v_pool_seq_no := v_pool_seq_no + 1;
--         
--         SELECT  acct_no, acct_no_display
--         INTO    v_er_acct_no, v_er_acct_no_display
--         FROM    temp_acct_no_pool
--         WHERE   seq_no = v_pool_seq_no and scheme_code = '&&1';
-- --        
-- --        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --        INTO    v_svc_dummp_uuid
-- --        FROM   DUAL;    
--         
--         v_svc_dummp_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--         INSERT INTO cmn_client
--         (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_svc_dummp_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--                 
--         v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
--         
--         INSERT INTO enr_er_acct
--         (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
--         ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
--         ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
--         ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
--         ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
--         ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE
--         ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
--         ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
--         ,ER_GROUP_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_svc_dummp_uuid, v_er_uuid, v_scheme_uuid, v_er_acct_no, null
--         ,er.trustee_emplr_cd, v_status_code, NULL, NULL, NULL
--         ,NULL, NULL, v_ref_no, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N', NULL
--         ,NULL, NULL, 'N', NULL, NULL
--         ,NULL, NULL, NULL, NULL, 'SVC'
--         ,NULL, v_av_submit_channel, TO_DATE('20001201', 'YYYYMMDD'), v_er_acct_no_display, NULL
--         ,NULL, '&&1', NULL, TO_DATE('20001201', 'YYYYMMDD'), 'N'
--         ,NULL
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         
--         UPDATE cmn_scheme_attr
--         SET     scheme_attribute_value = v_svc_dummp_uuid
--         WHERE   scheme_attribute_name = 'DUMMY_ACCOUNT'
--         AND     av_acct_type_code = 'SVC'
--         AND     scheme_code = '&&1';
--         /*
--         SELECT  id
--         INTO    v_subacct_type_uuid
--         FROM    enr_subacct_type
--         WHERE   subacct_type_short_name = 'SVC';
--         
--         INSERT INTO enr_er_subacct_type
--         (ID, er_acct_uuid, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--         ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_scheme_no||SUBSTR(sys_guid(),3), v_svc_dummp_uuid, v_subacct_type_uuid, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,v_scheme_cycle_date, 'N', v_er_acct_no, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE); 
--         */
--     END IF;
--     
--     dbms_output.put_line('v_svc_dummp_uuid ' || v_svc_dummp_uuid);
-- GN-04072024 End

    BEGIN
        SELECT  (CASE 
                    WHEN LENGTH(scheme_attribute_value) < 32
                    THEN NULL
                    ELSE HEXTORAW(scheme_attribute_value)
                END)
        INTO    v_cee_dummp_uuid
        FROM    cmn_scheme_attr
        WHERE   scheme_code = '&&1' --'&&1'
        AND     scheme_attribute_name = 'DUMMY_ACCOUNT'
-- GN-19062024 Begin
        AND     av_acct_type_code = 'CEE';
-- GN-19062024 End
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
              v_cee_dummp_uuid := NULL;
    END;
    
    IF v_cee_dummp_uuid IS NOT NULL THEN 
        BEGIN
            SELECT  'Y'
            INTO    v_found_flg
            FROM    enr_er_acct er
            WHERE   er.id = HEXTORAW(v_cee_dummp_uuid)
            AND     er.scheme_code = '&&1';
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_found_flg := 'N';
                v_cee_dummp_uuid := NULL;
        END;

    END IF;
    
-- GN-04072024 Begin
-- --    dbms_output.put_line('v_cee_dummp_uuid ' || v_cee_dummp_uuid);
-- -- GN-19062024 Begin
-- --    IF v_cee_dummp_uuid IS NULL THEN   
--     IF v_cee_dummp_uuid IS NULL AND '&&1' <> 'SK' AND ('&&1' = 'IS' OR '&&1' = 'IC')THEN   
-- -- GN-19062024 End
--           BEGIN
--             SELECT  id
--             INTO    v_er_uuid
--             FROM    reg_employer
--             WHERE   empf_id = '85555555555';
--             EXCEPTION
--                 WHEN NO_DATA_FOUND THEN
--                   v_er_uuid := NULL;
--           END;      
--         
--         IF v_er_uuid IS NULL THEN
-- --            SELECT v_scheme_no||SUBSTR(sys_guid(),3)
-- --            INTO    v_er_uuid
-- --            FROM   DUAL;    
--                     
--             v_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--             INSERT INTO cmn_client
--             (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);                
--              
--             INSERT INTO reg_employer
--             (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--             ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--             ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--             ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--             ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--             ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE, SCHEME_CODE
--             ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--             VALUES
--             (v_er_uuid, '85555555555', 'HK', NULL, NULL
-- -- GN-19062024 Begin
--             ,'Casual Employee (DUMMY)', 'Casual Employee (DUMMY)', 'ACTIVE', NULL, NULL
-- -- GN-19062024 End
--             ,NULL, NULL, NULL, NULL, NULL
--             ,'OTHR', 'EMAIL', NULL, NULL
--             ,NULL, TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N'
--             ,v_scheme_cycle_date, NULL, NULL, '&&1'
--                     ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         END IF;
--         
-- 							 
-- 												 
-- 									  
-- 										
-- 							 
--   
-- 								 
-- 										 
-- 										   
-- 												  
-- 												   
-- 		
--         v_pool_seq_no := v_pool_seq_no + 1;
--         
--         SELECT  acct_no, acct_no_display
--         INTO    v_er_acct_no, v_er_acct_no_display
--         FROM    temp_acct_no_pool
--         WHERE   seq_no = v_pool_seq_no and scheme_code = '&&1';
--         
-- 						   
-- 								  
-- 						  
--         
--         v_cee_dummp_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
--         
--         INSERT INTO cmn_client
--         (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_cee_dummp_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--                 
--         v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
--         
--         INSERT INTO enr_er_acct
--         (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
--         ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
--         ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
--         ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
--         ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
--         ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE
--         ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
--         ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
--         ,ER_GROUP_CODE
--         ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--         VALUES
--         (v_cee_dummp_uuid, v_er_uuid, v_scheme_uuid, v_er_acct_no, null
--         ,er.trustee_emplr_cd, v_status_code, NULL, NULL, NULL
--         ,NULL, NULL, v_ref_no, TO_DATE('20001201', 'YYYYMMDD'), NULL
--         ,TO_DATE('20001201', 'YYYYMMDD'), v_scheme_cycle_date, 'N', 'N', NULL
--         ,NULL, NULL, 'N', NULL, NULL
--         ,NULL, NULL, NULL, NULL, 'ER'
--         ,NULL, v_av_submit_channel, TO_DATE('20001201', 'YYYYMMDD'), v_er_acct_no_display, NULL
--         ,NULL, '&&1', NULL, TO_DATE('20001201', 'YYYYMMDD'), 'N'
--         ,NULL
--                 ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
--         
--         UPDATE cmn_scheme_attr
--         SET     scheme_attribute_value = v_cee_dummp_uuid
--         WHERE   scheme_attribute_name = 'DUMMY_ACCOUNT'
--         AND     av_acct_type_code = 'CEE'
--         AND     scheme_code = '&&1';
-- 		  
-- 				  
-- 								   
-- 								
-- 												
--         
-- 									   
-- 																 
-- 																   
-- 																	  
-- 			  
-- 																								 
-- 															  
-- 															  
-- 		  
--     END IF;
--     
--     dbms_output.put_line('v_cee_dummp_uuid ' || v_cee_dummp_uuid);
-- GN-04072024 End

	cas_dm_util_pkg.disable_constraint('&&1', 'CMN_CLIENT');
	cas_dm_util_pkg.disable_constraint('&&1', 'REG_EMPLOYER');
	cas_dm_util_pkg.disable_constraint('&&1', 'ENR_ER_ACCT');
	cas_dm_util_pkg.disable_constraint('&&1', 'CMN_SOURCE_OF_FUND');
	cas_dm_util_pkg.disable_constraint('&&1', 'ENR_ER_SUBACCT_TYPE');
	cas_dm_util_pkg.disable_index('&&1', 'CMN_CLIENT');
	cas_dm_util_pkg.disable_index('&&1', 'REG_EMPLOYER');
	cas_dm_util_pkg.disable_index('&&1', 'ENR_ER_ACCT');
	cas_dm_util_pkg.disable_index('&&1', 'CMN_SOURCE_OF_FUND');
	cas_dm_util_pkg.disable_index('&&1', 'ENR_ER_SUBACCT_TYPE');

	--WL20250127 begin
	select decode(count(*), 0, 'N', 'Y')
	into v_mfund_class_flag
	from cmn_scheme_attr a 
	where a.scheme_attribute_name = 'FUND_CLASS' 
	and scheme_code = '&&1';
	--WL20250127 end

    -- ER Level
    FOR er IN er_cur LOOP  
--        dbms_output.put_line('er.trustee_emplr_cd ' || er.trustee_emplr_cd);                 
--        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
--        INTO    v_er_uuid
--        FROM   DUAL;    
        
        v_er_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
    
        INSERT INTO cmn_client
        (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        VALUES
        (v_er_uuid, 'EMPLOYER', 'N', NULL, '&&1'
                ,v_update_by, SYSDATE, v_update_by, SYSDATE);   
        
--       dbms_output.put_line('v_empf_id_uuid ' || v_empf_id_uuid); 
        BEGIN
            SELECT  c.country_code
            INTO    v_country_code
            FROM    cmn_country c
            WHERE   c.country_code_alpha3 = er.place_of_incorporation;
            EXCEPTION
            WHEN NO_DATA_FOUND THEN      
                -- GL20250516 Begin
                -- v_country_code := er.place_of_incorporation;      
                -- JL20250605 Begin
                -- v_country_code := case when er.er_seq = 4 then NULL else er.place_of_incorporation end;
                v_country_code := er.place_of_incorporation;
                -- JL20250605 End
                -- GL20250516 End
        END;        
        
--        
--        INSERT INTO reg_employer
--        (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
--        ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
--        ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
--        ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
--        ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
--        ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE, SCHEME_CODE
--        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--        SELECT *
--        FROM    
--       dbms_output.put_line('er.trustee_emplr_cd ' || er.trustee_emplr_cd); 

        -- reg_employer
        INSERT INTO reg_employer
        (ID, EMPF_ID, COUNTRY_CODE, ER_GROUP_CODE, TR_COMPANY_CODE
        ,ER_NAME, ER_NAME_ZHHK, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE
        ,BRANCH_DESC, BRANCH_NO, CORP_CERT_NO, CORP_DATE, AV_ORG_TYPE_CODE
        ,AV_BIZ_NATURE_CODE, AV_NOTIFY_MEDIUM_CODE, TAX_RESIDNCY_HK_FLAG, DEREG_DETECT_SUSPEND_DATE
        ,TERM_DATE, EFF_DATE, CYCLE_CHANGE_DATE, ARCHIVE_FLAG, MIGRATE_FLAG
        ,STATUS_UPDATE_DATE, AV_ISCHEME_CLASSIF_CODE, AV_ER_SKILL_TYPE, SCHEME_CODE
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        VALUES
        -- JL20250526 begin
        -- (v_er_uuid, NULL, v_country_code, NULL, er.trustee_emplr_cd
        -- JL20250605 begin
        -- (v_er_uuid, NULL, v_country_code, NULL, case when er.er_seq = 4 then NULL else er.trustee_emplr_cd end
        (v_er_uuid, NULL, v_country_code, NULL, er.trustee_emplr_cd
        -- JL20250605 end
        -- JL20250526 end
        ,er.company_nm, er.company_chinese_nm, v_status_code, NULL, NULL
        ,NULL, er.branch_num, er.incrprtn_crtfct_nmbr_txt, TO_DATE(er.date_of_incorporation, 'YYYY-MM-DD'), UPPER(er.company_type)
        ,nvl(er.business_nature, 'OTHR'), NULL, NULL, NULL
        ,TO_DATE(er.term_date, 'YYYY-MM-DD'), TO_DATE(er.commencement_date, 'YYYY-MM-DD'), v_scheme_cycle_date, 'N', 'Y'
        ,TO_DATE(er.er_stts_lst_updtd_dt, 'YYYY-MM-DD'), er.is_er_classification_cd, er.is_er_skill_typ, '&&1'
                ,v_update_by, SYSDATE, v_update_by, SYSDATE);         

--        SELECT v_scheme_no||SUBSTR(sys_guid(),3)
--        INTO    v_er_acct_uuid
--        FROM   DUAL;    
                
        v_er_acct_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ;
        
        INSERT INTO cmn_client
        (id, system_client_type, archive_flag, scheme_onboard_seq, scheme_code
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        VALUES
        -- JL20250605 Begin
        -- (v_er_acct_uuid,
		-- --GL20250516 Begin
		-- CASE er.er_seq
        --     WHEN 4 THEN 'EMPLOYER_CONTACT'
        --     ELSE 'EMPLOYER_ACCT' END
		-- -- , 'N', NULL, '&&1',v_update_by, SYSDATE, v_update_by, SYSDATE);   
        -- , 'N', NULL, '&&1',
        -- CASE er.er_seq
        --     WHEN 4 THEN er.place_of_incorporation
        --     ELSE v_update_by END
        -- , SYSDATE, 
        -- CASE er.er_seq
        --     WHEN 4 THEN er.trustee_emplr_cd
        --     ELSE v_update_by END
        -- , SYSDATE);
        -- --GL20250516 End
        (v_er_acct_uuid, 'EMPLOYER_ACCT', 'N', NULL, '&&1'
                ,v_update_by, SYSDATE, v_update_by, SYSDATE);  
        -- JL20250605 End
        
        IF er.source_of_fund = 'Others' THEN
            v_source_of_fund := 'OTHERS';
        ELSIF er.source_of_fund = 'Salary' THEN
            v_source_of_fund := 'SALARY';
        ELSIF er.source_of_fund = 'Personal savings' THEN
            v_source_of_fund := 'PERSONAL_SAVINGS';
        ELSIF er.source_of_fund = 'Business income and profits' THEN
            v_source_of_fund := 'BUSINESS_INCOME_AND_PROFITS';
        ELSIF er.source_of_fund = 'Inheritance' THEN
            v_source_of_fund := 'INHERITANCE';
        ELSIF er.source_of_fund = 'Sale of property' THEN
            v_source_of_fund := 'SALES_OF_PROPERTY';
        ELSIF er.source_of_fund = 'Investment return / Investment matured' THEN
            v_source_of_fund := 'INVEST_RETURN_OR_MATURED';
        END IF;
        
        IF er.other_source_of_fund = 'Not Provided' THEN            
            v_source_fund_desc := NULL;
        ELSE
            v_source_fund_desc := er.other_source_of_fund;
        END IF;
        
        IF er.initial_source_of_fund = 'Not Provided' THEN            
            v_origin_initial_source := NULL;
        ELSE
            v_origin_initial_source := er.initial_source_of_fund;
        END IF;
        IF er.ongoing_source_of_fund = 'Not Provided' THEN            
            v_origin_ongoing_source := NULL;
        ELSE
            v_origin_ongoing_source := er.ongoing_source_of_fund;
        END IF;
        
        IF UPPER(er.lspsp_offset_seq) = 'OFFSET VC THEN MC' THEN      
            v_av_lspsp_offset_seq := 'OFFSET_VC_MC';
        ELSE
            v_av_lspsp_offset_seq := 'OFFSET_MC_VC';
        END IF;
        
        IF er.enrl_sbmssn_chnnl IS NULL THEN
            v_av_submit_channel := NULL;
        ELSIF er.enrl_sbmssn_chnnl = 'WEB' THEN
            v_av_submit_channel := 'WEB_PORTAL';
        ELSIF er.enrl_sbmssn_chnnl IN ('FAX', 'EML', 'PST') THEN
										   
											   
            v_av_submit_channel := 'PAPER_FORM';
        ELSIF er.enrl_sbmssn_chnnl = 'OTH' THEN
            v_av_submit_channel := 'OTHERS';        
        END IF;
        
        --v_av_er_acct_type_code := 'ER';                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   
        v_er_eff_date := TO_DATE(er.commencement_date, 'YYYY-MM-DD');
--        dbms_output.put_line('v_er_acct_uuid ' || v_er_acct_uuid);
--        dbms_output.put_line('v_trustee_emplr_cd ' || v_trustee_emplr_cd);

        -- JL20241004 Begin
        -- v_pool_seq_no := v_pool_seq_no + 1;
        -- 
        -- SELECT  acct_no, acct_no_display
        -- INTO    v_er_acct_no, v_er_acct_no_display
        -- FROM    temp_acct_no_pool
        -- WHERE   seq_no = v_pool_seq_no and scheme_code = '&&1';  
        
        BEGIN
            SELECT  acct_no, acct_no_display
            INTO    v_er_acct_no, v_er_acct_no_display
            FROM    dm_ud_acct_mapping
            -- JL20250526 begin
            -- WHERE   trustee_entity_code = er.trustee_emplr_cd and scheme_code = '&&1' and er.av_er_acct_type_code <> 'SEP';
            -- JL20250605 begin
            -- WHERE   trustee_entity_code = er.trustee_emplr_cd and scheme_code = '&&1' and entity_type = 'ER' and er.er_seq <> 4;
			-- JL20250806 begin
            -- WHERE   trustee_entity_code = er.trustee_emplr_cd and scheme_code = '&&1' and er.av_er_acct_type_code <> 'SEP';
			WHERE   trustee_entity_code = er.trustee_emplr_cd and scheme_code = '&&1' and entity_type = 'ER' and er.av_er_acct_type_code <> 'SEP';
			-- JL20250806 end
            -- JL20250605 end
            -- JL20250526 end
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_pool_seq_no := v_pool_seq_no + 1;
                    v_er_acct_no := -v_pool_seq_no;
                    v_er_acct_no_display := -v_pool_seq_no;
        END;
        -- JL20241004 End
        
        v_ref_no := 'ENP' || v_scheme_no || '0' || TO_CHAR(v_er_acct_no) || '0';
        
--        dbms_output.put_line('v_er_acct_no ' || v_er_acct_no);
        -- enr_er_acct
        
--        dbms_output.put_line('er.trustee_emplr_cd ' || er.trustee_emplr_cd);  
--        dbms_output.put_line('er.fund_clss_typ_id ' || er.fund_clss_typ_id);  
--        dbms_output.put_line('v_av_submit_channel ' || v_av_submit_channel); 
        
        INSERT INTO enr_er_acct
        (ID, EMPLOYER_UUID, TR_SCHEME_UUID, ER_ACCT_NO, COPY_FROM_ER_ACCT_CODE
        ,TR_EMPLOYER_CODE, AV_STATUS_CODE, AV_AML_RISK_LEVEL, AV_AML_RISK_TYPE, AV_FUND_CLASS
        ,MEM_ACCT_COUNT, MPFA_REF_NO, REF_NO, START_DATE, TERM_DATE
        ,EFF_DATE, CYCLE_CHANGE_DATE, CONTACT_DATA_VERIFY_FLAG, ARCHIVE_FLAG, SCHEME_TERM_EFF_DATE
        ,AV_ISCHEME_ER_LICENSE_TYPE, SEP_PRIMARY_ER_FLAG, MIGRATE_FLAG, EXTRA_DTL, AV_SOURCE_FUND
        ,SOURCE_FUND_DESC, ORIGIN_INITIAL_SOURCE, ORIGIN_ONGOING_SOURCE, AV_LSPSP_OFFSET_SEQ, AV_ER_ACCT_TYPE_CODE        
        ,CLIENT_SEGMENT, AV_SUBMIT_CHANNEL, STATUS_UPDATE_DATE, ER_ACCT_NO_DISPLAY, SEP_MEM_ACCT_UUID        
        ,BOGUS_ACCT_FLAG, SCHEME_CODE, SOURCE_OF_FUND_UUID, ENR_CREATE_DATE, ER_ENR_AFTER_SEP_FLAG
        ,ER_GROUP_CODE
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        VALUES
        (v_er_acct_uuid, v_er_uuid, v_scheme_uuid, v_er_acct_no, NULL --er.fund_clss_typ_id
        --WL20250127 begin
		--,er.trustee_emplr_cd, er.emplr_status, NULL, NULL, NULL
		-- GL20250516 begin
        -- ,er.trustee_emplr_cd, er.emplr_status, NULL, NULL, decode(v_mfund_class_flag, 'Y', er.fund_clss_typ_id, NULL)
        -- JL20250605 begin
        -- ,case when er.er_seq = 4 then NULL else er.trustee_emplr_cd end, er.emplr_status, NULL, NULL, decode(v_mfund_class_flag, 'Y', er.fund_clss_typ_id, NULL)
        ,er.trustee_emplr_cd, er.emplr_status, NULL, NULL, decode(v_mfund_class_flag, 'Y', er.fund_clss_typ_id, NULL)
        -- JL20250605 end
        -- GL20250516 end
		--WL20250127 end
        ,NULL, er.mpfa_ref_no, v_ref_no, v_er_eff_date, TO_DATE(er.term_date, 'YYYY-MM-DD')
        ,v_er_eff_date, v_scheme_cycle_date, 'N', 'N', TO_DATE(er.schm_term_date, 'YYYY-MM-DD')
        ,er.is_er_licence_typ, NULL, 'Y', er.additional_details, v_source_of_fund
        ,v_source_fund_desc, v_origin_initial_source, v_origin_ongoing_source, v_av_lspsp_offset_seq, er.av_er_acct_type_code
        ,NULL, v_av_submit_channel, TO_DATE(er.er_stts_lst_updtd_dt, 'YYYY-MM-DD'), v_er_acct_no_display, NULL
        ,er.bogus_acct, '&&1', NULL, TO_DATE(er.er_acct_open_date, 'YYYY-MM-DD'), 'N'
        ,er.company_group_cd
                ,v_update_by, SYSDATE, v_update_by, SYSDATE);
        
-----v1 start 		
        v_source_of_fund_uuid := v_scheme_no||SUBSTR(sys_guid(),3) ; 
        -- JL20250605 begin
        -- -- JL20250522 begin
        -- -- IF er.er_seq <> 4 THEN
        -- -- JL20250522 end
        -- JL20250605 end
        INSERT INTO CMN_SOURCE_OF_FUND 
            (ID, CLIENT_UUID, AV_CLIENT_TYPE, AV_MODULE_CODE, 
            AV_SOURCE_FUND, AMT_OF_FUND, NAME_OF_BANK, TOTAL_AMT_SAVE, DESC_OF_INVEST_HOLD, 
            VALUE_OF_INVEST, SALE_PROCEED, DATE_OF_SALE, DESC_OF_MATURE_INVEST, 
            AMT_FROM_INVEST, DATE_OF_MATURE, DTL_OF_INHERIT, DATE_RECEIVE_INHERIT, 
            AMT_FROM_INHERIT, NATURE_OF_INCOME, AMT_OF_RECEIVE, DATE_OF_RECEIPT, 
            CYCLE_CHANGE_DATE, EFF_DATE, ARCHIVE_FLAG, ORIG_INITIAL_SOURCE, 
            ORIG_ONGOING_SOURCE, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, 
            SEQ_NO, ADDR_UUID, SCHEME_CODE)
             VALUES  
                (
                    v_source_of_fund_uuid, v_er_acct_uuid,'EMPLOYER_ACCT','ENR',   -- ID, CLIENT_UUID, AV_CLIENT_TYPE, AV_MODULE_CODE, 
                    CASE upper( v_source_of_fund )
                        when 'OTHERS' then 'OTHERS' 
                        when 'SALARY' then 'SALARY'
                        when 'BUSINESS INCOME AND PROFITS' then 'BIZ_INCOME_PROFITS'
                        when 'INHERITANCE' then 'INHERITANCE'
                        when 'SALE OF PROPERTY' then 'SALE_OF_PROPERTY'
                        when 'INVESTMENT RETURN / INVESTMENT MATURED' then 'INV_RETURN_MATURED'
                        else 'OTHERS'
                    END, null, null, null, null, ---- Source_fund , AMT_OF_FUND, NAME_OF_BANK, TOTAL_AMT_SAVE, DESC_OF_INVEST_HOLD, 
                    null, null, null, null,   ---- VALUE_OF_INVEST, SALE_PROCEED, DATE_OF_SALE, DESC_OF_MATURE_INVEST, 
                    null, null, null, null,  --- AMT_FROM_INVEST, DATE_OF_MATURE, DTL_OF_INHERIT, DATE_RECEIVE_INHERIT, 
                    null, CASE upper( v_source_fund_desc ) when 'OTHERS' then v_source_fund_desc else null END, null, null,  --		AMT_FROM_INHERIT, NATURE_OF_INCOME, AMT_OF_RECEIVE, DATE_OF_RECEIPT,
                    v_scheme_cycle_date, v_er_eff_date, 'N', v_origin_initial_source, -- CYCLE_CHANGE_DATE, EFF_DATE, ARCHIVE_FLAG, ORIG_INITIAL_SOURCE, 
                    v_origin_ongoing_source, v_update_by, CURRENT_DATE, v_update_by, CURRENT_DATE, --ORIG_ONGOING_SOURCE, CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE, 
                    1, null, '&&1'   -- SEQ_NO, ADDR_UUID, SCHEME_CODE				
                );
        -- JL20250605 begin
        -- -- JL20250522 begin
        -- END IF;
        -- -- JL20250522 end
        -- JL20250605 end
------ v1 end				
    -- commit;
    END LOOP;
    COMMIT;

----- v1 start
	cas_dm_util_pkg.rebuild_index('&&1', 'CMN_CLIENT');
	cas_dm_util_pkg.rebuild_index('&&1', 'REG_EMPLOYER');
	cas_dm_util_pkg.rebuild_index('&&1', 'ENR_ER_ACCT');
	cas_dm_util_pkg.rebuild_index('&&1', 'CMN_SOURCE_OF_FUND');
	-- cas_dm_util_pkg.enable_constraint('&&1', 'CMN_CLIENT');
	-- cas_dm_util_pkg.enable_constraint('&&1', 'REG_EMPLOYER');
	-- cas_dm_util_pkg.enable_constraint('&&1', 'ENR_ER_ACCT');
	-- cas_dm_util_pkg.enable_constraint('&&1', 'CMN_SOURCE_OF_FUND');

	cas_dm_util_pkg.gather_table_stats('CMN_CLIENT');
	cas_dm_util_pkg.gather_table_stats('REG_EMPLOYER');
	cas_dm_util_pkg.gather_table_stats('ENR_ER_ACCT');
	cas_dm_util_pkg.gather_table_stats('CMN_SOURCE_OF_FUND');

    -- JL20241004 Begin
    UPDATE /*+ PARALLEL(32) */ temp_acct_no_pool
    SET SEQ_NO = -SEQ_NO
    WHERE -seq_no IN (SELECT /*+ PARALLEL(32) */ er_acct_no FROM enr_er_acct WHERE er_acct_no < 0);
    COMMIT;

    UPDATE /*+ PARALLEL(32) */ enr_er_acct er
    SET (er_acct_no, er_acct_no_display, ref_no) = (
        SELECT /*+ PARALLEL(32) */ acct_no, acct_no_display, 'ENP' || v_scheme_no || '0' || TO_CHAR(acct_no) || '0'
        FROM temp_acct_no_pool p 
        WHERE er.er_acct_no = p.seq_no
    )
    WHERE er_acct_no < 0;
    COMMIT;
    -- JL20241004 End

	cas_dm_util_pkg.gather_table_stats('ENR_ER_ACCT');

	update /*+ PARALLEL(32) */ enr_er_acct er set source_of_fund_uuid =  
		(   SELECT /*+ PARALLEL(32) */ sof.id
				FROM    CMN_SOURCE_OF_FUND sof
				WHERE   sof.CLIENT_UUID = er.id  and sof.av_client_type =  'EMPLOYER_ACCT' and er.migrate_flag = 'Y'
		) where scheme_code = '&&1' ;
    COMMIT;

	cas_dm_util_pkg.gather_table_stats('ENR_ER_ACCT');

----- v1 end

-------------------------------------------------------------------------
-- INSERT RECORDS IN ENR_ER_SUBACCT_TYPE FOR ('SEP', 'SVC', 'TVC')
-------------------------------------------------------------------------
-- 26/06/2024 Change Start
    BEGIN
        INSERT /*+ PARALLEL(32) */ INTO ENR_ER_SUBACCT_TYPE
        SELECT /*+ PARALLEL(32) */
            lpad(SCHEME_NO, 2, '0')|| SUBSTR(sys_guid(), 3)        AS ID,
            A.ID                            AS ER_ACCT_UUID,
            B.ID                            AS SUBACCT_TYPE_UUID,
            TO_DATE('20001201', 'YYYYMMDD') AS EFF_DATE,
            NULL                            AS TERM_DATE,
            v_scheme_cycle_date             AS CYCLE_CHANGE_DATE,
            'N'                             AS ARCHIVE_FLAG,
            A.ER_ACCT_NO                    AS ER_ACCT_CODE,
            A.SCHEME_CODE                   AS SCHEME_CODE,
            'AM'                            AS CREATED_BY,
            SYSDATE                         AS CREATION_DATE,
            'AM'                            AS LAST_UPDATED_BY,
            SYSDATE                         AS LAST_UPDATE_DATE
        FROM
                ENR_ER_ACCT A
            INNER JOIN ENR_SUBACCT_TYPE B ON ( A.AV_ER_ACCT_TYPE_CODE = SUBSTR(SUBACCT_TYPE_SHORT_NAME, 1, 3) )
            INNER JOIN CMN_SCHEME       C ON ( A.SCHEME_CODE = C.SCHEME_CODE )
        WHERE
                A.SCHEME_CODE = '&&1'
            AND A.AV_ER_ACCT_TYPE_CODE IN ( 'SEP', 'SVC', 'TVC' );
    END;
    v_upd_cnt :=  sql%Rowcount;
    dbms_output.put_line('Records inserted in ENR_ER_SUBACCT_TYPE : ' || v_upd_cnt);
    COMMIT;

	cas_dm_util_pkg.rebuild_index('&&1', 'ENR_ER_SUBACCT_TYPE');
	-- cas_dm_util_pkg.enable_constraint('&&1', 'ENR_ER_SUBACCT_TYPE');

	cas_dm_util_pkg.gather_table_stats('ENR_ER_SUBACCT_TYPE');

-------------------------------------------------------------------------------------
-- 26/06/2024 Change End
-------------------------------------------------------------------------------------

END;
/

/*

SELECT * FROM enr_er_acct where id like '%07d05860AD8%'

SELECT * 
FROM    enr_mem_acct ma
        INNER JOIN cmn_mem_acct_type at
        ON  at.id = ma.mem_acct_type_uuid
WHERE   ma.er_acct_uuid like '%07D05860AD80ED4AE%'
select s.registration_nmbr_1, s.* from dm_sep s where registration_nmbr_1 is not null

SELECT * FROM enr_mem_acct_emp_dtl

select count(*) from reg_member where scheme_code = '&&1'
select count(*) from enr_mem_acct where scheme_code = '&&1'
SELECT count(*) FROM enr_er_acct where scheme_code = '&&1'
SELECT count(*) FROM REG_EMPLOYER where scheme_code = '&&1'

select * from enr_mem_acct
select * from enr_er_subacct_type
select * from reg_member
select count(1) from reg_employer
SELECT * from enr_mem_acct_payroll_group 


DELETE temp_enr_mem;
DELETE ENR_MEM_ACCT_EMP_DTL WHERE SCHEME_CODE = '&&1';
DELETE ENR_MEM_ACCT_PAYROLL_GROUP WHERE SCHEME_CODE = '&&1';
UPDATE enr_er_acct 
SET SEP_MEM_ACCT_UUID = NULL
WHERE SCHEME_CODE = '&&1';
DELETE ENR_MEM_ACCT WHERE SCHEME_CODE = '&&1';
DELETE REG_MEMBER WHERE SCHEME_CODE = '&&1';
DELETE enr_payroll_group WHERE SCHEME_CODE = '&&1';
DELETE ENR_ER_SUBACCT_GRADE WHERE SCHEME_CODE = '&&1';
DELETE ENR_ER_ACCT_GRADE WHERE SCHEME_CODE = '&&1';
DELETE TRM_ER_ACCT_FORFEIT WHERE SCHEME_CODE = '&&1';
DELETE enr_er_acct WHERE SCHEME_CODE = '&&1';
DELETE REG_EMPLOYER WHERE SCHEME_CODE = '&&1';
DELETE cmn_client WHERE SCHEME_CODE = '&&1';

*/