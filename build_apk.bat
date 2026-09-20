@echo off
title Build APK
set "JAVA_HOME=D:\tools\jdk\jdk-17.0.20.1+1"
set "ANDROID_HOME=D:\android-sdk"
set "ANDROID_SDK_ROOT=D:\android-sdk"
set "FLUTTER_STORAGE_BASE_URL=https://mirrors.cloud.tencent.com/flutter"
set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "PATH=%JAVA_HOME%\bin;D:\flutter_sdk\flutter\bin;%PATH%"
set "LOG=D:\english_app\build_log.txt"
if exist "%LOG%" del "%LOG%"

echo [1/4] Check Java loopback...
> "%TEMP%\SelTest.java" echo import java.nio.channels.Selector; public class SelTest { public static void main(String[] args) throws Exception { Selector s = Selector.open(); System.out.println("LOOPBACK_OK"); } }
"%JAVA_HOME%\bin\java.exe" "%TEMP%\SelTest.java" > "%TEMP%\seltest.log" 2>&1
findstr /C:"LOOPBACK_OK" "%TEMP%\seltest.log" >nul
if errorlevel 1 goto fail_loopback
echo Java loopback OK.

echo [2/4] Flutter pub get...
cd /d D:\english_app\frontend
call D:\flutter_sdk\flutter\bin\flutter.bat pub get >> "%LOG%" 2>&1
if errorlevel 1 goto fail_pub

echo [3/4] Building APK (5-10 min)...
call D:\flutter_sdk\flutter\bin\flutter.bat build apk --release --dart-define=API_ENV=prod --dart-define=API_BASE_URL=http://8.138.161.154:8002/api/v1 >> "%LOG%" 2>&1
if errorlevel 1 goto fail_build

echo [4/4] Done! APK:
dir D:\english_app\frontend\build\app\outputs\flutter-apk\*.apk
echo.
echo Now tell Codex to install it on the phone.
pause
exit /b 0

:fail_loopback
echo.
echo [FAIL] Java loopback blocked - cannot build here.
type "%TEMP%\seltest.log"
echo.
echo Please screenshot this window and send it to Codex.
pause
exit /b 1

:fail_pub
echo.
echo [FAIL] pub get failed. Log: %LOG%
pause
exit /b 1

:fail_build
echo.
echo [FAIL] Build failed. Log: %LOG%
pause
exit /b 1
