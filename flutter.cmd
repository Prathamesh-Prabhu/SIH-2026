@echo off
REM Local wrapper so `flutter` works from this project folder.
REM Points at the Flutter SDK cloned to %USERPROFILE%\flutter (stable channel).
set "FLUTTER_ROOT=%USERPROFILE%\flutter"
if not exist "%FLUTTER_ROOT%\bin\flutter.bat" (
  echo [flutter.cmd] Flutter SDK not found at "%FLUTTER_ROOT%".
  echo Clone it with: git clone --depth 1 -b stable https://github.com/flutter/flutter.git "%FLUTTER_ROOT%"
  exit /b 1
)
REM C: has almost no free space, so all Android build storage lives on D:.
set "ANDROID_HOME=D:\android-dev\android-sdk"
set "ANDROID_SDK_ROOT=D:\android-dev\android-sdk"
set "GRADLE_USER_HOME=D:\android-dev\gradle"
set "PATH=%ANDROID_HOME%\platform-tools;%PATH%"

REM Use a local JDK for Android builds only if one is present; web/desktop do not need it.
if exist "%LOCALAPPDATA%\Android\jdk-17.0.10+7\bin\java.exe" (
  set "JAVA_HOME=%LOCALAPPDATA%\Android\jdk-17.0.10+7"
  set "PATH=%JAVA_HOME%\bin;%PATH%"
)
call "%FLUTTER_ROOT%\bin\flutter.bat" %*
