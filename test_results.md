# Nightfall Chess - Test Results

## Summary
- **Date:** 2025-03-25 14:05:30
- **Tests Run:** 9
- **Passed:** 6
- **Failed:** 3
- **Skipped:** 0
- **Success Rate:** 66%

## Test Details

### Test entity initialization (entity_initialization)
**Status:** ✅ Passed

### Test item system functionality (item_system)
**Status:** ✅ Passed

### Test unit system functionality (unit_system)
**Status:** ✅ Passed

### Test grid system functionality (grid_system)
**Status:** ✅ Passed

### Test menu state functionality (menu_state)
**Status:** ❌ Failed
**Error:** .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)

### Test game state functionality (game_state)
**Status:** ❌ Failed
**Error:** .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)

### Test inventory state functionality (inventory_state)
**Status:** ❌ Failed
**Error:** .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)

### Test item database content (item_database)
**Status:** ✅ Passed

### Test entity, item, and unit integration (entity_item_unit_integration)
**Status:** ✅ Passed

## Log

```
Starting test suite for Nightfall Chess
Total tests: 9
------------------------------------
Running test: Test entity initialization (entity_initialization)
  ✓ PASS
Running test: Test item system functionality (item_system)
  ✓ PASS
Running test: Test unit system functionality (unit_system)
  ✓ PASS
Running test: Test grid system functionality (grid_system)
  ✓ PASS
Running test: Test menu state functionality (menu_state)
  ✗ ERROR: .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)
Running test: Test game state functionality (game_state)
  ✗ ERROR: .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)
Running test: Test inventory state functionality (inventory_state)
  ✗ ERROR: .\lib\hump\gamestate.lua:85: bad argument #1 to 'for iterator' (table expected, got nil)
Running test: Test item database content (item_database)
  ✓ PASS
Running test: Test entity, item, and unit integration (entity_item_unit_integration)
  ✓ PASS
------------------------------------
Test results:
  Passed: 6
  Failed: 3
  Skipped: 0
  Total: 9
```
