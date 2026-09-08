@echo off
set "FLUTTER_ROOT=C:\Users\dell\.puro\envs\stable\flutter"
set "JAVA_HOME=C:\Users\dell\AppData\Local\Android\jdk-17.0.10+7"
set "PATH=%JAVA_HOME%\bin;%PATH%"
"%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe" --disable-dart-dev --packages="%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json" "%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot" %*
