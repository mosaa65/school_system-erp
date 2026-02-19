-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           نظام الدرجات والتقويم الذكي (SGAS) - v4.0                        ║
-- ║           Master Update Script (RUN_UPDATE_v4.sql)                         ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- ⚠️ هام: يجب تشغيل هذا الملف من الدليل الجذري للمشروع:
-- cd C:\Users\mousa\Desktop\system\school_system-erp
-- mysql -u root -p < systems/05_التعليم_والدرجات/RUN_UPDATE_v4.sql

SELECT '🚀 Executing System 08 Updates...' AS status;
SOURCE systems/08_لجان_الامتحانات/DDL_SCHEDULING.sql;
SOURCE systems/08_لجان_الامتحانات/DDL.sql;

SELECT '🚀 Executing System 05 Updates...' AS status;
SOURCE systems/05_التعليم_والدرجات/DDL_POLICIES.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_EXAMS.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_HOMEWORKS.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_MONTHLY.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_RESULTS.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_LESSON_PREP.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_AUDIT.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_REPORTS.sql;
SOURCE systems/05_التعليم_والدرجات/DDL_TOOLS.sql;

SELECT '🛠️ Patching Dependent Systems (15, 16)...' AS status;
SOURCE systems/15_لوحة_المعلومات/DDL.sql;
SOURCE systems/16_التقارير_والكشوفات/DDL.sql;

SELECT '🌱 Seeding Demo Data (Optional)...' AS status;
SOURCE systems/05_التعليم_والدرجات/DEMO_DATA.sql;

SELECT '✅ UPDATE v4.0 COMPLETED SUCCESSFULLY' AS status;
