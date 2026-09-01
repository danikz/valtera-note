@echo off
setlocal
echo Menghapus "Open with Valtera Note" dari klik-kanan Windows...
reg delete "HKCU\Software\Classes\*\shell\ValteraNote" /f >nul 2>&1
echo [SUKSES] Menu telah dihapus dari klik-kanan Windows.
pause
