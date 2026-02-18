# Script para automatizar build y deploy de Flutter a Firebase
clear

Write-Host "================================" -ForegroundColor Cyan
Write-Host "BUILD & DEPLOY - Flutter Web" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[*] Building Flutter web..." -ForegroundColor Green
#flutter clean
#flutter pub get
flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Build exitoso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[*] Deploying to Firebase..." -ForegroundColor Green
    firebase deploy
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "================================" -ForegroundColor Green
        Write-Host "[OK] Deploy completado!" -ForegroundColor Green
        Write-Host "================================"   -ForegroundColor Green
        Write-Host "[SUCCESS] Aplicación actualizada en Firebase!" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[ERROR] Error en el deploy" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "[ERROR] Build fallido!" -ForegroundColor Red
    exit 1
}
