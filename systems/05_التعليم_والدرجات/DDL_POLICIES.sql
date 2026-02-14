-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║           نظام الدرجات والتقويم الذكي (SGAS) - v3.3                        ║
-- ║           ملف 1: سياسات الدرجات والأوزان (Grading Policies)                ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- التاريخ: 2026-02-14
-- الإصدار: 3.3 (Customizable scoring model)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. جدول حالات اعتماد الدرجات
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lookup_grading_statuses (
    id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name_ar VARCHAR(50) NOT NULL,
    is_final BOOLEAN DEFAULT FALSE COMMENT 'هل الحالة نهائية؟',
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE KEY uk_lgs_name (name_ar)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='حالات اعتماد الدرجات (مسودة/مراجعة/معتمد/أرشيف)';

INSERT INTO lookup_grading_statuses (name_ar, is_final, is_active) VALUES
('مسودة', 0, 1),
('قيد المراجعة', 0, 1),
('معتمد', 1, 1),
('مرحل للأرشيف', 1, 1)
ON DUPLICATE KEY UPDATE
    is_final = VALUES(is_final),
    is_active = VALUES(is_active);

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. سياسات الدرجات والأوزان (لكل عام/صف/مادة/نوع تقييم)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS grading_policies (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    academic_year_id INT UNSIGNED NOT NULL,
    grade_level_id INT UNSIGNED NOT NULL,
    subject_id INT UNSIGNED NOT NULL,
    exam_period_type ENUM('MONTHLY', 'MIDTERM', 'FINAL', 'DIAGNOSTIC', 'CUSTOM') NOT NULL DEFAULT 'MONTHLY'
        COMMENT 'نوع التقييم المرتبط بهذه السياسة',

    -- الأوزان الافتراضية
    max_exam_score DECIMAL(5,2) DEFAULT 20.00 COMMENT 'الدرجة العظمى للاختبارات',
    max_homework_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الدرجة العظمى للواجبات',
    max_attendance_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الدرجة العظمى للمواظبة',
    max_activity_score DECIMAL(5,2) DEFAULT 5.00 COMMENT 'الدرجة العظمى للنشاط',
    max_contribution_score DECIMAL(5,2) DEFAULT 0.00 COMMENT 'الدرجة العظمى للمساهمة/المهارات السلوكية',

    -- حدود النجاح
    passing_score DECIMAL(5,2) DEFAULT 50.00 COMMENT 'درجة النجاح المئوية',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    created_by_user_id INT UNSIGNED NULL,

    CHECK (max_exam_score >= 0),
    CHECK (max_homework_score >= 0),
    CHECK (max_attendance_score >= 0),
    CHECK (max_activity_score >= 0),
    CHECK (max_contribution_score >= 0),
    CHECK (passing_score BETWEEN 0 AND 100),

    UNIQUE KEY uk_policy (academic_year_id, grade_level_id, subject_id, exam_period_type),
    INDEX idx_gp_type (exam_period_type),

    FOREIGN KEY (academic_year_id) REFERENCES academic_years(id),
    FOREIGN KEY (grade_level_id) REFERENCES grade_levels(id),
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (created_by_user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='سياسات الدرجات المرنة لكل مادة/صف/عام/نوع تقييم';

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. المكونات المخصصة للسياسة (اختياري لكل مدرسة)
-- ═══════════════════════════════════════════════════════════════════════════════
-- الهدف: السماح لكل مدرسة بإضافة مكونات إضافية مثل:
--   سلوك، مشروع فصلي، مهارات عملية، قراءة، إلخ
-- هذه المكونات تُجمع في monthly_custom_component_scores

CREATE TABLE IF NOT EXISTS grading_policy_custom_components (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    policy_id INT UNSIGNED NOT NULL COMMENT 'FK → grading_policies',
    component_code VARCHAR(50) NOT NULL COMMENT 'رمز داخلي ثابت مثل: BEHAVIOR, PROJECT',
    component_name_ar VARCHAR(100) NOT NULL COMMENT 'اسم المكون المعروض',
    max_score DECIMAL(5,2) NOT NULL DEFAULT 0.00 COMMENT 'الدرجة العظمى لهذا المكون',
    calculation_mode ENUM('MANUAL', 'AUTO_ATTENDANCE', 'AUTO_HOMEWORK', 'AUTO_EXAM') NOT NULL DEFAULT 'MANUAL'
        COMMENT 'طريقة احتساب المكون',
    include_in_monthly BOOLEAN DEFAULT TRUE COMMENT 'يدخل في المحصلة الشهرية',
    include_in_semester BOOLEAN DEFAULT TRUE COMMENT 'يدخل في نتيجة الفصل',
    sort_order TINYINT UNSIGNED DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,

    CHECK (max_score >= 0),
    UNIQUE KEY uk_gpcc (policy_id, component_code),
    INDEX idx_gpcc_active (is_active),
    INDEX idx_gpcc_order (sort_order),

    FOREIGN KEY (policy_id) REFERENCES grading_policies(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='تعريف مكونات تقييم مخصصة لكل سياسة درجات';

-- ═══════════════════════════════════════════════════════════════════════════════
SELECT '✅ DDL_POLICIES v3.3: تم إنشاء جداول السياسات المرنة بنجاح' AS message;
