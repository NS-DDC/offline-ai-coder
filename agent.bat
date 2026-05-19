@echo off
REM ============================================================================
REM Offline AI Coding Agent - CMD Launcher
REM Forwards to agent.ps1
REM ============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0agent.ps1" %*
