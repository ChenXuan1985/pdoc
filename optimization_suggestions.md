# 评测工作流优化建议

## 📋 基于本次评测的实践经验

本次评测完成了对三个模型（豆包、GLM、Kimi）在 DevOps/工程化任务上的完整评测，积累了宝贵的实践经验。基于 docs 目录的标准化文档和本次实际操作，提出以下优化建议。

---

## 一、流程优化建议

### 1.1 工作目录管理优化

**现状问题**：
- 文档中使用 `.worktrees/` 目录
- 本次评测使用 `.worktree/` 目录
- 命名不统一可能导致混淆

**优化建议**：
```markdown
### 统一工作目录命名
- 标准化为：`.worktree/`（单数形式）
- 目录结构：`.worktree/{model_name}/`
- 示例：`.worktree/glm/`, `.worktree/doubao/`, `.worktree/kimi/`
```

**追加内容**：
```bash
# 工作目录快速创建脚本
python scripts/create_worktree.py --models glm,doubao,kimi --base-repo pdoc
```

### 1.2 Git 分支命名规范

**现状问题**：
- 文档建议使用 `eval/{model}-{task}` 格式
- 本次评测使用了 `{model}-devops-solution` 格式

**优化建议**：
```markdown
### 统一分支命名规范
- 格式：`eval/{model}-{task-name}`
- 示例：
  - `eval/glm-devops` - GLM 的 DevOps 方案
  - `eval/doubao-devops` - 豆包的 DevOps 方案
  - `eval/kimi-devops` - Kimi 的 DevOps 方案
- 好处：清晰标识评测轮次和任务类型
```

### 1.3 推送流程优化

**本次成功经验**：
```bash
# 1. 初始化 Git 仓库
git init
git remote add origin <repo-url>

# 2. 创建主分支
git add .
git commit -m "Initial commit"
git branch -M main
git push -u origin main

# 3. 为每个模型创建分支
git checkout -b eval/glm-devops
git push -u origin eval/glm-devops

git checkout -b eval/doubao-devops
git push -u origin eval/doubao-devops

git checkout -b eval/kimi-devops
git push -u origin eval/kimi-devops
```

**优化建议**：
```markdown
### 自动化推送脚本
创建 `scripts/push_solutions.sh`：

```bash
#!/bin/bash
# 一键推送所有模型方案到 GitHub

MODELS=("glm" "doubao" "kimi")
TASK_NAME="devops"
REMOTE="origin"

# 推送主分支
git push -u origin main

# 推送各模型分支
for model in "${MODELS[@]}"; do
    branch_name="eval/${model}-${TASK_NAME}"
    git checkout "$branch_name"
    git push -u "$REMOTE" "$branch_name"
    echo "✓ Pushed $branch_name"
done

echo "✅ All solutions pushed successfully!"
```
```

---

## 二、评测报告模板优化

### 2.1 评分格式标准化

**现状问题**：
- 文档中使用小数评分（4.5 分、4.0 分）
- 本次评测后期改为整数评分（4 分、5 分）

**优化建议**：
```markdown
### 统一使用整数评分（1-5 分）

**评分标准**：
- **5 分**：完美 - 几乎无改进空间
- **4 分**：优秀 - 整体体验良好
- **3 分**：良好 - 存在轻微不足
- **2 分**：一般 - 需要人工干预
- **1 分**：较差 - 无法完成任务

**报告模板更新**：
将 `4.5 分` 改为 `4 分` 或 `5 分`
将 `3.83/5` 改为 `4/5`
```

### 2.2 修复成本评估优化

**现状问题**：
- 文档中修复成本评级不统一
- 本次评测使用了"低/中/高"和具体工时

**优化建议**：
```markdown
### 修复成本评估模板

| 修复项目 | 成本等级 | 预估工作量 | 说明 |
|---------|---------|-----------|------|
| 文档完善 | 低 | 1-2 小时 | 补充部署操作手册 |
| 监控告警 | 中 | 3-4 小时 | 增加监控机制 |
| 回滚机制 | 中 | 2-3 小时 | 完善回滚流程 |

**成本等级说明**：
- **低**：1-4 小时，模型可自行完成
- **中**：4-8 小时，需要少量引导
- **高**：8 小时以上，需要大量指导

**基于实际表现的重估机制**：
第一轮评估后，根据第二轮实际改进情况重新评估修复成本。
```

### 2.3 多轮评测对比模板

**新增模板**：
```markdown
## 多轮评测对比分析

### 评分提升对比
| 维度 | 第 1 轮 | 第 2 轮 | 提升幅度 |
|------|------|------|----------|
| 用户体验 | 4 分 | 5 分 | +1 分 |
| 规划执行 | 4 分 | 5 分 | +1 分 |
| 理解能力 | 4 分 | 5 分 | +1 分 |
| 指令遵循 | 4 分 | 5 分 | +1 分 |
| 工程完备度 | 3 分 | 5 分 | +2 分 |
| 长程任务能力 | 3 分 | 5 分 | +2 分 |

### 改进效果评估
**已解决的问题**：
- ✅ 文档完善度：从低提升到优秀
- ✅ 监控告警：从缺失到功能完整
- ✅ 回滚机制：从不完善到功能完善

**仍需优化的方面**：
- ⚠️ 性能优化：可进一步提升构建速度
- ⚠️ 高级特性：可添加智能变更检测

### 学习能力评级
- **G (Good)**：显著提升（+2 分或以上）
- **S (Same)**：保持稳定（±1 分）
- **B (Bad)**：提升有限（无提升或下降）
```

---

## 三、工具脚本优化

### 3.1 工作目录管理脚本

**新增脚本**：`scripts/worktree_manager.py`

```python
#!/usr/bin/env python3
"""
Worktree Manager - 自动化管理工作目录
"""

import argparse
import subprocess
from pathlib import Path

def create_worktree(base_repo: str, models: list, task_name: str):
    """为多个模型创建工作目录"""
    for model in models:
        worktree_path = Path(f".worktree/{model}")
        branch_name = f"eval/{model}-{task_name}"
        
        # 创建分支
        subprocess.run(["git", "checkout", "-b", branch_name], 
                      cwd=base_repo, check=True)
        
        # 创建工作目录
        subprocess.run(["git", "worktree", "add", str(worktree_path), 
                      branch_name], cwd=base_repo, check=True)
        
        print(f"✓ Created worktree for {model}")

def main():
    parser = argparse.ArgumentParser(description="Worktree Manager")
    parser.add_argument("--base-repo", required=True, help="基础仓库路径")
    parser.add_argument("--models", required=True, help="模型列表，逗号分隔")
    parser.add_argument("--task-name", required=True, help="任务名称")
    
    args = parser.parse_args()
    models = args.models.split(",")
    
    create_worktree(args.base_repo, models, args.task_name)

if __name__ == "__main__":
    main()
```

### 3.2 报告生成脚本

**新增脚本**：`scripts/generate_report.py`

```python
#!/usr/bin/env python3
"""
评测报告生成器 - 基于评测数据自动生成报告
"""

import json
from pathlib import Path
from jinja2 import Template

def load_evaluation_data(model: str, eval_dir: str):
    """加载评测数据"""
    with open(f"{eval_dir}/results/{model}.json", "r", encoding="utf-8") as f:
        return json.load(f)

def generate_report(models: list, eval_dir: str, output_path: str):
    """生成评测报告"""
    template = Template("""
# {{ title }}

## 基本信息
- **评测时间**: {{ date }}
- **任务类型**: {{ task_type }}

## 评分结果
{% for model in models %}
### {{ model.name }}
| 维度 | 得分 |
|------|------|
{% for dim, data in model.scores.items() %}
| {{ dim }} | {{ data.score }}分 |
{% endfor %}

**综合评分**: {{ model.total_score }}/5

{% endfor %}
    """)
    
    # 渲染报告
    report = template.render(
        title="评测报告",
        date="2026-03-23",
        task_type="DevOps/工程化",
        models=models
    )
    
    # 保存报告
    Path(output_path).write_text(report, encoding="utf-8")
    print(f"✓ Generated report: {output_path}")

if __name__ == "__main__":
    # 使用示例
    models = ["glm", "doubao", "kimi"]
    generate_report(models, "evaluations/2026-03-23_devops", "report.md")
```

### 3.3 快速检查脚本优化

**现状**：文档中有 `quick_check.py` 但功能较简单

**优化建议**：
```python
#!/usr/bin/env python3
"""
Quick Check Plus - 增强版违规检测
支持 DevOps/CI/CD 任务检查
"""

import re
from pathlib import Path

def check_devops_tasks(worktree_path: str, model: str):
    """检查 DevOps 任务的常见违规"""
    issues = []
    
    # 检查工作流文件
    workflow_files = list(Path(worktree_path).glob(".github/workflows/*.yml"))
    
    for wf in workflow_files:
        content = wf.read_text(encoding="utf-8")
        
        # 检查是否包含必要的安全措施
        if "permissions:" not in content:
            issues.append(f"⚠️ {wf.name}: 缺少权限配置")
        
        # 检查是否有缓存优化
        if "cache:" not in content and "actions/cache" not in content:
            issues.append(f"⚠️ {wf.name}: 建议添加缓存优化")
    
    # 检查文档完整性
    doc_files = ["DEPLOYMENT.md", "OPERATIONS.md", "TROUBLESHOOTING.md"]
    for doc in doc_files:
        if not Path(worktree_path, ".github", doc).exists():
            issues.append(f"ℹ️ 缺少文档：{doc}")
    
    return issues

def main():
    models = ["glm", "doubao", "kimi"]
    for model in models:
        print(f"\n=== {model} ===")
        issues = check_devops_tasks(f".worktree/{model}", model)
        
        if issues:
            for issue in issues:
                print(issue)
        else:
            print("✓ 所有检查通过")

if __name__ == "__main__":
    main()
```

---

## 四、评测流程优化

### 4.1 并行操作优化

**文档建议**：三个窗口同时投喂 prompt

**本次经验**：
- ✅ 可以同时启动多个模型
- ✅ 快速检查可以批量执行
- ⚠️ 推送代码需要逐个分支操作

**优化建议**：
```markdown
### 并行操作清单

**可以并行的操作**：
- ✅ 同时向三个模型投喂 prompt
- ✅ 同时观察三个模型的答题过程
- ✅ 批量运行快速检查脚本
- ✅ 同时审查多个模型的代码

**需要串行的操作**：
- ❌ Git 分支切换和推送
- ❌ 评分和报告生成
- ❌ GitHub PR 创建

### 时间优化建议
| 阶段 | 原预计时间 | 优化后时间 | 优化方法 |
|------|-----------|-----------|----------|
| 准备阶段 | 5 分钟 | 3 分钟 | 使用自动化脚本 |
| 模型答题 | 10-20 分钟 | 10 分钟 | 并行投喂 prompt |
| 快速检查 | 1 分钟 | 1 分钟 | 批量执行脚本 |
| 引导修正 | 5-10 分钟/轮 | 5 分钟/轮 | 使用话术模板 |
| 人工审查 | 5 分钟/模型 | 3 分钟/模型 | 并行审查 |
| 评分 | 10 分钟/模型 | 5 分钟/模型 | 使用评分模板 |
| 推送代码 | 5 分钟 | 3 分钟 | 使用推送脚本 |
| 生成报告 | 15 分钟 | 5 分钟 | 使用生成脚本 |
| **总计** | **60-90 分钟** | **40-50 分钟** | **效率提升 50%** |
```

### 4.2 引导话术库优化

**现状**：文档中有分级引导话术

**本次经验**：
- GLM 第二轮使用了具体的改进要求
- 豆包需要重新跑第一轮
- Kimi 表现稳定

**优化建议**：
```markdown
### 引导话术模板库

#### DevOps 任务专用话术

**Level 1 - 详细指导**：
```
请为 DevOps 流程添加以下改进：

1. 监控告警机制
   - 添加部署状态监控
   - 支持 Slack/Discord 通知
   - 包含异常告警功能

2. 文档完善
   - 创建 DEPLOYMENT.md 说明架构
   - 创建 OPERATIONS.md 操作手册
   - 创建 TROUBLESHOOTING.md 故障排查

3. 回滚机制
   - 实现版本回滚脚本
   - 支持按 commit SHA 回滚
   - 包含 dry-run 模式
```

**Level 2 - 提示启发**：
```
请重点关注以下方面的改进：
- 监控告警机制
- 文档系统完善
- 回滚流程优化

优化后应达到企业级 DevOps 标准。
```

**Level 3 - 问题导向**：
```
当前的 DevOps 流程还有哪些可以改进的地方？
请从监控、文档、回滚三个维度进行优化。
```
```

---

## 五、GitHub 仓库结构优化

### 5.1 推荐仓库结构

**本次实践**：
```
pdoc/
├── .worktree/              # 工作目录
│   ├── glm/               # GLM 方案
│   ├── doubao/            # 豆包方案
│   └── kimi/              # Kimi 方案
├── 评测报告/               # 评测文档
└── README.md
```

**优化建议**：
```
pdoc/
├── solutions/              # 模型解决方案
│   ├── glm/               # GLM 完整方案
│   ├── doubao/            # 豆包方案
│   └── kimi/              # Kimi 方案
├── evaluations/           # 评测报告
│   ├── 2026-03-23_devops/
│   │   ├── prompt.md
│   │   ├── config.json
│   │   └── results/
│   │       ├── glm_评估报告.md
│   │       ├── doubao_评估报告.md
│   │       └── kimi_评估报告.md
│   └── 横向对比报告.md
├── scripts/               # 工具脚本
│   ├── worktree_manager.py
│   ├── generate_report.py
│   └── push_solutions.sh
├── docs/                  # 文档
│   ├── evaluation_workflow_guide.md
│   └── optimization_suggestions.md
└── README.md
```

### 5.2 分支管理策略

**优化建议**：
```markdown
### 分支命名规范

**主分支**：
- `main` - 主分支，包含所有评测报告

**评测分支**：
- `eval/glm-devops` - GLM 的 DevOps 方案
- `eval/doubao-devops` - 豆包的 DevOps 方案
- `eval/kimi-devops` - Kimi 的 DevOps 方案

**功能分支**：
- `feature/worktree-manager` - 工作目录管理脚本
- `feature/report-generator` - 报告生成脚本

### 推送策略
1. 每个模型的方案推送到独立分支
2. 主分支包含所有评测报告
3. 工具脚本推送到 feature 分支
4. 通过 PR 合并到 main 分支
```

---

## 六、评分标准优化

### 6.1 六维度评分标准细化

**现状**：文档中有六维度但定义较笼统

**优化建议**：
```markdown
### 六维度评分标准（DevOps 任务专用）

#### 1. 用户体验（1-5 分）
- **5 分**：配置简洁，文档完善，易于理解和部署
- **4 分**：配置合理，有基础文档，易于上手
- **3 分**：配置复杂，文档不足，需要一定学习成本
- **2 分**：配置混乱，缺少文档，需要大量指导
- **1 分**：无法正常运行

#### 2. 规划&执行反馈（1-5 分）
- **5 分**：任务规划完整，执行流畅，反馈清晰
- **4 分**：任务规划合理，执行顺利，有基本反馈
- **3 分**：任务规划一般，执行有波折，反馈不够清晰
- **2 分**：任务规划不足，执行困难，缺少反馈
- **1 分**：无明确规划，执行失败

#### 3. 理解/推理能力（1-5 分）
- **5 分**：准确理解需求，架构设计优秀，推理严谨
- **4 分**：理解需求正确，架构设计合理
- **3 分**：基本理解需求，架构设计一般
- **2 分**：理解有偏差，架构设计不合理
- **1 分**：完全误解需求

#### 4. 复杂指令遵循（1-5 分）
- **5 分**：完美遵循所有约束条件
- **4 分**：较好遵循主要约束，轻微偏差
- **3 分**：遵循基本约束，存在明显偏差
- **2 分**：多次违反约束，需要反复纠正
- **1 分**：完全无法遵循约束

#### 5. 工程完备度（1-5 分）
- **5 分**：功能完整，文档完善，达到生产标准
- **4 分**：功能完整，有基础文档
- **3 分**：功能基本完整，文档不足
- **2 分**：功能不完整，缺少文档
- **1 分**：功能严重缺失

#### 6. 长程任务能力（1-5 分）
- **5 分**：完成完整流程，有监控、回滚等高级功能
- **4 分**：完成主要流程，有基础保障
- **3 分**：完成基本流程，缺少保障机制
- **2 分**：流程不完整，需要人工干预
- **1 分**：无法完成流程
```

### 6.2 学习能力评估

**新增评估维度**：
```markdown
### 学习能力评级（第二轮评测专用）

**评级标准**：
- **G (Good)**：显著提升，总分提升 2 分或以上
- **S (Same)**：保持稳定，总分提升 1 分或无变化
- **B (Bad)**：提升有限，总分无提升或下降

**评估维度**：
1. 指令理解能力 - 是否准确理解改进要求
2. 执行效率 - 改进方案的质量和速度
3. 创新性 - 是否提出有价值的改进建议
4. 文档完善 - 是否补充必要的文档
5. 功能完整性 - 改进后的功能完备程度

**示例**：
GLM 第二轮：
- 第 1 轮综合评分：3.83/5 → 第 2 轮：5/5
- 提升幅度：+1.17 分（约 2 分）
- 学习能力评级：**G (Good)** - 显著提升
```

---

## 七、自动化脚本清单

### 7.1 推荐开发的自动化脚本

**优先级排序**：

#### P0 - 必需脚本
1. **`worktree_manager.py`** - 工作目录管理
   - 创建工作目录
   - 删除工作目录
   - 同步代码

2. **`push_solutions.sh`** - 一键推送脚本
   - 推送所有模型方案
   - 自动创建分支
   - 错误处理和重试

3. **`generate_report.py`** - 报告生成器
   - 基于 JSON 数据生成报告
   - 支持 Markdown 格式
   - 包含对比分析

#### P1 - 重要脚本
4. **`quick_check.py`** - 快速检查（增强版）
   - 支持多种任务类型
   - 更详细的违规报告
   - 自动修复建议

5. **`compare_models.py`** - 模型对比工具
   - 自动生成对比表格
   - GSB 评级计算
   - 可视化图表生成

#### P2 - 辅助脚本
6. **`backup_worktrees.sh`** - 工作目录备份
7. **`sync_evaluations.py`** - 评测数据同步
8. **`cleanup_branches.sh`** - 分支清理工具

### 7.2 脚本使用示例

```bash
# 1. 创建工作目录
python scripts/worktree_manager.py create \
  --base-repo pdoc \
  --models glm,doubao,kimi \
  --task-name devops

# 2. 快速检查
python scripts/quick_check.py \
  --worktree-base .worktree \
  --models glm,doubao,kimi \
  --task-type devops

# 3. 生成报告
python scripts/generate_report.py \
  --eval-dir evaluations/2026-03-23_devops \
  --output report.md

# 4. 推送方案
bash scripts/push_solutions.sh \
  --remote origin \
  --task-name devops
```

---

## 八、经验总结与最佳实践

### 8.1 本次评测的关键发现

**成功经验**：
1. ✅ **整数评分更简洁** - 避免小数点带来的精度假象
2. ✅ **修复成本动态评估** - 基于实际表现重新评估
3. ✅ **学习能力重要性** - GLM 的第二轮改进展现了强大的学习能力
4. ✅ **并行操作提效** - 同时投喂 prompt 节省时间
5. ✅ **Git 分支管理** - 独立分支便于对比和审查

**教训总结**：
1. ⚠️ **网络问题** - GitHub 连接不稳定，需要重试机制
2. ⚠️ **权限问题** - 写入文件前确认权限
3. ⚠️ **上下文管理** - 长对话需要定期总结
4. ⚠️ **分支命名** - 需要统一命名规范

### 8.2 最佳实践清单

**评测前准备**：
- [ ] 确认 Git 仓库和远程连接正常
- [ ] 准备好 prompt 和评分模板
- [ ] 创建工作目录和分支结构
- [ ] 配置好自动化工具

**评测中操作**：
- [ ] 并行投喂 prompt，节省时间
- [ ] 及时记录 Session ID 和关键信息
- [ ] 使用快速检查脚本批量检测
- [ ] 边审查边记录，提高效率

**评测后处理**：
- [ ] 使用脚本一键推送所有方案
- [ ] 生成标准化评测报告
- [ ] 创建对比分析报告
- [ ] 归档所有评测数据

---

## 九、下一步行动计划

### 短期目标（1 周内）
- [ ] 开发 `worktree_manager.py` 脚本
- [ ] 开发 `push_solutions.sh` 脚本
- [ ] 统一评分标准和报告模板
- [ ] 整理本次评测的所有文档

### 中期目标（1 个月内）
- [ ] 开发 `generate_report.py` 报告生成器
- [ ] 增强 `quick_check.py` 功能
- [ ] 建立引导话术模板库
- [ ] 创建评测案例库

### 长期目标（3 个月内）
- [ ] 完整的自动化评测工具链
- [ ] 可视化的对比分析面板
- [ ] 跨模型能力数据库
- [ ] 标准化的评测流程文档

---

## 附录：快速命令参考

```bash
# 创建工作目录
python scripts/worktree_manager.py create \
  --base-repo pdoc \
  --models glm,doubao,kimi \
  --task-name devops

# 快速检查
python scripts/quick_check.py \
  --worktree-base .worktree \
  --models glm,doubao,kimi

# 生成报告
python scripts/generate_report.py \
  --eval-dir evaluations/2026-03-23_devops \
  --output report.md

# 推送方案
bash scripts/push_solutions.sh \
  --remote origin \
  --task-name devops

# 查看分支
git branch -r | grep eval

# 恢复历史提交
git reflog --all | grep eval
```

---

*文档版本：v1.0*  
*更新时间：2026-03-23*  
*基于本次 DevOps 评测实践经验总结*
