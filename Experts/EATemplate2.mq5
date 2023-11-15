//+------------------------------------------------------------------+
//|                                                  EATemplate2.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2023, Geraked"
#property link        "https://github.com/geraked"
#property version     "1.0"
#property description "A strategy using..."
#property description ""

#include <EAUtils.mqh>

input group "Indicator Parameters"
input int P1 = 0;

input group "General"
input bool MultipleSymbol = false; // Multiple Symbols
input string Symbols = ""; // Symbols
input double TPCoef = 1.0; // TP Coefficient
input int SLLookback = 10; // SL Lookback
input int SLDev = 60; // SL Deviation (Points)
input bool CloseOrders = true; // Check For Closing Conditions
input bool CloseOnProfit = false; // Close Only On Profit
input bool Reverse = false; // Reverse Signal

input group "Risk Management"
input double Risk = 1.0; // Risk (%)
input bool IgnoreSL = false; // Ignore SL
input bool IgnoreTP = false; // Ignore TP
input bool Trail = false; // Trailing Stop
input double TrailingStopLevel = 50; // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0; // Equity Drawdown Limit (%) (0: Disable)

input group "Strategy: Grid"
input bool Grid = false; // Grid Enable
input double GridVolMult = 1.0; // Grid Volume Multiplier
input double GridTrailingStopLevel = 0; // Grid Trailing Stop Level (%) (0: Disable)
input int GridMaxLvl = 20; // Grid Max Levels

input group "News"
input bool News = false; // News Enable
input ENUM_NEWS_IMPORTANCE NewsImportance = NEWS_IMPORTANCE_MEDIUM; // News Importance
input int NewsMinsBefore = 60; // News Minutes Before
input int NewsMinsAfter = 60; // News Minutes After
input int NewsStartYear = 0; // News Start Year to Fetch for Backtesting (0: Disable)

input group "Open Position Limit"
input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = true; // Allow Having Multiple Open Positions
input double MarginLimit = 300; // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1; // Spread Limit (Points) (-1: Disable)

input group "Auxiliary"
input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30; // Timer Interval (Seconds)
input ulong MagicNumber = 1000; // Magic Number

GerEA ea;
datetime tc;
datetime lastCandles[];
string symbols[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal(string s) {

    return false;

    double point = SymbolInfoDouble(s, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);
    double in = Ask(s);
    int il = iLowest(s, 0, MODE_LOW, SLLookback);
    double sl = iLow(s, 0, il) - SLDev * point;
    double d = MathAbs(in - sl);
    double tp = in + TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.BuyOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal(string s) {

    return false;

    double point = SymbolInfoDouble(s, SYMBOL_POINT);
    int digits = (int) SymbolInfoInteger(s, SYMBOL_DIGITS);
    double in = Bid(s);
    int ih = iHighest(s, 0, MODE_HIGH, SLLookback);
    double sl = iHigh(s, 0, ih) + SLDev * point;
    double d = MathAbs(in - sl);
    double tp = in - TPCoef * d;
    bool isl = Grid ? true : IgnoreSL;

    ea.SellOpen(sl, tp, isl, IgnoreTP, DoubleToString(d, digits), s);
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose(string s) {
    if (CloseOnProfit) {
        double p = getProfit(ea.GetMagic(), s) - calcCost(ea.GetMagic(), s);
        if (p < 0) return;
    }
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    ea.Init();
    ea.SetMagic(MagicNumber);
    ea.risk = Risk * 0.01;
    ea.reverse = Reverse;
    ea.trailingStopLevel = TrailingStopLevel * 0.01;
    ea.gridVolMult = GridVolMult;
    ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    ea.gridMaxLvl = GridMaxLvl;
    ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    ea.slippage = Slippage;
    ea.news = News;
    ea.newsImportance = NewsImportance;
    ea.newsMinsBefore = NewsMinsBefore;
    ea.newsMinsAfter = NewsMinsAfter;

    if (News) fetchCalendarFromYear(NewsStartYear);
    fillSymbols(symbols, MultipleSymbol, Symbols);
    ArrayResize(lastCandles, ArraySize(symbols));
    EventSetTimer(TimerInterval);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeCurrent();
    if (tc == oldTc) return;

    if (Trail) ea.CheckForTrail();
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) ea.CheckForGrid();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    int n = ArraySize(symbols);
    for (int i = 0; i < n; i++) {
        string s = symbols[i];

        datetime t = iTime(s, 0, 0);
        if (lastCandles[i] == t) continue;
        else lastCandles[i] = t;

        if (CloseOrders) CheckClose(s);

        if (!OpenNewPos) break;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) break;
        if (!MultipleOpenPos && ea.PosTotal() > 0) break;
        if (SpreadLimit != -1 && Spread(s) > SpreadLimit) continue;
        if (positionsTotalMagic(ea.GetMagic(), s) > 0) continue;

        if (BuySignal(s)) continue;
        SellSignal(s);
    }
}

//+------------------------------------------------------------------+
