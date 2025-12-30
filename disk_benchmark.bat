@echo off
setlocal enabledelayedexpansion

REM ################################################################################
REM 跨平台硬盘性能测试脚本 - Windows版本
REM 功能：自动检测fio并执行全面的硬盘性能测试
REM 支持：Windows 7/8/10/11, Windows Server
REM 输出：生成HTML格式的测试报告
REM ################################################################################

chcp 65001 >nul
title 硬盘性能测试工具

REM 设置颜色代码
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "BLUE=[94m"
set "NC=[0m"

REM 全局变量
set "TEST_FILE=fio_test_file"
set "REPORT_FILE=disk_benchmark_report_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.html"
set "REPORT_FILE=%REPORT_FILE: =0%"
set "START_TIME=%time%"
set "TEST_COUNT=0"

echo.
echo %BLUE%================================================================%NC%
echo %GREEN%              硬盘性能测试工具%NC%
echo           基于 fio (Flexible I/O Tester)
echo %BLUE%================================================================%NC%
echo.

REM 检查fio是否已安装
echo %BLUE%[INFO]%NC% 检查fio安装状态...
where fio >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%[WARNING]%NC% fio未安装
    echo.
    echo %RED%请先安装fio：%NC%
    echo   1. 下载: https://github.com/axboe/fio/releases
    echo   2. 或使用Chocolatey: choco install fio
    echo   3. 或使用Scoop: scoop install fio
    echo.
    pause
    exit /b 1
) else (
    for /f "tokens=*" %%i in ('fio --version 2^>^&1') do set FIO_VERSION=%%i
    echo %GREEN%[SUCCESS]%NC% fio已安装 (!FIO_VERSION!)
)

REM 收集系统信息
echo %BLUE%[INFO]%NC% 收集系统信息...
for /f "tokens=2 delims==" %%i in ('wmic os get caption /value ^| find "="') do set OS_NAME=%%i
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "="') do set CPU_NAME=%%i
for /f "tokens=2 delims==" %%i in ('wmic computersystem get totalphysicalmemory /value ^| find "="') do set TOTAL_MEM=%%i
set /a MEM_GB=!TOTAL_MEM:~0,-9!
for /f "tokens=3" %%i in ('dir /-c ^| find "bytes free"') do set DISK_FREE=%%i

echo %GREEN%[SUCCESS]%NC% 系统信息收集完成
echo.

REM 检查磁盘空间
echo %BLUE%[INFO]%NC% 检查磁盘空间...
if !DISK_FREE! lss 2147483648 (
    echo %RED%[ERROR]%NC% 磁盘空间不足！需要至少2GB可用空间
    pause
    exit /b 1
)
echo %GREEN%[SUCCESS]%NC% 磁盘空间检查通过
echo.

REM 创建临时结果文件
set "TEMP_RESULTS=%TEMP%\fio_results_%RANDOM%.txt"
echo. > "%TEMP_RESULTS%"

echo %BLUE%[INFO]%NC% 开始硬盘性能测试...
echo.
timeout /t 2 /nobreak >nul

REM ① 连续写入测试
call :run_test "1" "连续写入测试 (1GB文件，模拟大文件拷贝)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=write -ioengine=windowsaio -bs=1M -size=1G -numjobs=8 -runtime=30 -group_reporting -name=Sequential_Write_Test"

REM ② 连续读取测试
call :run_test "2" "连续读取测试 (1GB文件，模拟大文件读取)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=read -ioengine=windowsaio -bs=1M -size=1G -numjobs=8 -runtime=30 -group_reporting -name=Sequential_Read_Test"

REM ③ 4K随机写入测试
call :run_test "3" "4K随机写入测试 (SSD核心性能指标)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=randwrite -ioengine=windowsaio -bs=4K -size=1G -numjobs=8 -runtime=30 -group_reporting -name=4K_Random_Write"

REM ④ 4K随机读取测试
call :run_test "4" "4K随机读取测试 (开发/推理核心指标)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=randread -ioengine=windowsaio -bs=4K -size=1G -numjobs=8 -runtime=30 -group_reporting -name=4K_Random_Read"

REM ⑤ 4K混合随机读写测试
call :run_test "5" "4K混合随机读写测试 (70%%读/30%%写，模拟真实场景)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=randrw -rwmixread=70 -ioengine=windowsaio -bs=4K -size=1G -numjobs=8 -runtime=30 -group_reporting -name=4K_Mixed_RW"

REM ⑥ 1MB混合读写测试
call :run_test "6" "1MB混合读写测试 (70%%读/30%%写，模拟视频流/大模型)" "-filename=%TEST_FILE% -direct=1 -iodepth=64 -thread -rw=randrw -rwmixread=70 -ioengine=windowsaio -bs=1M -size=1G -numjobs=8 -runtime=30 -group_reporting -name=1M_Mixed_RW"

REM 清理测试文件
echo.
echo %BLUE%[INFO]%NC% 清理测试文件...
del /f /q "%TEST_FILE%" 2>nul
echo %GREEN%[SUCCESS]%NC% 清理完成

REM 生成HTML报告
call :generate_html_report

echo.
echo %BLUE%================================================================%NC%
echo %GREEN%[SUCCESS]%NC% 所有测试完成！
echo %BLUE%================================================================%NC%
echo.
echo %YELLOW%性能参考指标：%NC%
echo   - 连续读写: 优秀 ^>500MB/s, 良好 ^>200MB/s
echo   - 4K随机读: 优秀 ^>50K IOPS, 良好 ^>20K IOPS
echo   - 4K随机写: 优秀 ^>40K IOPS, 良好 ^>15K IOPS
echo.
echo %GREEN%HTML报告已生成: %REPORT_FILE%%NC%
echo.

REM 询问是否打开报告
set /p OPEN_REPORT="是否打开HTML报告? (Y/N): "
if /i "%OPEN_REPORT%"=="Y" start "" "%REPORT_FILE%"

REM 清理临时文件
del /f /q "%TEMP_RESULTS%" 2>nul

pause
exit /b 0

REM ============================================================================
REM 函数：运行fio测试
REM ============================================================================
:run_test
set "test_num=%~1"
set "test_desc=%~2"
set "fio_params=%~3"

echo %BLUE%================================================================%NC%
echo %GREEN%【测试 %test_num%】%NC% %test_desc%
echo %BLUE%================================================================%NC%

REM 执行fio测试并保存输出
set "TEMP_OUTPUT=%TEMP%\fio_output_%RANDOM%.txt"
fio %fio_params% > "%TEMP_OUTPUT%" 2>&1
type "%TEMP_OUTPUT%"

REM 解析结果
call :parse_fio_output "%TEMP_OUTPUT%" "%test_desc%"

REM 保存结果到临时文件（包含摘要信息）
echo %test_num%^|%test_desc%^|!BW_READ!^|!IOPS_READ!^|!BW_WRITE!^|!IOPS_WRITE!^|!READ_SUMMARY!^|!WRITE_SUMMARY! >> "%TEMP_RESULTS%"

del /f /q "%TEMP_OUTPUT%" 2>nul
echo.
goto :eof

REM ============================================================================
REM 函数：解析fio输出
REM ============================================================================
:parse_fio_output
set "output_file=%~1"
set "test_type=%~2"

set "BW_READ=N/A"
set "IOPS_READ=N/A"
set "BW_WRITE=N/A"
set "IOPS_WRITE=N/A"
set "READ_SUMMARY="
set "WRITE_SUMMARY="

REM 提取 Run status 摘要信息
for /f "tokens=*" %%i in ('findstr /r "READ:.*bw=" "%output_file%"') do (
    set "READ_SUMMARY=%%i"
)

for /f "tokens=*" %%i in ('findstr /r "WRITE:.*bw=" "%output_file%"') do (
    set "WRITE_SUMMARY=%%i"
)

REM 解析读取性能
for /f "tokens=*" %%i in ('findstr /r "read.*bw=" "%output_file%"') do (
    set "line=%%i"
    for /f "tokens=2 delims==" %%j in ("!line!") do (
        for /f "tokens=1" %%k in ("%%j") do set "BW_READ=%%k"
    )
)

for /f "tokens=*" %%i in ('findstr /r "read.*IOPS=" "%output_file%"') do (
    set "line=%%i"
    for /f "tokens=*" %%j in ("!line!") do (
        echo !line! | findstr /r "IOPS=[0-9]" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims==" %%k in ("!line!") do (
                for /f "tokens=1 delims=," %%l in ("%%k") do set "IOPS_READ=%%l"
            )
        )
    )
)

REM 解析写入性能
for /f "tokens=*" %%i in ('findstr /r "write.*bw=" "%output_file%"') do (
    set "line=%%i"
    for /f "tokens=2 delims==" %%j in ("!line!") do (
        for /f "tokens=1" %%k in ("%%j") do set "BW_WRITE=%%k"
    )
)

for /f "tokens=*" %%i in ('findstr /r "write.*IOPS=" "%output_file%"') do (
    set "line=%%i"
    for /f "tokens=*" %%j in ("!line!") do (
        echo !line! | findstr /r "IOPS=[0-9]" >nul
        if !errorlevel! equ 0 (
            for /f "tokens=2 delims==" %%k in ("!line!") do (
                for /f "tokens=1 delims=," %%l in ("%%k") do set "IOPS_WRITE=%%l"
            )
        )
    )
)

REM 如果是纯读或纯写测试，使用通用解析
if "!BW_READ!"=="N/A" if not "%test_type%"=="%test_type:Read=%" (
    for /f "tokens=*" %%i in ('findstr /r "bw=" "%output_file%" ^| findstr /v "write"') do (
        set "line=%%i"
        for /f "tokens=2 delims==" %%j in ("!line!") do (
            for /f "tokens=1" %%k in ("%%j") do set "BW_READ=%%k"
        )
    )
)

if "!BW_WRITE!"=="N/A" if not "%test_type%"=="%test_type:Write=%" (
    for /f "tokens=*" %%i in ('findstr /r "bw=" "%output_file%" ^| findstr /v "read"') do (
        set "line=%%i"
        for /f "tokens=2 delims==" %%j in ("!line!") do (
            for /f "tokens=1" %%k in ("%%j") do set "BW_WRITE=%%k"
        )
    )
)

goto :eof

REM ============================================================================
REM 函数：生成HTML报告
REM ============================================================================
:generate_html_report
echo %BLUE%[INFO]%NC% 生成HTML报告...

REM 计算测试时长
set "END_TIME=%time%"

REM 创建HTML文件头部
(
echo ^<!DOCTYPE html^>
echo ^<html lang="zh-CN"^>
echo ^<head^>
echo     ^<meta charset="UTF-8"^>
echo     ^<meta name="viewport" content="width=device-width, initial-scale=1.0"^>
echo     ^<title^>硬盘性能测试报告^</title^>
echo     ^<style^>
echo         * { margin: 0; padding: 0; box-sizing: border-box; }
echo         body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: linear-gradient^(135deg, #667eea 0%%, #764ba2 100%%^); padding: 20px; min-height: 100vh; }
echo         .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 20px; box-shadow: 0 20px 60px rgba^(0,0,0,0.3^); overflow: hidden; }
echo         .header { background: linear-gradient^(135deg, #667eea 0%%, #764ba2 100%%^); color: white; padding: 40px; text-align: center; }
echo         .header h1 { font-size: 2.5em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba^(0,0,0,0.2^); }
echo         .header p { font-size: 1.1em; opacity: 0.9; }
echo         .system-info { background: #f8f9fa; padding: 30px; border-bottom: 3px solid #e9ecef; }
echo         .system-info h2 { color: #495057; margin-bottom: 20px; font-size: 1.5em; }
echo         .info-grid { display: grid; grid-template-columns: repeat^(auto-fit, minmax^(250px, 1fr^)^); gap: 15px; }
echo         .info-item { background: white; padding: 15px; border-radius: 10px; border-left: 4px solid #667eea; box-shadow: 0 2px 4px rgba^(0,0,0,0.1^); }
echo         .info-item strong { color: #667eea; display: block; margin-bottom: 5px; }
echo         .results { padding: 40px; }
echo         .results h2 { color: #495057; margin-bottom: 30px; font-size: 1.8em; text-align: center; }
echo         .test-card { background: white; border-radius: 15px; padding: 25px; margin-bottom: 25px; box-shadow: 0 4px 6px rgba^(0,0,0,0.1^); border: 2px solid #e9ecef; transition: transform 0.3s; }
echo         .test-card:hover { transform: translateY^(-5px^); box-shadow: 0 8px 15px rgba^(0,0,0,0.2^); }
echo         .test-header { display: flex; align-items: center; margin-bottom: 20px; padding-bottom: 15px; border-bottom: 2px solid #e9ecef; }
echo         .test-number { background: linear-gradient^(135deg, #667eea 0%%, #764ba2 100%%^); color: white; width: 50px; height: 50px; border-radius: 50%%; display: flex; align-items: center; justify-content: center; font-size: 1.5em; font-weight: bold; margin-right: 20px; }
echo         .test-title { flex: 1; font-size: 1.3em; color: #495057; font-weight: 600; }
echo         .metrics { display: grid; grid-template-columns: repeat^(auto-fit, minmax^(200px, 1fr^)^); gap: 15px; }
echo         .metric { background: #f8f9fa; padding: 15px; border-radius: 10px; text-align: center; }
echo         .metric-label { color: #6c757d; font-size: 0.9em; margin-bottom: 8px; text-transform: uppercase; }
echo         .metric-value { color: #495057; font-size: 1.5em; font-weight: bold; }
echo         .footer { background: #f8f9fa; padding: 30px; text-align: center; border-top: 3px solid #e9ecef; }
echo         .reference { background: white; padding: 20px; border-radius: 10px; margin-top: 20px; text-align: left; max-width: 600px; margin-left: auto; margin-right: auto; }
echo         .reference h3 { color: #495057; margin-bottom: 15px; }
echo         .reference ul { list-style: none; padding-left: 0; }
echo         .reference li { padding: 8px 0; color: #6c757d; border-bottom: 1px solid #e9ecef; }
echo     ^</style^>
echo ^</head^>
echo ^<body^>
echo     ^<div class="container"^>
echo         ^<div class="header"^>
echo             ^<h1^>🚀 硬盘性能测试报告^</h1^>
echo             ^<p^>基于 FIO ^(Flexible I/O Tester^) 专业测试工具^</p^>
echo         ^</div^>
echo         ^<div class="system-info"^>
echo             ^<h2^>📊 系统信息^</h2^>
echo             ^<div class="info-grid"^>
echo                 ^<div class="info-item"^>^<strong^>操作系统^</strong^>%OS_NAME%^</div^>
echo                 ^<div class="info-item"^>^<strong^>CPU^</strong^>%CPU_NAME%^</div^>
echo                 ^<div class="info-item"^>^<strong^>内存^</strong^>%MEM_GB% GB^</div^>
echo                 ^<div class="info-item"^>^<strong^>测试时间^</strong^>%date% %time:~0,8%^</div^>
echo             ^</div^>
echo         ^</div^>
echo         ^<div class="results"^>
echo             ^<h2^>📈 测试结果^</h2^>
) > "%REPORT_FILE%"

REM 添加测试结果
for /f "usebackq tokens=1-8 delims=|" %%a in ("%TEMP_RESULTS%") do (
    if not "%%a"=="" (
        >>"%REPORT_FILE%" echo             ^<div class="test-card"^>
        >>"%REPORT_FILE%" echo                 ^<div class="test-header"^>
        >>"%REPORT_FILE%" echo                     ^<div class="test-number"^>%%a^</div^>
        >>"%REPORT_FILE%" echo                     ^<div class="test-title"^>%%b^</div^>
        >>"%REPORT_FILE%" echo                 ^</div^>
        >>"%REPORT_FILE%" echo                 ^<div class="metrics"^>
        
        if not "%%c"=="N/A" (
            if not "%%c"=="" (
                >>"%REPORT_FILE%" echo                     ^<div class="metric"^>^<div class="metric-label"^>读取带宽^</div^>^<div class="metric-value"^>%%c^</div^>^</div^>
            )
        )
        if not "%%d"=="N/A" (
            if not "%%d"=="" (
                >>"%REPORT_FILE%" echo                     ^<div class="metric"^>^<div class="metric-label"^>读取IOPS^</div^>^<div class="metric-value"^>%%d^</div^>^</div^>
            )
        )
        if not "%%e"=="N/A" (
            if not "%%e"=="" (
                >>"%REPORT_FILE%" echo                     ^<div class="metric"^>^<div class="metric-label"^>写入带宽^</div^>^<div class="metric-value"^>%%e^</div^>^</div^>
            )
        )
        if not "%%f"=="N/A" (
            if not "%%f"=="" (
                >>"%REPORT_FILE%" echo                     ^<div class="metric"^>^<div class="metric-label"^>写入IOPS^</div^>^<div class="metric-value"^>%%f^</div^>^</div^>
            )
        )
        
        >>"%REPORT_FILE%" echo                 ^</div^>
        
        REM 添加详细测试摘要信息
        set "has_summary=0"
        if not "%%g"=="" set "has_summary=1"
        if not "%%h"=="" set "has_summary=1"
        
        if "!has_summary!"=="1" (
            >>"%REPORT_FILE%" echo                 ^<div style="margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 8px; font-size: 0.85em; color: #495057; font-family: 'Courier New', monospace;"^>
            >>"%REPORT_FILE%" echo                     ^<div style="font-weight: bold; margin-bottom: 8px; color: #667eea;"^>📊 详细测试数据^</div^>
            
            if not "%%g"=="" (
                set "read_summary=%%g"
                set "read_summary=!read_summary:<=^&lt;!"
                set "read_summary=!read_summary:>=^&gt;!"
                set "read_summary=!read_summary:&=^&amp;!"
                >>"%REPORT_FILE%" echo                     ^<div style="margin-bottom: 5px;"^>!read_summary!^</div^>
            )
            
            if not "%%h"=="" (
                set "write_summary=%%h"
                set "write_summary=!write_summary:<=^&lt;!"
                set "write_summary=!write_summary:>=^&gt;!"
                set "write_summary=!write_summary:&=^&amp;!"
                >>"%REPORT_FILE%" echo                     ^<div^>!write_summary!^</div^>
            )
            
            >>"%REPORT_FILE%" echo                 ^</div^>
        )
        
        >>"%REPORT_FILE%" echo             ^</div^>
    )
)

REM 添加HTML文件尾部
(
echo         ^</div^>
echo         ^<div class="footer"^>
echo             ^<div class="reference"^>
echo                 ^<h3^>📌 性能参考指标^</h3^>
echo                 ^<ul^>
echo                     ^<li^>✅ 连续读写: 优秀 ^&gt;500MB/s, 良好 ^&gt;200MB/s^</li^>
echo                     ^<li^>✅ 4K随机读: 优秀 ^&gt;50K IOPS, 良好 ^&gt;20K IOPS^</li^>
echo                     ^<li^>✅ 4K随机写: 优秀 ^&gt;40K IOPS, 良好 ^&gt;15K IOPS^</li^>
echo                 ^</ul^>
echo             ^</div^>
echo             ^<p style="margin-top: 20px; color: #6c757d;"^>报告生成时间: %date% %time:~0,8%^</p^>
echo         ^</div^>
echo     ^</div^>
echo ^</body^>
echo ^</html^>
) >> "%REPORT_FILE%"

echo %GREEN%[SUCCESS]%NC% HTML报告生成成功
goto :eof
