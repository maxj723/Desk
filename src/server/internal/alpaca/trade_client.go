package alpaca

import (
	"github.com/alpacahq/alpaca-trade-api-go/v3/alpaca"
	"github.com/shopspring/decimal"
	orderprotos "desk/internal/protos/orders"
)

type Client struct {
	tradeClient *alpaca.Client
}

func NewClient(apiKey, apiSecret, baseUrl string) (*Client, error) {
	tradeClient := alpaca.NewClient(alpaca.ClientOpts{
		APIKey:    apiKey,
		APISecret: apiSecret,
		BaseURL:   baseUrl,
	})
	_, err := tradeClient.GetAccount()

	return &Client{
		tradeClient: tradeClient,
	}, err
}

func (c *Client) PlaceOrder(orderReq *orderprotos.OrderRequest) (*alpaca.Order, error) {
	qtyDecimal, err := decimal.NewFromString(orderReq.GetQty())
	if err != nil {
		return nil, err
	}

	placeOrderRequest := alpaca.PlaceOrderRequest{
		Symbol:      orderReq.GetSymbol(),
		Qty:         &qtyDecimal,
		Side:        alpaca.Side(orderReq.GetSide()),
		Type:        alpaca.OrderType(orderReq.GetOrderType()),
		TimeInForce: alpaca.TimeInForce(orderReq.GetTimeInForce()),
	}

	// Add limit price if provided
	if limitPrice := orderReq.GetLimitPrice(); limitPrice != "" {
		limitPriceDecimal, err := decimal.NewFromString(limitPrice)
		if err != nil {
			return nil, err
		}
		placeOrderRequest.LimitPrice = &limitPriceDecimal
	}

	// Add stop price if provided
	if stopPrice := orderReq.GetStopPrice(); stopPrice != "" {
		stopPriceDecimal, err := decimal.NewFromString(stopPrice)
		if err != nil {
			return nil, err
		}
		placeOrderRequest.StopPrice = &stopPriceDecimal
	}

	placedOrder, err := c.tradeClient.PlaceOrder(placeOrderRequest)
	if err != nil {
		return nil, err
	}

	return placedOrder, nil
}