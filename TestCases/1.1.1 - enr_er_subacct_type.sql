SET SERVEROUT ON SIZE 1000000;
/*
22/02/2024	Paul Pang		Update cntrb_type mapping
12/06/2024	George Ngai		change sys_guid to generate_guid
13/08/2024  Dipanshu Singh  Update ALLOW_VC_FLAG column in ENR_PAYROLL_GROUP as per BAC Request
04/09/2024	George Ngai		change generate_guid to SUBSTR sys_guid()
01/09/2025	George Ngai		Change parallel 16 to parallel 32
*/

ALTER SESSION ENABLE PARALLEL DML;

DECLARE
v_update_by             VARCHAR2(50) := 'DM'; 
v_scheme_no				VARCHAR2(2);
v_scheme_cycle_date     DATE;
V_SCHEME_UUID           RAW(16);
v_upd_cnt       	    INTEGER := 0;

--CURSOR ersa_cur IS
--SELECT * 
--FROM (
--SELECT  DISTINCT ea.id, im.cntrb_type
----, mat.short_code
--        ,(  SELECT  st.id
--            FROM    enr_subacct_type st
--            WHERE   st.subacct_type_short_name = ( CASE im.cntrb_type
--                                                    WHEN 'FMRMC' THEN 'FRMC'
--                                                    WHEN 'FMRVC' THEN 'FRVC'
--                                                    --
--                                                    WHEN 'FFT' THEN 'FORFEITURE'
--                                                    WHEN 'OEVPT' THEN 'POSTMPFEE'
--                                                    WHEN 'ORVPT' THEN 'POSTMPFER'
--                                                    --
--                                                    ELSE im.cntrb_type
--                                                    END)
--                                                    ) AS subacct_type_uuid
--        ,ea.eff_date
--        ,ea.term_date
--        ,ea.er_acct_no
--FROM    enr_er_acct ea
--        INNER JOIN enr_mem_acct ma
--        ON  ma.er_acct_uuid = ea.id
--        INNER JOIN DM_INVESTMENT_MANDATE im
--        ON  im.trustee_entty_cd = ma.orig_tr_mem_no  
--        AND im.scheme_code = ea.scheme_code
--        INNER JOIN cmn_mem_acct_type mat
--        ON  mat.id = ma.mem_acct_type_uuid
--WHERE   mat.short_code NOT IN ('PAH', 'SVC', 'TVC', 'SEP')
--AND     ea.scheme_code = '&&1'
--
--UNION
--
--SELECT  DISTINCT ea.id, im.cntrb_type
----, mat.short_code
--        ,(  SELECT  st.id
--            FROM    enr_subacct_type st
--            WHERE   st.subacct_type_short_name = ( CASE UPPER(im.cntrb_type)
--                                                    WHEN 'FMRMC' THEN 'FRMC'
--                                                    WHEN 'FMRVC' THEN 'FRVC'
--                                                    --
--                                                    WHEN 'FFT' THEN 'FORFEITURE'
--													WHEN 'RSA' THEN 'RESERVE'
--                                                    WHEN 'OEVPT' THEN 'POSTMPFEE'
--                                                    WHEN 'ORVPT' THEN 'POSTMPFER'
--                                                    --
--                                                    ELSE UPPER(im.cntrb_type)
--                                                    END)
--                                                    ) AS subacct_type_uuid
--        ,ea.eff_date
--        ,ea.term_date
--        ,ea.er_acct_no
--FROM    enr_er_acct ea
--        INNER JOIN enr_mem_acct ma
--        ON  ma.er_acct_uuid = ea.id
--        INNER JOIN DM_ACCOUNT_BALANCE im
--        ON  im.trustee_entty_cd = ma.orig_tr_mem_no  
--        AND im.scheme_code = ea.scheme_code
--        INNER JOIN cmn_mem_acct_type mat
--        ON  mat.id = ma.mem_acct_type_uuid
--WHERE   mat.short_code NOT IN ('PAH', 'SVC', 'TVC', 'SEP')
--AND     ea.scheme_code = '&&1'
--);

--ersa ersa_cur%ROWTYPE;


BEGIN
    dbms_output.put_line('START scheme_code ' || '&&1');

	SELECT LPAD(SCHEME_NO, 2,'0') into v_scheme_no FROM CMN_SCHEME WHERE SCHEME_CODE = '&&1';
    --SELECT * FROM cmn_scheme
--    
--    SELECT  cycle_date
--    INTO    v_master_cycle_date
--    FROM    cmn_master_cycle
--    WHERE   cycle_date_step_code = 1;
    
    SELECT  sc.cycle_date, s.id
    INTO    v_scheme_cycle_date, v_scheme_uuid
    FROM    cmn_scheme_cycle sc
            INNER JOIN cmn_scheme s
            ON  s.id = sc.tr_scheme_uuid
    WHERE   s.scheme_code = '&&1'
    AND     sc.cycle_date_step_code = '2';    
    
    
--    FOR ersa IN ersa_cur LOOP  
--        INSERT INTO enr_er_subacct_type
--        (ID, ER_ACCT_UUID, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
--        ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
--        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
--        VALUES
--        (v_scheme_no||SUBSTR(sys_guid(),3), ersa.id, ersa.subacct_type_uuid, ersa.eff_date, NULL
--        ,v_scheme_cycle_date, 'N', ersa.er_acct_no, '&&1'
--                ,v_update_by, SYSDATE, v_update_by, SYSDATE);    
--                
--                
--    END LOOP;    
--        
        
        cas_dm_util_pkg.disable_constraint('&&1', 'ENR_ER_SUBACCT_TYPE');
        cas_dm_util_pkg.disable_index('&&1', 'ENR_ER_SUBACCT_TYPE');
        INSERT /*+ PARALLEL(32) */ INTO enr_er_subacct_type
        (ID, ER_ACCT_UUID, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
        ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        SELECT /*+ PARALLEL(32) */ v_scheme_no||SUBSTR(sys_guid(),3), er_acct_uuid, SUBACCT_TYPE_UUID, eff_date, term_date
            ,v_scheme_cycle_date, 'N', er_acct_no, '&&1'
            ,v_update_by, SYSDATE, v_update_by, SYSDATE
        FROM    (
            SELECT /*+ PARALLEL(32) */ DISTINCT ea.id AS er_acct_uuid, st.id AS SUBACCT_TYPE_UUID, ea.eff_date, ea.term_date, ea.er_acct_no
            FROM    enr_er_acct ea
                    INNER JOIN enr_mem_acct ma
                    ON  ma.er_acct_uuid = ea.id
                    INNER JOIN DM_INVESTMENT_MANDATE im
                    ON  im.trustee_entty_cd = ma.orig_tr_mem_no  
                    AND im.scheme_code = ea.scheme_code
                    INNER JOIN cmn_mem_acct_type mat
                    ON  mat.id = ma.mem_acct_type_uuid
                    LEFT JOIN enr_subacct_type st
                    ON  st.subacct_type_short_name = ( CASE im.cntrb_type
                                                                WHEN 'FMRMC' THEN 'FRMC'
                                                                WHEN 'FMRVC' THEN 'FRVC'
                                                                --
                                                                WHEN 'FFT' THEN 'FORFEITURE'
                                                                WHEN 'OEVPT' THEN 'POSTMPFEE'
                                                                WHEN 'OEVPT2' THEN 'POSTMPFEE2'																
                                                                WHEN 'ORVPT' THEN 'POSTMPFER'
                                                                WHEN 'ORVPT2' THEN 'POSTMPFER2'																
                                                                WHEN 'OEVPE' THEN 'PREMPFEE'
                                                                WHEN 'OEVPE2' THEN 'PREMPFEE2'																
																WHEN 'ORVPE' THEN 'PREMPFER'																
                                                                WHEN 'ORVPE2' THEN 'PREMPFER2'
																WHEN 'RSA' THEN 'RESERVE'
                                                                --
                                                                ELSE im.cntrb_type
                                                                END)
            WHERE   mat.short_code NOT IN ('PAH', 'SVC', 'TVC', 'SEP')
            AND     ea.scheme_code = '&&1'
        );
		COMMIT;

        cas_dm_util_pkg.rebuild_index('&&1', 'ENR_ER_SUBACCT_TYPE');
--        cas_dm_util_pkg.disable_constraint('&&1', 'ENR_ER_SUBACCT_TYPE');

        cas_dm_util_pkg.gather_table_stats('ENR_ER_SUBACCT_TYPE');

        INSERT /*+ PARALLEL(32) */ INTO enr_er_subacct_type
        (ID, ER_ACCT_UUID, SUBACCT_TYPE_UUID, EFF_DATE, TERM_DATE
        ,CYCLE_CHANGE_DATE, ARCHIVE_FLAG, ER_ACCT_CODE, SCHEME_CODE
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE)
        SELECT /*+ PARALLEL(32) */ v_scheme_no||SUBSTR(sys_guid(),3), er_acct_uuid, SUBACCT_TYPE_UUID, eff_date, term_date
            ,v_scheme_cycle_date, 'N', er_acct_no, '&&1'
            ,v_update_by, SYSDATE, v_update_by, SYSDATE
        FROM    (
            SELECT /*+ PARALLEL(32) */ DISTINCT ea.id AS er_acct_uuid, st.id AS SUBACCT_TYPE_UUID, ea.eff_date, ea.term_date, ea.er_acct_no
            FROM    enr_er_acct ea
                    INNER JOIN enr_mem_acct ma
                    ON  ma.er_acct_uuid = ea.id
                    INNER JOIN DM_ACCOUNT_BALANCE im
                    ON  im.trustee_entty_cd = ma.orig_tr_mem_no  
                    AND im.scheme_code = ea.scheme_code
                    INNER JOIN cmn_mem_acct_type mat
                    ON  mat.id = ma.mem_acct_type_uuid
                    LEFT JOIN enr_subacct_type st
                    ON  st.subacct_type_short_name = ( CASE im.cntrb_type
                                                                WHEN 'FMRMC' THEN 'FRMC'
                                                                WHEN 'FMRVC' THEN 'FRVC'
                                                                --
                                                                WHEN 'FFT' THEN 'FORFEITURE'
                                                                WHEN 'OEVPT' THEN 'POSTMPFEE'
                                                                WHEN 'OEVPT2' THEN 'POSTMPFEE2'																
                                                                WHEN 'ORVPT' THEN 'POSTMPFER'
                                                                WHEN 'ORVPT2' THEN 'POSTMPFER2'																
                                                                WHEN 'OEVPE' THEN 'PREMPFEE'
                                                                WHEN 'OEVPE2' THEN 'PREMPFEE2'																
																WHEN 'ORVPE' THEN 'PREMPFER'																
                                                                WHEN 'ORVPE2' THEN 'PREMPFER2'
																WHEN 'RSA' THEN 'RESERVE'
                                                                --
                                                                ELSE im.cntrb_type
                                                                END)
            WHERE   mat.short_code NOT IN ('PAH', 'SVC', 'TVC', 'SEP')
            AND     NOT EXISTS (    SELECT /*+ PARALLEL(32) */ *
                                    FROM    enr_er_subacct_type est
                                    WHERE   est.ER_ACCT_UUID = ea.id
                                    AND     est.SUBACCT_TYPE_UUID = st.id
                                    AND     est.EFF_DATE = ea.eff_date
                                    AND     est.SCHEME_CODE = '&&1')
            AND     ea.scheme_code = '&&1'
        );
		COMMIT;

        cas_dm_util_pkg.gather_table_stats('ENR_ER_SUBACCT_TYPE');

-------------------------------------------------------------------------------------
-- 13/08/2024 Change Start
-------------------------------------------------------------------------------------
-- Update ALLOW_VC_FLAG column with default value as 'N'
-------------------------------------------------------------------------------------
    BEGIN
        UPDATE /*+ PARALLEL(32) */ ENR_PAYROLL_GROUP X
        SET X.ALLOW_VC_FLAG = 'N'
        WHERE
            X.SCHEME_CODE = '&&1';
    END;
    v_upd_cnt :=  sql%Rowcount;
    dbms_output.put_line('ALLOW_VC_FLAG(ENR_PAYROLL_GROUP) column updated with N - record count : ' || v_upd_cnt);
    COMMIT;
    

-------------------------------------------------------------------------------------
-- Update ALLOW_VC_FLAG column with 'Y' for SUBACCT_GROUP_NAME(ENR_SUBACCT_TYPE) = 'VC'
-------------------------------------------------------------------------------------
    BEGIN
        MERGE /*+ PARALLEL(32) */ INTO ENR_PAYROLL_GROUP X
        USING
        (
            SELECT /*+ PARALLEL(32) */
                DISTINCT A.ID AS ER_ACCT_UUID, A.SCHEME_CODE
            FROM
                ENR_ER_ACCT A
            INNER JOIN
                ENR_ER_SUBACCT_TYPE B ON (A.ID = B.ER_ACCT_UUID AND A.SCHEME_CODE = B.SCHEME_CODE)
            INNER JOIN
                ENR_SUBACCT_TYPE C ON (B.SUBACCT_TYPE_UUID = C.ID AND C.SUBACCT_GROUP_NAME = 'VC')
            WHERE
                A.SCHEME_CODE = '&&1'
        ) Y
        ON ( X.ER_ACCT_UUID = Y.ER_ACCT_UUID AND X.SCHEME_CODE = Y.SCHEME_CODE)
        WHEN MATCHED THEN
        UPDATE SET
            X.ALLOW_VC_FLAG = 'Y';
    END;
    v_upd_cnt :=  sql%Rowcount;
    dbms_output.put_line('ALLOW_VC_FLAG(ENR_PAYROLL_GROUP) column updated with Y - record count : ' || v_upd_cnt);
    COMMIT;
-------------------------------------------------------------------------------------
-- 13/08/2024 Change End
-------------------------------------------------------------------------------------
END;
/

/*
SELECT COUNT(1) FROM enr_er_subacct_type
*/