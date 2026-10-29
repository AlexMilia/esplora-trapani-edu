@echo off
rem ESPLORA TRAPANI EDU - avvia il player locale (Windows). Doppio clic e basta.
cd /d "%~dp0"
title Esplora Trapani Edu - player locale
where node >nul 2>nul
if %errorlevel%==0 (
  node avvia.js
  goto :fine
)
where php >nul 2>nul
if %errorlevel%==0 (
  echo Node.js non trovato: uso PHP. Se i salti avanti/indietro nei video non funzionano, installa Node.js da nodejs.org
  start "" "http://localhost:8765/"
  php -S localhost:8765
  goto :fine
)
where python >nul 2>nul
if %errorlevel%==0 (
  echo Node.js non trovato: uso Python. ATTENZIONE: con Python i salti avanti/indietro nei video possono non funzionare. Meglio installare Node.js da nodejs.org
  start "" "http://localhost:8765/"
  python -m http.server 8765 --bind 127.0.0.1
  goto :fine
)
echo.
echo Per avviare il player locale serve Node.js: scaricalo da https://nodejs.org (versione LTS), installalo e riprova.
echo.
pause
:fine
