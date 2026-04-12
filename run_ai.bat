@echo off
title AI Monitor - SmartBovine
echo ==================================================
echo.  MENGAKTIFKAN AI MONITOR (BACKGROUND SERVICE)...
echo ==================================================
cd C:\laragon\www\frontsapi
C:\laragon\www\ai_sapi\venv\Scripts\python.exe C:\laragon\www\frontsapi\ai_monitor\monitor.py
pause
