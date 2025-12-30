# 硬盘性能测试工具

跨平台硬盘性能测试脚本，基于 FIO (Flexible I/O Tester)，支持 Linux、macOS 和 Windows 系统，自动生成专业的 HTML 测试报告。

## ✨ 功能特性

- 🚀 **跨平台支持**
  - Linux: Ubuntu/Debian, CentOS/RHEL/Fedora, Arch/Manjaro
  - macOS: 通过 Homebrew 自动安装
  - Windows: 支持 Windows 7/8/10/11 及 Server 版本

- 📊 **全面的测试套件**
  1. 连续写入测试 (1GB, 1MB块) - 模拟大文件拷贝
  2. 连续读取测试 (1GB, 1MB块) - 模拟大文件读取
  3. 4K随机写入测试 - SSD核心性能指标
  4. 4K随机读取测试 - 开发/推理核心指标
  5. 4K混合读写测试 (70%读/30%写) - 模拟真实使用场景
  6. 1MB混合读写测试 (70%读/30%写) - 模拟视频流/大模型场景

- 📈 **专业HTML报告**
  - 现代化响应式设计
  - 详细的系统信息
  - 可视化测试结果
  - 性能参考指标
  - 支持打印输出

- 🛡️ **安全特性**
  - 自动检测磁盘空间
  - 测试完成后自动清理
  - 错误处理和异常捕获

## 📦 安装依赖

### Linux (Ubuntu/Debian)
```bash
# 脚本会自动提示安装，或手动安装：
sudo apt-get update
sudo apt-get install -y fio
```

### Linux (CentOS/RHEL/Fedora)
```bash
# 使用 dnf
sudo dnf install -y fio

# 或使用 yum
sudo yum install -y fio
```

### macOS
```bash
# 使用 Homebrew
brew install fio
```

### Windows
```powershell
# 方法1: 使用 Chocolatey
choco install fio

# 方法2: 使用 Scoop
scoop install fio

# 方法3: 手动下载
# 访问 https://github.com/axboe/fio/releases
```

## 🚀 使用方法

### Linux / macOS

```bash
# 1. 添加执行权限
chmod +x disk_benchmark.sh

# 2. 运行测试（默认在当前目录）
./disk_benchmark.sh

# 3. 指定测试文件路径
TEST_FILE=/path/to/test/file ./disk_benchmark.sh
```

### Windows

```batch
# 方法1: 双击运行
disk_benchmark.bat

# 方法2: 命令行运行
disk_benchmark.bat

# 方法3: PowerShell运行
.\disk_benchmark.bat
```

## 📊 测试说明

### 测试参数
- **文件大小**: 1GB
- **块大小**: 1MB (连续测试), 4KB (随机测试)
- **队列深度**: 64
- **并发任务**: 8
- **测试时长**: 每项测试30秒
- **I/O引擎**: 
  - Linux: libaio
  - macOS: posixaio
  - Windows: windowsaio

### 性能参考指标

| 测试项目 | 优秀 | 良好 | 说明 |
|---------|------|------|------|
| 连续读写 | >500 MB/s | >200 MB/s | 大文件传输性能 |
| 4K随机读 | >50K IOPS | >20K IOPS | 系统响应速度 |
| 4K随机写 | >40K IOPS | >15K IOPS | 数据库/小文件性能 |

## 📄 报告示例

测试完成后会生成 HTML 报告，包含：

- **系统信息**: 主机名、操作系统、CPU、内存、磁盘容量
- **测试结果**: 每项测试的带宽和 IOPS 数据
- **性能评估**: 与参考指标对比
- **时间戳**: 测试开始和结束时间

报告文件名格式：`disk_benchmark_report_YYYYMMDD_HHMMSS.html`

## 🔧 高级选项

### 自定义测试文件位置
```bash
# Linux/macOS
TEST_FILE=/mnt/nvme/test ./disk_benchmark.sh

# Windows (在脚本中修改 TEST_FILE 变量)
set "TEST_FILE=D:\test_file"
```

### 修改测试参数
编辑脚本中的 `run_fio_test` 函数调用，可以调整：
- `-size`: 测试文件大小
- `-runtime`: 测试运行时间
- `-numjobs`: 并发任务数
- `-iodepth`: I/O队列深度
- `-bs`: 块大小

## ⚠️ 注意事项

1. **磁盘空间**: 至少需要 2GB 可用空间
2. **权限要求**: 
   - Linux/macOS: 可能需要 sudo 权限安装 fio
   - Windows: 建议以管理员身份运行
3. **测试影响**: 测试期间会产生大量磁盘 I/O，建议：
   - 关闭其他程序
   - 不要在系统盘上测试（Windows）
   - 避免在生产环境运行
4. **SSD 寿命**: 频繁测试会消耗 SSD 写入寿命，建议适度测试

## 🐛 故障排除

### fio 未找到
```bash
# Linux: 检查 PATH
which fio

# Windows: 检查环境变量
where fio
```

### 权限错误
```bash
# Linux/macOS: 使用 sudo
sudo ./disk_benchmark.sh

# Windows: 右键 -> 以管理员身份运行
```

### 磁盘空间不足
```bash
# 清理磁盘空间或指定其他位置
TEST_FILE=/path/to/larger/disk/test ./disk_benchmark.sh
```

## 📝 输出示例

```
================================================================
              硬盘性能测试工具
           基于 fio (Flexible I/O Tester)
================================================================

[INFO] 检测到操作系统: ubuntu
[SUCCESS] fio已安装 (fio-3.28)
[INFO] 测试文件路径: ./fio_test_file
[SUCCESS] 磁盘空间检查通过 (可用: 50GB)

[INFO] 开始硬盘性能测试...

================================================================
【测试 1】 连续写入测试 (1GB文件，模拟大文件拷贝)
================================================================
...

================================================================
[SUCCESS] 所有测试完成！
================================================================

性能参考指标：
  - 连续读写: 优秀 >500MB/s, 良好 >200MB/s
  - 4K随机读: 优秀 >50K IOPS, 良好 >20K IOPS
  - 4K随机写: 优秀 >40K IOPS, 良好 >15K IOPS

HTML报告已生成: disk_benchmark_report_20250101_120000.html
```

## 📜 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系方式

如有问题或建议，请通过 Issue 反馈。
