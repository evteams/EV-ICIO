# Figure 6 SI calculation package / 图6 SI独立复现包

本文件夹对应SI图：Battery、Steel、ACES、ACES + Battery、ACES + Steel、ACES + Battery + Steel相对于BAU的parity提前量，以及BAU绝对parity插图。与正文完全独立；所有输入均是本文件夹内的实际文件，不是链接。不读取正文、父目录或其他图的文件。

## Run / 运行

在RStudio打开 `Fig6_SI.Rproj`，完整Source `Fig6_SI.R`。使用Base R，无须安装额外包；交付结果使用R 4.3.3。路径根据脚本位置自动确定，整个 `SI` 文件夹可单独移动或上传。

脚本只包含数据处理和MC计算，不含制图、参考结果核对、确定性baseline或回收抵扣。重新运行会覆盖本包 `output/` 中同名结果，不修改任何Origin、Word或Excel文件。

## Input / 必要输入（9份）

| 文件 | 内容与单位 |
| --- | --- |
| `production_coefficients_EV.csv` | 六国各1000个原A编号的2023总系数 `b_total`、全供应链钢铁贡献 `b_C24A`、77个供应国D电力部门贡献，kt CO2/million USD |
| `production_coefficients_ICEV.csv` | 六国固定ICEV A的同类系数，每国一行，相同单位 |
| `vehicle_price_ranges_2023.csv` | EV/ICEV价格下限与上限，USD/vehicle，与Fig3公开复现包一致；没有base价格 |
| `grid_factors_2023_2030.csv` | 77个供应国2023–2030年BAU和ACES电网因子，无量纲，2023=1；不含Solar/Wind字段 |
| `vehicle_use_2023.csv` | 固定BEV/PHEV份额、EC（kWh/km）、FC（L/km）、统一年里程annual_km（km/vehicle/year）、直接电网强度（kg CO2/kWh）、间接/直接比例、运行/充电系数、汽油排放因子（kg CO2/L）；ICEV_WTT_kgCO2_per_km和ICEV_TTW_kgCO2_per_km为每公里强度 |
| `sampling_ranges.csv` | UF及PHEV共用能耗乘数q的均匀抽样上下限；不含MEG |
| `battery_parameters.csv` | LFP份额端点、NMC811/LFP单位容量排放强度、6.17 t CO2e/代表性EV的基期电池组成代理 |
| `steel_factors_2023_2030.csv` | 当前SBTi钢铁强度路径归一化因子，2023=1 |
| `scenarios_SI.csv` | 7个情景的电网路径、Battery与Steel开关，BAU为首行 |

SI不计算Solar、Wind或MEG。生产系数已由1000份既有EV A和固定ICEV A求得，中国EV侧C27/D校准已包含其中，不再乘1.15。本包从这些系数开始，不重新求ICIO逆矩阵；若需从原始A、X和CO2求系数，需使用相应Fig3/Fig4原始矩阵复现包。

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

| 情景 | 电网路径 | Battery | Steel |
| --- | --- | --- | --- |
| BAU | BAU | 否 | 否 |
| Battery | BAU | 是 | 否 |
| Steel | BAU | 否 | 是 |
| ACES | ACES | 否 | 否 |
| ACES + Battery | ACES | 是 | 否 |
| ACES + Steel | ACES | 否 | 是 |
| ACES + Battery + Steel | ACES | 是 | 是 |

Battery和Steel均是在BAU电网路径上叠加技术，而不是冻结2023电网。不额外计算图中未显示的Battery + Steel。

## Calculations and MC / 计算过程与抽样

1. 按CHN、DEU、JPN、KOR、MEX、USA顺序，每国先抽5000个EV价格，再抽5000个ICEV价格，均为Uniform(lower, upper)，种子20261005。EV与ICEV价格独立；同编号用于配对，不表示价格相等。单车核算不需要产业总需求Y或销量。
2. 使用种子2026100601，每国先抽全部UF，再抽全部q：UF ~ U(0.3,0.7)，q ~ U(0.9,1.1)，相互独立。同一q作用于PHEV电耗和油耗，同一UF同时决定电动与燃油份额。与2026-10-18更新后的图5统一为共用能耗乘数假设；这是建模相关性设定，不是从观测数据估计的相关系数。图6的随机种子、样本数及既有数值算法未变。
3. 1000个A编号与5000个联合价格/使用编号全交叉，每国、年、情景共500万组合。各年份和情景共享同批抽样以便配对。这不是500万个独立A或使用参数样本。电网、电池份额/强度及钢铁路径固定，不额外抽样。

固定A，电力D和钢铁C24A直接排放系数改变时，生产系数可精确重组：

```text
b_scenario = b_2023 + sum_r[D_r × (grid_factor_r,year − 1)]
             + Steel_switch × b_C24A × (steel_factor_year − 1)
Production_EV[A,p] = b_EV_scenario[A] × Price_EV[p] / 1000 − Battery_switch × delta_year
Production_ICEV[p] = b_ICEV_scenario × Price_ICEV[p] / 1000
```

生产排放单位为t CO2/vehicle。因 `b=f'(I−A)^−1` 对f线性，固定A时无需重新求逆，不是将不同情景的parity中位数相加。

Battery沿用批准的化学替代设定：LFP容量份额从2023年40%线性升至2030年60%，其余采用NMC811代理，单位容量强度分别为56与79 kg CO2e/kWh：

```text
LFP_share_y = 0.40 + (0.60−0.40) × (y−2023)/7
I_y = 79 × (1−LFP_share_y) + 56 × LFP_share_y
delta_y = 6.17 × (1−I_y/I_2023)   [t CO2e/EV]
```

I_2023=69.8，I_2030=65.2，2030扣减约0.4066189112 t/EV。6.17是既有生产排放中的电池组成代理，不是kg/kWh，不能再额外添加6.17。Battery不改变EC、FC、UF或TTW，不包含电池更换。

Steel将当前SBTi强度路径映射到C24A直接排放系数，同时作用于EV和ICEV全部供应国；不填入未知单车钢铁质量，也不假设EV/ICEV钢铁用量相同。

BEV、PHEV份额、EC、FC及年里程固定2023年。保留两种车型各自校准的直接电网强度；间接强度=直接强度×间接/直接比例，直接和间接同时乘该国电网因子：

```text
CI_total_y = CI_direct_2023 × (1 + indirect/direct ratio) × grid_factor_y
BEV_electric = EC_BEV × k_rw × k_loss × CI_total_BEV,y × annual_km / 1000
PHEV_electric = UF × EC_PHEV × q × k_rw,electric × k_loss
                × CI_total_PHEV,y × annual_km / 1000
Electric_WTT = BEV_share × BEV_electric + PHEV_share × PHEV_electric
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

## Output / 结果（6份）

| 文件 | 内容 |
| --- | --- |
| `Fig6_SI_parity_2023_2030.csv` | 336行，6国×8年×7情景；绝对parity的Mean、Median、Low、High、SD及计数，单位year；含BAU |
| `Fig6_SI_advance_vs_BAU_2023_2030.csv` | 288行，6个非BAU情景；配对提前量、百分比、中位数比较 |
| `Fig6_SI_production_and_use_summary.csv` | 336行，生产均值（t CO2/vehicle）、WTT/TTW与年减排分布（t CO2/year） |
| `Fig6_SI_price_use_draws.csv` | 30000行，价格、UF、q及样本编号 |
| `Fig6_SI_annual_technology_parameters.csv` | 8行，逐年电池份额、加权强度、扣减量及钢铁因子 |
| `Fig6_SI_factorized_MC.rds` | 6国完整A编号、抽样、年度生产系数、年减排和电池扣减，可重建全部交叉parity分布 |

主图曲线取 `Median_Advance_years`，区间取 `Low_Advance_years`/`High_Advance_years`。插图从parity表筛选BAU，取 `Median_years`/`Low_years`/`High_years`。Low/High为逐年2.5%/97.5%分位数（R quantile type 7），不是均值置信区间或跨年份同时置信带；组合计数不是独立观测数。

RDS中 `Countries[[country]]` 的 `b_EV[A,year,scenario]`、`b_ICEV[year,scenario]`、`Annual_saving[year,p,scenario]`、`Prices`，以及情景Battery开关和 `Battery_reduction_tCO2e_per_EV` 可代入上述公式。无需保存数十亿行重复组合，也不需要正文的RDS。

## Provenance and limits / 来源与边界

生产、电网、车辆、钢铁和电池输入沿用当前正式版 `20261006_uniform_UF_q_LFP40`，价格范围和价格种子与更新后的Fig3一致。本次拆分不新增文献估计或改变模型。

6.17 t代理沿用作者确认的Clemente M, Maharjan P, Salazar M, Hofman T, *Meta-analysis of life cycle assessments for Li-ion batteries production emissions*, The International Journal of Life Cycle Assessment 30 (2025), 2625–2641。LFP40%→60%及79/56强度保持已有批准设定。

Battery将LCA CO2e代理扣减施加到ICIO CO2核算，属于混合边界近似，不是按各国BEV/PHEV电池容量重建的部件LCA。Steel为C24A部门强度代理；SBTi路径包含其定义范围的能源排放，不应将组合解释为完全物理独立、无重叠的工艺效应。Battery与电网组合沿用既有加法近似，未额外估计化学替代与电池工厂电力去碳化的交互。

本包未生成DOI或指定许可证；第三方数据使用仍须遵循各原始来源的许可要求。
