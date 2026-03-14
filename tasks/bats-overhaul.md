# Spec: bats-overhaul
Status: done

## 目标
修复 ClawKing 所有 15 个 bats 测试失败 + 添加 CI

## 改什么
1. chmod +x 6 个脚本文件
2. 修 JSON5 模板缺失逗号
3. 修 release-dashboard stub node 的 shell 参数展开兼容性
4. 更新 setup.sh 测试匹配当前代码
5. 添加 CI workflow (bats + shellcheck)

## 怎么验
- `bats tests/` 108/108 全绿
- CI workflow 包含 bats 和 shellcheck
