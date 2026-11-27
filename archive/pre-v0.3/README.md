# 归档 · Magic Core 0.1.2 与执行 DSL 0.2.2

本目录保存 54 词推导、Core、旧执行规范、样例、校验器、阶段 A/B 对照与测试。冻结版本为 [4cab4f9](https://github.com/fpddmw/magic-3D/tree/4cab4f937de55e3e8702985f4218ada18687c99c)。原项目的完整导航和跨目录链接可在该提交查阅。

从本目录运行以下命令可独立重放 19 条旧回归。现行工具从 v0.3 配方直接读取确定语义。

```sh
uv run --isolated --with-requirements tools/magic_compiler/requirements.txt python -m unittest discover -s tests -v
```
