//+------------------------------------------------------------------+
//|                                                         MyEA.mq5  |
//|                        Copyright 2024, Your Name                 |
//|                                     https://www.example.com      |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Strings\String.mqh>

CTrade trade;

// Define your MetaTrader 5 account credentials
input long MT5_LOGIN = 1520507063; // Replace with your MT5 account login
input string MT5_PASSWORD = "e?I??56k?W*"; // Replace with your MT5 password
input string MT5_SERVER = "FTMO-Demo2"; // Replace with your broker's server

input string url_formatter = "http://%s:%d%s";
input string Host = "localhost";
input int Port = 8080;
input int Timeout = 50;
input int Timer = 20;
input string headers = "Content-Type: application/json\r\n";
input int MAX_RECENT_ORDERS = 4;

//+------------------------------------------------------------------+
//| Http responce                                                    |
//+------------------------------------------------------------------+
struct HttpResponse
  {
   int               status;
   string            body;
  };
//+------------------------------------------------------------------+
//| Http request                                                     |
//+------------------------------------------------------------------+
struct HttpRequest
  {
   string            url;
   string            body;
   string            headers;
  };
//+--

struct OrderInfo
{
    string symbol;
    string type;
    datetime time;
    double profit;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    if(!InitializeMT5())
    {
        Print("MetaTrader 5 initialization or login failed, exiting...");
        return INIT_FAILED;
    }
    
    string data = ConnectServer();
    Print(data);
    EventSetMillisecondTimer(Timer);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Initialize MetaTrader 5 and log in to the account              |
//+------------------------------------------------------------------+
bool InitializeMT5()
{
    long account = AccountInfoInteger(ACCOUNT_LOGIN);
      
    // Connect to MetaTrader 5
    if(account == 0) 
    {
        Print("Failed to initialize MetaTrader 5, error: ", GetLastError());
        return false;
    }
    
    Print("Logged in to account ", account , " successfully");
    return true;
}

//+------------------------------------------------------------------+
//| Handle commands received from client                             |
//+------------------------------------------------------------------+
string HandleCommand(string jsonString)
{
    // Manually parse the simple JSON command
    string command = ParseJson(jsonString, "command");
    Print(command);
    string uuid = ParseJson(jsonString, "uuid");
    Print(uuid);
    string accountId = ParseJson(jsonString, "account");
    Print(accountId);
    string action = ParseJson(command, "action");
    Print(action);
    string response;

    int account = AccountInfoInteger(ACCOUNT_LOGIN);
    if (account != accountId) {
        return "{\"error\": \"Not the correct account for execution.\"}";
    }

    if (action == "order_send")
    {
        response = OrderSend(jsonString);
    }
    else if (action == "order_modify")
    {
        response = OrderModify(jsonString);
    }
    else if (action == "order_close")
    {
        response = OrderClose(jsonString);
    }
    else if (action == "order_find")
    {
        response = OrderFind(jsonString);
    }
    else if (action == "order_list")
    {
        response = OrderList();
    }
    else if (action == "last_orders")
    {
        response = LastOrders();
    }
    else
    {
        return "{\"error\": \"Unknown command\"}";
    }
    
    return "{\"uuid\": \"" + uuid + "\", \"response\": " + response + "}";
}

//+------------------------------------------------------------------+
//| Parse JSON string to extract a value                            |
//+------------------------------------------------------------------+
string ParseJson(string jsonString, string key)
{
    string result = "";
    int keyIndex = StringFind(jsonString, "\"" + key + "\"");

    if (keyIndex != -1)
    {
        // Find the position of the colon
        int valueStart = StringFind(jsonString, ":", keyIndex) + 1;

        // Find the position of the next comma or closing brace
        int valueEnd = StringFind(jsonString, ",", valueStart);
        if (valueEnd == -1) // Handle the last key-value pair
        {
            valueEnd = StringFind(jsonString, "}", valueStart);
        }

        // Extract the value
        result = StringSubstr(jsonString, valueStart, valueEnd - valueStart);

        // Remove surrounding quotes
        if (StringFind(result, "\"") == 0)
        {
            result = StringSubstr(result, 1, StringLen(result) - 2); // Remove quotes
        }

        // Remove leading spaces
        while (StringLen(result) > 0 && StringFind(result, " ") == 0)
        {
            result = StringSubstr(result, 1, StringLen(result) - 1);
        }

        // Remove trailing spaces
        while (StringLen(result) > 0 && StringFind(result, " ", StringLen(result) - 1) == StringLen(result) - 1)
        {
            result = StringSubstr(result, 0, StringLen(result) - 1);
        }
    }
    return result;
}




//+------------------------------------------------------------------+
//| Send order function                                             |
//+------------------------------------------------------------------+
string OrderSend(string jsonString)
{
    // Parse the order type, symbol, and volume from the JSON string
    string order_type = ParseJson(jsonString, "type");
    Print("TYPE: ", order_type);
    string symbol = ParseJson(jsonString, "symbol");
    Print("SYMBOL: ", symbol);
   
    string volume_str = ParseJson(jsonString, "volume");
    double lot_size = StringToDouble(volume_str);
    Print("LOT: ", lot_size);
    
    // Retrieve market prices for the symbol
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Initialize optional parameters
    double price = (order_type == "buy") ? ask : bid; // Default to 0.0 to indicate "not set"
    Print("PRICE: ", price);
    //long slippage = 0;  // Default slippage
    //ulong magic = 0;    // Default magic number

    // Check if optional parameters are provided
    string price_str = ParseJson(jsonString, "price");
    if (StringLen(price_str) > 0)
        price = StringToDouble(price_str);

    // Prepare the trade request
    MqlTradeRequest request={};
    MqlTradeResult result={};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lot_size;
    request.type = (order_type == "buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = price;
    //request.deviation = slippage;
    //request.magic = magic;
    request.comment = ParseJson(jsonString, "comment");
    request.type_time = ORDER_TIME_GTC;
    request.type_filling = ORDER_FILLING_IOC;


    string slippage_str = ParseJson(jsonString, "slippage");
    if (StringLen(slippage_str) > 0)
    {
        Print("SLIPPAGE IS SET!");
        request.deviation = StringToInteger(slippage_str);
        
    }

    string magic_str = ParseJson(jsonString, "magic");
    if (StringLen(magic_str) > 0)
    {
        Print("MAGIC IS SET!");
        request.magic = StringToInteger(magic_str);
    }
    
    // Handle stop loss (sl)
    string sl_str = ParseJson(jsonString, "sl");
    if (StringLen(sl_str) > 0) 
    {
        Print("SL IS SET!");
        request.sl = StringToInteger(sl_str);
    }

    // Handle take profit (tp)
    string tp_str = ParseJson(jsonString, "tp");
    if (StringLen(tp_str) > 0) 
    {
        Print("TP IS SET!");
        double tp = StringToDouble(tp_str);
        request.tp = (order_type == "buy") ? price + tp * SymbolInfoDouble(symbol, SYMBOL_POINT) : price - tp * SymbolInfoDouble(symbol, SYMBOL_POINT);
    }

    // Send the order
    if (OrderSend(request, result)) 
    {
        // Prepare response data as a JSON-like string
        string response = "{\"TICKET\": " + IntegerToString(result.order) +
                          ", \"RETCODE\": " + IntegerToString(result.retcode) +
                          ", \"DEAL\": " + IntegerToString(result.deal) +
                          ", \"VOLUME\": " + DoubleToString(lot_size, 2) +
                          ", \"PRICE\": " + DoubleToString(price, 5) +
                          ", \"BID\": " + DoubleToString(bid, 5) +
                          ", \"ASK\": " + DoubleToString(ask, 5) +
                          ", \"TYPE\": \"" + order_type + "\"}";

        return response;
    } 
    else 
    {
        // If the order failed, return an error message
        return "{\"error\": \"Order send failed, error: " + GetLastError() + "\"}";
    }
}


//+------------------------------------------------------------------+
//| Modify order function                                           |
//+------------------------------------------------------------------+
string OrderModify(string jsonString)
{
    // Parse the ticket and other parameters from the input string
    ulong order_ticket = StringToInteger(ParseJson(jsonString, "ticket"));
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    
    string response;

    // Select the order by ticket
    if (PositionSelectByTicket(order_ticket))
    {
        int type = PositionGetInteger(POSITION_TYPE);
        
        int closeType;
        if (type == POSITION_TYPE_BUY) closeType = ORDER_TYPE_SELL; // Close a buy position with a sell order
        else if (type == POSITION_TYPE_SELL) closeType = ORDER_TYPE_BUY;  // Close a sell position with a buy order
        
        request.action = TRADE_ACTION_SLTP;
        request.symbol = Symbol();
        request.position = order_ticket;
        request.type = closeType;
        request.sl = PositionGetDouble(POSITION_SL); // Retain existing SL unless specified
        request.tp = PositionGetDouble(POSITION_TP); // Retain existing TP unless specified

        // Update stop loss (sl) if provided in the command
        string sl_str = ParseJson(jsonString, "sl");
        if (StringLen(sl_str) > 0)
        {
            double sl = StringToDouble(sl_str);
            request.sl = sl; // Update stop loss
        }

        // Update take profit (tp) if provided in the command
        string tp_str = ParseJson(jsonString, "tp");
        if (StringLen(tp_str) > 0)
        {
            double tp = StringToDouble(tp_str);
            request.tp = tp; // Update take profit
        }

        // Send the modification request
        if (OrderSend(request, result))
        {
            // Prepare the response in a JSON-like format
            response = "{\"TICKET\": " + IntegerToString(order_ticket) +
                       ", \"RETCODE\": " + IntegerToString(result.retcode) +
                       ", \"DEAL\": " + IntegerToString(result.deal) +
                       ", \"VOLUME\": " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) +
                       ", \"PRICE\": " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) +
                       ", \"BID\": " + DoubleToString(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID), 5) +
                       ", \"ASK\": " + DoubleToString(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK), 5) +
                       ", \"TYPE\": " + IntegerToString(PositionGetInteger(POSITION_TYPE)) + "}";
        }
        else
        {
            // If the modification failed, return an error message
            response = "{\"error\": \"Order modify failed, error: " + IntegerToString(GetLastError()) + "\"}";
        }
    }
    else
    {
        // If the order is not found, return an error message
        response = "{\"error\": \"Order with ticket " + IntegerToString(order_ticket) + " not found.\"}";
    }

    return response;
}


//+------------------------------------------------------------------+
//| Close order function                                            |
//+------------------------------------------------------------------+
string OrderClose(string jsonString)
{
    // Parse the ticket from the input JSON string
    ulong order_ticket = StringToInteger(ParseJson(jsonString, "ticket"));
    
    string response;
    
    // Select the order by ticket
    if (PositionSelectByTicket(order_ticket))
    {
        // Parse the requested volume from the JSON string
        double requested_volume = StringToDouble(ParseJson(jsonString, "volume"));
        
        // If volume is not provided, default to the current order's volume
        if (requested_volume <= 0)
        {
            requested_volume = PositionGetDouble(POSITION_VOLUME);
        }
        
        int type = PositionGetInteger(POSITION_TYPE);
        
        int closeType;
        if (type == POSITION_TYPE_BUY) closeType = ORDER_TYPE_SELL; // Close a buy position with a sell order
        else if (type == POSITION_TYPE_SELL) closeType = ORDER_TYPE_BUY;  // Close a sell position with a buy order

        MqlTradeRequest close_request;
        MqlTradeResult result;
        ZeroMemory(close_request);

        // Prepare the close request
        close_request.action = TRADE_ACTION_DEAL;
        close_request.symbol = Symbol();
        close_request.position = order_ticket;
        close_request.type = closeType;
        close_request.volume = requested_volume;
        close_request.price = SymbolInfoDouble(Symbol(), closeType == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID);
        close_request.deviation = 10; // Set slippage tolerance

        // Send the close request
        if (OrderSend(close_request, result))
        {
            // Determine the close type (fully closed or partially closed)
            string close_type = (requested_volume == PositionGetDouble(POSITION_VOLUME)) ? "FULLY_CLOSED" : "PARTIALLY_CLOSED";

            // Prepare the response in a JSON-like format with additional details
            response = "{\"TICKET\": " + IntegerToString(order_ticket) +
                       ", \"RETCODE\": " + IntegerToString(result.retcode) +
                       ", \"DEAL\": " + IntegerToString(result.deal) +
                       ", \"VOLUME\": " + DoubleToString(requested_volume, 2) +
                       ", \"PRICE\": " + DoubleToString(close_request.price, 5) +
                       ", \"BID\": " + DoubleToString(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID), 5) +
                       ", \"ASK\": " + DoubleToString(SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK), 5) +
                       ", \"TYPE\": \"" + close_type + "\"}";
        }
        else
        {
            // If closing the order failed, return an error message
            response = "{\"error\": \"Order close failed, error: " + IntegerToString(GetLastError()) + "\"}";
        }
    }
    else
    {
        // If the order is not found, return an error message
        response = "{\"error\": \"Order with ticket " + IntegerToString(order_ticket) + " not found.\"}";
    }

    return response;
}


//+------------------------------------------------------------------+
//| Find order function                                            |
//+------------------------------------------------------------------+
string OrderFind(string jsonString)
{
    // Parse the ticket from the input JSON string
    ulong order_ticket = StringToInteger(ParseJson(jsonString, "ticket"));

    string response;

    // Select the order by ticket
    if (PositionSelectByTicket(order_ticket))
    {
        // Prepare the response in a JSON-like format with all required order details
        response = "{\"TICKET\": " + IntegerToString(order_ticket) +
                   ", \"SYMBOL\": \"" + PositionGetString(POSITION_SYMBOL) + "\"" +
                   ", \"VOLUME\": " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) +
                   ", \"PRICE\": " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) +
                   ", \"SL\": " + DoubleToString(PositionGetDouble(POSITION_SL), 5) +
                   ", \"TP\": " + DoubleToString(PositionGetDouble(POSITION_TP), 5) +
                   ", \"MAGIC\": " + IntegerToString(PositionGetInteger(POSITION_MAGIC)) +
                   ", \"COMMENT\": \"" + PositionGetString(POSITION_COMMENT) + "\"" +
                   ", \"TYPE\": " + IntegerToString(PositionGetInteger(POSITION_TYPE)) +
                   ", \"TIME\": " + IntegerToString(PositionGetInteger(POSITION_TIME)) +
                   ", \"PROFIT\": " + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + "}";
    }
    else
    {
        // If the order is not found, return an error message
        response = "{\"error\": \"Order with ticket " + IntegerToString(order_ticket) + " not found.\"}";
    }

    return response;
}


//+------------------------------------------------------------------+
//| List orders function                                            |
//+------------------------------------------------------------------+
string OrderList()
{
    string response = "{\"ORDERS\": [";
    int totalOrders = PositionsTotal();

    if (totalOrders == 0)
    {
        // If there are no open positions, return an empty orders list
        response += "]}";
        Print("No open positions found.");
        return response;
    }

    // Loop through all positions
    for (int i = 0; i < totalOrders; i++)
    {
        // Get the ticket of the position at index i
        ulong ticket = PositionGetTicket(i);
        
        // Select the position by its ticket
        if (PositionSelectByTicket(ticket))
        {
            // Format the order information in JSON
            string orderInfo = "{\"TICKET\": " + IntegerToString(PositionGetInteger(POSITION_TICKET)) +
                               ", \"SYMBOL\": \"" + PositionGetString(POSITION_SYMBOL) + "\"" +
                               ", \"VOLUME\": " + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2) +
                               ", \"PRICE\": " + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), 5) +
                               ", \"TYPE\": " + IntegerToString(PositionGetInteger(POSITION_TYPE)) +
                               ", \"SL\": " + DoubleToString(PositionGetDouble(POSITION_SL), 5) +
                               ", \"TP\": " + DoubleToString(PositionGetDouble(POSITION_TP), 5) +
                               ", \"MAGIC\": " + IntegerToString(PositionGetInteger(POSITION_MAGIC)) +
                               ", \"COMMENT\": \"" + PositionGetString(POSITION_COMMENT) + "\"" +
                               ", \"TIME\": " + IntegerToString(PositionGetInteger(POSITION_TIME)) +
                               ", \"PROFIT\": " + DoubleToString(PositionGetDouble(POSITION_PROFIT), 2) + "}";

            // Append orderInfo to the response
            response += orderInfo;

            // Add a comma between orders, except for the last one
            if (i < totalOrders - 1)
                response += ",";
        }
        else
        {
            Print("Failed to select position with ticket ", ticket);
        }
    }

    response += "]}";  // Close the JSON array
    return response;
}

string LastOrders() {
    datetime end_time = TimeCurrent();
    datetime start_time = end_time - 100 * 86400;

    // Declare an array for order info
    OrderInfo order_list[];
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);

    HistorySelect(start_time, end_time);
    ulong total_orders = HistoryDealsTotal();
    if (total_orders == 0)
    {
        return "{\"ORDERS\": \"[]\", \"BALANCE\": \"" + DoubleToString(balance, 2) + "\"}";
    }

    // Populate order_list with deals based on profit and time filter
for (ulong i = 0; i < total_orders; i++)
{
    ulong deal_ticket = HistoryDealGetTicket(i);
    if (deal_ticket == 0)
        continue;

    double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
    datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
    string symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
    int deal_type = (int)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);

    // Filter based on profit and time
    if (profit != 0.0 && deal_time >= start_time && deal_time <= end_time)
    {
        OrderInfo order_info;
        order_info.symbol = symbol;
        order_info.type = (deal_type == DEAL_TYPE_SELL) ? "Sell" : "Buy";
        order_info.time = deal_time;
        order_info.profit = profit;

        // Add order information to the list
        ArrayResize(order_list, ArraySize(order_list) + 1);
        order_list[ArraySize(order_list) - 1] = order_info;
    }
}

    // Custom sorting loop to sort orders by time in descending order
    int order_count = ArraySize(order_list);
    for (int j = 0; j < order_count - 1; j++)
    {
        for (int k = j + 1; k < order_count; k++)
        {
            if (order_list[j].time < order_list[k].time)
            {
                OrderInfo temp = order_list[j];
                order_list[j] = order_list[k];
                order_list[k] = temp;
            }
        }
    }

    // Limit to the most recent orders
    if (order_count > MAX_RECENT_ORDERS)
    {
        ArrayResize(order_list, MAX_RECENT_ORDERS);
    }

    // Prepare the output JSON
    string output_orders = "[";
    for (int j = 0; j < ArraySize(order_list); j++) {
        if (j > 0)
            output_orders += ", ";
        output_orders += StringFormat("{\"SYMBOL\": \"%s\", \"TYPE\": \"%s\", \"TIME\": \"%s\", \"PROFIT\": %.2f}",
                                       order_list[j].symbol,
                                       order_list[j].type,
                                       TimeToString(order_list[j].time, TIME_DATE | TIME_MINUTES),
                                       order_list[j].profit);
    }
    output_orders += "]";

    return "{\"ORDERS\": " + output_orders + ", \"BALANCE\": \"" + DoubleToString(balance, 2) + "\"}";
}

void GetData(HttpRequest &request, HttpResponse &response) {
    char responseBody[];
    uchar requestBody[];
    string responseHeaders;
    
    int status = WebRequest("GET", request.url, request.headers, Timeout, requestBody, responseBody, responseHeaders);
    response.body = CharArrayToString(responseBody); // Convert response to string
    response.status = status;
    
    if (status == 200) {
        Print(request.body);
        response.body = HandleCommand(response.body);  // Process and handle command
    }
   //   Intercept(response);
}
  
void PostData(HttpRequest &request, HttpResponse &response)
  {
   char responseBody[];
   uchar requestBody[];
   string responseHeaders;
   StringToCharArray(request.body, requestBody, 0, StringLen(request.body));
   int status = WebRequest("POST", request.url, headers, Timeout, requestBody, responseBody, responseHeaders);
   response.body = CharArrayToString(responseBody, 0, WHOLE_ARRAY, CP_UTF8);
   response.status = status;
//   Intercept(response);
  }
  
string ConnectServer()
  {
   HttpRequest request;
   request.url = StringFormat(url_formatter, Host, Port, "/connect");
   request.headers = headers;
   HttpResponse response;
   PostData(request, response);
   return response.body;
  }


void Intercept(HttpResponse &response)
  {
   if (response.status != 400)
      return;
      
      Alert(response.body, " ");
  }

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}


void OnTimer() 
{
   HttpRequest request;
   request.url = StringFormat(url_formatter, Host, Port, "/execute?id=44W6Z7oREwSccEU1577Yio05UYH20kayUmLR8u7X685gmUSiAbJhguKUmKR8vYPT&account=" + AccountInfoInteger(ACCOUNT_LOGIN));
   request.headers = headers;
   HttpResponse response;
   GetData(request, response);
   
   if (response.body == "{\"error\": \"No commands to execute.\"}") {
       return;
   }
   
   if (response.body == "{\"error\": \"Not the correct account for execution.\"}") {
       return;
   }
   
   Print(response.body);
   
   HttpRequest request2;
   request2.url = StringFormat(url_formatter, Host, Port, "/signal?id=44W6Z7oREwSccEU1577Yio05UYH20kayUmLR8u7X685gmUSiAbJhguKUmKR8vYPT");
   request2.headers = headers;
   request2.body = response.body;
   HttpResponse response2;
   
   PostData(request2, response2);
   Print(response2.body);
}
//+------------------------------------------------------------------+
//| Main function                                                   |
//+------------------------------------------------------------------+
void OnTick()
{    
}
//+------------------------------------------------------------------+