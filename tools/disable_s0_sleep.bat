@echo off
REM ============================================================
REM  disable_s0_sleep.bat
REM  Run as Administrator (right-click -> Run as administrator)
REM
REM  Disables S0 Low Power Idle auto-sleep so the PC keeps running.
REM
REM  To re-enable default sleep behaviour: Settings > Power & sleep
REM ============================================================

echo.
echo === Disabling S0 auto-sleep (admin required) ===
echo.

REM 1. Core sleep/hibernate timers: Never on AC and DC
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
powercfg /setdcvalueindex SCHEME_CURRENT SUB_SLEEP HYBRIDSLEEP 0
echo [OK] Sleep / hibernate / hybrid = Never

REM 2. Lid close = Do nothing (AC + DC)
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
echo [OK] Lid close = Do nothing

REM 3. Disable Modern Standby (S0) auto-sleep (EnabledActions 0x7 - 0x0)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\ModernSleep" /v EnabledActions /t REG_DWORD /d 0 /f
echo [OK] ModernStandby EnabledActions = 0

REM 4. Disable hibernation file
powercfg /h off
echo [OK] Hibernation off

REM 5. Apply the active scheme
powercfg /setactive SCHEME_CURRENT
echo [OK] Active scheme reapplied

echo.
echo === Done ===
echo Verify with:  powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
echo.
pause
