* 블록외생 부호·서사제약 SVAR
*   Spec A: 국내 기원 불확실성 충격 U, 금융충격 F (한국 블록)
*   Spec B: 글로벌 금융불확실성 UF*, 정책불확실성 UP*, 금융충격 F* (글로벌 블록)

cd "/Users/koojy/Documents/GitHub/uncertainty-svar/data"

clear all
set more off
capture mkdir "../output"


* 0. Settings

local p    6       // 자기 시차
local q    2       // 한국 식에 들어가는 글로벌 변수 시차 (0~q)
local H    48      // IRF 지평
local nd   2000    // 축약형 사후 추출 횟수
local Rk   500     // 축약형 추출 1개당 한국 블록 회전 수
local Rg   2500    // 축약형 추출 1개당 글로벌 블록 회전 수
local maxk 2000    // 블록별 채택 상한
local M    1000    // 서사제약 통과확률 계산용 충격 시뮬레이션 횟수


* 1. Load data

import excel using "DATA.xlsx", sheet("VAR") firstrow clear
gen mdate = monthly(ym, "YM")
format mdate %tm
drop date
tsset mdate, monthly

quietly count if missing(lusip, lchn, loil, us2y, ebp, lvix, lusepu, lip, lcpi, kr_call, spread, lfx, lkrepu)
if r(N) > 0 {
    di as error "VAR 시트에 결측이 있다. DATA.xlsx를 Excel에서 열어 저장했는지 확인할 것"
    exit 459
}
// openpyxl로 만든 직후의 파일은 수식 결과값이 비어 있어 전부 결측으로 읽힌다


* 2. Restrictions

* 부호제약: 행 = (충격, 변수, 지평, 부호)
* 한국 충격  1 공급 S, 2 수요 D, 3 통화 MP, 4 금융 F, 5 불확실성 U, 6 잔여
* 한국 변수  1 lip, 2 lcpi, 3 kr_call, 4 spread, 5 lfx, 6 lkrepu
matrix SRK = ( ///
    1, 1, 0, -1 \ ///
    1, 2, 0,  1 \ ///
    2, 1, 0, -1 \ ///
    2, 2, 0, -1 \ ///
    2, 3, 1, -1 \ ///
    2, 3, 2, -1 \ ///
    3, 3, 0,  1 \ ///
    3, 3, 1,  1 \ ///
    3, 5, 0, -1 \ ///
    4, 4, 0,  1 \ ///
    5, 6, 0,  1 )
// 수요충격의 콜금리 반응은 1~2개월 뒤에 건다. 금통위가 연 8회라 당월 반응이 없는 달이 많다
// 생산·물가·환율은 F, U 충격에 제약하지 않는다. 결과로 볼 변수다

* 글로벌 충격  1 수요 D*, 2 미 통화 MP*, 3 금융 F*, 4 금융불확실성 UF*, 5 정책불확실성 UP*, 6~7 잔여
* 글로벌 변수  1 lusip, 2 lchn, 3 loil, 4 us2y, 5 ebp, 6 lvix, 7 lusepu
matrix SRG = ( ///
    1, 1, 0, -1 \ ///
    1, 2, 0, -1 \ ///
    1, 3, 0, -1 \ ///
    1, 4, 0, -1 \ ///
    2, 4, 0,  1 \ ///
    3, 5, 0,  1 \ ///
    4, 6, 0,  1 \ ///
    5, 7, 0,  1 )

* 서사제약 시점
scalar tU1 = tm(2024m12)   // U > 0, lkrepu 변화의 최대 기여 (글로벌 기여 포함 비교)
scalar tU2 = tm(2016m11)   // U > 0
scalar tU3 = tm(2004m3)    // U > 0
scalar tF1 = tm(2022m11)   // F > 0, spread 변화의 최대 기여 (글로벌 기여 포함 비교)
scalar tF2 = tm(2003m3)    // F > 0
scalar tG1 = tm(2001m9)    // UF* > 0
scalar tG2 = tm(2007m7)    // F* > 0
scalar tG3 = tm(2007m8)    // UF* > 0, lvix 변화의 최대 기여
scalar tG4 = tm(2008m9)    // F* > 0, UF* > 0
scalar tG5 = tm(2008m10)   // F* > 0, UF* > 0
scalar tG6 = tm(2011m8)    // UF* > 0, UP* > 0
scalar tG7 = tm(2016m11)   // UP* > 0, lusepu 변화의 최대 기여
scalar tG8 = tm(2025m4)    // UP* > 0
// 글로벌 Type A는 2개만 건다. 4개(2007M7, 2025M4 추가)면 시험 결과 채택률이 1/4로 떨어진다
// 2007M7, 2025M4 Type A 추가는 강건성으로 돌릴 것


* 3. Mata function

mata:
mata clear

// Haar 균등 직교행렬. R 대각을 양으로 맞춰야 균등분포가 된다
real matrix haarQ(real scalar n)
{
    real matrix X, Q, R
    real scalar j
    X = rnormal(n, n, 0, 1)
    qrd(X, Q=., R=.)
    for (j=1; j<=n; j++) {
        if (R[j,j] < 0) Q[., j] = -Q[., j]
    }
    return(Q)
}

// 부호제약. 충격 1~ns열이 (부호를 뒤집어서라도) 제약을 만족하면 1, Q의 열 부호를 고친다
// PH: 지평별 MA 계수를 세로로 쌓은 행렬 (h=0 블록이 단위행렬)
real scalar signR(real matrix Q, real matrix P, real matrix PH, real matrix SR, real scalar ns)
{
    real scalar n, j, s, r, ok, good
    real colvector c, v
    n = rows(P)
    for (j=1; j<=ns; j++) {
        ok = 0
        for (s=1; s>=-1; s=s-2) {
            c = s * (P * Q[., j])
            good = 1
            for (r=1; r<=rows(SR); r++) {
                if (SR[r,1] != j) continue
                v = PH[|SR[r,3]*n+1, 1 \ (SR[r,3]+1)*n, n|] * c
                if (SR[r,4] * v[SR[r,2]] <= 0) {
                    good = 0
                    break
                }
            }
            if (good == 1) {
                ok = s
                break
            }
        }
        if (ok == 0) return(0)
        Q[., j] = ok * Q[., j]
    }
    return(1)
}

// Type A: 충격 j의 기여가 다른 충격 각각의 기여, 그리고 글로벌 기여 g보다 크다 (절댓값)
real scalar typeA(real rowvector L, real colvector e, real scalar j, real scalar g)
{
    real rowvector c
    real scalar a
    c = abs(L :* e')
    a = c[j]
    c[j] = -1
    return(a >= max(c) & a >= abs(g))
}

// Type A 통과확률 (A0, A+, Q 고정, 해당 월 충격만 N(0,I)에서 시뮬레이션)
// 부호 조건은 절댓값과 독립이라 확률이 1/2로 곱해질 뿐이므로 뺐다. 상수라 가중치 비율에 영향 없음
// gr: 글로벌 혁신이 해당 한국 변수에 주는 계수 (C0 행 × chol(Σ*)). 글로벌 블록이면 J(1,0,.)
real scalar pA(real rowvector L, real scalar j, real scalar M, real rowvector gr)
{
    real matrix C
    real colvector a, ok
    C = abs(rnormal(M, cols(L), 0, 1) :* L)
    a = C[., j]
    C[., j] = J(M, 1, -1)
    ok = a :>= rowmax(C)
    if (cols(gr) > 0) ok = ok :* (a :>= abs(rnormal(M, cols(gr), 0, 1) * gr'))
    return(mean(ok))
}

// 글로벌 충격의 13변수 IRF. 행 = 지평, 열 = 글로벌 7 + 한국 6
real matrix irfG(real colvector a, real matrix AS, real matrix CS, real matrix DS, real scalar p, real scalar q, real scalar H)
{
    real scalar ng, nk, h, l
    real matrix RG, RK
    ng = rows(a)
    nk = cols(DS)
    RG = J(H+1, ng, 0)
    RK = J(H+1, nk, 0)
    RG[1, .] = a'
    for (h=0; h<=H; h++) {
        for (l=1; l<=min((h, p)); l++) {
            RG[h+1, .] = RG[h+1, .] + (AS[|(l-1)*ng+1, 1 \ l*ng, ng|] * RG[h+1-l, .]')'
        }
        for (l=0; l<=min((h, q)); l++) {
            RK[h+1, .] = RK[h+1, .] + (CS[|l*nk+1, 1 \ (l+1)*nk, ng|] * RG[h+1-l, .]')'
        }
        for (l=1; l<=min((h, p)); l++) {
            RK[h+1, .] = RK[h+1, .] + (DS[|(l-1)*nk+1, 1 \ l*nk, nk|] * RK[h+1-l, .]')'
        }
    }
    return((RG, RK))
}

// 가중 분위수
real scalar wq(real colvector x, real colvector w, real scalar pr)
{
    real colvector o, cw, k
    o  = order(x, 1)
    cw = runningsum(w[o]) :/ sum(w)
    k  = selectindex(cw :>= pr)
    return(x[o[k[1]]])
}

// Fry-Pagan 중앙값 목표 모형: 가중 중앙값 IRF에 가장 가까운 채택 모형 번호
real scalar fpidx(real matrix IR, real colvector w)
{
    real rowvector med, sd
    real colvector dist, ii
    real matrix ww
    real scalar c, m
    med = J(1, cols(IR), .)
    sd  = J(1, cols(IR), .)
    for (c=1; c<=cols(IR); c++) {
        med[c] = wq(IR[., c], w, 0.5)
        m      = sum(w :* IR[., c]) / sum(w)
        sd[c]  = sqrt(sum(w :* (IR[., c] :- m):^2) / sum(w))
    }
    sd = sd :+ (sd :== 0)
    dist = rowsum(((IR :- med) :/ sd):^2)
    minindex(dist, 1, ii, ww)
    return(ii[1])
}

// IRF 요약: 행 = (변수, 지평), 열 = 변수, h, q16, q50, q84, FP 모형
real matrix irfsum(real matrix IR, real colvector w, real scalar nv, real scalar H, real scalar jfp, real scalar voff)
{
    real matrix S
    real scalar i, h, c, r
    S = J((H+1)*nv, 6, .)
    r = 0
    for (i=1; i<=nv; i++) {
        for (h=0; h<=H; h++) {
            r = r + 1
            c = h*nv + i
            S[r, .] = (i+voff, h, wq(IR[., c], w, 0.16), wq(IR[., c], w, 0.50), wq(IR[., c], w, 0.84), IR[jfp, c])
        }
    }
    return(S)
}

// 채택 추출별 충격계열을 긴 형태로
real matrix longdraws(real matrix E1, real matrix E2, real matrix E3, real colvector w, real colvector dd, real colvector md)
{
    real scalar n, Tr
    real matrix X
    n  = rows(E1)
    Tr = cols(E1)
    X  = vec(J(Tr, 1, 1) * (1..n)), vec(J(Tr, 1, 1) * w'), vec(J(Tr, 1, 1) * dd'), vec(md * J(1, n, 1))
    X  = X, vec(E1')
    if (rows(E2) > 0) X = X, vec(E2')
    if (rows(E3) > 0) X = X, vec(E3')
    return(X)
}

void todata(real matrix X, string rowvector nm)
{
    st_addobs(rows(X))
    (void) st_addvar("double", nm)
    st_store(., nm, X)
}

end


* 4. Estimation & Identification

timer clear 1
timer on 1

mata:
p    = `p'
q    = `q'
H    = `H'
nd   = `nd'
Rk   = `Rk'
Rg   = `Rg'
maxk = `maxk'
M    = `M'

SRK = st_matrix("SRK")
SRG = st_matrix("SRG")

YG0 = st_data(., "lusip lchn loil us2y ebp lvix lusepu")
YK0 = st_data(., "lip lcpi kr_call spread lfx lkrepu")
DM0 = st_data(., "d2020m3 d2020m4 d2020m5 d2020m6")
MD0 = st_data(., "mdate")
T   = rows(YG0)
ng  = cols(YG0)
nk  = cols(YK0)
ndm = cols(DM0)

// 유효표본 p+1~T. 글로벌 식: [상수, 더미, 글로벌 시차 1~p]
// 한국 식: [상수, 더미, 글로벌 시차 0~q, 한국 시차 1~p]
rr = (p+1::T)
YG = YG0[rr, .]
YK = YK0[rr, .]
md = MD0[rr]
Tr = rows(YG)
XG = J(Tr, 1, 1), DM0[rr, .]
for (l=1; l<=p; l++) XG = XG, YG0[rr :- l, .]
XK = J(Tr, 1, 1), DM0[rr, .]
for (l=0; l<=q; l++) XK = XK, YG0[rr :- l, .]
for (l=1; l<=p; l++) XK = XK, YK0[rr :- l, .]
kg = cols(XG)
kk = cols(XK)
printf("\n유효표본 %g개월 (%s ~ %s), 식당 계수: 글로벌 %g, 한국 %g\n", Tr, strofreal(md[1], "%tm"), strofreal(md[Tr], "%tm"), kg, kk)

// 서사제약 시점의 행 번호
// it의 순서: 1 U1, 2 U2, 3 U3, 4 F1, 5 F2, 6~13 G1~G8
tn = ("tU1", "tU2", "tU3", "tF1", "tF2", "tG1", "tG2", "tG3", "tG4", "tG5", "tG6", "tG7", "tG8")
it = J(1, cols(tn), .)
for (j=1; j<=cols(tn); j++) {
    k = selectindex(md :== st_numscalar(tn[j]))
    if (rows(k) == 0) _error("서사제약 시점이 유효표본 밖에 있다")
    it[j] = k[1]
}

// 블록별 OLS와 확산 NIW 사후분포 모수 (Zha 1999: 블록 재귀라 우도가 분리된다)
iXG = invsym(XG' * XG)
BG0 = iXG * XG' * YG
SG0 = (YG - XG*BG0)' * (YG - XG*BG0)
iXK = invsym(XK' * XK)
BK0 = iXK * XK' * YK
SK0 = (YK - XK*BK0)' * (YK - XK*BK0)
LXG = cholesky(iXG)
LXK = cholesky(iXK)
CSG = cholesky(invsym(SG0))
CSK = cholesky(invsym(SK0))
dfg = Tr - kg
dfk = Tr - kk

// 계수 위치
offC = 1 + ndm
offD = 1 + ndm + (q+1)*ng

rseed(20260929)

IKU = J(maxk, (H+1)*nk, .)
IKF = J(maxk, (H+1)*nk, .)
EKU = J(maxk, Tr, .)
EKF = J(maxk, Tr, .)
WK  = J(maxk, 1, .)
DK  = J(maxk, 1, .)
IGF = J(maxk, (H+1)*(ng+nk), .)
IGA = J(maxk, (H+1)*(ng+nk), .)
IGP = J(maxk, (H+1)*(ng+nk), .)
EGF = J(maxk, Tr, .)
EGA = J(maxk, Tr, .)
EGP = J(maxk, Tr, .)
WG  = J(maxk, 1, .)
DG  = J(maxk, 1, .)

trK = 0
sgK = 0
nK  = 0
trG = 0
sgG = 0
nG  = 0

for (d=1; d<=nd; d++) {

    if (nK >= maxk & nG >= maxk) break

    // 축약형 추출: Σ ~ IW(S, T-k), B | Σ ~ MN(B_ols, Σ ⊗ (X'X)^-1)
    Z  = rnormal(dfg, ng, 0, 1) * CSG'
    Sg = invsym(Z' * Z)
    Bg = BG0 + LXG * rnormal(kg, ng, 0, 1) * cholesky(Sg)'
    Z  = rnormal(dfk, nk, 0, 1) * CSK'
    Sk = invsym(Z' * Z)
    Bk = BK0 + LXK * rnormal(kk, nk, 0, 1) * cholesky(Sk)'

    Ug = YG - XG * Bg
    Ek = YK - XK * Bk
    Pg = cholesky(Sg)
    Pk = cholesky(Sk)
    Zg = Ug * luinv(Pg)'
    Zk = Ek * luinv(Pk)'
    // Zk의 t행 = (Pk^-1 e_t)'. 구조충격 j의 계열 = Zk * Q[., j]

    // 계수 블록: AS = A*_l, CS = C_l (l=0~q), DS = D_l
    AS = J(p*ng, ng, 0)
    for (l=1; l<=p; l++) AS[|(l-1)*ng+1, 1 \ l*ng, ng|] = Bg[|offC+(l-1)*ng+1, 1 \ offC+l*ng, ng|]'
    CS = J((q+1)*nk, ng, 0)
    for (l=0; l<=q; l++) CS[|l*nk+1, 1 \ (l+1)*nk, ng|] = Bk[|offC+l*ng+1, 1 \ offC+(l+1)*ng, nk|]'
    DS = J(p*nk, nk, 0)
    for (l=1; l<=p; l++) DS[|(l-1)*nk+1, 1 \ l*nk, nk|] = Bk[|offD+(l-1)*nk+1, 1 \ offD+l*nk, nk|]'
    C0 = CS[|1, 1 \ nk, ng|]

    // 한국 블록 MA 계수
    PHI = J((H+1)*nk, nk, 0)
    PHI[|1, 1 \ nk, nk|] = I(nk)
    for (h=1; h<=H; h++) {
        for (l=1; l<=min((h, p)); l++) {
            PHI[|h*nk+1, 1 \ (h+1)*nk, nk|] = PHI[|h*nk+1, 1 \ (h+1)*nk, nk|] + DS[|(l-1)*nk+1, 1 \ l*nk, nk|] * PHI[|(h-l)*nk+1, 1 \ (h-l+1)*nk, nk|]
        }
    }

    // 서사제약 시점의 글로벌 기여 (회전과 무관)
    gU1 = C0[6, .] * Ug[it[1], .]'
    gF1 = C0[4, .] * Ug[it[4], .]'

    // Spec A: 한국 블록 회전
    for (r=1; r<=Rk; r++) {
        if (nK >= maxk) break
        trK = trK + 1
        Q = haarQ(nk)
        if (signR(Q, Pk, PHI, SRK, 5) == 0) continue
        sgK = sgK + 1
        L0 = Pk * Q
        eU1 = Q' * Zk[it[1], .]'
        eU2 = Q' * Zk[it[2], .]'
        eU3 = Q' * Zk[it[3], .]'
        eF1 = Q' * Zk[it[4], .]'
        eF2 = Q' * Zk[it[5], .]'
        if (eU1[5] <= 0 | eU2[5] <= 0 | eU3[5] <= 0 | eF1[4] <= 0 | eF2[4] <= 0) continue
        if (typeA(L0[6, .], eU1, 5, gU1) == 0) continue
        if (typeA(L0[4, .], eF1, 4, gF1) == 0) continue

        nK = nK + 1
        om = pA(L0[6, .], 5, M, C0[6, .] * Pg) * pA(L0[4, .], 4, M, C0[4, .] * Pg)
        WK[nK] = 1 / max((om, 1/M))
        DK[nK] = d
        for (h=0; h<=H; h++) {
            LL = PHI[|h*nk+1, 1 \ (h+1)*nk, nk|] * L0
            IKU[|nK, h*nk+1 \ nK, (h+1)*nk|] = LL[., 5]'
            IKF[|nK, h*nk+1 \ nK, (h+1)*nk|] = LL[., 4]'
        }
        EKU[nK, .] = (Zk * Q[., 5])'
        EKF[nK, .] = (Zk * Q[., 4])'
    }

    // Spec B: 글로벌 블록 회전 (부호제약은 impact만 걸리므로 PH = I)
    for (r=1; r<=Rg; r++) {
        if (nG >= maxk) break
        trG = trG + 1
        Q = haarQ(ng)
        if (signR(Q, Pg, I(ng), SRG, 5) == 0) continue
        sgG = sgG + 1
        L0 = Pg * Q
        e1 = Q' * Zg[it[6], .]'
        e2 = Q' * Zg[it[7], .]'
        e3 = Q' * Zg[it[8], .]'
        e4 = Q' * Zg[it[9], .]'
        e5 = Q' * Zg[it[10], .]'
        e6 = Q' * Zg[it[11], .]'
        e7 = Q' * Zg[it[12], .]'
        e8 = Q' * Zg[it[13], .]'
        if (e1[4] <= 0 | e2[3] <= 0 | e3[4] <= 0 | e4[3] <= 0 | e4[4] <= 0 | e5[3] <= 0 | e5[4] <= 0) continue
        if (e6[4] <= 0 | e6[5] <= 0 | e7[5] <= 0 | e8[5] <= 0) continue
        if (typeA(L0[6, .], e3, 4, 0) == 0) continue
        if (typeA(L0[7, .], e7, 5, 0) == 0) continue

        nG = nG + 1
        om = pA(L0[6, .], 4, M, J(1, 0, .)) * pA(L0[7, .], 5, M, J(1, 0, .))
        WG[nG] = 1 / max((om, 1/M))
        DG[nG] = d
        IGF[nG, .] = vec(irfG(L0[., 3], AS, CS, DS, p, q, H)')'
        IGA[nG, .] = vec(irfG(L0[., 4], AS, CS, DS, p, q, H)')'
        IGP[nG, .] = vec(irfG(L0[., 5], AS, CS, DS, p, q, H)')'
        EGF[nG, .] = (Zg * Q[., 3])'
        EGA[nG, .] = (Zg * Q[., 4])'
        EGP[nG, .] = (Zg * Q[., 5])'
    }

    if (mod(d, 200) == 0) printf("  추출 %g / %g: 채택 A %g, B %g\n", d, nd, nK, nG)
    displayflush()
}

printf("\nSpec A (한국 블록): 회전 %g, 부호 통과 %g (%5.2f%%), 서사까지 채택 %g (회전당 %6.4f%%)\n", trK, sgK, 100*sgK/trK, nK, 100*nK/trK)
printf("Spec B (글로벌 블록): 회전 %g, 부호 통과 %g (%5.2f%%), 서사까지 채택 %g (회전당 %6.4f%%)\n", trG, sgG, 100*sgG/trG, nG, 100*nG/trG)
if (nK < 2 | nG < 2) _error("채택 모형이 너무 적다. nd, Rk, Rg를 늘리거나 서사제약을 점검할 것")

IKU = IKU[|1, 1 \ nK, .|]
IKF = IKF[|1, 1 \ nK, .|]
EKU = EKU[|1, 1 \ nK, .|]
EKF = EKF[|1, 1 \ nK, .|]
WK  = WK[|1 \ nK|]
DK  = DK[|1 \ nK|]
IGF = IGF[|1, 1 \ nG, .|]
IGA = IGA[|1, 1 \ nG, .|]
IGP = IGP[|1, 1 \ nG, .|]
EGF = EGF[|1, 1 \ nG, .|]
EGA = EGA[|1, 1 \ nG, .|]
EGP = EGP[|1, 1 \ nG, .|]
WG  = WG[|1 \ nG|]
DG  = DG[|1 \ nG|]

essK = sum(WK)^2 / sum(WK:^2)
essG = sum(WG)^2 / sum(WG:^2)
printf("중요도가중 유효표본(ESS): A %5.1f / %g, B %5.1f / %g\n", essK, nK, essG, nG)
printf("서로 다른 축약형 추출에서 나온 채택 모형: A %g, B %g\n", rows(uniqrows(DK)), rows(uniqrows(DG)))

// Fry-Pagan 모형: A는 U 충격, B는 UP* 충격의 IRF 기준
jA = fpidx(IKU, WK)
jB = fpidx(IGP, WG)

// IRF summary (변수 번호: 1~7 글로벌, 8~13 한국)
IRS = J((H+1)*nk, 1, 1), irfsum(IKU, WK, nk, H, jA, ng)
IRS = IRS \ (J((H+1)*nk, 1, 2), irfsum(IKF, WK, nk, H, jA, ng))
IRS = IRS \ (J((H+1)*(ng+nk), 1, 3), irfsum(IGA, WG, ng+nk, H, jB, 0))
IRS = IRS \ (J((H+1)*(ng+nk), 1, 4), irfsum(IGP, WG, ng+nk, H, jB, 0))
IRS = IRS \ (J((H+1)*(ng+nk), 1, 5), irfsum(IGF, WG, ng+nk, H, jB, 0))

// 시점별 충격 summary: 가중 중앙값, Pr(>0), Fry-Pagan 모형
SER = J(Tr, 10, .)
for (t=1; t<=Tr; t++) {
    SER[t, 1]  = wq(EKU[., t], WK, 0.5)
    SER[t, 2]  = sum(WK :* (EKU[., t] :> 0)) / sum(WK)
    SER[t, 3]  = EKU[jA, t]
    SER[t, 4]  = wq(EKF[., t], WK, 0.5)
    SER[t, 5]  = EKF[jA, t]
    SER[t, 6]  = wq(EGP[., t], WG, 0.5)
    SER[t, 7]  = sum(WG :* (EGP[., t] :> 0)) / sum(WG)
    SER[t, 8]  = EGP[jB, t]
    SER[t, 9]  = wq(EGA[., t], WG, 0.5)
    SER[t, 10] = wq(EGF[., t], WG, 0.5)
}
nmS = ("epsU_med", "prU_pos", "epsU_fp", "epsF_med", "epsF_fp", "epsUP_med", "prUP_pos", "epsUP_fp", "epsUF_med", "epsFg_med")
(void) st_addvar("double", nmS)
st_store(rr, nmS, SER)

st_numscalar("nK", nK)
st_numscalar("nG", nG)
st_numscalar("essK", essK)
st_numscalar("essG", essG)
end

timer off 1
timer list 1


* 5. Checkpoint

label var epsU_med  "국내 불확실성 충격 U: 가중 중앙값"
label var prU_pos   "Pr(U > 0)"
label var epsU_fp   "국내 불확실성 충격 U: Fry-Pagan 모형"
label var epsF_med  "국내 금융충격 F: 가중 중앙값"
label var epsF_fp   "국내 금융충격 F: Fry-Pagan 모형"
label var epsUP_med "글로벌 정책불확실성 충격 UP*: 가중 중앙값"
label var prUP_pos  "Pr(UP* > 0)"
label var epsUP_fp  "글로벌 정책불확실성 충격 UP*: Fry-Pagan 모형"
label var epsUF_med "글로벌 금융불확실성 충격 UF*: 가중 중앙값"
label var epsFg_med "글로벌 금융충격 F*: 가중 중앙값"

correlate epsU_med epsU_fp epsF_med epsUP_med epsUF_med epsFg_med
// epsU_med와 epsU_fp 상관이 0.9 미만이면 식별집합이 넓다는 뜻
// epsU와 epsUP의 상관은 0에 가까워야 한다 (block exogeneity)

list mdate epsU_med prU_pos epsU_fp if inlist(mdate, tm(2006m10), tm(2019m7), tm(2010m11)), noobs
	// hold-out 사건

list mdate epsU_med prU_pos if prU_pos > 0.9 & !missing(prU_pos), noobs
	// non-restricted, U 충격이 거의 확실히 양(+)인 달
	// 국내 사건과 맞는지 check

tsline epsU_med, yline(0) tline(2004m3 2016m11 2024m12, lpattern(solid) lcolor(gs10)) tline(2006m10 2019m7, lpattern(dash) lcolor(gs10)) tlabel(, format(%tmCY)) title("국내 불확실성 충격 U (가중 중앙값)") note("실선: 서사제약 시점, 점선: hold-out") name(g_epsU, replace)

save "../output/series_svar.dta", replace


* 6. IRF

preserve
clear
mata: todata(IRS, ("shock", "var", "h", "q16", "q50", "q84", "fp"))
label define shk 1 "U 국내 불확실성" 2 "F 국내 금융" 3 "UF* 글로벌 금융불확실성" 4 "UP* 글로벌 정책불확실성" 5 "F* 글로벌 금융"
label values shock shk
label define vv 1 "lusip" 2 "lchn" 3 "loil" 4 "us2y" 5 "ebp" 6 "lvix" 7 "lusepu" ///
    8 "lip" 9 "lcpi" 10 "kr_call" 11 "spread" 12 "lfx" 13 "lkrepu"
label values var vv
save "../output/irf_svar.dta", replace

twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 1 & var == 8, yline(0) legend(off) xlabel(0(12)48) title("U → 전산업생산") name(a1, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 1 & var == 9, yline(0) legend(off) xlabel(0(12)48) title("U → CPI") name(a2, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 1 & var == 12, yline(0) legend(off) xlabel(0(12)48) title("U → 원/달러") name(a3, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 2 & var == 8, yline(0) legend(off) xlabel(0(12)48) title("F → 전산업생산") name(a4, replace)
graph combine a1 a2 a3 a4, title("Spec A: 국내 충격") note("음영 16~84분위, 점선 가중 중앙값, 실선 Fry-Pagan 모형") name(g_irfA, replace)

twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 4 & var == 8, yline(0) legend(off) xlabel(0(12)48) title("UP* → 전산업생산") name(b1, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 4 & var == 13, yline(0) legend(off) xlabel(0(12)48) title("UP* → KR EPU") name(b2, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 3 & var == 8, yline(0) legend(off) xlabel(0(12)48) title("UF* → 전산업생산") name(b3, replace)
twoway (rarea q84 q16 h, color(gs13)) (line q50 h, lcolor(gs6) lpattern(dash)) (line fp h, lcolor(black)) ///
    if shock == 3 & var == 12, yline(0) legend(off) xlabel(0(12)48) title("UF* → 원/달러") name(b4, replace)
graph combine b1 b2 b3 b4, title("Spec B: 글로벌 불확실성 충격의 한국 파급") name(g_irfB, replace)
restore


* 7. Export shock sequences

preserve
clear
mata: todata(longdraws(EKU, EKF, J(0, 0, .), WK, DK, md), ("draw", "w", "rfdraw", "mdate", "epsU", "epsF"))
format mdate %tm
compress
save "../output/shocks_A.dta", replace
restore

preserve
clear
mata: todata(longdraws(EGP, EGA, EGF, WG, DG, md), ("draw", "w", "rfdraw", "mdate", "epsUP", "epsUF", "epsFg"))
format mdate %tm
compress
save "../output/shocks_B.dta", replace
restore



* check point
* (1) 서사제약 leave-one-out: tU1~tF2를 하나씩 주석 처리하고 epsU_med, IRF 변화를 본다
* (2) hold-out(2006M10, 2019M7)의 Pr(U>0)
* (3) q = 6, p = 4/12, 글로벌 Type A 4개, 스프레드 BBB- 교체 (docs/02 §9 R1~R11)
