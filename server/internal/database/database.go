package database

import (
	"database/sql"
	_ "embed"
	"fmt"
	"log"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

//go:embed schema.sql
var schemaSQL string

type DB struct {
	conn *sql.DB
}

// Trade represents a trade record
type Trade struct {
	ID              int64
	StrategyID      *int64
	UserID          string
	OrderID         string
	Symbol          string
	Qty             string
	Side            string
	OrderType       string
	TimeInForce     string
	LimitPrice      *string
	StopPrice       *string
	FilledQty       string
	FilledAvgPrice  *string
	OrderStatus     string
	SubmittedAt     time.Time
	FilledAt        *time.Time
	ErrorMessage    *string
}

// Strategy represents a trading strategy
type Strategy struct {
	ID        int64
	UserID    string
	Name      string
	FilePath  string
	CreatedAt time.Time
	UpdatedAt time.Time
	Status    string
}

// Position represents a current position
type Position struct {
	ID             int64
	StrategyID     int64
	UserID         string
	Symbol         string
	Qty            string
	AvgEntryPrice  string
	CurrentPrice   *string
	MarketValue    *string
	UnrealizedPL   *string
	UpdatedAt      time.Time
}

// NewDB creates a new database connection and initializes the schema
func NewDB(dbPath string) (*DB, error) {
	conn, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Enable foreign keys
	if _, err := conn.Exec("PRAGMA foreign_keys = ON"); err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to enable foreign keys: %w", err)
	}

	// Initialize schema
	if _, err := conn.Exec(schemaSQL); err != nil {
		conn.Close()
		return nil, fmt.Errorf("failed to initialize schema: %w", err)
	}

	log.Printf("Database initialized at %s", dbPath)

	return &DB{conn: conn}, nil
}

// Close closes the database connection
func (db *DB) Close() error {
	return db.conn.Close()
}

// LogTrade inserts a new trade record
func (db *DB) LogTrade(trade *Trade) (int64, error) {
	query := `
		INSERT INTO trades (
			strategy_id, user_id, order_id, symbol, qty, side,
			order_type, time_in_force, limit_price, stop_price,
			filled_qty, filled_avg_price, order_status, submitted_at,
			filled_at, error_message
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	result, err := db.conn.Exec(
		query,
		trade.StrategyID,
		trade.UserID,
		trade.OrderID,
		trade.Symbol,
		trade.Qty,
		trade.Side,
		trade.OrderType,
		trade.TimeInForce,
		trade.LimitPrice,
		trade.StopPrice,
		trade.FilledQty,
		trade.FilledAvgPrice,
		trade.OrderStatus,
		trade.SubmittedAt,
		trade.FilledAt,
		trade.ErrorMessage,
	)

	if err != nil {
		return 0, fmt.Errorf("failed to log trade: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("failed to get trade ID: %w", err)
	}

	log.Printf("Logged trade ID=%d for user=%s order=%s symbol=%s", id, trade.UserID, trade.OrderID, trade.Symbol)
	return id, nil
}

// UpdateTradeStatus updates the status of an existing trade
func (db *DB) UpdateTradeStatus(orderID string, status string, filledQty string, filledAvgPrice *string, filledAt *time.Time) error {
	query := `
		UPDATE trades
		SET order_status = ?, filled_qty = ?, filled_avg_price = ?, filled_at = ?
		WHERE order_id = ?
	`

	_, err := db.conn.Exec(query, status, filledQty, filledAvgPrice, filledAt, orderID)
	if err != nil {
		return fmt.Errorf("failed to update trade status: %w", err)
	}

	log.Printf("Updated trade order=%s status=%s filled_qty=%s", orderID, status, filledQty)
	return nil
}

// GetTradesByUser retrieves all trades for a specific user
func (db *DB) GetTradesByUser(userID string, limit int) ([]Trade, error) {
	query := `
		SELECT id, strategy_id, user_id, order_id, symbol, qty, side,
		       order_type, time_in_force, limit_price, stop_price,
		       filled_qty, filled_avg_price, order_status, submitted_at,
		       filled_at, error_message
		FROM trades
		WHERE user_id = ?
		ORDER BY submitted_at DESC
		LIMIT ?
	`

	rows, err := db.conn.Query(query, userID, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to query trades: %w", err)
	}
	defer rows.Close()

	var trades []Trade
	for rows.Next() {
		var t Trade
		err := rows.Scan(
			&t.ID, &t.StrategyID, &t.UserID, &t.OrderID, &t.Symbol,
			&t.Qty, &t.Side, &t.OrderType, &t.TimeInForce,
			&t.LimitPrice, &t.StopPrice, &t.FilledQty,
			&t.FilledAvgPrice, &t.OrderStatus, &t.SubmittedAt,
			&t.FilledAt, &t.ErrorMessage,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan trade: %w", err)
		}
		trades = append(trades, t)
	}

	return trades, nil
}

// CreateStrategy creates a new strategy record
func (db *DB) CreateStrategy(strategy *Strategy) (int64, error) {
	query := `
		INSERT INTO strategies (user_id, name, file_path, status)
		VALUES (?, ?, ?, ?)
	`

	result, err := db.conn.Exec(query, strategy.UserID, strategy.Name, strategy.FilePath, strategy.Status)
	if err != nil {
		return 0, fmt.Errorf("failed to create strategy: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return 0, fmt.Errorf("failed to get strategy ID: %w", err)
	}

	log.Printf("Created strategy ID=%d name=%s for user=%s", id, strategy.Name, strategy.UserID)
	return id, nil
}

// GetStrategyByID retrieves a strategy by ID
func (db *DB) GetStrategyByID(id int64) (*Strategy, error) {
	query := `
		SELECT id, user_id, name, file_path, created_at, updated_at, status
		FROM strategies
		WHERE id = ?
	`

	var s Strategy
	err := db.conn.QueryRow(query, id).Scan(
		&s.ID, &s.UserID, &s.Name, &s.FilePath,
		&s.CreatedAt, &s.UpdatedAt, &s.Status,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to get strategy: %w", err)
	}

	return &s, nil
}
