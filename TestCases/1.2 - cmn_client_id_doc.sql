/*
01/02/2024	Winnie Lau		WL20240201 SEP OT without BR number handling
02/04/2024	Don Leung		DL20240402 upper the Registration_type for case select 
03/04/2024	Don Leung		DL20240403 add history table for BizRecon issue, to handle both HKId and passport for one UUID case
05/04/2024	Don Leung		DL20240405 reported by Savina (ifast) , some SO case registration_nmbr more than 7 char 
12/04/2024  Freeman Kam     Sync the changes since 2/4/2024
							- Use generate_guid()
							- Performance tunning by rewriting by converting 'cursor' to 'insert into'
07/06/2024  Don Leung       DL20240607 Fixed delete ---> truncate 
27/06/2024  Winnie Lau		WL20240627 insert correlated person passport# in hst table
03/07/2024  Winnie Lau		WL20240703 refine hst table logic
04/07/2024  Winnie Lau		fix hst table logic
08/11/2024  Justin Leung    JL20241108 Fix SEP ER joining
06/01/2025  Winnie Lau		WL20250106 exclude related person passport number = 'NOT PROVIDED'
16/05/2025  Carr Liang      CL20250516 add ER of dm_correlated_person table into ER table in CAS
04/06/2025  Justin Leung    JL20250604 Remove duplicated ORO insert
05/06/2025  Justin Leung    JL20250605 Fix director/bene_owner insert
03/07/2025  Justin Leung    JL20250703 Include correlated person company records
*/

SET SERVEROUT ON SIZE 1000000;
ALTER SESSION ENABLE PARALLEL DML;

truncate table CMN_CLIENT_ID_DOC ; -- DL20240607
truncate table CMN_CLIENT_ID_DOC_HST ; -- DL20240607
truncate table temp_client_id_doc_pre  ; -- DL20240607

DECLARE
V_UPDATE_BY         VARCHAR2(50) := 'DM INSERT VERSION';
V_SCHEME_CYCLE_DATE DATE;
V_SCHEME_UUID       RAW(16);

/*
DROP TABLE temp_client_id_doc_pre;
CREATE TABLE temp_client_id_doc_pre
(
ENTTY_TYPE              VARCHAR2(20), 
CLIENT_UUID             RAW(16), 
SYSTEM_CLIENT_TYPE      VARCHAR2(20), 
HKID_NMBR               VARCHAR2(80), 
HKID_CHECK_DIGIT        VARCHAR2(2), 
PASSPORT_NMBR           VARCHAR2(80), 
EFF_DATE                DATE,
AV_ID_TYPE_CODE         VARCHAR2(20),
ID_NO                   VARCHAR2(80),
ID_COUNTRY_CODE         VARCHAR2(20),
SCHEME_CODE             VARCHAR2(15),
);

CREATE INDEX temp_client_id_doc_pre_index1 ON temp_client_id_doc_pre (entty_type, client_uuid, system_client_type, av_id_type_code);
*/

BEGIN

    dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'CMN_CLIENT_ID_DOC'); 	
    dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'CMN_CLIENT_ID_DOC_HST'); 	

    COMMIT;

    cas_dm_util_pkg.disable_constraint('&&1', 'CMN_CLIENT_ID_DOC');
    cas_dm_util_pkg.disable_constraint('&&1', 'CMN_CLIENT_ID_DOC_HST');
    cas_dm_util_pkg.disable_index('&&1', 'CMN_CLIENT_ID_DOC');
    cas_dm_util_pkg.disable_index('&&1', 'CMN_CLIENT_ID_DOC_HST');

    INSERT INTO temp_client_id_doc_pre
    (
    ENTTY_TYPE, CLIENT_UUID, SYSTEM_CLIENT_TYPE, HKID_NMBR, HKID_CHECK_DIGIT, PASSPORT_NMBR, EFF_DATE, 
    AV_ID_TYPE_CODE, ID_NO, ID_COUNTRY_CODE, SCHEME_CODE --, INSERT_TYPE, DOC_ID_UUID
    )
    -- JL20241108 Begin
    WITH er_sep as (
        SELECT er.*, row_number() over(partition by tr_employer_code order by er_acct_no) as r
        FROM enr_er_acct er
        WHERE scheme_code = '&&1' and AV_ER_ACCT_TYPE_CODE = 'SEP'
    )
    -- JL20241108 End
    SELECT 
    src.ENTTY_TYPE, src.CLIENT_UUID, src.SYSTEM_CLIENT_TYPE, src.HKID_NMBR, src.HKID_CHECK_DIGIT, src.PASSPORT_NMBR, src.EFF_DATE, 
    src.AV_ID_TYPE_CODE, src.ID_NO, src.ID_COUNTRY_CODE, src.SCHEME_CODE --, src.INSERT_TYPE, src.DOC_ID_UUID 
    FROM (
    SELECT DISTINCT 'PERSON' AS ENTTY_TYPE, mem.id AS client_uuid, c.system_client_type, m.HKID_NMBR, m.hkid_check_digit, m.passport_nmbr,
        ma.eff_date
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HKID' 
                ELSE 'PASSPORT'
            END) AS av_id_type_code
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN m.hkid_nmbr
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN m.passport_nmbr
                ELSE NULL
            END) AS id_no
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HK'
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN NULL
                ELSE NULL
            END) AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_MEMBER m
            INNER JOIN enr_mem_acct ma
            ON  ma.orig_tr_mem_no = m.trustee_mbr_id
            AND ma.scheme_code = m.scheme_code
            INNER JOIN reg_member mem
            ON  mem.id = ma.member_uuid
            INNER JOIN CMN_CLIENT C
            on  C.ID = MEM.ID
    WHERE   m.SCHEME_CODE = '&&1'
    
    UNION ALL
    
    SELECT DISTINCT 'PERSON' AS ENTTY_TYPE, mem.id AS client_uuid, c.system_client_type, m.HKID_NMBR, m.hkid_check_digit, m.passport_nmbr,
        ma.eff_date
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HKID' 
                ELSE 'PASSPORT'
            END) AS av_id_type_code
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN m.hkid_nmbr
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN m.passport_nmbr
                ELSE NULL
            END) AS id_no
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HK'
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN NULL
                ELSE NULL
            END) AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_SEP m
            INNER JOIN enr_mem_acct ma
            ON  ma.orig_tr_mem_no = m.trustee_sep_cd
            AND ma.scheme_code = m.scheme_code
            INNER JOIN reg_member mem
            ON  mem.id = ma.member_uuid
            INNER JOIN CMN_CLIENT C
            ON  C.ID = MEM.ID
    WHERE   m.SCHEME_CODE = '&&1'
    --AND     m.trustee_emplr_cd = '00003966115-000001'
    --AND m.hkid_nmbr is null
    --AND m.passport_nmbr IS NOT NULL 
    --AND UPPER(m.passport_nmbr) <> 'NOT PROVIDED'
    --and m.passport_nmbr = 'M10883208'
    
    UNION ALL
    
    SELECT DISTINCT 'COMPANY' AS ENTTY_TYPE, r.id AS client_uuid, c.system_client_type
    --    ,(  CASE der.registration_type
    --            WHEN 'OT' THEN NULL -- der.REGISTRATION_TYPE_OT || der.branch_num 
    --            ELSE der.registration_nmbr || der.branch_num 
    --        END) 
    --WL20240201 Begin
    ,decode(UPPER(m.REGISTRATION_TYPE_1), 'OT'
        ,nvl(m.REGISTRATION_NMBR_1 || m.BRANCH_NUM_1, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        ,(m.REGISTRATION_NMBR_1 || m.BRANCH_NUM_1)
    ) AS HKID_NMBR
        --,m.REGISTRATION_NMBR_1 || m.BRANCH_NUM_1 AS HKID_NMBR
    --WL20240201 End	
        , NULL AS hkid_check_digit, NULL AS passport_nmbr
        ,r.eff_date, (   CASE UPPER(m.REGISTRATION_TYPE_1)   -- DL20240402
                        WHEN 'IR' THEN 'IRD'
                        WHEN 'ED' THEN 'EDU'
                        WHEN 'OT' THEN 'OTHERS'
                        ELSE    UPPER(m.REGISTRATION_TYPE_1)
                        END) AS AV_ID_TYPE_CODE
      
        , decode(UPPER(m.REGISTRATION_TYPE_1), 'OT'
        , nvl(m.REGISTRATION_NMBR_1 || m.BRANCH_NUM_1, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        , (m.REGISTRATION_NMBR_1 || m.BRANCH_NUM_1)
        ) AS id_no
        , NULL AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_SEP m
            -- JL20241108 Begin
            -- INNER JOIN enr_er_acct er
            -- ON  er.tr_employer_code = m.TRUSTEE_SEP_CD            
            -- AND er.scheme_code = m.scheme_code
            -- INNER JOIN reg_employer r
            -- ON  r.id = er.employer_uuiD
            INNER JOIN er_sep
            ON  er_sep.tr_employer_code = m.TRUSTEE_SEP_CD
            AND er_sep.r = 1
            AND er_sep.scheme_code = m.scheme_code
            INNER JOIN reg_employer r
            ON  r.id = er_sep.employer_uuiD
            -- JL20241108 End
            INNER JOIN cmn_client c
            ON  c.id = r.id
    WHERE   m.SCHEME_CODE = '&&1'
    --AND     m.trustee_sep_cd = '00003966115-000001'
    AND     m.REGISTRATION_TYPE_1 IS NOT NULL
    -- JL20241108 Begin
    -- AND     er.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    AND     er_sep.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    -- JL20241108 End
                            FROM    cmn_scheme_attr sa
                            WHERE   sa.scheme_code = '&&1'
                            AND     sa.scheme_attribute_name = 'DUMMY_ACCOUNT'
                            AND     sa.av_acct_type_code = 'SEP')
    
    UNION ALL
    
    SELECT DISTINCT 'COMPANY' AS ENTTY_TYPE, r.id AS client_uuid, c.system_client_type
    --WL20240201 Begin
    ,decode(UPPER(m.REGISTRATION_TYPE_2), 'OT'
        ,nvl(m.REGISTRATION_NMBR_2 || m.BRANCH_NUM_2, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        ,(m.REGISTRATION_NMBR_2 || m.BRANCH_NUM_2)
    ) AS HKID_NMBR
        --,m.REGISTRATION_NMBR_2 || m.BRANCH_NUM_2 AS HKID_NMBR
    --WL20240201 End    
        , NULL AS hkid_check_digit, NULL AS passport_nmbr
        ,r.eff_date, (   CASE UPPER(m.REGISTRATION_TYPE_2) --DL20240402
                        WHEN 'IR' THEN 'IRD'
                        WHEN 'ED' THEN 'EDU'
                        WHEN 'OT' THEN 'OTHERS'
                        ELSE    UPPER(m.REGISTRATION_TYPE_2)
                        END) AS AV_ID_TYPE_CODE
        , decode(UPPER(m.REGISTRATION_TYPE_2), 'OT'
        , nvl(m.REGISTRATION_NMBR_2 || m.BRANCH_NUM_2, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        , (m.REGISTRATION_NMBR_2 || m.BRANCH_NUM_2)
        ) AS id_no
        , NULL AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_SEP m
            -- JL20241108 Begin
            -- INNER JOIN enr_er_acct er
            -- ON  er.tr_employer_code = m.TRUSTEE_SEP_CD         
            -- AND er.scheme_code = m.scheme_code
            -- INNER JOIN reg_employer r
            -- ON  r.id = er.employer_uuiD
            INNER JOIN er_sep
            ON  er_sep.tr_employer_code = m.TRUSTEE_SEP_CD
            AND er_sep.r = 2
            AND er_sep.scheme_code = m.scheme_code
            INNER JOIN reg_employer r
            ON  r.id = er_sep.employer_uuiD
            -- JL20241108 End
            INNER JOIN cmn_client c
            ON  c.id = r.id
    WHERE   m.SCHEME_CODE = '&&1'
    --AND     m.trustee_sep_cd = '00003966115-000001'
    AND     m.REGISTRATION_TYPE_2 IS NOT NULL
    -- JL20241108 Begin
    -- AND     er.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    AND     er_sep.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    -- JL20241108 End
                            FROM    cmn_scheme_attr sa
                            WHERE   sa.scheme_code = '&&1'
                            AND     sa.scheme_attribute_name = 'DUMMY_ACCOUNT'
                            AND     sa.av_acct_type_code = 'SEP')
    
    UNION ALL
    
    SELECT DISTINCT 'COMPANY' AS ENTTY_TYPE, r.id AS client_uuid, c.system_client_type
    --WL20240201 Begin
    ,decode(UPPER(m.REGISTRATION_TYPE_3), 'OT'
        ,nvl(m.REGISTRATION_NMBR_3 || m.BRANCH_NUM_3, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        ,(m.REGISTRATION_NMBR_3 || m.BRANCH_NUM_3)
    ) AS HKID_NMBR
        --,m.REGISTRATION_NMBR_3 || m.BRANCH_NUM_3 AS HKID_NMBR
    --WL20240201 End        
        , NULL AS hkid_check_digit, NULL AS passport_nmbr
        ,r.eff_date, (   CASE UPPER(m.REGISTRATION_TYPE_3) -- DL20240402
                        WHEN 'IR' THEN 'IRD'
                        WHEN 'ED' THEN 'EDU'
                        WHEN 'OT' THEN 'OTHERS'
                        ELSE   UPPER(m.REGISTRATION_TYPE_3)
                        END) AS AV_ID_TYPE_CODE
        , decode(UPPER(m.REGISTRATION_TYPE_3), 'OT'
        , nvl(m.REGISTRATION_NMBR_3 || m.BRANCH_NUM_3, nvl(HKID_NMBR||hkid_check_digit, passport_nmbr))
        , (m.REGISTRATION_NMBR_3 || m.BRANCH_NUM_3)
        ) AS id_no
        , NULL AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_SEP m
            -- JL20241108 Begin
            -- INNER JOIN enr_er_acct er
            -- ON  er.tr_employer_code = m.TRUSTEE_SEP_CD           
            -- AND er.scheme_code = m.scheme_code
            -- INNER JOIN reg_employer r
            -- ON  r.id = er.employer_uuiD
            INNER JOIN er_sep
            ON  er_sep.tr_employer_code = m.TRUSTEE_SEP_CD
            AND er_sep.r = 3
            AND er_sep.scheme_code = m.scheme_code
            INNER JOIN reg_employer r
            ON  r.id = er_sep.employer_uuiD
            -- JL20241108 End
            INNER JOIN cmn_client c
            ON  c.id = r.id
    WHERE   m.SCHEME_CODE = '&&1'
    AND     m.REGISTRATION_TYPE_3 IS NOT NULL
    -- JL20241108 Begin
    -- AND     er.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    AND     er_sep.id NOT IN (  SELECT sa.SCHEME_ATTRIBUTE_VALUE
    -- JL20241108 End
                            FROM    cmn_scheme_attr sa
                            WHERE   sa.scheme_code = '&&1'
                            AND     sa.scheme_attribute_name = 'DUMMY_ACCOUNT'
                            AND     sa.av_acct_type_code = 'SEP')
    --AND     m.trustee_sep_cd = '00003966115-000001'
    
    UNION ALL
    
    SELECT DISTINCT 'COMPANY' AS ENTTY_TYPE, r.id AS client_uuid, c.system_client_type
    --    ,(  CASE der.registration_type
    --            WHEN 'OT' THEN NULL -- der.REGISTRATION_TYPE_OT || der.branch_num 
    --            ELSE der.registration_nmbr || der.branch_num 
    --        END) 
    --- DL20240405 start
    --    ,der.registration_nmbr || der.branch_num AS HKID_NMBR, NULL AS hkid_check_digit, NULL AS passport_nmbr
        , (CASE WHEN UPPER(der.registration_type) IN ('SO', 'TU', 'ED', 'OT', 'IR') THEN der.registration_nmbr 
            ELSE der.registration_nmbr || der.branch_num  
            END ) AS HKID_NMBR
        , NULL AS hkid_check_digit, NULL AS passport_nmbr
    --- DL20240405 end
        ,r.eff_date, (  CASE UPPER(der.registration_type) -- DL20240402
                        WHEN 'IR' THEN 'IRD'
                        WHEN 'ED' THEN 'EDU'
                        WHEN 'OT' THEN 'OTHERS'
                        ELSE    UPPER(der.registration_type)
                        END) AS AV_ID_TYPE_CODE
    --    , der.registration_nmbr || der.branch_num AS id_no
        , (CASE WHEN UPPER(der.registration_type) IN ('SO', 'TU', 'ED', 'OT', 'IR') THEN der.registration_nmbr 
            ELSE der.registration_nmbr || der.branch_num  
            END) AS ID_NO    
        , NULL AS id_country_code
        , der.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_EMPLOYER der
            INNER JOIN enr_er_acct er
            ON  er.tr_employer_code = der.trustee_emplr_cd
            AND er.scheme_code = der.scheme_code
            INNER JOIN reg_employer r
            ON  r.id = er.employer_uuiD
            INNER JOIN cmn_client c
            ON  c.id = r.id
    WHERE   er.scheme_code = '&&1'
    
    UNION ALL
    
    SELECT DISTINCT
    --m.hkid_nmbr, m.passport_nmbr,
		--WL20240627 change PERSON to CFERSON
		--WL20240703 use PERSON
        'PERSON' AS ENTTY_TYPE, ma.id AS client_uuid, c.system_client_type, m.HKID_NMBR, m.hkid_check_digit, m.passport_nmbr,
        ma.eff_date
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HKID' 
                ELSE 'PASSPORT'
            END) AS av_id_type_code
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN m.hkid_nmbr
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN m.passport_nmbr
                ELSE NULL
            END) AS id_no
        , ( CASE 
                WHEN m.hkid_nmbr IS NOT NULL THEN 'HK'
                WHEN UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%' THEN NULL
                ELSE NULL
            END) AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_CORRELATED_PERSON m
            INNER JOIN cmn_client_contact_person ma
            ON  ma.remark = m.RELATED_PERSON_ID
            AND ma.scheme_code = m.scheme_code
            INNER JOIN CMN_CLIENT C
            on  C.ID = ma.ID
            AND c.scheme_code = m.scheme_code
    WHERE   m.SCHEME_CODE = '&&1'
    AND (m.hkid_nmbr IS NOT NULL 
    OR
    UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE '%NOT%PROVIDED%')
    -- JL20250604 begin
    AND TYPE_COM_RELATED_PERSON <> 'ORO'
    -- JL20250604 end
    --and m.passport_nmbr = 'Z173729(6)'
	-- JL20250703 Begin
    -- JL20250605 Begin
	-- --CL20250516 Begin 
	UNION ALL
    
    SELECT DISTINCT
        'COMPANY' AS ENTTY_TYPE, ma.id AS client_uuid, c.system_client_type
        ,NULL AS HKID_NMBR
        ,NULL AS hkid_check_digit, NULL AS passport_nmbr
        ,ma.eff_date
		, (  CASE UPPER(m.registration_type) 
                        WHEN 'IR' THEN 'IRD'
                        WHEN 'ED' THEN 'EDU'
                        WHEN 'OT' THEN 'OTHERS'
                        ELSE    UPPER(m.registration_type)
            END) AS AV_ID_TYPE_CODE
        , (CASE WHEN UPPER(m.registration_type) IN ('SO', 'TU', 'ED', 'OT', 'IR') THEN m.registration_nmbr 
            ELSE m.registration_nmbr || m.branch_num  
            END) AS ID_NO    
        , NULL AS id_country_code
        , m.SCHEME_CODE AS SCHEME_CODE
    FROM    DM_CORRELATED_PERSON m
        INNER JOIN cmn_client_contact_person ma
        ON  ma.remark = m.RELATED_PERSON_ID
        AND ma.scheme_code = m.scheme_code
        INNER JOIN CMN_CLIENT c
        on  c.id = ma.id
        AND c.scheme_code = m.scheme_code
    WHERE   m.SCHEME_CODE = '&&1'
    AND (m.company_nm is not null OR m.company_chinese_nm IS NOT NULL)
    -- AND m.type_com_related_person IN ('DIRECTOR','BENE_OWNER')
	-- AND m.hkid_nmbr is null
	-- JL20250703 Begin
	AND m.type_com_related_person IN ('CLAIMANT','TIB','DIRECTOR','THIRD_PAYOR', 'PARTNER')
    -- JL20250703 End
    AND (m.hkid_nmbr IS NULL 
    AND
    UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) LIKE '%NOT%PROVIDED%')
	--CL20250516 End 
    -- JL20250605 End
	-- JL20250703 End
	) src
    ;

    dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'temp_client_id_doc_pre'); 	

--id id_cur %ROWTYPE;
    
    SELECT sc.cycle_date, s.id
    INTO    v_scheme_cycle_date, v_scheme_uuid
    FROM    cmn_scheme_cycle sc
            INNER JOIN cmn_scheme s
            ON  s.id = sc.tr_scheme_uuid
    WHERE   s.scheme_code = '&&1'
    AND     sc.cycle_date_step_code = '2';

--    v_check_exist := 'N';
    
    INSERT /*+ PARALLEL (8) */ INTO CMN_CLIENT_ID_DOC
    (ID, client_uuid, av_client_type, client_type_code, id_country_code
    ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
    ,cycle_change_date, archive_flag, scheme_code
    ,created_by, creation_date, last_updated_by, last_update_date)
    SELECT generate_guid('&&1'), id.client_uuid, id.system_client_type, NULL, id.id_country_code
    ,id.av_id_type_code, id.id_no, NULL, id.hkid_check_digit, id.eff_date
    ,v_scheme_cycle_date, 'N', '&&1'
    ,v_update_by, SYSDATE, v_update_by, sysdate
    FROM temp_client_id_doc_pre id
    WHERE id.scheme_code = '&&1'
    AND id.eff_date = (SELECT MAX(id2.eff_date)
                        FROM temp_client_id_doc_pre id2
                        WHERE id.entty_type = id2.entty_type
                        AND id.client_uuid = id2.client_uuid
                        AND id.system_client_type = id2.system_client_type
                        AND id.av_id_type_code = id2.av_id_type_code)

    ;
    COMMIT;


	
----------------- insert cmn_client_id_doc_hst step 1
    INSERT /*+ PARALLEL (8) */ INTO CMN_CLIENT_ID_DOC_HST
            (ID, client_uuid, av_client_type, client_type_code, id_country_code
            ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
            ,cycle_change_date, archive_flag, scheme_code
            ,created_by, creation_date, last_updated_by, last_update_date)
    SELECT 
    ID, client_uuid, av_client_type, client_type_code, id_country_code
    ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
    ,cycle_change_date, archive_flag, scheme_code
    ,created_by, creation_date, last_updated_by, last_update_date
    FROM CMN_CLIENT_ID_DOC
    WHERE scheme_code = '&&1';
            
    COMMIT;
	
	--WL-030724 remove begin
------------------- insert cmn_client_id_doc_hst step 2 -- dm_member
    -- INSERT /*+ PARALLEL (8) */ INTO CMN_CLIENT_ID_DOC_HST
            -- ( client_uuid, av_client_type, client_type_code, id_country_code
            -- ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
            -- ,cycle_change_date, archive_flag, scheme_code
            -- ,created_by, creation_date, last_updated_by, last_update_date)
    -- SELECT
    -- DISTINCT d.client_uuid, d.av_client_type, d.client_type_code, d.id_country_code
    -- ,'PASSPORT', m.passport_nmbr, d.biz_reg_expiry_date, null, d.eff_date
    -- ,d.cycle_change_date, d.archive_flag, d.scheme_code
    -- ,d.created_by, d.creation_date, d.last_updated_by, d.last_update_date
    -- FROM CMN_CLIENT_ID_DOC d
    -- INNER JOIN DM_MEMBER m 
        -- on d.av_id_type_code = 'HKID' and d.id_no = m.hkid_nmbr
            -- and  m.hkid_check_digit = d.id_check_digit 
            -- and m.scheme_code = '&&1'
--                    and m.passport_nmbr is not null and  upper(m.passport_nmbr)  <> 'NOT PROVIDED' and  upper(m.passport_nmbr)  <> 'NOT_PROVIDED'  and  upper(m.passport_nmbr)  <> 'NOTPROVIDED'
            -- and UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%'; 
    -- COMMIT;

    ------------------- insert cmn_client_id_doc_hst step 3 -- dm_sep
    -- INSERT /*+ PARALLEL (8) */ INTO CMN_CLIENT_ID_DOC_HST
            -- ( client_uuid, av_client_type, client_type_code, id_country_code
            -- ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
            -- ,cycle_change_date, archive_flag, scheme_code
            -- ,created_by, creation_date, last_updated_by, last_update_date)
    -- SELECT
            -- distinct d.client_uuid, d.av_client_type, d.client_type_code, d.id_country_code
            -- ,'PASSPORT', m.passport_nmbr, d.biz_reg_expiry_date, null, d.eff_date
            -- ,d.cycle_change_date, d.archive_flag, d.scheme_code
            -- ,d.created_by, d.creation_date, d.last_updated_by, d.last_update_date
            -- FROM CMN_CLIENT_ID_DOC  d
            -- INNER JOIN DM_SEP m 
                -- ON d.av_id_type_code = 'HKID' AND d.id_no = m.hkid_nmbr
                    -- AND  m.hkid_check_digit = d.id_check_digit 
                    -- AND m.scheme_code = '&&1'
--                    and m.passport_nmbr is not null and  upper(m.passport_nmbr)  <> 'NOT PROVIDED'  and  upper(m.passport_nmbr)  <> 'NOT_PROVIDED'  and  upper(m.passport_nmbr)  <> 'NOTPROVIDED'
                    -- AND UPPER(NVL(m.passport_nmbr, 'NOT PROVIDED')) NOT LIKE 'NOT%PROVIDED%'; 
    -- COMMIT;
   	--- DL20240403 end        
	--WL030724 remove end

	--WL20240627 begin	
    INSERT /*+ PARALLEL (8) */ INTO CMN_CLIENT_ID_DOC_HST
    (ID, client_uuid, av_client_type, client_type_code, id_country_code
    ,av_id_type_code, id_no, biz_reg_expiry_date, id_check_digit, eff_date
    ,cycle_change_date, archive_flag, scheme_code
    ,created_by, creation_date, last_updated_by, last_update_date)
    SELECT generate_guid('&&1'), id.client_uuid, id.system_client_type, NULL, id.id_country_code
    ,'PASSPORT', id.passport_nmbr, NULL, id.hkid_check_digit, id.eff_date
    ,v_scheme_cycle_date, 'N', '&&1'
    ,v_update_by, SYSDATE, v_update_by, v_scheme_cycle_date
    FROM temp_client_id_doc_pre id
    WHERE id.scheme_code = '&&1'
	and id.ENTTY_TYPE = 'PERSON'
	--WL20250106 begin
	--and id.passport_nmbr is not null
	and UPPER(NVL(id.passport_nmbr, 'NOT PROVIDED')) NOT LIKE '%NOT%PROVIDED%'
	--WL20250106 end
	and id.id_no is not null
	and av_id_type_code='HKID'
    ;
    COMMIT;
	--WL20240627 end

    cas_dm_util_pkg.rebuild_index('&&1', 'CMN_CLIENT_ID_DOC_HST');
    cas_dm_util_pkg.rebuild_index('&&1', 'CMN_CLIENT_ID_DOC');
    -- cas_dm_util_pkg.enable_constraint('&&1', 'CMN_CLIENT_ID_DOC_HST');
    -- cas_dm_util_pkg.enable_constraint('&&1', 'CMN_CLIENT_ID_DOC');

	cas_dm_util_pkg.gather_table_stats('CMN_CLIENT_ID_DOC_HST');
	cas_dm_util_pkg.gather_table_stats('CMN_CLIENT_ID_DOC');

END;
/

/*
select COUNT(1) from cmn_client_id_doc where scheme_code = '&&1'

select * from cmn_client_id_doc where scheme_code = '&&1'
AND client_uuid = '0A2F1A40869886D2E0630C15E10A5DE6'

select COUNT(1)  from cmn_client_id_doc where scheme_code = '&&1'
AND av_id_type_code IN ('HKID', 'PASSPORT');

select COUNT(1)  from cmn_client_id_doc where scheme_code = '&&1'
AND av_id_type_code NOT IN ('HKID', 'PASSPORT')

DELETE cmn_client_id_doc
truncate table cmn_client_id_doc

SELECT  COUNT(DISTINCT HKID_NMBR)
FROM    DM_MEMBER M
WHERE   SCHEME_CODE = '&&1'

select COUNT(1) from cmn_client_id_doc id
    INNER JOIN reg_member m
    ON  m.id = id.client_uuid
    INNER JOIN enr_mem_acct ma
    ON  ma.member_uuid = m.id
where m.scheme_code = '&&1' and av_id_type_code = 'PASSPORT' --'HKID'
AND     NOT EXISTS (SELECT  COUNT(DISTINCT HKID_NMBR)
                    FROM    DM_MEMBER M2
                    WHERE   m2.SCHEME_CODE = '&&1'
                    and     m2.trustee_mbr_id = ma.orig_tr_mem_no)

SELECT *
FROM    cmn_client_contact_person
WHERE   remark = '00000274357-000001'

SELECT ER.employer_uuid, der.*
FROM    DM_EMPLOYER der
        INNER JOIN enr_er_acct er
        ON  er.tr_employer_code = der.trustee_emplr_cd
        AND er.scheme_code = der.scheme_code
        INNER JOIN reg_employer r
        ON  r.id = er.employer_uuiD
        INNER JOIN cmn_client c
        ON  c.id = r.id
WHERE   er.scheme_code = '&&1'
AND     EXISTS (    SELECT *
                        FROM    cmn_client_id_doc id
                        WHERE   id.client_uuid = r.id
                        AND     id.ID_NO is null)


CREATE TABLE cmn_client_id_doc_fk AS select * from cmn_client_id_doc where 1 = 2;
CREATE TABLE cmn_client_id_doc_hst_fk AS select * from cmn_client_id_doc_hst where 1 = 2;


delete cmn_client_id_doc_fk where scheme_code = '&&1';
delete cmn_client_id_doc_hst_fk where scheme_code = '&&1';

select 
--*
count(*) 
from cmn_client_id_doc_fk where scheme_code = '&&1';
select count(*) from cmn_client_id_doc_hst_fk where scheme_code = '&&1';
commit;

select 
--*
count(*) 
from cmn_client_id_doc_orig where scheme_code = '&&1';
select count(*) from cmn_client_id_doc_hst_orig where scheme_code = '&&1';

CREATE INDEX CMN_CLIENT_ID_DOC_ORIG_UK1 ON (CLIENT_UUID, AV_ID_TYPE_CODE);

drop INDEX cmn_client_id_doc_orig_ind1;
CREATE INDEX cmn_client_id_doc_orig_ind1 ON cmn_client_id_doc_orig (client_uuid, av_id_type_code, scheme_code) -- local parallel 8;
alter INDEX cmn_client_id_doc_orig_ind1 NOPARALLEL;

drop INDEX cmn_client_id_doc_fk_ind1;
CREATE INDEX cmn_client_id_doc_fk_ind1 ON cmn_client_id_doc_fk (client_uuid, av_id_type_code, scheme_code) -- local parallel 8;
alter INDEX cmn_client_id_doc_fk_ind1 NOPARALLEL;

truncate table cmn_client_id_doc_fk;
truncate table cmn_client_id_doc_orig;
truncate table cmn_client_id_doc_hst_fk;
truncate table cmn_client_id_doc_hst_orig;



begin
	dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'cmn_client_id_doc_orig');
	dbms_stats.gather_table_stats(ownname=>USER, degree=>4, no_invalidate=>FALSE, tabname=>'cmn_client_id_doc_fk');
end;


select * from temp_client_id_doc_pre where scheme_code = '&&1'



SELECT --* 
CLIENT_UUID,
AV_CLIENT_TYPE,
CLIENT_TYPE_CODE,
ID_COUNTRY_CODE,
AV_ID_TYPE_CODE,
ID_NO,
BIZ_REG_EXPIRY_DATE,
ID_CHECK_DIGIT,
EFF_DATE,
CYCLE_CHANGE_DATE,
ARCHIVE_FLAG,
--CREATED_BY,
--CREATION_DATE,
--LAST_UPDATED_BY,
--LAST_UPDATE_DATE,
SCHEME_CODE,
DELETE_FLAG
--FROM cmn_client_id_doc_fk
FROM cmn_client_id_doc_orig
MINUS
SELECT --* 
CLIENT_UUID,
AV_CLIENT_TYPE,
CLIENT_TYPE_CODE,
ID_COUNTRY_CODE,
AV_ID_TYPE_CODE,
ID_NO,
BIZ_REG_EXPIRY_DATE,
ID_CHECK_DIGIT,
EFF_DATE,
CYCLE_CHANGE_DATE,
ARCHIVE_FLAG,
--CREATED_BY,
--CREATION_DATE,
--LAST_UPDATED_BY,
--LAST_UPDATE_DATE,
SCHEME_CODE,
DELETE_FLAG
--FROM cmn_client_id_doc_orig
FROM cmn_client_id_doc_fk


SELECT --* 
CLIENT_UUID,
AV_CLIENT_TYPE,
CLIENT_TYPE_CODE,
ID_COUNTRY_CODE,
AV_ID_TYPE_CODE,
ID_NO,
BIZ_REG_EXPIRY_DATE,
ID_CHECK_DIGIT,
EFF_DATE,
CYCLE_CHANGE_DATE,
ARCHIVE_FLAG,
--CREATED_BY,
--CREATION_DATE,
--LAST_UPDATED_BY,
--LAST_UPDATE_DATE,
SCHEME_CODE
--FROM cmn_client_id_doc_hst_fk
FROM cmn_client_id_doc_hst_orig
MINUS
SELECT --* 
CLIENT_UUID,
AV_CLIENT_TYPE,
CLIENT_TYPE_CODE,
ID_COUNTRY_CODE,
AV_ID_TYPE_CODE,
ID_NO,
BIZ_REG_EXPIRY_DATE,
ID_CHECK_DIGIT,
EFF_DATE,
CYCLE_CHANGE_DATE,
ARCHIVE_FLAG,
--CREATED_BY,
--CREATION_DATE,
--LAST_UPDATED_BY,
--LAST_UPDATE_DATE,
SCHEME_CODE
--FROM cmn_client_id_doc_hst_orig
FROM cmn_client_id_doc_hst_fk

set serverout on;
exec sys.list_session;

*/