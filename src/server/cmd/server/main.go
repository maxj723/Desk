package main

import (
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"google.golang.org/protobuf/proto"

	"desk/internal/alpaca"
	"desk/internal/database"
	orderprotos "desk/internal/protos/orders"
)

type Application struct {
	alpacaClient *alpaca.Client
	db           *database.DB
}

func (app *Application) handleOrder(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusInternalServerError)
		return
	}

	var orderReq orderprotos.OrderRequest
	if err := proto.Unmarshal(body, &orderReq); err != nil {
		http.Error(w, "Bad request: Failed to unmarshal protobuf", http.StatusBadRequest)
		return
	}

	// Extract user ID from request header (for now, use a default or header value)
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		userID = "default_user" // Default for testing
	}

	log.Printf("Received order request: User=%s Symbol=%s Qty=%s Side=%s Type=%s",
		userID, orderReq.GetSymbol(), orderReq.GetQty(), orderReq.GetSide(), orderReq.GetOrderType())

	placedOrder, err := app.alpacaClient.PlaceOrder(&orderReq)
	if err != nil {
		log.Printf("Failed to place order: %v", err)

		// Log failed trade to database
		errMsg := err.Error()
		trade := &database.Trade{
			UserID:       userID,
			OrderID:      "", // No order ID for failed orders
			Symbol:       orderReq.GetSymbol(),
			Qty:          orderReq.GetQty(),
			Side:         orderReq.GetSide(),
			OrderType:    orderReq.GetOrderType(),
			TimeInForce:  orderReq.GetTimeInForce(),
			OrderStatus:  "rejected",
			SubmittedAt:  time.Now(),
			ErrorMessage: &errMsg,
		}
		if limitPrice := orderReq.GetLimitPrice(); limitPrice != "" {
			trade.LimitPrice = &limitPrice
		}
		if stopPrice := orderReq.GetStopPrice(); stopPrice != "" {
			trade.StopPrice = &stopPrice
		}

		if _, dbErr := app.db.LogTrade(trade); dbErr != nil {
			log.Printf("Failed to log rejected trade to database: %v", dbErr)
		}

		// Create error response
		errorResp := &orderprotos.OrderResponse{
			Status:  "error",
			Message: err.Error(),
			Symbol:  orderReq.GetSymbol(),
			Qty:     orderReq.GetQty(),
			Side:    orderReq.GetSide(),
		}

		respBytes, _ := proto.Marshal(errorResp)
		w.Header().Set("Content-Type", "application/x-protobuf")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write(respBytes)
		return
	}

	log.Printf("Successfully placed order - ID: %s, Status: %s", placedOrder.ID, placedOrder.Status)

	// Log successful trade to database
	filledAvgPrice := placedOrder.FilledAvgPrice.String()
	trade := &database.Trade{
		UserID:         userID,
		OrderID:        placedOrder.ID,
		Symbol:         placedOrder.Symbol,
		Qty:            placedOrder.Qty.String(),
		Side:           string(placedOrder.Side),
		OrderType:      string(placedOrder.Type),
		TimeInForce:    string(placedOrder.TimeInForce),
		FilledQty:      placedOrder.FilledQty.String(),
		FilledAvgPrice: &filledAvgPrice,
		OrderStatus:    string(placedOrder.Status),
		SubmittedAt:    time.Now(),
	}
	if limitPrice := orderReq.GetLimitPrice(); limitPrice != "" {
		trade.LimitPrice = &limitPrice
	}
	if stopPrice := orderReq.GetStopPrice(); stopPrice != "" {
		trade.StopPrice = &stopPrice
	}

	if _, err := app.db.LogTrade(trade); err != nil {
		log.Printf("Failed to log trade to database: %v", err)
	}

	// Create success response
	successResp := &orderprotos.OrderResponse{
		Status:      "success",
		OrderId:     placedOrder.ID,
		Message:     "Order placed successfully",
		Symbol:      placedOrder.Symbol,
		Qty:         placedOrder.Qty.String(),
		Side:        string(placedOrder.Side),
		FilledQty:   placedOrder.FilledQty.String(),
		OrderStatus: string(placedOrder.Status),
	}

	respBytes, err := proto.Marshal(successResp)
	if err != nil {
		http.Error(w, "Failed to marshal response", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/x-protobuf")
	w.WriteHeader(http.StatusCreated)
	w.Write(respBytes)
}

func main() {
	apiKey := os.Getenv("APCA_API_KEY_ID")
	apiSecret := os.Getenv("APCA_API_SECRET_KEY")
	baseURL := os.Getenv("APCA_API_BASE_URL")
	dbPath := os.Getenv("DB_PATH")

	if apiKey == "" || apiSecret == "" {
		log.Fatal("Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY must be set in environment.")
	}

	// Default to paper trading URL if not specified
	if baseURL == "" {
		baseURL = "https://paper-api.alpaca.markets"
		log.Printf("Using default paper trading URL: %s", baseURL)
	}

	// Default database path
	if dbPath == "" {
		dbPath = "./trading_desk.db"
	}

	// Initialize Alpaca client
	client, err := alpaca.NewClient(apiKey, apiSecret, baseURL)
	if err != nil {
		log.Fatalf("Failed to initialize Alpaca client: %v", err)
	}

	// Initialize database
	db, err := database.NewDB(dbPath)
	if err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	defer db.Close()

	app := &Application{
		alpacaClient: client,
		db:           db,
	}

	// Register the handler method
	http.HandleFunc("/order", app.handleOrder)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Starting Quant Club Trading Desk on http://localhost:%s", port)
	log.Printf("Connected to Alpaca API at %s", baseURL)
	log.Printf("Database: %s", dbPath)
	log.Printf("Endpoints:")
	log.Printf("   POST /order - Place a trading order (protobuf)")

	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Could not start server: %s", err)
	}
}