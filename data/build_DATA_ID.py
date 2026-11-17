"""
DATA_ID.xlsx 생성 — 충격 식별용 통합 데이터셋
DATA.xlsx(메인 14변수) + VKOSPI(공백 보정) + 강건성용 대체 계열을 한 파일에 모은다
먼저 build_DATA.py로 DATA.xlsx를 만든 뒤 실행한다

VKOSPI 공백(2003M1 이전) 보정은 Bloom (2009)과 같은 방식이다
  실현변동성 = 월중 KOSPI200 일별 로그수익률의 표준편차 × √252 × 100
  VKOSPI와 겹치는 2003M1–2025M12에서 평균·분산을 VKOSPI에 맞춘 뒤 공백 달에만 쓴다
2003년 이전 KOSPI200 일별은 KOSPI200_DAILY_EXT.xlsx(1열 날짜, 2열 종가)로 넣는다
이 파일이 없으면 lvkospi는 2000M1–2002M12가 결측으로 남는다
"""

import os
import numpy as np
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter

HERE  = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
OUT   = os.path.join(HERE, "DATA_ID.xlsx")
IDX   = pd.date_range("2000-01-01", "2025-12-01", freq="MS")
OVL   = ("2003-01-01", "2025-12-01")      # VKOSPI–실현변동성 겹치는 기간
MINOBS = 10                               # 실현변동성 계산 최소 거래일수


# 기존 데이터

def sheet(name):
    d = pd.read_excel(os.path.join(HERE, "DATA.xlsx"), sheet_name=name)
    d.index = pd.to_datetime(d["date"])
    return d.drop(columns=["date", "ym"]).reindex(IDX)

VAR0  = sheet("VAR")
LEV0  = sheet("LEVEL")
EXT0  = sheet("EXTRA")
if VAR0[[c for c in VAR0.columns if not c.startswith("d20")]].isna().any().any():
    raise SystemExit("DATA.xlsx VAR 시트에 결측이 있다. build_DATA.py를 다시 돌릴 것")


# KOSPI200 일별 → 월별 실현변동성

k = pd.read_stata(os.path.join(HERE, "KOSPI200_DAILY.dta"))
k = k.set_index(pd.to_datetime(k["ddate"]))["k200"].astype(float).sort_index()

ret = np.log(k).diff().dropna()

ext_path = os.path.join(HERE, "KOSPI200_DAILY_EXT.xlsx")
if os.path.exists(ext_path):
    e = pd.read_excel(ext_path).iloc[:, :2]
    e.columns = ["d", "v"]
    e["d"] = pd.to_datetime(e["d"], errors="coerce")
    e["v"] = pd.to_numeric(e["v"], errors="coerce")
    e = e.dropna().set_index("d")["v"].sort_index()
    common = e.index.intersection(k.index)
    if len(common) > 0:
        gap = (e[common] / k[common] - 1).abs().max()
        print(f"EXT와 기존 파일이 겹치는 {len(common)}일의 종가 차이 최대 {100 * gap:.2f}%")
        if gap > 0.005:
            print("경고: 두 원천의 KOSPI200 종가가 0.5% 넘게 다르다. 같은 지수인지 확인할 것")
    e = e[e.index < k.index.min()]
    # 원천이 바뀌는 날의 수익률은 쓰지 않는다 (각 원천 안에서만 수익률 계산)
    ret = pd.concat([np.log(e).diff().dropna(), ret])
    k = pd.concat([e, k])
    print(f"KOSPI200_DAILY_EXT.xlsx 사용: {e.index.min():%Y-%m-%d}부터 연결")
else:
    print("KOSPI200_DAILY_EXT.xlsx 없음: 2003년 이전 lvkospi는 결측")

g = ret.groupby(ret.index.to_period("M"))
rv = pd.DataFrame({"rv": g.std() * np.sqrt(252) * 100, "ndays": g.count()})
rv.index = rv.index.to_timestamp()
rv.loc[rv["ndays"] < MINOBS, "rv"] = np.nan
rv = rv.reindex(IDX)


# VKOSPI 공백 보정 (Bloom 2009: 겹치는 기간 평균·분산 일치)

vk = pd.read_excel(os.path.join(HERE, "VKOSPI200_F.xlsx"), sheet_name="월별")
vk.index = pd.to_datetime(vk["월"], format="%Y-%m")
vk = vk["종가_평균"].reindex(IDX)

ov = pd.concat([vk, rv["rv"]], axis=1, keys=["vk", "rv"]).loc[OVL[0]:OVL[1]].dropna()
a, b = ov["vk"].mean(), ov["vk"].std()
c, d = ov["rv"].mean(), ov["rv"].std()
rho  = ov["vk"].corr(ov["rv"])
rvn  = (rv["rv"] - c) / d * b + a
if (rvn.dropna() <= 0).any():
    raise SystemExit("정규화한 실현변동성에 0 이하 값이 있다")

vks = vk.where(vk.notna(), rvn)
src = pd.Series(np.where(vk.notna(), 0, np.where(rvn.notna(), 1, np.nan)), index=IDX)
print(f"겹치는 {len(ov)}개월 상관 {rho:.3f}, 보정 달 {int((src == 1).sum())}개, 결측 달 {int(src.isna().sum())}개")


# 미 EPU 3요소 지수 (DSVdV가 쓴 버전)

u3 = pd.read_excel(os.path.join(HERE, "US_Policy_Uncertainty_Data.xlsx"), sheet_name="Legacy Three Component EPU")
u3 = u3[pd.to_numeric(u3["Year"], errors="coerce").notna()]
u3.index = pd.to_datetime(dict(year=u3["Year"].astype(int), month=u3["Month"].astype(int), day=1))
u3 = u3["Three_Component_Index"].sort_index().reindex(IDX)


# 시트 구성

GLOBAL = ["lusip", "lchn", "loil", "us2y", "ebp", "lvix", "lusepu", "ldxy"]
KOREA  = ["lip", "lcpi", "kr_call", "spread", "lfx", "lkrepu"]
DUMS   = ["d2020m3", "d2020m4", "d2020m5", "d2020m6", "d2020m7"]

VAR = VAR0[GLOBAL + KOREA].copy()
VAR["lvkospi"] = 100 * np.log(vks)
for s in DUMS:
    VAR[s] = (IDX == pd.Timestamp(f"{s[1:5]}-{s[6:]}-01")).astype(int)

k_eop = k.resample("MS").last().reindex(pd.date_range("1999-12-01", IDX[-1], freq="MS"))
ALT = pd.DataFrame(index=IDX)
ALT["lusepu3"]    = 100 * np.log(u3)
ALT["lvkospi_rv"] = 100 * np.log(rvn)
ALT["r_k200"]     = (100 * np.log(k_eop).diff()).reindex(IDX)
ALT["spread_bbb"] = EXT0["spread_bbb"]
ALT["cds5"]       = EXT0["cds5"]
ALT["vkospi_src"] = src

LEV = LEV0.copy()
LEV["vkospi"] = vks
LEV["vkospi_raw"] = vk
LEV["rv_k200"] = rv["rv"]

SPL = pd.DataFrame({"vkospi_raw": vk, "rv_k200": rv["rv"], "ndays": rv["ndays"],
                    "rv_norm": rvn, "vkospi": vks, "src": src}, index=IDX)

META = [
    # 변수, 시트, 블록, 설명, 원천, 단위, 변환
    ("lusip–ldxy (8개)", "VAR", "글로벌", "DATA.xlsx VAR 시트와 동일", "DATA.xlsx", "—", "그대로"),
    ("lip–lkrepu (6개)", "VAR", "한국", "DATA.xlsx VAR 시트와 동일", "DATA.xlsx", "—", "그대로"),
    ("lvkospi", "VAR", "한국", "VKOSPI200 월평균. 2003M1 이전은 KOSPI200 실현변동성을 평균·분산 일치로 보정 (Bloom 2009)", "VKOSPI200_F.xlsx, KOSPI200_DAILY.dta(+EXT)", "지수", "100×ln"),
    ("d2020m3–d2020m7", "VAR", "더미", "COVID 월 더미. m7은 혼합 차분 스펙용", "—", "0/1", "—"),
    ("lusepu3", "ALT", "글로벌", "미 EPU 3요소 지수(뉴스·세법 만료·예측 불일치). DSVdV가 쓴 버전", "US_Policy_Uncertainty_Data.xlsx", "지수", "100×ln"),
    ("lvkospi_rv", "ALT", "한국", "전 기간 실현변동성(정규화) 기반 VKOSPI 대용 — 보정 방식 강건성", "KOSPI200_DAILY.dta(+EXT)", "지수", "100×ln"),
    ("r_k200", "ALT", "외부변수", "KOSPI200 월말 로그수익률 — LMN식 상관 제약용", "KOSPI200_DAILY.dta(+EXT)", "%", "100×Δln"),
    ("spread_bbb", "ALT", "한국", "회사채 BBB- − AA- 3년 (2000M10부터)", "DATA.xlsx EXTRA", "%p", "수준"),
    ("cds5", "ALT", "외부변수", "한국 CDS 5년 (2002M2부터)", "DATA.xlsx EXTRA", "bp", "수준"),
    ("vkospi_src", "ALT", "참고", "lvkospi 출처: 0 = VKOSPI 실측, 1 = 실현변동성 보정, 빈칸 = 결측", "—", "—", "—"),
]
NOTES = [
    f"VKOSPI 보정: 겹치는 기간 {OVL[0][:7]}–{OVL[1][:7]} ({len(ov)}개월), 상관 {rho:.3f}. Bloom (2009)의 VXO–실현변동성 상관은 0.874.",
    f"정규화 모수: VKOSPI 평균 {a:.2f}, 표준편차 {b:.2f} / 실현변동성 평균 {c:.2f}, 표준편차 {d:.2f}.",
    "실현변동성 = 월중 KOSPI200 일별 로그수익률 표준편차 × √252 × 100. 거래일 10일 미만인 달은 결측.",
    "2003년 이전 KOSPI200 일별은 KOSPI200_DAILY_EXT.xlsx(1열 날짜, 2열 종가)로 넣고 다시 실행한다.",
    "VAR 시트는 DATA.xlsx VAR의 상위집합이다. svar.do는 파일명만 DATA_ID.xlsx로 바꾸면 그대로 돌아간다.",
    "값으로 저장했으므로 Excel에서 다시 저장하지 않아도 Stata가 읽는다.",
    "생성: build_DATA_ID.py (build_DATA.py 다음에 실행)",
]


# 엑셀 쓰기

F      = Font(name="Arial", size=10)
FB     = Font(name="Arial", size=10, bold=True)
FILL_H = PatternFill("solid", start_color="D9E1F2")
FILL_G = PatternFill("solid", start_color="EDEDED")
FILL_N = PatternFill("solid", start_color="FFF2CC")

wb = Workbook()


def write(ws, df, fills=None, fmt="0.000"):
    names = ["date", "ym"] + list(df.columns)
    for j, n in enumerate(names, 1):
        cell = ws.cell(row=1, column=j, value=n)
        cell.font = FB
        cell.alignment = Alignment(horizontal="center")
        cell.fill = fills[j - 3] if (fills and j > 2) else FILL_H
    for i, dt in enumerate(df.index, 2):
        a1 = ws.cell(row=i, column=1, value=dt.to_pydatetime())
        a1.number_format = "yyyy-mm"
        a1.font = F
        ws.cell(row=i, column=2, value=f"{dt.year}m{dt.month}").font = F
        for j, col in enumerate(df.columns, 3):
            v = df.at[dt, col]
            if pd.notna(v):
                cell = ws.cell(row=i, column=j, value=float(v))
                cell.font = F
                cell.number_format = "0" if (col.startswith("d20") or col in ("ndays", "src", "vkospi_src")) else fmt
    ws.freeze_panes = "C2"
    ws.column_dimensions["A"].width = 10
    ws.column_dimensions["B"].width = 9
    for j in range(3, ws.max_column + 1):
        ws.column_dimensions[get_column_letter(j)].width = 11


ws = wb.active
ws.title = "VAR"
write(ws, VAR, [FILL_H] * 8 + [FILL_G] * 6 + [FILL_N] + [FILL_H] * len(DUMS))
write(wb.create_sheet("ALT"), ALT)
write(wb.create_sheet("LEVEL"), LEV)
write(wb.create_sheet("SPLICE"), SPL)

wm = wb.create_sheet("META")
mcols = ["변수", "시트", "블록", "설명", "원천", "단위", "VAR 변환"]
for j, n in enumerate(mcols, 1):
    cell = wm.cell(row=1, column=j, value=n)
    cell.font = FB
    cell.fill = FILL_H
for i, row in enumerate(META, 2):
    for j, v in enumerate(row, 1):
        wm.cell(row=i, column=j, value=v).font = F
r = len(META) + 3
wm.cell(row=r, column=1, value="비고").font = FB
for kk, n in enumerate(NOTES, r + 1):
    wm.cell(row=kk, column=1, value=n).font = F
for j, w in enumerate([18, 7, 9, 70, 40, 7, 10], 1):
    wm.column_dimensions[get_column_letter(j)].width = w

wb.save(OUT)
print(f"저장: {OUT}  ({len(IDX)}개월, VAR {VAR.shape[1]}열, ALT {ALT.shape[1]}열)")
