//+------------------------------------------------------------------+
//|                                       PositionSizeCalculator.mq5 |
//| 				                 Copyright © 2012-2019, EarnForex.com |
//|                                     Based on panel by qubbit.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "EarnForex.com"
#property link      "https://www.earnforex.com/metatrader-indicators/Position-Size-Calculator/"
#property version   "2.22"
string    Version = "2.22";
#property indicator_chart_window
#property indicator_plots 0

#property description "Calculates position size based on account balance/equity,"
#property description "currency, currency pair, given entry level, stop-loss level,"
#property description "and risk tolerance (set either in percentage points or in base currency)."
#property description "Displays reward/risk ratio based on take-profit."
#property description "Shows total portfolio risk based on open trades and pending orders."
#property description "Calculates margin required for new position, allows custom leverage.\r\n"
#property description "WARNING: There is no guarantee that the output of this indicator is correct. Use at your own risk."

#include "PositionSizeCalculator.mqh";

// Default values for settings:
double EntryLevel = 0;
double StopLossLevel = 0;
double TakeProfitLevel = 0;
double MoneyRisk = 0;
bool CountPendingOrders = false;
bool IgnoreOrdersWithoutStopLoss = false;
bool HideSecondRisk = false;
bool ShowLines = true;
int MagicNumber = 0;
string ScriptCommentary = "";
bool DisableTradingWhenLinesAreHidden = false;
int MaxSlippage = 0;
int MaxSpread = 0;
int MaxEntrySLDistance = 0;
int MinEntrySLDistance = 0;
double MaxPositionSize = 0;
string Caption = "";

input bool ShowLineLabels = true; // ShowLineLabels: Show pip distance for TP/SL near lines?
input bool DrawTextAsBackground = false; // DrawTextAsBackground: Draw label objects as background?
input bool PanelOnTopOfChart = true; // PanelOnTopOfChart: Draw chart as background?
input bool HideAccSize = false; // HideAccSize: Hide account size?
input bool ShowPipValue = false; // ShowPipValue: Show pip value?
input color sl_label_font_color = clrLime; // SL Label  Color
input color tp_label_font_color = clrYellow; // TP Label Font Color
input uint font_size = 13; // Labels Font Size
input string font_face = "Courier"; // Labels Font Face
input color entry_line_color = clrBlue; // Entry Line Color
input color stoploss_line_color = clrLime; // Stop-Loss Line Color
input color takeprofit_line_color = clrYellow; // Take-Profit Line Color
input ENUM_LINE_STYLE entry_line_style = STYLE_SOLID; // Entry Line Style
input ENUM_LINE_STYLE stoploss_line_style = STYLE_SOLID; // Stop-Loss Line Style
input ENUM_LINE_STYLE takeprofit_line_style = STYLE_SOLID; // Take-Profit Line Style
input uint entry_line_width = 1; // Entry Line Width
input uint stoploss_line_width = 1; // Stop-Loss Line Width
input uint takeprofit_line_width = 1; // Take-Profit Line Width
input double Risk = 1; // Risk: Initial risk tolerance in percentage points
input ENTRY_TYPE EntryType = Instant; // EntryType: Instant or Pending.
input double Commission = 0; // Commission: Default one-way commission size.
input string Commentary = ""; // Commentary: Default order comment.
input int DefaultSL = 0; // DefaultSL: Deafault stop-loss value, in broker's pips.
input int DefaultTP = 0; // DefaultTP: Deafault take-profit value, in broker's pips.
input ENUM_TIMEFRAMES DefaultATRTimeframe = PERIOD_CURRENT; // DefaultATRTimeframe: Deafault timeframe for ATR.
input double TP_Multiplier = 1; // TP Multiplier for SL value, appears in Take-profit button.
input bool UseCommissionToSetTPDistance = false; // UseCommissionToSetTPDistance: For TP button.
input bool ShowSpread = false; // ShowSpread: If true, shows current spread in window caption.
input double AdditionalFunds = 0; // AdditionalFunds: Added to account balance for risk calculation.
input bool UseFixedSLDistance = false; // UseFixedSLDistance: SL distance in points instead of level.
input bool UseFixedTPDistance = false; // UseFixedTPDistance: TP distance in points instead of level.
input bool UseCFDMultiplier = false; // UseCFDMultiplier: Multiply UnitCost by ContractSize for CFDs.
input bool ShowATROptions = false; // ShowATROptions: If true, SL and TP can be set via ATR.

QCPositionSizeCalculator ExtDialog;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Position Size Calculator" + IntegerToString(ChartID()));
   
   Caption = "Position Size Calculator (ver. " + Version + ")";

   if (!ExtDialog.LoadSettingsFromDisk())
   {
      sets.EntryType = EntryType; // If Instant, Entry level will be updated to current Ask/Bid price automatically; if Pending, Entry level will remain intact and StopLevel warning will be issued if needed.
      sets.EntryLevel = EntryLevel;
      sets.StopLossLevel = StopLossLevel;
      sets.TakeProfitLevel = TakeProfitLevel; // Optional
      sets.Risk = Risk; // Risk tolerance in percentage points
      sets.MoneyRisk = MoneyRisk; // Risk tolerance in account currency
      sets.CommissionPerLot = Commission; // Commission charged per lot (one side) in account currency.
      sets.UseMoneyInsteadOfPercentage = false;
      sets.RiskFromPositionSize = false;
      sets.AccountButton = Balance;
      sets.CountPendingOrders = CountPendingOrders; // If true, portfolio risk calculation will also involve pending orders.
      sets.IgnoreOrdersWithoutStopLoss = IgnoreOrdersWithoutStopLoss; // If true, portfolio risk calculation will skip orders without stop-loss.
      sets.HideAccSize = HideAccSize; // If true, account size line will not be shown.
      sets.HideSecondRisk = HideSecondRisk; // If true, second risk line will not be shown.
      sets.ShowLines = ShowLines;
      sets.SelectedTab = MainTab;
      sets.MagicNumber = MagicNumber;
      sets.ScriptCommentary = Commentary;
      sets.DisableTradingWhenLinesAreHidden = DisableTradingWhenLinesAreHidden;
      sets.MaxSlippage = MaxSlippage;
      sets.MaxSpread = MaxSpread;
      sets.MaxEntrySLDistance = MaxEntrySLDistance;
      sets.MinEntrySLDistance = MinEntrySLDistance;
      sets.MaxPositionSize = MaxPositionSize;
      sets.StopLoss = 0;
      sets.TakeProfit = 0;
      sets.TradeType = Buy;
      sets.SubtractPendingOrders = false;
      sets.SubtractPositions = false;
      sets.ATRPeriod = 14;
      sets.ATRMultiplierSL = 0;
      sets.ATRTimeframe = DefaultATRTimeframe;
      if ((int)sets.ATRTimeframe == 0)sets.ATRTimeframe = (ENUM_TIMEFRAMES)_Period;
   }
   
	if (!ExtDialog.Create(0, Caption, 0, 20, 20)) return(-1);
	ExtDialog.IniFileLoad();
   ExtDialog.Run();   

   Initialization();
   
   // Brings panel on top of other objects without actual maximization of the panel.
   ExtDialog.HideShowMaximize(false);

   EventSetTimer(1);
   
   if (ShowATROptions) ExtDialog.InitATR();

   return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason)
{
	ObjectDelete(0, "StopLossLabel");
	ObjectDelete(0, "TakeProfitLabel");
   if ((reason == REASON_REMOVE) || (reason == REASON_PARAMETERS))
   {
      // It is deinitialization due to input parameters change - save current parameters values (that are also changed via panel) to global variables.
      if (reason == REASON_PARAMETERS)
      {
         GlobalVariableSet("PSC-" + IntegerToString(ChartID()) + "-Parameters", 1);
         ExtDialog.SaveSettingsOnDisk();
      }
      else ExtDialog.DeleteSettingsFile();
      ObjectDelete(0, "EntryLine");
      ObjectDelete(0, "StopLossLine");
      ObjectDelete(0, "TakeProfitLine");
      if (!FileDelete(ExtDialog.IniFileName() + ExtDialog.IniFileExt())) Print("Failed to delete PSC panel's .ini file: ", GetLastError());
   }  
   else ExtDialog.SaveSettingsOnDisk();  
   
   ExtDialog.Destroy(reason);
   ChartRedraw();

   EventKillTimer();
}
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ExtDialog.RefreshValues();
	return(rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Remember the panel's location to have the same location for minimized and maximized states.
   if ((id == CHARTEVENT_CUSTOM + ON_DRAG_END) && (lparam == -1))
   {
      ExtDialog.remember_top = ExtDialog.Top();
      ExtDialog.remember_left = ExtDialog.Left();
   }

	// Call Panel's event handler only if it is not a CHARTEVENT_CHART_CHANGE - workaround for minimization bug on chart switch.
	if (id != CHARTEVENT_CHART_CHANGE)
	{
		ExtDialog.OnEvent(id, lparam, dparam, sparam);
		if (id >= CHARTEVENT_CUSTOM) ChartRedraw();
	}

   // Recalculate on chart changes, clicks, and certain object dragging.
   if ((id == CHARTEVENT_CLICK) || (id == CHARTEVENT_CHART_CHANGE) ||
   ((id == CHARTEVENT_OBJECT_DRAG) && ((sparam == "EntryLine") || (sparam == "StopLossLine") || (sparam == "TakeProfitLine"))))
   {
      // Moving lines when fixed SL/TP distance is enabled. Should set a new fixed SL/TP distance.
      if ((id == CHARTEVENT_OBJECT_DRAG) && (sparam == "StopLossLine") && (UseFixedSLDistance)) ExtDialog.UpdateFixedSL();
      if ((id == CHARTEVENT_OBJECT_DRAG) && (sparam == "TakeProfitLine") && (UseFixedTPDistance)) ExtDialog.UpdateFixedTP();
      if (id != CHARTEVENT_CHART_CHANGE) ExtDialog.RefreshValues();
		if (ExtDialog.Top() < 0) ExtDialog.Move(ExtDialog.Left(), 0);
      int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      if (ExtDialog.Top() > chart_height) ExtDialog.Move(ExtDialog.Left(), chart_height - ExtDialog.Height());
      int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      if (ExtDialog.Left() > chart_width) ExtDialog.Move(chart_width - ExtDialog.Width(), ExtDialog.Top());
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
   ExtDialog.RefreshValues();
   ChartRedraw();     
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   ExtDialog.RefreshValues();
   ChartRedraw();   
}
//+------------------------------------------------------------------+