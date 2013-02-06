package org.marketcetera.marketdata.interactivebrokers;

import java.math.BigDecimal;

import org.marketcetera.marketdata.interactivebrokers.IBFeedManager.EventType;

public class MarketDataResponse {
	
	private BigDecimal price=new BigDecimal(0);
	private BigDecimal size=new BigDecimal(0);
	private EventType eventType;
	private String symbol;
		
	MarketDataResponse(EventType inEventType) {
		eventType=inEventType;	

	}
	
	public void setPrice(BigDecimal price) {
		this.price = price;
	}

	public BigDecimal getPrice() {
		return price;
	}

	public void setEventType(EventType eventType) {
		this.eventType = eventType;
	}

	public EventType getEventType() {
		return eventType;
	}

	public void setSize(BigDecimal size) {
		this.size = size;
	}

	public BigDecimal getSize() {
		return size;
	}

	public void setSymbol(String symbol) {
		this.symbol = symbol;
	}

	public String getSymbol() {
		return symbol;
	}


}
