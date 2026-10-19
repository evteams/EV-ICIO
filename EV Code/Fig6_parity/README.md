# Figure 6: independent main-text and SI packages / 图6正文与SI独立复现包

正文和SI已完全拆分。每个子文件夹都有自己的RStudio项目、完整R计算脚本、实际input文件、output结果和README；不共享输入、不互相调用，也不依赖另一份结果。可以分别移动、上传和运行。

| 对应结果 | 独立文件夹 | RStudio项目 | 计算脚本 | 必需输入 | 结果文件 |
| --- | --- | --- | --- | --- | --- |
| 正文，第一张图 | [main_text](main_text/) | [Fig6_main_text.Rproj](main_text/Fig6_main_text.Rproj) | [Fig6_parity.R](main_text/Fig6_parity.R) | 7份 | 5份 |
| SI，第二张图 | [SI](SI/) | [Fig6_SI.Rproj](SI/Fig6_SI.Rproj) | [Fig6_SI.R](SI/Fig6_SI.R) | 9份 | 6份 |

正文情景：BAU、Solar、Wind、MEG、ACES、ACES + MEG。

SI情景：BAU、Battery、Steel、ACES、ACES + Battery、ACES + Steel、ACES + Battery + Steel。

各自BAU结果同时用于插图。两份计算都使用no recycling、带符号parity和生产当年的固定使用排放。只保留数据处理和MC，不含制图或核对代码。具体公式、抽样、输入单位和输出字段见各自README。

2026-10-19修正：年行驶里程统一为CHN 10220、DEU 12320、JPN 8060、KOR 11936、MEX 12832、USA 17873 km/vehicle/year。同一国家的BEV、PHEV和ICEV共用唯一annual_km。ICEV输入以kg CO2/km保存，年排放在代码中用当前里程计算。正文与SI的input和脚本同步更新；正式output尚未重跑，不应将修正前结果当作新结果。原有Origin项目、Excel和Word未修改。

运行时打开对应Rproj并完整Source同文件夹中的R脚本。使用Base R，无须安装其他包。每份均为1000个EV A编号×每国5000组价格/使用参数的交叉计算；本次仅修正里程及其年排放换算，抽样和情景参数保持不变。

本包不依赖历史备份。2026-10-12拆分时曾完整重跑并核对结果；这不等于2026-10-19里程修正后的正式重跑。本次已对六国全部年份和情景进行小样本回归测试，正式output仍需重新生成。

本目录原有两个Origin项目保留原位置、未修改。公开复现只需分别使用main_text和SI的input、R脚本、Rproj及README；不上传旧output、作者核对或历史备份目录。
