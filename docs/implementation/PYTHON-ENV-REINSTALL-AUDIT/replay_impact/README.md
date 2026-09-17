# Python environment reinstall replay impact audit

审计日期：2026-09-15（Asia/Shanghai）  
仓库：`D:\006-Programing\LMC\FusionConceptAI`  
基线：`4b69f55f7f80240147a65a22809dc1207824dde2`  
工作树：审计开始时已有 3547 个 dirty/untracked 状态条目；本审计只在本目录新增文件，保留其余脏工作和历史 `runs/`。

## 结论

输出目录下可识别出五个项目环境目录，但第五个 `.conda-cql3d-build` 没有 `python.exe`，不能被称作 Python 解释器环境。项目实际 Python 角色为：DESC `.venv-desc`、FreeGS `.venv-freegs`、VMEX `.conda-vmex`、Pleiades `.conda-pleiades-public`；CQL3D 是独立的 Fortran/NetCDF 构建环境。

本次现场检查没有重放 Julia、DESC、FreeGS、VMEX、Pleiades 或 CQL3D，也没有安装、更新或删除任何依赖。历史收据仍然是对历史字节和历史执行的有效记录；环境重装后，不能据此直接声称“当前 checkout 可复现”。当前可以低成本复核的是文档计划检查、JSON 解析和 CLI 帮助。任何新的 provider、mesh、物理执行或 UP2-01 入口工作都应先完成对应环境的 fresh replay receipt。

## 当前环境身份

| 目录 | 当前解释器/工具 | 关键现场版本 | 现场完整性与可复现风险 |
|---|---|---|---|
| `D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-desc` | CPython 3.13.5；`desc-opt` 0.17.3 | JAX/JAXLIB 0.9.2/0.9.2，NumPy 2.4.2，SciPy 1.18.0，h5py 3.16.0 | `pip check` exit 1：`desc-opt 0.17.3 requires jax-finufft, which is not installed.` 固定边界路线在现有文档中声明不依赖 NUFFT，但仍须在新 replay receipt 中明确该缺口是否是声明内的允许缺口。解释器 SHA256 当前为 `cec2fab4b3258900cc330346de8c664e57fa04227406920a6edb06f0efeeebb1`；pip freeze 文本摘要为 `96268f3d030caa747be778d243739f4dd2c8dbe1ecb0452325485e62b8530de9`。 |
| `D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs` | CPython 3.13.5；FreeGS 0.8.2，freeqdsk 0.5.2 | 可见 NumPy 2.1.3，SciPy 1.15.3，h5py 3.12.1 | `pyvenv.cfg` 设置 `include-system-site-packages = true`；因此 base Anaconda 重装会改变该环境可见的科学包。`pip check` exit 0；解释器 SHA256 与 DESC 相同（`cec2fab4...feebb1`），pip freeze 文本摘要为 `9d76970333705b1e85d0356823191e740f8ea3422ffdcb6d057a38ad95c274be`。requirements 只锁 FreeGS/freeqdsk，未锁继承的 NumPy/SciPy/h5py。 |
| `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-vmex` | CPython 3.12.13；VMEX 0.7.0 | JAX/JAXLIB 0.11.1/0.11.1，NumPy 2.5.2，SciPy 1.18.1，netCDF4 1.7.4 | conda history 只记录 `python=3.12.13 pip`，不是完整可离线重建锁。`vmex` 的 `direct_url.json` 指向仓库外 `C:\Users\Newman\Documents\Codex\2026-09-15\c\work\vmex-source`；该目录当前存在 513 个文件，现场树摘要 `9bc7c2926831a6b7d768c4c0eb5cb6ab13dc9a880cf65afe4e50361712ee1e5c`，但历史收据没有绑定这个树摘要。解释器 SHA256 `0937d5ac6dd108c73b0fad5d25c8da700038673f212242dbae4901fce8573de6`；conda-meta 聚合摘要 `deb4cd4caef3e7a23ea89060599c99afc2bba49818ee9a2250f721e550f3595e`。 |
| `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-pleiades-public` | CPython 3.9.25；Pleiades 0.2.0.dev0 | NumPy 1.26.4，SciPy 1.13.1 | conda history 只记录 `python=3.9.25 pip=26.0.1`。`pleiades` 的 `direct_url.json` 指向仓库外临时目录 `C:\Users\Newman\AppData\Local\Temp\fusion-ai-pleiades-0161abb3`；该目录当前存在 86 个文件，现场树摘要 `17fe800f8b1bbadb7925353fb70d4d57625aa4e00d198bd6e412ef7a6c71f7cb`，历史收据没有绑定这个树摘要。解释器 SHA256 `3c573165deb67c2af3ab3495044a04bfb0d895edb2611ebe3e9cb77a6629715b`；conda-meta 聚合摘要 `a674d10d76ca3e5fd228747217418f02cf7b0a851eb5ea0d5c596a102568181b`。 |
| `D:\006-Programing\LMC\outputs\fusion_concept_ai\.conda-cql3d-build` | 没有 Python；Fortran/NetCDF 构建工具链 | `m2w64-gcc-fortran` 5.3.0，`netcdf-fortran` 4.6.4，`libnetcdf` 4.10.0，HDF5 2.2.0 | conda history 记录 conda-forge 构建命令；这是构建后端身份，不能用 Python smoke 代替。conda-meta 聚合摘要 `10b19e46b83cb84322159ccaf70183fd14b8bcfdb67e8ac105e054159f2a6aff`。 |

`conda env list` 还显示 base、`newquant` 和 `test`。它们不是上述四个 provider Python 目录；base `D:\Users\Newman\anaconda3\python.exe` 是历史 contract/manifest 检查常用的解释器，也是两个 venv 的创建来源。base 重装会影响所有使用裸 `python` 的历史命令，并会直接影响 `.venv-freegs` 的继承包集合。

## 解释器绑定和历史收据

当前源码和实现文档中可定位到这些绑定：

- `src/RuntimeV4/FreeGSAxisymmetricExecution.jl` 使用固定绝对 FreeGS 解释器路径；移动或重装 `.venv-freegs` 后必须重新生成当前 receipt。
- `src/RuntimeV4/DESCRequestProviderExecutionV4.jl` 支持 `DESC_PYTHON`、仓库 `.venv-desc`、外层 outputs `.venv-desc` 和 PATH fallback，但历史 DESC 收据固定记录 outputs 下的绝对路径及解释器 SHA。
- outputs 中的历史 adapter/test 还按 `.venv-desc`、`.venv-freegs`、`.conda-vmex`、`.conda-pleiades-public` 相对路径拼接；它们是旧 portfolio/历史材料，不能把路径存在解释为当前 provider 已验证。
- CQL3D 相关构建引用 `.conda-cql3d-build` 的编译/NetCDF 工具链，不应伪造 Python 版本字段。

仍可作为历史有效记录的材料包括：

- `docs/implementation/n2_source_desc_replay_v4.md`：记录了旧 `.venv-desc` 的 Python、请求文件 SHA、adapter/HDF5 SHA、测试和非收敛 screen-only 结论。
- `docs/reports/revised_coupled_execution_v4_20260912_evidence.json`：记录了旧 DESC sampling/physics 命令、Python 路径及 `cec2fab4...feebb1` 解释器 SHA；该文件也明确物理 solver exit 3、whole-device deferred。
- `docs/reports/spatial_coupled_execution_v4_20260913_evidence.json` 与 `docs/reports/spatial_coupled_execution_v4_20260913.md`：其 Python 角色主要是 base 解释器运行 manifest checker；它们的 stage/exit/artifact 语义仍是历史记录，不自动成为当前复放。
- UP2/AD focused receipts 中以 `D:\Users\Newman\anaconda3\python.exe` 运行的 JSON parse、plan validator 等 contract-only 检查，仍是当时 base Python 的历史软件证据。它们不提供 DESC/FreeGS/VMEX/Pleiades 物理证据。

重装后必须重新取证才能声称当前可复现的范围：DESC source replay/provider execution、FreeGS axisymmetric screen、VMEX equilibrium/qualification、Pleiades WHAM/NBI 相关执行，以及任何依赖 CQL3D 构建产物的工作。仅有同名环境目录、相同包名、CLI `--help` 成功或历史 Python executable SHA 不足以关闭这些门。

## 对当前主线的影响

计划中的 UP1/UP2 contract-only schema、identity、authority 和 JSON/plan 静态检查不需要先启动物理后端；它们可以继续，但命令应明确使用哪个 Python，并把结果标成软件/合同范围。UP2-01 及其 provider/mesh/组合执行依赖前述环境门，不能从已有历史 DESC/FreeGS 收据直接晋升。

本审计发现的实际阻塞/风险为：

1. `.venv-desc` 的依赖闭合目前不完整（缺 `jax-finufft`）；需要由主线决定是安装并锁定它，还是在固定边界 profile 中把缺口声明为预期的 `terminal_deferred`，再以新 receipt 证明 fixed-boundary 路径仍可运行。
2. `.venv-freegs` 继承 base site packages，base Python/NumPy/SciPy/h5py 变更会改变 FreeGS 数值环境；应改为隔离 venv 或至少冻结并复核完整可见包集合后再做 provider replay。此处只提出复核门，不在本审计修改源码或环境。
3. VMEX 和 Pleiades 的安装源在仓库外；应把源树内容摘要、安装命令、依赖包完整集合和 provider module hash 纳入新 receipt，否则只能复现“当前机器上的临时目录”。
4. 没有发现针对这五个目录的仓库内完整 Python lock/export（requirements 文件只覆盖 DESC、FreeGS 或 Pleiades 的部分 pip 层；VMEX/Pleiades conda history 不是完整 lock）。

## 最小可执行复核门

按重计算串行规则，下一次环境复核应按以下顺序执行并落盘退出码、解释器 SHA、包/源树摘要和 artifact SHA：

1. 先在 fresh process 中运行 `validate_plan.py`、JSON/manifest checker；这只能确认软件合同和收据检查器，不产生物理信用。
2. 对 `.venv-desc` 先做 dependency/profile admission，再重放冻结 request 的 construct/reimport；通过后才重放 bounded DESC solver。保留 solver convergence 与 process exit 的区别。
3. 对 `.venv-freegs` 运行当前 typed bridge 的 candidate-bound screen，并记录完整 `environment manifest`；确认 NumPy/SciPy/h5py 来源不再随 base site-packages 隐式漂移。
4. 只有在相应 provider 工作单进入执行阶段时，才依次对 VMEX、Pleiades 和 CQL3D toolchain 做版本/来源/最小候选执行复核；CQL3D 使用构建工具链收据，不写 Python 版本。
5. 将 fresh replay 作为 UP2-01/provider 工作单的前置证据，保留 `screen_only`、`terminal_deferred`、`numerical_fail`、`physical_fail` 和 `unknown` 的原始分类；不得因环境 smoke 通过而关闭 R01–R10 或父目标。

本报告没有修改任何源码、历史 `runs/`、环境目录或公共任务清单。
