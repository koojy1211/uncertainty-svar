"""
DATA.xlsx 생성 — 블록외생 부호·서사제약 SVAR 메인 모형용 월별 데이터
먼저 prep_rate_dxy.py를 돌려 RATE_DXY.xlsx를 만든 뒤 실행한다
"""

import os
import numpy as np
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, PatternFill
from openpyxl.utils import get_column_letter

HERE  = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
OUT   = os.path.join(HERE, "DATA.xlsx")
START = "2000-01-01"
END   = "2025-12-01"
IDX   = pd.date_range(START, END, freq="MS")


# 원자료 읽기

def sys_export(path, sheet="Sheet2"):
    """0929_data.xlsx, call.xlsx: 2열씩 (날짜, 값), 13행부터 자료"""
    raw = pd.read_excel(path, sheet_name=sheet, header=None)
    out = {}
    for c in range(0, raw.shape[1] - 1, 2):
        code = str(raw.iloc[0, c])
        d = raw.iloc[13:, [c, c + 1]].copy()
        d.columns = ["d", "v"]
        d["v"] = pd.to_numeric(d["v"], errors="coerce")
        d = d.dropna()
        d["d"] = pd.to_datetime(d["d"])
        out[code] = d.set_index("d")["v"].sort_index()
    return out


def cpb_row(path, sheet, code):
    raw = pd.read_excel(path, sheet_name=sheet, header=None)
    row = raw.index[raw.iloc[:, 2] == code][0]
    hdr = raw.iloc[3, 5:]
    val = pd.to_numeric(raw.iloc[row, 5:], errors="coerce")
    s = pd.Series(val.values, index=pd.to_datetime(hdr.astype(str).str.replace("m", "-"), format="%Y-%m"))
    return s.dropna()


def ym_int(s):
    return pd.to_datetime(s.astype(str).str[:6], format="%Y%m")


def monthly_mean(s):
    return s.resample("MS").mean()


sx = sys_export(os.path.join(HERE, "0929_data.xlsx"))
cpb = os.path.join(HERE, "CPB-world-trade-monitor-july-2026.xlsx")

ebp = pd.read_csv(os.path.join(HERE, "ebp_csv.csv"))
ebp.index = pd.to_datetime(ebp["date"])

us = pd.read_excel(os.path.join(HERE, "US_Policy_Uncertainty_Data.xlsx"), sheet_name="Main News Index")
us = us[pd.to_numeric(us["Year"], errors="coerce").notna()]
us.index = pd.to_datetime(dict(year=us["Year"].astype(int), month=us["Month"].astype(int), day=1))
us = us["News_Based_Policy_Uncert_Index"].sort_index()

kr = pd.read_excel(os.path.join(HERE, "Korea_Policy_Uncertainty_Data.xlsx"), sheet_name="SK EPU Index Entire Period")
kr.index = pd.to_datetime(kr["Date"], format="%m/%Y")
kr = kr["New South Koean EPU Index"]

macro = pd.read_excel(os.path.join(HERE, "MACRO.xlsx"), sheet_name="월별")
macro.index = ym_int(macro["date"])

rd = pd.read_excel(os.path.join(HERE, "RATE_DXY.xlsx"), sheet_name="월별")
rd.index = pd.to_datetime(rd["date"])

vk = pd.read_excel(os.path.join(HERE, "VKOSPI200_F.xlsx"), sheet_name="월별")
vk.index = pd.to_datetime(vk["월"], format="%Y-%m")

k200 = pd.read_stata(os.path.join(HERE, "KOSPI200_DAILY.dta"))
k200 = k200.set_index(pd.to_datetime(k200["ddate"]))["k200"].sort_index()


# 메인 모형 변수 (원단위)

fx_d   = sx["NECOS-731U003-D-0000003"]           # 원/달러 종가 15:30
call_d = sys_export(os.path.join(HERE, "call.xlsx"), "Sheet1")["NECOS-817U002-D-010101000"]

LEVEL = pd.DataFrame(index=IDX)
LEVEL["usip"]    = sx["BBG-BBG-IP_Index"]
LEVEL["chn"]     = cpb_row(cpb, "inpro_out", "ipz_cn_qnmi_sm")
LEVEL["oil"]     = monthly_mean(sx["NECOS-701U003-D-4010102"])
LEVEL["us2y"]    = sx["FRED-115-GS2"]
LEVEL["ebp"]     = ebp["ebp"]
LEVEL["vix"]     = monthly_mean(sx["BBG-BBG-VIX_Index"])
LEVEL["usepu"]   = us
LEVEL["dxy"]     = rd["dxy"]
LEVEL["ip"]      = sx["NECOS-901U033-M-A00-2"]
LEVEL["cpi"]     = sx["NECOS-901U009-M-0"]
LEVEL["kr_call"] = monthly_mean(call_d)
LEVEL["spread"]  = rd["spread"]
LEVEL["fx"]      = monthly_mean(fx_d)
LEVEL["krepu"]   = kr

miss = LEVEL.isna().sum()
if miss.any():
    raise SystemExit(f"결측 있음:\n{miss[miss > 0]}")


# 강건성·외부변수 (원단위)

cds_d = sx["BBG-BBG-KOREA_CDS_USD_SR_5Y_Corp__(R2)"]
cds_n = cds_d.resample("MS").count().reindex(IDX)
cds_m = monthly_mean(cds_d).reindex(IDX)
first = cds_d.index.min().to_period("M").to_timestamp()
cds_i = cds_m.copy()
cds_i[cds_i.index >= first] = cds_m[cds_m.index >= first].interpolate("linear")

EXTRA = pd.DataFrame(index=IDX)
EXTRA["cds5"]      = cds_i
EXTRA["cds5_nobs"] = cds_n.where(cds_n.index >= first)
EXTRA["fx_eop"]    = fx_d.resample("MS").last()
EXTRA["brent"]     = macro["oil"]
EXTRA["chn_imp"]   = cpb_row(cpb, "trade_out", "mgz_cn_qnmi_sn")
EXTRA["vkospi"]    = vk["종가_평균"]
EXTRA["k200_eop"]  = k200.resample("MS").last()
EXTRA["mfg"]       = macro["kr_mfg"]
EXTRA["retail"]    = macro["kr_retail"]
EXTRA["equip"]     = macro["kr_equip"]
EXTRA["us_ffr"]    = macro["us_ffr"]
EXTRA["dxy_eop"]   = rd["dxy_eop"]
EXTRA["spread_bbb"] = rd["spread_bbb"]
EXTRA["msb1y"]     = rd["msb1y"]
EXTRA = EXTRA.reindex(IDX)


# VAR 시트 정의: (이름, LEVEL 열, 변환)

VAR_SPEC = [
    ("lusip",   "usip",    "log"), ("lchn",   "chn",    "log"), ("loil",    "oil",    "log"),
    ("us2y",    "us2y",    "lvl"), ("ebp",    "ebp",    "lvl"), ("lvix",    "vix",    "log"),
    ("lusepu",  "usepu",   "log"), ("ldxy",    "dxy",    "log"),
    ("lip",     "ip",      "log"), ("lcpi",   "cpi",    "log"), ("kr_call", "kr_call", "lvl"),
    ("spread",  "spread",  "lvl"), ("lfx",    "fx",     "log"), ("lkrepu",  "krepu",  "log"),
]
DUMMIES = ["2020-03", "2020-04", "2020-05", "2020-06"]

META = [
    # 변수, 시트, 블록, 설명, 원천 파일, 계열 코드, 단위, 월 변환, VAR 변환
    ("lusip", "VAR", "글로벌", "미국 산업생산 (SA)", "0929_data.xlsx", "BBG IP Index", "지수", "월", "100×ln"),
    ("lchn", "VAR", "글로벌", "중국 산업생산 (SA, 수입가중)", "CPB-world-trade-monitor-july-2026.xlsx", "ipz_cn_qnmi_sm", "2021=100", "월", "100×ln"),
    ("loil", "VAR", "글로벌", "두바이유 현물", "0929_data.xlsx", "NECOS 701U003 D 4010102", "USD/배럴", "일별 → 월평균", "100×ln"),
    ("us2y", "VAR", "글로벌", "미 국채 2년 (CMT)", "0929_data.xlsx", "FRED GS2", "%", "월", "수준"),
    ("ebp", "VAR", "글로벌", "GZ excess bond premium", "ebp_csv.csv", "Fed FEDS Notes ebp", "%p", "월", "수준"),
    ("lvix", "VAR", "글로벌", "VIX", "0929_data.xlsx", "BBG VIX Index", "지수", "일별 → 월평균", "100×ln"),
    ("lusepu", "VAR", "글로벌", "미국 EPU (News)", "US_Policy_Uncertainty_Data.xlsx", "Main News Index", "지수", "월", "100×ln"),
    ("ldxy", "VAR", "글로벌", "ICE 달러인덱스 (원화 미포함 6개 통화)", "RATE_DXY.xlsx ← Investing.com 일별", "US Dollar Index (DXY)", "지수", "일별 → 월평균", "100×ln"),
    ("lip", "VAR", "한국", "전산업생산지수 (농림어업 제외, SA)", "0929_data.xlsx", "NECOS 901U033 M A00-2", "2020=100", "월", "100×ln"),
    ("lcpi", "VAR", "한국", "소비자물가지수 총지수", "0929_data.xlsx", "NECOS 901U009 M 0", "2020=100", "월", "100×ln"),
    ("kr_call", "VAR", "한국", "콜금리 1일 전체거래", "call.xlsx", "NECOS 817U002 D 010101000", "%", "일별 → 월평균", "수준"),
    ("spread", "VAR", "한국", "회사채 AA- 3년 − 국고 3년", "RATE_DXY.xlsx ← 1016_rate.xlsx", "NECOS 721U001 M 7020000 − 5020000", "%p", "월", "수준"),
    ("lfx", "VAR", "한국", "원/달러 종가 15:30", "0929_data.xlsx", "NECOS 731U003 D 0000003", "원", "일별 → 월평균", "100×ln"),
    ("lkrepu", "VAR", "한국", "한국 EPU (Baker-Bloom-Davis)", "Korea_Policy_Uncertainty_Data.xlsx (원본 .xls를 변환)", "SK EPU Index Entire Period", "지수", "월", "100×ln"),
    ("d2020m3–d2020m6", "VAR", "더미", "COVID 월 더미 (두 블록 모든 식)", "—", "—", "0/1", "—", "—"),
    ("cds5", "EXTRA", "외부변수", "한국 CDS 5년 (USD, SR, D14)", "0929_data.xlsx", "BBG KOREA CDS USD SR 5Y D14 Corp (R2)", "bp", "일별 → 월평균, 관측 0건 월은 선형보간", "—"),
    ("cds5_nobs", "EXTRA", "외부변수", "CDS 월별 관측일수 (5 미만이면 주의)", "0929_data.xlsx", "—", "일", "—", "—"),
    ("fx_eop", "EXTRA", "강건성", "원/달러 종가 15:30 월말", "0929_data.xlsx", "NECOS 731U003 D 0000003", "원", "일별 → 월말", "—"),
    ("brent", "EXTRA", "강건성", "브렌트유", "MACRO.xlsx", "FRED DCOILBRENTEU", "USD/배럴", "일별 → 월평균", "—"),
    ("chn_imp", "EXTRA", "강건성", "중국 수입물량 (SA)", "CPB-world-trade-monitor-july-2026.xlsx", "mgz_cn_qnmi_sn", "2021=100", "월", "—"),
    ("vkospi", "EXTRA", "강건성", "VKOSPI200", "VKOSPI200_F.xlsx", "KRX 코스피200 변동성지수", "지수", "일별 → 월평균", "—"),
    ("k200_eop", "EXTRA", "외부변수", "KOSPI200 월말", "KOSPI200_DAILY.dta", "KRX KOSPI200", "지수", "일별 → 월말", "—"),
    ("mfg", "EXTRA", "강건성", "광공업생산지수 (SA)", "MACRO.xlsx", "ECOS 901Y033 AB00-2", "2020=100", "월", "—"),
    ("retail", "EXTRA", "2단계", "소매판매액지수 (SA)", "MACRO.xlsx", "ECOS 901Y100 G0 T3", "지수", "월", "—"),
    ("equip", "EXTRA", "2단계", "설비투자지수 (SA)", "MACRO.xlsx", "ECOS 901Y066 I15B", "지수", "월", "—"),
    ("us_ffr", "EXTRA", "참고", "미 연방기금금리", "MACRO.xlsx", "FRED FEDFUNDS", "%", "월", "—"),
    ("dxy_eop", "EXTRA", "강건성", "ICE 달러인덱스 월말", "RATE_DXY.xlsx ← Investing.com 일별", "US Dollar Index (DXY)", "지수", "일별 → 월말", "—"),
    ("spread_bbb", "EXTRA", "강건성", "회사채 BBB- 3년 − AA- 3년 (2000M10부터)", "RATE_DXY.xlsx ← 1016_rate.xlsx", "NECOS 721U001 M 7030000 − 7020000", "%p", "월", "—"),
    ("msb1y", "EXTRA", "강건성", "통안증권 1년", "RATE_DXY.xlsx ← 1016_rate.xlsx", "NECOS 721U001 M 6010100", "%", "월", "—"),
]


# 엑셀 쓰기

F      = Font(name="Arial", size=10)
FB     = Font(name="Arial", size=10, bold=True)
FILL_H = PatternFill("solid", start_color="D9E1F2")
FILL_G = PatternFill("solid", start_color="EDEDED")

wb = Workbook()


def header(ws, names, fills=None):
    for j, n in enumerate(names, 1):
        c = ws.cell(row=1, column=j, value=n)
        c.font = FB
        c.alignment = Alignment(horizontal="center")
        c.fill = (fills[j - 1] if fills else FILL_H)
    ws.freeze_panes = "C2"


def date_cols(ws, i, d):
    a = ws.cell(row=i, column=1, value=d.to_pydatetime())
    a.number_format = "yyyy-mm"
    a.font = F
    b = ws.cell(row=i, column=2, value=f"{d.year}m{d.month}")
    b.font = F


# LEVEL
ws_l = wb.active
ws_l.title = "LEVEL"
lev_cols = list(LEVEL.columns)
header(ws_l, ["date", "ym"] + lev_cols)
for i, d in enumerate(IDX, 2):
    date_cols(ws_l, i, d)
    for j, col in enumerate(lev_cols, 3):
        c = ws_l.cell(row=i, column=j, value=float(LEVEL.at[d, col]))
        c.font = F
        c.number_format = "0.000"
lev_letter = {col: get_column_letter(j) for j, col in enumerate(lev_cols, 3)}

# VAR (LEVEL 참조 수식)
ws_v = wb.create_sheet("VAR", 0)
var_names = [v[0] for v in VAR_SPEC] + [f"d{y}m{int(m)}" for y, m in (s.split("-") for s in DUMMIES)]
fills = [FILL_H, FILL_H] + [FILL_H] * 8 + [FILL_G] * 6 + [FILL_H] * len(DUMMIES)
header(ws_v, ["date", "ym"] + var_names, fills)
VARV = pd.DataFrame(index=IDX)
for name, src, tr in VAR_SPEC:
    VARV[name] = 100 * np.log(LEVEL[src]) if tr == "log" else LEVEL[src]
for s in DUMMIES:
    y, m = s.split("-")
    VARV[f"d{y}m{int(m)}"] = (IDX == pd.Timestamp(f"{s}-01")).astype(int)
if VARV.isna().any().any():
    raise SystemExit("VAR 값에 결측이 있다")
for i, d in enumerate(IDX, 2):
    date_cols(ws_v, i, d)
    for j, name in enumerate(var_names, 3):
        c = ws_v.cell(row=i, column=j, value=float(VARV.at[d, name]))
        c.font = F
        c.number_format = "0" if name.startswith("d20") else "0.000"

# EXTRA
ws_e = wb.create_sheet("EXTRA")
ext_cols = list(EXTRA.columns)
header(ws_e, ["date", "ym"] + ext_cols)
for i, d in enumerate(IDX, 2):
    date_cols(ws_e, i, d)
    for j, col in enumerate(ext_cols, 3):
        v = EXTRA.at[d, col]
        if pd.notna(v):
            c = ws_e.cell(row=i, column=j, value=float(v))
            c.font = F
            c.number_format = "0" if col == "cds5_nobs" else "0.000"

# META
ws_m = wb.create_sheet("META")
mcols = ["변수", "시트", "블록", "설명", "원천 파일", "계열 코드", "단위", "월 변환", "VAR 변환"]
for j, n in enumerate(mcols, 1):
    c = ws_m.cell(row=1, column=j, value=n)
    c.font = FB
    c.fill = FILL_H
for i, row in enumerate(META, 2):
    for j, v in enumerate(row, 1):
        ws_m.cell(row=i, column=j, value=v).font = F
r = len(META) + 3
notes = [
    "표본 2000M1–2025M12 (312개월). 시작은 전산업생산, 끝은 KR EPU가 결정.",
    "VAR 시트는 값이다(LEVEL을 위 VAR 변환 열대로 변환). 파란 헤더 = 글로벌 블록·더미, 회색 헤더 = 한국 블록.",
    "변수 순서는 블록 순서(글로벌 → 한국)만 의미가 있다. 블록 안 순서는 식별에 영향 없음.",
    "spread는 RATE_DXY.xlsx(1016_rate.xlsx). 기존 SPREAD_LONG.xlsx와 2025M12까지 값이 같다.",
    "spread_bbb는 2000M10부터이고 BBB- 호가가 경직적이라 강건성 전용. RATE_DXY.xlsx는 prep_rate_dxy.py로 먼저 만든다.",
    "kr_call은 일별 단순평균. ECOS 월 통계(721Y001)와 차이 최대 0.08%p (2000–2025).",
    "Stata: import excel using DATA.xlsx, sheet(VAR) firstrow clear → gen mdate = monthly(ym, \"YM\") → tsset mdate, monthly",
    "생성: build_DATA.py",
]
ws_m.cell(row=r, column=1, value="비고").font = FB
for k, n in enumerate(notes, r + 1):
    ws_m.cell(row=k, column=1, value=n).font = F

# 열 너비
for ws in (ws_v, ws_l, ws_e):
    ws.column_dimensions["A"].width = 10
    ws.column_dimensions["B"].width = 9
    for j in range(3, ws.max_column + 1):
        ws.column_dimensions[get_column_letter(j)].width = 11
for j, w in enumerate([16, 7, 9, 34, 36, 36, 10, 34, 9], 1):
    ws_m.column_dimensions[get_column_letter(j)].width = w

wb.save(OUT)
print(f"저장: {OUT}  ({len(IDX)}개월, VAR {len(var_names)}열, EXTRA {len(ext_cols)}열)")
