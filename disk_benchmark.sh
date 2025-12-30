#!/bin/bash

################################################################################
# 跨平台硬盘性能测试脚本
# 功能：自动安装fio并执行全面的硬盘性能测试
# 支持：Linux (Ubuntu/Debian/CentOS/RHEL/Arch), macOS
# 输出：生成HTML格式的测试报告
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
TEST_RESULTS=()
REPORT_FILE="disk_benchmark_report_$(date +%Y%m%d_%H%M%S).html"
START_TIME=$(date +%s)
SYSTEM_INFO=""

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 打印分隔线
print_separator() {
    echo -e "${BLUE}================================================================${NC}"
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            OS_VERSION=$VERSION_ID
        elif [ -f /etc/redhat-release ]; then
            OS="rhel"
        else
            OS="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    
    log_info "检测到操作系统: $OS"
}

# 收集系统信息
collect_system_info() {
    local hostname=$(hostname)
    local kernel=$(uname -r 2>/dev/null || echo "N/A")
    local cpu_info=""
    local mem_info=""
    local disk_info=""
    
    case $OS in
        ubuntu|debian|centos|rhel|fedora|arch|manjaro)
            cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
            mem_info=$(free -h | awk '/^Mem:/ {print $2}')
            disk_info=$(df -h "$TEST_FILE" | awk 'NR==2 {print $2}')
            ;;
        macos)
            cpu_info=$(sysctl -n machdep.cpu.brand_string)
            mem_info=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))GB
            disk_info=$(df -h "$TEST_FILE" | awk 'NR==2 {print $2}')
            ;;
        windows)
            cpu_info=$(wmic cpu get name 2>/dev/null | sed -n 2p | xargs || echo "N/A")
            mem_info=$(wmic computersystem get totalphysicalmemory 2>/dev/null | sed -n 2p | awk '{printf "%.0fGB", $1/1024/1024/1024}' || echo "N/A")
            disk_info=$(df -h "$TEST_FILE" 2>/dev/null | awk 'NR==2 {print $2}' || echo "N/A")
            ;;
    esac
    
    SYSTEM_INFO="主机名: $hostname | 操作系统: $OS | 内核: $kernel | CPU: $cpu_info | 内存: $mem_info | 磁盘容量: $disk_info"
}

# 检查fio是否已安装
check_fio() {
    if command -v fio &> /dev/null; then
        FIO_VERSION=$(fio --version)
        log_success "fio已安装 ($FIO_VERSION)"
        return 0
    else
        log_warning "fio未安装"
        return 1
    fi
}

# 安装fio
install_fio() {
    log_info "开始安装fio..."
    
    case $OS in
        ubuntu|debian)
            log_info "使用apt安装fio..."
            sudo apt-get update
            sudo apt-get install -y fio
            ;;
        centos|rhel|fedora)
            log_info "使用yum/dnf安装fio..."
            if command -v dnf &> /dev/null; then
                sudo dnf install -y fio
            else
                sudo yum install -y fio
            fi
            ;;
        arch|manjaro)
            log_info "使用pacman安装fio..."
            sudo pacman -Sy --noconfirm fio
            ;;
        macos)
            log_info "使用Homebrew安装fio..."
            if ! command -v brew &> /dev/null; then
                log_error "未检测到Homebrew，请先安装Homebrew: https://brew.sh"
                exit 1
            fi
            brew install fio
            ;;
        windows)
            log_error "Windows系统请手动安装fio："
            log_error "1. 下载: https://github.com/axboe/fio/releases"
            log_error "2. 或使用Chocolatey: choco install fio"
            log_error "3. 或使用WSL运行此脚本"
            exit 1
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            log_error "请手动安装fio: https://github.com/axboe/fio"
            exit 1
            ;;
    esac
    
    if check_fio; then
        log_success "fio安装成功！"
    else
        log_error "fio安装失败，请手动安装"
        exit 1
    fi
}

# 检查磁盘空间
check_disk_space() {
    local test_dir=$(dirname "$TEST_FILE")
    local available_space=""
    
    # macOS 和 Linux 使用不同的 df 命令
    if [[ "$OS" == "macos" ]]; then
        available_space=$(df -g "$test_dir" | awk 'NR==2 {print $4}')
    else
        available_space=$(df -BG "$test_dir" | awk 'NR==2 {print $4}' | sed 's/G//')
    fi
    
    # 确保 available_space 是数字
    if [[ ! "$available_space" =~ ^[0-9]+$ ]]; then
        log_warning "无法检测磁盘空间，跳过检查"
        return 0
    fi
    
    if [ "$available_space" -lt 2 ]; then
        log_error "磁盘空间不足！需要至少2GB可用空间，当前可用: ${available_space}GB"
        exit 1
    fi
    
    log_success "磁盘空间检查通过 (可用: ${available_space}GB)"
}

# 清理测试文件
cleanup() {
    log_info "清理测试文件..."
    rm -f "$TEST_FILE"
    log_success "清理完成"
}

# 解析fio输出结果
parse_fio_output() {
    local output="$1"
    local test_type="$2"
    
    local bw_read="N/A"
    local iops_read="N/A"
    local bw_write="N/A"
    local iops_write="N/A"
    local read_summary=""
    local write_summary=""
    
    # 提取 Run status 摘要信息
    read_summary=$(echo "$output" | grep "READ:" | grep "bw=" || echo "")
    write_summary=$(echo "$output" | grep "WRITE:" | grep "bw=" || echo "")
    
    # 解析读取性能 - 支持多种格式
    if echo "$output" | grep -q "read:"; then
        # 提取带宽 (支持 MiB/s, GiB/s, KiB/s 等格式)
        bw_read=$(echo "$output" | grep "read:" | grep -oE "bw=[0-9.]+[KMGT]i?B/s" | head -1 | cut -d= -f2 || echo "N/A")
        # 提取IOPS (支持带k后缀的格式，如 5.18k)
        iops_read=$(echo "$output" | grep "read:" | grep -oE "IOPS=[0-9.]+k?" | head -1 | cut -d= -f2 || echo "N/A")
    fi
    
    # 解析写入性能
    if echo "$output" | grep -q "write:"; then
        bw_write=$(echo "$output" | grep "write:" | grep -oE "bw=[0-9.]+[KMGT]i?B/s" | head -1 | cut -d= -f2 || echo "N/A")
        iops_write=$(echo "$output" | grep "write:" | grep -oE "IOPS=[0-9.]+k?" | head -1 | cut -d= -f2 || echo "N/A")
    fi
    
    # 对于纯读或纯写测试，如果上面没有匹配到，尝试通用解析
    if [[ "$bw_read" == "N/A" ]] && [[ "$test_type" == *"读"* ]]; then
        # 查找包含 bw= 的行（排除 write 相关的）
        bw_read=$(echo "$output" | grep -v "write:" | grep -oE "bw=[0-9.]+[KMGT]i?B/s" | head -1 | cut -d= -f2 || echo "N/A")
        iops_read=$(echo "$output" | grep -v "write:" | grep -oE "IOPS=[0-9.]+k?" | head -1 | cut -d= -f2 || echo "N/A")
    fi
    
    if [[ "$bw_write" == "N/A" ]] && [[ "$test_type" == *"写"* ]]; then
        bw_write=$(echo "$output" | grep -v "read:" | grep -oE "bw=[0-9.]+[KMGT]i?B/s" | head -1 | cut -d= -f2 || echo "N/A")
        iops_write=$(echo "$output" | grep -v "read:" | grep -oE "IOPS=[0-9.]+k?" | head -1 | cut -d= -f2 || echo "N/A")
    fi
    
    echo "$bw_read|$iops_read|$bw_write|$iops_write|$read_summary|$write_summary"
}

# 生成HTML报告
generate_html_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local test_date=$(date "+%Y-%m-%d %H:%M:%S")
    
    cat > "$REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>硬盘性能测试报告</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .system-info {
            background: #f8f9fa;
            padding: 30px;
            border-bottom: 3px solid #e9ecef;
        }
        
        .system-info h2 {
            color: #495057;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        
        .info-item {
            background: white;
            padding: 15px;
            border-radius: 10px;
            border-left: 4px solid #667eea;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        
        .info-item strong {
            color: #667eea;
            display: block;
            margin-bottom: 5px;
        }
        
        .results {
            padding: 40px;
        }
        
        .results h2 {
            color: #495057;
            margin-bottom: 30px;
            font-size: 1.8em;
            text-align: center;
        }
        
        .test-card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 25px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            border: 2px solid #e9ecef;
            transition: transform 0.3s, box-shadow 0.3s;
        }
        
        .test-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 15px rgba(0,0,0,0.2);
        }
        
        .test-header {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 15px;
            border-bottom: 2px solid #e9ecef;
        }
        
        .test-number {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            width: 50px;
            height: 50px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5em;
            font-weight: bold;
            margin-right: 20px;
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.3);
        }
        
        .test-title {
            flex: 1;
            font-size: 1.3em;
            color: #495057;
            font-weight: 600;
        }
        
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .metric {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
        }
        
        .metric-label {
            color: #6c757d;
            font-size: 0.9em;
            margin-bottom: 8px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .metric-value {
            color: #495057;
            font-size: 1.5em;
            font-weight: bold;
        }
        
        .metric-value.good {
            color: #28a745;
        }
        
        .metric-value.warning {
            color: #ffc107;
        }
        
        .metric-value.poor {
            color: #dc3545;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 30px;
            text-align: center;
            border-top: 3px solid #e9ecef;
        }
        
        .reference {
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-top: 20px;
            text-align: left;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
        }
        
        .reference h3 {
            color: #495057;
            margin-bottom: 15px;
        }
        
        .reference ul {
            list-style: none;
            padding-left: 0;
        }
        
        .reference li {
            padding: 8px 0;
            color: #6c757d;
            border-bottom: 1px solid #e9ecef;
        }
        
        .reference li:last-child {
            border-bottom: none;
        }
        
        @media print {
            body {
                background: white;
                padding: 0;
            }
            
            .container {
                box-shadow: none;
            }
            
            .test-card {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 硬盘性能测试报告</h1>
            <p>基于 FIO (Flexible I/O Tester) 专业测试工具</p>
        </div>
        
        <div class="system-info">
            <h2>📊 系统信息</h2>
            <div class="info-grid">
EOF

    # 添加系统信息
    echo "                <div class=\"info-item\"><strong>测试时间</strong>$test_date</div>" >> "$REPORT_FILE"
    echo "                <div class=\"info-item\"><strong>测试时长</strong>${duration}秒</div>" >> "$REPORT_FILE"
    
    # 解析系统信息
    IFS='|' read -ra INFO_PARTS <<< "$SYSTEM_INFO"
    for part in "${INFO_PARTS[@]}"; do
        echo "                <div class=\"info-item\">$part</div>" >> "$REPORT_FILE"
    done
    
    cat >> "$REPORT_FILE" << 'EOF'
            </div>
        </div>
        
        <div class="results">
            <h2>📈 测试结果</h2>
EOF

    # 添加测试结果
    for result in "${TEST_RESULTS[@]}"; do
        IFS='|' read -r test_num test_desc bw_read iops_read bw_write iops_write read_summary write_summary <<< "$result"
        
        cat >> "$REPORT_FILE" << EOF
            <div class="test-card">
                <div class="test-header">
                    <div class="test-number">$test_num</div>
                    <div class="test-title">$test_desc</div>
                </div>
                <div class="metrics">
EOF
        
        # 只添加有效的读取指标
        if [[ "$bw_read" != "N/A" && -n "$bw_read" ]]; then
            echo "                    <div class=\"metric\">" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-label\">读取带宽</div>" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-value\">$bw_read</div>" >> "$REPORT_FILE"
            echo "                    </div>" >> "$REPORT_FILE"
        fi
        
        if [[ "$iops_read" != "N/A" && -n "$iops_read" ]]; then
            echo "                    <div class=\"metric\">" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-label\">读取IOPS</div>" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-value\">$iops_read</div>" >> "$REPORT_FILE"
            echo "                    </div>" >> "$REPORT_FILE"
        fi
        
        # 只添加有效的写入指标
        if [[ "$bw_write" != "N/A" && -n "$bw_write" ]]; then
            echo "                    <div class=\"metric\">" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-label\">写入带宽</div>" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-value\">$bw_write</div>" >> "$REPORT_FILE"
            echo "                    </div>" >> "$REPORT_FILE"
        fi
        
        if [[ "$iops_write" != "N/A" && -n "$iops_write" ]]; then
            echo "                    <div class=\"metric\">" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-label\">写入IOPS</div>" >> "$REPORT_FILE"
            echo "                        <div class=\"metric-value\">$iops_write</div>" >> "$REPORT_FILE"
            echo "                    </div>" >> "$REPORT_FILE"
        fi
        
        cat >> "$REPORT_FILE" << 'EOF'
                </div>
EOF
        
        # 添加详细的测试摘要信息
        if [[ -n "$read_summary" || -n "$write_summary" ]]; then
            echo "                <div style=\"margin-top: 15px; padding: 15px; background: #f8f9fa; border-radius: 8px; font-size: 0.85em; color: #495057; font-family: 'Courier New', monospace;\">" >> "$REPORT_FILE"
            echo "                    <div style=\"font-weight: bold; margin-bottom: 8px; color: #667eea;\">📊 详细测试数据</div>" >> "$REPORT_FILE"
            
            if [[ -n "$read_summary" ]]; then
                # HTML转义处理
                read_summary_escaped=$(echo "$read_summary" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                echo "                    <div style=\"margin-bottom: 5px;\">$read_summary_escaped</div>" >> "$REPORT_FILE"
            fi
            
            if [[ -n "$write_summary" ]]; then
                write_summary_escaped=$(echo "$write_summary" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                echo "                    <div>$write_summary_escaped</div>" >> "$REPORT_FILE"
            fi
            
            echo "                </div>" >> "$REPORT_FILE"
        fi
        
        cat >> "$REPORT_FILE" << 'EOF'
            </div>
EOF
    done
    
    cat >> "$REPORT_FILE" << 'EOF'
        </div>
        
        <div class="footer">
            <div class="reference">
                <h3>📌 性能参考指标</h3>
                <ul>
                    <li>✅ 连续读写: 优秀 &gt;500MB/s, 良好 &gt;200MB/s</li>
                    <li>✅ 4K随机读: 优秀 &gt;50K IOPS, 良好 &gt;20K IOPS</li>
                    <li>✅ 4K随机写: 优秀 &gt;40K IOPS, 良好 &gt;15K IOPS</li>
                </ul>
            </div>
            <p style="margin-top: 20px; color: #6c757d;">
                报告生成时间: <strong id="reportTime"></strong>
            </p>
        </div>
    </div>
    
    <script>
        document.getElementById('reportTime').textContent = new Date().toLocaleString('zh-CN');
    </script>
</body>
</html>
EOF

    log_success "HTML报告生成成功: $REPORT_FILE"
}


# 运行fio测试
run_fio_test() {
    local test_name=$1
    local test_desc=$2
    shift 2
    local fio_params="$@"
    
    print_separator
    echo -e "${GREEN}【测试 $test_name】${NC} $test_desc"
    print_separator
    
    # 根据操作系统选择合适的ioengine
    local ioengine="libaio"
    if [[ "$OS" == "macos" ]]; then
        ioengine="posixaio"
        fio_params=$(echo "$fio_params" | sed 's/ioengine=libaio/ioengine=posixaio/')
    elif [[ "$OS" == "windows" ]]; then
        ioengine="windowsaio"
        fio_params=$(echo "$fio_params" | sed 's/ioengine=libaio/ioengine=windowsaio/')
    fi
    
    # 执行测试并捕获输出
    local output=$(eval "fio $fio_params" 2>&1)
    echo "$output"
    
    # 解析结果
    local result=$(parse_fio_output "$output" "$test_desc")
    TEST_RESULTS+=("$test_name|$test_desc|$result")
    
    echo ""
}

# 主函数
main() {
    print_separator
    echo -e "${GREEN}硬盘性能测试工具${NC}"
    echo -e "基于 fio (Flexible I/O Tester)"
    print_separator
    echo ""
    
    # 检测操作系统
    detect_os
    
    # 检查并安装fio
    if ! check_fio; then
        read -p "是否自动安装fio? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_fio
        else
            log_error "需要安装fio才能继续测试"
            exit 1
        fi
    fi
    
    # 设置测试文件路径
    TEST_FILE="${TEST_FILE:-./fio_test_file}"
    log_info "测试文件路径: $TEST_FILE"
    
    # 检查磁盘空间
    check_disk_space
    
    # 收集系统信息
    collect_system_info
    
    # 设置清理陷阱
    trap cleanup EXIT INT TERM
    
    echo ""
    log_info "开始硬盘性能测试..."
    echo ""
    sleep 2
    
    # ① 连续写入测试 (1G文件，最贴近大文件拷贝)
    run_fio_test "1" "连续写入测试 (1GB文件，模拟大文件拷贝)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=write \
         -ioengine=libaio -bs=1M -size=1G -numjobs=8 -runtime=30 \
         -group_reporting -name=Sequential_Write_Test"
    
    # ② 连续读取测试 (1G文件，最贴近大文件读取)
    run_fio_test "2" "连续读取测试 (1GB文件，模拟大文件读取)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=read \
         -ioengine=libaio -bs=1M -size=1G -numjobs=8 -runtime=30 \
         -group_reporting -name=Sequential_Read_Test"
    
    # ③ 4K随机写入 (SSD核心性能，影响小文件/AI/视频)
    run_fio_test "3" "4K随机写入测试 (SSD核心性能指标)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=randwrite \
         -ioengine=libaio -bs=4K -size=1G -numjobs=8 -runtime=30 \
         -group_reporting -name=4K_Random_Write"
    
    # ④ 4K随机读取 (开发/推理的核心指标)
    run_fio_test "4" "4K随机读取测试 (开发/推理核心指标)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=randread \
         -ioengine=libaio -bs=4K -size=1G -numjobs=8 -runtime=30 \
         -group_reporting -name=4K_Random_Read"
    
    # ⑤ 混合随机读写(4K)，模拟真实使用场景
    run_fio_test "5" "4K混合随机读写测试 (70%读/30%写，模拟真实场景)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=randrw \
         -rwmixread=70 -ioengine=libaio -bs=4K -size=1G -numjobs=8 \
         -runtime=30 -group_reporting -name=4K_Mixed_RW"
    
    # ⑥ 大文件混合读写(1M)，模拟视频流/大模型拷贝场景
    run_fio_test "6" "1MB混合读写测试 (70%读/30%写，模拟视频流/大模型)" \
        "-filename=$TEST_FILE -direct=1 -iodepth=64 -thread -rw=randrw \
         -rwmixread=70 -ioengine=libaio -bs=1M -size=1G -numjobs=8 \
         -runtime=30 -group_reporting -name=1M_Mixed_RW"
    
    print_separator
    log_success "所有测试完成！"
    print_separator
    
    # 生成HTML报告
    generate_html_report
    
    echo ""
    echo -e "${YELLOW}性能参考指标：${NC}"
    echo "  - 连续读写: 优秀 >500MB/s, 良好 >200MB/s"
    echo "  - 4K随机读: 优秀 >50K IOPS, 良好 >20K IOPS"
    echo "  - 4K随机写: 优秀 >40K IOPS, 良好 >15K IOPS"
    echo ""
    echo -e "${GREEN}HTML报告已生成: $REPORT_FILE${NC}"
    echo ""
}

# 执行主函数
main "$@"
