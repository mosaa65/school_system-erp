# 📝 تحضير الدروس
## DDL_LESSON_PREP v3.1 — Lesson Preparation

---

## 📌 بطاقة الملف
| البند | القيمة |
|-------|--------|
| **الملف** | `DDL_LESSON_PREP.sql` |
| **ترتيب التنفيذ** | 6️⃣ السادس |
| **الإصدار** | v3.1 |
| **عدد الجداول** | 1 جدول |
| **يعتمد على** | System 01 (users), System 02 (النواة) |

---

## 📊 تفاصيل الجدول

### lesson_preparation — تحضير الدروس

| الحقل | الاسم البرمجي | النوع | الوصف |
|-------|---------------|-------|-------|
| المعرف | `id` | INT (PK) | معرف فريد |
| المنشئ | `created_by` | INT (FK → users) | **المستخدم** الذي حضّر الدرس |
| المادة | `subject_id` | INT (FK) | المادة الدراسية |
| الفصل | `classroom_id` | INT (FK) | الفصل/الشعبة |
| التاريخ | `prep_date` | DATE | تاريخ التحضير |
| العنوان | `lesson_title` | VARCHAR(255) | عنوان الدرس |
| الأهداف | `objectives` | TEXT | الأهداف السلوكية |
| الاستراتيجيات | `strategies` | TEXT | استراتيجيات التدريس |
| الوسائل | `aids` | TEXT | الوسائل التعليمية |
| معتمد؟ | `is_approved` | BOOLEAN | هل تمت الموافقة من المشرف؟ |
| تاريخ الإنشاء | `created_at` | TIMESTAMP | وقت إنشاء سجل التحضير |

---

## 🧩 عناصر تقنية إضافية موثقة
- توجد فهارس تشغيلية لتحسين الاستعلام:
  - `idx_prep_creator` على `created_by`
  - `idx_prep_classroom` على `classroom_id`
  - `idx_prep_date` على `prep_date`

## 💡 أمثلة SQL

### إضافة تحضير درس
```sql
INSERT INTO lesson_preparation (created_by, subject_id, classroom_id, prep_date, lesson_title, objectives)
VALUES (1, 1, 1, '2026-09-14', 'المعادلات الخطية', 'أن يتمكن الطالب من حل المعادلات الخطية');
```

### جلب تحضيرات مستخدم معين
```sql
SELECT lp.*, u.full_name AS creator_name
FROM lesson_preparation lp
JOIN users u ON lp.created_by = u.id
WHERE lp.created_by = 1
ORDER BY lp.prep_date DESC;
```

### تحضيرات فصل معين مع اسم المنشئ
```sql
SELECT lp.prep_date, lp.lesson_title, lp.is_approved, u.full_name
FROM lesson_preparation lp
JOIN users u ON lp.created_by = u.id
WHERE lp.classroom_id = 1
ORDER BY lp.prep_date;
```

---

**تم التحديث:** 2026-02-14
