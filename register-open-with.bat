@echo off
setlocal
echo =======================================================
echo  Mendaftarkan "Open with Valtera Note" ke Klik-Kanan Windows
echo =======================================================
echo.

set "EXE_PATH=%~dp0src-tauri\target\release\valtera-note.exe"

if not exist "%EXE_PATH%" (
    echo [ERROR] File executable tidak ditemukan di:
    echo %EXE_PATH%
    echo Harap jalankan build terlebih dahulu!
    pause
    exit /b 1
)

echo Menambahkan registri untuk Windows Explorer...
reg add "HKCU\Software\Classes\*\shell\ValteraNote" /ve /d "Open with Valtera Note" /f >nul
reg add "HKCU\Software\Classes\*\shell\ValteraNote" /v "Icon" /d "\"%EXE_PATH%\",0" /f >nul
reg add "HKCU\Software\Classes\*\shell\ValteraNote\command" /ve /d "\"%EXE_PATH%\" \"%%1\"" /f >nul

echo.
echo [SUKSES] Menu "Open with Valtera Note" berhasil ditambahkan ke klik-kanan semua file!
echo Sekarang Anda bisa klik kanan file .txt, .json, .md, .sql, dll dan pilih "Open with Valtera Note".
echo.
pause
