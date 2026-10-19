# Figure 6 main-text calculation package / 图6正文独立复现包

本文件夹对应正文图：Solar、Wind、MEG、ACES、ACES + MEG相对于BAU的parity提前量，以及BAU绝对parity插图。与SI完全独立；所有输入均是本文件夹内的实际文件，不是链接。不读取SI、父目录或其他图的文件。

## Run / 运行

在RStudio打开 `Fig6_main_text.Rproj`，完整Source `Fig6_parity.R`。使用Base R，无须安装额外包；路径根据脚本位置自动确定，整个 `main_text` 文件夹可单独移动或上传。

脚本只包含数据处理和MC计算，不含制图、参考结果核对、确定性baseline或回收抵扣。重新运行会覆盖本包 `output/` 中同名结果，不修改任何Origin、Word或Excel文件。

## Input / 必要输入（7份）

| 文件 | 内容与单位 |
| --- | --- |
| `production_coefficients_EV.csv` | 六国各1000个原A编号的2023生产总系数 `b_total` 和77个供应国D电力部门贡献 `D_ARG` 等，kt CO2/million USD |
| `production_coefficients_ICEV.csv` | 六国固定ICEV A的同类系数，每国一行，相同单位 |
| `vehicle_price_ranges_2023.csv` | EV/ICEV价格下限与上限，USD/vehicle，与Fig3公开复现包一致；没有base价格 |
| `grid_factors_2023_2030.csv` | 77个供应国2023–2030年BAU、Solar、Wind、ACES电网因子，无量纲，2023=1 |
| `vehicle_use_2023.csv` | 固定BEV/PHEV份额、EC（kWh/km）、FC（L/km）、统一年里程annual_km（km/vehicle/year）、直接电网强度（kg CO2/kWh）、间接/直接比例、运行/充电系数、汽油排放因子（kg CO2/L）；ICEV_WTT_kgCO2_per_km和ICEV_TTW_kgCO2_per_km为每公里强度 |
| `sampling_ranges.csv` | UF、PHEV共用能耗乘数q、MEG2030减耗端点的均匀抽样上下限 |
| `scenarios_main_text.csv` | 6个情景的电网路径和MEG开关，BAU为首行 |

正文不计算Battery或Steel，不包含其参数表或C24A贡献字段。生产系数已由1000份既有EV A和固定ICEV A求得，中国EV侧C27/D校准已包含其中，不再乘1.15。本包从这些系数开始，不重新求ICIO逆矩阵；若需从原始A、X和CO2求系数，需使用相应Fig3/Fig4原始矩阵复现包。

## Annual mileage correction / 年里程修正（2026-10-19）

按论文表“Average annual mileage (km/vehicle/year)”固定六国年里程。每个国家的BEV、PHEV和ICEV使用相同数值，2023–2030年及全部情景均不改变、不抽样。

| Country | annual_km (km/vehicle/year) |
| --- | ---: |
| China | 10220 |
| Germany | 12320 |
| Japan | 8060 |
| South Korea | 11936 |
| Mexico | 12832 |
| United States | 17873 |

`vehicle_use_2023.csv`仅保留一个年里程字段`annual_km`。ICEV输入改为`ICEV_WTT_kgCO2_per_km`及`ICEV_TTW_kgCO2_per_km`，由原年排放除以原年里程并乘1000得到，保留原每公里强度；代码再乘当前`annual_km`并除1000得到t CO2/year。因此修改里程会同时更新EV和ICEV的年排放，不会留下旧里程对应的ICEV年排放。

本次仅更新input、代码和说明，未重新生成正式output、Origin、Excel或论文图形。原output仍对应修正前的里程，必须完整重跑脚本后才能作为新版结果使用。抽样分布、种子、电网路径、MEG、电池、钢铁及no-recycling边界保持不变。

## Scenarios / 情景

| 情景 | 电网路径 | MEG |
| --- | --- | --- |
| BAU | BAU | 否 |
| Solar | Solar | 否 |
| Wind | Wind | 否 |
| MEG | BAU | 是 |
| ACES | ACES | 否 |
| ACES + MEG | ACES | 是 |

MEG是在BAU或ACES电网路径上叠加电力WTT减耗，不是冻结2023电网。正文主图使用五个非BAU情景的配对提前量；BAU绝对parity用于插图。

## Calculations and MC / 计算过程与抽样

1. 按CHN、DEU、JPN、KOR、MEX、USA顺序，每国先抽5000个EV价格，再抽5000个ICEV价格，均为Uniform(lower, upper)，种子20261005。EV与ICEV价格独立；同编号用于配对，不表示价格相等。单车核算不需要产业总需求Y或销量。
2. 使用种子2026100601，每国先抽全部UF，再抽全部q：UF ~ U(0.3,0.7)，q ~ U(0.9,1.1)，相互独立。同一q作用于PHEV电耗和油耗，同一UF同时决定电动与燃油份额。与2026-10-18更新后的图5统一为共用能耗乘数假设；这是建模相关性设定，不是从观测数据估计的相关系数。图6的随机种子、样本数及既有数值算法未变。
3. 使用种子2026100501抽5000个MEG端点r ~ U(0.03,0.07)，每个编号的r在六国共享。年度减耗比例为 `r × (year−2023)/7`，仅改变电力WTT，不改变生产、汽油WTT或TTW。
4. 1000个A编号与5000个联合价格/使用编号全交叉，每国、年、情景共500万组合。各年份和情景共享同批抽样以便配对。这不是500万个独立A或使用参数样本。电网路径固定，不额外抽样。

固定A，仅更新供应国电力D部门直接排放系数时，生产系数可精确重组：

```text
b_scenario = b_2023 + sum_r[D_r × (grid_factor_r,year − 1)]
Production_EV[A,p] = b_EV_scenario[A] × Price_EV[p] / 1000
Production_ICEV[p] = b_ICEV_scenario × Price_ICEV[p] / 1000
```

生产排放单位为t CO2/vehicle。因 `b=f'(I−A)^−1` 对f线性，固定A时无需重新求逆，不是将不同情景的parity中位数相加。

BEV、PHEV份额、EC、FC及年里程固定2023年。保留两种车型各自校准的直接电网强度；间接强度=直接强度×间接/直接比例，直接和间接同时乘该国电网因子：

```text
CI_total_y = CI_direct_2023 × (1 + indirect/direct ratio) × grid_factor_y
BEV_electric = EC_BEV × k_rw × k_loss × CI_total_BEV,y × annual_km / 1000
PHEV_electric = UF × EC_PHEV × q × k_rw,electric × k_loss
                × CI_total_PHEV,y × annual_km / 1000
Electric_WTT = BEV_share × BEV_electric + PHEV_share × PHEV_electric
MEG_Electric_WTT = Electric_WTT × [1 − r × (year−2023)/7]
Gasoline_WTT = PHEV_share × (1−UF) × FC_PHEV × q × k_rw,fuel
               × EF_gas,WTT × annual_km / 1000
TTW = PHEV_share × (1−UF) × FC_PHEV × q × k_rw,fuel
      × EF_gas,TTW × annual_km / 1000
ICEV_WTT = ICEV_WTT_kgCO2_per_km × annual_km / 1000
ICEV_TTW = ICEV_TTW_kgCO2_per_km × annual_km / 1000
```

以上年排放单位为t CO2/year，BEV无燃烧TTW。ICEV每公里WTT/TTW及汽油因子固定；ICEV年排放由同一annual_km计算。中美BEV/PHEV直接强度分别保留原精度：CHN为0.524872144/0.525410364，USA约0.251379219/0.267231081 kg CO2/kWh。间接比例是间接/直接，不是间接/总量。

```text
Annual_saving[p] = ICEV_WTT + ICEV_TTW − Electric_WTT[p] − Gasoline_WTT[p] − TTW[p]
Parity[A,p] = (Production_EV[A,p] − Production_ICEV[p]) / Annual_saving[p]
Advance[A,p] = Parity_BAU[A,p] − Parity_scenario[A,p]
```

使用生产当年的年排放并在追平期固定，不采用购车队列的动态电网；不计recycling。年减排优势非正时parity记NA；年减排优势为正、生产差为负时保留负parity，不截断到零。负值表示生产阶段已具排放优势，不是生产前真实追平日期。

提前量逐A/联合编号配对，正值表示提前，负值表示延后。Median和Low/High来自差值分布，不是两个边际中位数或区间相减。配对百分比 `100×Advance/Parity_BAU` 仅对正BAU parity计算；另存两情景中位数之差和中位数相对降幅，不能混用。

## Output / 结果（5份）

| 文件 | 内容 |
| --- | --- |
| `Fig6_main_parity_2023_2030.csv` | 288行，6国×8年×6情景；绝对parity的Mean、Median、Low、High、SD及计数，单位year；含BAU |
| `Fig6_main_advance_vs_BAU_2023_2030.csv` | 240行，5个非BAU情景；配对提前量、百分比、中位数比较 |
| `Fig6_main_production_and_use_summary.csv` | 288行，生产均值（t CO2/vehicle）、WTT/TTW与年减排分布（t CO2/year） |
| `Fig6_main_price_use_draws.csv` | 30000行，价格、UF、q、MEG端点及样本编号 |
| `Fig6_main_factorized_MC.rds` | 6国完整A编号、抽样、年度生产系数和年减排，可重建全部交叉parity分布 |

主图曲线取 `Median_Advance_years`，区间取 `Low_Advance_years`/`High_Advance_years`。插图从parity表筛选BAU，取 `Median_years`/`Low_years`/`High_years`。Low/High为逐年2.5%/97.5%分位数（R quantile type 7），不是均值置信区间或跨年份同时置信带；组合计数不是独立观测数。

RDS中 `Countries[[country]]` 的 `b_EV[A,year,scenario]`、`b_ICEV[year,scenario]`、`Annual_saving[year,p,scenario]` 和 `Prices` 可代入上述公式。无需保存数十亿行重复组合，也不需要SI的RDS。

## Provenance / 来源与边界

生产、电网和车辆输入沿用当前正式版 `20261006_uniform_UF_q_LFP40` 中对应数据，价格范围和价格种子与更新后的Fig3一致。MEG3%–7%保持已批准设定，本次拆分不新增文献估计或改变模型。

本包未生成DOI或指定许可证；第三方数据使用仍须遵循各原始来源的许可要求。
