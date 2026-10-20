# خطة إصلاح وتحسين شاشات عروض الأسعار (قائمة / إضافة / تفاصيل)

## السياق (من الكود الفعلي)
- `lib/screens/quotations_screen.dart` (1417 سطر) — قائمة العروض
- `lib/screens/quotation_form_screen.dart` (1658 سطر) — شاشة الإضافة/التعديل
- `lib/screens/quotation_details_screen.dart` (2382 سطر) — شاشة التفاصيل
- الهوية: `AppColors` (كحلي `#13273F` + ذهبي `#DBBF74`)، ثيم ليلي/نهاري، خط Cairo، دعم RTL.
- نظام ألوان الحالات مُضاف بالفعل في `lib/services/app_colors.dart`: `success #10B981`، `error #EF4444`، `warning #F59E0B`، `info #3B82F6`، `neutral #64748B` + نسخة `Light` لكل منها.

## نطاق العمل
**داخل النطاق:** إصلاح الشاشة الحمراء، تصغير هيدر القائمة + نقل الكروت الإحصائية، احترافية الأيقونات، توحيد الألوان.
**خارج النطاق (بقرار صريح من المستخدم):** ملف طباعة عرض السعر (PDF) — لا تعديل ولا لمس. وطباعة `crm_pdf_generator.dart` ليست متضمنة.

---

## القرارات المتخذة
| # | القرار | التبرير |
|---|--------|---------|
| 1 | الهيدر: تصغير + إزالة تكرار العنوان + إزالة المسافة + نقل الكروت الإحصائية لصف KPI مستقل | يحقق "الأفضل والأحسن" مع "تناسق" مع بقية التطبيق (نفس نمط صف بطاقات الإحصائيات في `price_list_screen.dart`) |
| 2 | الحفاظ على التدرّج الكحلي/الذهبي في الهيدر | المستخدم وصف التصميم العام بأنه "ممتتاز" — المشكلة في الحجم والمسافة فقط |
| 3 | الأيقونات: استبدال المجموعة الحالية بمجموعة دلالية موحّدة | `thumb_up/thumb_down` تعني "إعجاب/عدم إعجاب" (سوشيال ميديا) ولا تعني "مقبول/مرفوض" |
| 4 | توحيد كل الألوان على `AppColors` + ألوان الحالات | الألوان الثابتة الحالية (`Colors.green/red/blue/orange/pink`) لا تستجيب لتغيير لون التمييز |
| 5 | إصلاح الشاشات الحمراء بإصلاح جذري في ترتيب الإنهاء (dispose) وليس تهيئة جديدة | الخلل من `dispose()` قبل إزالة الـ widgets من الشجرة |

---

## العيوب المؤكدة في الكود

### أ) الشاشة الحمراء عند اختيار العميل (`quotation_form_screen.dart`)
| # | الموقع | الخلل | الأثر |
|---|--------|-------|-------|
| A1 | السطران 337-338 | `controller.dispose()` مباشرة بعد `await showModalBottomSheet(...)` — الـ bottom sheet ما زال في شجرة الـ widgets أثناء أنيميشن الإغلاق | `TextEditingController was used after being disposed` → ErrorWidget أحمر |
| A2 | السطران 340-342 | `item.dispose()` على عناصر `_QuotationItem` **قبل** `setState` الذي يزيلها من الشجرة | نفس الخطأ عند تغيير العميل بعد إضافة أصناف |
| A3 | السطران 1310-1332 | `DropdownButtonFormField` بـ `initialValue: _opportunityId` + مفتاح `ValueKey` | assert في Flutter (`dropdown.dart:1851-1863`): يجب أن يطابق `initialValue` عنصراً واحداً بالضبط — في وضع التعديل، إذا لم يكن `OpportunityID` المحفوظ ضمن الفرص المُحمّلة → **شاشة حمراء** |
| A4 | السطران 194-201 | `_loadPartyData()` يُسند `_opportunities` **بدون** `setState` | القائمة المنسدلة للفرص لا تُملأ أبداً |

### ب) هيدر قائمة العروض (`quotations_screen.dart`)
| # | الموقع | الخلل |
|---|--------|-------|
| B1 | السطر 221 | `expandedHeight: 270` — الهيدر يشغل ~ثلث الشاشة |
| B2 | السطر 312 | `padding: EdgeInsets.fromLTRB(16, 66, 16, 13)` — الـ 66px هي مصدر "المسافة بين العنوان" |
| B3 | السطران 225 + 348 | العنوان "عروض الأسعار" **مكرر**: في `SliverAppBar.title` وداخل `_hero()` |
| B4 | السطران 370-405 | الكروت الإحصائية (pills) مدفونة داخل الهيدر — تُزاحم المحتوى |
| B5 | السطران 386, 394, 479-508, 1044-1050 | ألوان ثابتة: `Color(0xFF60A5FA)`, `Color(0xFF4ADE80)`, `Colors.green/red/blue/orange/pink`, `Color(0xFF16A34A)` |

---

## المهام المرتبة (قابلة للتنفيذ)

### المرحلة 1 — إصلاح الشاشة الحمراء (الأولوية القصوى)
1. **A1** — في `_selectParty()`: استبدل `controller.dispose()` الفوري بـ `controller.dispose()` مؤجّل بعد الإطار:
   ```dart
   // بعد await showModalBottomSheet
   WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
   ```
   أو، وهو الأنظف: تحويل `controller` إلى حقل في الـ State و`dispose()` في `dispose()`.
2. **A2** — في `_selectParty()`: اعكس الترتيب — أزل العناصر من الشجرة أولاً ثم تخلّص من الـ controllers:
   ```dart
   final old = List<_QuotationItem>.from(_items);
   setState(() { _items.clear(); /* ... */ });
   for (final item in old) { item.dispose(); }
   ```
3. **A3** — في `_partyFields()`: لا تمرّر `initialValue` غير الموجود في القائمة. الحل: تصفية `items` لتتضمن دائماً القيمة الحالية، أو استبدال `DropdownButtonFormField` بـ `DropdownButton<int?>` داخل `InputDecorator` (يتجنّب assert بالكامل).
4. **A4** — في `_loadPartyData()`: تغليف إسناد `_opportunities` بـ `setState`، والتحقق من `mounted` قبل الإسناد.

### المرحلة 2 — هيدر قائمة العروض
5. **B1** — `expandedHeight: 270` → `170` (يتسع للهيدر المدمج فقط).
6. **B2** — `padding` الـ hero: من `fromLTRB(16, 66, 16, 13)` → `fromLTRB(16, 8, 16, 14)` بعد التأكد أن `SliverAppBar` يوفّر المساحة العلوية؛ أو حذف البادج العلوي كلياً والاعتماد على `SafeArea`.
7. **B3** — حذف نص "عروض الأسعار" المكرر من `_hero()`؛ يبقى العنوان في `SliverAppBar.title` فقط. استبدال السطر الفرعي في الـ hero بوصف وظيفي قصير (يظهر فقط عند `expandedHeight` الكامل).
8. **B4** — نقل الكروت الإحصائية إلى **صف KPI مستقل** يُدرج بعد `_controls()` مباشرة، بنفس تصميم بطاقات `price_list_screen.dart` (أو `CrmDesignSystem.kpiCard`): 4 بطاقات (إجمالي القيمة / العملاء / نسبة التحويل / عدد العروض) — أفقية قابلة للتمرير على الشاشات الصغيرة.
9. **B5** — استبدال كل الألوان الثابتة في الملف بـ `AppColors`:
   - `Colors.green` → `AppColors.success`، `Colors.red` → `AppColors.error`، `Colors.blue` → `AppColors.info`، `Colors.orange` → `AppColors.warning`، `Colors.pink` → `AppColors.errorLight`، `Colors.blueGrey` → `AppColors.neutral`
   - `Color(0xFF60A5FA)` → `AppColors.infoLight`، `Color(0xFF4ADE80)` → `AppColors.successLight`، `Color(0xFF16A34A)` → `AppColors.success`
   - `Colors.red.shade400/700`، `Colors.green.shade700` → `AppColors.error`/`AppColors.success`

### المرحلة 3 — احترافية الأيقونات
10. **جدول استبدال موحّد** يُطبَّق على الشاشات الثلاث:
    | الاستخدام | الحالي | البديل |
    |-----------|--------|--------|
    | هوية عرض السعر | `request_quote_rounded` | `description_rounded` |
    | مسودة | `edit_note_rounded` | `draft_rounded` |
    | مقبول | `thumb_up_rounded` | `check_circle_rounded` |
    | مرفوض | `thumb_down_rounded` | `cancel_rounded` |
    | محوّل | `swap_horiz_rounded` | `receipt_long_rounded` (للعرض) / `assignment_turned_in_rounded` (للفلتر) |
    | منتهي | `event_busy_rounded` | `timer_off_rounded` |
    | الكل | `apps_rounded` | `dashboard_rounded` |
    | العملاء | `groups_rounded` | `people_alt_rounded` |
    | إجمالي القيمة | `payments_rounded` | `account_balance_wallet_rounded` |
    | الموظف (chip) | `badge_rounded` | `support_agent_rounded` |
    | أيام التصنيع | `schedule_rounded` | `precision_manufacturing_rounded` |
    | الكمية | `numbers_rounded` | `production_quantity_limits_rounded` |
    | سعر الوحدة | `payments_rounded` | `local_offer_rounded` |
    | بديل مصنّع | `tune_rounded` | `factory_rounded` |
    | تعديل/حذف (اتساق) | `edit_rounded` + `delete_outline_rounded` | `edit_rounded` + `delete_rounded` |
11. **توحيد المقاسات**: كل أيقونة داخل chip ‎= 13-15px، داخل زر = 17-18px، داخل دائرة هوية = 21-27px.

### المرحلة 4 — تنسيق شاشات الإضافة والتفاصيل
12. استبدال الألوان الثابتة في `quotation_form_screen.dart` و`quotation_details_screen.dart` بـ `AppColors` (نفس جدول B5).
13. توحيد خط النصوص: استخدام `AppTextStyles` (`lib/services/app_text_styles.dart`) بدل `GoogleFonts.cairo` المباشر مع مقاسات متفرقة.
14. في شاشة التفاصيل: توحيد أيقونات الأقسام (الأصناف/الملاحظات/الإجماليات) مع نظيراتها في شاشة الإضافة.

---

## المخاطر
- **تغيير `expandedHeight`** يؤثر على تمرير القائمة — يلزم التأكد أن `NestedScrollView` ما زال يطوي الهيدر بشكل صحيح بعد نقل الكروت.
- **إصلاح A3** قد يغيّر سلوك حقل "فرصة البيع" — التأكد أن اختيار فرصة لا يزال يُحفظ في `_opportunityId` ويُرسل مع الحفظ.
- **توحيد الأيقونات** تغيير بصري فقط ولا يمس المنطق.

## خطوات التحقق
1. `flutter analyze lib` — صفر أخطاء (المستوى الحالي: صفر أخطاء، 1979 تنبيه `info` سابقة).
2. اختبار يدوي لتدفق **إضافة عرض سعر**: اختيار عميل (لا شاشة حمراء) → اختيار عميل **بعد** إضافة أصناف (لا شاشة حمراء) → فتح عرض محفوظ ومرتبط بفرصة (لا شاشة حمراء) → dropdown الفرص معبّأ فعلياً.
3. فتح شاشة **تعديل** لعرض به `OpportunityID` محفوظ.
4. التحقق من ارتفاع الهيدر الجديد ومساحة المحتوى أسفله.
5. التحقق من ظهور صف الكروت الإحصائية في الوضعين الليلي والنهاري.
6. مراجعة الأيقونات الثلاث شاشات بصرياً على الموبايل.

---

## ملاحظات
- الخطة لا تلمس دوال PDF في `quotation_details_screen.dart` (`_buildPdf` وماFollows) — خارج النطاق بقرار المستخدم.
- `crm_pdf_generator.dart` لا يُعدَّل.
