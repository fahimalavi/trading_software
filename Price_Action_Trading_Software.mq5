//+------------------------------------------------------------------+
//|                                    MyPriceActionManual_BRENT.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Fahim A.(also known as Norman Black)"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\AccountInfo.mqh>
#include<Trade\Trade.mqh>
//--- object for performing trade operations
CTrade  trade;
CAccountInfo account;

const double C_LOT_SIZE = 0.5;

const double c_trading_offset = 0.0003;
const double c_SL_OFFESET = 0.002;

// Make sure level should be at least 0.6%
//const double level[]={75.4, 76.0, 76.4, 77};        // Brent

const int C_LEVEL_DEPTH = 9;
const double level[]={87.23, 87.53, 87.83, 88.02, 88.23, 88.55, 88.8, 89.1, 89.55, 89.8};      // Amazon 12-12-22
int level_success[]={0, 0, 0, 0, 0, 0, 0, 0, 0};
int level_failure[]={0, 0, 0, 0, 0, 0, 0, 0, 0};

//const int C_LEVEL_DEPTH = 10;
//const double level[]={91.13, 91.55, 91.76, 92.12, 92.48, 92.82, 93.22, 93.72, 94.57, 95.82};      // Amazon 14-12-22
//int level_success[]={0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
//int level_failure[]={0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
double profit_val;
int selected_level = -1;
int forbidden_level = -1; // it is the one you should avoid, drop few times before another level is hit
const int c_buying_condition_met_size = 3;
const int c_buying_condition_valid_size = 3;

// MA-3/7, PSAR, RSI-3/7, PSAR-RSI-Buy, PSAR-RSI-Sell
const int c_number_of_indicators=6;
int num_trades_triggered_per_ind[]={0,0,0,0,0,0};
int num_successful_trades_triggered_per_ind[] = {0,0,0,0,0,0};
bool current_trade_triggered_per_ind[] = {false, false, false, false, false,false};

const int PSAR_RSI_WEIGHT=3;

int num_of_profitable_trd = 0;
int num_of_non_profitable_trd = 0;

int ma3_handle = 0;
int ma7_handle = 0;
int ma20_handle = 0;
int ma50_handle = 0;
const int c_MA_Size=1;
double ma3[];
double ma7[];
double ma20[];
double ma50[];

const double C_RSI_BUYING = 50.0;
const double C_RSI_SELLING = 50.0;
int rsi3_handle = 0;
int rsi7_handle = 0;
const int c_rsi_size=3;
const double rsi_trading_delta = 0.1;
double rsi3_arr[];
double rsi7_arr[];

int psar_handle = 0;
double psar_arr[];
const int c_psar_size=7; // Don't place less than 4

int macd_handle=0;
double macd_arr[];
const int c_macd_size=3;
const int c_slow_period=10;
const int c_fast_period=5;
const int c_signal_period=3;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ma3_handle = iMA(_Symbol,PERIOD_CURRENT,3,0,MODE_SMA,PRICE_CLOSE);
   ma7_handle = iMA(_Symbol,PERIOD_CURRENT,7,0,MODE_SMA,PRICE_CLOSE);
   //ma20_handle = iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_SMA,PRICE_CLOSE);
   //ma50_handle = iMA(_Symbol,PERIOD_CURRENT,50,0,MODE_SMA,PRICE_CLOSE);
   
   rsi3_handle = iRSI(_Symbol,PERIOD_CURRENT,3,PRICE_CLOSE);   
   rsi7_handle = iRSI(_Symbol,PERIOD_CURRENT,7,PRICE_CLOSE);
   
   psar_handle = iSAR(_Symbol, PERIOD_CURRENT,0.02, 0.2);
   
   macd_handle = iMACD(_Symbol,PERIOD_CURRENT,c_fast_period,c_slow_period,c_signal_period,PRICE_CLOSE);
//--- object for working with the account
//--- receiving the account number, the Expert Advisor is launched at
   long login=account.Login();
   Print("Login=",login);
//--- clarifying account type
   ENUM_ACCOUNT_TRADE_MODE account_type=account.TradeMode();
//--- if the account is real, the Expert Advisor is stopped immediately!
   if(account_type==ACCOUNT_TRADE_MODE_REAL)
     {
      MessageBox("Trading on a real account is forbidden, disabling","The Expert Advisor has been launched on a real account!");
      return(-1);
     }
//--- displaying the account type    
   Print("Account type: ",EnumToString(account_type));
//--- clarifying if we can trade on this account
   if(account.TradeAllowed())
      Print("Trading on this account is allowed");
   else
      Print("Trading on this account is forbidden: you may have entered using the Investor password");
//--- clarifying if we can use an Expert Advisor on this account
   if(account.TradeExpert())
      Print("Automated trading on this account is allowed");
   else
      Print("Automated trading using Expert Advisors and scripts on this account is forbidden");
//--- clarifying if the permissible number of orders has been set
   int orders_limit=account.LimitOrders();
   if(orders_limit!=0)Print("Maximum permissible amount of active pending orders: ",orders_limit);
//--- displaying company and server names
   Print(account.Company(),": server ",account.Server());
//--- displaying balance and current profit on the account in the end
   profit_val = account.Balance();
   Print("Balance=",account.Balance(),"  Profit=",account.Profit(),"   Equity=",account.Equity());
   Print("Margin=",account.Margin(),"FreeMargin=", account.FreeMargin());
   Print(__FUNCTION__,"  completed"); //---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print("Profitable trades=", num_of_profitable_trd, " , Non-Profitable trades=", num_of_non_profitable_trd);
   PrintFormat("MA-3/7 indicator based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[0], num_successful_trades_triggered_per_ind[0]);
   PrintFormat("PSAR indicator based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[1], num_successful_trades_triggered_per_ind[1]);
   PrintFormat("RSI-3/7 indicator based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[2], num_successful_trades_triggered_per_ind[2]);
   PrintFormat("PSAR-RSI_BUYING based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[3], num_successful_trades_triggered_per_ind[3]);
   PrintFormat("PSAR-RSI_SELLING based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[4], num_successful_trades_triggered_per_ind[4]);
   PrintFormat("PSAR-MACD based trades=%d, Number of success = %d", 
               num_trades_triggered_per_ind[5], num_successful_trades_triggered_per_ind[5]);
               
   for(int i=0; i<C_LEVEL_DEPTH; i++)
   {
      PrintFormat("Level:%f, Profitable_Trades=%d, Loss_Trades=%d", level[i],level_success[i],level_failure[i]);
   }
}
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(PositionsTotal() == 0)
   {
      calculate_profit();
            
      if(true)
      {
         for(int i=0; i<(C_LEVEL_DEPTH-1); i++)
         {
            //if(not_a_continuous_failure_level(i) == true)
            {
               if(buy_price_action(i) == true)
               {
                  selected_level = i;
                  break;
               }
            }
         }
      }
   }
   else
   {
      is_buying_condition_valid();      
   }
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
//--- get the current values 
   //int curr_orders=OrdersTotal(); 
   //int curr_positions=PositionsTotal(); 
   //int curr_deals=HistoryDealsTotal(); 
   //int curr_history_orders=HistoryOrdersTotal(); 
   
   Print("OnTrade called");
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
  {
   //PrintFormat("OnTradeTransaction called: TrasactionType:%d, OrderType:%d, OrderState:%d, DealType:%d"
   //            , trans.type, trans.order_type, trans.order_state, trans.deal_type);  
   Print("OnTradeTransaction called");
  }
//+------------------------------------------------------------------+


bool buy_price_action(int index)
{
   bool return_val = false;
   double ask_value = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid_value = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   calculate_indicators();
   
   if((ask_value < (level[index] * (1+c_trading_offset)) && ask_value > (level[index] * (1-c_trading_offset)))
      && buying_condition_met(ask_value,index))
   {
      // Give relief to forbidden level
      if(forbidden_level >= 0)
      {
         level_failure[forbidden_level] = level_failure[forbidden_level] -1;
         forbidden_level = -1;
      }
   //--- 1. example of buying at the current symbol
      if(!trade.Buy(C_LOT_SIZE,_Symbol,ask_value, ask_value*(1-c_SL_OFFESET), level[index+1]))
        {
         //--- failure message
         Print("Buy() method failed. Return code=",trade.ResultRetcode(),
               ". Code description: ",trade.ResultRetcodeDescription());
        }
      else
        {
         Print("Buy() method executed successfully. Return code=",trade.ResultRetcode(),
               " (",trade.ResultRetcodeDescription(),")");
         return_val = true;
        }
   }
   return return_val;
}

void calculate_profit()
{
   if(profit_val > account.Balance())
   {
      Print("Loss detected");
      level_failure[selected_level] = level_failure[selected_level] + 1;
      num_of_non_profitable_trd++;
   }
   else if(profit_val < account.Balance())
   {
      level_success[selected_level] = level_success[selected_level] + 1;
      Print("Profit detected");
      num_of_profitable_trd++;
      
      for(int i=0; i<c_number_of_indicators; i++)
      {
         if(current_trade_triggered_per_ind[i] == true)
         {
            num_successful_trades_triggered_per_ind[i] = num_successful_trades_triggered_per_ind[i] + 1;
         }
      }
   }
   profit_val = account.Balance();
}

void calculate_indicators()
{
   CopyBuffer(ma3_handle,0,0,c_MA_Size,ma3);
   CopyBuffer(ma7_handle,0,0,c_MA_Size,ma7);
   //CopyBuffer(ma20_handle,0,0,c_MA_Size,ma20);
   //CopyBuffer(ma50_handle,0,0,c_MA_Size,ma50);
   
   CopyBuffer(rsi3_handle,0,0,c_rsi_size,rsi3_arr);   
   CopyBuffer(rsi7_handle,0,0,c_rsi_size,rsi7_arr);
   
   CopyBuffer(psar_handle,0,0,c_psar_size,psar_arr); 
   CopyBuffer(macd_handle,0,0,c_macd_size,macd_arr);
}

void print_indicators()
{    
   PrintFormat("MA3:%f, MA7:%f, RSI3:%f, RSI7:%f PSAR:%f",
        ma3[c_MA_Size-1],ma7[c_MA_Size-1],rsi3_arr[c_rsi_size-1],rsi7_arr[c_rsi_size-1], psar_arr[c_psar_size-1]);
   PrintFormat("Latest RSI > last 2 RSI ind. -> RSI3[0]=%f, RSI3[1]=%f, RSI3[2]=%f",
        rsi3_arr[0],rsi3_arr[1],rsi3_arr[2]);
   PrintFormat("macd[2]:%f, macd[1]:%f, macd[0]:%f (%d/%d)", macd_arr[c_macd_size-1], macd_arr[c_macd_size-2], macd_arr[c_macd_size-3],
      macd_arr[c_macd_size-1] >= macd_arr[c_macd_size-2], macd_arr[c_macd_size-1] >= macd_arr[c_macd_size-3]);

}

void print_indicator_per_tick(bool& trade_triggered[])
{
   PrintFormat("MA-3/7:%d, PSAR:%d, RSI-3/7:%d, PSAR-RSI-Buy:%d, PSAR-RSI-Sell:%d, MACD:%d",
         trade_triggered[0],trade_triggered[1],trade_triggered[2],
         trade_triggered[3], trade_triggered[4], trade_triggered[5]);
}

bool buying_condition_met(double ask_value, int index)
{
   bool ret_val=false;
   int   num_indicator_met = 0;

   //if(ma3[0] < ask_value*(1+c_SL_OFFESET/2.0) && ma3[0] > ask_value*(1-c_SL_OFFESET/2.0))
   //{
   //   num_indicator_met++;
   //}
   if(is_moving_average_indicating_buying())
   {
      //num_indicator_met++;
      //current_trade_triggered_per_ind[0] = true;
   }
   else
   {
      current_trade_triggered_per_ind[0] = false;
   }
   if(is_PSAR_trade_buying_direction(ask_value))
   {
      //if(detect_early_psar(ask_value))
      {
         num_indicator_met++;
         current_trade_triggered_per_ind[1] = true;
      }
   }
   else
   {
      current_trade_triggered_per_ind[1] = false;
   }
   
   if(is_rsi_crossover_indicating_buying())
   {
      num_indicator_met++;
      current_trade_triggered_per_ind[2] = true;
   }
   else
   {
      current_trade_triggered_per_ind[2] = false;
   }
   
   if(is_PSAR_RSI_Buying_Direction(ask_value, index) == true)
   {
      num_indicator_met+=PSAR_RSI_WEIGHT;
      current_trade_triggered_per_ind[3] = true;
   }
   else
   {
      current_trade_triggered_per_ind[3] = false;
   }
   
   if(is_PSAR_RSI_Selling_Direction(ask_value, index) == true)
   {
      num_indicator_met-=2;
      current_trade_triggered_per_ind[4] = true;
   }
   else
   {
      current_trade_triggered_per_ind[4] = false;
   }
   
   if(is_macd_bullish() == true)
   {
      num_indicator_met++;
      current_trade_triggered_per_ind[5] = true;
   }
   else
   {
      current_trade_triggered_per_ind[5] = false;
   }
   
   //if(detect_upwards_buying_RSI())
   //{
   //   num_indicator_met++;
   //   current_trade_triggered_per_ind[3] = true;
   //}
   //else
   //{
   //   current_trade_triggered_per_ind[3] = false;
   //}
   
   print_indicator_per_tick(current_trade_triggered_per_ind);
   
   if(num_indicator_met >= c_buying_condition_met_size)
   {
      ret_val = true;
      current_ind_trade_triggered();
      print_indicators();
   }
   else
   {
      PrintFormat("%f buying condition not met=>%d! MA-3/7:%d, PSAR:%d, RSI-3/7:%d, PSAR-RSI-Buy:%d, PSAR-RSI-Sell:%d, MACD:%d",
      level[index], num_indicator_met,current_trade_triggered_per_ind[0],current_trade_triggered_per_ind[1],current_trade_triggered_per_ind[2],
      current_trade_triggered_per_ind[3], current_trade_triggered_per_ind[4], current_trade_triggered_per_ind[5]);
   }
   return ret_val;
}

bool is_moving_average_indicating_buying()
{
   if(ma3[c_MA_Size-1] >= ma7[c_MA_Size-1])
   {
      return true;
   }
   else
   {
      return false;
   }
}

// Value can be ask or bid value
bool is_PSAR_trade_buying_direction(double value)
{
   if(psar_arr[c_psar_size-1] < value && psar_arr[c_psar_size-2] < value)
   {
      return true;
   }
   else
   {
      return false;
   }
}

bool is_rsi_crossover_indicating_buying()
{
   // RSI3 is greater than RSI7 and make sure that RSI3 is going down by 10% margin
   if(rsi3_arr[c_rsi_size-1] > rsi7_arr[c_rsi_size-1] && is_RSI3_increasing())
   {
      return true;
   }
   else
   {
      return false;
   }
}

// Not increasing and not stable
bool is_RSI3_decreasing()
{
   if((rsi3_arr[c_rsi_size-1] < rsi3_arr[c_rsi_size-2]) &&
   ((rsi3_arr[c_rsi_size-2]-rsi3_arr[c_rsi_size-1])/rsi3_arr[c_rsi_size-2] > rsi_trading_delta) &&
      ((rsi3_arr[c_rsi_size-3]-rsi3_arr[c_rsi_size-1])/rsi3_arr[c_rsi_size-3] > rsi_trading_delta)
   )
   {
      return true;
   }
   else
   {
      return false;
   }
}

bool is_RSI3_increasing(){
   if((rsi3_arr[c_rsi_size-1] > rsi3_arr[c_rsi_size-2]) &&
      ((rsi3_arr[c_rsi_size-1]-rsi3_arr[c_rsi_size-2])/rsi3_arr[c_rsi_size-1] > rsi_trading_delta) 
      && ((rsi3_arr[c_rsi_size-1]-rsi3_arr[c_rsi_size-3])/rsi3_arr[c_rsi_size-1] > rsi_trading_delta)
      )
   {
      return true;
   }
   else
   {
      return false;
   }
}

bool is_PSAR_RSI_Buying_Direction(double ask_value, int index)
{
   bool ret_val = false;
   // Not last index
   if(index < (C_LEVEL_DEPTH-1))
   {
      // PSAR value is Selling even above level, and RSI indicating oversold. It can be a good buy
      if((psar_arr[c_psar_size-2]> (level[index+1]*(1-c_SL_OFFESET/2.0))) && is_RSI3_increasing())
      {
         ret_val = true;
      }
      //else
      {
         PrintFormat("PSAR_RSI_Buying::PSAR:%f, next Level with SL:%f, RSI3:%f (%d/%d)",psar_arr[c_psar_size-2], level[index+1]*(1-c_SL_OFFESET/2.0), 
            rsi3_arr[c_rsi_size-1],(psar_arr[c_psar_size-2]> (level[index+1]*(1-c_SL_OFFESET/2.0))), 
            is_RSI3_increasing());
      }
   }
   else
   {
      ret_val = false;
   }
   return ret_val;
}

// It is only in buying decision, not in selling
bool is_PSAR_RSI_Selling_Direction(double ask_value, int index)
{
   bool ret_val = false;
   // Not first index
   if(index > 0)
   {
      // PSAR value is Selling even above level, and RSI3 increasing. It can be a good buy
      if((psar_arr[c_psar_size-1] < (level[index-1]*(1+(c_SL_OFFESET/2.0)))) && !is_RSI3_increasing())
      {
         ret_val = true;
      }
      //else
      //{
      //   PrintFormat("PSAR_RSI_Selling::PSAR:%f, next Level:%f, RSI3:%f (%d/%d)",psar_arr[c_psar_size-1], level[index+1],
      //       rsi3_arr[c_rsi_size-1], (psar_arr[c_psar_size-1] < level[index-1]), (rsi3_arr[c_rsi_size-1] >= C_RSI_SELLING));
      //}
   }
   else
   {
      ret_val = false;
   }
   return ret_val;
}

bool is_macd_bullish()
{
   bool ret_val = false;
   // Not first index
   if(macd_arr[c_macd_size-1] >= macd_arr[c_macd_size-2] && macd_arr[c_macd_size-1] >= macd_arr[c_macd_size-3])
   //if(macd_arr[c_macd_size-1] > 0.0)
   {
      ret_val = true;
   }
   else
   {
      ret_val = false;
   }
   return ret_val;
}



bool is_buying_condition_valid()
{
   bool ret_val=false;
   int   num_indicator_met = 0;
   double bid_value = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bool indicators_status[] = {false, false, false, false, false,false};
   
   calculate_indicators();

   if(is_moving_average_indicating_buying() == true)
   {
      num_indicator_met++;
      indicators_status[0] = true;
   }
   else
   {
      indicators_status[0] = false;
   }
   
   if(is_PSAR_trade_buying_direction(bid_value) == true)
   {
      num_indicator_met++;
      indicators_status[1] = true;
   }
   else
   {
      indicators_status[1] = false;
   }
   
   if(is_rsi_crossover_indicating_buying() == true)
   {
      num_indicator_met++;
      indicators_status[2] = true;
   }
   else
   {
      indicators_status[2] = false;
   }
   
   if(is_PSAR_RSI_Buying_Direction(bid_value, selected_level) == true)
   {
      num_indicator_met+=3;
      indicators_status[3] = true;
   }
   else
   {
      indicators_status[3] = false;
   }
   
   //if(is_PSAR_RSI_Selling_Direction(bid_value, selected_level) == true)
   //{
   //   num_indicator_met--;
   //   indicators_status[4] = true;
   //}
   //else
   //{
   //   indicators_status[4] = false;
   //}
   
   if(is_macd_bullish() == true)
   {
      num_indicator_met++;
      indicators_status[5] = true;
   }
   else
   {
      indicators_status[5] = false;
   }
   
   print_indicator_per_tick(indicators_status);
   
   // Buying condition invalid and in loss
   if(num_indicator_met < c_buying_condition_valid_size && bid_value < (level[selected_level]*(1-c_SL_OFFESET/3.0))
      //(num_indicator_met < (c_buying_condition_valid_size-1) && (bid_value < level[selected_level])) || 
      //(bid_value < (level[selected_level]*(1+c_SL_OFFESET/2.0)) && num_indicator_met < (c_buying_condition_valid_size-1))
      )
   {
      //if(trade.RequestSL() < bid_value*(1-c_trading_offset))
      //{
      //   Print("is_buying_condition_valid::Modifying the current order as basis of Order no longer valid!");
      //   trade.PositionModify(_Symbol,bid_value*(1-c_trading_offset),bid_value);
      //   print_indicators();
      //}
      //else
      //{
      //   Print("is_buying_condition_valid::Skipping modification as stoploss near");
      //}
   }
   return ret_val;
}

void current_ind_trade_triggered()
{
   for(int i=0; i<c_number_of_indicators; i++)
   {
      if(current_trade_triggered_per_ind[i] == true)
      {
         num_trades_triggered_per_ind[i] = num_trades_triggered_per_ind[i] + 1; 
      }
   }
}


bool detect_early_psar(double ask_value)
{
   bool ret_val = false;

   // May be 5  or 5candles ago psar was showing sell, It is relative (may or may not be correct)
   if(psar_arr[0] > ask_value)
   {
      // Here we detect early psar buyig signal
      ret_val = true;
   }
   PrintFormat("PSAR[0] =%f, PSAR[3] =%f,PSAR[latest]=%f",psar_arr[0],psar_arr[3],psar_arr[(c_psar_size-1)]);
   return ret_val;
}

bool detect_upwards_buying_RSI()
{
   bool ret_val = false;
   
   // last one shouldn't be top of RSI
   if(((rsi3_arr[c_rsi_size-1] > rsi3_arr[c_rsi_size-2]) && (rsi3_arr[c_rsi_size-1] > rsi3_arr[c_rsi_size-3])))
   {
      // Here 
      ret_val = true;
   }

   return ret_val;
}

bool not_a_continuous_failure_level(int index)
{
   bool ret_val = true;
   if(level_failure[index] > 0)
   {
      double success_ratio= level_success[index]/(double)(level_failure[index]);
      if((success_ratio > 0.0 && success_ratio < 0.32) || (success_ratio == 0.0 && level_failure[index] > 1))
      {
         ret_val = false;
         if(index!=forbidden_level)
         {
            PrintFormat("success_ratio:%f of index:%d", success_ratio, index); 
            forbidden_level = index;
         }
      }
   }
   return ret_val;
}
