# Price List Screen UX/UI Improvements and Sidebar Integration

## Context

**Primary target**: `lib/screens/price_list_screen.dart` — Price list screen with 1,534 lines.
**Integration focus**: Sidebar navigation (`lib/widgets/app_drawer.dart` — 1,680 lines).

### Current structure
- **Price list screen**: Includes hero section with stat cards, search + filters, grid/list views, product cards with prices
- **Sidebar**: Currently price list appears as `SubMenuItem('قائمة الأسعار')` nested under Sales section (see MenuStructure.getItems() in app_drawer.dart)

### Recent work completed
- ✅ **UX improvements across application** (see 1792485898558-ux-improvement-plan.md):
  - Unified colors under `AppColors`/`ThemeService`
  - Created `AppTextStyles` with Cairo typography
  - Centralized loading/error/empty states (`AppLoading`, `AppError`, `AppEmpty`)
  - Fixed login screen contrast in light mode
  - Added responsive design using `LayoutBuilder`
  - Improved accessibility with semantics and WCAG AA contrast
  
- ✅ **Price list design analysis completed** (400+ line review):
  **Strengths**:
  - Utilizes `AppColors` for backgrounds and text
  - RTL Arabic support with Cairo font
  - Toggle between grid/list views
  - Search + filters with tierChips
  - Good loading state (shimmer)
  - Export Excel functionality
  
  **Weaknesses**:
  1. **Hardcoded colors** (S6, S10): `Colors.red.shade700`, `Color(0xFF6366F1)`, `0xFFB45309`, `0xFF16A34A`, etc.
  2. **Mixed typography**: Uses `GoogleFonts.cairo` inconsistently
  3. **Design inconsistencies**: Different card shadows, borders across screens
  4. **No accessibility**: Missing `semanticsLabel`, small touch targets
  5. **No shimmer**: Loading state uses basic shimmer but not consistent
  6. **No trend indicators**: Price changes not visually tracked
  7. **Filter overflow**: Filter row on mobile may overflow (S1)
  8. **No saved views**: User preferences not persisted
  9. **Sidebar**: Price list nested under Sales, not independent top-level item

## Decisions (approved)

| # | Decision | Justification |
|---|----------|---------------|
| 1 | Price list becomes **independent sidebar item** alongside Sales (top-level MenuItem) | Improves navigation hierarchy, makes price list easily accessible, aligns with common CRM patterns |
| 2 | Apply **Premium Dark design system** to price list screen | Consistent with recent premium direction, deeper visual hierarchy |
| 3 | Use **shared design library** (`AppColors`, `AppTextStyles`, `AppLoading` etc.) across app | Reduces code duplication, ensures consistency |
| 4 | Add **filter grid layout** (2 cols mobile / 3 cols tablet) | Prevents overflow, better use of screen space |
| 5 | Include **price trend indicators** and **saved filter views** | Advanced features for power users |

## Affected boundaries

**lib/screens/price_list_screen.dart** (1,534 lines) — Screen UI and logic
**lib/widgets/app_drawer.dart** (1,680 lines) — Sidebar navigation structure
**lib/services/app_colors.dart** (107 lines) — Add premiumBackground/premiumSurface for Premium Dark theme
**lib/services/app_text_styles.dart** (100+ lines) — Ensure all needed styles exist
**lib/widgets/premium_ui.dart** (new) — Shared Premium Dark design components

## Current sidebar structure

Price list already exists as both:
1. **Independent top-level MenuItem** (lines 688-695 in app_drawer.dart)
2. **Child of Sales section** (lines 644 in Sales children)

**Integration points**:
1. **MenuStructure.getItems()** in `app_drawer.dart`: Remove duplicate price list entry from Sales children (keep independent MenuItem)
2. **app_drawer.dart line 197-198**: Keep existing `_canViewMenu` logic for price list (covers both contexts)
3. **FormNames.priceList**: Already exists as `frm_PriceList`
4. **permission_service.dart**: No changes needed

## Tasks (ordered)

### Phase 1 — Core Screen Improvements

**1.1** Add Premium design colors to `AppColors`:
- `premiumBackgroundDark` (#0A1524), `premiumBackgroundLight` (#F7F8FC)
- `premiumSurfaceDark` (#16233A), `premiumSurfaceLight` (#FFFFFF)  
- `premiumStrokeDark` (#26364F), `premiumStrokeLight` (#E8ECF4)
- `premiumGlow` = gold.withValues(alpha: 0.10)

**1.2** Create `PremiumHero` widget:
- Gradient: navyDark → navy → navyLight
- Gold glow effect (circle positioned)
- Icon + subtitle, no redundant header badge
- `expandedHeight` ≈ 132

**1.3** Create `PremiumStatCard` widget:
- Icon + value + label + optional selected state + onTap
- `minHeight: 96`, value size 18/w900, label with ellipsis

**1.4** Create `PremiumStatStrip` widget:
- Wrap stat cards in responsive grid/row, width fixed 156×100
- Prevents overflow with any number of cards

**1.5** Create `PremiumFilterGrid` widget:
- Uses `Responsive.of(context)` for mobile/tablet breakpoints
- 2 cols mobile / 3 cols tablet, `Wrap` with spacing 10
- Each field gets `constraints.maxWidth` divided by cols

**1.6** Create `PremiumEntityCard` for product rows (optional for future)

**1.7** Create `PremiumBadge` widget:
- Neutral/success/warning/error states based on theme
- Backgrounds use `AppColors` with transparency

**1.8** Ensure `AppTextStyles` covers new sizes (displayLarge, titleLarge, titleMedium, bodySmall, labelSmall)

### Phase 2 — Screen Implementation

**2.1** Update `price_list_screen.dart`:
- Replace `Scaffold.backgroundColor` with `AppColors.premiumBackground(_isDark)`
- Replace `_buildHero()` with `PremiumHero` widget
- Replace `_buildFilters()` with `PremiumFilterGrid` + `PremiumFilterField` × 3
- Replace `_buildKpis()` with `PremiumStatStrip` with 4 cards:
  - Cost → `AppColors.warning`
  - Sale → `AppColors.success` 
  - Profit → `AppColors.info`
  - Range → `AppColors.neutral`
- Fix inverted label/value bug for range card
- Replace `_ValueRowCard` with 2×2 grid using `Wrap`
- Replace hardcoded colors with `AppColors` values
- Replace `DropdownButtonFormField(value:)` with `initialValue:`
- Add `semanticsLabel` to key widgets for accessibility
- Add shimmer loading state for better UX

**2.2** Add price trend indicators:
- Visual indicators for price changes (up/down arrows, % changes)
- Show trend data in stat cards
- Add trend toggle in filters

**2.3** Add saved filter views:
- Persist user filters in `SharedPreferences`
- Quick access to saved filter presets

### Phase 3 — Sidebar Integration

**3.1** Update `MenuStructure.getItems()` in `app_drawer.dart`:
- Move price list from Sales children to top-level MenuItem
- Create new Sales MenuItem with remaining children (quotations, job orders, pipeline, etc.)

**3.2** Update `_canViewMenu` method:
- Modify line 197-198 to allow top-level access check
- Remove dependency on Sales section permissions

**3.3** Update `_buildSection` and `_buildSubItem` if needed:
- Adjust visual styling for independent top-level item

### Phase 4 — Testing and Validation

**4.1** `flutter analyze lib/screens/price_list_screen.dart`:
- Target: zero new errors

**4.2** Manual testing on 320/360/411/768dp:
- No overflow in filters or stat strip
- WCAG AA contrast for all text
- Grid layout correct on mobile/tablet
- Sidebar navigation works, price list accessible at top-level

**4.3** Functional verification:
- Search + filters work correctly
- Grid/list view toggle functions
- Export Excel works
- Price tier selection and filtering
- Permissions respected

## Risks

**R1** - *Menu restructuring* (3.1): Changing price list from nested to top-level may affect permission checks or route navigation. Impact: Medium | Mitigation: Update all navigation switch cases in `_navigateToScreen`

**R2** - *Premium colors consistency* (1.1): New premium colors may need updates in other screens. Impact: Low | Mitigation: Track usage in app_colors.dart

**R3** - *Filter layout overflow* (2.1): Premium filter grid may still overflow on very small screens. Impact: Low | Mitigation: Use `Flexible` inside rows if needed

**R4** - *Performance* (2.2): Price trend indicators may add computation. Impact: Low | Mitigation: Debounce updates

## Out of scope

- `lib/screens/lost_recovery_report_screen.dart` and other inventory screens: Design improvements apply only to price list per current scope
- Changing core `AppColors` identity (navy/gold) — no modifications
- PDF printing functionality (unrelated to this effort)

## Dependencies

- Implementation requires access to modify `app_drawer.dart`, `app_colors.dart`, and `app_text_styles.dart`
- New file `premium_ui.dart` will be created for shared components
- Widget creation and refactoring in `price_list_screen.dart`
- This plan is implementation-ready for an agent with file modification permissions

---

**Plan created**: 2025-10-21 (today)
**Status**: Ready for implementation